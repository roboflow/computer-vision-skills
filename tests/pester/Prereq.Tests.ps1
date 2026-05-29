# Pester tests for installer/lib/prereq.ps1 — Node.js prerequisite detection
# and auto-install dispatch. Never actually runs winget; stubs catch the
# would-be invocations.

BeforeAll {
    . (Join-Path $PSScriptRoot 'helpers/Setup.ps1')
    . (Join-Path $Script:RfRepoRoot 'installer/lib/common.ps1')
    . (Join-Path $Script:RfRepoRoot 'installer/lib/prereq.ps1')
}

Describe 'host-needs-node lookups' {
    It 'Test-RfHostNeedsNode is true for claude-code-cli, codex-cli, claude-desktop' {
        Test-RfHostNeedsNode -Id 'claude-code-cli'  | Should -BeTrue
        Test-RfHostNeedsNode -Id 'codex-cli'        | Should -BeTrue
        Test-RfHostNeedsNode -Id 'claude-desktop'   | Should -BeTrue
    }
    It 'Test-RfHostNeedsNode is false for the http-MCP hosts' {
        Test-RfHostNeedsNode -Id 'cursor-desktop'   | Should -BeFalse
        Test-RfHostNeedsNode -Id 'gemini-cli'       | Should -BeFalse
        Test-RfHostNeedsNode -Id 'copilot-cli'      | Should -BeFalse
        Test-RfHostNeedsNode -Id 'windsurf-desktop' | Should -BeFalse
        Test-RfHostNeedsNode -Id 'vscode-copilot'   | Should -BeFalse
        Test-RfHostNeedsNode -Id 'opencode-cli'     | Should -BeFalse
    }
    It 'Test-RfAnyHostNeedsNode is true iff at least one host needs Node' {
        Test-RfAnyHostNeedsNode -Ids @('cursor-desktop','claude-code-cli','gemini-cli') | Should -BeTrue
        Test-RfAnyHostNeedsNode -Ids @('cursor-desktop','gemini-cli','opencode-cli')    | Should -BeFalse
    }
}

Describe 'Find-RfNpx' {
    BeforeEach { $script:rfHome = New-RfIsolatedHome }
    AfterEach  { Remove-RfIsolatedHome }

    It 'returns a single string, not an array, when both npx and npx.ps1 are on PATH' {
        # Reproduces the field crash: Get-Command -CommandType
        # Application,ExternalScript matches BOTH npx.cmd/npx (Application)
        # and npx.ps1 (ExternalScript), so $cmd.Source was a 2-element
        # array and binding it to Use-RfNpx's [string]$NpxPath threw
        # "Cannot convert value to type System.String".
        New-RfStubCommand -Name 'npx' -ExitCode 0 -Stdout '10.5.0'
        $binDir = Join-Path $env:HOME 'bin'
        Set-Content -LiteralPath (Join-Path $binDir 'npx.ps1') -Value 'Write-Output 10.5.0'

        $result = Find-RfNpx
        $result | Should -Not -BeNullOrEmpty
        @($result).Count | Should -Be 1
        $result | Should -BeOfType ([string])
    }
}

Describe 'Confirm-RfNpxAvailable behavior' {
    BeforeEach {
        $script:rfHome = New-RfIsolatedHome
        $Script:RfOptDryRun       = $false
        $Script:RfOptNoInstallNode = $false
        $Script:RfYes              = $false
    }
    AfterEach { Remove-RfIsolatedHome }

    It 'returns true when npx is already on PATH' {
        New-RfStubCommand -Name 'npx' -ExitCode 0 -Stdout '10.5.0'
        Confirm-RfNpxAvailable | Should -BeTrue
    }

    It 'returns true when both npx and npx.ps1 resolve (multi-result PATH)' {
        # The crash path end-to-end: Confirm-RfNpxAvailable calls Find-RfNpx
        # then Use-RfNpx -NpxPath, which previously threw on the array.
        New-RfStubCommand -Name 'npx' -ExitCode 0 -Stdout '10.5.0'
        $binDir = Join-Path $env:HOME 'bin'
        Set-Content -LiteralPath (Join-Path $binDir 'npx.ps1') -Value 'Write-Output 10.5.0'
        Confirm-RfNpxAvailable | Should -BeTrue
    }

    It '--no-install-node refuses without invoking winget' {
        # npx NOT stubbed → not on PATH
        New-RfStubCommand -Name 'winget' -ExitCode 0
        $Script:RfOptNoInstallNode = $true
        Confirm-RfNpxAvailable | Should -BeFalse
        (Get-RfStubCallCount -Name 'winget') | Should -Be 0
    }

    It '--dry-run reports plan without invoking winget' {
        New-RfStubCommand -Name 'winget' -ExitCode 0
        $Script:RfOptDryRun = $true
        Confirm-RfNpxAvailable | Should -BeTrue
        (Get-RfStubCallCount -Name 'winget') | Should -Be 0
    }
}
