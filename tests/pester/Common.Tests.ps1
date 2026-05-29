# Pester tests for installer/lib/common.ps1 helpers.

BeforeAll {
    . (Join-Path $PSScriptRoot 'helpers/Setup.ps1')
    . (Join-Path $Script:RfRepoRoot 'installer/lib/common.ps1')
}

Describe 'Invoke-RfNative' {
    BeforeEach { $script:rfHome = New-RfIsolatedHome }
    AfterEach  { Remove-RfIsolatedHome }

    It 'returns the exit code instead of throwing when a native command writes to stderr under ErrorActionPreference=Stop' {
        # This is the regression guard for the Windows field crash: claude
        # writes its requirement error to stderr and exits non-zero. With the
        # script-wide 'Stop' preference and a bare `& cmd 2>&1`, the first
        # stderr line would throw a terminating exception before any
        # exit-code check ran. Invoke-RfNative must localize the preference
        # and hand back the code.
        $ErrorActionPreference = 'Stop'
        # A stub that writes a line to stderr and exits 3.
        New-RfStubCommand -Name 'noisy' -ExitCode 3 -Stderr 'something on stderr'
        $stub = if ($Script:RfIsWindows) { 'noisy' } else { Join-Path $env:HOME 'bin/noisy' }

        $script:code = $null
        { $script:code = Invoke-RfNative -FilePath $stub } | Should -Not -Throw
        $script:code | Should -Be 3
    }

    It 'returns 0 for a successful native command' {
        $ErrorActionPreference = 'Stop'
        New-RfStubCommand -Name 'quiet' -ExitCode 0 -Stdout 'ok'
        $stub = if ($Script:RfIsWindows) { 'quiet' } else { Join-Path $env:HOME 'bin/quiet' }
        Invoke-RfNative -FilePath $stub | Should -Be 0
    }
}
