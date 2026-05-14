#!/usr/bin/env bats
# Tests for the Claude Code CLI adapter (plugin install path).

load 'helpers/setup'

setup() {
    rf_test::isolated_home
    export NO_COLOR=1
    export ROBOFLOW_API_KEY=rf_test_key
    # The Claude Code plugin now needs npx at runtime (mcp-remote bridge).
    # Stub it so prereq check passes; individual install calls don't actually
    # invoke npx.
    rf_test::stub_command "npx" 0 "10.5.0"
}

teardown() {
    rf_test::cleanup_home
}

@test "claude install: dry-run prints plan without invoking plugin commands" {
    rf_test::stub_command "claude" 0
    run bash "$RF_REPO_ROOT/installer/main.sh" --yes --host=claude-code-cli --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"[dry-run]"* ]]
    [[ "$output" == *"plugin marketplace add"* ]]
    [[ "$output" == *"plugin install"* ]]
    # The detect step invokes `claude --version`; that's allowed. What we
    # disallow is the actual plugin install/marketplace commands running.
    local calls
    calls="$(rf_test::stub_calls claude || true)"
    if [[ "$calls" == *"arg: plugin"* ]]; then
        echo "ERROR: plugin command was invoked under --dry-run: $calls" >&2
        return 1
    fi
}

@test "claude install: invokes plugin marketplace add and plugin install" {
    rf_test::stub_command "claude" 0
    run bash "$RF_REPO_ROOT/installer/main.sh" --yes --host=claude-code-cli
    [ "$status" -eq 0 ]

    local calls
    calls="$(rf_test::stub_calls claude)"
    [[ "$calls" == *"plugin"* ]]
    [[ "$calls" == *"marketplace"* ]]
    [[ "$calls" == *"add"* ]]
    [[ "$calls" == *"roboflow/computer-vision-skills"* ]]
    [[ "$calls" == *"install"* ]]
    [[ "$calls" == *"roboflow"* ]]

    # Two calls: marketplace add + plugin install.
    [ "$(rf_test::stub_call_count claude)" -ge "2" ]
}

@test "claude install: writes a manifest entry" {
    rf_test::stub_command "claude" 0
    run bash "$RF_REPO_ROOT/installer/main.sh" --yes --host=claude-code-cli
    [ "$status" -eq 0 ]
    [ -f "$HOME/.config/roboflow/installations.json" ]
    grep -q '"host_id": "claude-code-cli"' "$HOME/.config/roboflow/installations.json"
    grep -q '"component": "plugin"' "$HOME/.config/roboflow/installations.json"
}

@test "claude install: patches cached .mcp.json (stdio shape) with literal key" {
    # Pretend the plugin is already cached (claude plugin install would do this).
    local cache_dir="$HOME/.claude/plugins/cache/roboflow/roboflow/0.2.0"
    mkdir -p "$cache_dir"
    cat >"$cache_dir/.mcp.json" <<'EOF'
{
  "mcpServers": {
    "roboflow": {
      "command": "npx",
      "args": [
        "-y",
        "mcp-remote@0.1.27",
        "https://mcp.roboflow.com/mcp",
        "--header",
        "x-api-key:${ROBOFLOW_API_KEY}"
      ],
      "note": "Replace ${ROBOFLOW_API_KEY} with your key."
    }
  }
}
EOF
    rf_test::stub_command "claude" 0
    run bash "$RF_REPO_ROOT/installer/main.sh" --yes --host=claude-code-cli
    [ "$status" -eq 0 ]
    grep -q '"x-api-key:rf_test_key"' "$cache_dir/.mcp.json"
    if grep -q '${ROBOFLOW_API_KEY}' "$cache_dir/.mcp.json"; then return 1; fi
    if grep -q '"note":' "$cache_dir/.mcp.json"; then return 1; fi
    grep -q '"api_key_mode": "inlined"' "$HOME/.config/roboflow/installations.json"
}

@test "claude install: legacy http-shape cache is still patched (back-compat)" {
    # Users who installed under plugin 0.1.x have the http shape cached. The
    # patcher should handle either shape so updaters land smoothly.
    local cache_dir="$HOME/.claude/plugins/cache/roboflow/roboflow/0.1.0"
    mkdir -p "$cache_dir"
    cat >"$cache_dir/.mcp.json" <<'EOF'
{
  "mcpServers": {
    "roboflow": {
      "type": "http",
      "url": "https://mcp.roboflow.com/mcp",
      "headers": {
        "x-api-key": "${ROBOFLOW_API_KEY}",
        "Accept": "application/json, text/event-stream"
      },
      "note": "Set ROBOFLOW_API_KEY in env to authenticate."
    }
  }
}
EOF
    rf_test::stub_command "claude" 0
    run bash "$RF_REPO_ROOT/installer/main.sh" --yes --host=claude-code-cli
    [ "$status" -eq 0 ]
    grep -q '"x-api-key": "rf_test_key"' "$cache_dir/.mcp.json"
    if grep -q '${ROBOFLOW_API_KEY}' "$cache_dir/.mcp.json"; then return 1; fi
}

