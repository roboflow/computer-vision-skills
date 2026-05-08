#!/usr/bin/env bats
# Tests for the Codex CLI adapter (marketplace registration path).

load 'helpers/setup'

setup() {
    rf_test::isolated_home
    export NO_COLOR=1
    export ROBOFLOW_API_KEY=rf_test_key
}

teardown() {
    rf_test::cleanup_home
}

@test "codex install: dry-run does not invoke codex" {
    rf_test::stub_command "codex" 0
    run bash "$RF_REPO_ROOT/installer/main.sh" --yes --host=codex-cli --dry-run
    [ "$status" -eq 0 ]
    [ "$(rf_test::stub_call_count codex)" = "0" ]
    [[ "$output" == *"[dry-run]"* ]]
    [[ "$output" == *"plugin marketplace add"* ]]
}

@test "codex install: invokes plugin marketplace add" {
    rf_test::stub_command "codex" 0
    run bash "$RF_REPO_ROOT/installer/main.sh" --yes --host=codex-cli
    [ "$status" -eq 0 ]
    local calls
    calls="$(rf_test::stub_calls codex)"
    [[ "$calls" == *"plugin"* ]]
    [[ "$calls" == *"marketplace"* ]]
    [[ "$calls" == *"add"* ]]
    [[ "$calls" == *"roboflow/computer-vision-skills"* ]]
}

@test "codex install: prints next-steps for /plugins" {
    rf_test::stub_command "codex" 0
    run bash "$RF_REPO_ROOT/installer/main.sh" --yes --host=codex-cli
    [ "$status" -eq 0 ]
    [[ "$output" == *"/plugins"* ]]
    [[ "$output" == *"Roboflow"* ]]
}

@test "codex install: writes manifest entry with manual_step note" {
    rf_test::stub_command "codex" 0
    run bash "$RF_REPO_ROOT/installer/main.sh" --yes --host=codex-cli
    [ "$status" -eq 0 ]
    [ -f "$HOME/.config/roboflow/installations.json" ]
    grep -q '"host_id": "codex-cli"' "$HOME/.config/roboflow/installations.json"
    grep -q '"manual_step"' "$HOME/.config/roboflow/installations.json"
}

@test "codex install: missing codex exits non-zero with hint" {
    
    run bash "$RF_REPO_ROOT/installer/main.sh" --yes --host=codex-cli
    [ "$status" -ne 0 ]
    [[ "$output" == *"codex not found on PATH"* ]]
}

@test "codex uninstall: invokes plugin marketplace remove" {
    rf_test::stub_command "codex" 0
    run bash "$RF_REPO_ROOT/installer/main.sh" --yes --host=codex-cli --uninstall
    [ "$status" -eq 0 ]
    local calls
    calls="$(rf_test::stub_calls codex)"
    [[ "$calls" == *"plugin"* ]]
    [[ "$calls" == *"marketplace"* ]]
    [[ "$calls" == *"remove"* ]]
    [[ "$calls" == *"roboflow"* ]]
}
