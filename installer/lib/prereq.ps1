<#
prereq.ps1 — runtime prerequisite checks and (optional) auto-install.

Scoped to Node.js (npx) — the Claude Code plugin's .mcp.json launches
`npx -y mcp-remote@<ver> ...` to bridge HTTP MCP over stdio, and the
claude-desktop adapter writes the same bridge into the chat-tab config.
#>

$Script:RfPrereqNodeHosts = @('claude-code-cli', 'codex-cli', 'claude-desktop')

# Hosts whose install path shells out to git — `plugin marketplace add
# <repo>` clones the marketplace, and on Windows Claude Code also needs the
# bash that Git for Windows bundles for its plugin/git operations. Only
# enforced on Windows (git is effectively always present on dev macOS/Linux,
# and there's no universal no-sudo installer there).
$Script:RfPrereqGitHosts = @('claude-code-cli', 'codex-cli')

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

function Test-RfHostNeedsGit {
    param([string]$Id)
    return $Script:RfPrereqGitHosts -contains $Id
}

function Test-RfAnyHostNeedsGit {
    param([string[]]$Ids)
    foreach ($id in $Ids) {
        if (Test-RfHostNeedsGit -Id $id) { return $true }
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
# Returns a SINGLE full path string to npx (or $null). Checks the current
# PATH first, then known Node install locations (system-wide, user-scope,
# npm global). This matters because winget may install Node and update the
# persistent PATH in the registry, but PowerShell only re-reads PATH at
# process start, and Get-Command caches "not found" results.
function Find-RfNpx {
    # Get-Command with two CommandTypes returns BOTH npx.cmd (Application)
    # and npx.ps1 (ExternalScript) when a Node install ships both, so the
    # result is an array. Collapse to one, preferring .cmd/.exe over .ps1
    # (piping a .ps1 through our outer pwsh would re-trigger ExecutionPolicy
    # prompts), and always return a scalar string so callers binding to a
    # [string] parameter don't blow up on a multi-element array.
    $cmds = @(Get-Command npx -CommandType Application, ExternalScript -ErrorAction SilentlyContinue)
    if ($cmds.Count -gt 0) {
        $preferred = $cmds | Sort-Object @{Expression = {
            switch -Regex ($_.Source) {
                '\.exe$' { 0; break }
                '\.cmd$' { 1; break }
                '\.bat$' { 2; break }
                default  { 3 }
            }
        }} | Select-Object -First 1
        return [string]$preferred.Source
    }
    if (-not (Test-RfWindows)) { return $null }

    $candidates = @(
        (Join-Path $env:ProgramFiles 'nodejs\npx.cmd'),
        (Join-Path ${env:ProgramFiles(x86)} 'nodejs\npx.cmd'),
        (Join-Path $env:LOCALAPPDATA 'Programs\nodejs\npx.cmd'),
        (Join-Path $env:APPDATA 'npm\npx.cmd')
    )
    foreach ($c in $candidates) {
        if ($c -and (Test-Path -LiteralPath $c)) { return [string]$c }
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
    # Invoke-RfNative so winget's stderr progress doesn't throw under the
    # script-wide ErrorActionPreference=Stop.
    $code = Invoke-RfNative -FilePath 'winget' -Arguments @(
        'install', '--id', 'OpenJS.NodeJS.LTS', '--source', 'winget',
        '--accept-source-agreements', '--accept-package-agreements', '--silent')
    # Don't trust the exit code by itself — winget can return non-zero when
    # a secondary source fails or a UAC prompt was suppressed, even though
    # the actual install succeeded. Verify by disk in the caller via
    # Find-RfNpx.
    if ($code -ne 0) {
        Write-RfWarn "winget reported non-zero exit ($code); verifying install state regardless"
    }
    Update-RfSessionPathFromRegistry
    return $true
}

# Update-RfSessionPathFromRegistry — rebuild $env:PATH from the persisted
# Machine + User hives so a just-completed winget install (which writes to
# one of those hives) is visible to the current process without a restart.
function Update-RfSessionPathFromRegistry {
    if (-not (Test-RfWindows)) { return }
    $machinePath = [Environment]::GetEnvironmentVariable('PATH', 'Machine')
    $userPath    = [Environment]::GetEnvironmentVariable('PATH', 'User')
    $merged = @($machinePath, $userPath) | Where-Object { $_ }
    if ($merged) { $env:PATH = ($merged -join ';') }
}

# Confirm-RfGitAvailable — Claude Code / Codex shell out to git for plugin
# marketplace operations, and on Windows Claude Code wants either Git for
# Windows (bash) or PowerShell 7. If neither git nor pwsh is present, offer
# to install Git for Windows via winget. Windows-only; on other platforms
# git is assumed present (returns $true). Returns $true if the requirement
# is satisfied (now or after install). Respects $Script:RfOptNoInstallGit
# and $Script:RfYes.
function Confirm-RfGitAvailable {
    if (-not (Test-RfWindows)) {
        # macOS/Linux: git is effectively always present; if it somehow
        # isn't, claude's own error will guide the user. Don't gate.
        return $true
    }
    if (Test-RfOnPath 'git') {
        Write-RfDim '  git detected (Claude Code plugin/git operations satisfied)'
        return $true
    }
    if (Test-RfOnPath 'pwsh') {
        Write-RfDim '  PowerShell 7 (pwsh) detected (Claude Code shell requirement satisfied)'
        return $true
    }

    Write-RfWarn 'git is required for Claude Code / Codex plugin operations on Windows.'
    Write-RfInfo 'Claude Code clones the plugin marketplace with git and needs a POSIX'
    Write-RfInfo 'shell (Git for Windows bundles bash). Manual install: https://git-scm.com/download/win'

    if ($Script:RfOptNoInstallGit) {
        Write-RfErr '--no-install-git set; install Git for Windows manually and re-run.'
        return $false
    }

    if ($Script:RfOptDryRun) {
        Write-RfInfo '[dry-run] would install Git for Windows via winget (Git.Git)'
        return $true
    }

    if (-not $Script:RfYes) {
        if (-not (Confirm-Rf -Prompt 'Install Git for Windows now via winget (Git.Git)?' -DefaultAnswer 'y')) {
            Write-RfErr 'Git is required to configure Claude Code. Install it from https://git-scm.com/download/win and re-run.'
            return $false
        }
    }

    if (-not (Install-RfGitWindows)) {
        Write-RfErr 'Git install failed. Install manually from https://git-scm.com/download/win and re-run.'
        return $false
    }

    $gitPath = Find-RfGit
    if ($gitPath) {
        # Prepend git's dir so the claude/codex child processes we spawn
        # next inherit it without a shell restart.
        $dir = Split-Path -Parent $gitPath
        if ($dir -and (($env:PATH -split ';') -notcontains $dir)) {
            $env:PATH = "$dir;$env:PATH"
        }
        Write-RfOk "Git installed: $gitPath"
        return $true
    }
    Write-RfErr 'Git installer reported success but git still not found. Open a new PowerShell window and re-run agents.ps1.'
    return $false
}

# Find-RfGit — locate git.exe, tolerating Get-Command's per-session cache
# and the just-installed-but-PATH-not-refreshed case. Returns a single path
# string or $null.
function Find-RfGit {
    $cmds = @(Get-Command git -CommandType Application -ErrorAction SilentlyContinue)
    if ($cmds.Count -gt 0) { return [string]$cmds[0].Source }
    if (-not (Test-RfWindows)) { return $null }
    $candidates = @(
        (Join-Path $env:ProgramFiles 'Git\cmd\git.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'Git\cmd\git.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Git\cmd\git.exe')
    )
    foreach ($c in $candidates) {
        if ($c -and (Test-Path -LiteralPath $c)) { return [string]$c }
    }
    return $null
}

function Install-RfGitWindows {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-RfErr 'winget not available — install Git for Windows manually from https://git-scm.com/download/win'
        return $false
    }
    Write-RfStep 'winget install Git.Git --source winget --silent'
    $code = Invoke-RfNative -FilePath 'winget' -Arguments @(
        'install', '--id', 'Git.Git', '--source', 'winget',
        '--accept-source-agreements', '--accept-package-agreements', '--silent')
    if ($code -ne 0) {
        Write-RfWarn "winget reported non-zero exit ($code); verifying install state regardless"
    }
    Update-RfSessionPathFromRegistry
    return $true
}
