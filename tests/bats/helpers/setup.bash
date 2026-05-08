#!/usr/bin/env bash
# Shared bats setup helpers.

# RF_REPO_ROOT — absolute path to the repo root. Tests use this to invoke
# agents.sh / installer/main.sh from a known location regardless of cwd.
RF_REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
export RF_REPO_ROOT

# RF_SYSTEM_PATH — minimal PATH segments that always need to remain available
# (mktemp, rm, cat, bash, etc.). Tests can prepend a stub bin dir but should
# always include this so teardown and bats internals work.
RF_SYSTEM_PATH="/usr/bin:/bin:/usr/sbin:/sbin"
export RF_SYSTEM_PATH

# rf_test::isolated_home — give each test a fresh HOME with empty ~/.config.
# Call from setup(). Cleanup happens via teardown().
rf_test::isolated_home() {
    RF_TEST_HOME="$(mktemp -d "${BATS_TMPDIR:-/tmp}/rf-home.XXXXXX")"
    export HOME="$RF_TEST_HOME"
    export XDG_CACHE_HOME="$RF_TEST_HOME/.cache"
    mkdir -p "$RF_TEST_HOME/.config" "$RF_TEST_HOME/bin"
    # Reset any inherited Roboflow env so fixture state controls behavior.
    unset ROBOFLOW_API_KEY ROBOFLOW_CONFIG_DIR
    # Default PATH: stub bin (test-controlled) + system bin (so bash, rm, etc.
    # remain available). Excludes /usr/local/bin and /opt/homebrew/bin so the
    # user's real `claude` / `codex` don't leak into tests.
    export PATH="$RF_TEST_HOME/bin:$RF_SYSTEM_PATH"
    export RF_INSTALLER_DIR="$RF_REPO_ROOT/installer"
    export RF_REPO_DIR="$RF_REPO_ROOT"
}

rf_test::cleanup_home() {
    if [[ -n "${RF_TEST_HOME:-}" ]] && [[ -d "$RF_TEST_HOME" ]]; then
        rm -rf "$RF_TEST_HOME"
    fi
}

# rf_test::stub_command <name> [<exit_code>] [<stdout>] [<stderr>]
#
# Drop a stub binary on PATH that records its argv to
# $RF_TEST_HOME/.stubs/<name>.calls (one invocation per file via timestamped
# filenames so multiple calls all get captured). Tests can then read those
# files to assert what was invoked.
rf_test::stub_command() {
    local name="$1" code="${2:-0}" out="${3:-}" err="${4:-}"
    local calls_dir="$RF_TEST_HOME/.stubs/${name}.calls"
    mkdir -p "$calls_dir"
    local stub_path="$RF_TEST_HOME/bin/$name"
    cat >"$stub_path" <<STUB
#!/usr/bin/env bash
ts="\$(date +%s%N)"
{
    printf '%s\n' "\$0 \$*"
    for a in "\$@"; do printf 'arg: %s\n' "\$a"; done
} > "$calls_dir/\$ts.\$\$"
STUB
    if [[ -n "$out" ]]; then
        printf 'printf %q\n' "$out" >>"$stub_path"
    fi
    if [[ -n "$err" ]]; then
        printf 'printf %q >&2\n' "$err" >>"$stub_path"
    fi
    printf 'exit %s\n' "$code" >>"$stub_path"
    chmod +x "$stub_path"
}

rf_test::stub_calls() {
    local name="$1"
    local calls_dir="$RF_TEST_HOME/.stubs/${name}.calls"
    [[ -d "$calls_dir" ]] || return 0
    cat "$calls_dir"/* 2>/dev/null
}

rf_test::stub_call_count() {
    local name="$1"
    local calls_dir="$RF_TEST_HOME/.stubs/${name}.calls"
    [[ -d "$calls_dir" ]] || { printf '0'; return; }
    find "$calls_dir" -type f | wc -l | tr -d '[:space:]'
}

# rf_test::main_sh — print the path to installer/main.sh. Use with `run bash $(rf_test::main_sh) ...`
# to keep `run` happy (bats's run can't see test-helper functions in the subshell).
rf_test::main_sh() {
    printf '%s' "$RF_REPO_ROOT/installer/main.sh"
}
