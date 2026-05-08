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

rf::detect::claude_code_cli() {
    if rf::on_path claude; then
        local v
        v="$(claude --version 2>/dev/null | head -n1 || true)"
        printf 'claude-code-cli|cli|Claude Code CLI|%s\n' "${v:-detected on PATH}"
    fi
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
rf::detect::all() {
    rf::detect::claude_code_cli
    rf::detect::codex_cli
    rf::detect::cursor_desktop
    rf::detect::claude_desktop
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
