#!/usr/bin/env bash
# common.sh — logging, prompts, atomic writes, backups.
# Sourced by main.sh and host adapters.

# Colors (suppressed if NO_COLOR set or stdout not a tty).
# RF_COLOR_* are referenced from host adapters; shellcheck can't follow that
# across files, so silence the unused-variable warnings here.
# shellcheck disable=SC2034
{
    if [[ -z "${NO_COLOR:-}" ]] && [[ -t 1 ]]; then
        RF_COLOR_RESET=$'\033[0m'
        RF_COLOR_BOLD=$'\033[1m'
        RF_COLOR_DIM=$'\033[2m'
        RF_COLOR_RED=$'\033[31m'
        RF_COLOR_GREEN=$'\033[32m'
        RF_COLOR_YELLOW=$'\033[33m'
        RF_COLOR_BLUE=$'\033[34m'
        RF_COLOR_CYAN=$'\033[36m'
    else
        RF_COLOR_RESET=
        RF_COLOR_BOLD=
        RF_COLOR_DIM=
        RF_COLOR_RED=
        RF_COLOR_GREEN=
        RF_COLOR_YELLOW=
        RF_COLOR_BLUE=
        RF_COLOR_CYAN=
    fi
}

rf::info() { printf '%s\n' "$*" >&2; }
rf::step() { printf '%s→%s %s\n' "$RF_COLOR_BLUE" "$RF_COLOR_RESET" "$*" >&2; }
rf::ok() { printf '%s✓%s %s\n' "$RF_COLOR_GREEN" "$RF_COLOR_RESET" "$*" >&2; }
rf::warn() { printf '%s!%s %s\n' "$RF_COLOR_YELLOW" "$RF_COLOR_RESET" "$*" >&2; }
rf::err() { printf '%s✗%s %s\n' "$RF_COLOR_RED" "$RF_COLOR_RESET" "$*" >&2; }
rf::dim() { printf '%s%s%s\n' "$RF_COLOR_DIM" "$*" "$RF_COLOR_RESET" >&2; }
rf::header() { printf '\n%s%s%s\n' "$RF_COLOR_BOLD" "$*" "$RF_COLOR_RESET" >&2; }

rf::die() {
    rf::err "$*"
    exit "${RF_EXIT_CODE:-1}"
}

# rf::confirm <prompt>  — returns 0 for yes, 1 for no. Auto-yes if RF_YES=1.
rf::confirm() {
    if [[ "${RF_YES:-0}" == "1" ]]; then
        return 0
    fi
    local prompt="$1" reply
    read -r -p "$prompt [y/N] " reply </dev/tty
    [[ "$reply" =~ ^[Yy] ]]
}

# rf::prompt <prompt> [default]  — read a line from /dev/tty.
rf::prompt() {
    local prompt="$1" default="${2:-}" reply
    if [[ -n "$default" ]]; then
        read -r -p "$prompt [$default] " reply </dev/tty || reply=""
        [[ -z "$reply" ]] && reply="$default"
    else
        read -r -p "$prompt " reply </dev/tty
    fi
    printf '%s' "$reply"
}

# rf::prompt_secret <prompt>  — silent read for API keys.
rf::prompt_secret() {
    local prompt="$1" reply
    read -r -s -p "$prompt " reply </dev/tty
    printf '\n' >&2
    printf '%s' "$reply"
}

# rf::backup <file>  — copy <file> to <file>.bak.<UTC ISO> if it exists. Echoes the backup path.
rf::backup() {
    local file="$1"
    [[ -e "$file" ]] || return 0
    local stamp
    stamp="$(date -u +%Y%m%dT%H%M%SZ)"
    local bak="${file}.bak.${stamp}"
    cp -p "$file" "$bak"
    printf '%s' "$bak"
}

# rf::atomic_write <target> <content>  — write content to a temp file in the same dir, then mv into place.
# Use with stdin via heredoc or piped content for binary safety.
rf::atomic_write() {
    local target="$1"
    local dir
    dir="$(dirname "$target")"
    mkdir -p "$dir"
    local tmp
    tmp="$(mktemp "${dir}/.atomic.XXXXXX")"
    cat >"$tmp"
    mv "$tmp" "$target"
}

# rf::ensure_dir <path>
rf::ensure_dir() {
    [[ -d "$1" ]] || mkdir -p "$1"
}

# rf::on_path <cmd>  — 0 if cmd is on PATH, 1 otherwise.
rf::on_path() {
    command -v "$1" >/dev/null 2>&1
}

# rf::is_macos / rf::is_linux / rf::is_windows
rf::is_macos() { [[ "$(uname -s)" == "Darwin" ]]; }
rf::is_linux() { [[ "$(uname -s)" == "Linux" ]]; }
rf::is_windows() { [[ "$(uname -s)" =~ ^(MINGW|MSYS|CYGWIN) ]]; }
