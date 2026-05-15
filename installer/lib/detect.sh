#!/usr/bin/env bash
# detect.sh — locate installed coding agents.
#
# Each detect function prints a single line "id|kind|label|hint" if found,
# nothing if not. Higher-level rf::detect::all aggregates them.
#
# id: stable host id used elsewhere (matches installer/hosts/<id>.sh)
# kind: cli | desktop
# label: human-readable name
# hint: short note about how it was detected (path, version, etc.)

# rf::resolve_claude_cli — print the path/name we should use to invoke
# `claude`, or nothing if Claude Code isn't installed. Cached in
# $_RF_CLAUDE_CLI_PATH so repeat calls within one run don't re-stat the FS.
#
# Lookup order:
#   1. `claude` on PATH (npm/global install).
#   2. macOS Anthropic installer / Claude Desktop CLI bundle:
#      ~/Library/Application Support/Claude/claude-code/<ver>/claude
#   3. Linux native install:
#      ~/.local/share/anthropic-claude/claude-code/<ver>/claude
#      ~/.config/Claude/claude-code/<ver>/claude
#   4. Common Unix prefix fallbacks (Homebrew, /usr/local).
#
# On Windows-via-bash (Git Bash / MSYS) we also try the same %APPDATA%
# location the PowerShell installer probes, since users sometimes pipe
# agents.sh through bash on Windows.
rf::resolve_claude_cli() {
    if [[ -n "${_RF_CLAUDE_CLI_PATH:-}" ]]; then
        printf '%s\n' "$_RF_CLAUDE_CLI_PATH"
        return 0
    fi

    if rf::on_path claude; then
        _RF_CLAUDE_CLI_PATH="claude"
        printf '%s\n' "$_RF_CLAUDE_CLI_PATH"
        return 0
    fi

    # bats tests set RF_TEST_NO_DETECT_APPS=1 to suppress probes that would
    # find the developer's real Anthropic install. PATH lookup above is
    # already isolated by the harness; install-dir probes are not.
    [[ "${RF_TEST_NO_DETECT_APPS:-}" == "1" ]] && return 1

    local candidates=() versioned_root=""
    if rf::is_macos; then
        versioned_root="$HOME/Library/Application Support/Claude/claude-code"
    elif rf::is_linux; then
        # Prefer XDG layout; fall back to ~/.config/Claude (parity with the
        # Windows %APPDATA%\Claude path).
        if [[ -d "$HOME/.local/share/anthropic-claude/claude-code" ]]; then
            versioned_root="$HOME/.local/share/anthropic-claude/claude-code"
        elif [[ -d "$HOME/.config/Claude/claude-code" ]]; then
            versioned_root="$HOME/.config/Claude/claude-code"
        fi
    elif rf::is_windows; then
        # MSYS / Git Bash: APPDATA is a Windows path. Convert with a leading
        # slash so bash globbing works; cygpath isn't always available.
        local appdata="${APPDATA:-$HOME/AppData/Roaming}"
        # MSYS-style: /c/Users/... — translate drive letter if needed.
        appdata="${appdata//\\//}"
        versioned_root="$appdata/Claude/claude-code"
    fi

    if [[ -n "$versioned_root" && -d "$versioned_root" ]]; then
        # Sort numerically by dotted version. `sort -V` is GNU-specific but
        # ships on macOS 11+; fall back to lex sort if -V isn't supported.
        local sorter="sort -V"
        if ! printf '1.0\n' | sort -V >/dev/null 2>&1; then sorter="sort"; fi
        local latest
        latest="$(
            find "$versioned_root" -mindepth 1 -maxdepth 1 -type d 2>/dev/null \
                | $sorter \
                | tail -n1
        )"
        if [[ -n "$latest" ]]; then
            local exe="$latest/claude"
            if rf::is_windows; then exe="$latest/claude.exe"; fi
            if [[ -x "$exe" || -f "$exe" ]]; then
                _RF_CLAUDE_CLI_PATH="$exe"
                printf '%s\n' "$_RF_CLAUDE_CLI_PATH"
                return 0
            fi
        fi
    fi

    candidates+=(
        '/opt/homebrew/bin/claude'
        '/usr/local/bin/claude'
        "$HOME/.local/bin/claude"
    )
    for c in "${candidates[@]}"; do
        if [[ -x "$c" ]]; then
            _RF_CLAUDE_CLI_PATH="$c"
            printf '%s\n' "$_RF_CLAUDE_CLI_PATH"
            return 0
        fi
    done

    return 1
}

