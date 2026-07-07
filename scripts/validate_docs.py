#!/usr/bin/env python3
"""Repository documentation validator.

Runs cheap structural checks that catch the classes of bug found in review:

  * relative markdown links under ``skills/`` resolve to a real file
  * every ``skills/*/SKILL.md`` has ``name`` + ``description`` frontmatter
  * SKILL frontmatter ``name`` values are unique
  * non-SKILL pages under ``skills/`` carry no YAML frontmatter (only SKILL.md
    defines a skill)

Exit code is non-zero when any check fails; every failure is printed. Run from
the repo root:

    python scripts/validate_docs.py
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
SKILLS_DIR = REPO_ROOT / "skills"

# [text](target) — capture the target. Skips images by requiring no leading '!'
# is handled separately; here we just grab every link and filter targets below.
LINK_RE = re.compile(r"(?<!\!)\[[^\]]*\]\(([^)]+)\)")


def _iter_markdown() -> list[Path]:
    return sorted(SKILLS_DIR.rglob("*.md"))


def _has_frontmatter(text: str) -> bool:
    return text.startswith("---\n") or text.startswith("---\r\n")


def _frontmatter_block(text: str) -> str | None:
    if not _has_frontmatter(text):
        return None
    end = text.find("\n---", 3)
    if end == -1:
        return None
    return text[3:end]


def check_links(errors: list[str]) -> None:
    for md in _iter_markdown():
        text = md.read_text(encoding="utf-8")
        for target in LINK_RE.findall(text):
            target = target.strip()
            # Skip external, anchor-only, mailto, and template-y targets.
            if (
                target.startswith(("http://", "https://", "#", "mailto:"))
                or target.startswith("roboflow://")
                or "{" in target
            ):
                continue
            path_part = target.split("#", 1)[0]
            if not path_part:
                continue
            resolved = (md.parent / path_part).resolve()
            if not resolved.exists():
                errors.append(f"{md.relative_to(REPO_ROOT)}: broken link -> {target}")


def check_frontmatter(errors: list[str]) -> None:
    names: dict[str, Path] = {}
    for md in _iter_markdown():
        text = md.read_text(encoding="utf-8")
        block = _frontmatter_block(text)
        is_skill = md.name == "SKILL.md"

        if is_skill:
            if block is None:
                errors.append(
                    f"{md.relative_to(REPO_ROOT)}: SKILL.md missing YAML frontmatter"
                )
                continue
            name_match = re.search(r"^name:\s*(.+)$", block, re.MULTILINE)
            if not name_match:
                errors.append(f"{md.relative_to(REPO_ROOT)}: frontmatter missing 'name'")
            else:
                name = name_match.group(1).strip()
                if name in names:
                    errors.append(
                        f"{md.relative_to(REPO_ROOT)}: duplicate skill name "
                        f"'{name}' (also in {names[name].relative_to(REPO_ROOT)})"
                    )
                names[name] = md
            if not re.search(r"^description:\s*\S", block, re.MULTILINE):
                errors.append(
                    f"{md.relative_to(REPO_ROOT)}: frontmatter missing 'description'"
                )
        else:
            if block is not None:
                errors.append(
                    f"{md.relative_to(REPO_ROOT)}: non-SKILL page must not carry "
                    "YAML frontmatter (only SKILL.md defines a skill)"
                )


def main() -> int:
    if not SKILLS_DIR.is_dir():
        print(f"skills/ not found under {REPO_ROOT}", file=sys.stderr)
        return 2
    errors: list[str] = []
    check_links(errors)
    check_frontmatter(errors)
    if errors:
        print("Documentation validation failed:\n", file=sys.stderr)
        for err in errors:
            print(f"  - {err}", file=sys.stderr)
        print(f"\n{len(errors)} problem(s).", file=sys.stderr)
        return 1
    print("Documentation validation passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
