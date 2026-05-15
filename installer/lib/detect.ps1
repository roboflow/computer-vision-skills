<#
detect.ps1 — locate installed coding agents.

Each Test-RfHost-* function emits a "id|kind|label|hint" string if the host
is detected, or nothing. Get-RfDetectedHosts aggregates them.
#>

# Resolve-RfClaudeCliPath — returns the launcher we should use to invoke
# `claude` for the rest of this installer run, or $null if Claude Code isn't
# installed.
#
# Lookup order, in priority:
#   1. `claude` on PATH (npm/global install; user's PATH already set up).
#   2. The native Anthropic Windows installer / MSIX Claude Desktop bundled
#      CLI, which lands at %APPDATA%\Claude\claude-code\<version>\claude.exe.
#      This is *not* on PATH out of the box, but it's a fully usable CLI and
#      shares the plugin store with the Code tab in Claude Desktop, so the
#      same `claude plugin install roboflow` configures both at once.
#   3. Legacy / alternate Windows install locations (Squirrel, Programs\).
#   4. macOS / Linux: `~/.local/share/anthropic-claude/claude-code/<ver>/claude`
#      and the Homebrew default `/opt/homebrew/bin/claude` -- both unlikely
#      to be off PATH, but kept for completeness.
#
# Cached in $Script:RfClaudeCliPath because both detection and the host
# adapter need it. Pass -Force to bust the cache (used by tests).
function Resolve-RfClaudeCliPath {
    param([switch]$Force)
    if ((-not $Force) -and $Script:RfClaudeCliPath) {
        return $Script:RfClaudeCliPath
    }
    $Script:RfClaudeCliPath = $null

    # 1. PATH.
    # PATH lookup runs even with RF_TEST_NO_DETECT_APPS=1 — the test
    # harness narrows PATH for isolation already; the suppression flag is
    # for off-PATH install-dir probes.
    $cmd = Get-Command -Name 'claude' -CommandType Application, ExternalScript -ErrorAction SilentlyContinue
    if ($cmd) {
        # Get-Command returns multiple entries when both .cmd and .ps1 shims
        # exist (npm-on-Windows). Prefer the .exe / .cmd over .ps1 -- piping a
        # .ps1 through our outer pwsh would re-trigger ExecutionPolicy prompts.
        $preferred = $cmd | Sort-Object @{Expression = {
            switch -Regex ($_.Source) {
                '\.exe$' { 0; break }
                '\.cmd$' { 1; break }
                '\.bat$' { 2; break }
                default  { 3 }
            }
        }} | Select-Object -First 1
        $Script:RfClaudeCliPath = $preferred.Source
        return $Script:RfClaudeCliPath
    }

    # 2-3. Windows install locations not on PATH.
    # Honor the same suppression flag used by desktop-app detectors so the
    # Pester suite's "no agents installed" tests don't trip on the user's
    # real Anthropic install under %APPDATA%\Claude.
    if ($env:RF_TEST_NO_DETECT_APPS -eq '1') { return $null }
    if (Test-RfWindows) {
        $appdata  = if ($env:APPDATA)      { $env:APPDATA }      else { Join-Path $HOME 'AppData\Roaming' }
        $localApp = if ($env:LOCALAPPDATA) { $env:LOCALAPPDATA } else { Join-Path $HOME 'AppData\Local' }

        # Versioned tree: <root>\claude-code\<semver>\claude.exe.
        # Three possible roots on Windows, all checked in order:
        #
        #   a) %APPDATA%\Claude\claude-code\
        #      What both the standalone Anthropic installer and the
        #      Claude Desktop MSIX populate -- visible from any process
        #      that is a child of the MSIX app (the path is virtualized
        #      back via the WindowsApps redirect), and from any process
        #      outside the MSIX context IF the install also wrote a real
        #      reparse point there.
        #
        #   b) %LOCALAPPDATA%\Packages\Claude_*\LocalCache\Roaming\Claude\claude-code\
        #      The REAL filesystem location that the MSIX redirect points
        #      to. When a user launches a fresh PowerShell (not a child
        #      of the MSIX app), (a) typically returns "does not exist"
        #      because the redirect only applies to processes inside the
        #      MSIX container, and you have to fall through to here.
        #      This was the bug reported in the field.
        #
        #   c) %LOCALAPPDATA%\Programs\claude\claude.exe and friends --
        #      Squirrel installer / future paths, kept for completeness.
        $codeRoots = @()
        $codeRoots += (Join-Path $appdata 'Claude\claude-code')
        $msixPackages = Join-Path $localApp 'Packages'
        if (Test-Path -LiteralPath $msixPackages) {
            try {
                Get-ChildItem -LiteralPath $msixPackages -Directory -Filter 'Claude_*' -ErrorAction Stop |
                    ForEach-Object {
                        $codeRoots += (Join-Path $_.FullName 'LocalCache\Roaming\Claude\claude-code')
                    }
            } catch { }
        }

        foreach ($codeRoot in $codeRoots) {
            if (-not (Test-Path -LiteralPath $codeRoot)) { continue }
            $versioned = Get-ChildItem -LiteralPath $codeRoot -Directory -ErrorAction SilentlyContinue |
                Where-Object {
                    $exe = Join-Path $_.FullName 'claude.exe'
                    Test-Path -LiteralPath $exe -PathType Leaf
                }
            $latest = $versioned |
                Sort-Object @{Expression = {
                    $v = $null
                    if ([Version]::TryParse($_.Name, [ref]$v)) { $v } else { [Version]'0.0.0' }
                }}, Name |
                Select-Object -Last 1
            if ($latest) {
                $Script:RfClaudeCliPath = Join-Path $latest.FullName 'claude.exe'
                return $Script:RfClaudeCliPath
            }

            # Flat fallback in case Anthropic ever ships a non-versioned layout.
            $flat = Join-Path $codeRoot 'claude.exe'
            if (Test-Path -LiteralPath $flat -PathType Leaf) {
                $Script:RfClaudeCliPath = $flat
                return $Script:RfClaudeCliPath
            }
        }

        # Squirrel / Programs install layouts (legacy + speculative).
        $fallbacks = @(
            (Join-Path $localApp 'AnthropicClaude\claude.exe'),
            (Join-Path $localApp 'Programs\claude\claude.exe'),
            (Join-Path $localApp 'Programs\Claude\claude.exe'),
            (Join-Path $localApp 'Programs\claude-code\claude.exe')
        )
        foreach ($p in $fallbacks) {
            if (Test-Path -LiteralPath $p -PathType Leaf) {
                $Script:RfClaudeCliPath = $p
                return $Script:RfClaudeCliPath
            }
        }
    }

    # 4. macOS / Linux off-PATH install locations.
    if (Test-RfMacOS -or Test-RfLinux) {
        $unixFallbacks = @()
        $share = Join-Path $HOME '.local/share/anthropic-claude/claude-code'
        if (Test-Path -LiteralPath $share) {
            $latest = Get-ChildItem -LiteralPath $share -Directory -ErrorAction SilentlyContinue |
                Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'claude') -PathType Leaf } |
                Sort-Object Name |
                Select-Object -Last 1
            if ($latest) {
                $unixFallbacks += (Join-Path $latest.FullName 'claude')
            }
        }
        $unixFallbacks += @('/opt/homebrew/bin/claude', '/usr/local/bin/claude')
        foreach ($p in $unixFallbacks) {
            if (Test-Path -LiteralPath $p -PathType Leaf) {
                $Script:RfClaudeCliPath = $p
                return $Script:RfClaudeCliPath
            }
        }
    }

    return $null
}

