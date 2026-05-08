#!/usr/bin/env bash
# cursor_desktop.sh — install Roboflow into Cursor.
#
# Cursor has no plugin system; we configure it via two well-known files:
#   - ~/.cursor/mcp.json (MCP servers)
#   - ~/.claude/skills/<name>/  (Cursor reads SKILL.md files from this path,
#     same convention `npx skills add` uses; per-project version under
#     <project>/.claude/skills/ when scope=project)
#
# Optional rules at .cursor/rules/roboflow.mdc are written by lib/rules.sh
# in Phase 5; this adapter ignores RF_DO_RULES until then.

RF_HOST_ID="cursor-desktop"
RF_HOST_LABEL="Cursor"

rf::host::cursor_desktop::mcp_path() {
    if [[ "${RF_OPT_SCOPE:-global}" == "project" ]]; then
        printf '%s/.cursor/mcp.json' "${RF_PROJECT_DIR:-$PWD}"
    else
        printf '%s/.cursor/mcp.json' "$HOME"
    fi
}

rf::host::cursor_desktop::skills_dir() {
    if [[ "${RF_OPT_SCOPE:-global}" == "project" ]]; then
        printf '%s/.claude/skills' "${RF_PROJECT_DIR:-$PWD}"
    else
        printf '%s/.claude/skills' "$HOME"
    fi
}

rf::host::cursor_desktop::install() {
    rf::header "Configuring Roboflow for $RF_HOST_LABEL"

    local mcp_path skills_dir
    mcp_path="$(rf::host::cursor_desktop::mcp_path)"
    skills_dir="$(rf::host::cursor_desktop::skills_dir)"

    if [[ "${RF_DO_MCP:-1}" == "1" ]]; then
        rf::step "MCP → $mcp_path"
        rf::mcp::install "$mcp_path"
        if [[ "${RF_OPT_DRY_RUN:-0}" != "1" ]]; then
            rf::manifest::record "$(cat <<EOF
{
  "host_id": "$RF_HOST_ID",
  "component": "mcp",
  "scope": "${RF_OPT_SCOPE:-global}",
  "config_path": "$mcp_path",
  "server_name": "roboflow",
  "installer_version": "$RF_INSTALLER_VERSION",
  "installed_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
)" || true
        fi
    fi

    if [[ "${RF_DO_SKILLS:-1}" == "1" ]]; then
        rf::step "Skills → $skills_dir"
        rf::skills::install_all "$skills_dir" "$RF_HOST_ID" "${RF_OPT_SCOPE:-global}"
    fi

    # Cursor's rule system uses per-rule .mdc files under .cursor/rules.
    # Only meaningful at project scope — skip for --global.
    if [[ "${RF_DO_RULES:-1}" == "1" ]] && [[ "${RF_OPT_SCOPE:-global}" == "project" ]]; then
        local project="${RF_PROJECT_DIR:-$PWD}"
        local rule_path="$project/.cursor/rules/roboflow.mdc"
        rf::step "Rules → $rule_path"
        rf::rules::install_cursor_mdc "$rule_path"
        if [[ "${RF_OPT_DRY_RUN:-0}" != "1" ]]; then
            rf::manifest::record "$(cat <<EOF
{
  "host_id": "$RF_HOST_ID",
  "component": "rules",
  "scope": "${RF_OPT_SCOPE:-global}",
  "config_path": "$rule_path",
  "installer_version": "$RF_INSTALLER_VERSION",
  "installed_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
)" || true
        fi
    fi

    rf::ok "Roboflow configured for $RF_HOST_LABEL"
    return 0
}

rf::host::cursor_desktop::uninstall() {
    rf::header "Removing Roboflow from $RF_HOST_LABEL"

    local mcp_path skills_dir
    mcp_path="$(rf::host::cursor_desktop::mcp_path)"
    skills_dir="$(rf::host::cursor_desktop::skills_dir)"

    if [[ "${RF_DO_MCP:-1}" == "1" ]]; then
        rf::mcp::remove "$mcp_path"
        rf::manifest::remove "$RF_HOST_ID" "mcp" "${RF_OPT_SCOPE:-global}" || true
    fi
    if [[ "${RF_DO_SKILLS:-1}" == "1" ]]; then
        rf::skills::remove_all "$skills_dir" "$RF_HOST_ID" "${RF_OPT_SCOPE:-global}"
    fi
    if [[ "${RF_DO_RULES:-1}" == "1" ]] && [[ "${RF_OPT_SCOPE:-global}" == "project" ]]; then
        local project="${RF_PROJECT_DIR:-$PWD}"
        rf::rules::remove_cursor_mdc "$project/.cursor/rules/roboflow.mdc"
        rf::manifest::remove "$RF_HOST_ID" "rules" "${RF_OPT_SCOPE:-global}" || true
    fi
    return 0
}
