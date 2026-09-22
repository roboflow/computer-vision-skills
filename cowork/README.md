# Microsoft Copilot Cowork package

This directory contains the Microsoft-specific overlay used to import the existing Roboflow Claude/Cursor plugin into Copilot Cowork. The existing plugin manifests, `.mcp.json`, and `skills/` directory remain the source of truth.

The v1.28 manifest intentionally omits `authorization`. Roboflow publishes OAuth protected-resource and authorization-server metadata, including a Dynamic Client Registration endpoint, so Cowork registers its OAuth client during connection setup. Do not add the placeholder `OAuthPluginVault` authorization emitted by `atk import openplugin`.

The package icons are derived directly from the official [Roboflow brand kit](https://roboflow.com/brand), without recoloring the supplied artwork. `color.png` places the official color logomark on the required opaque light background; `outline.png` uses the official white logomark on transparency.

## Build

Install Git, Python 3, uv (with Python 3.12 available or automatic downloads enabled), Node.js, and npm. Network access to GitHub and the Python/npm registries is required.

```bash
./cowork/build.sh
```

The build fetches the exact `roboflow-mcp` commit in `mcp-revision.txt` into a temporary checkout, installs its locked dependencies, and runs `dev/export_public_tools.py`. The exporter uses the public tool-list middleware, excluding employee-only tools. The generated catalog is validated in the staged package and included at `tools/roboflow-tools.json`; it is never checked into this repository.

The pinned Microsoft 365 Agents Toolkit CLI imports the existing plugin into a temporary project. The build applies the reviewed v1.28 manifest and icons, replaces the imported tool description with the generated catalog, and packages the result. Fetch, export, and validation failures stop the build without replacing previous successful outputs.

`cowork/build/roboflow-cowork.provenance.json` records the MCP commit and SHA-256 hashes of the catalog and ZIP. Both outputs are ignored by Git. A package is a snapshot: rebuilding with the same MCP pin does not adopt newer tool definitions.

## Update the MCP catalog revision

Set `cowork/mcp-revision.txt` to a full, reviewed 40-character commit SHA from `roboflow/roboflow-mcp` that contains `dev/export_public_tools.py`. Rebuild, validate the package, and commit only the pin change. Do not add a generated catalog to source control or substitute a moving branch name. The initial pin uses the exporter PR commit; after [MCP PR #163](https://github.com/roboflow/roboflow-mcp/pull/163) merges, replace it with the final merged commit and rebuild before distribution.

## Install

The uploadable package is written to `cowork/build/roboflow-cowork.zip`. In Cowork, open **Customize > Plugins**, select **Upload plugin**, and choose the ZIP. The **Skills** uploader is only for a single standalone skill and will reject this complete plugin package.

After installation, enable Roboflow for a new Cowork conversation. Verify that OAuth sign-in completes, a skill activates, a read-only tool succeeds, and a mutating tool requests confirmation.
