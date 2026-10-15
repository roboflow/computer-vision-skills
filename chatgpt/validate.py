"""Validate the assembled ChatGPT plugin package against OpenAI's rules and the ChatGPT surface."""

from __future__ import annotations

import json
from pathlib import Path, PurePosixPath
import re
import struct

SEMVER = re.compile(r"^\d+\.\d+\.\d+$")
NAME = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
COLOR = re.compile(r"^#[0-9A-Fa-f]{6}$")
LINK = re.compile(r"\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)")
REFERENCE_LINK = re.compile(r"(?m)^ {0,3}\[[^\]]+\]:\s*<?([^>\s]+)>?")
CODE_IDENTIFIER = re.compile(r"`([a-z][a-z0-9]*(?:_[a-z0-9]+)+)`")
TEXT_SUFFIXES = {".md", ".py", ".sh", ".txt", ".json", ".yaml", ".yml"}
MAX_IMAGE_BYTES = 5 * 1024 * 1024
URL_FIELDS = ("websiteURL", "supportURL", "privacyPolicyURL", "termsOfServiceURL")


class ValidationError(ValueError):
    def __init__(self, errors: list[str]):
        super().__init__("ChatGPT package is invalid:\n- " + "\n- ".join(errors))
        self.errors = errors


def parse_frontmatter(text: str) -> tuple[dict[str, str], str] | None:
    """Parse flat `key: value` frontmatter. Returns None when anything else is used."""
    text = text.replace("\r\n", "\n")
    if not text.startswith("---\n"):
        return None
    end = text.find("\n---\n", 4)
    if end == -1:
        return None
    fields: dict[str, str] = {}
    for line in text[4:end].split("\n"):
        if not line.strip():
            continue
        match = re.fullmatch(r"([A-Za-z][A-Za-z0-9_-]*):\s*(.*)", line)
        if not match:
            return None
        key, value = match.group(1), match.group(2).strip()
        if value.startswith('"'):
            try:
                value = json.loads(value)
            except ValueError:
                return None
            if not isinstance(value, str):
                return None
        elif value.startswith("'"):
            if len(value) < 2 or not value.endswith("'") or "'" in value[1:-1].replace("''", ""):
                return None
            value = value[1:-1].replace("''", "'")
        elif (value.startswith(("[", "{", "|", ">", "&", "*", "!", "%", "@", "`", "#", "- ", "? ", ": "))
              or value in ("-", "?", ":") or " #" in value or ": " in value or value.endswith(":")):
            return None
        if key in fields:
            return None
        fields[key] = value
    return fields, text[end + 5:]


def luminance(color: str) -> float:
    channels = []
    for index in (1, 3, 5):
        value = int(color[index:index + 2], 16) / 255
        channels.append(value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4)
    return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]


def contrast(first: str, second: str) -> float:
    lighter, darker = sorted((luminance(first), luminance(second)), reverse=True)
    return (lighter + 0.05) / (darker + 0.05)


def image_errors(path: Path, label: str) -> list[str]:
    if not path.is_file():
        return [f"{label} {path.name} does not exist"]
    # OpenAI also accepts JPEG and WebP; we only ship PNG and SVG, so only those are checked.
    if path.suffix.lower() not in (".png", ".svg"):
        return [f"{label} must be PNG or SVG"]
    if path.stat().st_size > MAX_IMAGE_BYTES:
        return [f"{label} is larger than 5 MiB"]
    if path.suffix.lower() == ".svg":
        return []
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        return [f"{label} is not a valid PNG"]
    width, height = struct.unpack(">II", data[16:24])
    if width != height or not 48 <= width <= 4096:
        return [f"{label} must be square, between 48 and 4096 px (got {width}x{height})"]
    return []


def package_path(package: Path, value: object, label: str, errors: list[str]) -> Path | None:
    if not isinstance(value, str) or not value.startswith("./"):
        errors.append(f"{label} must be a relative path starting with ./")
        return None
    path = (package / value).resolve()
    if not path.is_relative_to(package.resolve()):
        errors.append(f"{label} points outside the package")
        return None
    return path


