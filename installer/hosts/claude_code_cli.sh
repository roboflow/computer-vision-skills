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

# Mirror that `claude plugin marketplace add` clones to. Field debugging
# on a real install showed Claude Code reads the plugin's MCP config
# from this mirror, not the cache, so we have to patch it too -- else
# the literal ${ROBOFLOW_API_KEY} placeholder stays live in mcpServers.
rf::host::claude_code_cli::marketplace_dir() {
    printf '%s/.claude/plugins/marketplaces/roboflow' "$HOME"
}

# Find every roboflow plugin .mcp.json (under cache/ and marketplaces/)
# and replace its x-api-key placeholder/value with the resolved literal
# key. Idempotent on re-run. No-op (returns 0) if RF_API_KEY is empty so
# users with --auth-skip can still install.
rf::host::claude_code_cli::patch_cache() {
    local key="${RF_API_KEY:-}"
    if [[ -z "$key" ]]; then
        rf::warn "no API key resolved — Roboflow MCP will keep \${ROBOFLOW_API_KEY} placeholder"
        rf::dim "  set ROBOFLOW_API_KEY in your shell, or re-run with --api-key=<key>"
        return 0
    fi

    rf::json::has_tool || rf::die "no JSON tool available (need python3 or jq)"

    # Build the list of .mcp.json files to patch. Recurse so future
    # layouts that move the file under .claude-plugin/ are also caught.
    local roots=()
    local cache_dir marketplace_dir
    cache_dir="$(rf::host::claude_code_cli::cache_dir)"
    marketplace_dir="$(rf::host::claude_code_cli::marketplace_dir)"
    [[ -d "$cache_dir" ]] && roots+=("$cache_dir")
    [[ -d "$marketplace_dir" ]] && roots+=("$marketplace_dir")
    if [[ ${#roots[@]} -eq 0 ]]; then
        rf::warn "plugin cache + marketplace not found under $cache_dir, $marketplace_dir"
        return 1
    fi

    local mcp_files=()
    local r f
    for r in "${roots[@]}"; do
        while IFS= read -r f; do mcp_files+=("$f"); done < <(find "$r" -type f -name '.mcp.json' 2>/dev/null)
    done

    if [[ ${#mcp_files[@]} -eq 0 ]]; then
        rf::warn "no plugin .mcp.json found under: ${roots[*]}"
        return 0
    fi

    local patched=0 mcp_file
    for mcp_file in "${mcp_files[@]}"; do
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
    sys.exit(2)  # no roboflow server in this file, skip

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
                2) ;;  # no roboflow server in this file, skip silently
                4) rf::warn "unrecognized .mcp.json shape in $mcp_file — run \`claude plugin uninstall roboflow\` and re-run agents.sh to refresh" ;;
                *) rf::warn "failed to patch $mcp_file (exit $rc)" ;;
            esac
        fi
    done

    [[ $patched -eq 0 ]] && rf::warn "no roboflow MCP entry found in any of ${#mcp_files[@]} .mcp.json file(s)"
    return 0
}

rf::host::claude_code_cli::install() {
    rf::header "Installing Roboflow plugin for $RF_HOST_LABEL"

    local claude
    if ! claude="$(rf::resolve_claude_cli)"; then
        rf::err "claude not found (PATH or any known install location)"
        rf::dim "Install Claude Code: https://docs.claude.com/claude-code"
        return 1
    fi
    if [[ "$claude" != "claude" ]]; then
        rf::dim "using claude at: $claude (not on PATH)"
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
    if ! "$claude" plugin marketplace add "$marketplace_source" 2>&1; then
        rf::warn "marketplace add reported a non-zero exit (may already be registered); continuing"
    fi

    rf::step "claude plugin install $plugin_name $scope_flag"
    # shellcheck disable=SC2086
    if ! "$claude" plugin install "$plugin_name" $scope_flag 2>&1; then
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
    local claude
    if ! claude="$(rf::resolve_claude_cli)"; then
        rf::warn "claude not found; skipping uninstall (run \`claude plugin remove roboflow\` manually)"
        return 0
    fi

    if [[ "${RF_OPT_DRY_RUN:-0}" == "1" ]]; then
        rf::info "[dry-run] would run: claude plugin remove roboflow"
        return 0
    fi

    if "$claude" plugin remove roboflow 2>&1; then
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
