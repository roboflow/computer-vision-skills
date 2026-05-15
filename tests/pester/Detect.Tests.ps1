# Pester tests for installer/lib/detect.ps1 — Resolve-RfClaudeCliPath and
# Test-RfHostClaudeCodeCli on off-PATH Windows installs (the case that
# regressed in https://github.com/roboflow/computer-vision-skills/issues/XX
# where Claude Desktop's MSIX bundles claude.exe in a versioned subdir of
# %APPDATA%\Claude\claude-code\ that isn't on PATH).

# Pester 5 evaluates -Skip:<expr> during the Discovery phase, before any
# BeforeAll block runs. Compute the platform flag in BeforeDiscovery so the
# -Skip predicates below see it.
BeforeDiscovery {
    $script:rfTestIsWindows = ($PSVersionTable.PSEdition -eq 'Desktop') -or ($PSVersionTable.Platform -eq 'Win32NT') -or [bool]$IsWindows
}

BeforeAll {
    . (Join-Path $PSScriptRoot 'helpers/Setup.ps1')
    . (Join-Path $Script:RfRepoRoot 'installer/lib/common.ps1')
    . (Join-Path $Script:RfRepoRoot 'installer/lib/detect.ps1')
    $script:rfTestIsWindows = ($PSVersionTable.PSEdition -eq 'Desktop') -or ($PSVersionTable.Platform -eq 'Win32NT') -or [bool]$IsWindows
}

Describe 'Resolve-RfClaudeCliPath' {
    BeforeEach {
        $script:rfHome = New-RfIsolatedHome
        # Bust any cache from a previous test.
        $Script:RfClaudeCliPath = $null
        # APPDATA / LOCALAPPDATA must point into the isolated home so the
        # helper looks at our fake install tree, not the user's real one.
        $script:origAppData      = $env:APPDATA
        $script:origLocalAppData = $env:LOCALAPPDATA
        $env:APPDATA      = Join-Path $script:rfHome 'AppData/Roaming'
        $env:LOCALAPPDATA = Join-Path $script:rfHome 'AppData/Local'
        New-Item -ItemType Directory -Path $env:APPDATA      -Force | Out-Null
        New-Item -ItemType Directory -Path $env:LOCALAPPDATA -Force | Out-Null
        # New-RfIsolatedHome sets RF_TEST_NO_DETECT_APPS=1 (desktop-app
        # suppression), but this Describe is *testing* the install-dir
        # probe specifically. Clear the flag inside the controlled APPDATA
        # so we exercise the code under test.
        Remove-Item Env:RF_TEST_NO_DETECT_APPS -ErrorAction SilentlyContinue
    }
    AfterEach {
        $env:APPDATA      = $script:origAppData
        $env:LOCALAPPDATA = $script:origLocalAppData
        $Script:RfClaudeCliPath = $null
        Remove-RfIsolatedHome
    }

    It 'returns $null when claude is nowhere' {
        # New-RfIsolatedHome already narrows PATH to the stub bin + system
        # dirs, so the user's real `claude` can't leak in.
        Resolve-RfClaudeCliPath -Force | Should -BeNullOrEmpty
    }

    It 'returns $null when RF_TEST_NO_DETECT_APPS=1 even if install dir exists' -Skip:(-not $script:rfTestIsWindows) {
        $env:RF_TEST_NO_DETECT_APPS = '1'
        $verDir = Join-Path $env:APPDATA 'Claude\claude-code\2.1.138'
        New-Item -ItemType Directory -Path $verDir -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $verDir 'claude.exe') -Force | Out-Null
        Resolve-RfClaudeCliPath -Force | Should -BeNullOrEmpty
    }

    It 'finds claude on PATH and returns the full source path' -Skip:(-not $script:rfTestIsWindows) {
        New-RfStubCommand -Name 'claude' -Stdout '2.0.0'
        $resolved = Resolve-RfClaudeCliPath -Force
        $resolved | Should -Not -BeNullOrEmpty
        $resolved | Should -Match 'claude\.(cmd|exe|bat)$'
    }

    It 'finds the MSIX-bundled / Anthropic native install at %APPDATA%\Claude\claude-code\<ver>\claude.exe' -Skip:(-not $script:rfTestIsWindows) {
        $verDir = Join-Path $env:APPDATA 'Claude\claude-code\2.1.138'
        New-Item -ItemType Directory -Path $verDir -Force | Out-Null
        # An empty file is enough — Resolve-RfClaudeCliPath only Test-Paths
        # for the exe and (later) invokes --version, which we don't exercise
        # here. The Get-RfClaudeCliInfo test does.
        New-Item -ItemType File -Path (Join-Path $verDir 'claude.exe') -Force | Out-Null
        $resolved = Resolve-RfClaudeCliPath -Force
        $resolved | Should -Be (Join-Path $verDir 'claude.exe')
    }

    It 'picks the highest semver dir when multiple versions exist' -Skip:(-not $script:rfTestIsWindows) {
        $root = Join-Path $env:APPDATA 'Claude\claude-code'
        foreach ($v in @('1.0.0', '2.1.138', '2.1.9', '2.10.0')) {
            $d = Join-Path $root $v
            New-Item -ItemType Directory -Path $d -Force | Out-Null
            New-Item -ItemType File -Path (Join-Path $d 'claude.exe') -Force | Out-Null
        }
        $resolved = Resolve-RfClaudeCliPath -Force
        # 2.10.0 > 2.1.138 (semver: 10 > 1 in minor). Confirms we sort by
        # parsed [Version], not by lex order ("2.1.138" > "2.10.0" lex).
        $resolved | Should -Be (Join-Path $root '2.10.0\claude.exe')
    }

    It 'skips versioned dirs that lack claude.exe' -Skip:(-not $script:rfTestIsWindows) {
        $root = Join-Path $env:APPDATA 'Claude\claude-code'
        $emptyDir = Join-Path $root '9.9.9'
        New-Item -ItemType Directory -Path $emptyDir -Force | Out-Null
        # No claude.exe written.
        $verDir = Join-Path $root '2.1.138'
        New-Item -ItemType Directory -Path $verDir -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $verDir 'claude.exe') -Force | Out-Null
        $resolved = Resolve-RfClaudeCliPath -Force
        $resolved | Should -Be (Join-Path $verDir 'claude.exe')
    }

    It 'falls back to legacy Programs\claude\claude.exe' -Skip:(-not $script:rfTestIsWindows) {
        $exe = Join-Path $env:LOCALAPPDATA 'Programs\claude\claude.exe'
        New-Item -ItemType Directory -Path (Split-Path -Parent $exe) -Force | Out-Null
        New-Item -ItemType File -Path $exe -Force | Out-Null
        $resolved = Resolve-RfClaudeCliPath -Force
        $resolved | Should -Be $exe
    }

    It 'PATH lookup wins over off-PATH install' -Skip:(-not $script:rfTestIsWindows) {
        # Set up both: a versioned install AND a PATH stub. PATH should win
        # because npm-style installs are easier to update.
        $verDir = Join-Path $env:APPDATA 'Claude\claude-code\2.1.138'
        New-Item -ItemType Directory -Path $verDir -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $verDir 'claude.exe') -Force | Out-Null
        New-RfStubCommand -Name 'claude' -Stdout '9.9.9-onpath'
        $resolved = Resolve-RfClaudeCliPath -Force
        $resolved | Should -Match 'claude\.(cmd|exe|bat)$'
        $resolved | Should -Not -Be (Join-Path $verDir 'claude.exe')
    }

    It 'caches the result between calls' -Skip:(-not $script:rfTestIsWindows) {
        $verDir = Join-Path $env:APPDATA 'Claude\claude-code\2.1.138'
        New-Item -ItemType Directory -Path $verDir -Force | Out-Null
        $exe = Join-Path $verDir 'claude.exe'
        New-Item -ItemType File -Path $exe -Force | Out-Null
        $first  = Resolve-RfClaudeCliPath -Force
        # Now delete the file. Without caching the second call would return
        # $null. The cache means we still get the original path.
        Remove-Item -LiteralPath $exe -Force
        $second = Resolve-RfClaudeCliPath
        $second | Should -Be $first
        # -Force re-probes; should now return $null since the exe is gone.
        $third = Resolve-RfClaudeCliPath -Force
        $third | Should -BeNullOrEmpty
    }
}