def validate_manifest(package: Path, tools: dict, errors: list[str]) -> str:
    manifest = json.loads((package / "plugin.json").read_text(encoding="utf-8"))
    name = manifest.get("name", "")
    if not NAME.fullmatch(name) or len(name) > 64:
        errors.append("plugin.json name must be lowercase words joined by hyphens, at most 64 characters")
    if not SEMVER.fullmatch(str(manifest.get("version", ""))):
        errors.append("plugin.json version must be a semantic version like 1.0.4")
    openai = manifest.get("extensions", {}).get("com.openai", {})
    interface = openai.get("interface", {})
    for field, limit in (("displayName", 30), ("shortDescription", 30),
                         ("longDescription", 4000), ("developerName", 80)):
        value = interface.get(field)
        if not isinstance(value, str) or not value.strip():
            errors.append(f"interface.{field} is required")
        elif len(value) > limit:
            errors.append(f"interface.{field} is {len(value)} characters, the limit is {limit}")
    if "category" in interface and not isinstance(interface["category"], str):
        errors.append("interface.category must be a string")
    for field in URL_FIELDS:
        if not str(interface.get(field, "")).startswith("https://"):
            errors.append(f"interface.{field} must be an HTTPS URL")
    prompts = interface.get("defaultPrompt", [])
    if not isinstance(prompts, list) or len(prompts) > 3:
        errors.append("interface.defaultPrompt must be a list of at most 3 prompts")
    elif len(set(prompts)) != len(prompts):
        errors.append("interface.defaultPrompt has duplicate prompts")
    else:
        for prompt in prompts:
            if not isinstance(prompt, str) or not prompt.strip() or len(prompt) > 128:
                errors.append(f"starter prompt must be 1 to 128 characters: {prompt!r}")
            elif "@" in prompt:
                errors.append(f"starter prompt must not @mention an app: {prompt!r}")
    for field, background in (("brandColor", "#FFFFFF"), ("brandColorDark", "#212121")):
        color = interface.get(field)
        if color is None:
            continue
        if not isinstance(color, str) or not COLOR.fullmatch(color):
            errors.append(f"interface.{field} must be #RRGGBB")
        elif contrast(color, background) < 2:
            errors.append(f"interface.{field} needs at least 2:1 contrast against {background}")
    for field in ("logo", "composerIcon"):
        if field in interface:
            path = package_path(package, interface[field], f"interface.{field}", errors)
            if path:
                errors.extend(image_errors(path, f"interface.{field}"))
    for index, screenshot in enumerate(interface.get("screenshots", [])):
        path = package_path(package, screenshot, f"interface.screenshots[{index}]", errors)
        if path:
            errors.extend(image_errors(path, f"interface.screenshots[{index}]"))

    cases = openai.get("review", {}).get("test_cases", {})
    positive, negative = cases.get("positive", []), cases.get("negative", [])
    if len(positive) != 5 or len(negative) != 3:
        errors.append("review.test_cases needs 5 positive and 3 negative cases")
    visible = set(tools["visible"])
    for case in positive:
        for field in ("description", "prompt", "tools_triggered", "expected_behavior"):
            if not str(case.get(field, "")).strip():
                errors.append(f"positive test case is missing {field}")
        for tool in re.split(r"[,\s]+", str(case.get("tools_triggered", "")).strip()):
            if tool and tool not in visible:
                errors.append(f"test case tool {tool} is not visible on /openai/mcp")
    for case in negative:
        for field in ("description", "prompt"):
            if not str(case.get(field, "")).strip():
                errors.append(f"negative test case is missing {field}")

    servers = json.loads((package / "mcp.json").read_text(encoding="utf-8")).get("mcpServers", {})
    urls = [server.get("url", "") for server in servers.values()]
    if len(urls) != 1 or not urls[0].startswith("https://") or not urls[0].endswith("/openai/mcp"):
        errors.append("mcp.json must declare one HTTPS server ending in /openai/mcp")
    return name


