#!/usr/bin/env bats
# Tests for the Copilot CLI adapter (MCP only).

load 'helpers/setup'

setup() {
    rf_test::isolated_home
    export NO_COLOR=1
    export ROBOFLOW_API_KEY=rf_test_key
}

teardown() {
    rf_test::cleanup_home
}

@test "copilot install: writes ~/.copilot/mcp-config.json" {
    run bash "$RF_REPO_ROOT/installer/main.sh" --yes --host=copilot-cli
    [ "$status" -eq 0 ]
    [ -f "$HOME/.copilot/mcp-config.json" ]
    grep -q '"roboflow"' "$HOME/.copilot/mcp-config.json"
    grep -q '"https://mcp.roboflow.com/mcp"' "$HOME/.copilot/mcp-config.json"
}

@test "copilot install: preserves existing servers" {
    mkdir -p "$HOME/.copilot"
    cat >"$HOME/.copilot/mcp-config.json" <<'EOF'
{
  "mcpServers": { "existing": { "type": "stdio", "command": "/bin/sh" } }
}
EOF
    run bash "$RF_REPO_ROOT/installer/main.sh" --yes --host=copilot-cli
    [ "$status" -eq 0 ]
    grep -q '"existing"' "$HOME/.copilot/mcp-config.json"
    grep -q '"roboflow"' "$HOME/.copilot/mcp-config.json"
}

@test "copilot uninstall: removes only the Roboflow entry" {
    mkdir -p "$HOME/.copilot"
    cat >"$HOME/.copilot/mcp-config.json" <<'EOF'
{ "mcpServers": { "existing": { "type": "stdio", "command": "/bin/sh" } } }
EOF
    run bash "$RF_REPO_ROOT/installer/main.sh" --yes --host=copilot-cli
    [ "$status" -eq 0 ]
    run bash "$RF_REPO_ROOT/installer/main.sh" --yes --host=copilot-cli --uninstall
    [ "$status" -eq 0 ]
    if grep -q '"roboflow"' "$HOME/.copilot/mcp-config.json"; then return 1; fi
    grep -q '"existing"' "$HOME/.copilot/mcp-config.json"
}