rf::detect::claude_code_cli() {
    local claude
    claude="$(rf::resolve_claude_cli)" || return 0
    local v on_path_suffix=""
    v="$("$claude" --version 2>/dev/null | head -n1 || true)"
    if [[ "$claude" != "claude" ]]; then on_path_suffix=" (not on PATH)"; fi
    printf 'claude-code-cli|cli|Claude Code CLI|%s%s\n' "${v:-detected}" "$on_path_suffix"
}

rf::detect::codex_cli() {
    if rf::on_path codex; then
        local v
        v="$(codex --version 2>/dev/null | head -n1 || true)"
        printf 'codex-cli|cli|Codex CLI|%s\n' "${v:-detected on PATH}"
    fi
}

rf::detect::cursor_desktop() {
    [[ "${RF_TEST_NO_DETECT_APPS:-}" == "1" ]] && return 0
    local hint=""
    if rf::is_macos && [[ -d "/Applications/Cursor.app" ]]; then
        hint="/Applications/Cursor.app"
    elif rf::is_linux && { [[ -d "$HOME/.config/Cursor" ]] || [[ -d "$HOME/.cursor" ]]; }; then
        hint="${HOME}/.config/Cursor"
    elif rf::is_windows && [[ -d "${LOCALAPPDATA:-$HOME/AppData/Local}/Programs/cursor" ]]; then
        hint="${LOCALAPPDATA:-$HOME/AppData/Local}/Programs/cursor"
    elif rf::on_path cursor; then
        hint="cursor on PATH"
    else
        return 0
    fi
    printf 'cursor-desktop|desktop|Cursor|%s\n' "$hint"
}

rf::detect::claude_desktop() {
    [[ "${RF_TEST_NO_DETECT_APPS:-}" == "1" ]] && return 0
    local hint=""
    if rf::is_macos && [[ -d "/Applications/Claude.app" ]]; then
        hint="/Applications/Claude.app"
    elif rf::is_linux && [[ -d "$HOME/.config/Claude" ]]; then
        hint="${HOME}/.config/Claude"
    elif rf::is_windows && [[ -d "${APPDATA:-$HOME/AppData/Roaming}/Claude" ]]; then
        hint="${APPDATA:-$HOME/AppData/Roaming}/Claude"
    else
        return 0
    fi
    printf 'claude-desktop|desktop|Claude Desktop|%s\n' "$hint"
}

rf::detect::copilot_cli() {
    if rf::on_path copilot; then
        local v
        v="$(copilot --version 2>/dev/null | head -n1 || true)"
        printf 'copilot-cli|cli|GitHub Copilot CLI|%s\n' "${v:-detected on PATH}"
        return 0
    fi
    if rf::on_path gh; then
        # Drain the pipe (no `-q`) so we don't trip `pipefail` via SIGPIPE.
        if gh extension list 2>/dev/null | grep -F 'github/gh-copilot' >/dev/null 2>&1; then
            printf 'copilot-cli|cli|GitHub Copilot CLI|gh extension\n'
        fi
    fi
}

rf::detect::gemini_cli() {
    if rf::on_path gemini; then
        local v
        v="$(gemini --version 2>/dev/null | head -n1 || true)"
        printf 'gemini-cli|cli|Gemini CLI|%s\n' "${v:-detected on PATH}"
    fi
}

