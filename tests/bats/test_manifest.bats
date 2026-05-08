#!/usr/bin/env bats
# Tests for the installations.json manifest read/write/remove.

load 'helpers/setup'

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
}

teardown() {
    rf_test::cleanup_home
}

@test "manifest: ensure creates file with empty installations" {
    rf::manifest::ensure
    local path
    path="$(rf::manifest::path)"
    [ -f "$path" ]
    grep -q '"installations": \[\]' "$path"
    grep -q '"schema_version": 1' "$path"
}

@test "manifest: record adds an entry" {
    rf::manifest::record '{"host_id":"claude-code-cli","component":"plugin","scope":"global"}'
    local path
    path="$(rf::manifest::path)"
    grep -q '"host_id": "claude-code-cli"' "$path"
    grep -q '"component": "plugin"' "$path"
}

@test "manifest: record replaces same key on duplicate" {
    rf::manifest::record '{"host_id":"claude-code-cli","component":"plugin","scope":"global","plugin_name":"v1"}'
    rf::manifest::record '{"host_id":"claude-code-cli","component":"plugin","scope":"global","plugin_name":"v2"}'
    local path
    path="$(rf::manifest::path)"
    local v1_count v2_count
    v1_count="$(grep -c '"plugin_name": "v1"' "$path" || true)"
    v2_count="$(grep -c '"plugin_name": "v2"' "$path" || true)"
    [ "$v1_count" -eq 0 ]
    [ "$v2_count" -eq 1 ]
}

@test "manifest: record adds different scopes as separate entries" {
    rf::manifest::record '{"host_id":"claude-code-cli","component":"plugin","scope":"global"}'
    rf::manifest::record '{"host_id":"claude-code-cli","component":"plugin","scope":"project"}'
    local path
    path="$(rf::manifest::path)"
    local count
    count="$(grep -c '"host_id": "claude-code-cli"' "$path")"
    [ "$count" -eq 2 ]
}

@test "manifest: remove drops matching entry only" {
    rf::manifest::record '{"host_id":"claude-code-cli","component":"plugin","scope":"global"}'
    rf::manifest::record '{"host_id":"codex-cli","component":"plugin","scope":"global"}'
    rf::manifest::remove claude-code-cli plugin global
    local path
    path="$(rf::manifest::path)"
    [ "$(grep -c '"host_id": "claude-code-cli"' "$path")" -eq 0 ]
    [ "$(grep -c '"host_id": "codex-cli"' "$path")" -eq 1 ]
}

@test "manifest: list filters by host" {
    rf::manifest::record '{"host_id":"claude-code-cli","component":"plugin","scope":"global"}'
    rf::manifest::record '{"host_id":"codex-cli","component":"plugin","scope":"global"}'
    run rf::manifest::list claude-code-cli
    [ "$status" -eq 0 ]
    [[ "$output" == *"claude-code-cli"* ]]
    [[ "$output" != *"codex-cli"* ]]
}
