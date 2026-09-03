#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$(cd "${script_dir}/.." && pwd)"
output_dir="${script_dir}/build"
staging_dir="$(mktemp -d)"
trap 'rm -rf "${staging_dir}"' EXIT

python3 "${script_dir}/validate.py"

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
cp -R "${script_dir}/appPackage/tools" "${staging_dir}/project/appPackage/tools"

mkdir -p "${output_dir}"
(cd "${staging_dir}/project" && \
  npx -y -p @microsoft/m365agentstoolkit-cli@1.1.16 atk package \
    --manifest-file "${staging_dir}/project/appPackage/manifest.json" \
    --output-package-file "${output_dir}/roboflow-cowork.zip" \
    --output-folder "${staging_dir}/project/appPackage/build")

echo "Built ${output_dir}/roboflow-cowork.zip"
