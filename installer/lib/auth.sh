#!/usr/bin/env bash
# auth.sh — resolve the user's Roboflow API key.
#
# Precedence:
#   1. --api-key=<key>           (RF_OPT_API_KEY exported by main.sh)
#   2. $ROBOFLOW_API_KEY         (env var)
#   3. ~/.config/roboflow/config.json (Python SDK config; honors $ROBOFLOW_CONFIG_DIR)
#      - single workspace → use it
#      - multiple → prompt to pick (or use --workspace=<url>)
#   4. interactive prompt (skipped when --yes or --auth-skip)
#
# Sets RF_API_KEY to the resolved key, or empty string if --auth-skip.
# Sets RF_API_KEY_SOURCE to a short label describing where the key came from
# (used by main.sh to print a status line).
# shellcheck disable=SC2034  # RF_API_KEY_SOURCE is read by main.sh after sourcing.

# Resolve the Roboflow Python SDK config dir.
rf::auth::sdk_config_dir() {
    if [[ -n "${ROBOFLOW_CONFIG_DIR:-}" ]]; then
        printf '%s' "$ROBOFLOW_CONFIG_DIR"
        return 0
    fi
    if rf::is_macos || rf::is_linux; then
        printf '%s/.config/roboflow' "$HOME"
    else
        printf '%s/roboflow' "$HOME"
    fi
}

# Read api key from SDK config. Sets RF_API_KEY on success; returns 1 if no key resolved.
# On multiple workspaces with no --workspace, prompts the user (unless --yes, in which case fails).
# rf::auth::sdk_workspace_key <config_path> <url>
# Read the apiKey for a specific workspace. Workspace keys are full URLs and
# can't be addressed via dotted-path expressions, so this uses python3/jq
# directly with the URL as an argument.
rf::auth::sdk_workspace_key() {
    local file="$1" url="$2"
    rf::json::detect || return 1
    if [[ "$RF_JSON_TOOL" == "python3" ]]; then
        FILE="$file" URL="$url" python3 -c '
import json, os, sys
with open(os.environ["FILE"]) as fh:
    data = json.load(fh)
ws = data.get("workspaces", {}).get(os.environ["URL"], {})
key = ws.get("apiKey")
if key:
    print(key)
'
    else
        jq -r --arg url "$url" '.workspaces[$url].apiKey // empty' "$file"
    fi
}

# rf::auth::sdk_workspace_name <config_path> <url> — friendly name or URL.
rf::auth::sdk_workspace_name() {
    local file="$1" url="$2"
    rf::json::detect || return 1
    if [[ "$RF_JSON_TOOL" == "python3" ]]; then
        FILE="$file" URL="$url" python3 -c '
import json, os, sys
with open(os.environ["FILE"]) as fh:
    data = json.load(fh)
ws = data.get("workspaces", {}).get(os.environ["URL"], {})
print(ws.get("name") or os.environ["URL"])
'
    else
        jq -r --arg url "$url" '.workspaces[$url].name // $url' "$file"
    fi
}

rf::auth::from_sdk_config() {
    local config_dir config_path
    config_dir="$(rf::auth::sdk_config_dir)"
    config_path="$config_dir/config.json"
    [[ -f "$config_path" ]] || return 1

    rf::json::has_tool || return 1

    # Read all workspace URLs into an array (avoids the head -n1 + pipefail
    # SIGPIPE pitfall and lets us index without re-reading).
    local urls=()
    local url
    while IFS= read -r url; do
        [[ -n "$url" ]] && urls+=("$url")
    done < <(rf::json::keys "$config_path" .workspaces)

    local workspace_count="${#urls[@]}"
    local default_url
    default_url="$(rf::json::read_field "$config_path" .RF_WORKSPACE 2>/dev/null || true)"

    [[ $workspace_count -eq 0 ]] && return 1

    local target_url=""
    if [[ -n "${RF_OPT_WORKSPACE:-}" ]]; then
        target_url="$RF_OPT_WORKSPACE"
    elif [[ $workspace_count -eq 1 ]]; then
        target_url="${urls[0]}"
    elif [[ -n "$default_url" ]] && [[ "$default_url" != "null" ]]; then
        target_url="$default_url"
    elif [[ "${RF_YES:-0}" == "1" ]]; then
        rf::warn "multiple workspaces in $config_path; pass --workspace=<url> to choose one"
        return 1
    else
        rf::info "Multiple Roboflow workspaces found:"
        local i=1
        for url in "${urls[@]}"; do
            local name
            name="$(rf::auth::sdk_workspace_name "$config_path" "$url")"
            rf::info "  [$i] $name ($url)"
            i=$((i + 1))
        done
        local choice
        choice="$(rf::prompt "Pick workspace [1-${#urls[@]}]:" "1")"
        if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le "${#urls[@]}" ]]; then
            target_url="${urls[$((choice - 1))]}"
        else
            return 1
        fi
    fi

    [[ -n "$target_url" ]] || return 1
    local key
    key="$(rf::auth::sdk_workspace_key "$config_path" "$target_url")"
    if [[ -n "$key" ]]; then
        RF_API_KEY="$key"
        RF_API_KEY_SOURCE="sdk-config:$target_url"
        return 0
    fi
    return 1
}

# rf::auth::resolve — populate RF_API_KEY, RF_API_KEY_SOURCE.
# Returns 0 on success or with --auth-skip; non-zero only on hard error.
rf::auth::resolve() {
    if [[ "${RF_OPT_AUTH_SKIP:-0}" == "1" ]]; then
        RF_API_KEY=""
        RF_API_KEY_SOURCE="skipped"
        return 0
    fi

    if [[ -n "${RF_OPT_API_KEY:-}" ]]; then
        RF_API_KEY="$RF_OPT_API_KEY"
        RF_API_KEY_SOURCE="--api-key flag"
        return 0
    fi

    if [[ -n "${ROBOFLOW_API_KEY:-}" ]]; then
        RF_API_KEY="$ROBOFLOW_API_KEY"
        RF_API_KEY_SOURCE="ROBOFLOW_API_KEY env"
        return 0
    fi

    if rf::auth::from_sdk_config; then
        return 0
    fi

    if [[ "${RF_YES:-0}" == "1" ]]; then
        rf::warn "no API key found (env, SDK config, flag); installs will skip auth wiring"
        RF_API_KEY=""
        RF_API_KEY_SOURCE="missing"
        return 0
    fi

    rf::info "Roboflow MCP authenticates via the ROBOFLOW_API_KEY environment variable."
    rf::info "Get yours at https://app.roboflow.com/settings/api"
    local key
    key="$(rf::prompt_secret "Paste your Roboflow API key (or press Enter to skip):")"
    if [[ -n "$key" ]]; then
        RF_API_KEY="$key"
        RF_API_KEY_SOURCE="prompt"
    else
        RF_API_KEY=""
        RF_API_KEY_SOURCE="skipped"
    fi
    return 0
}

# rf::auth::shell_export_hint — tell the user the env-var line they should add
# to their shell rc file. Called after resolve() to provide a copy-paste line.
rf::auth::shell_export_hint() {
    [[ -n "${RF_API_KEY:-}" ]] || return 0
    if [[ "${ROBOFLOW_API_KEY:-}" == "$RF_API_KEY" ]]; then
        return 0
    fi
    rf::info ""
    rf::info "${RF_COLOR_BOLD}Add this to your shell profile so agents can authenticate:${RF_COLOR_RESET}"
    rf::info "  export ROBOFLOW_API_KEY=********"
    rf::dim   "  (use the key you just provided; we don't echo it back)"
}
