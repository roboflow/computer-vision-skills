"""Offline tests: python3 -m unittest discover -s chatgpt -p 'test_*.py'."""

import json
from pathlib import Path
import re
import shutil
import tempfile
import unittest
import zipfile

from build import build


class BuildTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        source = Path(__file__).resolve().parents[1]
        shutil.copytree(source / "chatgpt", self.root / "chatgpt",
                        ignore=shutil.ignore_patterns("build", "__pycache__"))
        shutil.copytree(source / "skills", self.root / "skills")
        self.tools = json.loads((self.root / "chatgpt/tools.json").read_text())

    def write(self, relative, text):
        path = self.root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")

    def skill_files(self, archive):
        with zipfile.ZipFile(archive) as bundle:
            return {name: bundle.read(name) for name in bundle.namelist()}

    def test_overrides_win_and_supporting_files_are_copied(self):
        files = self.skill_files(build(self.root))
        overridden = "skills/roboflow-inference/workflows.md"
        self.assertEqual(files[overridden], (self.root / "chatgpt" / overridden).read_bytes())
        default = "skills/roboflow-universe/SKILL.md"
        self.assertEqual(files[default], (self.root / default).read_bytes())
        script = "skills/roboflow-inference/bin/poll_batch_job.py"
        self.assertEqual(files[script], (self.root / script).read_bytes())
        for name in ("plugin.json", "mcp.json"):
            self.assertIn(name, files)

    def test_excluded_skills_are_left_out(self):
        files = self.skill_files(build(self.root))
        self.assertFalse(any(name.startswith("skills/workflow-from-eval/") for name in files))

    def test_all_source_skill_links_are_canonical_and_resolve(self):
        for tree in (self.root / "skills", self.root / "chatgpt/skills"):
            for path in tree.rglob("*.md"):
                text = path.read_text(encoding="utf-8")
                self.assertNotIn("roboflow://skills/", text, str(path))
                for uri in re.findall(r"skill://roboflow/[A-Za-z0-9_./-]+", text):
                    target = self.root / "skills" / uri.removeprefix("skill://roboflow/")
                    self.assertTrue(target.is_file(), f"{path}: {uri}")

    def test_old_skill_uri_fails(self):
        path = self.root / "skills/roboflow-universe/SKILL.md"
        path.write_text(path.read_text() + "\nRead `roboflow://skills/roboflow-inference/SKILL`.\n")
        with self.assertRaisesRegex(ValueError, "old skill address"):
            build(self.root)

    def test_canonical_uri_to_missing_or_excluded_file_fails(self):
        path = self.root / "skills/roboflow-universe/SKILL.md"
        original = path.read_text()
        for target in ("does-not-exist/SKILL.md", "workflow-from-eval/SKILL.md"):
            with self.subTest(target=target):
                path.write_text(original + f"\nRead `skill://roboflow/{target}`.\n")
                with self.assertRaisesRegex(ValueError, "not in the package"):
                    build(self.root)

    def test_windows_line_endings_still_parse(self):
        for path in (self.root / "skills").rglob("*.md"):
            path.write_bytes(path.read_bytes().replace(b"\r\n", b"\n").replace(b"\n", b"\r\n"))
        build(self.root)

    def test_hidden_tool_name_fails(self):
        hidden = self.tools["hidden"][0]
        path = self.root / "skills/roboflow-universe/SKILL.md"
        path.write_text(path.read_text() + f"\nCall `{hidden}` first.\n")
        with self.assertRaisesRegex(ValueError, f"names {hidden}"):
            build(self.root)

    def test_hidden_tool_name_in_any_file_type_fails(self):
        hidden = self.tools["hidden"][0]
        self.write("skills/roboflow-universe/helper.js", f"call('{hidden}')\n")
        with self.assertRaisesRegex(ValueError, f"helper.js:1 names {hidden}"):
            build(self.root)

    def test_hidden_name_inside_a_longer_identifier_is_not_flagged(self):
        hidden = self.tools["hidden"][0]
        path = self.root / "skills/roboflow-universe/SKILL.md"
        path.write_text(path.read_text() + f"\nSee `my_{hidden}_helper`.\n")
        build(self.root)

    def test_orphan_override_fails(self):
        self.write("chatgpt/skills/roboflow-universe/missing.md", "Nothing to replace.\n")
        with self.assertRaisesRegex(ValueError, "doesn't have"):
            build(self.root)

    def test_override_of_excluded_skill_fails(self):
        self.write("chatgpt/skills/workflow-from-eval/SKILL.md", "---\nname: x\n---\n")
        with self.assertRaisesRegex(ValueError, "excluded skill"):
            build(self.root)

    def test_unknown_exclusion_fails(self):
        self.write("chatgpt/exclude.txt", "workflow-from-eval\nnot-a-skill\n")
        with self.assertRaisesRegex(ValueError, "not-a-skill"):
            build(self.root)

    def test_link_into_excluded_skill_fails(self):
        path = self.root / "skills/roboflow-universe/SKILL.md"
        path.write_text(path.read_text() + "\nSee [evals](../workflow-from-eval/SKILL.md).\n")
        with self.assertRaisesRegex(ValueError, "not in the package"):
            build(self.root)

    def test_reference_link_into_excluded_skill_fails(self):
        path = self.root / "skills/roboflow-universe/SKILL.md"
        path.write_text(path.read_text() + "\nSee [evals][ref].\n\n[ref]: ../workflow-from-eval/SKILL.md\n")
        with self.assertRaisesRegex(ValueError, "not in the package"):
            build(self.root)

    def test_malformed_frontmatter_fails(self):
        path = self.root / "skills/roboflow-universe/SKILL.md"
        text = path.read_text()
        start = text.index("description:")
        end = text.index("\n", start)
        for invalid in ('"unterminated', "foo: bar", "- item", "# comment"):
            with self.subTest(invalid=invalid):
                path.write_text(text[:start] + f"description: {invalid}" + text[end:])
                with self.assertRaisesRegex(ValueError, "frontmatter"):
                    build(self.root)

    def test_skill_name_must_match_folder(self):
        path = self.root / "skills/roboflow-universe/SKILL.md"
        path.write_text(path.read_text().replace("name: roboflow-universe", "name: universe", 1))
        with self.assertRaisesRegex(ValueError, "must match its folder"):
            build(self.root)

    def test_listing_limits_are_enforced(self):
        manifest_path = self.root / "chatgpt/plugin/plugin.json"
        manifest = json.loads(manifest_path.read_text())
        interface = manifest["extensions"]["com.openai"]["interface"]
        interface["shortDescription"] = "x" * 31
        interface["defaultPrompt"] = ["one", "two", "three", "four"]
        interface["brandColorDark"] = "#222222"
        manifest_path.write_text(json.dumps(manifest))
        with self.assertRaises(ValueError) as raised:
            build(self.root)
        message = str(raised.exception)
        self.assertIn("shortDescription", message)
        self.assertIn("defaultPrompt", message)
        self.assertIn("brandColorDark", message)

    def test_test_case_tools_must_not_be_hidden(self):
        manifest_path = self.root / "chatgpt/plugin/plugin.json"
        manifest = json.loads(manifest_path.read_text())
        cases = manifest["extensions"]["com.openai"]["review"]["test_cases"]["positive"]
        cases[0]["tools_triggered"] = self.tools["hidden"][0]
        manifest_path.write_text(json.dumps(manifest))
        with self.assertRaisesRegex(ValueError, "hidden on /openai/mcp"):
            build(self.root)

    def test_failure_keeps_previous_outputs(self):
        archive = build(self.root)
        provenance = archive.with_suffix(".provenance.json")
        original, original_provenance = archive.read_bytes(), provenance.read_bytes()
        self.write("chatgpt/skills/roboflow-universe/missing.md", "Nothing to replace.\n")
        with self.assertRaises(ValueError):
            build(self.root)
        self.assertEqual(archive.read_bytes(), original)
        self.assertEqual(provenance.read_bytes(), original_provenance)


if __name__ == "__main__":
    unittest.main()
