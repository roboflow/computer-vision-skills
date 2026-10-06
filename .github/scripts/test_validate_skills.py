"""Tests for validate_skills.py. Run: python3 -m unittest discover -s .github/scripts"""

from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

import validate_skills


def write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def skill_md(name: str, body: str = "See [the guide](guide.md).\n") -> str:
    return f"---\nname: {name}\ndescription: Use when testing.\n---\n\n# Test\n\n{body}"


def reference_manifest(version: str = "1.2.3", assets: list[dict] | None = None) -> str:
    return json.dumps(
        {
            "schemaVersion": validate_skills.REFERENCE_SCHEMA_VERSION,
            "engineVersion": version,
            "source": {"repository": "roboflow/workflow-evals", "tag": f"engine-v{version}"},
            "assets": assets if assets is not None else [
                {"id": "resource:engine-catalogs", "kind": "resource", "path": "catalogs.json"}
            ],
        }
    )


class ValidateSkillTest(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.skills = Path(self.tmp.name) / "skills"
        self.folder = self.skills / "roboflow-demo"
        write(self.folder / "SKILL.md", skill_md("roboflow-demo"))
        write(self.folder / "guide.md", "# Guide\n")

    def tearDown(self) -> None:
        self.tmp.cleanup()

    def errors(self) -> list[str]:
        return validate_skills.validate(self.skills)

    def test_the_repository_skills_are_valid(self) -> None:
        self.assertEqual(validate_skills.validate(), [])

    def test_a_minimal_skill_is_valid(self) -> None:
        self.assertEqual(self.errors(), [])

    def test_name_must_match_folder(self) -> None:
        write(self.folder / "SKILL.md", skill_md("other-name"))
        self.assertIn("must match the folder", "\n".join(self.errors()))

    def test_size_and_companion_limits(self) -> None:
        write(self.folder / "SKILL.md", skill_md("roboflow-demo", "x" * 20_001))
        for index in range(21):
            write(self.folder / f"extra-{index}.md", "extra\n")
        errors = "\n".join(self.errors())
        self.assertIn("limit 20000", errors)
        self.assertIn("22 companion files", errors)  # guide.md plus 21 extras

    def test_broken_relative_links_fail_and_external_links_pass(self) -> None:
        write(
            self.folder / "SKILL.md",
            skill_md("roboflow-demo", "[x](missing.md) [y](https://example.com) [z](#top)\n"),
        )
        self.assertEqual(len(self.errors()), 1)
        self.assertIn("broken link missing.md", self.errors()[0])

    def test_nested_skill_files_fail(self) -> None:
        write(self.folder / "reference" / "procedures" / "SKILL.md", "# nested\n")
        self.assertIn("loads as a separate skill", "\n".join(self.errors()))

    def test_reference_must_declare_exactly_what_it_ships(self) -> None:
        reference = self.folder / "reference"
        write(reference / "manifest.json", reference_manifest())
        write(reference / "catalogs.json", "{}")
        self.assertEqual(self.errors(), [])

        write(reference / "stray.json", "{}")
        (reference / "catalogs.json").unlink()
        errors = "\n".join(self.errors())
        self.assertIn("declared asset catalogs.json is missing", errors)
        self.assertIn("stray.json is not declared", errors)

    def test_reference_version_and_json_are_checked(self) -> None:
        reference = self.folder / "reference"
        write(reference / "manifest.json", reference_manifest(version="1.2"))
        write(reference / "catalogs.json", "{not json")
        errors = "\n".join(self.errors())
        self.assertIn("is not MAJOR.MINOR.PATCH", errors)
        self.assertIn("catalogs.json: invalid JSON", errors)


if __name__ == "__main__":
    unittest.main()
