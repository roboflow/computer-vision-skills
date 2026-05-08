<#
.SYNOPSIS
    Roboflow coding-agent installer (entry bootstrap).

.DESCRIPTION
    Lives at installer/agents.ps1 in the source tree. Two modes:
      1. Local checkout: pwsh -File installer/agents.ps1 from a clone —
         invokes main.ps1 from the same directory.
      2. Pipe-from-irm:
            irm https://roboflow.com/agents.ps1 | iex
         Downloads a tarball of the repo, extracts to the cache dir, runs
         installer/main.ps1.

    Override the ref with $env:ROBOFLOW_AGENTS_REF=<branch-or-tag> for testing.
#>

[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$RemainingArgs
)

$ErrorActionPreference = 'Stop'

# `irm | iex` evaluates this script in the caller's shell, so a top-level
# `exit` would terminate the user's terminal window. Detect that mode (no
# $PSCommandPath = wasn't run as a file) and report exit codes via output
# instead of `exit` when the host shell is ours to keep.
$Script:RfFileMode = [bool]$PSCommandPath
function Invoke-RfFinish {
    param([int]$Code = 0)
    if ($Script:RfFileMode) {
        exit $Code
    }
    if ($Code -ne 0) {
        Write-Host ""
        Write-Host "agents.ps1 exited with code $Code" -ForegroundColor Red
    }
    # Don't `exit` — that would close the host shell when invoked via iex.
}

Write-Host "Roboflow installer (PowerShell $($PSVersionTable.PSEdition) $($PSVersionTable.PSVersion))" -ForegroundColor DarkGray

# Older Windows PowerShell 5.1 builds default to TLS 1.0, which
# raw.githubusercontent and codeload.github.com no longer accept. Force TLS
# 1.2 before any web request.
try {
    [Net.ServicePointManager]::SecurityProtocol =
        [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
} catch { }

# Resolve the running PowerShell host (PS 5.1 → powershell.exe, PS 7+ → pwsh)
# so the rest of the installer runs in the same edition the user invoked.
$Script:RfPwshExe = if ($PSVersionTable.PSEdition -eq 'Desktop') { 'powershell.exe' } else { 'pwsh' }

$repo = $env:ROBOFLOW_AGENTS_REPO; if (-not $repo) { $repo = 'roboflow/computer-vision-skills' }
$ref  = $env:ROBOFLOW_AGENTS_REF;  if (-not $ref)  { $ref  = 'main' }

# Local-checkout mode — agents.ps1 sits next to main.ps1 under installer/.
# (Only reachable when invoked as a file; safe to `exit`.)
if ($PSCommandPath) {
    $localMain = Join-Path (Split-Path -Parent $PSCommandPath) 'main.ps1'
    if (Test-Path -LiteralPath $localMain) {
        & $Script:RfPwshExe -NoProfile -ExecutionPolicy Bypass -File $localMain @RemainingArgs
        Invoke-RfFinish -Code $LASTEXITCODE
        return
    }
}

# Pipe-from-irm mode — download + extract + invoke.
$cacheRoot = if ($env:XDG_CACHE_HOME) { $env:XDG_CACHE_HOME } else { Join-Path $HOME '.cache' }
$cacheDir  = Join-Path $cacheRoot 'roboflow-agents'
New-Item -ItemType Directory -Force -Path $cacheDir | Out-Null

$tmp = New-Item -ItemType Directory -Path (Join-Path $cacheDir ("dl." + [Guid]::NewGuid().ToString('N').Substring(0, 8)))
try {
    $zipUrl = "https://codeload.github.com/$repo/zip/refs/heads/$ref"

    Write-Host "Downloading installer from $repo@$ref…" -ForegroundColor Cyan

    # Prefer zip on Windows because Expand-Archive ships with PowerShell —
    # tar is also available on Windows 10+ but unzip semantics are simpler.
    $zipPath = Join-Path $tmp 'src.zip'
    Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing
    Expand-Archive -Path $zipPath -DestinationPath $tmp -Force
    Remove-Item -LiteralPath $zipPath

    $extracted = Get-ChildItem -Path $tmp -Directory | Select-Object -First 1
    if (-not $extracted) {
        Write-Host "agents.ps1: extracted archive root not found in $tmp" -ForegroundColor Red
        Invoke-RfFinish -Code 1
        return
    }
    $main = Join-Path $extracted.FullName 'installer/main.ps1'
    if (-not (Test-Path -LiteralPath $main)) {
        Write-Host "agents.ps1: installer/main.ps1 not found in extracted tarball at $main" -ForegroundColor Red
        Invoke-RfFinish -Code 1
        return
    }
    & $Script:RfPwshExe -NoProfile -ExecutionPolicy Bypass -File $main @RemainingArgs
    Invoke-RfFinish -Code $LASTEXITCODE
}
catch {
    Write-Host "agents.ps1: $($_.Exception.Message)" -ForegroundColor Red
    Invoke-RfFinish -Code 1
}
finally {
    if (Test-Path -LiteralPath $tmp) {
        Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
}
