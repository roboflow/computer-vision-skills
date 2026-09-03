# Microsoft Copilot Cowork package

This directory contains the Microsoft-specific overlay used to import the existing Roboflow Claude/Cursor plugin into Copilot Cowork. The existing plugin manifests, `.mcp.json`, and `skills/` directory remain the source of truth.

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

Node.js and npm are required. The build script uses the pinned Microsoft 365 Agents Toolkit CLI to import the existing plugin into a temporary project, replaces the generated development manifest and icons with the reviewed Cowork v1.28 overlay, and packages the result. Toolkit environment and provisioning files exist only in that temporary directory.

```bash
./cowork/build.sh
```

The uploadable package is written to `cowork/build/roboflow-cowork.zip`. In Cowork, open **Customize > Plugins**, select **Upload plugin**, and choose the ZIP. The **Skills** uploader is only for a single standalone skill and will reject this complete plugin package.

After installation, enable Roboflow for a new Cowork conversation. Verify that OAuth sign-in completes, a skill activates, a read-only tool succeeds, and a mutating tool requests confirmation.
