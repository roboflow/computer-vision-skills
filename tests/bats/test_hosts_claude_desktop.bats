#!/usr/bin/env bats
# Tests for the Claude Desktop adapter — chat-tab MCP via mcp-remote stdio bridge.

load 'helpers/setup'

setup() {
    rf_test::isolated_home
    export NO_COLOR=1
    export ROBOFLOW_API_KEY=rf_test_key
    # The bridge requires npx on PATH. Provide a stub so install can succeed
    # in the isolated test PATH; tests that exercise the missing-npx path
    # explicitly skip stubbing.
    rf_test::stub_command "npx" 0
}

teardown() {
    rf_test::cleanup_home
}

# Determine the platform-specific Claude Desktop config path.
rf_test::claude_desktop_config_path() {
    case "$(uname -s)" in
        Darwin) printf '%s/Library/Application Support/Claude/claude_desktop_config.json' "$HOME" ;;
        Linux)  printf '%s/.config/Claude/claude_desktop_config.json' "$HOME" ;;
        *)      printf '%s/Claude/claude_desktop_config.json' "${APPDATA:-$HOME/AppData/Roaming}" ;;
    esac
}

@test "claude-desktop install: writes mcp-remote bridge entry with literal key" {
    run bash "$RF_REPO_ROOT/installer/main.sh" --yes --host=claude-desktop
    [ "$status" -eq 0 ]
    local cfg
    cfg="$(rf_test::claude_desktop_config_path)"
    [ -f "$cfg" ]
    grep -q '"roboflow"' "$cfg"
    # Bridge schema: command + args, NOT type/url/headers. On macOS/Linux
    # (the CI host OS) that's bare npx; the Windows cmd /c form is covered
    # by the unit tests below.
    grep -q '"command": "npx"' "$cfg"
    grep -q 'mcp-remote@' "$cfg"
    grep -q 'https://mcp.roboflow.com/mcp' "$cfg"
    # Literal key embedded in --header arg
    grep -q 'x-api-key:rf_test_key' "$cfg"
    # Schema fields that would crash Claude Desktop's validator must NOT appear
    if grep -q '"type": "http"' "$cfg"; then return 1; fi
    if grep -q '"url":' "$cfg"; then return 1; fi
}

# --- bridge command form (Windows vs Unix) ------------------------------
# Claude Desktop spawns the MCP command without a shell, so on Windows the
# bare name "npx" fails (CreateProcess can't run npx.cmd without PATHEXT
# resolution). The adapter must emit `cmd /c npx` on Windows. We force the
# platform branch by overriding rf::is_windows so the test is host-agnostic.

rf_test::source_claude_desktop() {
    # shellcheck disable=SC1091
    source "$RF_REPO_ROOT/installer/lib/common.sh"
    # shellcheck disable=SC1091
    source "$RF_REPO_ROOT/installer/lib/json_io.sh"
    # shellcheck disable=SC1091
    source "$RF_REPO_ROOT/installer/hosts/claude_desktop.sh"
}

@test "claude-desktop bridge: Windows routes through cmd /c npx" {
    rf_test::source_claude_desktop
    rf::is_windows() { return 0; }
    run rf::host::claude_desktop::bridge_server_json "rf_test_key"
    [ "$status" -eq 0 ]
    [[ "$output" == *'"cmd"'* ]]
    [[ "$output" == *'/c'* ]]
    [[ "$output" == *'npx'* ]]
    [[ "$output" == *'mcp-remote@'* ]]
    [[ "$output" == *'x-api-key:rf_test_key'* ]]
}

@test "claude-desktop bridge: non-Windows uses bare npx (no cmd wrapper)" {
    rf_test::source_claude_desktop
    rf::is_windows() { return 1; }
    run rf::host::claude_desktop::bridge_server_json "rf_test_key"
    [ "$status" -eq 0 ]
    [[ "$output" == *'"command": "npx"'* ]] || [[ "$output" == *'"command":"npx"'* ]]
    if [[ "$output" == *'"cmd"'* ]]; then
        echo "ERROR: non-Windows bridge should not wrap in cmd: $output" >&2
        return 1
    fi
}

@test "claude-desktop install: refuses without a resolved API key" {
    unset ROBOFLOW_API_KEY
    run bash "$RF_REPO_ROOT/installer/main.sh" --yes --host=claude-desktop --auth-skip
    [ "$status" -ne 0 ]
    [[ "$output" == *"literal API key"* ]]
}

@test "claude-desktop install: refuses when npx is missing" {
    # Hide the stub by clearing PATH back to system minimum (no test bin).
    export PATH="$RF_SYSTEM_PATH"
    # --no-install-node so the Node prereq gate fails fast instead of trying
    # to download nvm/Node over the network inside the test sandbox (which
    # is what made this test slow + non-deterministic before).
    run bash "$RF_REPO_ROOT/installer/main.sh" --yes --host=claude-desktop --no-install-node
    [ "$status" -ne 0 ]
    # The Node prereq gate now intercepts missing npx before the adapter
    # runs; both surfaces phrase it as "npx (Node.js) is required".
    [[ "$output" == *"npx (Node.js) is required"* ]]
    [[ "$output" == *"Node.js prerequisite not met"* ]]
}

@test "claude-desktop install: --no-mcp is a no-op" {
    run bash "$RF_REPO_ROOT/installer/main.sh" --yes --host=claude-desktop --no-mcp
    [ "$status" -eq 0 ]
    local cfg
    cfg="$(rf_test::claude_desktop_config_path)"
    [ ! -f "$cfg" ]
}

@test "claude-desktop install: --skills-only is a no-op (no skills support)" {
    run bash "$RF_REPO_ROOT/installer/main.sh" --yes --host=claude-desktop --skills-only
    [ "$status" -eq 0 ]
    local cfg
    cfg="$(rf_test::claude_desktop_config_path)"
    [ ! -f "$cfg" ]
}

@test "claude-desktop uninstall: removes the bridge entry" {
    run bash "$RF_REPO_ROOT/installer/main.sh" --yes --host=claude-desktop
    [ "$status" -eq 0 ]
    local cfg
    cfg="$(rf_test::claude_desktop_config_path)"
    grep -q '"roboflow"' "$cfg"
    run bash "$RF_REPO_ROOT/installer/main.sh" --yes --host=claude-desktop --uninstall
    [ "$status" -eq 0 ]
    if grep -q '"roboflow"' "$cfg" 2>/dev/null; then return 1; fi
}
