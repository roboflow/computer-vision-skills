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

# The installer's main.ps1 uses constructs that need PowerShell 7+ ($IsWindows,
# `null` propagation patterns, etc.). Detect Windows PowerShell 5.1 up front so
# users get a clear message instead of a mysterious "pwsh not recognized" later.
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host ""
    Write-Host "Roboflow installer needs PowerShell 7 or newer." -ForegroundColor Yellow
    Write-Host "  Detected: $($PSVersionTable.PSEdition) $($PSVersionTable.PSVersion)"
    Write-Host ""
    Write-Host "Install PowerShell 7 (one-time):"
    Write-Host "  winget install --id Microsoft.PowerShell --source winget" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Then open a new 'PowerShell' window (not 'Windows PowerShell') and re-run:"
    Write-Host "  `$env:ROBOFLOW_AGENTS_REF = 'installer'" -ForegroundColor Cyan
    Write-Host "  irm https://roboflow.com/agents.ps1 | iex" -ForegroundColor Cyan
    exit 2
}

$repo = $env:ROBOFLOW_AGENTS_REPO; if (-not $repo) { $repo = 'roboflow/computer-vision-skills' }
$ref  = $env:ROBOFLOW_AGENTS_REF;  if (-not $ref)  { $ref  = 'main' }

# Local-checkout mode — agents.ps1 sits next to main.ps1 under installer/.
if ($PSCommandPath) {
    $localMain = Join-Path (Split-Path -Parent $PSCommandPath) 'main.ps1'
    if (Test-Path -LiteralPath $localMain) {
        & pwsh -NoProfile -File $localMain @RemainingArgs
        exit $LASTEXITCODE
    }
}

# Pipe-from-irm mode — download + extract + invoke.
$cacheRoot = if ($env:XDG_CACHE_HOME) { $env:XDG_CACHE_HOME } else { Join-Path $HOME '.cache' }
$cacheDir  = Join-Path $cacheRoot 'roboflow-agents'
New-Item -ItemType Directory -Force -Path $cacheDir | Out-Null

$tmp = New-Item -ItemType Directory -Path (Join-Path $cacheDir ("dl." + [Guid]::NewGuid().ToString('N').Substring(0, 8)))
try {
    $tarUrl = "https://codeload.github.com/$repo/tar.gz/refs/heads/$ref"
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
        throw "Could not locate extracted archive root in $tmp"
    }
    $main = Join-Path $extracted.FullName 'installer/main.ps1'
    if (-not (Test-Path -LiteralPath $main)) {
        throw "installer/main.ps1 not found in extracted tarball at $main"
    }
    & pwsh -NoProfile -File $main @RemainingArgs
    exit $LASTEXITCODE
}
finally {
    if (Test-Path -LiteralPath $tmp) {
        Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
}
