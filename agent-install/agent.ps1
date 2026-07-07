# Roboflow agent installer (Windows / PowerShell).
#
# Served from https://repo.roboflow.com/agent-install/agent.ps1
# Source of truth: https://github.com/roboflow/computer-vision-skills/blob/main/agent-install/agent.ps1
#
# Usage:
#   iwr -useb https://repo.roboflow.com/agent-install/agent.ps1 | iex
#
# TODO: install logic. Until it lands, fail loudly so a no-op is never mistaken
# for a successful install.
$ErrorActionPreference = "Stop"

Write-Error "Roboflow agent installer is not yet available. Nothing was installed."
exit 1
