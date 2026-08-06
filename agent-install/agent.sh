#!/usr/bin/env bash
# Roboflow agent installer (macOS / Linux).
#
# Served from https://repo.roboflow.com/agent-install/agent.sh
# Source of truth: https://github.com/roboflow/computer-vision-skills/blob/main/agent-install/agent.sh
#
# Usage:
#   curl -fsSL https://repo.roboflow.com/agent-install/agent.sh | bash
#
set -euo pipefail

SOURCE="${ROBOFLOW_PLUGIN_SOURCE:-roboflow/computer-vision-skills}"
MARKETPLACE="${ROBOFLOW_PLUGIN_MARKETPLACE:-roboflow}"
PLUGIN="${ROBOFLOW_PLUGIN_NAME:-roboflow}"

want_codex=1
want_claude=1

usage() {
  printf '%s\n' "Usage: $0 [--codex-only|--claude-only]"
  printf '%s\n' "Environment overrides:"
  printf '%s\n' "  ROBOFLOW_PLUGIN_SOURCE=$SOURCE"
  printf '%s\n' "  ROBOFLOW_PLUGIN_MARKETPLACE=$MARKETPLACE"
  printf '%s\n' "  ROBOFLOW_PLUGIN_NAME=$PLUGIN"
}

for arg in "$@"; do
  case "$arg" in
    --codex-only)
      want_codex=1
      want_claude=0
      ;;
    --claude-only)
      want_codex=0
      want_claude=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n\n' "$arg" >&2
      usage >&2
      exit 2
      ;;
  esac
done

installed=0

install_codex() {
  if ! command -v codex >/dev/null 2>&1; then
    printf '%s\n' "codex not found; skipping Codex install."
    return 1
  fi

  printf '%s\n' "Registering Roboflow marketplace for Codex..."
  if ! codex plugin marketplace add "$SOURCE"; then
    printf '%s\n' "Codex marketplace add failed; trying install with an existing marketplace named '$MARKETPLACE'."
  fi

  printf '%s\n' "Installing Roboflow plugin for Codex..."
  codex plugin add "${PLUGIN}@${MARKETPLACE}" || codex plugin add "$PLUGIN" --marketplace "$MARKETPLACE"
}

install_claude() {
  if ! command -v claude >/dev/null 2>&1; then
    printf '%s\n' "claude not found; skipping Claude Code install."
    return 1
  fi

  printf '%s\n' "Registering Roboflow marketplace for Claude Code..."
  if ! claude plugin marketplace add "$SOURCE"; then
    printf '%s\n' "Claude marketplace add failed; trying install with an existing marketplace."
  fi

  printf '%s\n' "Installing Roboflow plugin for Claude Code..."
  claude plugin install "$PLUGIN"
}

if [ "$want_codex" -eq 1 ] && install_codex; then
  installed=1
fi

if [ "$want_claude" -eq 1 ] && install_claude; then
  installed=1
fi

if [ "$installed" -ne 1 ]; then
  printf '%s\n' "No supported agent CLI was installed successfully. Install Codex or Claude Code, then rerun this script." >&2
  exit 1
fi

printf '%s\n' "Roboflow plugin installation completed. Restart your agent so it reloads plugin metadata."
