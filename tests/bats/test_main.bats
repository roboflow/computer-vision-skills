#!/usr/bin/env bats
# Tests for argument parsing, help/version output, and unknown-flag handling.

load 'helpers/setup'

setup() {
    rf_test::isolated_home
    export NO_COLOR=1
}

teardown() {
    rf_test::cleanup_home
}

@test "main.sh --help exits 0 with usage" {
    run bash "$RF_REPO_ROOT/installer/main.sh" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"agents.sh"* ]]
    [[ "$output" == *"--host="* ]]
    [[ "$output" == *"claude-code-cli"* ]]
}

@test "main.sh --version prints installer version" {
    run bash "$RF_REPO_ROOT/installer/main.sh" --version
    [ "$status" -eq 0 ]
    [[ "$output" == *"installer"* ]]
}

@test "main.sh unknown flag exits 2" {
    run bash "$RF_REPO_ROOT/installer/main.sh" --bogus-flag
    [ "$status" -eq 2 ]
    [[ "$output" == *"unknown flag"* ]]
}

@test "main.sh --project --inline-key conflict exits 4" {
    run bash "$RF_REPO_ROOT/installer/main.sh" --project --inline-key
    [ "$status" -eq 4 ]
    [[ "$output" == *"--inline-key is only allowed with --global"* ]]
}

@test "main.sh with no detected hosts exits 3" {
    # No stubs, so claude/codex are not on PATH.
    
    run bash "$RF_REPO_ROOT/installer/main.sh" --yes --auth-skip
    [ "$status" -eq 3 ]
    [[ "$output" == *"no supported coding agents"* ]]
}

@test "main.sh --host with unknown id exits 2" {
    run bash "$RF_REPO_ROOT/installer/main.sh" --yes --host=nonexistent-cli --auth-skip
    [ "$status" -eq 2 ]
    [[ "$output" == *"unknown host id"* ]]
}
