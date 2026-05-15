#!/usr/bin/env bash
# claude_desktop.sh — install Roboflow MCP into Claude Desktop's chat tab.
#
# Claude Desktop's claude_desktop_config.json schema only accepts stdio-based
# MCP servers (verified against the bundled validator: { command, args, env,
# extensionId }). It does NOT take `type: "http"` like Claude Code, Cursor,
# Gemini, etc.
#
# To run an HTTP MCP from Claude Desktop's chat tab we bridge stdio↔HTTP via
# the npm package `mcp-remote`. That requires Node + npx on PATH. The bridge
# also doesn't expand env vars in args, so the API key has to be inlined.
#
# Note: this adapter only configures the chat tab. The Code tab (Claude Code
# in Claude Desktop) reads the Claude Code plugin system, so installing
# `claude-code-cli` covers it without any bridge or Node dependency.
#
# == Why we write to the MSIX-private path on Windows ==
#
# Anthropic's canonical install path going forward is Desktop Extensions
# (`.mcpb` files: https://www.anthropic.com/engineering/desktop-extensions).
# We can't use that path yet. Verified on Claude_1.7196.0.0_arm64 (Nov 2026):
#   * The MSIX manifest registers only `claude://cowork/shared-artifact?...`
#     — no claude://install-mcp, no .mcpb file association.
#   * No file handler is registered for .mcpb or .dxt; Start-Process /
#     `open` on a .mcpb does nothing.
#   * The `installExtension` handlers inside app.asar are Electron IPC
#     routes from the renderer, gated by origin validation — not externally
#     callable.
#
# So today, writing claude_desktop_config.json ourselves is the only way to
# install + persist from an external installer. On Windows specifically, the
# MSIX package per-process-virtualizes %APPDATA%\Claude\, so the *real* path
# Claude Desktop reads from is
# %LOCALAPPDATA%\Packages\Claude_<family>\LocalCache\Roaming\Claude\
# claude_desktop_config.json. config_path() resolves to that path when an
# MSIX package is detected.
#
# Tracking: https://github.com/anthropics/claude-code/issues/26073 (open).
# Migrate to .mcpb / claude://install-mcp / a CLI install flag when any of
# those ship.

RF_HOST_ID="claude-desktop"
RF_HOST_LABEL="Claude Desktop"

rf::host::claude_desktop::config_path() {
    if rf::is_macos; then
        printf '%s/Library/Application Support/Claude/claude_desktop_config.json' "$HOME"
        return 0
    fi
    if rf::is_linux; then
        printf '%s/.config/Claude/claude_desktop_config.json' "$HOME"
        return 0
    fi

    # Windows (via Git Bash / MSYS / WSL): Claude Desktop is an MSIX app,
    # so %APPDATA%\Claude is per-process-virtualized. The bash installer
    # writes from outside the MSIX container, so we have to target the
    # underlying real path under
    # %LOCALAPPDATA%\Packages\Claude_<family>\LocalCache\Roaming\Claude\.
    local appdata="${APPDATA:-$HOME/AppData/Roaming}"
    local local_app="${LOCALAPPDATA:-$HOME/AppData/Local}"
    appdata="${appdata//\\//}"
    local_app="${local_app//\\//}"

    local pkg_root="$local_app/Packages"
    if [[ -d "$pkg_root" ]]; then
        local pkg
        pkg="$(find "$pkg_root" -mindepth 1 -maxdepth 1 -type d -name 'Claude_*' 2>/dev/null | head -n1 || true)"
        if [[ -n "$pkg" ]]; then
            printf '%s/LocalCache/Roaming/Claude/claude_desktop_config.json' "$pkg"
            return 0
        fi
    fi
    printf '%s/Claude/claude_desktop_config.json' "$appdata"
}

# Pinned version + key go into args literally because Claude Desktop neither
# expands ${VAR} nor accepts http MCPs natively.
RF_MCP_REMOTE_VERSION="0.1.27"