def validate_skills(package: Path, plugin_name: str, tools: dict,
                    errors: list[str], warnings: list[str]) -> None:
    skills = package / "skills"
    visible = set(tools["visible"])
    # A backticked name sharing a tool's first two words (`universe_search_app`) is probably a
    # stale tool reference; parameters like `model_id` or `api_key` don't match any.
    prefixes = {"_".join(name.split("_")[:2]) for name in visible}
    names: set[str] = set()
    folders = sorted(path for path in skills.iterdir() if path.is_dir())
    if not folders:
        errors.append("the package has no skills")
    for folder in folders:
        entry = folder / "SKILL.md"
        if not entry.is_file():
            errors.append(f"skills/{folder.name} has no SKILL.md")
            continue
        parsed = parse_frontmatter(entry.read_text(encoding="utf-8"))
        if parsed is None:
            errors.append(f"skills/{folder.name}/SKILL.md must start with flat key: value frontmatter")
            continue
        fields, body = parsed
        name, description = fields.get("name", ""), fields.get("description", "")
        if name != folder.name:
            errors.append(f"skills/{folder.name}/SKILL.md name must match its folder")
        if name in names:
            errors.append(f"skill name {name} is not unique")
        names.add(name)
        if len(f"{plugin_name}:{name}") > 64:
            errors.append(f"{plugin_name}:{name} is longer than 64 characters")
        if not description or len(description) > 1024:
            errors.append(f"skills/{folder.name} description must be 1 to 1,024 characters")
        if not body.strip():
            errors.append(f"skills/{folder.name}/SKILL.md has an empty body")

    hidden_bytes = {name: re.compile(rf"(?<![A-Za-z0-9_]){re.escape(name)}(?![A-Za-z0-9_])".encode())
                    for name in tools["hidden"]}
    for path in sorted(package.rglob("*")):
        if not path.is_file():
            continue
        relative = path.relative_to(package).as_posix()
        data = path.read_bytes()
        for name, pattern in hidden_bytes.items():
            match = pattern.search(data)
            if match:
                number = data.count(b"\n", 0, match.start()) + 1
                errors.append(f"{relative}:{number} names {name}, which /openai/mcp hides")

    for path in sorted(skills.rglob("*")):
        if not path.is_file() or path.suffix.lower() not in TEXT_SUFFIXES:
            continue
        relative = path.relative_to(package).as_posix()
        text = path.read_text(encoding="utf-8")
        for number, line in enumerate(text.splitlines(), 1):
            for identifier in CODE_IDENTIFIER.findall(line):
                if "_".join(identifier.split("_")[:2]) in prefixes and identifier not in visible \
                        and identifier not in tools["hidden"]:
                    warnings.append(f"{relative}:{number} `{identifier}` looks like a tool but isn't listed")
        if path.suffix.lower() == ".md":
            for target in LINK.findall(text) + REFERENCE_LINK.findall(text):
                if re.match(r"^[a-z][a-z0-9+.-]*:", target) or target.startswith("#"):
                    continue
                linked = (path.parent / target.split("#", 1)[0]).resolve()
                if not linked.is_relative_to(skills.resolve()) or not linked.exists():
                    errors.append(f"{relative} links to {target}, which is not in the package")


def validate_archive_paths(package: Path, errors: list[str]) -> None:
    seen: set[str] = set()
    for path in package.rglob("*"):
        if not path.is_file():
            continue
        relative = PurePosixPath(path.relative_to(package).as_posix())
        if relative.is_absolute() or ".." in relative.parts:
            errors.append(f"unsafe archive path {relative}")
        folded = str(relative).lower()
        if folded in seen:
            errors.append(f"archive paths collide when case is ignored: {relative}")
        seen.add(folded)


def validate(package: Path, tools: dict) -> list[str]:
    """Raise ValidationError for anything that would break the package; return warnings."""
    errors: list[str] = []
    warnings: list[str] = []
    plugin_name = validate_manifest(package, tools, errors)
    validate_skills(package, plugin_name, tools, errors, warnings)
    validate_archive_paths(package, errors)
    if errors:
        raise ValidationError(errors)
    return warnings
