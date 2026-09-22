"""Offline regressions for fail-closed package generation.

Run with: python3 -m unittest discover -s cowork -p 'test_*.py'
"""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


class BuildFailureTests(unittest.TestCase):
    def test_failures_do_not_package_or_replace_previous_outputs(self):
        for failure in ("fetch", "export", "validation"):
            with self.subTest(failure=failure), tempfile.TemporaryDirectory() as temp:
                root = Path(temp)
                source = Path(__file__).resolve().parent
                cowork = root / "cowork"
                shutil.copytree(source, cowork, ignore=shutil.ignore_patterns("build", "__pycache__"))
                (cowork / "mcp-revision.txt").write_text("a" * 40 + "\n")
                output = cowork / "build"
                output.mkdir()
                previous = output / "roboflow-cowork.zip"
                previous.write_bytes(b"previous successful build")
                provenance = output / "roboflow-cowork.provenance.json"
                provenance.write_text("previous provenance")
                commands = root / "bin"
                commands.mkdir()
                log = root / "commands.log"
                stubs = {
                    "git": '''#!/usr/bin/env python3
import os, pathlib, sys
args = sys.argv[1:]
if args[0] == "init":
    pathlib.Path(args[-1]).mkdir()
if "fetch" in args and os.environ["FAILURE"] == "fetch":
    sys.exit(1)
if "rev-parse" in args:
    print("a" * 40)
''',
                    "uv": '''#!/usr/bin/env python3
import os, pathlib, sys
if "run" in sys.argv:
    if os.environ["FAILURE"] == "export":
        sys.exit(1)
    pathlib.Path(sys.argv[-1]).write_text('{"tools": []}')
''',
                    "npx": '''#!/usr/bin/env python3
import os, pathlib, shutil, sys
args = sys.argv[1:]
with open(os.environ["COMMAND_LOG"], "a") as log:
    log.write(" ".join(args) + "\\n")
if "import" in args:
    destination = pathlib.Path(args[args.index("--output") + 1]) / "appPackage"
    destination.mkdir(parents=True)
if "package" in args:
    sys.exit("packaging must not run after generation failure")
''',
                }
                for name, script in stubs.items():
                    path = commands / name
                    path.write_text(script)
                    path.chmod(0o755)
                result = subprocess.run(
                    ["bash", str(cowork / "build.sh")],
                    env={**os.environ, "PATH": f"{commands}:{os.environ['PATH']}",
                         "FAILURE": failure, "COMMAND_LOG": str(log)},
                    capture_output=True, text=True,
                )
                self.assertNotEqual(result.returncode, 0, result.stdout)
                self.assertEqual(previous.read_bytes(), b"previous successful build")
                self.assertEqual(provenance.read_text(), "previous provenance")
                self.assertNotIn("atk package", log.read_text() if log.exists() else "")
                if failure == "validation":
                    self.assertIn("must contain at least one tool", result.stderr)
                else:
                    self.assertFalse(log.exists(), "importer ran after fetch/export failed")


if __name__ == "__main__":
    unittest.main()
