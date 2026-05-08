#!/usr/bin/env bash
# json_io.sh — JSON read/write abstraction.
#
# Strategy: prefer python3 (preinstalled almost everywhere), fall back to jq.
# We do NOT bootstrap jq for now — that's a Phase-3+ enhancement if we hit a
# system missing both. All current Bash hosts hit the python3 path on macOS
# and modern Linux distros.

# Internal: detect tool. Caches in RF_JSON_TOOL.
rf::json::detect() {
    if [[ -n "${RF_JSON_TOOL:-}" ]]; then
        return 0
    fi
    if command -v python3 >/dev/null 2>&1; then
        RF_JSON_TOOL="python3"
    elif command -v jq >/dev/null 2>&1; then
        RF_JSON_TOOL="jq"
    else
        RF_JSON_TOOL=""
        return 1
    fi
    export RF_JSON_TOOL
}

# rf::json::has_tool — 0 if a JSON tool is available.
rf::json::has_tool() {
    rf::json::detect
    [[ -n "$RF_JSON_TOOL" ]]
}

# rf::json::tool — print the detected tool name ("python3" or "jq").
rf::json::tool() {
    rf::json::detect
    printf '%s' "$RF_JSON_TOOL"
}

# rf::json::merge_mcp <config_path> <server_name> <server_json>
#
# Read JSON from <config_path> (or {} if missing), set
# .mcpServers[<server_name>] = <server_json>, write back atomically.
# Other servers and other top-level keys are preserved.
rf::json::merge_mcp() {
    local config_path="$1" server_name="$2" server_json="$3"
    rf::json::detect || rf::die "no JSON tool available (need python3 or jq)"

    rf::ensure_dir "$(dirname "$config_path")"

    local existing="{}"
    if [[ -f "$config_path" ]]; then
        existing="$(cat "$config_path")"
        [[ -n "$existing" ]] || existing="{}"
    fi

    local merged
    if [[ "$RF_JSON_TOOL" == "python3" ]]; then
        merged="$(
            EXISTING="$existing" SERVER="$server_json" SERVER_NAME="$server_name" \
                python3 -c '
import json, os, sys
existing = json.loads(os.environ["EXISTING"]) if os.environ["EXISTING"].strip() else {}
server = json.loads(os.environ["SERVER"])
name = os.environ["SERVER_NAME"]
existing.setdefault("mcpServers", {})
existing["mcpServers"][name] = server
json.dump(existing, sys.stdout, indent=2)
sys.stdout.write("\n")
'
        )" || rf::die "failed to merge MCP config into $config_path"
    else
        merged="$(
            jq --arg name "$server_name" --argjson server "$server_json" \
                '.mcpServers[$name] = $server' <<<"$existing"
        )" || rf::die "failed to merge MCP config into $config_path"
    fi

    printf '%s' "$merged" | rf::atomic_write "$config_path"
}

# rf::json::remove_mcp <config_path> <server_name>
#
# Delete .mcpServers[<server_name>] from the config, leaving the rest intact.
# No-op if the file or the entry does not exist.
rf::json::remove_mcp() {
    local config_path="$1" server_name="$2"
    [[ -f "$config_path" ]] || return 0
    rf::json::detect || rf::die "no JSON tool available (need python3 or jq)"

    local existing
    existing="$(cat "$config_path")"
    [[ -n "$existing" ]] || return 0

    local updated
    if [[ "$RF_JSON_TOOL" == "python3" ]]; then
        updated="$(
            EXISTING="$existing" SERVER_NAME="$server_name" \
                python3 -c '
import json, os, sys
existing = json.loads(os.environ["EXISTING"])
servers = existing.get("mcpServers")
if isinstance(servers, dict) and os.environ["SERVER_NAME"] in servers:
    del servers[os.environ["SERVER_NAME"]]
    if not servers:
        del existing["mcpServers"]
json.dump(existing, sys.stdout, indent=2)
sys.stdout.write("\n")
'
        )"
    else
        updated="$(
            jq --arg name "$server_name" \
                'if .mcpServers? then .mcpServers |= (del(.[$name])) | (if (.mcpServers == {}) then del(.mcpServers) else . end) else . end' \
                <<<"$existing"
        )"
    fi

    printf '%s' "$updated" | rf::atomic_write "$config_path"
}

# rf::json::read_field <file> <jq-style path, e.g. .workspaces>
#
# Print the value at <path>. For objects/arrays returns JSON; for scalars returns the raw value (no quotes for strings).
rf::json::read_field() {
    local file="$1" path="$2"
    [[ -f "$file" ]] || return 1
    rf::json::detect || return 1

    if [[ "$RF_JSON_TOOL" == "python3" ]]; then
        FILE="$file" PATHEXPR="$path" python3 -c '
import json, os, sys
with open(os.environ["FILE"]) as fh:
    data = json.load(fh)
expr = os.environ["PATHEXPR"]
parts = [p for p in expr.lstrip(".").split(".") if p]
cur = data
for p in parts:
    if isinstance(cur, dict) and p in cur:
        cur = cur[p]
    else:
        sys.exit(2)
if isinstance(cur, (str, int, float, bool)) or cur is None:
    if isinstance(cur, bool):
        print("true" if cur else "false")
    elif cur is None:
        print("null")
    else:
        print(cur)
else:
    json.dump(cur, sys.stdout)
    sys.stdout.write("\n")
'
    else
        jq -r "$path // empty" "$file"
    fi
}

# rf::json::keys <file> <path-to-object>
#
# Print object keys at <path>, one per line.
rf::json::keys() {
    local file="$1" path="$2"
    [[ -f "$file" ]] || return 1
    rf::json::detect || return 1

    if [[ "$RF_JSON_TOOL" == "python3" ]]; then
        FILE="$file" PATHEXPR="$path" python3 -c '
import json, os, sys
with open(os.environ["FILE"]) as fh:
    data = json.load(fh)
expr = os.environ["PATHEXPR"]
parts = [p for p in expr.lstrip(".").split(".") if p]
cur = data
for p in parts:
    if isinstance(cur, dict) and p in cur:
        cur = cur[p]
    else:
        sys.exit(2)
if not isinstance(cur, dict):
    sys.exit(2)
for k in cur.keys():
    print(k)
'
    else
        jq -r "$path | keys[]" "$file"
    fi
}
