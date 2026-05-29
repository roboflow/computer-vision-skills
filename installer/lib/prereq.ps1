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
    $npxPath = Find-RfNpx
    if ($npxPath) {
        Use-RfNpx -NpxPath $npxPath
        $v = & $npxPath --version 2>$null
        if (-not $v) { $v = '(unknown version)' }
        Write-RfDim "  npx detected: $v ($npxPath)"
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

    $npxPath = Find-RfNpx
    if ($npxPath) {
        Use-RfNpx -NpxPath $npxPath
        $v = & $npxPath --version 2>$null
        Write-RfOk "Node.js installed: npx $v ($npxPath)"
        return $true
    }
    Write-RfErr 'Node.js installer reported success but npx still not found. Open a new PowerShell window and re-run agents.ps1.'
    return $false
}

# Find-RfNpx — locate npx without trusting Get-Command's per-session cache.
# Returns the full path to npx.cmd, or $null. Checks the current PATH first,
# then known Node install locations (system-wide, user-scope, npm global).
# This matters because winget may install Node and update the persistent
# PATH in the registry, but PowerShell only re-reads PATH at process start,
# and Get-Command caches "not found" results.
function Find-RfNpx {
    $cmd = Get-Command npx -CommandType Application, ExternalScript -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    if (-not (Test-RfWindows)) { return $null }

    $candidates = @(
        (Join-Path $env:ProgramFiles 'nodejs\npx.cmd'),
        (Join-Path ${env:ProgramFiles(x86)} 'nodejs\npx.cmd'),
        (Join-Path $env:LOCALAPPDATA 'Programs\nodejs\npx.cmd'),
        (Join-Path $env:APPDATA 'npm\npx.cmd')
    )
    foreach ($c in $candidates) {
        if ($c -and (Test-Path -LiteralPath $c)) { return $c }
    }
    return $null
}

# Use-RfNpx — make sure npx's directory is on the *current* session's PATH
# so adapters that shell out to bare `npx` resolve it.
function Use-RfNpx {
    param([Parameter(Mandatory)][string]$NpxPath)
    $dir = Split-Path -Parent $NpxPath
    if (-not $dir) { return }
    $sep = if (Test-RfWindows) { ';' } else { ':' }
    $parts = $env:PATH -split [regex]::Escape($sep)
    if ($parts -notcontains $dir) {
        $env:PATH = "$dir$sep$env:PATH"
    }
}

function Install-RfNodeWindows {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-RfErr 'winget not available — install Node.js manually from https://nodejs.org'
        return $false
    }
    # --source winget pins to the winget repository explicitly. Skips
    # msstore, which on some corporate boxes fails with a cert-validation
    # error ("server certificate did not match"). The Node.js LTS package
    # lives in the winget source anyway, so this only removes a flaky path.
    Write-RfStep 'winget install OpenJS.NodeJS.LTS --source winget --silent'
    & winget install --id OpenJS.NodeJS.LTS --source winget `
        --accept-source-agreements --accept-package-agreements --silent 2>&1 |
        ForEach-Object { Write-Host $_ }
    # Don't trust the exit code by itself — winget can return non-zero when
    # a secondary source fails or a UAC prompt was suppressed, even though
    # the actual install succeeded. Verify by disk in the caller via
    # Find-RfNpx.
    if ($LASTEXITCODE -ne 0) {
        Write-RfWarn "winget reported non-zero exit ($LASTEXITCODE); verifying install state regardless"
    }
    # Refresh PATH from both registry hives. winget's Node install writes
    # to the Machine hive when system-scope, User hive when user-scope.
    $machinePath = [Environment]::GetEnvironmentVariable('PATH', 'Machine')
    $userPath    = [Environment]::GetEnvironmentVariable('PATH', 'User')
    $merged = @($machinePath, $userPath) | Where-Object { $_ } | ForEach-Object { $_ }
    if ($merged) { $env:PATH = ($merged -join ';') }
    return $true
}
