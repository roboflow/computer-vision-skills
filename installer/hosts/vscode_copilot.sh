#!/usr/bin/env bash
# vscode_copilot.sh — install Roboflow MCP into VS Code Copilot.
#
# VS Code Copilot's MCP config uses a different schema:
#   {
#     "servers": { "<name>": { ... } },
#     "inputs": [...]   // for prompted secrets
#   }
#
# Default project scope writes to .vscode/mcp.json with an inputs[]
# promptString entry so the user is prompted for the API key on first use.
# `--global` writes to the user-level VS Code settings, which varies by
# install (Stable / Insiders / portable / Cursor-fork). We pick the most
# common location and tell the user about manual alternatives.

RF_HOST_ID="vscode-copilot"
RF_HOST_LABEL="VS Code Copilot"

rf::host::vscode_copilot::config_path() {
    if [[ "${RF_OPT_SCOPE:-global}" == "project" ]]; then
        printf '%s/.vscode/mcp.json' "${RF_PROJECT_DIR:-$PWD}"
    elif rf::is_macos; then
        printf '%s/Library/Application Support/Code/User/mcp.json' "$HOME"
    elif rf::is_linux; then
        printf '%s/.config/Code/User/mcp.json' "$HOME"
    else
        printf '%s/Code/User/mcp.json' "${APPDATA:-$HOME/AppData/Roaming}"
    fi
}

# Ensure an inputs[] entry is present that prompts for the API key. Returns
# the input id so the caller can reference it in headers.
rf::host::vscode_copilot::ensure_input() {
    local config_path="$1"
    local input_id="roboflow_api_key"

    rf::ensure_dir "$(dirname "$config_path")"

    local existing="{}"
    [[ -f "$config_path" ]] && existing="$(cat "$config_path")"
    [[ -n "$existing" ]] || existing="{}"

    local merged
    if [[ "$(rf::json::tool)" == "python3" ]]; then
        merged="$(EXISTING="$existing" INPUT_ID="$input_id" python3 -c '
import json, os, sys
existing = json.loads(os.environ["EXISTING"]) if os.environ["EXISTING"].strip() else {}
input_id = os.environ["INPUT_ID"]
inputs = existing.setdefault("inputs", [])
present = any(isinstance(i, dict) and i.get("id") == input_id for i in inputs)
if not present:
    inputs.append({
        "id": input_id,
        "type": "promptString",
        "description": "Roboflow API key (https://app.roboflow.com/settings/api)",
        "password": True
    })
json.dump(existing, sys.stdout, indent=2)
sys.stdout.write("\n")
')"
    else
        merged="$(jq --arg id "$input_id" '
            .inputs //= []
            | (if any(.inputs[]; .id == $id) then . else
                 .inputs += [{id: $id, type: "promptString",
                              description: "Roboflow API key (https://app.roboflow.com/settings/api)",
                              password: true}]
               end)
        ' <<<"$existing")"
    fi
    printf '%s' "$merged" | rf::atomic_write "$config_path"
    printf '%s' "$input_id"
}

rf::host::vscode_copilot::install() {
    rf::header "Configuring Roboflow MCP for $RF_HOST_LABEL"
    if [[ "${RF_DO_MCP:-1}" != "1" ]]; then
        rf::dim "  MCP disabled by --no-mcp; nothing to do (VS Code Copilot has no skills support)"
        return 0
    fi
    local config_path
    config_path="$(rf::host::vscode_copilot::config_path)"

    if [[ "${RF_OPT_DRY_RUN:-0}" == "1" ]]; then
        rf::info "[dry-run] would write Roboflow MCP entry (servers/inputs schema) to $config_path"
        return 0
    fi

    rf::step "MCP → $config_path"

    # First, write the inputs[] entry (prompted secret).
    local input_id
    input_id="$(rf::host::vscode_copilot::ensure_input "$config_path")"

    # Then merge the server entry under .servers (not .mcpServers), with the
    # api-key referencing the input ID rather than an env var.
    local key_value="\${input:${input_id}}"
    if [[ "${RF_OPT_INLINE_KEY:-0}" == "1" ]] && [[ -n "${RF_API_KEY:-}" ]]; then
        rf::warn "--inline-key with vscode-copilot embeds the literal key in .vscode/mcp.json (project files are commit-able — make sure that's intentional)"
        key_value="$RF_API_KEY"
    fi
    local server_json
    server_json="$(rf::mcp::server_json --key-value="$key_value")"
    rf::json::merge_mcp "$config_path" "roboflow" "$server_json" "servers"
    rf::ok "wrote Roboflow MCP entry to $config_path"

    rf::manifest::record "$(cat <<EOF
{
  "host_id": "$RF_HOST_ID",
  "component": "mcp",
  "scope": "${RF_OPT_SCOPE:-global}",
  "config_path": "$config_path",
  "server_name": "roboflow",
  "container_key": "servers",
  "input_id": "$input_id",
  "installer_version": "$RF_INSTALLER_VERSION",
  "installed_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
)" || true
    rf::dim "VS Code will prompt you for the API key when you first use Roboflow MCP."
    return 0
}

rf::host::vscode_copilot::uninstall() {
    rf::header "Removing Roboflow MCP from $RF_HOST_LABEL"
    if [[ "${RF_DO_MCP:-1}" != "1" ]]; then return 0; fi
    local config_path
    config_path="$(rf::host::vscode_copilot::config_path)"
    rf::mcp::remove "$config_path" "servers"
    # Also remove the inputs entry (best-effort).
    if [[ -f "$config_path" ]]; then
        local input_id="roboflow_api_key"
        local existing
        existing="$(cat "$config_path")"
        local updated
        if [[ "$(rf::json::tool)" == "python3" ]]; then
            updated="$(EXISTING="$existing" INPUT_ID="$input_id" python3 -c '
import json, os, sys
existing = json.loads(os.environ["EXISTING"])
inputs = existing.get("inputs")
if isinstance(inputs, list):
    inputs[:] = [i for i in inputs if not (isinstance(i, dict) and i.get("id") == os.environ["INPUT_ID"])]
    if not inputs:
        del existing["inputs"]
json.dump(existing, sys.stdout, indent=2)
sys.stdout.write("\n")
')"
        else
            updated="$(jq --arg id "$input_id" '
                if .inputs? then
                    .inputs |= map(select(.id != $id))
                    | (if (.inputs | length) == 0 then del(.inputs) else . end)
                else . end
            ' <<<"$existing")"
        fi
        printf '%s' "$updated" | rf::atomic_write "$config_path"
    fi
    rf::manifest::remove "$RF_HOST_ID" "mcp" "${RF_OPT_SCOPE:-global}" || true
    return 0
}
