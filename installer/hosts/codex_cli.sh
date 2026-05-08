#!/usr/bin/env bash
# codex_cli.sh — register Roboflow as a Codex marketplace source.
#
# Codex's CLI exposes `plugin marketplace add/upgrade/remove` but does NOT
# have a non-interactive `plugin install` (per this repo's README). The user
# has to open Codex, run `/plugins`, pick the Roboflow source, and install.
# We do the marketplace registration and surface a clear next-step prompt.

RF_HOST_ID="codex-cli"
RF_HOST_LABEL="Codex CLI"

rf::host::codex_cli::install() {
    rf::header "Registering Roboflow marketplace source for $RF_HOST_LABEL"

    if ! rf::on_path codex; then
        rf::err "codex not found on PATH"
        rf::dim "Install Codex CLI: https://github.com/openai/codex"
        return 1
    fi

    local marketplace_source
    marketplace_source="${ROBOFLOW_AGENTS_REPO:-roboflow/computer-vision-skills}"

    if [[ "${RF_OPT_DRY_RUN:-0}" == "1" ]]; then
        rf::info "[dry-run] would run: codex plugin marketplace add $marketplace_source"
        return 0
    fi

    rf::step "codex plugin marketplace add $marketplace_source"
    if ! codex plugin marketplace add "$marketplace_source" 2>&1; then
        rf::warn "marketplace add reported a non-zero exit (may already be registered); continuing"
    fi

    local entry
    entry="$(rf::host::codex_cli::manifest_entry "$marketplace_source")"
    rf::manifest::record "$entry" || rf::warn "could not update installer manifest (non-fatal)"

    rf::ok "Roboflow marketplace registered for $RF_HOST_LABEL"
    rf::info ""
    rf::info "${RF_COLOR_BOLD}Finish installation:${RF_COLOR_RESET}"
    rf::info "  1. Restart Codex (close and reopen)"
    rf::info "  2. Run ${RF_COLOR_CYAN}/plugins${RF_COLOR_RESET} in Codex"
    rf::info "  3. Pick the ${RF_COLOR_BOLD}Roboflow${RF_COLOR_RESET} source, then install the ${RF_COLOR_BOLD}Roboflow${RF_COLOR_RESET} plugin"
    rf::info "  4. Press Space if it shows installed-but-disabled"
    if [[ -z "${ROBOFLOW_API_KEY:-}" ]] && [[ -n "${RF_API_KEY:-}" ]]; then
        rf::info ""
        rf::dim "Reminder: export ROBOFLOW_API_KEY in the shell that launches \`codex\` so the MCP server authenticates."
    fi
    return 0
}

rf::host::codex_cli::uninstall() {
    rf::header "Removing Roboflow from $RF_HOST_LABEL"
    if ! rf::on_path codex; then
        rf::warn "codex not on PATH; skipping (you can run \`codex plugin marketplace remove roboflow\` manually)"
        return 0
    fi

    if [[ "${RF_OPT_DRY_RUN:-0}" == "1" ]]; then
        rf::info "[dry-run] would run: codex plugin marketplace remove roboflow"
        return 0
    fi

    if codex plugin marketplace remove roboflow 2>&1; then
        rf::ok "removed Roboflow marketplace from $RF_HOST_LABEL"
    else
        rf::warn "codex plugin marketplace remove reported a non-zero exit (may not have been registered)"
    fi
    rf::dim "If the plugin itself is still installed, remove it from \`codex /plugins\`."

    rf::manifest::remove "$RF_HOST_ID" "plugin" "${RF_OPT_SCOPE:-global}" || true
    return 0
}

rf::host::codex_cli::manifest_entry() {
    local source="$1"
    local now
    now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    cat <<EOF
{
  "host_id": "$RF_HOST_ID",
  "component": "plugin",
  "scope": "${RF_OPT_SCOPE:-global}",
  "marketplace": "$source",
  "plugin_name": "roboflow",
  "installer_version": "$RF_INSTALLER_VERSION",
  "installed_at": "$now",
  "updated_at": "$now",
  "manual_step": "open Codex, run /plugins, install the Roboflow plugin"
}
EOF
}
