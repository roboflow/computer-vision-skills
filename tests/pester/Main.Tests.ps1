# Pester tests for installer/main.ps1 — argument parsing, help/version, exit codes.

BeforeAll {
    . (Join-Path $PSScriptRoot 'helpers/Setup.ps1')
}

Describe 'main.ps1 — usage / version' {
    BeforeEach { New-RfIsolatedHome | Out-Null }
    AfterEach  { Remove-RfIsolatedHome }

    It '--help exits 0 with usage text' {
        $main = Join-Path $Script:RfRepoRoot 'installer/main.ps1'
        $output = & $Script:RfPwshPath -NoProfile -File $main --help 2>&1 | Out-String
        $LASTEXITCODE | Should -Be 0
        $output | Should -Match 'agents.ps1'
        $output | Should -Match '--host='
        $output | Should -Match 'claude-code-cli'
    }

    It '--version prints installer version' {
        $main = Join-Path $Script:RfRepoRoot 'installer/main.ps1'
        $output = & $Script:RfPwshPath -NoProfile -File $main --version 2>&1 | Out-String
        $LASTEXITCODE | Should -Be 0
        $output | Should -Match 'installer'
    }

    It 'unknown flag exits 2' {
        $main = Join-Path $Script:RfRepoRoot 'installer/main.ps1'
        $null = & $Script:RfPwshPath -NoProfile -File $main --bogus-flag 2>&1
        $LASTEXITCODE | Should -Be 2
    }

    It '--project --inline-key conflict exits 4' {
        $main = Join-Path $Script:RfRepoRoot 'installer/main.ps1'
        $null = & $Script:RfPwshPath -NoProfile -File $main --project --inline-key 2>&1
        $LASTEXITCODE | Should -Be 4
    }

    It 'with no detected hosts exits 3' {
        $main = Join-Path $Script:RfRepoRoot 'installer/main.ps1'
        $null = & $Script:RfPwshPath -NoProfile -File $main --yes --auth-skip 2>&1
        $LASTEXITCODE | Should -Be 3
    }

    It '--host with unknown id exits 2' {
        $main = Join-Path $Script:RfRepoRoot 'installer/main.ps1'
        $null = & $Script:RfPwshPath -NoProfile -File $main --yes --host=nonexistent-cli --auth-skip 2>&1
        $LASTEXITCODE | Should -Be 2
    }
}
