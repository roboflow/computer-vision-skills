"""Build the Cowork ZIP with a pinned public catalog and Python standard library."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import shutil
import tempfile
import zipfile
from urllib.request import urlopen

from validate import validate


def build(root: Path, catalog_path: Path | None = None) -> Path:
    source = root / "cowork"
    output = source / "build"
    # Validate before touching the last successful build.
    pin = json.loads((source / "catalog.json").read_text(encoding="utf-8"))
    if catalog_path is None:
        if not pin["url"].startswith("https://"):
            raise ValueError("Catalog download must use HTTPS")
        with urlopen(pin["url"], timeout=60) as response:
            catalog = response.read()
    else:
        catalog = catalog_path.read_bytes()
    if hashlib.sha256(catalog).hexdigest() != pin["sha256"]:
        raise ValueError("Tool catalog SHA-256 does not match catalog.json")
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
        tools = package / "tools"
        tools.mkdir(exist_ok=True)
        (tools / "roboflow-tools.json").write_bytes(catalog)
        validate(package, package)
        archive = staging / "roboflow-cowork.zip"
        with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as bundle:
            for path in sorted(package.rglob("*")):
                if path.is_file():
                    bundle.write(path, path.relative_to(package).as_posix())
        provenance = staging / "roboflow-cowork.provenance.json"
        provenance.write_text(json.dumps({
            "package_version": manifest["version"],
            "mcp_commit": pin["mcp_commit"],
            "tool_catalog_sha256": pin["sha256"],
            "package_sha256": hashlib.sha256(archive.read_bytes()).hexdigest(),
        }, indent=2) + "\n", encoding="utf-8")
        archive.replace(output / archive.name)
        provenance.replace(output / provenance.name)
    result = output / "roboflow-cowork.zip"
    print(f"Built {result}")
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tool-catalog", type=Path,
                        help="Use a downloaded catalog offline; its pinned SHA-256 is still checked")
    args = parser.parse_args()
    build(Path(__file__).resolve().parents[1], args.tool_catalog)
