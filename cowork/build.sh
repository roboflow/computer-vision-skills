#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$(cd "${script_dir}/.." && pwd)"
output_dir="${script_dir}/build"
staging_dir="$(mktemp -d)"
trap 'rm -rf "${staging_dir}"' EXIT

# Resolve a reviewed revision, never a moving branch or a local sibling checkout.
mcp_revision="$(tr -d '\n' < "${script_dir}/mcp-revision.txt")"
if [[ ! "${mcp_revision}" =~ ^[0-9a-f]{40}$ ]]; then
  echo "mcp-revision.txt must contain a full MCP commit SHA" >&2
  exit 1
fi
mcp_dir="${staging_dir}/roboflow-mcp"
git init -q "${mcp_dir}"
git -C "${mcp_dir}" remote add origin https://github.com/roboflow/roboflow-mcp.git
git -C "${mcp_dir}" fetch --depth=1 origin "${mcp_revision}"
git -C "${mcp_dir}" checkout --detach FETCH_HEAD
[[ "$(git -C "${mcp_dir}" rev-parse HEAD)" == "${mcp_revision}" ]]

# Export before the importer runs so failures cannot fall back to its tool catalog.
generated_tools="${staging_dir}/roboflow-tools.json"
(cd "${mcp_dir}" && \
  uv sync --locked --no-dev --python 3.12 && \
  uv run --locked --no-sync python dev/export_public_tools.py "${generated_tools}")

npx -y -p @microsoft/m365agentstoolkit-cli@1.1.16 atk import openplugin \
  --path "${repo_dir}" \
  --output "${staging_dir}/project" \
  --privacy-url https://roboflow.com/privacy \
  --terms-url https://roboflow.com/terms \
  --website-url https://roboflow.com/ \
  --app-id a2158cf0-5901-5f4a-8f67-3dc812b0f650 \
  --default-auth-type None

cp "${script_dir}/appPackage/manifest.json" "${staging_dir}/project/appPackage/manifest.json"
cp "${script_dir}/appPackage/color.png" "${staging_dir}/project/appPackage/color.png"
cp "${script_dir}/appPackage/outline.png" "${staging_dir}/project/appPackage/outline.png"
rm -rf "${staging_dir}/project/appPackage/tools"
mkdir -p "${staging_dir}/project/appPackage/tools"
mv "${generated_tools}" "${staging_dir}/project/appPackage/tools/roboflow-tools.json"

python3 "${script_dir}/validate.py" \
  --package-dir "${staging_dir}/project/appPackage" \
  --skills-root "${staging_dir}/project/appPackage"

(cd "${staging_dir}/project" && \
  npx -y -p @microsoft/m365agentstoolkit-cli@1.1.16 atk package \
    --manifest-file "${staging_dir}/project/appPackage/manifest.json" \
    --output-package-file "${staging_dir}/roboflow-cowork.zip" \
    --output-folder "${staging_dir}/project/appPackage/build")

python3 - "${staging_dir}" "${mcp_revision}" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

staging = Path(sys.argv[1])
catalog = staging / "project/appPackage/tools/roboflow-tools.json"
provenance = {
    "mcp_commit": sys.argv[2],
    "tool_catalog_sha256": hashlib.sha256(catalog.read_bytes()).hexdigest(),
    "package_sha256": hashlib.sha256((staging / "roboflow-cowork.zip").read_bytes()).hexdigest(),
}
(staging / "roboflow-cowork.provenance.json").write_text(
    json.dumps(provenance, indent=2) + "\n"
)
PY

mkdir -p "${output_dir}"
mv "${staging_dir}/roboflow-cowork.zip" "${output_dir}/"
mv "${staging_dir}/roboflow-cowork.provenance.json" "${output_dir}/"
echo "Built ${output_dir}/roboflow-cowork.zip"
