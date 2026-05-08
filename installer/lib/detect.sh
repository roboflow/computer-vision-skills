#!/usr/bin/env bash
# detect.sh — locate installed coding agents.
#
# Each detect function prints a single line "id|kind|label|hint" if found,
# nothing if not. Higher-level rf::detect::all aggregates them.
#
# id: stable host id used elsewhere (matches installer/hosts/<id>.sh)
# kind: cli | desktop
# label: human-readable name
# hint: short note about how it was detected (path, version, etc.)

rf::detect::claude_code_cli() {
    if rf::on_path claude; then
        local v
        v="$(claude --version 2>/dev/null | head -n1 || true)"
        printf 'claude-code-cli|cli|Claude Code CLI|%s\n' "${v:-detected on PATH}"
    fi
}

rf::detect::codex_cli() {
    if rf::on_path codex; then
        local v
        v="$(codex --version 2>/dev/null | head -n1 || true)"
        printf 'codex-cli|cli|Codex CLI|%s\n' "${v:-detected on PATH}"
    fi
}

# Aggregator: print one line per detected host. Phase 1 only includes
# claude-code-cli and codex-cli; later phases add more rf::detect::<host>
# functions and call them here.
rf::detect::all() {
    rf::detect::claude_code_cli
    rf::detect::codex_cli
}

# rf::detect::lookup <id>
# Run the appropriate detect function and emit the matching line if present.
# Used to validate --host=<id> requests.
rf::detect::lookup() {
    local id="$1"
    case "$id" in
        claude-code-cli) rf::detect::claude_code_cli ;;
        codex-cli) rf::detect::codex_cli ;;
        *) return 1 ;;
    esac
}

# rf::detect::known_ids — print the full set of host ids the installer knows
# about, one per line. Includes hosts not yet implemented (used by --host
# validation to tell the user "we know about X but it's not supported yet").
rf::detect::known_ids() {
    cat <<'EOF'
claude-code-cli
codex-cli
EOF
}
