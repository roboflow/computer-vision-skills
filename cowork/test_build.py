"""Offline build regressions: python3 -m unittest discover -s cowork -p 'test_*.py'."""

import hashlib
import json
from pathlib import Path
import shutil
import tempfile
import unittest
from unittest.mock import patch
import zipfile

from build import build


class BuildTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        source = Path(__file__).resolve().parents[1]
        shutil.copytree(source / "cowork", self.root / "cowork",
                        ignore=shutil.ignore_patterns("build", "__pycache__"))
        shutil.copytree(source / "skills", self.root / "skills")

    def test_build_offline_with_windows_line_endings(self):
        # No checkout, git credentials, revision file, npm, or uv is available.
        for path in self.root.rglob("*.md"):
            path.write_bytes(path.read_bytes().replace(b"\r\n", b"\n").replace(b"\n", b"\r\n"))
        with patch("subprocess.run", side_effect=AssertionError("external process")):
            archive = build(self.root)
        with zipfile.ZipFile(archive) as bundle:
            self.assertIsNone(bundle.testzip())
            manifest = json.loads(bundle.read("manifest.json"))
            remote = manifest["agentConnectors"][0]["toolSource"]["remoteMcpServer"]
            self.assertEqual(remote["mcpServerUrl"], "https://mcp.roboflow.com/mcp")
            self.assertNotIn("authorization", remote)
            self.assertEqual(json.loads(bundle.read("tools/roboflow-tools.json")), {"tools": []})
            for skill in manifest["agentSkills"]:
                self.assertIn(skill["folder"].removeprefix("./") + "/SKILL.md", bundle.namelist())
        metadata = json.loads(archive.with_suffix(".provenance.json").read_text())
        self.assertEqual(metadata["package_sha256"], hashlib.sha256(archive.read_bytes()).hexdigest())

    def test_archive_failure_preserves_previous_outputs(self):
        archive = build(self.root)
        original = archive.read_bytes()
        provenance = archive.with_suffix(".provenance.json")
        original_provenance = provenance.read_bytes()
        with patch("zipfile.ZipFile.write", side_effect=OSError("disk failure")):
            with self.assertRaises(OSError):
                build(self.root)
        self.assertEqual(archive.read_bytes(), original)
        self.assertEqual(provenance.read_bytes(), original_provenance)

    def test_invalid_package_preserves_previous_outputs(self):
        for invalid in ("authorization", "mcpToolDescription", "skill"):
            with self.subTest(invalid=invalid):
                output = self.root / "cowork/build"
                output.mkdir(exist_ok=True)
                archive = output / "roboflow-cowork.zip"
                provenance = output / "roboflow-cowork.provenance.json"
                archive.write_bytes(b"previous ZIP")
                provenance.write_text("previous provenance")
                manifest_path = self.root / "cowork/appPackage/manifest.json"
                original = manifest_path.read_text()
                manifest = json.loads(original)
                if invalid == "skill":
                    manifest["agentSkills"][0]["folder"] = "./skills/missing"
                else:
                    manifest["agentConnectors"][0]["toolSource"]["remoteMcpServer"][invalid] = {}
                manifest_path.write_text(json.dumps(manifest))
                try:
                    with self.assertRaises((ValueError, OSError)):
                        build(self.root)
                    self.assertEqual(archive.read_bytes(), b"previous ZIP")
                    self.assertEqual(provenance.read_text(), "previous provenance")
                finally:
                    manifest_path.write_text(original)


if __name__ == "__main__":
    unittest.main()
