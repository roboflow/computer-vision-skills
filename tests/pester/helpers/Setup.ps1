# Shared Pester setup helpers.

$Script:RfRepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path

# Resolve the PowerShell executable up front (full path) so child-process
# invocations work even when we narrow $env:PATH for isolation. Use whichever
# edition is currently running (PS 5.1 → powershell.exe, PS 7+ → pwsh) so the
# test suite exercises the same edition that invoked it.
function Resolve-RfPwsh {
    if ($PSVersionTable.PSEdition -eq 'Desktop') {
        # Windows PowerShell 5.1 — $PSHOME holds powershell.exe.
        return (Join-Path $PSHOME 'powershell.exe')
    }
    $cmd = Get-Command pwsh -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $candidates = @(
        '/opt/homebrew/bin/pwsh',
        '/usr/local/bin/pwsh',
        '/usr/bin/pwsh',
        (Join-Path $PSHOME 'pwsh')
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
    # On Windows PS 5.1, $HOME is derived from $env:USERPROFILE rather than
    # $env:HOME. Set both so child processes (including powershell.exe)
    # see the isolated home regardless of edition.
    if ($IsWindows) { $env:USERPROFILE = $rfHome.FullName }
    $env:XDG_CACHE_HOME = Join-Path $rfHome.FullName '.cache'
    Remove-Item Env:ROBOFLOW_API_KEY -ErrorAction SilentlyContinue
    Remove-Item Env:ROBOFLOW_CONFIG_DIR -ErrorAction SilentlyContinue
    $env:RF_TEST_NO_DETECT_APPS = '1'
    $env:NO_COLOR = '1'
    New-Item -ItemType Directory -Path (Join-Path $rfHome '.config') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $rfHome 'bin') -Force | Out-Null

    if ($IsWindows) {
        # Narrow PATH to the test stub dir + minimum system bins so the user's
        # actual claude / codex / npx don't leak into "missing binary" tests.
        $sysRoot = if ($env:SystemRoot) { $env:SystemRoot } else { 'C:\Windows' }
        $env:PATH = (Join-Path $rfHome.FullName 'bin') + ';' + (Join-Path $sysRoot 'System32') + ';' + $sysRoot
    } else {
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
    $binDir = Join-Path $env:HOME 'bin'
    if (-not (Test-Path -LiteralPath $binDir)) {
        New-Item -ItemType Directory -Path $binDir -Force | Out-Null
    }

    if ($IsWindows) {
        # .cmd is in PATHEXT by default; tests invoke `claude` and PATHEXT
        # resolution finds claude.cmd. Each invocation logs argv to a unique
        # file so Get-RfStubCalls can replay them.
        $stubPath   = Join-Path $binDir "$Name.cmd"
        $callsDirW  = $callsDir -replace '/', '\'
        $lines = @(
            '@echo off',
            'setlocal enabledelayedexpansion',
            'set "ts=%RANDOM%-%RANDOM%-%RANDOM%"',
            "set `"calls_dir=$callsDirW`"",
            '> "%calls_dir%\%ts%.txt" echo %~nx0 %*',
            ':loop',
            'if "%~1"=="" goto :done',
            '>> "%calls_dir%\%ts%.txt" echo arg: %~1',
            'shift',
            'goto :loop',
            ':done'
        )
        if ($Stdout) { $lines += "echo $Stdout" }
        if ($Stderr) { $lines += "echo $Stderr 1>&2" }
        $lines += "exit /b $ExitCode"
        Set-Content -LiteralPath $stubPath -Value ($lines -join "`r`n") -Encoding ASCII
    } else {
        $stubPath = Join-Path $binDir $Name
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
    # `-ExecutionPolicy Bypass` keeps Windows PS 5.1's default Restricted
    # policy from blocking the spawned script.
    & $Script:RfPwshPath -NoProfile -ExecutionPolicy Bypass -File $main @Items 2>&1 | Out-Null
    return $LASTEXITCODE
}