Describe 'Test-RfHostClaudeCodeCli' {
    BeforeEach {
        $script:rfHome = New-RfIsolatedHome
        $Script:RfClaudeCliPath = $null
        $script:origAppData = $env:APPDATA
        $env:APPDATA = Join-Path $script:rfHome 'AppData/Roaming'
        New-Item -ItemType Directory -Path $env:APPDATA -Force | Out-Null
        Remove-Item Env:RF_TEST_NO_DETECT_APPS -ErrorAction SilentlyContinue
    }
    AfterEach {
        $env:APPDATA = $script:origAppData
        $Script:RfClaudeCliPath = $null
        Remove-RfIsolatedHome
    }

    It 'emits nothing when claude is not installed' {
        Test-RfHostClaudeCodeCli | Should -BeNullOrEmpty
    }

    It 'emits an id|kind|label|hint line with (not on PATH) marker for off-PATH installs' -Skip:(-not $script:rfTestIsWindows) {
        $verDir = Join-Path $env:APPDATA 'Claude\claude-code\2.1.138'
        New-Item -ItemType Directory -Path $verDir -Force | Out-Null
        # Create a stub that actually emits a version line on --version. A
        # zero-byte file would be detected by Resolve-RfClaudeCliPath but
        # would fail the `& $exe --version` call in Get-RfClaudeCliInfo. We
        # write a tiny .cmd-equivalent here via a real powershell stub.
        # Simpler: just use a real binary that exits 0 with no output, then
        # assert the fallback hint format.
        Copy-Item -LiteralPath (Join-Path $env:SystemRoot 'System32\where.exe') -Destination (Join-Path $verDir 'claude.exe') -Force
        $line = Test-RfHostClaudeCodeCli
        $line | Should -Match '^claude-code-cli\|cli\|Claude Code CLI\|'
        # `where.exe --version` returns non-version output but `(not on PATH)`
        # is appended either way.
        $line | Should -Match 'not on PATH'
    }
}
