<#
common.ps1 — logging, prompts, atomic writes, backups.
Imported by main.ps1 and host adapters via dot-source.
#>

# PowerShell 6+ ships $IsWindows / $IsLinux / $IsMacOS as automatic read-only
# globals. Windows PowerShell 5.1 doesn't have them — fill them in so the
# rest of the lib can use them uniformly. Skip if already defined (PS 7+) to
# avoid trying to overwrite a read-only auto-variable.
if (-not (Get-Variable -Name IsWindows -ErrorAction SilentlyContinue)) {
    # Windows PowerShell 5.1 only runs on Windows.
    Set-Variable -Name IsWindows -Value $true  -Scope Global -Option ReadOnly -Force
    Set-Variable -Name IsLinux   -Value $false -Scope Global -Option ReadOnly -Force
    Set-Variable -Name IsMacOS   -Value $false -Scope Global -Option ReadOnly -Force
}

# Color suppression — honor $env:NO_COLOR and non-tty stdout.
$Script:RfColorEnabled = -not $env:NO_COLOR -and [Console]::IsOutputRedirected -eq $false

function Write-RfInfo { param([string]$Message) Write-Host $Message }
function Write-RfStep { param([string]$Message) if ($Script:RfColorEnabled) { Write-Host "→ $Message" -ForegroundColor Blue } else { Write-Host "→ $Message" } }
function Write-RfOk   { param([string]$Message) if ($Script:RfColorEnabled) { Write-Host "✓ $Message" -ForegroundColor Green } else { Write-Host "✓ $Message" } }
function Write-RfWarn { param([string]$Message) if ($Script:RfColorEnabled) { Write-Host "! $Message" -ForegroundColor Yellow } else { Write-Host "! $Message" } }
function Write-RfErr  { param([string]$Message) if ($Script:RfColorEnabled) { Write-Host "✗ $Message" -ForegroundColor Red } else { Write-Host "✗ $Message" } }
function Write-RfDim  { param([string]$Message) if ($Script:RfColorEnabled) { Write-Host $Message -ForegroundColor DarkGray } else { Write-Host $Message } }
function Write-RfHeader { param([string]$Message) Write-Host ""; if ($Script:RfColorEnabled) { Write-Host $Message -ForegroundColor White } else { Write-Host $Message } }

function Invoke-RfDie {
    param([string]$Message, [int]$Code = 1)
    Write-RfErr $Message
    exit $Code
}

function Confirm-Rf {
    param([string]$Prompt)
    if ($Script:RfYes) { return $true }
    $reply = Read-Host "$Prompt [y/N]"
    return $reply -match '^[Yy]'
}

function Read-RfPrompt {
    param([string]$Prompt, [string]$Default)
    if ($Default) {
        $reply = Read-Host "$Prompt [$Default]"
        if ([string]::IsNullOrEmpty($reply)) { return $Default }
        return $reply
    }
    return Read-Host $Prompt
}

function Read-RfSecret {
    param([string]$Prompt)
    $secure = Read-Host -Prompt $Prompt -AsSecureString
    return [System.Net.NetworkCredential]::new('', $secure).Password
}

# Backup-RfFile — copy <Path> to <Path>.bak.<UTC>; returns the backup path or empty.
function Backup-RfFile {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return '' }
    $stamp = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssZ")
    $bak = "$Path.bak.$stamp"
    Copy-Item -LiteralPath $Path -Destination $bak -Force
    return $bak
}

# Set-RfFileContent — atomic write of $Content to $Path (write to a temp in
# the same dir, then move into place).
function Set-RfFileContent {
    param([string]$Path, [string]$Content, [int]$Mode = 0)
    $dir = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $tmp = Join-Path $dir (".atomic.{0:N}.tmp" -f [Guid]::NewGuid())
    [System.IO.File]::WriteAllText($tmp, $Content, [System.Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $tmp -Destination $Path -Force
    if ($Mode -ne 0 -and ($IsLinux -or $IsMacOS)) {
        try { & chmod ([Convert]::ToString($Mode, 8)) $Path 2>$null } catch { }
    }
}

function Test-RfOnPath {
    param([string]$Command)
    return [bool](Get-Command -Name $Command -CommandType Application, ExternalScript -ErrorAction SilentlyContinue)
}

function Get-RfHomeDir {
    return $HOME
}

function Test-RfMacOS   { return $IsMacOS }
function Test-RfLinux   { return $IsLinux }
function Test-RfWindows { return $IsWindows }
