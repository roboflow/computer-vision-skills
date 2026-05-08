#!/usr/bin/env bash
# gemini_cli.sh — install Roboflow MCP into Gemini CLI.
#
# Gemini CLI's settings file at ~/.gemini/settings.json uses the same
# `mcpServers` schema most hosts use, so we can lean on the shared MCP lib.

RF_HOST_ID="gemini-cli"
RF_HOST_LABEL="Gemini CLI"

rf::host::gemini_cli::config_path() {
    printf '%s/.gemini/settings.json' "$HOME"
}

rf::host::gemini_cli::install() {
    rf::header "Configuring Roboflow MCP for $RF_HOST_LABEL"
    if [[ "${RF_DO_MCP:-1}" != "1" ]]; then
        rf::dim "  MCP disabled by --no-mcp; nothing to do (Gemini CLI has no skills support)"
        return 0
    fi
    local config_path
    config_path="$(rf::host::gemini_cli::config_path)"
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
    return 0
}

rf::host::gemini_cli::uninstall() {
    rf::header "Removing Roboflow MCP from $RF_HOST_LABEL"
    if [[ "${RF_DO_MCP:-1}" != "1" ]]; then return 0; fi
    local config_path
    config_path="$(rf::host::gemini_cli::config_path)"
    rf::mcp::remove "$config_path"
    rf::manifest::remove "$RF_HOST_ID" "mcp" "${RF_OPT_SCOPE:-global}" || true
    return 0
}
