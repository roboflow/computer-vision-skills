#!/usr/bin/env bash
# mcp.sh — write/remove the Roboflow MCP server entry in a host's config.
#
# The Roboflow MCP server is HTTP-based (live at mcp.roboflow.com) and
# authenticates via the x-api-key header. Hosts that support env-var
# expansion in MCP config (most do) get the ${ROBOFLOW_API_KEY} reference.
# `--inline-key` writes the literal key instead — global scope only,
# enforced in main.sh.

# rf::mcp::server_json [--inline]
# Print the JSON object describing the Roboflow MCP server.
# Without --inline: uses ${ROBOFLOW_API_KEY} placeholder.
# With --inline:    embeds $RF_API_KEY literally.
rf::mcp::server_json() {
    local inline=0
    [[ "${1:-}" == "--inline" ]] && inline=1

    local key_value='${ROBOFLOW_API_KEY}'
    if [[ $inline -eq 1 ]] && [[ -n "${RF_API_KEY:-}" ]]; then
        key_value="$RF_API_KEY"
    fi

    rf::json::has_tool || rf::die "no JSON tool available (need python3 or jq)"
    if [[ "$(rf::json::tool)" == "python3" ]]; then
        KEY_VALUE="$key_value" python3 -c '
import json, os, sys
server = {
    "type": "http",
    "url": "https://mcp.roboflow.com/mcp",
    "headers": {
        "x-api-key": os.environ["KEY_VALUE"],
        "Accept": "application/json, text/event-stream",
    },
}
json.dump(server, sys.stdout)
'
    else
        jq -n --arg k "$key_value" '{
            type: "http",
            url: "https://mcp.roboflow.com/mcp",
            headers: {"x-api-key": $k, "Accept": "application/json, text/event-stream"}
        }'
    fi
}

# rf::mcp::install <config_path>
# Merge the Roboflow server entry into the named MCP config file.
# Backs up any existing file first.
rf::mcp::install() {
    local config_path="$1"

    if [[ "${RF_OPT_DRY_RUN:-0}" == "1" ]]; then
        rf::info "[dry-run] would write Roboflow MCP entry to $config_path"
        return 0
    fi

    if [[ -f "$config_path" ]]; then
        local bak
        bak="$(rf::backup "$config_path")"
        [[ -n "$bak" ]] && rf::dim "  backup: $bak"
    fi

    local server_json
    if [[ "${RF_OPT_INLINE_KEY:-0}" == "1" ]]; then
        server_json="$(rf::mcp::server_json --inline)"
    else
        server_json="$(rf::mcp::server_json)"
    fi
    rf::json::merge_mcp "$config_path" "roboflow" "$server_json"
    rf::ok "wrote Roboflow MCP entry to $config_path"
}

# rf::mcp::remove <config_path>
# Strip the Roboflow MCP entry without touching others.
rf::mcp::remove() {
    local config_path="$1"
    [[ -f "$config_path" ]] || { rf::dim "  $config_path: nothing to remove"; return 0; }

    if [[ "${RF_OPT_DRY_RUN:-0}" == "1" ]]; then
        rf::info "[dry-run] would remove Roboflow MCP entry from $config_path"
        return 0
    fi

    local bak
    bak="$(rf::backup "$config_path")"
    [[ -n "$bak" ]] && rf::dim "  backup: $bak"

    rf::json::remove_mcp "$config_path" "roboflow"
    rf::ok "removed Roboflow MCP entry from $config_path"
}
