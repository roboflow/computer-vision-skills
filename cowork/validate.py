"""Validate the checked-in source for the Copilot Cowork app package."""

from __future__ import annotations

import json
import re
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PACKAGE = Path(__file__).resolve().parent / "appPackage"
NAME_PATTERN = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")


def fail(message: str) -> None:
    raise ValueError(message)


def png_size(path: Path) -> tuple[int, int]:
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        fail(f"{path} is not a PNG")
    return struct.unpack(">II", data[16:24])


def frontmatter_value(path: Path, field: str) -> str:
    text = path.read_text()
    if not text.startswith("---\n"):
        fail(f"{path} has no YAML frontmatter")
    parts = text.split("---", 2)
    if len(parts) != 3:
        fail(f"{path} has unterminated YAML frontmatter")
    match = re.search(rf"(?m)^{re.escape(field)}:\s*(.+?)\s*$", parts[1])
    if not match:
        fail(f"{path} has no valid {field} frontmatter field")
    return match.group(1)


def validate() -> None:
    manifest = json.loads((PACKAGE / "manifest.json").read_text())
    if manifest.get("manifestVersion") != "1.28":
        fail("Cowork manifest must use version 1.28")
    if int(manifest.get("version", "0").split(".", 1)[0]) < 1:
        fail("Microsoft 365 app versions must start at 1.0.0 or newer")

    remote = manifest["agentConnectors"][0]["toolSource"]["remoteMcpServer"]
    if "authorization" in remote:
        fail("DCR requires the Cowork connector to omit authorization")
    if not remote["mcpServerUrl"].startswith("https://"):
        fail("Cowork MCP endpoint must use HTTPS")

    tool_path = PACKAGE / remote["mcpToolDescription"]["file"].removeprefix("./")
    tools = json.loads(tool_path.read_text()).get("tools", [])
    if not tools:
        fail("mcpToolDescription must contain at least one tool")
    names = [tool.get("name") for tool in tools]
    if len(names) != len(set(names)):
        fail("mcpToolDescription contains duplicate tool names")
    for tool in tools:
        if not tool.get("description"):
            fail(f"{tool.get('name')} has no description")
        if tool.get("inputSchema", {}).get("type") != "object":
            fail(f"{tool.get('name')} has no object inputSchema")
        annotations = tool.get("annotations", {})
        if not annotations.get("title"):
            fail(f"{tool.get('name')} has no annotation title")
        if "readOnlyHint" not in annotations or "destructiveHint" not in annotations:
            fail(f"{tool.get('name')} has incomplete safety annotations")

    skills = manifest["agentSkills"]
    if len(skills) > 20:
        fail("Cowork supports at most 20 skills per package")
    for entry in skills:
        folder = ROOT / entry["folder"].removeprefix("./")
        skill_file = folder / "SKILL.md"
        name = frontmatter_value(skill_file, "name")
        description = frontmatter_value(skill_file, "description")
        if len(skill_file.read_text()) > 20_000:
            fail(f"{name} SKILL.md exceeds Cowork's 20,000-character limit")
        if folder.name != name or not NAME_PATTERN.fullmatch(name):
            fail(f"skill folder/name mismatch: {folder.name!r} != {name!r}")
        if not 1 <= len(description) <= 1024:
            fail(f"{name} description must contain 1-1024 characters")
        companions = [path for path in folder.rglob("*") if path.is_file() and path != skill_file]
        if len(companions) > 20:
            fail(f"{name} has more than 20 companion files")
        if sum(path.stat().st_size for path in companions) > 10 * 1024 * 1024:
            fail(f"{name} companions exceed 10 MiB")
        if any(path.stat().st_size > 5 * 1024 * 1024 for path in companions):
            fail(f"{name} has a companion larger than 5 MiB")

    expected_icons = {"color.png": (192, 192), "outline.png": (32, 32)}
    for filename, expected in expected_icons.items():
        actual = png_size(PACKAGE / filename)
        if actual != expected:
            fail(f"{filename} must be {expected[0]}x{expected[1]}, got {actual}")

    print(f"Cowork package source is valid: {len(skills)} skills, {len(tools)} tools")


if __name__ == "__main__":
    try:
        validate()
    except (KeyError, OSError, TypeError, ValueError, json.JSONDecodeError) as error:
        print(f"Cowork validation failed: {error}", file=sys.stderr)
        raise SystemExit(1) from error
