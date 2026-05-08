#!/usr/bin/env bats
# Tests for the Claude Desktop adapter (MCP only — no skills).

load 'helpers/setup'

setup() {
    rf_test::isolated_home
    export NO_COLOR=1
    export ROBOFLOW_API_KEY=rf_test_key
}

teardown() {
    rf_test::cleanup_home
}

# Determine the platform-specific Claude Desktop config path. Mirrors the
# logic in installer/hosts/claude_desktop.sh.
rf_test::claude_desktop_config_path() {
    case "$(uname -s)" in
        Darwin) printf '%s/Library/Application Support/Claude/claude_desktop_config.json' "$HOME" ;;
        Linux)  printf '%s/.config/Claude/claude_desktop_config.json' "$HOME" ;;
        *)      printf '%s/Claude/claude_desktop_config.json' "${APPDATA:-$HOME/AppData/Roaming}" ;;
    esac
}

@test "claude-desktop install: writes MCP entry to platform config path" {
    run bash "$RF_REPO_ROOT/installer/main.sh" --yes --host=claude-desktop
    [ "$status" -eq 0 ]
    local cfg
    cfg="$(rf_test::claude_desktop_config_path)"
    [ -f "$cfg" ]
    grep -q '"roboflow"' "$cfg"
    grep -q '"https://mcp.roboflow.com/mcp"' "$cfg"
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

@test "claude-desktop uninstall: removes the MCP entry" {
    run bash "$RF_REPO_ROOT/installer/main.sh" --yes --host=claude-desktop
    [ "$status" -eq 0 ]
    local cfg
    cfg="$(rf_test::claude_desktop_config_path)"
    grep -q '"roboflow"' "$cfg"
    run bash "$RF_REPO_ROOT/installer/main.sh" --yes --host=claude-desktop --uninstall
    [ "$status" -eq 0 ]
    if grep -q '"roboflow"' "$cfg" 2>/dev/null; then return 1; fi
}
