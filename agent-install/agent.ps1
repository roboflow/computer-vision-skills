# Roboflow agent installer (Windows / PowerShell).
#
# Served from https://repo.roboflow.com/agent-install/agent.ps1
# Source of truth: https://github.com/roboflow/computer-vision-skills/blob/main/agent-install/agent.ps1
#
# Usage:
#   iwr -useb https://repo.roboflow.com/agent-install/agent.ps1 | iex
#
[CmdletBinding()]
param(
    [switch] $CodexOnly,
    [switch] $ClaudeOnly
)

$ErrorActionPreference = "Stop"

$Source = if ($env:ROBOFLOW_PLUGIN_SOURCE) { $env:ROBOFLOW_PLUGIN_SOURCE } else { "roboflow/computer-vision-skills" }
$Marketplace = if ($env:ROBOFLOW_PLUGIN_MARKETPLACE) { $env:ROBOFLOW_PLUGIN_MARKETPLACE } else { "roboflow" }
$Plugin = if ($env:ROBOFLOW_PLUGIN_NAME) { $env:ROBOFLOW_PLUGIN_NAME } else { "roboflow" }

$WantCodex = -not $ClaudeOnly
$WantClaude = -not $CodexOnly
$Installed = $false

function Install-CodexPlugin {
    if (-not (Get-Command codex -ErrorAction SilentlyContinue)) {
        Write-Host "codex not found; skipping Codex install."
        return $false
    }

    Write-Host "Registering Roboflow marketplace for Codex..."
    & codex plugin marketplace add $Source
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Codex marketplace add failed; trying install with an existing marketplace named '$Marketplace'."
    }

    Write-Host "Installing Roboflow plugin for Codex..."
    & codex plugin add "$Plugin@$Marketplace"
    if ($LASTEXITCODE -ne 0) {
        & codex plugin add $Plugin --marketplace $Marketplace
    }
    return ($LASTEXITCODE -eq 0)
}

function Install-ClaudePlugin {
    if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
        Write-Host "claude not found; skipping Claude Code install."
        return $false
    }

    Write-Host "Registering Roboflow marketplace for Claude Code..."
    & claude plugin marketplace add $Source
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Claude marketplace add failed; trying install with an existing marketplace."
    }

    Write-Host "Installing Roboflow plugin for Claude Code..."
    & claude plugin install $Plugin
    return ($LASTEXITCODE -eq 0)
}

if ($WantCodex -and (Install-CodexPlugin)) {
    $Installed = $true
}

if ($WantClaude -and (Install-ClaudePlugin)) {
    $Installed = $true
}

if (-not $Installed) {
    Write-Error "No supported agent CLI was installed successfully. Install Codex or Claude Code, then rerun this script."
    exit 1
}

Write-Host "Roboflow plugin installation completed. Restart your agent so it reloads plugin metadata."
