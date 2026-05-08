#!/usr/bin/env bats
# Tests for host detection.

load 'helpers/setup'

setup() {
    rf_test::isolated_home
    export NO_COLOR=1
    # shellcheck disable=SC1091
    source "$RF_REPO_ROOT/installer/lib/common.sh"
    # shellcheck disable=SC1091
    source "$RF_REPO_ROOT/installer/lib/detect.sh"
}

teardown() {
    rf_test::cleanup_home
}

@test "detect::all is empty when no agents are on PATH" {
    
    run rf::detect::all
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "detect::all reports claude when claude is on PATH" {
    rf_test::stub_command "claude" 0 "1.0.0"
    run rf::detect::all
    [ "$status" -eq 0 ]
    [[ "$output" == *"claude-code-cli|cli|"* ]]
}

@test "detect::all reports codex when codex is on PATH" {
    rf_test::stub_command "codex" 0 "0.5.0"
    run rf::detect::all
    [ "$status" -eq 0 ]
    [[ "$output" == *"codex-cli|cli|"* ]]
}

@test "detect::all reports both when both are on PATH" {
    rf_test::stub_command "claude" 0 "1.0.0"
    rf_test::stub_command "codex" 0 "0.5.0"
    run rf::detect::all
    [ "$status" -eq 0 ]
    [[ "$output" == *"claude-code-cli"* ]]
    [[ "$output" == *"codex-cli"* ]]
}

@test "detect::known_ids includes phase 1 + 2 hosts" {
    run rf::detect::known_ids
    [ "$status" -eq 0 ]
    [[ "$output" == *"claude-code-cli"* ]]
    [[ "$output" == *"codex-cli"* ]]
    [[ "$output" == *"cursor-desktop"* ]]
    [[ "$output" == *"claude-desktop"* ]]
    [[ "$output" == *"copilot-cli"* ]]
}

@test "detect::lookup recognizes phase 2 host ids" {
    run rf::detect::lookup cursor-desktop
    [ "$status" -eq 0 ]
    run rf::detect::lookup claude-desktop
    [ "$status" -eq 0 ]
    run rf::detect::lookup copilot-cli
    [ "$status" -eq 0 ]
}

@test "detect::copilot_cli reports when copilot is on PATH" {
    rf_test::stub_command "copilot" 0 "1.0.0"
    run rf::detect::copilot_cli
    [ "$status" -eq 0 ]
    [[ "$output" == *"copilot-cli|cli"* ]]
}

@test "detect::lookup returns line for known id with cmd available" {
    rf_test::stub_command "claude" 0 "1.0.0"
    run rf::detect::lookup claude-code-cli
    [ "$status" -eq 0 ]
    [[ "$output" == *"claude-code-cli|cli"* ]]
}

@test "detect::lookup returns empty for known id without cmd" {
    
    run rf::detect::lookup claude-code-cli
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "detect::lookup returns nonzero for unknown id" {
    run rf::detect::lookup totally-fake
    [ "$status" -ne 0 ]
}
