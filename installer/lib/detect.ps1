<#
detect.ps1 — locate installed coding agents.

Each Test-RfHost-* function emits a "id|kind|label|hint" string if the host
is detected, or nothing. Get-RfDetectedHosts aggregates them.
#>

function Test-RfHostClaudeCodeCli {
    if (-not (Test-RfOnPath 'claude')) { return }
    $version = ''
    try {
        $version = (& claude --version 2>$null | Select-Object -First 1)
    } catch { }
    if (-not $version) { $version = 'detected on PATH' }
    "claude-code-cli|cli|Claude Code CLI|$version"
}

function Test-RfHostCodexCli {
    if (-not (Test-RfOnPath 'codex')) { return }
    $version = ''
    try {
        $version = (& codex --version 2>$null | Select-Object -First 1)
    } catch { }
    if (-not $version) { $version = 'detected on PATH' }
    "codex-cli|cli|Codex CLI|$version"
}

function Test-RfHostCursorDesktop {
    if ($env:RF_TEST_NO_DETECT_APPS -eq '1') { return }
    $hint = ''
    if (Test-RfMacOS) {
        if (Test-Path '/Applications/Cursor.app') { $hint = '/Applications/Cursor.app' }
    } elseif (Test-RfLinux) {
        $a = Join-Path $HOME '.config/Cursor'
        $b = Join-Path $HOME '.cursor'
        if (Test-Path $a) { $hint = $a }
        elseif (Test-Path $b) { $hint = $b }
    } elseif (Test-RfWindows) {
        $local = if ($env:LOCALAPPDATA) { $env:LOCALAPPDATA } else { Join-Path $HOME 'AppData/Local' }
        $candidate = Join-Path $local 'Programs/cursor'
        if (Test-Path $candidate) { $hint = $candidate }
    }
    if (-not $hint -and (Test-RfOnPath 'cursor')) { $hint = 'cursor on PATH' }
    if (-not $hint) { return }
    "cursor-desktop|desktop|Cursor|$hint"
}

function Test-RfHostClaudeDesktop {
    if ($env:RF_TEST_NO_DETECT_APPS -eq '1') { return }
    $hint = ''
    if (Test-RfMacOS) {
        if (Test-Path '/Applications/Claude.app') { $hint = '/Applications/Claude.app' }
    } elseif (Test-RfLinux) {
        $candidate = Join-Path $HOME '.config/Claude'
        if (Test-Path $candidate) { $hint = $candidate }
    } elseif (Test-RfWindows) {
        $appdata = if ($env:APPDATA) { $env:APPDATA } else { Join-Path $HOME 'AppData/Roaming' }
        $candidate = Join-Path $appdata 'Claude'
        if (Test-Path $candidate) { $hint = $candidate }
    }
    if (-not $hint) { return }
    "claude-desktop|desktop|Claude Desktop|$hint"
}

function Test-RfHostCopilotCli {
    if (Test-RfOnPath 'copilot') {
        $version = ''
        try { $version = (& copilot --version 2>$null | Select-Object -First 1) } catch { }
        if (-not $version) { $version = 'detected on PATH' }
        return "copilot-cli|cli|GitHub Copilot CLI|$version"
    }
    if (Test-RfOnPath 'gh') {
        try {
            $extensions = & gh extension list 2>$null
            if ($extensions -match 'github/gh-copilot') {
                return "copilot-cli|cli|GitHub Copilot CLI|gh extension"
            }
        } catch { }
    }
}

function Get-RfDetectedHosts {
    $lines = @()
    $lines += Test-RfHostClaudeCodeCli
    $lines += Test-RfHostCodexCli
    $lines += Test-RfHostCursorDesktop
    $lines += Test-RfHostClaudeDesktop
    $lines += Test-RfHostCopilotCli
    return $lines | Where-Object { $_ -and $_.Trim() }
}

function Get-RfHostById {
    param([string]$Id)
    switch ($Id) {
        'claude-code-cli' { return Test-RfHostClaudeCodeCli }
        'codex-cli'       { return Test-RfHostCodexCli }
        'cursor-desktop'  { return Test-RfHostCursorDesktop }
        'claude-desktop'  { return Test-RfHostClaudeDesktop }
        'copilot-cli'     { return Test-RfHostCopilotCli }
        default { throw "unknown host id: $Id" }
    }
}

function Get-RfKnownHostIds {
    return @(
        'claude-code-cli',
        'codex-cli',
        'cursor-desktop',
        'claude-desktop',
        'copilot-cli'
    )
}
