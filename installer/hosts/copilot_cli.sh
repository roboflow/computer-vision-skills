#!/usr/bin/env bash
# copilot_cli.sh — install Roboflow MCP into GitHub Copilot CLI.
#
# Copilot CLI reads MCP servers from ~/.copilot/mcp-config.json. It does not
# (yet) consume SKILL.md files, so this adapter only handles MCP.

RF_HOST_ID="copilot-cli"
RF_HOST_LABEL="GitHub Copilot CLI"

rf::host::copilot_cli::config_path() {
    printf '%s/.copilot/mcp-config.json' "$HOME"
}

rf::host::copilot_cli::install() {
    rf::header "Configuring Roboflow MCP for $RF_HOST_LABEL"

    if [[ "${RF_DO_MCP:-1}" != "1" ]]; then
        rf::dim "  MCP disabled by --no-mcp; nothing to do (Copilot CLI has no skills support)"
        return 0
    fi

    local config_path
    config_path="$(rf::host::copilot_cli::config_path)"

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
    if [[ -z "${ROBOFLOW_API_KEY:-}" ]] && [[ "${RF_OPT_INLINE_KEY:-0}" != "1" ]]; then
        rf::dim "Reminder: export ROBOFLOW_API_KEY in your shell so Copilot CLI can authenticate against the MCP."
    fi
    return 0
}

rf::host::copilot_cli::uninstall() {
    rf::header "Removing Roboflow MCP from $RF_HOST_LABEL"
    if [[ "${RF_DO_MCP:-1}" != "1" ]]; then
        return 0
    fi
    local config_path
    config_path="$(rf::host::copilot_cli::config_path)"
    rf::mcp::remove "$config_path"
    rf::manifest::remove "$RF_HOST_ID" "mcp" "${RF_OPT_SCOPE:-global}" || true
    return 0
}
