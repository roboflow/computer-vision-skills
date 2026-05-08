#!/usr/bin/env bash
# claude_desktop.sh — install Roboflow MCP into Claude Desktop.
#
# Claude Desktop reads claude_desktop_config.json from a platform-specific dir.
# It does NOT read SKILL.md files (those are a Claude Code CLI / plugin
# concept), so this adapter only handles the MCP component.

RF_HOST_ID="claude-desktop"
RF_HOST_LABEL="Claude Desktop"

rf::host::claude_desktop::config_path() {
    if rf::is_macos; then
        printf '%s/Library/Application Support/Claude/claude_desktop_config.json' "$HOME"
    elif rf::is_linux; then
        printf '%s/.config/Claude/claude_desktop_config.json' "$HOME"
    else
        # Windows: %APPDATA%\Claude\claude_desktop_config.json. Use forward
        # slashes throughout because the JSON tool doesn't care and bash
        # tooling treats backslashes badly.
        printf '%s/Claude/claude_desktop_config.json' "${APPDATA:-$HOME/AppData/Roaming}"
    fi
}

rf::host::claude_desktop::install() {
    rf::header "Configuring Roboflow MCP for $RF_HOST_LABEL"

    if [[ "${RF_DO_MCP:-1}" != "1" ]]; then
        rf::dim "  MCP disabled by --no-mcp; nothing to do (Claude Desktop has no skills support)"
        return 0
    fi

    local config_path
    config_path="$(rf::host::claude_desktop::config_path)"

    rf::step "MCP → $config_path"
    rf::mcp::install "$config_path"

    if [[ "${RF_OPT_DRY_RUN:-0}" != "1" ]]; then
        rf::manifest::record "$(cat <<EOF
{
  "host_id": "$RF_HOST_ID",
  "component": "mcp",
  "scope": "${RF_OPT_SCOPE:-global}",
  "config_path": "$config_path",
  "server_name": "roboflow",
  "installer_version": "$RF_INSTALLER_VERSION",
  "installed_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
)" || true
    fi

    rf::ok "Roboflow MCP configured for $RF_HOST_LABEL"
    rf::dim "Restart Claude Desktop for the change to take effect."
    if [[ -z "${ROBOFLOW_API_KEY:-}" ]] && [[ "${RF_OPT_INLINE_KEY:-0}" != "1" ]]; then
        rf::dim "Reminder: ROBOFLOW_API_KEY must be exported in the launchd / shell environment Claude Desktop inherits."
    fi
    return 0
}

rf::host::claude_desktop::uninstall() {
    rf::header "Removing Roboflow MCP from $RF_HOST_LABEL"
    if [[ "${RF_DO_MCP:-1}" != "1" ]]; then
        return 0
    fi
    local config_path
    config_path="$(rf::host::claude_desktop::config_path)"
    rf::mcp::remove "$config_path"
    rf::manifest::remove "$RF_HOST_ID" "mcp" "${RF_OPT_SCOPE:-global}" || true
    return 0
}
