#!/usr/bin/env bats
# Tests for the Claude Code CLI adapter (plugin install path).

load 'helpers/setup'

setup() {
    rf_test::isolated_home
    export NO_COLOR=1
    export ROBOFLOW_API_KEY=rf_test_key
}

teardown() {
    rf_test::cleanup_home
}

@test "claude install: dry-run does not invoke claude" {
    rf_test::stub_command "claude" 0
    run bash "$RF_REPO_ROOT/installer/main.sh" --yes --host=claude-code-cli --dry-run
    [ "$status" -eq 0 ]
    [ "$(rf_test::stub_call_count claude)" = "0" ]
    [[ "$output" == *"[dry-run]"* ]]
    [[ "$output" == *"plugin marketplace add"* ]]
    [[ "$output" == *"plugin install"* ]]
}

@test "claude install: invokes plugin marketplace add and plugin install" {
    rf_test::stub_command "claude" 0
    run bash "$RF_REPO_ROOT/installer/main.sh" --yes --host=claude-code-cli
    [ "$status" -eq 0 ]

    local calls
    calls="$(rf_test::stub_calls claude)"
    [[ "$calls" == *"plugin"* ]]
    [[ "$calls" == *"marketplace"* ]]
    [[ "$calls" == *"add"* ]]
    [[ "$calls" == *"roboflow/computer-vision-skills"* ]]
    [[ "$calls" == *"install"* ]]
    [[ "$calls" == *"roboflow"* ]]

    # Two calls: marketplace add + plugin install.
    [ "$(rf_test::stub_call_count claude)" -ge "2" ]
}

@test "claude install: writes a manifest entry" {
    rf_test::stub_command "claude" 0
    run bash "$RF_REPO_ROOT/installer/main.sh" --yes --host=claude-code-cli
    [ "$status" -eq 0 ]
    [ -f "$HOME/.config/roboflow/installations.json" ]
    grep -q '"host_id": "claude-code-cli"' "$HOME/.config/roboflow/installations.json"
    grep -q '"component": "plugin"' "$HOME/.config/roboflow/installations.json"
}

@test "claude install: --project sets scope local" {
    rf_test::stub_command "claude" 0
    run bash "$RF_REPO_ROOT/installer/main.sh" --yes --host=claude-code-cli --project
    [ "$status" -eq 0 ]
    local calls
    calls="$(rf_test::stub_calls claude)"
    [[ "$calls" == *"--scope"* ]]
    [[ "$calls" == *"local"* ]]
}

@test "claude install: missing claude exits non-zero with hint" {
    # No stub — claude not on PATH.
    
    run bash "$RF_REPO_ROOT/installer/main.sh" --yes --host=claude-code-cli
    [ "$status" -ne 0 ]
    [[ "$output" == *"claude not found on PATH"* ]]
}

@test "claude install: marketplace-add nonzero is treated as warning" {
    rf_test::stub_command "claude" 1 "" "already registered"
    # Stub returns 1 always, including for plugin install. Test should fail.
    run bash "$RF_REPO_ROOT/installer/main.sh" --yes --host=claude-code-cli
    [ "$status" -ne 0 ]
    # We still attempted both.
    [ "$(rf_test::stub_call_count claude)" -ge "2" ]
}

@test "claude uninstall: invokes plugin remove" {
    rf_test::stub_command "claude" 0
    run bash "$RF_REPO_ROOT/installer/main.sh" --yes --host=claude-code-cli --uninstall
    [ "$status" -eq 0 ]
    local calls
    calls="$(rf_test::stub_calls claude)"
    [[ "$calls" == *"plugin"* ]]
    [[ "$calls" == *"remove"* ]]
    [[ "$calls" == *"roboflow"* ]]
}

@test "claude install: re-run is idempotent" {
    rf_test::stub_command "claude" 0
    run bash "$RF_REPO_ROOT/installer/main.sh" --yes --host=claude-code-cli
    [ "$status" -eq 0 ]
    run bash "$RF_REPO_ROOT/installer/main.sh" --yes --host=claude-code-cli
    [ "$status" -eq 0 ]
    # Manifest should still exist with one claude-code-cli entry, not duplicated.
    local count
    count="$(grep -c '"host_id": "claude-code-cli"' "$HOME/.config/roboflow/installations.json")"
    [ "$count" -eq 1 ]
}
