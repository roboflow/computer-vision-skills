# Microsoft Copilot Cowork package

This package combines Roboflow skills with the hosted MCP server. Building requires Python 3.9 or newer and access to a public GitHub release asset. It does not require access to the private MCP repository, Node.js, or uv.

## Build

From the root of this repository:

macOS/Linux:

```bash
python3 cowork/build.py
```

Windows PowerShell:

```powershell
py -3 cowork/build.py
```

The existing `./cowork/build.sh` command also works on macOS/Linux. The output is `cowork/build/roboflow-cowork.zip`. The adjacent provenance JSON records the package version, MCP source revision, and catalog/ZIP SHA-256 hashes.

The build downloads the public catalog artifact pinned in `cowork/catalog.json` and verifies its hash before packaging. There is no Git checkout or shell parsing of a commit SHA. To build offline after downloading that artifact:

```bash
python3 cowork/build.py --tool-catalog /path/to/roboflow-cowork-tools.json
```

Download, hash, validation, and ZIP-write failures preserve previous successful outputs.

## Install

In Cowork, open **Customize > Plugins > Upload plugin** and choose the ZIP. The Skills uploader accepts individual skills, not a complete plugin. Enable Roboflow in a new conversation and connect your account when prompted. Try asking Roboflow to list your workspace projects.

The manifest intentionally omits `authorization` for OAuth Dynamic Client Registration. This is not anonymous access. Do not replace it with `None` or a placeholder `OAuthPluginVault` registration. See [Microsoft's Cowork plugin documentation](https://learn.microsoft.com/en-us/microsoft-365/copilot/cowork/cowork-plugin-development#dynamic-client-registration).

Microsoft documents that Cowork discovers tools dynamically, but its upload flow still rejects an empty `mcpToolDescription.tools` array. Include the exported catalog. Do not replace it with an empty placeholder, even if toolkit validation passes.

## Update the catalog (maintainers)

Export `dev/export_public_tools.py` from a reviewed MCP commit using its locked environment, publish the resulting public-only JSON as a release asset, and update the URL, full MCP commit, and SHA-256 in `catalog.json`. Tool definitions remain generated artifacts, never checked into this repository. Rebuild and test the ZIP in Cowork before distribution.

## Troubleshooting

- Older builds that report `mcp-revision.txt must contain a full MCP commit SHA` or cannot fetch `roboflow-mcp` should be replaced with this build.
- `Could not verify connection` before sign-in is a runtime connection/authentication problem. Record the Retry time and timezone, Cowork client (web/desktop), and any request/correlation ID for support. Do not share tokens or client secrets.
- Package validation does not establish that OAuth works in a customer tenant. Acceptance requires sign-in, a successful read-only tool call, skill activation, and confirmation for a mutating tool.

## Verification

```bash
python3 -m unittest discover -s cowork -p 'test_*.py'
```

CI tests packaging on Windows and Linux. The icons are derived from the official [Roboflow brand kit](https://roboflow.com/brand).
