# Microsoft Copilot Cowork package

This package combines Roboflow skills with the hosted MCP server. Cowork discovers tools directly from the server after connecting. No static tool catalog, MCP source checkout, GitHub credentials, Node.js, or uv is needed.

## Build

From the root of this repository, using Python 3.9 or newer:

macOS/Linux:

```bash
python3 cowork/build.py
```

Windows PowerShell:

```powershell
py -3 cowork/build.py
```

The existing `./cowork/build.sh` command also works on macOS/Linux. Building is offline once you have this repository and Python. Windows line endings in the skill files are supported.

The output is `cowork/build/roboflow-cowork.zip`. The adjacent `roboflow-cowork.provenance.json` records the package version and ZIP SHA-256. Validation failures preserve previous successful outputs.

## Install

In Cowork, open **Customize > Plugins > Upload plugin** and choose the ZIP. The Skills uploader accepts individual skills, not a complete plugin. Enable Roboflow in a new conversation and connect your account when prompted. Try asking Roboflow to list your workspace projects.

The manifest intentionally omits `authorization` for OAuth Dynamic Client Registration. This is not anonymous access. Do not replace it with `None` or a placeholder `OAuthPluginVault` registration. See [Microsoft's Cowork plugin documentation](https://learn.microsoft.com/en-us/microsoft-365/copilot/cowork/cowork-plugin-development#dynamic-client-registration).

Microsoft documents that Cowork ignores `mcpToolDescription` and discovers tools dynamically. The published v1.28 schema still requires the file reference, so the build generates an empty `{"tools": []}` compatibility file. It contains no duplicated tool definitions and requires no access to the MCP source repository.

## Troubleshooting

- Older builds that report `mcp-revision.txt must contain a full MCP commit SHA` or cannot fetch `roboflow-mcp` should be replaced with this build. The revision pin is no longer used.
- `Could not verify connection` before sign-in is a runtime connection/authentication problem, not a reason to rebuild the tool catalog. Record the Retry time and timezone, Cowork client (web/desktop), and any request/correlation ID for support. Do not share access tokens or client secrets.
- Package validation does not establish that OAuth works in a customer tenant. Acceptance requires sign-in, a successful read-only tool call, skill activation, and confirmation for a mutating tool.

## Verification

```bash
python3 -m unittest discover -s cowork -p 'test_*.py'
python3 cowork/validate.py
```

The icons are derived from the official [Roboflow brand kit](https://roboflow.com/brand).
