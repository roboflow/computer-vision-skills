# Pester tests for Phase 4 hosts.

BeforeAll {
    . (Join-Path $PSScriptRoot 'helpers/Setup.ps1')
}

Describe 'gemini-cli adapter' {
    BeforeEach {
        $script:rfHome = New-RfIsolatedHome
        $env:ROBOFLOW_API_KEY = 'rf_test_key'
    }
    AfterEach {
        Remove-Item Env:ROBOFLOW_API_KEY -ErrorAction SilentlyContinue
        Remove-RfIsolatedHome
    }

    It 'writes ~/.gemini/settings.json' {
        Invoke-RfMainPs -Items @('--yes', '--host=gemini-cli') | Should -Be 0
        $cfg = Join-Path $script:rfHome '.gemini/settings.json'
        Test-Path -LiteralPath $cfg | Should -BeTrue
        (Get-Content -LiteralPath $cfg -Raw) | Should -Match '"roboflow"'
    }

    It 'uninstall removes only Roboflow' {
        Invoke-RfMainPs -Items @('--yes', '--host=gemini-cli') | Should -Be 0
        Invoke-RfMainPs -Items @('--yes', '--host=gemini-cli', '--uninstall') | Should -Be 0
        $cfg = Join-Path $script:rfHome '.gemini/settings.json'
        if (Test-Path -LiteralPath $cfg) {
            (Get-Content -LiteralPath $cfg -Raw) | Should -Not -Match '"roboflow"'
        }
    }
}

Describe 'windsurf-desktop adapter' {
    BeforeEach {
        $script:rfHome = New-RfIsolatedHome
        $env:ROBOFLOW_API_KEY = 'rf_test_key'
    }
    AfterEach {
        Remove-Item Env:ROBOFLOW_API_KEY -ErrorAction SilentlyContinue
        Remove-RfIsolatedHome
    }

    It 'writes ~/.codeium/windsurf/mcp_config.json' {
        Invoke-RfMainPs -Items @('--yes', '--host=windsurf-desktop') | Should -Be 0
        $cfg = Join-Path $script:rfHome '.codeium/windsurf/mcp_config.json'
        Test-Path -LiteralPath $cfg | Should -BeTrue
        (Get-Content -LiteralPath $cfg -Raw) | Should -Match '"roboflow"'
    }
}

Describe 'vscode-copilot adapter' {
    BeforeEach {
        $script:rfHome = New-RfIsolatedHome
        $env:ROBOFLOW_API_KEY = 'rf_test_key'
    }
    AfterEach {
        Remove-Item Env:ROBOFLOW_API_KEY -ErrorAction SilentlyContinue
        Remove-RfIsolatedHome
    }

    It 'global install writes user-level mcp.json with servers + inputs' {
        Invoke-RfMainPs -Items @('--yes', '--host=vscode-copilot') | Should -Be 0
        $cfg = if ($IsMacOS) {
            Join-Path $script:rfHome 'Library/Application Support/Code/User/mcp.json'
        } elseif ($IsLinux) {
            Join-Path $script:rfHome '.config/Code/User/mcp.json'
        } else {
            Join-Path $env:APPDATA 'Code/User/mcp.json'
        }
        Test-Path -LiteralPath $cfg | Should -BeTrue
        $content = Get-Content -LiteralPath $cfg -Raw
        $content | Should -Match '"servers"'
        $content | Should -Match '"inputs"'
        $content | Should -Match '"roboflow_api_key"'
        $content | Should -Match 'promptString'
        $content | Should -Match '\$\{input:roboflow_api_key\}'
    }

    It 'project install writes .vscode/mcp.json' {
        Push-Location $script:rfHome
        try {
            Invoke-RfMainPs -Items @('--yes', '--host=vscode-copilot', '--project') | Should -Be 0
            $cfg = Join-Path $script:rfHome '.vscode/mcp.json'
            Test-Path -LiteralPath $cfg | Should -BeTrue
            $content = Get-Content -LiteralPath $cfg -Raw
            $content | Should -Match '"servers"'
            $content | Should -Match '"inputs"'
        }
        finally {
            Pop-Location
        }
    }

    It 'uninstall removes server + input entries' {
        Push-Location $script:rfHome
        try {
            Invoke-RfMainPs -Items @('--yes', '--host=vscode-copilot', '--project') | Should -Be 0
            Invoke-RfMainPs -Items @('--yes', '--host=vscode-copilot', '--project', '--uninstall') | Should -Be 0
            $cfg = Join-Path $script:rfHome '.vscode/mcp.json'
            if (Test-Path -LiteralPath $cfg) {
                $content = Get-Content -LiteralPath $cfg -Raw
                $content | Should -Not -Match '"roboflow"'
                $content | Should -Not -Match '"roboflow_api_key"'
            }
        }
        finally {
            Pop-Location
        }
    }
}

Describe 'opencode-cli adapter' {
    BeforeEach {
        $script:rfHome = New-RfIsolatedHome
        $env:ROBOFLOW_API_KEY = 'rf_test_key'
    }
    AfterEach {
        Remove-Item Env:ROBOFLOW_API_KEY -ErrorAction SilentlyContinue
        Remove-RfIsolatedHome
    }

    It 'writes mcp/remote schema' {
        Invoke-RfMainPs -Items @('--yes', '--host=opencode-cli') | Should -Be 0
        $cfg = Join-Path $script:rfHome '.config/opencode/opencode.json'
        Test-Path -LiteralPath $cfg | Should -BeTrue
        $content = Get-Content -LiteralPath $cfg -Raw
        $content | Should -Match '"mcp"'
        $content | Should -Match '"roboflow"'
        $content | Should -Match '"remote"'
    }

    It 'refuses JSONC config without --force' {
        $cfg = Join-Path $script:rfHome '.config/opencode/opencode.json'
        New-Item -ItemType Directory -Path (Split-Path -Parent $cfg) -Force | Out-Null
        @"
{
  // user comment
  "theme": "dark"
}
"@ | Set-Content -LiteralPath $cfg
        Invoke-RfMainPs -Items @('--yes', '--host=opencode-cli') | Should -Not -Be 0
    }

    It '--force overrides JSONC refusal' {
        $cfg = Join-Path $script:rfHome '.config/opencode/opencode.json'
        New-Item -ItemType Directory -Path (Split-Path -Parent $cfg) -Force | Out-Null
        @"
{
  // user comment
  "theme": "dark"
}
"@ | Set-Content -LiteralPath $cfg
        Invoke-RfMainPs -Items @('--yes', '--host=opencode-cli', '--force') | Should -Be 0
        $content = Get-Content -LiteralPath $cfg -Raw
        $content | Should -Match '"roboflow"'
    }
}
