#!/usr/bin/env bats
# Tests for the Cursor adapter (config-file path: MCP + skills).

load 'helpers/setup'

setup() {
    rf_test::isolated_home
    export NO_COLOR=1
    export ROBOFLOW_API_KEY=rf_test_key
    # Cursor isn't actually on disk for tests; force detection by lying about
    # the app path is hard, so we use --host=cursor-desktop directly.
}

teardown() {
    rf_test::cleanup_home
}

@test "cursor install: writes ~/.cursor/mcp.json with Roboflow entry" {
    run bash "$RF_REPO_ROOT/installer/main.sh" --yes --host=cursor-desktop
    [ "$status" -eq 0 ]
    [ -f "$HOME/.cursor/mcp.json" ]
    grep -q '"roboflow"' "$HOME/.cursor/mcp.json"
    grep -q '"https://mcp.roboflow.com/mcp"' "$HOME/.cursor/mcp.json"
    # Default uses placeholder, not the literal key
    grep -q '${ROBOFLOW_API_KEY}' "$HOME/.cursor/mcp.json"
}

@test "cursor install: --inline-key embeds the literal key" {
    run bash "$RF_REPO_ROOT/installer/main.sh" --yes --host=cursor-desktop --inline-key
    [ "$status" -eq 0 ]
    grep -q "rf_test_key" "$HOME/.cursor/mcp.json"
}

@test "cursor install: copies skills into ~/.claude/skills" {
    run bash "$RF_REPO_ROOT/installer/main.sh" --yes --host=cursor-desktop
    [ "$status" -eq 0 ]
    # We're using the actual repo as the skills source — at least one skill
    # should make it through.
    [ -d "$HOME/.claude/skills/inference" ]
    [ -f "$HOME/.claude/skills/inference/SKILL.md" ]
    [ -f "$HOME/.claude/skills/inference/.roboflow-install-manifest.json" ]
}

@test "cursor install: --no-skills writes MCP only" {
    run bash "$RF_REPO_ROOT/installer/main.sh" --yes --host=cursor-desktop --no-skills
    [ "$status" -eq 0 ]
    [ -f "$HOME/.cursor/mcp.json" ]
    [ ! -d "$HOME/.claude/skills" ]
}

@test "cursor install: --mcp-only same as --no-skills (no rules support yet)" {
    run bash "$RF_REPO_ROOT/installer/main.sh" --yes --host=cursor-desktop --mcp-only
    [ "$status" -eq 0 ]
    [ -f "$HOME/.cursor/mcp.json" ]
    [ ! -d "$HOME/.claude/skills" ]
}

@test "cursor install: --skills-only skips MCP" {
    run bash "$RF_REPO_ROOT/installer/main.sh" --yes --host=cursor-desktop --skills-only
    [ "$status" -eq 0 ]
    [ ! -f "$HOME/.cursor/mcp.json" ]
    [ -d "$HOME/.claude/skills" ]
}

@test "cursor install: dry-run writes nothing" {
    run bash "$RF_REPO_ROOT/installer/main.sh" --yes --host=cursor-desktop --dry-run
    [ "$status" -eq 0 ]
    [ ! -f "$HOME/.cursor/mcp.json" ]
    [ ! -d "$HOME/.claude/skills" ]
}

@test "cursor install: re-run is idempotent (pristine skills get refreshed)" {
    run bash "$RF_REPO_ROOT/installer/main.sh" --yes --host=cursor-desktop
    [ "$status" -eq 0 ]
    run bash "$RF_REPO_ROOT/installer/main.sh" --yes --host=cursor-desktop
    [ "$status" -eq 0 ]
    # MCP entry exists once (not duplicated as something other than the
    # 'roboflow' key)
    [ "$(grep -c '"roboflow"' "$HOME/.cursor/mcp.json")" -eq 1 ]
}

@test "cursor install: preserves existing MCP servers" {
    mkdir -p "$HOME/.cursor"
    cat >"$HOME/.cursor/mcp.json" <<'EOF'
{
  "mcpServers": {
    "my-other-server": { "type": "stdio", "command": "/bin/echo" }
  }
}
EOF
    run bash "$RF_REPO_ROOT/installer/main.sh" --yes --host=cursor-desktop
    [ "$status" -eq 0 ]
    grep -q '"my-other-server"' "$HOME/.cursor/mcp.json"
    grep -q '"roboflow"' "$HOME/.cursor/mcp.json"
}

@test "cursor uninstall: removes Roboflow MCP entry, leaves others" {
    mkdir -p "$HOME/.cursor"
    cat >"$HOME/.cursor/mcp.json" <<'EOF'
{
  "mcpServers": {
    "my-other-server": { "type": "stdio", "command": "/bin/echo" }
  }
}
EOF
    run bash "$RF_REPO_ROOT/installer/main.sh" --yes --host=cursor-desktop
    [ "$status" -eq 0 ]
    run bash "$RF_REPO_ROOT/installer/main.sh" --yes --host=cursor-desktop --uninstall
    [ "$status" -eq 0 ]
    if grep -q '"roboflow"' "$HOME/.cursor/mcp.json"; then return 1; fi
    grep -q '"my-other-server"' "$HOME/.cursor/mcp.json"
}

@test "cursor uninstall: removes installed skills" {
    run bash "$RF_REPO_ROOT/installer/main.sh" --yes --host=cursor-desktop
    [ "$status" -eq 0 ]
    [ -d "$HOME/.claude/skills/inference" ]
    run bash "$RF_REPO_ROOT/installer/main.sh" --yes --host=cursor-desktop --uninstall
    [ "$status" -eq 0 ]
    [ ! -d "$HOME/.claude/skills/inference" ]
}
