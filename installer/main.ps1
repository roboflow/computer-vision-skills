<#
main.ps1 — Roboflow agents.ps1 installer orchestration.

Mirrors installer/main.sh: argument parsing, host detection/selection, auth
resolution, per-host dispatch, summary.
#>

[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$RemainingArgs
)

# `$ErrorActionPreference = 'Stop'` gives us bash-like fail-fast behavior on
# unhandled cmdlet errors. We deliberately do NOT enable Set-StrictMode here:
# it makes `.PSObject.Properties.Name -contains '<x>'` throw on empty
# objects, which is the natural pattern for "does this JSON have key X yet?"
# We catch typos via Pester tests and shellcheck-equivalent linters instead.
$ErrorActionPreference = 'Stop'

$Script:RfInstallerDir = Split-Path -Parent $PSCommandPath
$Script:RfRepoDir      = (Resolve-Path (Join-Path $Script:RfInstallerDir '..')).Path

# Tell host adapters which marketplace source to register.
if (-not $env:ROBOFLOW_AGENTS_REPO) {
    $env:ROBOFLOW_AGENTS_REPO = 'roboflow/computer-vision-skills'
}

# Dot-source libs into the script scope so functions are visible everywhere.
. (Join-Path $Script:RfInstallerDir 'lib/common.ps1')
. (Join-Path $Script:RfInstallerDir 'lib/json_io.ps1')
. (Join-Path $Script:RfInstallerDir 'lib/detect.ps1')
. (Join-Path $Script:RfInstallerDir 'lib/auth.ps1')
. (Join-Path $Script:RfInstallerDir 'lib/manifest.ps1')
. (Join-Path $Script:RfInstallerDir 'lib/mcp.ps1')
. (Join-Path $Script:RfInstallerDir 'lib/skills.ps1')
. (Join-Path $Script:RfInstallerDir 'lib/rules.ps1')

