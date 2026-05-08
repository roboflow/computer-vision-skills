#!/usr/bin/env bash
# opencode_cli.sh — install Roboflow MCP into OpenCode CLI.
#
# OpenCode's config is JSONC at ~/.config/opencode/opencode.json with an
# `mcp` container key (not `mcpServers`) and `type: "remote"` (not "http")
# for HTTP-based MCP servers.
#
# We refuse to touch the file if comments are present unless --force —
# preserving JSONC comments through a JSON round-trip is too risky.

RF_HOST_ID="opencode-cli"
RF_HOST_LABEL="OpenCode CLI"

rf::host::opencode_cli::config_path() {
    printf '%s/.config/opencode/opencode.json' "$HOME"
}

# rf::host::opencode_cli::has_jsonc_comments <file>
# Best-effort scan for `//` or `/* */` outside string literals. Refuses
# rather than risking a comment-stripping bug.
rf::host::opencode_cli::has_jsonc_comments() {
    local file="$1"
    [[ -f "$file" ]] || return 1
    if [[ "$(rf::json::tool)" == "python3" ]]; then
        FILE="$file" python3 -c '
import sys, os, re
with open(os.environ["FILE"]) as fh:
    text = fh.read()
# Strip strings to avoid false positives on URLs / paths.
text2 = re.sub(r"\"(?:\\.|[^\"\\\\])*\"", "", text)
sys.exit(0 if "//" in text2 or "/*" in text2 else 1)
'
    else
        # No python3 → conservative: assume there are comments if any line has //.
        grep -E '(^|[^:])//' "$file" >/dev/null 2>&1
    fi
}

rf::host::opencode_cli::install() {
    rf::header "Configuring Roboflow MCP for $RF_HOST_LABEL"
    if [[ "${RF_DO_MCP:-1}" != "1" ]]; then
        rf::dim "  MCP disabled by --no-mcp; nothing to do (OpenCode MCP only)"
        return 0
    fi
    local config_path
    config_path="$(rf::host::opencode_cli::config_path)"

    local jsonc_present=0
    if rf::host::opencode_cli::has_jsonc_comments "$config_path"; then
        if [[ "${RF_OPT_FORCE:-0}" != "1" ]]; then
            rf::err "$config_path contains JSONC comments; refusing to overwrite without --force"
            rf::dim "Add the Roboflow entry manually, or run with --force to drop comments."
            return 1
        fi
        rf::warn "JSONC comments + any non-roboflow content will be lost (--force was passed)"
        jsonc_present=1
    fi

    if [[ "${RF_OPT_DRY_RUN:-0}" == "1" ]]; then
        rf::info "[dry-run] would write Roboflow MCP entry (mcp/remote schema) to $config_path"
        return 0
    fi

    rf::step "MCP → $config_path"

    # If --force was used to override JSONC, the existing file isn't parseable
    # JSON. Back it up and start from empty so the merge succeeds.
    if [[ $jsonc_present -eq 1 ]]; then
        rf::backup "$config_path" >/dev/null
        rf::ensure_dir "$(dirname "$config_path")"
        printf '{}\n' >"$config_path"
    fi

    rf::mcp::install "$config_path" "mcp" --type=remote
    if [[ "${RF_OPT_DRY_RUN:-0}" != "1" ]]; then
        rf::manifest::record "$(cat <<EOF
{
  "host_id": "$RF_HOST_ID",
  "component": "mcp",
  "scope": "${RF_OPT_SCOPE:-global}",
  "config_path": "$config_path",
  "server_name": "roboflow",
  "container_key": "mcp",
  "installer_version": "$RF_INSTALLER_VERSION",
  "installed_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
)" || true
    fi
    rf::ok "Roboflow MCP configured for $RF_HOST_LABEL"
    if [[ -z "${ROBOFLOW_API_KEY:-}" ]] && [[ "${RF_OPT_INLINE_KEY:-0}" != "1" ]]; then
        rf::dim "Reminder: export ROBOFLOW_API_KEY in the shell that launches \`opencode\`."
    fi
    return 0
}

rf::host::opencode_cli::uninstall() {
    rf::header "Removing Roboflow MCP from $RF_HOST_LABEL"
    if [[ "${RF_DO_MCP:-1}" != "1" ]]; then return 0; fi
    local config_path
    config_path="$(rf::host::opencode_cli::config_path)"
    rf::mcp::remove "$config_path" "mcp"
    rf::manifest::remove "$RF_HOST_ID" "mcp" "${RF_OPT_SCOPE:-global}" || true
    return 0
}
