#!/usr/bin/env bats
# Tests for lib/mcp.sh — the high-level MCP install/remove for hosts that
# write the Roboflow server entry directly into a config file.

load 'helpers/setup'

setup() {
    rf_test::isolated_home
    export NO_COLOR=1
    # shellcheck disable=SC1091
    source "$RF_REPO_ROOT/installer/lib/common.sh"
    # shellcheck disable=SC1091
    source "$RF_REPO_ROOT/installer/lib/json_io.sh"
    # shellcheck disable=SC1091
    source "$RF_REPO_ROOT/installer/lib/mcp.sh"
}

teardown() {
    rf_test::cleanup_home
}

@test "mcp: server_json default uses ROBOFLOW_API_KEY placeholder" {
    run rf::mcp::server_json
    [ "$status" -eq 0 ]
    [[ "$output" == *'${ROBOFLOW_API_KEY}'* ]]
    [[ "$output" == *'"https://mcp.roboflow.com/mcp"'* ]]
}

@test "mcp: server_json --inline embeds RF_API_KEY literal" {
    export RF_API_KEY="rf_actual_key"
    run rf::mcp::server_json --inline
    [ "$status" -eq 0 ]
    [[ "$output" == *"rf_actual_key"* ]]
    if [[ "$output" == *'${ROBOFLOW_API_KEY}'* ]]; then return 1; fi
}

@test "mcp: install creates a new file" {
    local cfg="$HOME/somewhere/mcp.json"
    rf::mcp::install "$cfg"
    [ -f "$cfg" ]
    grep -q '"roboflow"' "$cfg"
    grep -q '"https://mcp.roboflow.com/mcp"' "$cfg"
}

@test "mcp: install backs up existing config" {
    local cfg="$HOME/cursor/mcp.json"
    mkdir -p "$(dirname "$cfg")"
    cat >"$cfg" <<'EOF'
{ "mcpServers": { "other": { "type": "stdio", "command": "/bin/sh" } } }
EOF
    rf::mcp::install "$cfg"
    # Backup file exists
    local backups
    backups="$(find "$(dirname "$cfg")" -name 'mcp.json.bak.*' | head -n1)"
    [ -n "$backups" ]
    # Existing entry preserved
    grep -q '"other"' "$cfg"
    grep -q '"roboflow"' "$cfg"
}

@test "mcp: dry-run does not write" {
    export RF_OPT_DRY_RUN=1
    local cfg="$HOME/cfg.json"
    rf::mcp::install "$cfg"
    [ ! -f "$cfg" ]
}

@test "mcp: remove drops only roboflow entry" {
    local cfg="$HOME/cfg.json"
    cat >"$cfg" <<'EOF'
{
  "mcpServers": {
    "roboflow": { "type": "http" },
    "other": { "type": "stdio" }
  }
}
EOF
    rf::mcp::remove "$cfg"
    if grep -q '"roboflow"' "$cfg"; then return 1; fi
    grep -q '"other"' "$cfg"
}

@test "mcp: remove no-op when file missing" {
    local cfg="$HOME/missing.json"
    run rf::mcp::remove "$cfg"
    [ "$status" -eq 0 ]
    [ ! -f "$cfg" ]
}
