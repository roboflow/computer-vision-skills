#!/usr/bin/env bats
# Tests for installer/lib/prereq.sh — Node.js prerequisite detection +
# auto-install dispatch.
#
# We never actually run brew / nvm / curl-pipes during tests — stubs catch
# the would-be invocations and confirm the right path was taken.

load 'helpers/setup'

setup() {
    rf_test::isolated_home
    export NO_COLOR=1
    # shellcheck disable=SC1091
    source "$RF_REPO_ROOT/installer/lib/common.sh"
    # shellcheck disable=SC1091
    source "$RF_REPO_ROOT/installer/lib/prereq.sh"
}

teardown() {
    rf_test::cleanup_home
}

# --- host-needs-node lookups --------------------------------------------

@test "host_needs_node: claude-code-cli, codex-cli, claude-desktop need Node" {
    rf::prereq::host_needs_node claude-code-cli
    rf::prereq::host_needs_node codex-cli
    rf::prereq::host_needs_node claude-desktop
}

@test "host_needs_node: cursor / gemini / copilot / windsurf / vscode / opencode do not" {
    ! rf::prereq::host_needs_node cursor-desktop
    ! rf::prereq::host_needs_node gemini-cli
    ! rf::prereq::host_needs_node copilot-cli
    ! rf::prereq::host_needs_node windsurf-desktop
    ! rf::prereq::host_needs_node vscode-copilot
    ! rf::prereq::host_needs_node opencode-cli
}

@test "any_needs_node: true if at least one selected host needs Node" {
    rf::prereq::any_needs_node cursor-desktop claude-code-cli gemini-cli
    rf::prereq::any_needs_node claude-desktop
    ! rf::prereq::any_needs_node cursor-desktop gemini-cli opencode-cli
}

# --- ensure_npx happy path: already installed ---------------------------

@test "ensure_npx: skips install when npx is on PATH" {
    rf_test::stub_command "npx" 0 "10.5.0"
    rf_test::stub_command "brew" 0
    run rf::prereq::ensure_npx
    [ "$status" -eq 0 ]
    # brew should NOT have been invoked
    [ "$(rf_test::stub_call_count brew)" = "0" ]
}

# --- ensure_npx: refuse if --no-install-node ----------------------------

@test "ensure_npx: --no-install-node fails without installing" {
    # npx NOT stubbed → not on PATH
    export RF_OPT_NO_INSTALL_NODE=1
    rf_test::stub_command "brew" 0
    run rf::prereq::ensure_npx
    [ "$status" -ne 0 ]
    [[ "$output" == *"--no-install-node"* ]]
    [ "$(rf_test::stub_call_count brew)" = "0" ]
}

# --- ensure_npx --dry-run -----------------------------------------------

@test "ensure_npx: --dry-run reports plan, no install" {
    export RF_OPT_DRY_RUN=1
    rf_test::stub_command "brew" 0
    run rf::prereq::ensure_npx
    [ "$status" -eq 0 ]
    [[ "$output" == *"[dry-run] would install Node.js LTS"* ]]
    [ "$(rf_test::stub_call_count brew)" = "0" ]
}

# --- ensure_npx --yes --------------------------------------------------

@test "ensure_npx: --yes + brew on macOS uses brew install node" {
    # Skip on non-macOS runners — the brew branch is gated on rf::is_macos.
    [[ "$(uname -s)" == "Darwin" ]] || skip "macOS-only branch"

    rf_test::stub_command "brew" 0
    # After "brew install node" runs the stub, npx still won't appear on PATH
    # (we don't actually install anything in tests), so ensure_npx returns 1
    # in the post-install check. That's expected — we just want to verify
    # that brew WAS invoked with the right args.
    export RF_YES=1
    run rf::prereq::ensure_npx
    # exit status is non-zero because npx isn't actually appearing, but
    # the install branch should have been taken
    local calls
    calls="$(rf_test::stub_calls brew)"
    [[ "$calls" == *"install"* ]]
    [[ "$calls" == *"node"* ]]
}

@test "node_method_label: brew when available on macOS, nvm otherwise" {
    [[ "$(uname -s)" == "Darwin" ]] || skip "macOS-only"
    rf_test::stub_command "brew" 0
    [[ "$(rf::prereq::node_method_label)" == *"Homebrew"* ]]
}

@test "node_method_label: nvm fallback when brew missing" {
    # No brew stub
    [[ "$(rf::prereq::node_method_label)" == *"nvm"* ]]
}

# Note: we don't end-to-end-test the actual `curl | bash | nvm` install
# pipeline — stubbing `bash` interferes with bats's own test runner.
# install_node_unix is a 6-line wrapper around well-known commands; the
# branching it makes (brew vs nvm) is covered by node_method_label.
