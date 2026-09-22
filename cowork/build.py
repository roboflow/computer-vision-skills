"""Build the Cowork ZIP offline using only Python's standard library."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
import shutil
import tempfile
import zipfile

from validate import validate


def build(root: Path) -> Path:
    source = root / "cowork"
    output = source / "build"
    # Validate before touching the last successful build.
    validate(source / "appPackage", root)
    output.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(dir=output) as temp:
        staging = Path(temp)
        package = staging / "package"
        shutil.copytree(source / "appPackage", package)
        manifest = json.loads((package / "manifest.json").read_text(encoding="utf-8"))
        for skill in manifest["agentSkills"]:
            relative = skill["folder"].removeprefix("./")
            shutil.copytree(root / relative, package / relative,
                            ignore=shutil.ignore_patterns("__pycache__", "*.pyc"))
        # Microsoft v1.28 still requires this file reference although Cowork
        # ignores its contents and discovers tools from the authenticated server.
        tools = package / "tools"
        tools.mkdir(exist_ok=True)
        (tools / "roboflow-tools.json").write_text('{"tools": []}\n', encoding="utf-8")
        validate(package, package)
        archive = staging / "roboflow-cowork.zip"
        with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as bundle:
            for path in sorted(package.rglob("*")):
                if path.is_file():
                    bundle.write(path, path.relative_to(package).as_posix())
        provenance = staging / "roboflow-cowork.provenance.json"
        provenance.write_text(json.dumps({
            "package_version": manifest["version"],
            "tool_discovery": "live",
            "package_sha256": hashlib.sha256(archive.read_bytes()).hexdigest(),
        }, indent=2) + "\n", encoding="utf-8")
        archive.replace(output / archive.name)
        provenance.replace(output / provenance.name)
    result = output / "roboflow-cowork.zip"
    print(f"Built {result}")
    return result


if __name__ == "__main__":
    build(Path(__file__).resolve().parents[1])
