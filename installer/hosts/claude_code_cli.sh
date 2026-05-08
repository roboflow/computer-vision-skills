#!/usr/bin/env bash
# claude_code_cli.sh — install Roboflow into Claude Code via plugin marketplace.
#
# Strategy: shell out to `claude plugin marketplace add` + `claude plugin install`.
# This is the same path documented in this repo's README and gives users
# auto-updates via Claude Code's plugin system.

RF_HOST_ID="claude-code-cli"
RF_HOST_LABEL="Claude Code CLI"

rf::host::claude_code_cli::install() {
    rf::header "Installing Roboflow plugin for $RF_HOST_LABEL"

    if ! rf::on_path claude; then
        rf::err "claude not found on PATH"
        rf::dim "Install Claude Code: https://docs.claude.com/claude-code"
        return 1
    fi

    local marketplace_source plugin_name scope_flag
    marketplace_source="${ROBOFLOW_AGENTS_REPO:-roboflow/computer-vision-skills}"
    plugin_name="roboflow"
    scope_flag=""
    if [[ "${RF_OPT_SCOPE:-global}" == "project" ]]; then
        scope_flag="--scope local"
    fi

    if [[ "${RF_OPT_DRY_RUN:-0}" == "1" ]]; then
        rf::info "[dry-run] would run: claude plugin marketplace add $marketplace_source"
        rf::info "[dry-run] would run: claude plugin install $plugin_name $scope_flag"
        return 0
    fi

    rf::step "claude plugin marketplace add $marketplace_source"
    if ! claude plugin marketplace add "$marketplace_source" 2>&1; then
        rf::warn "marketplace add reported a non-zero exit (may already be registered); continuing"
    fi

    rf::step "claude plugin install $plugin_name $scope_flag"
    # shellcheck disable=SC2086
    if ! claude plugin install "$plugin_name" $scope_flag 2>&1; then
        rf::err "claude plugin install failed"
        return 1
    fi

    local entry
    entry="$(rf::host::claude_code_cli::manifest_entry "$marketplace_source" "$plugin_name")"
    rf::manifest::record "$entry" || rf::warn "could not update installer manifest (non-fatal)"

    rf::ok "Roboflow plugin installed for $RF_HOST_LABEL"
    if [[ -z "${ROBOFLOW_API_KEY:-}" ]] && [[ -n "${RF_API_KEY:-}" ]]; then
        rf::dim "Reminder: export ROBOFLOW_API_KEY in the shell that launches \`claude\` so the MCP server authenticates."
    fi
    return 0
}

rf::host::claude_code_cli::uninstall() {
    rf::header "Removing Roboflow plugin from $RF_HOST_LABEL"
    if ! rf::on_path claude; then
        rf::warn "claude not on PATH; skipping uninstall (you can run \`claude plugin remove roboflow\` manually)"
        return 0
    fi

    if [[ "${RF_OPT_DRY_RUN:-0}" == "1" ]]; then
        rf::info "[dry-run] would run: claude plugin remove roboflow"
        return 0
    fi

    if claude plugin remove roboflow 2>&1; then
        rf::ok "removed Roboflow plugin from $RF_HOST_LABEL"
    else
        rf::warn "claude plugin remove reported a non-zero exit (plugin may not have been installed)"
    fi

    rf::manifest::remove "$RF_HOST_ID" "plugin" "${RF_OPT_SCOPE:-global}" || true
    return 0
}

rf::host::claude_code_cli::manifest_entry() {
    local source="$1" plugin_name="$2"
    local now
    now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    cat <<EOF
{
  "host_id": "$RF_HOST_ID",
  "component": "plugin",
  "scope": "${RF_OPT_SCOPE:-global}",
  "marketplace": "$source",
  "plugin_name": "$plugin_name",
  "installer_version": "$RF_INSTALLER_VERSION",
  "installed_at": "$now",
  "updated_at": "$now"
}
EOF
}
