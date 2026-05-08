#!/usr/bin/env bash
# agents.sh — Roboflow coding-agent installer (entry bootstrap).
#
# Lives at installer/agents.sh in the source tree. Two modes:
#   1. Local checkout: `bash installer/agents.sh [args]` from a clone — execs
#      main.sh from the same directory.
#   2. Pipe-from-curl: `curl -fsSL https://roboflow.com/agents.sh | bash` —
#      downloads a tarball of this repo, extracts to ~/.cache/roboflow-agents/,
#      execs installer/main.sh from there.
#
# Override the ref with ROBOFLOW_AGENTS_REF=<branch-or-tag> for testing.

set -euo pipefail

ROBOFLOW_AGENTS_REPO="${ROBOFLOW_AGENTS_REPO:-roboflow/computer-vision-skills}"
ROBOFLOW_AGENTS_REF="${ROBOFLOW_AGENTS_REF:-main}"

# Local-checkout mode: agents.sh sits next to main.sh under installer/.
if [[ -n "${BASH_SOURCE[0]:-}" ]] && [[ -f "${BASH_SOURCE[0]}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ -f "$SCRIPT_DIR/main.sh" ]]; then
        exec bash "$SCRIPT_DIR/main.sh" "$@"
    fi
fi

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/roboflow-agents"
mkdir -p "$CACHE_DIR"

TMP="$(mktemp -d "$CACHE_DIR/dl.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

TARBALL_URL="https://codeload.github.com/${ROBOFLOW_AGENTS_REPO}/tar.gz/refs/heads/${ROBOFLOW_AGENTS_REF}"

if ! command -v curl >/dev/null 2>&1; then
    echo "agents.sh: curl is required but not installed." >&2
    exit 1
fi
if ! command -v tar >/dev/null 2>&1; then
    echo "agents.sh: tar is required but not installed." >&2
    exit 1
fi

echo "Downloading installer from ${ROBOFLOW_AGENTS_REPO}@${ROBOFLOW_AGENTS_REF}…" >&2
if ! curl -fsSL "$TARBALL_URL" | tar -xz -C "$TMP"; then
    echo "agents.sh: failed to download or extract ${TARBALL_URL}" >&2
    exit 1
fi

EXTRACTED_DIR="$(find "$TMP" -mindepth 1 -maxdepth 1 -type d | head -n1)"
if [[ -z "$EXTRACTED_DIR" || ! -f "$EXTRACTED_DIR/installer/main.sh" ]]; then
    echo "agents.sh: installer/main.sh not found in extracted tarball" >&2
    exit 1
fi

exec bash "$EXTRACTED_DIR/installer/main.sh" "$@"