rf::detect::windsurf_desktop() {
    [[ "${RF_TEST_NO_DETECT_APPS:-}" == "1" ]] && return 0
    local hint=""
    if rf::is_macos && [[ -d "/Applications/Windsurf.app" ]]; then
        hint="/Applications/Windsurf.app"
    elif rf::is_linux && { [[ -d "$HOME/.config/Windsurf" ]] || [[ -d "$HOME/.codeium/windsurf" ]]; }; then
        hint="$HOME/.codeium/windsurf"
    elif rf::is_windows && [[ -d "${LOCALAPPDATA:-$HOME/AppData/Local}/Programs/Windsurf" ]]; then
        hint="${LOCALAPPDATA:-$HOME/AppData/Local}/Programs/Windsurf"
    elif rf::on_path windsurf; then
        hint="windsurf on PATH"
    else
        return 0
    fi
    printf 'windsurf-desktop|desktop|Windsurf|%s\n' "$hint"
}

rf::detect::vscode_copilot() {
    [[ "${RF_TEST_NO_DETECT_APPS:-}" == "1" ]] && return 0
    if rf::on_path code; then
        printf 'vscode-copilot|desktop|VS Code Copilot|code on PATH\n'
        return 0
    fi
    # Common install dirs for VS Code on macOS / Linux.
    if rf::is_macos && [[ -d "/Applications/Visual Studio Code.app" ]]; then
        printf 'vscode-copilot|desktop|VS Code Copilot|%s\n' "/Applications/Visual Studio Code.app"
    elif rf::is_linux && [[ -d "$HOME/.vscode" ]]; then
        printf 'vscode-copilot|desktop|VS Code Copilot|%s\n' "$HOME/.vscode"
    fi
}

rf::detect::opencode_cli() {
    if rf::on_path opencode; then
        local v
        v="$(opencode --version 2>/dev/null | head -n1 || true)"
        printf 'opencode-cli|cli|OpenCode CLI|%s\n' "${v:-detected on PATH}"
    fi
}

# Aggregator: print one line per detected host.
#
# Note: claude-desktop (chat tab) is deliberately omitted from the default
# auto-detect list. Anthropic's Claude Desktop currently rewrites
# claude_desktop_config.json on every prefs-save and strips out the
# mcpServers block we just wrote — making the chat-tab install fragile
# until Anthropic ships the cloud Connector path. Users who want to opt in
# explicitly can still pass `--host=claude-desktop`, and rf::detect::lookup
# still recognizes the id.
rf::detect::all() {
    rf::detect::claude_code_cli
    rf::detect::codex_cli
    rf::detect::cursor_desktop
    rf::detect::copilot_cli
    rf::detect::gemini_cli
    rf::detect::windsurf_desktop
    rf::detect::vscode_copilot
    rf::detect::opencode_cli
}

# rf::detect::lookup <id>
rf::detect::lookup() {
    local id="$1"
    case "$id" in
        claude-code-cli)   rf::detect::claude_code_cli ;;
        codex-cli)         rf::detect::codex_cli ;;
        cursor-desktop)    rf::detect::cursor_desktop ;;
        claude-desktop)    rf::detect::claude_desktop ;;
        copilot-cli)       rf::detect::copilot_cli ;;
        gemini-cli)        rf::detect::gemini_cli ;;
        windsurf-desktop)  rf::detect::windsurf_desktop ;;
        vscode-copilot)    rf::detect::vscode_copilot ;;
        opencode-cli)      rf::detect::opencode_cli ;;
        *) return 1 ;;
    esac
}

rf::detect::known_ids() {
    cat <<'EOF'
claude-code-cli
codex-cli
cursor-desktop
claude-desktop
copilot-cli
gemini-cli
windsurf-desktop
vscode-copilot
opencode-cli
EOF
}
