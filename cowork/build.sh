#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$(cd "${script_dir}/.." && pwd)"
output_dir="${script_dir}/build"
staging_dir="$(mktemp -d)"
trap 'rm -rf "${staging_dir}"' EXIT

python3 "${script_dir}/validate.py"

mkdir -p "${staging_dir}/appPackage"
cp -R "${script_dir}/appPackage/." "${staging_dir}/appPackage/"
cp -R "${repo_dir}/skills" "${staging_dir}/appPackage/skills"
cp "${script_dir}/m365agents.yml" "${staging_dir}/m365agents.yml"
cp -R "${script_dir}/env" "${staging_dir}/env"
mkdir -p "${output_dir}"

if command -v atk >/dev/null 2>&1; then
  (cd "${staging_dir}" && atk package \
    --manifest-file "${staging_dir}/appPackage/manifest.json" \
    --output-package-file "${output_dir}/roboflow-cowork.zip" \
    --output-folder "${staging_dir}/build")
else
  (cd "${staging_dir}" && npx -y -p @microsoft/m365agentstoolkit-cli@1.1.16 atk package \
    --manifest-file "${staging_dir}/appPackage/manifest.json" \
    --output-package-file "${output_dir}/roboflow-cowork.zip" \
    --output-folder "${staging_dir}/build")
fi

echo "Built ${output_dir}/roboflow-cowork.zip"
