#!/usr/bin/env bats
# Tests for json_io.sh — MCP merge / remove / read.

load 'helpers/setup'

setup() {
    rf_test::isolated_home
    export NO_COLOR=1
    # shellcheck disable=SC1091
    source "$RF_REPO_ROOT/installer/lib/common.sh"
    # shellcheck disable=SC1091
    source "$RF_REPO_ROOT/installer/lib/json_io.sh"
}

teardown() {
    rf_test::cleanup_home
}

@test "json_io: detect prefers python3 over jq" {
    rf::json::detect
    [ "$RF_JSON_TOOL" = "python3" ] || [ "$RF_JSON_TOOL" = "jq" ]
}

@test "json_io: merge_mcp creates a new file" {
    local path="$HOME/cfg.json"
    rf::json::merge_mcp "$path" "roboflow" '{"type":"http","url":"https://mcp.roboflow.com/mcp"}'
    [ -f "$path" ]
    grep -q '"roboflow"' "$path"
    grep -q '"https://mcp.roboflow.com/mcp"' "$path"
}

@test "json_io: merge_mcp preserves existing servers" {
    local path="$HOME/cfg.json"
    cat >"$path" <<'EOF'
{
  "mcpServers": {
    "other": { "type": "stdio", "command": "/usr/local/bin/other" }
  },
  "someOtherKey": 42
}
EOF
    rf::json::merge_mcp "$path" "roboflow" '{"type":"http","url":"https://mcp.roboflow.com/mcp"}'
    grep -q '"other"' "$path"
    grep -q '"roboflow"' "$path"
    grep -q '"someOtherKey"' "$path"
}

@test "json_io: merge_mcp replaces existing roboflow entry" {
    local path="$HOME/cfg.json"
    cat >"$path" <<'EOF'
{
  "mcpServers": {
    "roboflow": { "type": "stdio", "command": "/old/path" }
  }
}
EOF
    rf::json::merge_mcp "$path" "roboflow" '{"type":"http","url":"https://mcp.roboflow.com/mcp"}'
    grep -q '"https://mcp.roboflow.com/mcp"' "$path"
    if grep -q '"/old/path"' "$path"; then return 1; fi
}

@test "json_io: remove_mcp deletes the named server only" {
    local path="$HOME/cfg.json"
    cat >"$path" <<'EOF'
{
  "mcpServers": {
    "roboflow": { "type": "http" },
    "other": { "type": "stdio" }
  }
}
EOF
    rf::json::remove_mcp "$path" "roboflow"
    if grep -q '"roboflow"' "$path"; then return 1; fi
    grep -q '"other"' "$path"
}

@test "json_io: remove_mcp removes mcpServers key when emptied" {
    local path="$HOME/cfg.json"
    cat >"$path" <<'EOF'
{
  "mcpServers": {
    "roboflow": { "type": "http" }
  },
  "keepMe": 1
}
EOF
    rf::json::remove_mcp "$path" "roboflow"
    if grep -q '"mcpServers"' "$path"; then return 1; fi
    grep -q '"keepMe"' "$path"
}

@test "json_io: read_field reads nested string" {
    local path="$HOME/cfg.json"
    cat >"$path" <<'EOF'
{
  "workspaces": {
    "ws-a": {
      "apiKey": "rf_xyz"
    }
  }
}
EOF
    run rf::json::read_field "$path" .workspaces.ws-a.apiKey
    [ "$status" -eq 0 ]
    [ "$output" = "rf_xyz" ]
}

@test "json_io: keys lists object keys" {
    local path="$HOME/cfg.json"
    cat >"$path" <<'EOF'
{ "workspaces": { "ws-a": {}, "ws-b": {} } }
EOF
    run rf::json::keys "$path" .workspaces
    [ "$status" -eq 0 ]
    [[ "$output" == *"ws-a"* ]]
    [[ "$output" == *"ws-b"* ]]
}
