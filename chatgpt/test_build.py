"""Offline tests: python3 -m unittest discover -s chatgpt -p 'test_*.py'."""

import io
import json
from pathlib import Path
import shutil
import tempfile
import unittest
from unittest.mock import patch
import zipfile

from build import build
import fetch_tools


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

    def test_stale_tool_like_name_only_warns(self):
        path = self.root / "skills/roboflow-universe/SKILL.md"
        path.write_text(path.read_text() + "\nUse `universe_search_v2` and `model_id`.\n")
        archive = build(self.root)
        warnings = json.loads(archive.with_suffix(".provenance.json").read_text())["warnings"]
        self.assertTrue(any("universe_search_v2" in warning for warning in warnings))
        self.assertFalse(any("model_id" in warning for warning in warnings))

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
        path.write_text(text[:start] + 'description: "unterminated' + text[end:])
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

    def test_test_case_tools_must_be_visible(self):
        manifest_path = self.root / "chatgpt/plugin/plugin.json"
        manifest = json.loads(manifest_path.read_text())
        cases = manifest["extensions"]["com.openai"]["review"]["test_cases"]["positive"]
        cases[0]["tools_triggered"] = self.tools["hidden"][0]
        manifest_path.write_text(json.dumps(manifest))
        with self.assertRaisesRegex(ValueError, "not visible on /openai/mcp"):
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


class FakeResponse(io.BytesIO):
    def __enter__(self):
        return self

    def __exit__(self, *exc):
        return False


def reply(result, stream=False, request_id=1):
    body = json.dumps({"jsonrpc": "2.0", "id": request_id, **result})
    return FakeResponse((f"event: message\ndata: {body}\n\n" if stream else body).encode())


class FetchToolsTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.output = Path(self.temp.name) / "tools.json"
        self.output.write_text("previous\n")

    def tools(self, *names, cursor=None):
        result = {"tools": [{"name": name} for name in names]}
        if cursor:
            result["nextCursor"] = cursor
        return {"result": result}

    def test_json_and_event_stream_replies_with_pagination(self):
        replies = [
            reply(self.tools("a_list", "b_get", cursor="page2"), stream=True),
            reply(self.tools("hidden_run")),
            reply(self.tools("a_list", "b_get")),
        ]
        with patch("fetch_tools.urlopen", side_effect=replies) as urlopen:
            payload = fetch_tools.refresh("https://mcp.example.com", "key", self.output)
        self.assertEqual(payload["visible"], ["a_list", "b_get"])
        self.assertEqual(payload["hidden"], ["hidden_run"])
        second_request = json.loads(urlopen.call_args_list[1].args[0].data)
        self.assertEqual(second_request["params"], {"cursor": "page2"})
        self.assertEqual(json.loads(self.output.read_text())["hidden"], ["hidden_run"])

    def test_multiline_event_matches_the_request_id(self):
        body = json.dumps({"jsonrpc": "2.0", "id": 1, **self.tools("a_list")}, indent=1)
        notice = json.dumps({"jsonrpc": "2.0", "method": "notifications/message", "params": {}})
        stream = f"event: message\ndata: {notice}\n\n" + "".join(
            f"data: {line}\n" for line in body.splitlines()) + "\n"
        replies = [FakeResponse(stream.encode()), reply(self.tools("a_list"))]
        with patch("fetch_tools.urlopen", side_effect=replies):
            payload = fetch_tools.refresh("https://mcp.example.com", "key", self.output)
        self.assertEqual(payload["visible"], ["a_list"])

    def test_errors_leave_the_previous_file(self):
        failures = [
            [reply(self.tools("a_list")), reply({"error": {"code": -32000, "message": "nope"}})],
            [reply(self.tools("a_list")), reply({"result": {"unexpected": True}})],
            [reply(self.tools("a_list")), reply({"result": {"tools": [{"name": 123}]}})],
            [OSError("offline")],
        ]
        for side_effect in failures:
            with self.subTest(side_effect=side_effect):
                with patch("fetch_tools.urlopen", side_effect=side_effect):
                    with self.assertRaises((RuntimeError, ValueError, OSError)):
                        fetch_tools.refresh("https://mcp.example.com", "key", self.output)
                self.assertEqual(self.output.read_text(), "previous\n")

    def test_plain_http_server_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "HTTPS"):
            fetch_tools.refresh("http://mcp.example.com", "key", self.output)


if __name__ == "__main__":
    unittest.main()
