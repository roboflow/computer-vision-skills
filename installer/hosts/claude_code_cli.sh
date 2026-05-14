#!/usr/bin/env bash
# claude_code_cli.sh — install Roboflow into Claude Code via plugin marketplace.
#
# Strategy: shell out to `claude plugin marketplace add` + `claude plugin install`,
# then patch the cached plugin's .mcp.json to embed the resolved API key inline
# so users don't have to manage a ROBOFLOW_API_KEY env var themselves.
#
# Same plugin install also feeds Claude Code in Claude Desktop (the Code/CCD
# tab) — that surface reads ~/.claude/plugins/cache/, which is exactly what
# the CLI populates.

RF_HOST_ID="claude-code-cli"
RF_HOST_LABEL="Claude Code"

# Path pattern: $HOME/.claude/plugins/cache/<marketplace>/<plugin>/<version>/.mcp.json
rf::host::claude_code_cli::cache_dir() {
    printf '%s/.claude/plugins/cache/roboflow/roboflow' "$HOME"
}

# Find every cached version dir whose .mcp.json still has the placeholder
# header, replace it with the resolved literal key, drop the now-misleading
# "set ROBOFLOW_API_KEY" note. No-op (returns 0) if RF_API_KEY is empty so
# users with --auth-skip can still install the plugin.
rf::host::claude_code_cli::patch_cache() {
    local key="${RF_API_KEY:-}"
    if [[ -z "$key" ]]; then
        rf::warn "no API key resolved — Roboflow MCP will keep \${ROBOFLOW_API_KEY} placeholder"
        rf::dim "  set ROBOFLOW_API_KEY in your shell, or re-run with --api-key=<key>"
        return 0
    fi

    local cache_dir
    cache_dir="$(rf::host::claude_code_cli::cache_dir)"
    [[ -d "$cache_dir" ]] || { rf::warn "plugin cache not found at $cache_dir"; return 1; }

    rf::json::has_tool || rf::die "no JSON tool available (need python3 or jq)"

    local patched=0 dir mcp_file
    for dir in "$cache_dir"/*/; do
        mcp_file="${dir}.mcp.json"
        [[ -f "$mcp_file" ]] || continue
        if [[ "${RF_OPT_DRY_RUN:-0}" == "1" ]]; then
            rf::info "[dry-run] would embed API key in $mcp_file"
            patched=1
            continue
        fi

        # Idempotent re-runs detect the literal key already in place and skip.
        # Supports both shapes the plugin's .mcp.json has ever shipped:
        #   stdio  (current 0.2+): args[] element of form "x-api-key:<key>"
        #   http   (legacy 0.1.x): headers["x-api-key"] = "<key>"
        if RF_KEY="$key" FILE="$mcp_file" python3 -c '
import json, os, sys
path = os.environ["FILE"]
key = os.environ["RF_KEY"]
target = "x-api-key:" + key
with open(path) as fh:
    data = json.load(fh)
servers = data.get("mcpServers", {})
entry = servers.get("roboflow")
if not entry:
    sys.exit(2)  # no roboflow server in this version, skip

patched = False
already = False

# Current shape: stdio + mcp-remote bridge in args[].
if isinstance(entry.get("args"), list):
    args = entry["args"]
    for i, a in enumerate(args):
        if isinstance(a, str) and a.startswith("x-api-key:"):
            if a == target:
                already = True
            else:
                args[i] = target
                patched = True
            break

# Legacy 0.1.x shape: type:http + headers.x-api-key.
if not patched and not already and isinstance(entry.get("headers"), dict):
    hdrs = entry["headers"]
    if "x-api-key" in hdrs:
        if hdrs["x-api-key"] == key:
            already = True
        else:
            hdrs["x-api-key"] = key
            patched = True

if already:
    sys.exit(3)
if not patched:
    sys.exit(4)  # neither shape recognized

entry.pop("note", None)
with open(path, "w") as fh:
    json.dump(data, fh, indent=2)
    fh.write("\n")
sys.exit(0)
'; then
            rf::dim "  embedded API key in $mcp_file"
            patched=1
        else
            local rc=$?
            case $rc in
                3) rf::dim "  already up to date: $mcp_file"; patched=1 ;;
                2) ;;  # no roboflow server in this version, skip silently
                4) rf::warn "unrecognized .mcp.json shape in $mcp_file — run \`claude plugin uninstall roboflow\` and re-run agents.sh to refresh" ;;
                *) rf::warn "failed to patch $mcp_file (exit $rc)" ;;
            esac
        fi
    done

    [[ $patched -eq 0 ]] && rf::warn "no plugin .mcp.json found to patch under $cache_dir"
    return 0
}

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
        rf::host::claude_code_cli::patch_cache
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

    # Bake the resolved API key into the cached plugin's .mcp.json so the
    # MCP server authenticates without the user needing to export
    # ROBOFLOW_API_KEY anywhere.
    rf::host::claude_code_cli::patch_cache

    local entry
    entry="$(rf::host::claude_code_cli::manifest_entry "$marketplace_source" "$plugin_name")"
    rf::manifest::record "$entry" || rf::warn "could not update installer manifest (non-fatal)"

    rf::ok "Roboflow plugin installed for $RF_HOST_LABEL"
    rf::dim "Also enables Roboflow in the Code tab of Claude Desktop (same plugin system)."
    return 0
}

rf::host::claude_code_cli::uninstall() {
    rf::header "Removing Roboflow plugin from $RF_HOST_LABEL"
    if ! rf::on_path claude; then
        rf::warn "claude not on PATH; skipping uninstall (run \`claude plugin remove roboflow\` manually)"
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
    local now key_marker
    now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    if [[ -n "${RF_API_KEY:-}" ]]; then
        key_marker='inlined'
    else
        key_marker='placeholder'
    fi
    cat <<EOF
{
  "host_id": "$RF_HOST_ID",
  "component": "plugin",
  "scope": "${RF_OPT_SCOPE:-global}",
  "marketplace": "$source",
  "plugin_name": "$plugin_name",
  "api_key_mode": "$key_marker",
  "installer_version": "$RF_INSTALLER_VERSION",
  "installed_at": "$now",
  "updated_at": "$now"
}
EOF
}
