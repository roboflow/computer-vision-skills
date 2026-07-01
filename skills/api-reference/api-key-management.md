# Roboflow API Key Management

> **Source-of-truth note:** This page ships with the Roboflow plugin. If your client has the plugin loaded, prefer the local skill (`roboflow:api-reference`) over fetching `roboflow://skills/api-reference/api-key-management` via `ReadMcpResourceTool` — the MCP resources are a fallback for non-plugin clients and may lag the source repo.

> **Tip:** If you're connected to the [Roboflow MCP server](https://mcp.roboflow.com), prefer its `api_keys_*` tools over raw REST calls — they handle auth and typed responses for you. The REST patterns below stay relevant if you're not using MCP.

Base URLs:
- Production: `https://api.roboflow.com`
- Staging: `https://api.roboflow.one`

**Auth for management endpoints:** pass the API key via `?api_key=` query parameter or `Authorization: Bearer` header. The workspace publishable key (`rf_<workspaceId>`) is NOT accepted — you must use a private API key (or a scoped key that includes `api-key:read` / `api-key:create` / etc.).

Keys are addressed by their non-secret `keyId` field. Secret key values are **never returned** by any list or get endpoint — they are shown exactly once, in the 201 response from the create endpoint.

## Publishable vs. Private Keys

| | Publishable Key | Private API Key |
|---|---|---|
| Format | `rf_<workspaceId>` | opaque secret string |
| Secret? | No — safe to expose in client-side / browser code | Yes — treat like a password |
| Retrieval | `GET /:workspace/api-keys/publishable` | Created via POST; secret shown once |
| Lifecycle | Fixed per workspace; cannot be created or revoked | Can be created, disabled, and revoked |
| Capabilities | Inference and model download on workspace models only | Full API access (scoped by the key's own scopes) |
| Typical use | Browser/edge inference via `roboflow.js` / inferencejs | Server-side automation, CI/CD, MCP tools |

The publishable key grants inference and model-download access on that workspace's models to **anyone who holds it** — treat it accordingly (it's not a secret, but scope it to what you actually publish). Use a scoped private key for any server-side operation.

## REST Endpoints

### List API Keys

```
GET /:workspace/api-keys
```

Query params: `includeDisabled` (bool), `includeFolders` (bool)

Returns all non-secret key metadata for the workspace. The secret value is never included.

```bash
curl "https://api.roboflow.com/my-workspace/api-keys?api_key=KEY"
```

Response:

```json
{
  "apiKeys": [
    {
      "keyId": "abc123",
      "name": "CI pipeline",
      "prefix": "rf_ci_",
      "scopes": ["image:read", "image:create"],
      "folderIds": [],
      "default": false,
      "protected": true,
      "disabled": false,
      "created_on": "2024-01-15T10:30:00Z",
      "created_by": "user@example.com",
      "customMetadata": {}
    }
  ],
  "publishableKey": "rf_myworkspaceid"
}
```

### Get a Single Key

```
GET /:workspace/api-keys/:keyId
```

```bash
curl "https://api.roboflow.com/my-workspace/api-keys/abc123?api_key=KEY"
```

Response: `{ "apiKey": { ...same fields as above... } }`

### Get Publishable Key

```
GET /:workspace/api-keys/publishable
```

```bash
curl "https://api.roboflow.com/my-workspace/api-keys/publishable?api_key=KEY"
```

Response: `{ "publishableKey": "rf_myworkspaceid" }`

### Create a Key

```
POST /:workspace/api-keys
```

Body fields (all optional):

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Human-readable label |
| `scopes` | string[] or null | Scope strings to grant (or `role:<name>` presets). Omit to inherit the calling credential's scopes; `null` for full access (if the caller has it); `[]` for no abilities |
| `folderIds` | string[] | Restrict key to specific folders (requires Advanced API Keys) |
| `customMetadata` | object | Arbitrary key-value metadata |
| `protected` | bool | Mark as protected (cannot be disabled/revoked without dashboard action) |

`scopes`, `folderIds`, and `customMetadata` require the **Advanced API Keys** plan feature. A new key can never exceed the caller's own abilities.

**Who can create keys.** The acting credential may create keys only if it is **unscoped** (full access) or was granted the `api-key:create` scope; an OAuth token also needs the `create_api_key` permission. On workspaces with **Advanced API Keys**, new keys created from the dashboard are **scoped** (not full access) and `api-key:create` is **off by default** — include it explicitly only if the key must manage keys.

**Scopes are stored as explicit leaves.** A section name (e.g. `model`) or a `role:<name>` preset is expanded to its current leaf scopes at create time, so a key never auto-gains an ability added to that group later — request the new scope explicitly when you need it.

**Agents: scope to least privilege.** When you create a key on a workspace that has **Advanced API Keys**, you should pass an explicit `scopes` array covering only the abilities the key actually needs (e.g. `["image:create"]` for an upload-only key) rather than a full-access key. If the workspace does **not** have Advanced API Keys, only full-access keys can be created — tell the user that scoped, least-privilege keys are available on the **Enterprise** plan.

**A workspace-wide key** (no `folderIds`) requires the caller to have access to **all** folders in the workspace; otherwise scope the key to specific `folderIds` you can access.

```bash
curl -X POST "https://api.roboflow.com/my-workspace/api-keys?api_key=KEY" \
  -H "Content-Type: application/json" \
  -d '{"name": "read-only ingest", "scopes": ["image:read"]}'
```

Response (201):

```json
{
  "keyId": "abc123",
  "key": "rf_ACTUAL_SECRET_VALUE",
  "name": "read-only ingest",
  "scopes": ["image:read"],
  "folderIds": [],
  "protected": false,
  "publishableKey": "rf_myworkspaceid"
}
```

