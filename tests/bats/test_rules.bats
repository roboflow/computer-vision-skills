#!/usr/bin/env bats
# Tests for installer/lib/rules.sh — managed-block writer + Cursor .mdc.

load 'helpers/setup'

setup() {
    rf_test::isolated_home
    export NO_COLOR=1
    export RF_REPO_DIR="$RF_REPO_ROOT"
    export RF_INSTALLER_DIR="$RF_REPO_ROOT/installer"
    # shellcheck disable=SC1091
    source "$RF_REPO_ROOT/installer/lib/common.sh"
    # shellcheck disable=SC1091
    source "$RF_REPO_ROOT/installer/lib/json_io.sh"
    # shellcheck disable=SC1091
    source "$RF_REPO_ROOT/installer/lib/auth.sh"
    # shellcheck disable=SC1091
    source "$RF_REPO_ROOT/installer/lib/manifest.sh"
    # shellcheck disable=SC1091
    source "$RF_REPO_ROOT/installer/lib/rules.sh"
}

teardown() {
    rf_test::cleanup_home
}

@test "rules: install_managed_block creates new CLAUDE.md with markers" {
    local target="$HOME/CLAUDE.md"
    rf::rules::install_managed_block "$target" claude
    [ -f "$target" ]
    grep -q '<!-- BEGIN ROBOFLOW -->' "$target"
    grep -q '<!-- END ROBOFLOW -->' "$target"
    grep -q 'Roboflow' "$target"
}

@test "rules: install_managed_block appends to existing CLAUDE.md" {
    local target="$HOME/CLAUDE.md"
    cat >"$target" <<'EOF'
# My project

User-owned content here.
EOF
    rf::rules::install_managed_block "$target" claude
    grep -q 'User-owned content here' "$target"
    grep -q '<!-- BEGIN ROBOFLOW -->' "$target"
}

@test "rules: install_managed_block replaces existing block (idempotent)" {
    local target="$HOME/CLAUDE.md"
    rf::rules::install_managed_block "$target" claude
    local first_size
    first_size="$(wc -c <"$target")"
    rf::rules::install_managed_block "$target" claude
    local second_size
    second_size="$(wc -c <"$target")"
    [ "$first_size" = "$second_size" ]
    [ "$(grep -c '<!-- BEGIN ROBOFLOW -->' "$target")" -eq 1 ]
}

@test "rules: remove_managed_block strips block but keeps user content" {
    local target="$HOME/CLAUDE.md"
    cat >"$target" <<'EOF'
# My project

User-owned content here.
EOF
    rf::rules::install_managed_block "$target" claude
    rf::rules::remove_managed_block "$target"
    grep -q 'User-owned content here' "$target"
    if grep -q 'BEGIN ROBOFLOW' "$target"; then return 1; fi
    if grep -q 'Roboflow' "$target"; then return 1; fi
}

@test "rules: remove_managed_block deletes file when only block was present" {
    local target="$HOME/CLAUDE.md"
    rf::rules::install_managed_block "$target" claude
    rf::rules::remove_managed_block "$target"
    [ ! -f "$target" ]
}

@test "rules: install_cursor_mdc writes the template verbatim" {
    local target="$HOME/.cursor/rules/roboflow.mdc"
    rf::rules::install_cursor_mdc "$target"
    [ -f "$target" ]
    grep -q '^description:' "$target"
    grep -q '# Roboflow' "$target"
}

@test "rules: cursor install via main.sh writes .cursor/rules/roboflow.mdc with --project" {
    cd "$HOME"
    export ROBOFLOW_API_KEY=rf_test
    run bash "$RF_REPO_ROOT/installer/main.sh" --yes --host=cursor-desktop --project
    [ "$status" -eq 0 ]
    [ -f "$HOME/.cursor/rules/roboflow.mdc" ]
}

@test "rules: cursor install via main.sh skips rules at --global scope" {
    export ROBOFLOW_API_KEY=rf_test
    run bash "$RF_REPO_ROOT/installer/main.sh" --yes --host=cursor-desktop
    [ "$status" -eq 0 ]
    [ ! -f "$HOME/.cursor/rules/roboflow.mdc" ]
}

@test "rules: --no-rules skips rule install" {
    cd "$HOME"
    export ROBOFLOW_API_KEY=rf_test
    run bash "$RF_REPO_ROOT/installer/main.sh" --yes --host=cursor-desktop --project --no-rules
    [ "$status" -eq 0 ]
    [ ! -f "$HOME/.cursor/rules/roboflow.mdc" ]
}

@test "rules: --rules-only writes only rules (no MCP, no skills)" {
    cd "$HOME"
    export ROBOFLOW_API_KEY=rf_test
    run bash "$RF_REPO_ROOT/installer/main.sh" --yes --host=cursor-desktop --project --rules-only
    [ "$status" -eq 0 ]
    [ -f "$HOME/.cursor/rules/roboflow.mdc" ]
    [ ! -f "$HOME/.cursor/mcp.json" ]
    [ ! -d "$HOME/.claude/skills" ]
}

@test "rules: cursor uninstall --project removes rule file" {
    cd "$HOME"
    export ROBOFLOW_API_KEY=rf_test
    run bash "$RF_REPO_ROOT/installer/main.sh" --yes --host=cursor-desktop --project
    [ "$status" -eq 0 ]
    [ -f "$HOME/.cursor/rules/roboflow.mdc" ]
    run bash "$RF_REPO_ROOT/installer/main.sh" --yes --host=cursor-desktop --project --uninstall
    [ "$status" -eq 0 ]
    [ ! -f "$HOME/.cursor/rules/roboflow.mdc" ]
}
