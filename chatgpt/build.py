"""Build the ChatGPT plugin ZIP: default skills, the ChatGPT overrides, minus excluded skills."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import tempfile
import zipfile

from validate import validate

IGNORED = shutil.ignore_patterns("__pycache__", "*.pyc", ".DS_Store")


def read_exclusions(source: Path) -> list[str]:
    lines = (source / "exclude.txt").read_text(encoding="utf-8").splitlines()
    return [line.strip() for line in lines if line.strip() and not line.lstrip().startswith("#")]


def assemble(root: Path, package: Path) -> None:
    """Lay out plugin.json, mcp.json, assets/ and skills/ in `package`."""
    source = root / "chatgpt"
    defaults = root / "skills"
    excluded = read_exclusions(source)
    for name in excluded:
        if not (defaults / name / "SKILL.md").is_file():
            raise ValueError(f"exclude.txt names {name}, which is not a skill in skills/")
    shutil.copytree(source / "plugin", package, ignore=IGNORED)
    skills = package / "skills"
    skills.mkdir()
    for folder in sorted(defaults.iterdir()):
        if folder.is_dir() and folder.name not in excluded:
            shutil.copytree(folder, skills / folder.name, ignore=IGNORED)
    overrides = source / "skills"
    for override in sorted(overrides.rglob("*")) if overrides.is_dir() else []:
        if not override.is_file() or override.name == ".DS_Store":
            continue
        relative = override.relative_to(overrides)
        if not (defaults / relative).is_file():
            raise ValueError(f"chatgpt/skills/{relative.as_posix()} overrides a file that skills/ doesn't have")
        if relative.parts[0] in excluded:
            raise ValueError(f"chatgpt/skills/{relative.as_posix()} overrides an excluded skill")
        shutil.copy2(override, skills / relative)


def build(root: Path, commit: str | None = None) -> Path:
    source = root / "chatgpt"
    output = source / "build"
    tools = json.loads((source / "tools.json").read_text(encoding="utf-8"))
    version = json.loads((source / "plugin" / "plugin.json").read_text(encoding="utf-8"))["version"]
    output.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(dir=output) as temp:
        staging = Path(temp)
        package = staging / "package"
        assemble(root, package)
        warnings = validate(package, tools)
        name = f"roboflow-chatgpt-{version}"
        archive = staging / f"{name}.zip"
        with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as bundle:
            for path in sorted(package.rglob("*")):
                if path.is_file():
                    bundle.write(path, path.relative_to(package).as_posix())
        provenance = staging / f"{name}.provenance.json"
        provenance.write_text(json.dumps({
            "package_version": version,
            "skills_commit": commit,
            "tools_server": tools["server"],
            "tools_fetched_at": tools["fetched_at"],
            "package_sha256": hashlib.sha256(archive.read_bytes()).hexdigest(),
            "warnings": warnings,
        }, indent=2) + "\n", encoding="utf-8")
        archive.replace(output / archive.name)
        provenance.replace(output / provenance.name)
    for warning in warnings:
        print(f"warning: {warning}")
    result = output / f"{name}.zip"
    print(f"Built {result}")
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--commit", default=os.environ.get("GITHUB_SHA"),
                        help="skills commit to record in the provenance file (defaults to GITHUB_SHA)")
    args = parser.parse_args()
    build(Path(__file__).resolve().parents[1], args.commit)
