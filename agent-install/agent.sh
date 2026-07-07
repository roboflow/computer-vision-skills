#!/usr/bin/env bash
# Roboflow agent installer (macOS / Linux).
#
# Served from https://repo.roboflow.com/agent-install/agent.sh
# Source of truth: https://github.com/roboflow/computer-vision-skills/blob/main/agent-install/agent.sh
#
# Usage:
#   curl -fsSL https://repo.roboflow.com/agent-install/agent.sh | bash
#
# TODO: install logic. Until it lands, fail loudly so a no-op is never mistaken
# for a successful install.
set -euo pipefail

echo "Roboflow agent installer is not yet available. Nothing was installed." >&2
exit 1
