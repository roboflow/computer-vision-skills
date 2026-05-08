#!/usr/bin/env bats
# Tests for lib/skills.sh — copy from $RF_REPO_DIR/skills, content_hash,
# update / pristine-vs-edited handling, reconcile-on-removed.

load 'helpers/setup'

# Build a fake source tree at $RF_TEST_HOME/repo/skills with two skills.
rf_test::fake_skills_repo() {
    local root="$RF_TEST_HOME/repo"
    mkdir -p "$root/skills/alpha" "$root/skills/beta"
    cat >"$root/skills/alpha/SKILL.md" <<'EOF'
---
name: alpha
description: alpha test skill
---
alpha body v1
EOF
    cat >"$root/skills/alpha/extra.md" <<'EOF'
alpha extra v1
EOF
    cat >"$root/skills/beta/SKILL.md" <<'EOF'
---
name: beta
description: beta test skill
---
beta body v1
EOF
    export RF_REPO_DIR="$root"
}

setup() {
    rf_test::isolated_home
    export NO_COLOR=1
    # shellcheck disable=SC1091
    source "$RF_REPO_ROOT/installer/lib/common.sh"
    # shellcheck disable=SC1091
    source "$RF_REPO_ROOT/installer/lib/json_io.sh"
    # shellcheck disable=SC1091
    source "$RF_REPO_ROOT/installer/lib/auth.sh"
    # shellcheck disable=SC1091
    source "$RF_REPO_ROOT/installer/lib/manifest.sh"
    # shellcheck disable=SC1091
    source "$RF_REPO_ROOT/installer/lib/skills.sh"
    rf_test::fake_skills_repo
    RF_OPT_FORCE_SKILLS=()
    export RF_INSTALLER_VERSION="0.1.0-test"
}

teardown() {
    rf_test::cleanup_home
}

@test "skills: list_upstream returns alpha and beta" {
    run rf::skills::list_upstream
    [ "$status" -eq 0 ]
    [[ "$output" == *"alpha"* ]]
    [[ "$output" == *"beta"* ]]
}

@test "skills: install_all copies every skill into dest" {
    local dest="$HOME/.claude/skills"
    rf::skills::install_all "$dest" "test-host" "global"
    [ -f "$dest/alpha/SKILL.md" ]
    [ -f "$dest/alpha/extra.md" ]
    [ -f "$dest/beta/SKILL.md" ]
    [ -f "$dest/alpha/.roboflow-install-manifest.json" ]
    [ -f "$dest/beta/.roboflow-install-manifest.json" ]
}

@test "skills: install_one writes content_hash sidecar" {
    local dest="$HOME/.claude/skills"
    rf::skills::install_one alpha "$dest" "test-host" "global"
    grep -q '"content_hash": "sha256:' "$dest/alpha/.roboflow-install-manifest.json"
    grep -q '"skill_name": "alpha"' "$dest/alpha/.roboflow-install-manifest.json"
}

@test "skills: re-install on pristine skill is a refresh (no warning)" {
    local dest="$HOME/.claude/skills"
    rf::skills::install_all "$dest" "test-host" "global"
    # Modify upstream
    echo "v2 update" >>"$RF_REPO_DIR/skills/alpha/SKILL.md"
    run rf::skills::install_all "$dest" "test-host" "global"
    [ "$status" -eq 0 ]
    # The new line should be in dest
    grep -q "v2 update" "$dest/alpha/SKILL.md"
}

@test "skills: re-install preserves user-edited skill (warns)" {
    local dest="$HOME/.claude/skills"
    rf::skills::install_all "$dest" "test-host" "global"
    # User edit
    echo "user note" >>"$dest/alpha/SKILL.md"
    # Upstream changes too
    echo "upstream v2" >>"$RF_REPO_DIR/skills/alpha/SKILL.md"
    run rf::skills::install_all "$dest" "test-host" "global"
    [ "$status" -eq 0 ]
    [[ "$output" == *"local edits"* ]]
    grep -q "user note" "$dest/alpha/SKILL.md"
    if grep -q "upstream v2" "$dest/alpha/SKILL.md"; then return 1; fi
}

@test "skills: --force-skill overwrites edited skill" {
    local dest="$HOME/.claude/skills"
    rf::skills::install_all "$dest" "test-host" "global"
    echo "user note" >>"$dest/alpha/SKILL.md"
    echo "upstream v2" >>"$RF_REPO_DIR/skills/alpha/SKILL.md"
    RF_OPT_FORCE_SKILLS=("alpha")
    rf::skills::install_all "$dest" "test-host" "global"
    if grep -q "user note" "$dest/alpha/SKILL.md"; then return 1; fi
    grep -q "upstream v2" "$dest/alpha/SKILL.md"
}

@test "skills: reconcile removes obsolete Roboflow-managed skill" {
    local dest="$HOME/.claude/skills"
    rf::skills::install_all "$dest" "test-host" "global"
    # Upstream loses 'beta'
    rm -rf "$RF_REPO_DIR/skills/beta"
    rf::skills::install_all "$dest" "test-host" "global"
    # alpha still there, beta gone (or backed up)
    [ -d "$dest/alpha" ]
    [ ! -d "$dest/beta" ]
    # Backup created
    local bak
    bak="$(find "$dest" -maxdepth 1 -name 'beta.bak.*' | head -n1)"
    [ -n "$bak" ]
}

@test "skills: reconcile leaves user-installed (non-managed) skill alone" {
    local dest="$HOME/.claude/skills"
    rf::skills::install_all "$dest" "test-host" "global"
    # User adds their own skill — no sidecar
    mkdir -p "$dest/user-skill"
    echo "mine" >"$dest/user-skill/SKILL.md"
    # Upstream loses beta (irrelevant) and we re-install
    rm -rf "$RF_REPO_DIR/skills/beta"
    rf::skills::install_all "$dest" "test-host" "global"
    [ -d "$dest/user-skill" ]
    [ -f "$dest/user-skill/SKILL.md" ]
}

@test "skills: dry-run does not copy" {
    local dest="$HOME/.claude/skills"
    export RF_OPT_DRY_RUN=1
    rf::skills::install_all "$dest" "test-host" "global"
    [ ! -d "$dest/alpha" ]
}

@test "skills: remove_all removes managed and leaves non-managed" {
    local dest="$HOME/.claude/skills"
    rf::skills::install_all "$dest" "test-host" "global"
    mkdir -p "$dest/user-skill"
    echo "mine" >"$dest/user-skill/SKILL.md"
    rf::skills::remove_all "$dest" "test-host" "global"
    [ ! -d "$dest/alpha" ]
    [ ! -d "$dest/beta" ]
    [ -d "$dest/user-skill" ]
}

@test "skills: remove keeps user-edited managed skill unless --force" {
    local dest="$HOME/.claude/skills"
    rf::skills::install_all "$dest" "test-host" "global"
    echo "user note" >>"$dest/alpha/SKILL.md"
    rf::skills::remove_all "$dest" "test-host" "global"
    # alpha should still exist (edited; not removed)
    [ -d "$dest/alpha" ]
    # beta (pristine) should be removed
    [ ! -d "$dest/beta" ]
}

@test "skills: remove with --force drops edited skill too" {
    local dest="$HOME/.claude/skills"
    rf::skills::install_all "$dest" "test-host" "global"
    echo "user note" >>"$dest/alpha/SKILL.md"
    export RF_OPT_FORCE=1
    rf::skills::remove_all "$dest" "test-host" "global"
    [ ! -d "$dest/alpha" ]
    [ ! -d "$dest/beta" ]
}