# Get-RfClaudeCliInfo — returns @{ Path = ...; Source = 'path'|'install-dir'; Hint = '...' }
# or $null. Used to build detection lines with a meaningful hint and to log
# "claude not on PATH but found at X" so users know what we'll run.
function Get-RfClaudeCliInfo {
    $resolved = Resolve-RfClaudeCliPath
    if (-not $resolved) { return $null }
    $onPath = [bool](Get-Command -Name 'claude' -CommandType Application, ExternalScript -ErrorAction SilentlyContinue)
    $version = ''
    try {
        $version = (& $resolved --version 2>$null | Select-Object -First 1)
    } catch { }
    if (-not $version) { $version = if ($onPath) { 'detected on PATH' } else { 'detected (not on PATH)' } }
    elseif (-not $onPath) { $version = "$version (not on PATH)" }
    return [pscustomobject]@{
        Path    = $resolved
        OnPath  = $onPath
        Version = $version
    }
}

function Test-RfHostClaudeCodeCli {
    $info = Get-RfClaudeCliInfo
    if (-not $info) { return }
    "claude-code-cli|cli|Claude Code CLI|$($info.Version)"
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
        if (Test-Path -LiteralPath '/Applications/Claude.app') { $hint = '/Applications/Claude.app' }
    } elseif (Test-RfLinux) {
        $candidate = Join-Path $HOME '.config/Claude'
        if (Test-Path -LiteralPath $candidate) { $hint = $candidate }
    } elseif (Test-RfWindows) {
        # Windows ships Claude Desktop in two install flavors. Try in order:
        #   1. MSIX / Microsoft Store package — canonical on Windows 11.
        #      Lands in C:\Program Files\WindowsApps\Claude_<ver>_<arch>__<hash>\,
        #      which we can't predict by path; Get-AppxPackage is the right probe.
        #   2. User-config dir at %APPDATA%\Claude\ — exists once the app has
        #      been launched at least once, regardless of install flavor.
        #   3. Squirrel-installer fallbacks.
        try {
            $pkg = Get-AppxPackage -Name 'Claude' -ErrorAction SilentlyContinue
            if ($pkg) {
                $hint = "MSIX: $($pkg.PackageFullName)"
            }
        } catch { }

        if (-not $hint) {
            $appdata  = if ($env:APPDATA)      { $env:APPDATA }      else { Join-Path $HOME 'AppData/Roaming' }
            $localApp = if ($env:LOCALAPPDATA) { $env:LOCALAPPDATA } else { Join-Path $HOME 'AppData/Local' }
            $candidates = @(
                (Join-Path $appdata  'Claude'),
                (Join-Path $localApp 'AnthropicClaude'),
                (Join-Path $localApp 'Programs\claude'),
                (Join-Path $localApp 'Programs\Claude')
            )
            foreach ($c in $candidates) {
                if (Test-Path -LiteralPath $c) { $hint = $c; break }
            }
        }
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

function Test-RfHostGeminiCli {
    if (-not (Test-RfOnPath 'gemini')) { return }
    $version = ''
    try { $version = (& gemini --version 2>$null | Select-Object -First 1) } catch { }
    if (-not $version) { $version = 'detected on PATH' }
    "gemini-cli|cli|Gemini CLI|$version"
}

function Test-RfHostWindsurfDesktop {
    if ($env:RF_TEST_NO_DETECT_APPS -eq '1') { return }
    $hint = ''
    if (Test-RfMacOS) {
        if (Test-Path '/Applications/Windsurf.app') { $hint = '/Applications/Windsurf.app' }
    } elseif (Test-RfLinux) {
        $a = Join-Path $HOME '.codeium/windsurf'
        $b = Join-Path $HOME '.config/Windsurf'
        if (Test-Path $a) { $hint = $a }
        elseif (Test-Path $b) { $hint = $b }
    } elseif (Test-RfWindows) {
        $local = if ($env:LOCALAPPDATA) { $env:LOCALAPPDATA } else { Join-Path $HOME 'AppData/Local' }
        $candidate = Join-Path $local 'Programs/Windsurf'
        if (Test-Path $candidate) { $hint = $candidate }
    }
    if (-not $hint -and (Test-RfOnPath 'windsurf')) { $hint = 'windsurf on PATH' }
    if (-not $hint) { return }
    "windsurf-desktop|desktop|Windsurf|$hint"
}

function Test-RfHostVscodeCopilot {
    if ($env:RF_TEST_NO_DETECT_APPS -eq '1') { return }
    if (Test-RfOnPath 'code') {
        return 'vscode-copilot|desktop|VS Code Copilot|code on PATH'
    }
    if (Test-RfMacOS -and (Test-Path '/Applications/Visual Studio Code.app')) {
        return 'vscode-copilot|desktop|VS Code Copilot|/Applications/Visual Studio Code.app'
    } elseif (Test-RfLinux -and (Test-Path (Join-Path $HOME '.vscode'))) {
        return ("vscode-copilot|desktop|VS Code Copilot|" + (Join-Path $HOME '.vscode'))
    }
}

function Test-RfHostOpencodeCli {
    if (-not (Test-RfOnPath 'opencode')) { return }
    $version = ''
    try { $version = (& opencode --version 2>$null | Select-Object -First 1) } catch { }
    if (-not $version) { $version = 'detected on PATH' }
    "opencode-cli|cli|OpenCode CLI|$version"
}

function Get-RfDetectedHosts {
    $lines = @()
    $lines += Test-RfHostClaudeCodeCli
    $lines += Test-RfHostCodexCli
    $lines += Test-RfHostCursorDesktop
    $lines += Test-RfHostClaudeDesktop
    $lines += Test-RfHostCopilotCli
    $lines += Test-RfHostGeminiCli
    $lines += Test-RfHostWindsurfDesktop
    $lines += Test-RfHostVscodeCopilot
    $lines += Test-RfHostOpencodeCli
    return $lines | Where-Object { $_ -and $_.Trim() }
}

function Get-RfHostById {
    param([string]$Id)
    switch ($Id) {
        'claude-code-cli'  { return Test-RfHostClaudeCodeCli }
        'codex-cli'        { return Test-RfHostCodexCli }
        'cursor-desktop'   { return Test-RfHostCursorDesktop }
        'claude-desktop'   { return Test-RfHostClaudeDesktop }
        'copilot-cli'      { return Test-RfHostCopilotCli }
        'gemini-cli'       { return Test-RfHostGeminiCli }
        'windsurf-desktop' { return Test-RfHostWindsurfDesktop }
        'vscode-copilot'   { return Test-RfHostVscodeCopilot }
        'opencode-cli'     { return Test-RfHostOpencodeCli }
        default { throw "unknown host id: $Id" }
    }
}

function Get-RfKnownHostIds {
    return @(
        'claude-code-cli',
        'codex-cli',
        'cursor-desktop',
        'claude-desktop',
        'copilot-cli',
        'gemini-cli',
        'windsurf-desktop',
        'vscode-copilot',
        'opencode-cli'
    )
}

# Show-RfDetectDiagnostics — dump the inputs the detector saw on Windows
# when nothing was found, so the user can tell us (or see themselves) why.
# Cheap to call; only runs on the failure path.
function Show-RfDetectDiagnostics {
    Write-Host ""
    Write-RfDim "Detection diagnostics (Windows):"
    $appdata  = if ($env:APPDATA)      { $env:APPDATA }      else { '(unset)' }
    $localApp = if ($env:LOCALAPPDATA) { $env:LOCALAPPDATA } else { '(unset)' }
    $noDetect = if ($env:RF_TEST_NO_DETECT_APPS) { $env:RF_TEST_NO_DETECT_APPS } else { '(unset)' }
    $onPath = [bool](Get-Command -Name 'claude' -CommandType Application, ExternalScript -ErrorAction SilentlyContinue)
    Write-RfDim "  claude on PATH:            $onPath"
    Write-RfDim "  `$env:APPDATA:              $appdata"
    Write-RfDim "  `$env:LOCALAPPDATA:         $localApp"
    Write-RfDim "  `$env:RF_TEST_NO_DETECT_APPS: $noDetect"
    Write-RfDim "  whoami:                    $(try { whoami 2>$null } catch { '(failed)' })"

    $probes = @()
    if ($env:APPDATA)      { $probes += (Join-Path $env:APPDATA 'Claude\claude-code') }
    if ($env:LOCALAPPDATA) {
        $pkgRoot = Join-Path $env:LOCALAPPDATA 'Packages'
        if (Test-Path -LiteralPath $pkgRoot) {
            try {
                Get-ChildItem -LiteralPath $pkgRoot -Directory -Filter 'Claude_*' -ErrorAction Stop |
                    ForEach-Object { $probes += (Join-Path $_.FullName 'LocalCache\Roaming\Claude\claude-code') }
            } catch { }
        }
    }
    foreach ($probe in $probes) {
        if (Test-Path -LiteralPath $probe) {
            Write-RfDim "  Probe $probe — EXISTS, subdirs:"
            try {
                foreach ($d in (Get-ChildItem -LiteralPath $probe -Directory -ErrorAction Stop)) {
                    $exe = Join-Path $d.FullName 'claude.exe'
                    $hasExe = Test-Path -LiteralPath $exe -PathType Leaf
                    Write-RfDim "    - $($d.Name)  (claude.exe present: $hasExe)"
                }
            } catch {
                Write-RfDim "    (enumeration failed: $($_.Exception.Message))"
            }
        } else {
            Write-RfDim "  Probe $probe — does NOT exist"
        }
    }

    # Cross-check: maybe the file lives under the *other* user profile, which
    # is the typical "elevated PowerShell" trap (APPDATA still points to
    # yours, but a sibling profile owns the install).
    $usersRoot = Join-Path $env:SystemDrive 'Users'
    if (Test-Path -LiteralPath $usersRoot) {
        $other = @()
        try {
            foreach ($u in (Get-ChildItem -LiteralPath $usersRoot -Directory -ErrorAction Stop)) {
                $p = Join-Path $u.FullName 'AppData\Roaming\Claude\claude-code'
                if (Test-Path -LiteralPath $p) { $other += $p }
            }
        } catch { }
        if ($other.Count -gt 0) {
            Write-RfDim "  Claude install dirs found under other profiles:"
            foreach ($p in $other) { Write-RfDim "    - $p" }
            Write-RfDim '  Tip: if claude was installed under a different user, run agents.ps1 from that user (or pass --host=claude-code-cli).'
        }
    }
}