rf::host::claude_desktop::bridge_server_json() {
    local key="$1"
    rf::json::has_tool || rf::die "no JSON tool available (need python3 or jq)"
    if [[ "$(rf::json::tool)" == "python3" ]]; then
        KEY="$key" VER="$RF_MCP_REMOTE_VERSION" python3 -c '
import json, os, sys
ver = os.environ["VER"]
api_key = os.environ["KEY"]
server = {
    "command": "npx",
    "args": [
        "-y",
        "mcp-remote@" + ver,
        "https://mcp.roboflow.com/mcp",
        "--header",
        "x-api-key:" + api_key,
    ],
}
json.dump(server, sys.stdout)
'
    else
        jq -n --arg k "$key" --arg v "$RF_MCP_REMOTE_VERSION" '{
            command: "npx",
            args: ["-y", ("mcp-remote@" + $v), "https://mcp.roboflow.com/mcp", "--header", ("x-api-key:" + $k)]
        }'
    fi
}

rf::host::claude_desktop::install() {
    rf::header "Configuring Roboflow MCP for $RF_HOST_LABEL (chat tab)"

    if [[ "${RF_DO_MCP:-1}" != "1" ]]; then
        rf::dim "  MCP disabled by --no-mcp; nothing to do (Claude Desktop has no skills support)"
        return 0
    fi

    # Bridge requires npx. Refuse the install rather than write a broken config.
    if ! rf::on_path npx; then
        rf::err "npx (Node.js) is required for Claude Desktop's chat tab MCP bridge"
        rf::dim "Install Node.js: https://nodejs.org — then re-run agents.sh."
        rf::dim "If you only need Roboflow in Claude Code (CLI / Claude Desktop's Code tab),"
        rf::dim "use --host=claude-code-cli — that path doesn't need Node."
        return 1
    fi

    # Embed literal key. Claude Desktop doesn't expand env vars in args, and
    # the chat-tab schema doesn't accept ${ROBOFLOW_API_KEY} placeholders.
    if [[ -z "${RF_API_KEY:-}" ]]; then
        rf::err "Claude Desktop's chat tab needs a literal API key (it doesn't expand env vars in MCP args)."
        rf::dim "Re-run with --api-key=<key>, set ROBOFLOW_API_KEY, or skip with --auth-skip / --no-mcp."
        return 1
    fi

    local config_path
    config_path="$(rf::host::claude_desktop::config_path)"

    if [[ "${RF_OPT_DRY_RUN:-0}" == "1" ]]; then
        rf::info "[dry-run] would write Roboflow MCP (mcp-remote stdio bridge) to $config_path"
        return 0
    fi

    rf::step "MCP → $config_path"
    if [[ -f "$config_path" ]]; then
        local bak
        bak="$(rf::backup "$config_path")"
        [[ -n "$bak" ]] && rf::dim "  backup: $bak"
    fi
    local server_json
    server_json="$(rf::host::claude_desktop::bridge_server_json "$RF_API_KEY")"
    rf::json::merge_mcp "$config_path" "roboflow" "$server_json"
    rf::ok "wrote Roboflow MCP entry (mcp-remote@$RF_MCP_REMOTE_VERSION bridge) to $config_path"
    rf::dim "Restart Claude Desktop for the change to take effect."

    rf::manifest::record "$(cat <<EOF
{
  "host_id": "$RF_HOST_ID",
  "component": "mcp",
  "scope": "${RF_OPT_SCOPE:-global}",
  "config_path": "$config_path",
  "server_name": "roboflow",
  "transport": "stdio-bridge",
  "bridge": "mcp-remote@$RF_MCP_REMOTE_VERSION",
  "api_key_mode": "inlined",
  "installer_version": "$RF_INSTALLER_VERSION",
  "installed_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
)" || true
    return 0
}

rf::host::claude_desktop::uninstall() {
    rf::header "Removing Roboflow MCP from $RF_HOST_LABEL"
    if [[ "${RF_DO_MCP:-1}" != "1" ]]; then return 0; fi
    local config_path
    config_path="$(rf::host::claude_desktop::config_path)"
    rf::mcp::remove "$config_path"
    rf::manifest::remove "$RF_HOST_ID" "mcp" "${RF_OPT_SCOPE:-global}" || true
    return 0
}
