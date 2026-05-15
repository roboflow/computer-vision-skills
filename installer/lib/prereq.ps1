<#
prereq.ps1 — runtime prerequisite checks and (optional) auto-install.

Scoped to Node.js (npx) — the Claude Code plugin's .mcp.json launches
`npx -y mcp-remote@<ver> ...` to bridge HTTP MCP over stdio, and the
claude-desktop adapter writes the same bridge into the chat-tab config.
#>

$Script:RfPrereqNodeHosts = @('claude-code-cli', 'codex-cli', 'claude-desktop')

function Test-RfHostNeedsNode {
    param([string]$Id)
    return $Script:RfPrereqNodeHosts -contains $Id
}

function Test-RfAnyHostNeedsNode {
    param([string[]]$Ids)
    foreach ($id in $Ids) {
        if (Test-RfHostNeedsNode -Id $id) { return $true }
    }
    return $false
}

function Get-RfNodeInstallMethodLabel {
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        return 'winget (OpenJS.NodeJS.LTS, no admin)'
    }
    return 'manual download from https://nodejs.org'
}

# Confirm-RfNpxAvailable — verify npx on PATH; offer to install Node LTS
# via winget if missing. Returns $true if npx is available (now or after
# install), $false otherwise. Respects $Script:RfOptNoInstallNode and
# $Script:RfYes.
function Confirm-RfNpxAvailable {
    if (Test-RfOnPath 'npx') {
        $v = & npx --version 2>$null
        if (-not $v) { $v = '(unknown version)' }
        Write-RfDim "  npx detected: $v"
        return $true
    }

    Write-RfWarn 'npx (Node.js) is required for the selected hosts.'
    Write-RfInfo 'Roboflow MCP runs as `npx -y mcp-remote ...` (an HTTP-to-stdio bridge)'
    Write-RfInfo 'when your agent starts up. Manual install: https://nodejs.org'

    if ($Script:RfOptNoInstallNode) {
        Write-RfErr '--no-install-node set; install Node.js manually and re-run.'
        return $false
    }

    if ($Script:RfOptDryRun) {
        Write-RfInfo "[dry-run] would install Node.js LTS via $(Get-RfNodeInstallMethodLabel)"
        return $true
    }

    if (-not $Script:RfYes) {
        # Default to yes: the alternative is "installer aborts with no
        # progress, user manually installs Node, re-runs," which is worse
        # than a winget install in every case where the user didn't have a
        # specific reason to refuse. Refusing is still one keystroke (`n`).
        if (-not (Confirm-Rf -Prompt "Install Node.js LTS now via $(Get-RfNodeInstallMethodLabel)?" -DefaultAnswer 'y')) {
            Write-RfErr 'Node.js is required to proceed. Install it from https://nodejs.org and re-run agents.ps1.'
            return $false
        }
    }

    if (-not (Install-RfNodeWindows)) {
        Write-RfErr 'Node.js install failed. Install manually from https://nodejs.org and re-run.'
        return $false
    }

    if (Test-RfOnPath 'npx') {
        $v = & npx --version 2>$null
        Write-RfOk "Node.js installed: npx $v"
        return $true
    }
    Write-RfErr 'Node.js installer reported success but npx still not on PATH. Restart your shell and re-run.'
    return $false
}

function Install-RfNodeWindows {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-RfErr 'winget not available — install Node.js manually from https://nodejs.org'
        return $false
    }
    Write-RfStep 'winget install OpenJS.NodeJS.LTS --silent'
    & winget install --id OpenJS.NodeJS.LTS --accept-source-agreements --accept-package-agreements --silent 2>&1 | ForEach-Object { Write-Host $_ }
    # Some winget releases return non-zero on --silent when a UAC prompt
    # appeared; don't trust the exit code by itself. Refresh PATH and
    # check whether npx is actually visible.
    if ($LASTEXITCODE -ne 0) {
        Write-RfWarn "winget reported non-zero exit ($LASTEXITCODE); verifying install state regardless"
    }
    $env:PATH = [Environment]::GetEnvironmentVariable('PATH', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('PATH', 'User')
    return $true
}