**The `key` field in this response is the only time the secret is ever exposed.** Store it immediately (e.g. in a secrets manager); it cannot be retrieved again.

### Update a Key

```
PATCH /:workspace/api-keys/:keyId
```

Body fields (all optional — send only the fields you want to change):

| Field | Type | Notes |
|-------|------|-------|
| `name` | string | Rename the key |
| `scopes` | `string[] \| null` | Replace the key's scopes (tri-state — see below). Requires Advanced API Keys |
| `customMetadata` | object | Replace the key's metadata. Requires Advanced API Keys |
| `protected` | bool | Set to `true` only — unprotect is dashboard-only |
| `disabled` | bool | Temporarily disable or re-enable. Requires Advanced API Keys |

**The three states of `scopes`** (PATCH replaces, so omitting the field leaves scopes unchanged):

- **Omitted** - the key's existing scopes are left unchanged.
- **`null`** - the key becomes **full access** (unscoped). Use this to widen a scoped key back to full access; the caller must itself hold full access to grant it.
- **`[]`** (empty array) - the key stays a valid credential but has **no abilities**.
- **`["model:infer", ...]`** - **replaces** the scopes with exactly this set (a section name like `model` expands to all of that section's scopes).

Sending `scopes` (including `[]` or `null`), `customMetadata`, or `disabled` requires the **Advanced API Keys** plan feature.

```bash
curl -X PATCH "https://api.roboflow.com/my-workspace/api-keys/abc123?api_key=KEY" \
  -H "Content-Type: application/json" \
  -d '{"name": "renamed key", "disabled": true}'
```

Response: `{ "apiKey": { ...updated fields... } }`

Note: `protected: true` can be set via API, but removing the protected flag requires the dashboard. Attempting to disable or revoke a protected key returns 409.

### Revoke a Key

```
DELETE /:workspace/api-keys/:keyId
```

```bash
curl -X DELETE "https://api.roboflow.com/my-workspace/api-keys/abc123?api_key=KEY"
```

Response: `{ "status": "revoked", "keyId": "abc123" }`

Revocation is permanent. If you might need to re-enable the key later, use `PATCH` with `disabled: true` instead.

## OAuth Scopes for Key Management

When using a scoped key or OAuth token to manage other keys, the caller's token needs one or more of these scopes:

| Scope | Grants |
|-------|--------|
| `api-key:read` | List and get key metadata |
| `api-key:create` | Create new keys |
| `api-key:update` | Rename, scope, disable keys |
| `api-key:revoke` | Delete keys permanently |

## MCP Tools

If you're using the Roboflow MCP server, prefer these tools over raw REST calls:

| Tool | Description |
|------|-------------|
| `api_keys_list` | List all key metadata for a workspace |
| `api_keys_get` | Get a single key by `keyId` |
| `api_keys_get_publishable` | Get the workspace publishable key |
| `api_keys_create` | Create a key (returns the one-time secret) |
| `api_keys_update` | Rename, re-scope, or update metadata |
| `api_keys_protect` | Mark a key as protected (no unprotect tool by design) |
| `api_keys_disable` | Temporarily disable a key (reversible) |
| `api_keys_revoke` | Permanently revoke a key |

There is intentionally no `api_keys_unprotect` tool — removing the protected flag requires a deliberate dashboard action to prevent accidental exposure.

## Python CLI

The `roboflow` Python package exposes an `api-key` subcommand:

```bash
# List all keys
roboflow api-key list

# Get a specific key's metadata
roboflow api-key get KEY_ID

# Create a key (capture the secret immediately)
roboflow --json api-key create "my-key-name" | jq -r .key

# Create a scoped key
roboflow --json api-key create "ci-read-only" --scope image:read --scope model:infer | jq -r .key

# Rename a key
roboflow api-key update KEY_ID --name "new name"

# Disable a key (reversible)
roboflow api-key disable KEY_ID

# Mark a key as protected
roboflow api-key protect KEY_ID

# Get the workspace publishable key
roboflow api-key publishable

# Permanently revoke a key
roboflow api-key revoke KEY_ID
```

## Best Practices

### Least-privilege scoping

Only grant the scopes a key actually needs. A key used exclusively to upload images should have `image:create` — not a full unrestricted key. This limits the blast radius if the key is compromised.

```bash
# Good: scoped to what CI actually needs
roboflow --json api-key create "github-actions-upload" \
  --scope image:create --scope image:annotate | jq -r .key
```

### Protect production keys

Mark any key used in production workloads as `protected` immediately after creation. Protected keys cannot be accidentally disabled or revoked via API — only via a deliberate dashboard action.

```bash
# Protect a key after creating it
roboflow api-key protect KEY_ID
```

### Never commit secrets

Store the API key in a `.gitignore`'d `.env` file or a secrets manager. The key value is returned only once (at creation time) — if you miss it, you must create a new key.

```bash
# .env (never commit this file)
ROBOFLOW_API_KEY=rf_...
```

### Rotate keys safely

1. Create a new key with the same scopes as the key being rotated.
2. Deploy the new key to all consumers.
3. Verify the new key is working.
4. Revoke the old key.

This zero-downtime rotation avoids service interruptions.

### Prefer disable over revoke when unsure

`PATCH { "disabled": true }` is reversible. `DELETE` is permanent. If you're not certain a key is safe to remove (e.g. you're not sure all consumers have been updated), disable first and revoke after confirming.

### The secret is shown exactly once

The `key` field in the create response is the only time the plaintext secret appears. Copy it to your secrets manager immediately. There is no "show secret again" endpoint — if you lose it, create a new key and revoke the old one.
