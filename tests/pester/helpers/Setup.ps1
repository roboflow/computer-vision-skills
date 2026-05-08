# Shared Pester setup helpers.

$Script:RfRepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path

# Resolve pwsh up front (full path) so child-process invocations work even
# when we narrow $env:PATH to a controlled subset for isolation tests.
# Falls back to the well-known Homebrew/system locations if PATH was already
# narrowed by a previous test file's setup.
function Resolve-RfPwsh {
    $cmd = Get-Command pwsh -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $candidates = @(
        '/opt/homebrew/bin/pwsh',
        '/usr/local/bin/pwsh',
        '/usr/bin/pwsh'
    )
    foreach ($c in $candidates) { if (Test-Path -LiteralPath $c) { return $c } }
    throw 'cannot resolve pwsh'
}
if (-not $Script:RfPwshPath) {
    $Script:RfPwshPath = Resolve-RfPwsh
}

# Minimal system PATH used during isolated tests so /Applications/-installed
# `claude` and `codex` don't leak into "no agents detected" expectations.
$Script:RfSystemPath = '/usr/bin:/bin:/usr/sbin:/sbin'

# Capture the original PATH so we can restore it in teardown — child Pester
# files dot-source this file fresh, but $env:PATH persists across tests in
# the same process.
if (-not $Script:RfOriginalPath) {
    $Script:RfOriginalPath = $env:PATH
}

function New-RfIsolatedHome {
    # Note: $HOME is a PowerShell automatic read-only variable. We override
    # the env-var ($env:HOME), which child processes inherit. Use $rfHome
    # locally — never reassign $HOME.
    $rfHome = New-Item -ItemType Directory -Path (Join-Path ([System.IO.Path]::GetTempPath()) ("rf-home." + [Guid]::NewGuid().ToString('N').Substring(0, 8)))
    $env:HOME = $rfHome.FullName
    $env:XDG_CACHE_HOME = Join-Path $rfHome.FullName '.cache'
    Remove-Item Env:ROBOFLOW_API_KEY -ErrorAction SilentlyContinue
    Remove-Item Env:ROBOFLOW_CONFIG_DIR -ErrorAction SilentlyContinue
    $env:RF_TEST_NO_DETECT_APPS = '1'
    $env:NO_COLOR = '1'
    New-Item -ItemType Directory -Path (Join-Path $rfHome '.config') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $rfHome 'bin') -Force | Out-Null

    if ($IsMacOS -or $IsLinux) {
        $env:PATH = "$($rfHome.FullName)/bin:$Script:RfSystemPath"
    }
    return $rfHome.FullName
}

function Remove-RfIsolatedHome {
    if ($env:HOME -and (Test-Path -LiteralPath $env:HOME)) {
        Remove-Item -LiteralPath $env:HOME -Recurse -Force -ErrorAction SilentlyContinue
    }
    # Restore PATH so subsequent Pester files (which re-dot-source this
    # helper) can still find pwsh, brew, etc.
    if ($Script:RfOriginalPath) {
        $env:PATH = $Script:RfOriginalPath
    }
}

function New-RfStubCommand {
    param(
        [Parameter(Mandatory)] [string]$Name,
        [int]$ExitCode = 0,
        [string]$Stdout = '',
        [string]$Stderr = ''
    )
    $callsDir = Join-Path $env:HOME ".stubs/$Name.calls"
    New-Item -ItemType Directory -Path $callsDir -Force | Out-Null
    $stubPath = Join-Path $env:HOME "bin/$Name"
    $body = @"
#!/usr/bin/env bash
ts="`$(date +%s%N)"
{
    printf '%s\n' "`$0 `$*"
    for a in "`$@"; do printf 'arg: %s\n' "`$a"; done
} > "$callsDir/`$ts.`$`$"
"@
    if ($Stdout) { $body += "`nprintf %q `"$Stdout`"" }
    if ($Stderr) { $body += "`nprintf %q `"$Stderr`" >&2" }
    $body += "`nexit $ExitCode"
    Set-Content -LiteralPath $stubPath -Value $body
    & chmod +x $stubPath
}

function Get-RfStubCallCount {
    param([string]$Name)
    $callsDir = Join-Path $env:HOME ".stubs/$Name.calls"
    if (-not (Test-Path -LiteralPath $callsDir)) { return 0 }
    return (Get-ChildItem -LiteralPath $callsDir -File -ErrorAction SilentlyContinue).Count
}

function Get-RfStubCalls {
    param([string]$Name)
    $callsDir = Join-Path $env:HOME ".stubs/$Name.calls"
    if (-not (Test-Path -LiteralPath $callsDir)) { return '' }
    Get-ChildItem -LiteralPath $callsDir -File -ErrorAction SilentlyContinue | ForEach-Object { Get-Content $_ } | Out-String
}

function Invoke-RfMainPs {
    param([string[]]$Items)
    $main = Join-Path $Script:RfRepoRoot 'installer/main.ps1'
    # Discard the child's stdout — we only want to return the exit code.
    # Otherwise PowerShell captures the script's Write-Host output along
    # with the return value and `Should -Be 0` compares against an array.
    & $Script:RfPwshPath -NoProfile -File $main @Items 2>&1 | Out-Null
    return $LASTEXITCODE
}
