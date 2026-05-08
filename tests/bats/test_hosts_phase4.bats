#!/usr/bin/env bats
# Tests for Phase 4 hosts: Gemini CLI, Windsurf, VS Code Copilot, OpenCode.

load 'helpers/setup'

setup() {
    rf_test::isolated_home
    export NO_COLOR=1
    export ROBOFLOW_API_KEY=rf_test_key
}

teardown() {
    rf_test::cleanup_home
}

# --- gemini-cli (mcpServers schema, JSON, MCP only) ---------------------

@test "gemini install: writes ~/.gemini/settings.json" {
    run bash "$RF_REPO_ROOT/installer/main.sh" --yes --host=gemini-cli
    [ "$status" -eq 0 ]
    [ -f "$HOME/.gemini/settings.json" ]
    grep -q '"roboflow"' "$HOME/.gemini/settings.json"
    grep -q '"https://mcp.roboflow.com/mcp"' "$HOME/.gemini/settings.json"
}

@test "gemini install: preserves existing settings keys" {
    mkdir -p "$HOME/.gemini"
    cat >"$HOME/.gemini/settings.json" <<'EOF'
{ "theme": "dark", "mcpServers": { "other": { "type": "stdio" } } }
EOF
    run bash "$RF_REPO_ROOT/installer/main.sh" --yes --host=gemini-cli
    [ "$status" -eq 0 ]
    grep -q '"theme"' "$HOME/.gemini/settings.json"
    grep -q '"other"' "$HOME/.gemini/settings.json"
    grep -q '"roboflow"' "$HOME/.gemini/settings.json"
}

@test "gemini uninstall: removes Roboflow only" {
    run bash "$RF_REPO_ROOT/installer/main.sh" --yes --host=gemini-cli
    [ "$status" -eq 0 ]
    run bash "$RF_REPO_ROOT/installer/main.sh" --yes --host=gemini-cli --uninstall
    [ "$status" -eq 0 ]
    if grep -q '"roboflow"' "$HOME/.gemini/settings.json" 2>/dev/null; then return 1; fi
}

# --- windsurf-desktop (mcpServers schema, JSON, MCP only) ---------------

@test "windsurf install: writes ~/.codeium/windsurf/mcp_config.json" {
    run bash "$RF_REPO_ROOT/installer/main.sh" --yes --host=windsurf-desktop
    [ "$status" -eq 0 ]
    [ -f "$HOME/.codeium/windsurf/mcp_config.json" ]
    grep -q '"roboflow"' "$HOME/.codeium/windsurf/mcp_config.json"
}

# --- vscode-copilot (servers + inputs schema, project scope by default) -

@test "vscode-copilot install (global): writes user-level mcp.json with servers + inputs" {
    run bash "$RF_REPO_ROOT/installer/main.sh" --yes --host=vscode-copilot
    [ "$status" -eq 0 ]
    local cfg
    case "$(uname -s)" in
        Darwin) cfg="$HOME/Library/Application Support/Code/User/mcp.json" ;;
        Linux)  cfg="$HOME/.config/Code/User/mcp.json" ;;
        *)      cfg="$HOME/Code/User/mcp.json" ;;
    esac
    [ -f "$cfg" ]
    grep -q '"servers"' "$cfg"
    grep -q '"inputs"' "$cfg"
    grep -q '"roboflow_api_key"' "$cfg"
    grep -q 'promptString' "$cfg"
    grep -q '${input:roboflow_api_key}' "$cfg"
}

@test "vscode-copilot install (project): writes <project>/.vscode/mcp.json" {
    run bash "$RF_REPO_ROOT/installer/main.sh" --yes --host=vscode-copilot --project
    [ "$status" -eq 0 ]
    [ -f "$PWD/.vscode/mcp.json" ]
    grep -q '"servers"' "$PWD/.vscode/mcp.json"
    grep -q '"inputs"' "$PWD/.vscode/mcp.json"
    rm -rf "$PWD/.vscode"
}

@test "vscode-copilot uninstall: removes server + input" {
    run bash "$RF_REPO_ROOT/installer/main.sh" --yes --host=vscode-copilot --project
    [ "$status" -eq 0 ]
    [ -f "$PWD/.vscode/mcp.json" ]
    run bash "$RF_REPO_ROOT/installer/main.sh" --yes --host=vscode-copilot --project --uninstall
    [ "$status" -eq 0 ]
    if grep -q '"roboflow"' "$PWD/.vscode/mcp.json" 2>/dev/null; then rm -rf "$PWD/.vscode"; return 1; fi
    if grep -q '"roboflow_api_key"' "$PWD/.vscode/mcp.json" 2>/dev/null; then rm -rf "$PWD/.vscode"; return 1; fi
    rm -rf "$PWD/.vscode"
}

# --- opencode-cli (mcp container key, type=remote) ----------------------

@test "opencode install: writes ~/.config/opencode/opencode.json with mcp container + remote type" {
    run bash "$RF_REPO_ROOT/installer/main.sh" --yes --host=opencode-cli
    [ "$status" -eq 0 ]
    [ -f "$HOME/.config/opencode/opencode.json" ]
    grep -q '"mcp"' "$HOME/.config/opencode/opencode.json"
    grep -q '"roboflow"' "$HOME/.config/opencode/opencode.json"
    grep -q '"remote"' "$HOME/.config/opencode/opencode.json"
}

@test "opencode install: refuses JSONC config without --force" {
    mkdir -p "$HOME/.config/opencode"
    cat >"$HOME/.config/opencode/opencode.json" <<'EOF'
{
  // user comment
  "theme": "dark"
}
EOF
    run bash "$RF_REPO_ROOT/installer/main.sh" --yes --host=opencode-cli
    [ "$status" -ne 0 ]
    [[ "$output" == *"JSONC comments"* ]]
}

@test "opencode install: --force overrides JSONC refusal (drops comments)" {
    mkdir -p "$HOME/.config/opencode"
    cat >"$HOME/.config/opencode/opencode.json" <<'EOF'
{
  // user comment
  "theme": "dark"
}
EOF
    run bash "$RF_REPO_ROOT/installer/main.sh" --yes --host=opencode-cli --force
    [ "$status" -eq 0 ]
    grep -q '"roboflow"' "$HOME/.config/opencode/opencode.json"
    if grep -q 'user comment' "$HOME/.config/opencode/opencode.json"; then return 1; fi
}

@test "opencode uninstall: removes only Roboflow entry" {
    run bash "$RF_REPO_ROOT/installer/main.sh" --yes --host=opencode-cli
    [ "$status" -eq 0 ]
    run bash "$RF_REPO_ROOT/installer/main.sh" --yes --host=opencode-cli --uninstall
    [ "$status" -eq 0 ]
    if grep -q '"roboflow"' "$HOME/.config/opencode/opencode.json" 2>/dev/null; then return 1; fi
}

# --- detection / known-ids ---------------------------------------------

@test "detect::known_ids includes phase 4 hosts" {
    # shellcheck disable=SC1091
    source "$RF_REPO_ROOT/installer/lib/common.sh"
    # shellcheck disable=SC1091
    source "$RF_REPO_ROOT/installer/lib/detect.sh"
    run rf::detect::known_ids
    [ "$status" -eq 0 ]
    [[ "$output" == *"gemini-cli"* ]]
    [[ "$output" == *"windsurf-desktop"* ]]
    [[ "$output" == *"vscode-copilot"* ]]
    [[ "$output" == *"opencode-cli"* ]]
}