@test "claude install: re-running on already-patched stdio cache is a no-op" {
    local cache_dir="$HOME/.claude/plugins/cache/roboflow/roboflow/0.2.0"
    mkdir -p "$cache_dir"
    cat >"$cache_dir/.mcp.json" <<'EOF'
{
  "mcpServers": {
    "roboflow": {
      "command": "npx",
      "args": [
        "-y",
        "mcp-remote@0.1.27",
        "https://mcp.roboflow.com/mcp",
        "--header",
        "x-api-key:rf_test_key"
      ]
    }
  }
}
EOF
    rf_test::stub_command "claude" 0
    run bash "$RF_REPO_ROOT/installer/main.sh" --yes --host=claude-code-cli
    [ "$status" -eq 0 ]
    [[ "$output" == *"already up to date"* ]]
}

@test "claude install: --auth-skip leaves placeholder in stdio cache, warns" {
    local cache_dir="$HOME/.claude/plugins/cache/roboflow/roboflow/0.2.0"
    mkdir -p "$cache_dir"
    cat >"$cache_dir/.mcp.json" <<'EOF'
{
  "mcpServers": {
    "roboflow": {
      "command": "npx",
      "args": ["-y", "mcp-remote@0.1.27", "https://mcp.roboflow.com/mcp", "--header", "x-api-key:${ROBOFLOW_API_KEY}"]
    }
  }
}
EOF
    rf_test::stub_command "claude" 0
    unset ROBOFLOW_API_KEY
    run bash "$RF_REPO_ROOT/installer/main.sh" --yes --host=claude-code-cli --auth-skip
    [ "$status" -eq 0 ]
    grep -q '${ROBOFLOW_API_KEY}' "$cache_dir/.mcp.json"
    [[ "$output" == *"no API key resolved"* ]]
}

@test "claude install: --project sets scope local" {
    rf_test::stub_command "claude" 0
    run bash "$RF_REPO_ROOT/installer/main.sh" --yes --host=claude-code-cli --project
    [ "$status" -eq 0 ]
    local calls
    calls="$(rf_test::stub_calls claude)"
    [[ "$calls" == *"--scope"* ]]
    [[ "$calls" == *"local"* ]]
}

@test "claude install: missing claude exits non-zero with hint" {
    # No stub — claude not on PATH.
    
    run bash "$RF_REPO_ROOT/installer/main.sh" --yes --host=claude-code-cli
    [ "$status" -ne 0 ]
    [[ "$output" == *"claude not found on PATH"* ]]
}

@test "claude install: marketplace-add nonzero is treated as warning" {
    rf_test::stub_command "claude" 1 "" "already registered"
    # Stub returns 1 always, including for plugin install. Test should fail.
    run bash "$RF_REPO_ROOT/installer/main.sh" --yes --host=claude-code-cli
    [ "$status" -ne 0 ]
    # We still attempted both.
    [ "$(rf_test::stub_call_count claude)" -ge "2" ]
}

@test "claude uninstall: invokes plugin remove" {
    rf_test::stub_command "claude" 0
    run bash "$RF_REPO_ROOT/installer/main.sh" --yes --host=claude-code-cli --uninstall
    [ "$status" -eq 0 ]
    local calls
    calls="$(rf_test::stub_calls claude)"
    [[ "$calls" == *"plugin"* ]]
    [[ "$calls" == *"remove"* ]]
    [[ "$calls" == *"roboflow"* ]]
}

@test "claude install: re-run is idempotent" {
    rf_test::stub_command "claude" 0
    run bash "$RF_REPO_ROOT/installer/main.sh" --yes --host=claude-code-cli
    [ "$status" -eq 0 ]
    run bash "$RF_REPO_ROOT/installer/main.sh" --yes --host=claude-code-cli
    [ "$status" -eq 0 ]
    # Manifest should still exist with one claude-code-cli entry, not duplicated.
    local count
    count="$(grep -c '"host_id": "claude-code-cli"' "$HOME/.config/roboflow/installations.json")"
    [ "$count" -eq 1 ]
}
