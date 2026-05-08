#!/usr/bin/env bash
# windsurf_desktop.sh — install Roboflow MCP into Windsurf.

RF_HOST_ID="windsurf-desktop"
RF_HOST_LABEL="Windsurf"

rf::host::windsurf_desktop::config_path() {
    printf '%s/.codeium/windsurf/mcp_config.json' "$HOME"
}

rf::host::windsurf_desktop::install() {
    rf::header "Configuring Roboflow MCP for $RF_HOST_LABEL"
    if [[ "${RF_DO_MCP:-1}" != "1" ]]; then
        rf::dim "  MCP disabled by --no-mcp; nothing to do (Windsurf MCP only)"
        return 0
    fi
    local config_path
    config_path="$(rf::host::windsurf_desktop::config_path)"
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
    rf::dim "Restart Windsurf for the change to take effect."
    if [[ -z "${ROBOFLOW_API_KEY:-}" ]] && [[ "${RF_OPT_INLINE_KEY:-0}" != "1" ]]; then
        rf::dim "Reminder: ROBOFLOW_API_KEY must be in the environment that launches Windsurf."
    fi
    return 0
}

rf::host::windsurf_desktop::uninstall() {
    rf::header "Removing Roboflow MCP from $RF_HOST_LABEL"
    if [[ "${RF_DO_MCP:-1}" != "1" ]]; then return 0; fi
    local config_path
    config_path="$(rf::host::windsurf_desktop::config_path)"
    rf::mcp::remove "$config_path"
    rf::manifest::remove "$RF_HOST_ID" "mcp" "${RF_OPT_SCOPE:-global}" || true
    return 0
}
