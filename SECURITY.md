# Security Policy

## Reporting a vulnerability

If you believe you have found a security vulnerability in this repository or in
Roboflow's products, please report it responsibly.

- **Do not** open a public GitHub issue for security reports.
- Email **security@roboflow.com** with details and reproduction steps.
- For product-wide disclosure guidance, see Roboflow's Trust & Security page:
  <https://roboflow.com/security>.

We will acknowledge your report and work with you on a coordinated disclosure.

## Scope

This repository ships agent **skills** (markdown docs), plugin manifests, an MCP
server configuration, and a small polling helper script — it does not run a
service. The most relevant concerns here are:

- The bundled MCP config (`.mcp.json`) reads `ROBOFLOW_API_KEY` from the
  environment and forwards it as the `x-api-key` header. Never commit API keys.
- The `agent-install/` scripts are distributed for `curl … | bash` style
  installation; treat changes to them as security-sensitive.

Please report anything that could expose credentials, execute unexpected code on
a user's machine, or misdirect agents to unauthorized endpoints.
