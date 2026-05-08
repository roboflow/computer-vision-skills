# Pester tests for installer/lib/rules.ps1.

BeforeAll {
    . (Join-Path $PSScriptRoot 'helpers/Setup.ps1')
    $env:RF_REPO_DIR = $Script:RfRepoRoot
    $env:RF_INSTALLER_DIR = Join-Path $Script:RfRepoRoot 'installer'
    $Script:RfRepoDir = $Script:RfRepoRoot
    . (Join-Path $Script:RfRepoRoot 'installer/lib/common.ps1')
    . (Join-Path $Script:RfRepoRoot 'installer/lib/json_io.ps1')
    . (Join-Path $Script:RfRepoRoot 'installer/lib/rules.ps1')
}

Describe 'rules.ps1 — managed block + Cursor mdc' {
    BeforeEach {
        $script:rfHome = New-RfIsolatedHome
        $Script:RfRepoDir = $Script:RfRepoRoot
    }
    AfterEach { Remove-RfIsolatedHome }

    It 'install_managed_block creates new CLAUDE.md with markers' {
        $target = Join-Path $script:rfHome 'CLAUDE.md'
        Install-RfRulesManagedBlock -Target $target -Flavor 'claude' | Out-Null
        Test-Path -LiteralPath $target | Should -BeTrue
        $content = Get-Content -LiteralPath $target -Raw
        $content | Should -Match '<!-- BEGIN ROBOFLOW -->'
        $content | Should -Match '<!-- END ROBOFLOW -->'
        $content | Should -Match 'Roboflow'
    }

    It 'install_managed_block appends to existing CLAUDE.md' {
        $target = Join-Path $script:rfHome 'CLAUDE.md'
        "# My project`n`nUser-owned content here." | Set-Content -LiteralPath $target
        Install-RfRulesManagedBlock -Target $target -Flavor 'claude' | Out-Null
        $content = Get-Content -LiteralPath $target -Raw
        $content | Should -Match 'User-owned content here'
        $content | Should -Match '<!-- BEGIN ROBOFLOW -->'
    }

    It 'install_managed_block is idempotent' {
        $target = Join-Path $script:rfHome 'CLAUDE.md'
        Install-RfRulesManagedBlock -Target $target -Flavor 'claude' | Out-Null
        $first = (Get-Content -LiteralPath $target -Raw).Length
        Install-RfRulesManagedBlock -Target $target -Flavor 'claude' | Out-Null
        $second = (Get-Content -LiteralPath $target -Raw).Length
        $first | Should -Be $second
        $count = ([regex]::Matches((Get-Content -LiteralPath $target -Raw), '<!-- BEGIN ROBOFLOW -->')).Count
        $count | Should -Be 1
    }

    It 'remove_managed_block strips block but keeps user content' {
        $target = Join-Path $script:rfHome 'CLAUDE.md'
        "# My project`n`nUser-owned content here." | Set-Content -LiteralPath $target
        Install-RfRulesManagedBlock -Target $target -Flavor 'claude' | Out-Null
        Uninstall-RfRulesManagedBlock -Target $target | Out-Null
        $content = Get-Content -LiteralPath $target -Raw
        $content | Should -Match 'User-owned content here'
        $content | Should -Not -Match 'BEGIN ROBOFLOW'
    }

    It 'install_cursor_mdc writes the template' {
        $target = Join-Path $script:rfHome '.cursor/rules/roboflow.mdc'
        Install-RfCursorMdc -Target $target | Out-Null
        Test-Path -LiteralPath $target | Should -BeTrue
        $content = Get-Content -LiteralPath $target -Raw
        $content | Should -Match '^---'
        $content | Should -Match '# Roboflow'
    }
}

Describe 'cursor adapter — rules wiring' {
    BeforeEach {
        $script:rfHome = New-RfIsolatedHome
        $env:ROBOFLOW_API_KEY = 'rf_test_key'
    }
    AfterEach {
        Remove-Item Env:ROBOFLOW_API_KEY -ErrorAction SilentlyContinue
        Remove-RfIsolatedHome
    }

    It 'cursor --project writes .cursor/rules/roboflow.mdc' {
        Push-Location $script:rfHome
        try {
            Invoke-RfMainPs -Items @('--yes', '--host=cursor-desktop', '--project') | Should -Be 0
            Test-Path -LiteralPath (Join-Path $script:rfHome '.cursor/rules/roboflow.mdc') | Should -BeTrue
        } finally { Pop-Location }
    }

    It 'cursor --global skips rules' {
        Invoke-RfMainPs -Items @('--yes', '--host=cursor-desktop') | Should -Be 0
        Test-Path -LiteralPath (Join-Path $script:rfHome '.cursor/rules/roboflow.mdc') | Should -BeFalse
    }

    It '--rules-only writes only the rule file (no MCP, no skills)' {
        Push-Location $script:rfHome
        try {
            Invoke-RfMainPs -Items @('--yes', '--host=cursor-desktop', '--project', '--rules-only') | Should -Be 0
            Test-Path -LiteralPath (Join-Path $script:rfHome '.cursor/rules/roboflow.mdc') | Should -BeTrue
            Test-Path -LiteralPath (Join-Path $script:rfHome '.cursor/mcp.json') | Should -BeFalse
            Test-Path -LiteralPath (Join-Path $script:rfHome '.claude/skills') | Should -BeFalse
        } finally { Pop-Location }
    }
}
