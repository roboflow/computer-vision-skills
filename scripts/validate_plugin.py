#!/usr/bin/env python3
"""Validate the Roboflow agent plugin repository.

Checks structural guarantees that are easy to regress in a Markdown-heavy
plugin: JSON syntax, screenshot assets, install docs, concrete skill links,
installer placeholders, pricing dollar amounts, and executable script claims.
"""

from __future__ import annotations

import json
import os
import re
import stat
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]

JSON_FILES = (
    ".codex-plugin/plugin.json",
    ".claude-plugin/plugin.json",
    ".mcp.json",
    ".agents/plugins/marketplace.json",
    ".claude-plugin/marketplace.json",
)

TEXT_GLOBS = (
    "README.md",
    "skills/**/*.md",
    "agent-install/*",
)

SKILL_REF_RE = re.compile(r"roboflow://skills/([A-Za-z0-9_./-]+)")


def _read_json(path: Path, errors: list[str]) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:  # noqa: BLE001 - validation reports all parse failures.
        errors.append(f"{path.relative_to(ROOT)} is not valid JSON: {exc}")
        return None


def _iter_text_files() -> list[Path]:
    files: list[Path] = []
    for pattern in TEXT_GLOBS:
        files.extend(ROOT.glob(pattern))
    return [path for path in files if path.is_file()]


def _skill_ref_exists(ref: str) -> bool:
    if ref.endswith("/SKILL"):
        return (ROOT / "skills" / f"{ref}.md").is_file()
    return any(
        candidate.is_file()
        for candidate in (
            ROOT / "skills" / f"{ref}.md",
            ROOT / "skills" / ref / "SKILL.md",
            ROOT / "skills" / ref,
        )
    )


def validate_json(errors: list[str]) -> None:
    for relative in JSON_FILES:
        path = ROOT / relative
        if not path.is_file():
            errors.append(f"{relative} is missing")
            continue
        _read_json(path, errors)


def validate_codex_manifest(errors: list[str]) -> None:
    manifest = _read_json(ROOT / ".codex-plugin/plugin.json", errors)
    if not isinstance(manifest, dict):
        return
    interface = manifest.get("interface")
    if not isinstance(interface, dict):
        errors.append(".codex-plugin/plugin.json interface must be an object")
        return
    screenshots = interface.get("screenshots", [])
    if not isinstance(screenshots, list):
        errors.append(".codex-plugin/plugin.json interface.screenshots must be a list")
        return
    if not screenshots:
        errors.append(".codex-plugin/plugin.json interface.screenshots must not be empty")
    for raw_path in screenshots:
        if not isinstance(raw_path, str):
            errors.append("screenshot entries must be string paths")
            continue
        if not (ROOT / raw_path).is_file():
            errors.append(f"screenshot asset does not exist: {raw_path}")


def validate_readme(errors: list[str]) -> None:
    readme = (ROOT / "README.md").read_text(encoding="utf-8")
    if "codex plugin add roboflow@roboflow" not in readme:
        errors.append("README.md must document `codex plugin add roboflow@roboflow`")
    if "python scripts/validate_plugin.py" not in readme:
        errors.append("README.md must document the structural validator")


def validate_pricing(errors: list[str]) -> None:
    pricing = (ROOT / "skills/plans-and-pricing/SKILL.md").read_text(encoding="utf-8")
    if re.search(r"\$\d", pricing):
        errors.append("plans-and-pricing must not embed dollar amounts")


def validate_skill_refs(errors: list[str]) -> None:
    for path in _iter_text_files():
        text = path.read_text(encoding="utf-8")
        for match in SKILL_REF_RE.finditer(text):
            ref = match.group(1)
            if ref == "..." or ref.startswith("."):
                continue
            if not _skill_ref_exists(ref):
                errors.append(
                    f"{path.relative_to(ROOT)} references missing skill resource: {ref}"
                )


def validate_installers(errors: list[str]) -> None:
    for path in (ROOT / "agent-install").glob("*"):
        if not path.is_file():
            continue
        text = path.read_text(encoding="utf-8").lower()
        if "todo" in text or "placeholder" in text:
            errors.append(f"{path.relative_to(ROOT)} still contains placeholder text")


def validate_executable_claims(errors: list[str]) -> None:
    poller = ROOT / "skills/inference/bin/poll_batch_job.py"
    text = poller.read_text(encoding="utf-8")
    executable = bool(poller.stat().st_mode & stat.S_IXUSR)
    if "directly executable" in text and not executable:
        errors.append("poll_batch_job.py claims direct execution but is not executable")


def main() -> int:
    """Run plugin validation and return a process exit code."""
    os.chdir(ROOT)
    errors: list[str] = []
    validate_json(errors)
    validate_codex_manifest(errors)
    validate_readme(errors)
    validate_pricing(errors)
    validate_skill_refs(errors)
    validate_installers(errors)
    validate_executable_claims(errors)

    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1

    print("plugin validation passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
