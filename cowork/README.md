# Microsoft Copilot Cowork package

This directory contains the source for the Microsoft 365 app package that installs the Roboflow skills and remote MCP connector in Copilot Cowork.

The v1.28 manifest intentionally omits `authorization`. Roboflow publishes OAuth protected-resource and authorization-server metadata, including a Dynamic Client Registration endpoint, so Cowork registers its OAuth client during connection setup. Do not add the placeholder `OAuthPluginVault` authorization emitted by `atk import openplugin`.

The package icons are derived directly from the official [Roboflow brand kit](https://roboflow.com/brand), without recoloring the supplied artwork. `color.png` places the official color logomark on the required opaque light background; `outline.png` uses the official white logomark on transparency.

## Refresh the MCP tool description

The checked-in tool description is the public `tools/list` contract from `roboflow-mcp`. After changing the public MCP tool surface, refresh it from a sibling checkout:

```bash
cd ../roboflow-mcp
UV_CACHE_DIR=/tmp/roboflow-mcp-uv-cache uv run python \
  dev/export_cowork_tools.py \
  ../computer-vision-skills/cowork/appPackage/tools/roboflow-tools.json
```

The exporter runs the server's public tool-list middleware, so employee-only tools are excluded.

## Build

Microsoft 365 Agents Toolkit 1.1.12 or newer is required. If `atk` is not installed globally, the build script runs the pinned CLI with `npx`.

```bash
./cowork/build.sh
```

The uploadable package is written to `cowork/build/roboflow-cowork.zip`. Install it for personal testing with:

```bash
atk auth login
atk install --file-path ./cowork/build/roboflow-cowork.zip --scope Personal
```

After installation, open Cowork and enable Roboflow under **Sources & Skills > Plugins**. Verify that OAuth sign-in completes, a skill activates, a read-only tool succeeds, and a mutating tool requests confirmation.
