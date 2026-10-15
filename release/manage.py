"""Version checks and release artifacts, using only Python's standard library."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
from pathlib import Path

MANIFESTS = (".claude-plugin/plugin.json", ".codex-plugin/plugin.json")
PLUGIN_PATHS = ("skills", ".mcp.json", ".claude-plugin", ".codex-plugin", ".agents/plugins")


def git(root: Path, *args: str) -> bytes:
    return subprocess.check_output(["git", "-C", str(root), *args])


def version(value: str) -> tuple[int, int, int]:
    if not isinstance(value, str) or not re.fullmatch(r"(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)", value):
        raise ValueError(f"Expected a stable version X.Y.Z, got {value!r}")
    return tuple(int(part) for part in value.split("."))


def manifests(root: Path) -> list[dict]:
    return [json.loads((root / path).read_text(encoding="utf-8")) for path in MANIFESTS]


def check(root: Path, base: str | None = None) -> str:
    claude, codex = manifests(root)
    current = claude["version"]
    version(current)
    if codex["version"] != current:
        raise ValueError("Claude and Codex versions differ; run python3 release/manage.py bump X.Y.Z")
    if base:
        previous = [json.loads(git(root, "show", f"{base}:{path}"))["version"] for path in MANIFESTS]
        if any(version(current) < version(old) for old in previous):
            raise ValueError("Plugin versions must not decrease")
        changed = git(root, "diff", "--name-only", base, "--", *PLUGIN_PATHS)
        changed += git(root, "ls-files", "--others", "--exclude-standard", "--", *PLUGIN_PATHS)
        if changed and any(version(current) <= version(old) for old in previous):
            raise ValueError("Shipped plugin files changed without a version increase. Run python3 release/manage.py bump X.Y.Z")
    return current


def bump(root: Path, target: str) -> None:
    values = manifests(root)
    if any(version(target) <= version(value["version"]) for value in values):
        raise ValueError("The new version must be greater than both current plugin versions")
    for path, value in zip(MANIFESTS, values):
        value["version"] = target
        (root / path).write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def check_tag(root: Path, tag: str) -> str:
    if tag.startswith("plugin-v"):
        expected = check(root)
        prefix = "plugin-v"
    elif tag.startswith("chatgpt-v"):
        expected = json.loads((root / "chatgpt/plugin/plugin.json").read_text(encoding="utf-8"))["version"]
        prefix = "chatgpt-v"
    else:
        raise ValueError("Release tags must start with plugin-v or chatgpt-v")
    version(expected)
    if tag != prefix + expected:
        raise ValueError(f"Tag {tag!r} does not match manifest version {expected}")
    return expected


def build(root: Path, tag: str) -> Path:
    """Archive committed Claude/Codex plugin files, not local or ignored files."""
    current = check_tag(root, tag)
    if not tag.startswith("plugin-v"):
        raise ValueError("Use chatgpt/build.py for ChatGPT packages")
    if git(root, "status", "--porcelain", "--", *PLUGIN_PATHS):
        raise ValueError("Build from a clean checkout of the release commit")
    output = root / "release/build"
    output.mkdir(parents=True, exist_ok=True)
    archive = output / f"roboflow-plugin-{current}.zip"
    archive.write_bytes(git(root, "archive", "--format=zip", "HEAD", *PLUGIN_PATHS, "LICENSE"))
    archive.with_suffix(".provenance.json").write_text(json.dumps({
        "package_version": current,
        "skills_commit": git(root, "rev-parse", "HEAD").decode().strip(),
        "package_sha256": hashlib.sha256(archive.read_bytes()).hexdigest(),
    }, indent=2) + "\n", encoding="utf-8")
    return archive


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("check").add_argument("--base")
    commands.add_parser("bump").add_argument("version")
    commands.add_parser("check-tag").add_argument("tag")
    commands.add_parser("build").add_argument("tag")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    try:
        if args.command == "check":
            print(check(root, args.base))
        elif args.command == "bump":
            bump(root, args.version)
        elif args.command == "check-tag":
            print(check_tag(root, args.tag))
        else:
            print(build(root, args.tag))
    except (ValueError, KeyError) as error:
        parser.exit(1, f"{error}\n")
