"""Validate every skill folder: frontmatter, size limits, relative links, and generated references.

Run from the repository root: python3 .github/scripts/validate_skills.py
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SKILLS = ROOT / "skills"

# Limits Microsoft Copilot Cowork enforces on uploaded skills (see cowork/validate.py).
MAX_SKILL_CHARS = 20_000
MAX_DESCRIPTION_CHARS = 1024
MAX_COMPANION_FILES = 20

REFERENCE_DIR = "reference"
REFERENCE_MANIFEST = "manifest.json"
REFERENCE_SCHEMA_VERSION = "roboflow-workflow-evals/reference/v1"
SEMVER = re.compile(r"^\d+\.\d+\.\d+$")
MARKDOWN_LINK = re.compile(r"\[[^\]]*\]\(([^)\s]+)\)")
EXTERNAL_LINK = re.compile(r"^(?:[a-z][a-z0-9+.-]*:|#)", re.IGNORECASE)


def ignored(path: Path) -> bool:
    """Build and OS leftovers that packaging skips."""
    return "__pycache__" in path.parts or path.suffix == ".pyc" or path.name == ".DS_Store"


def shown(path: Path) -> str:
    try:
        return path.relative_to(ROOT).as_posix()
    except ValueError:
        return path.as_posix()


def frontmatter(text: str) -> dict[str, str]:
    """Read single-line `key: value` pairs from a leading `---` block."""
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        return {}
    values: dict[str, str] = {}
    for line in lines[1:]:
        if line.strip() == "---":
            return values
        key, separator, value = line.partition(":")
        if separator:
            values[key.strip()] = value.strip()
    return {}


def companion_files(folder: Path) -> list[Path]:
    return sorted(
        path
        for path in folder.rglob("*")
        if path.is_file() and path.name != "SKILL.md" and not ignored(path)
    )


def broken_links(markdown: Path) -> list[str]:
    errors = []
    for target in MARKDOWN_LINK.findall(markdown.read_text(encoding="utf-8")):
        if EXTERNAL_LINK.match(target):
            continue
        relative = target.split("#", 1)[0]
        if relative and not (markdown.parent / relative).exists():
            errors.append(f"{shown(markdown)}: broken link {target}")
    return errors


def validate_reference(reference: Path) -> list[str]:
    """A generated reference lists every file it ships and nothing else."""
    where = shown(reference)
    try:
        manifest = json.loads((reference / REFERENCE_MANIFEST).read_text(encoding="utf-8"))
    except (OSError, ValueError) as error:
        return [f"{where}/{REFERENCE_MANIFEST}: unreadable ({error})"]
    errors = []
    if manifest.get("schemaVersion") != REFERENCE_SCHEMA_VERSION:
        errors.append(f"{where}: schemaVersion must be {REFERENCE_SCHEMA_VERSION}")
    version = str(manifest.get("engineVersion", ""))
    if not SEMVER.match(version):
        errors.append(f"{where}: engineVersion {version!r} is not MAJOR.MINOR.PATCH")
    if manifest.get("source", {}).get("tag") != f"engine-v{version}":
        errors.append(f"{where}: source.tag must be engine-v{version}")

    assets = manifest.get("assets", [])
    ids = [asset.get("id") for asset in assets]
    paths = [asset.get("path") for asset in assets]
    if len(set(ids)) != len(ids) or len(set(paths)) != len(paths):
        errors.append(f"{where}: asset ids and paths must be unique")
    declared = {REFERENCE_MANIFEST, *paths}
    shipped = {path.relative_to(reference).as_posix() for path in companion_files(reference)}
    for missing in sorted(declared - shipped):
        errors.append(f"{where}: declared asset {missing} is missing")
    for extra in sorted(shipped - declared):
        errors.append(f"{where}: {extra} is not declared in {REFERENCE_MANIFEST}")
    for path in sorted(shipped & declared):
        if path.endswith(".json"):
            try:
                json.loads((reference / path).read_text(encoding="utf-8"))
            except ValueError as error:
                errors.append(f"{where}/{path}: invalid JSON ({error})")
    return errors


def validate_skill(folder: Path) -> list[str]:
    where = shown(folder)
    skill_file = folder / "SKILL.md"
    if not skill_file.is_file():
        return [f"{where}: SKILL.md is missing"]
    text = skill_file.read_text(encoding="utf-8")
    meta = frontmatter(text)
    errors = []
    if meta.get("name") != folder.name:
        errors.append(f"{where}: frontmatter name {meta.get('name')!r} must match the folder")
    if not 1 <= len(meta.get("description", "")) <= MAX_DESCRIPTION_CHARS:
        errors.append(f"{where}: description must be 1-{MAX_DESCRIPTION_CHARS} characters")
    if len(text) > MAX_SKILL_CHARS:
        errors.append(f"{where}: SKILL.md has {len(text)} characters; limit {MAX_SKILL_CHARS}")
    companions = companion_files(folder)
    if len(companions) > MAX_COMPANION_FILES:
        errors.append(
            f"{where}: {len(companions)} companion files; the limit is {MAX_COMPANION_FILES}"
        )
    errors.extend(
        f"{shown(path)}: a nested SKILL.md loads as a separate skill"
        for path in folder.rglob("SKILL.md")
        if path != skill_file
    )
    for markdown in [skill_file, *(path for path in companions if path.suffix == ".md")]:
        errors.extend(broken_links(markdown))
    if (folder / REFERENCE_DIR / REFERENCE_MANIFEST).is_file():
        errors.extend(validate_reference(folder / REFERENCE_DIR))
    return errors


def validate(skills: Path = SKILLS) -> list[str]:
    folders = sorted(folder for folder in skills.iterdir() if folder.is_dir())
    return [error for folder in folders for error in validate_skill(folder)]


def main() -> int:
    errors = validate()
    for error in errors:
        print(f"::error::{error}")
    if errors:
        return 1
    count = sum(1 for folder in SKILLS.iterdir() if folder.is_dir())
    print(f"{count} skills are valid.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