function Show-RfUsage {
@"
agents.ps1 — install Roboflow into your coding agents

USAGE
  pwsh -File installer/agents.ps1 [flags]      (from a checkout)

  irm https://roboflow.com/agents.ps1 | iex
  & { iex (irm https://roboflow.com/agents.ps1) } [flags]

FLAGS (mirrors agents.sh; see docs/INSTALLER.md)
  --host=<id,...>       Restrict to specific agent IDs
  --all                 All detected agents
  --skills-only / --mcp-only / --rules-only
  --no-skills / --no-mcp / --no-rules
  --global (default) / --project
  --api-key=<key>       Override key resolution
  --workspace=<url>     Pick a workspace from the Python SDK config
  --inline-key          Write key literally (global scope only)
  --auth-skip
  --update / --uninstall
  --dry-run / --force / --force-skill=<name>
  --yes, -y
  --version / --help, -h

KNOWN HOST IDS
  claude-code-cli, codex-cli, cursor-desktop, claude-desktop, copilot-cli
"@
}

# Defaults.
$Script:RfOptHosts        = @()
$Script:RfOptAll          = $false
$Script:RfOptComponents   = @()
$Script:RfOptNoComponents = @()
$Script:RfOptScope        = 'global'
$Script:RfOptApiKey       = ''
$Script:RfOptWorkspace    = ''
$Script:RfOptInlineKey    = $false
$Script:RfOptAuthSkip     = $false
$Script:RfOptMode         = 'install'
$Script:RfOptDryRun       = $false
$Script:RfOptForce        = $false
$Script:RfOptForceSkills  = @()
$Script:RfYes             = $false
$Script:RfProjectDir      = ''

function Invoke-RfParseArgs {
    param([string[]]$Items)
    if (-not $Items) { return }
    foreach ($a in $Items) {
        if (-not $a) { continue }
        if ($a -eq '--help' -or $a -eq '-h') {
            Show-RfUsage
            exit 0
        }
        if ($a -eq '--version') {
            Write-Host "agents.ps1 installer $Script:RfInstallerVersion"
            Write-Host ("repo: {0}@{1}" -f $env:ROBOFLOW_AGENTS_REPO, ($env:ROBOFLOW_AGENTS_REF))
            exit 0
        }
        switch -Wildcard ($a) {
            '--host=*'         { $Script:RfOptHosts        += @($a.Substring(7).Split(',', [StringSplitOptions]::RemoveEmptyEntries)); break }
            '--all'            { $Script:RfOptAll          = $true; break }
            '--skills-only'    { $Script:RfOptComponents   = @('skills'); break }
            '--mcp-only'       { $Script:RfOptComponents   = @('mcp'); break }
            '--rules-only'     { $Script:RfOptComponents   = @('rules'); break }
            '--no-skills'      { $Script:RfOptNoComponents += 'skills'; break }
            '--no-mcp'         { $Script:RfOptNoComponents += 'mcp'; break }
            '--no-rules'       { $Script:RfOptNoComponents += 'rules'; break }
            '--global'         { $Script:RfOptScope = 'global'; break }
            '--project'        { $Script:RfOptScope = 'project'; break }
            '--api-key=*'      { $Script:RfOptApiKey    = $a.Substring(10); break }
            '--workspace=*'    { $Script:RfOptWorkspace = $a.Substring(12); break }
            '--inline-key'     { $Script:RfOptInlineKey  = $true; break }
            '--auth-skip'      { $Script:RfOptAuthSkip   = $true; break }
            '--update'         { $Script:RfOptMode       = 'update'; break }
            '--uninstall'      { $Script:RfOptMode       = 'uninstall'; break }
            '--dry-run'        { $Script:RfOptDryRun     = $true; break }
            '--force'          { $Script:RfOptForce      = $true; break }
            '--force-skill=*'  { $Script:RfOptForceSkills += $a.Substring(14); break }
            '--yes'            { $Script:RfYes = $true; break }
            '-y'               { $Script:RfYes = $true; break }
            default {
                Write-RfErr "unknown flag: $a"
                Write-RfInfo "Run with --help for usage."
                exit 2
            }
        }
    }

    if ($Script:RfOptScope -eq 'project' -and $Script:RfOptInlineKey) {
        Write-RfWarn "--inline-key + --project: literal API key will be written into project config — make sure that file isn't committed."
    }
}

function Resolve-RfComponentFlags {
    $Script:RfDoMcp    = $true
    $Script:RfDoSkills = $true
    $Script:RfDoRules  = $true
    if ($Script:RfOptComponents.Count -gt 0) {
        $Script:RfDoMcp    = $false
        $Script:RfDoSkills = $false
        $Script:RfDoRules  = $false
        foreach ($c in $Script:RfOptComponents) {
            switch ($c) {
                'mcp'    { $Script:RfDoMcp    = $true }
                'skills' { $Script:RfDoSkills = $true }
                'rules'  { $Script:RfDoRules  = $true }
            }
        }
    }
    foreach ($c in $Script:RfOptNoComponents) {
        switch ($c) {
            'mcp'    { $Script:RfDoMcp    = $false }
            'skills' { $Script:RfDoSkills = $false }
            'rules'  { $Script:RfDoRules  = $false }
        }
    }
}

function Select-RfHosts {
    $detected = @(Get-RfDetectedHosts)
    $known    = @(Get-RfKnownHostIds)

    if ($Script:RfOptHosts.Count -gt 0) {
        foreach ($id in $Script:RfOptHosts) {
            if ($known -notcontains $id) {
                Write-RfErr "unknown host id: $id"
                Write-RfInfo "Known IDs: $($known -join ', ')"
                exit 2
            }
        }
        return $Script:RfOptHosts
    }

    if ($detected.Count -eq 0) { return @() }

    if ($Script:RfOptAll -or $Script:RfYes) {
        return @($detected | ForEach-Object { ($_ -split '\|')[0] })
    }

    Write-RfHeader "Detected agents"
    $i = 1
    $ids = @()
    foreach ($line in $detected) {
        $parts = $line -split '\|'
        $id = $parts[0]; $label = $parts[2]; $hint = $parts[3]
        Write-RfInfo "  $i. $label  — $hint"
        $ids += $id; $i++
    }
    $choice = Read-RfPrompt -Prompt "Configure which? Comma-separated numbers, or `"all`":" -Default 'all'
    if ($choice -eq 'all' -or [string]::IsNullOrEmpty($choice)) { return $ids }
    $picks = @()
    foreach ($p in ($choice -split ',')) {
        $p = $p.Trim()
        if ($p -match '^[0-9]+$' -and [int]$p -ge 1 -and [int]$p -le $ids.Count) {
            $picks += $ids[[int]$p - 1]
        }
    }
    return $picks
}

function Invoke-RfHost {
    param([string]$Id)
    $script = Join-Path $Script:RfInstallerDir "hosts/$($Id.Replace('-', '_')).ps1"
    if (-not (Test-Path -LiteralPath $script)) {
        Write-RfWarn "no adapter for $Id (not yet implemented in this installer version)"
        return $true
    }
    . $script

    $verb = switch ($Script:RfOptMode) {
        'install'   { 'Install' }
        'update'    { 'Install' }
        'uninstall' { 'Uninstall' }
        default     { Write-RfErr "unknown mode: $Script:RfOptMode"; exit 2 }
    }
    $fnName = "$verb-RfHost$([Globalization.CultureInfo]::InvariantCulture.TextInfo.ToTitleCase($Id.Replace('-', ' ')).Replace(' ', ''))"
    if (-not (Get-Command -Name $fnName -ErrorAction SilentlyContinue)) {
        Write-RfWarn "$Id has no $verb hook; skipping"
        return $true
    }
    return (& $fnName)
}

function Invoke-RfMain {
    Invoke-RfParseArgs -Items $RemainingArgs
    Resolve-RfComponentFlags

    Write-RfHeader "Roboflow agents installer"
    Write-RfDim "  source repo: $env:ROBOFLOW_AGENTS_REPO"
    Write-RfDim "  scope:       $Script:RfOptScope"
    Write-RfDim "  mode:        $Script:RfOptMode"
    if ($Script:RfOptDryRun) { Write-RfDim "  dry-run:     yes" }

    $selected = @(Select-RfHosts)
    if ($selected.Count -eq 0) {
        Write-RfWarn "no supported coding agents detected (or selected)"
        Write-RfInfo "Install one and re-run, or pass --host=<id> to override detection."
        Write-RfInfo "Known host IDs: $((Get-RfKnownHostIds) -join ', ')"
        exit 3
    }

    if ($Script:RfOptMode -eq 'uninstall' -and -not $Script:RfYes) {
        if (-not (Confirm-Rf -Prompt "Remove Roboflow from: $($selected -join ', ')?")) {
            Write-RfInfo "aborted."
            exit 0
        }
    }

    if (-not $Script:RfOptAuthSkip -and $Script:RfOptMode -ne 'uninstall') {
        Resolve-RfAuth
        if ($Script:RfApiKey) {
            Write-RfDim "  api key:     resolved from $Script:RfApiKeySource"
        }
    }

    $results = @()
    # `$host` is a PowerShell automatic variable (the PSHost). Use a
    # different name to avoid shadowing it.
    foreach ($hostId in $selected) {
        try {
            if (Invoke-RfHost -Id $hostId) {
                $results += "${hostId}:ok"
            } else {
                $results += "${hostId}:fail"
            }
        } catch {
            Write-RfErr ("error in {0}: {1}" -f $hostId, $_.Exception.Message)
            $results += "${hostId}:fail(exception)"
        }
    }

    Write-RfHeader "Summary"
    foreach ($r in $results) {
        if ($r -like '*:ok') {
            Write-RfOk ($r -replace ':ok$', '')
        } else {
            Write-RfErr $r
        }
    }

    if ($Script:RfOptMode -ne 'uninstall' -and $Script:RfApiKey -and $env:ROBOFLOW_API_KEY -ne $Script:RfApiKey) {
        Show-RfAuthExportHint
    }

    foreach ($r in $results) {
        if ($r -like '*:fail*') { exit 1 }
    }
    exit 0
}

Invoke-RfMain
