#!/usr/bin/env bash
# mcp.sh — write/remove the Roboflow MCP server entry in a host's config.
#
# The Roboflow MCP server is HTTP-based (live at mcp.roboflow.com) and
# authenticates via the x-api-key header. Hosts that support env-var
# expansion in MCP config (most do) get the ${ROBOFLOW_API_KEY} reference.
# `--inline-key` writes the literal key instead — global scope only,
# enforced in main.sh.

# rf::mcp::server_json [--type=<type>] [--key-value=<override>]
# Print the JSON object describing the Roboflow MCP server.
#
# Key-value resolution:
#   1. --key-value=<value>  explicit override (e.g. ${input:roboflow_api_key} for
#      VS Code Copilot's prompt-string mechanism)
#   2. global scope + RF_API_KEY resolved → embed literal key (default)
#   3. project scope + --inline-key + RF_API_KEY → embed literal (warn caller)
#   4. otherwise → ${ROBOFLOW_API_KEY} placeholder + caller should warn user
#
# --type defaults to "http" — most hosts. OpenCode uses "remote".
rf::mcp::server_json() {
    local type="http"
    local key_override=""
    while (($#)); do
        case "$1" in
            --type=*) type="${1#*=}" ;;
            --key-value=*) key_override="${1#*=}" ;;
            --inline) ;;   # no-op (kept for back-compat with old callers)
            *) ;;
        esac
        shift
    done

    local key_value
    if [[ -n "$key_override" ]]; then
        key_value="$key_override"
    elif [[ -n "${RF_API_KEY:-}" ]] && \
         { [[ "${RF_OPT_SCOPE:-global}" == "global" ]] || [[ "${RF_OPT_INLINE_KEY:-0}" == "1" ]]; }; then
        key_value="$RF_API_KEY"
    else
        key_value='${ROBOFLOW_API_KEY}'
    fi

    rf::json::has_tool || rf::die "no JSON tool available (need python3 or jq)"
    if [[ "$(rf::json::tool)" == "python3" ]]; then
        KEY_VALUE="$key_value" SERVER_TYPE="$type" python3 -c '
import json, os, sys
server = {
    "type": os.environ["SERVER_TYPE"],
    "url": "https://mcp.roboflow.com/mcp",
    "headers": {
        "x-api-key": os.environ["KEY_VALUE"],
        "Accept": "application/json, text/event-stream",
    },
}
json.dump(server, sys.stdout)
'
    else
        jq -n --arg k "$key_value" --arg t "$type" '{
            type: $t,
            url: "https://mcp.roboflow.com/mcp",
            headers: {"x-api-key": $k, "Accept": "application/json, text/event-stream"}
        }'
    fi
}

# rf::mcp::install <config_path> [<container_key>] [server_json_args...]
# Merge the Roboflow server entry into the named MCP config file.
# <container_key> defaults to "mcpServers" — pass "servers" for VS Code Copilot,
# "mcp" for OpenCode. Backs up any existing file first.
rf::mcp::install() {
    local config_path="$1"
    local container_key="${2:-mcpServers}"
    shift 2 || true

    if [[ "${RF_OPT_DRY_RUN:-0}" == "1" ]]; then
        rf::info "[dry-run] would write Roboflow MCP entry to $config_path"
        return 0
    fi

    if [[ -f "$config_path" ]]; then
        local bak
        bak="$(rf::backup "$config_path")"
        [[ -n "$bak" ]] && rf::dim "  backup: $bak"
    fi

    # Pass any extra args through to server_json (e.g. --type=remote, --key-value=...).
    local server_json
    if (($#)); then
        server_json="$(rf::mcp::server_json "$@")"
    else
        server_json="$(rf::mcp::server_json)"
    fi
    rf::json::merge_mcp "$config_path" "roboflow" "$server_json" "$container_key"
    rf::ok "wrote Roboflow MCP entry to $config_path"
}

# rf::mcp::remove <config_path> [<container_key>]
rf::mcp::remove() {
    local config_path="$1"
    local container_key="${2:-mcpServers}"
    [[ -f "$config_path" ]] || { rf::dim "  $config_path: nothing to remove"; return 0; }

    if [[ "${RF_OPT_DRY_RUN:-0}" == "1" ]]; then
        rf::info "[dry-run] would remove Roboflow MCP entry from $config_path"
        return 0
    fi

    local bak
    bak="$(rf::backup "$config_path")"
    [[ -n "$bak" ]] && rf::dim "  backup: $bak"

    rf::json::remove_mcp "$config_path" "roboflow" "$container_key"
    rf::ok "removed Roboflow MCP entry from $config_path"
}
