# Pester tests for the host adapters.

BeforeAll {
    . (Join-Path $PSScriptRoot 'helpers/Setup.ps1')
}

Describe 'cursor-desktop adapter' {
    BeforeEach {
        $script:rfHome = New-RfIsolatedHome
        $env:ROBOFLOW_API_KEY = 'rf_test_key'
    }
    AfterEach {
        Remove-Item Env:ROBOFLOW_API_KEY -ErrorAction SilentlyContinue
        Remove-RfIsolatedHome
    }

    It 'writes ~/.cursor/mcp.json with literal key at global scope' {
        Invoke-RfMainPs -Items @('--yes', '--host=cursor-desktop') | Should -Be 0
        $cfg = Join-Path $script:rfHome '.cursor/mcp.json'
        Test-Path -LiteralPath $cfg | Should -BeTrue
        $content = Get-Content -LiteralPath $cfg -Raw
        $content | Should -Match '"roboflow"'
        $content | Should -Match 'mcp.roboflow.com/mcp'
        # Global scope embeds the literal key; placeholder gone.
        $content | Should -Match 'rf_test_key'
        $content | Should -Not -Match '\$\{ROBOFLOW_API_KEY\}'
    }

    It '--project keeps the placeholder (committable file)' {
        Push-Location $script:rfHome
        try {
            Invoke-RfMainPs -Items @('--yes', '--host=cursor-desktop', '--project') | Should -Be 0
            $cfg = Join-Path $script:rfHome '.cursor/mcp.json'
            $content = Get-Content -LiteralPath $cfg -Raw
            $content | Should -Match '\$\{ROBOFLOW_API_KEY\}'
            $content | Should -Not -Match 'rf_test_key'
        } finally { Pop-Location }
    }

    It '--project --inline-key embeds the literal key (with warn)' {
        Push-Location $script:rfHome
        try {
            Invoke-RfMainPs -Items @('--yes', '--host=cursor-desktop', '--project', '--inline-key') | Should -Be 0
            $cfg = Join-Path $script:rfHome '.cursor/mcp.json'
            $content = Get-Content -LiteralPath $cfg -Raw
            $content | Should -Match 'rf_test_key'
        } finally { Pop-Location }
    }

    It 'copies skills into ~/.claude/skills' {
        Invoke-RfMainPs -Items @('--yes', '--host=cursor-desktop') | Should -Be 0
        Test-Path -LiteralPath (Join-Path $script:rfHome '.claude/skills/inference/SKILL.md') | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $script:rfHome '.claude/skills/inference/.roboflow-install-manifest.json') | Should -BeTrue
    }

    It '--no-skills writes MCP only' {
        Invoke-RfMainPs -Items @('--yes', '--host=cursor-desktop', '--no-skills') | Should -Be 0
        Test-Path -LiteralPath (Join-Path $script:rfHome '.cursor/mcp.json') | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $script:rfHome '.claude/skills') | Should -BeFalse
    }

    It '--skills-only skips MCP' {
        Invoke-RfMainPs -Items @('--yes', '--host=cursor-desktop', '--skills-only') | Should -Be 0
        Test-Path -LiteralPath (Join-Path $script:rfHome '.cursor/mcp.json') | Should -BeFalse
        Test-Path -LiteralPath (Join-Path $script:rfHome '.claude/skills/inference') | Should -BeTrue
    }

    It 'dry-run writes nothing' {
        Invoke-RfMainPs -Items @('--yes', '--host=cursor-desktop', '--dry-run') | Should -Be 0
        Test-Path -LiteralPath (Join-Path $script:rfHome '.cursor/mcp.json') | Should -BeFalse
        Test-Path -LiteralPath (Join-Path $script:rfHome '.claude/skills') | Should -BeFalse
    }

    It 'preserves existing MCP servers' {
        $cfg = Join-Path $script:rfHome '.cursor/mcp.json'
        New-Item -ItemType Directory -Path (Split-Path -Parent $cfg) -Force | Out-Null
        @{
            mcpServers = @{
                'my-other-server' = @{ type = 'stdio'; command = '/bin/echo' }
            }
        } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $cfg

        Invoke-RfMainPs -Items @('--yes', '--host=cursor-desktop') | Should -Be 0
        $content = Get-Content -LiteralPath $cfg -Raw
        $content | Should -Match '"my-other-server"'
        $content | Should -Match '"roboflow"'
    }

    It 'uninstall removes only Roboflow MCP entry, leaves others' {
        $cfg = Join-Path $script:rfHome '.cursor/mcp.json'
        New-Item -ItemType Directory -Path (Split-Path -Parent $cfg) -Force | Out-Null
        @{
            mcpServers = @{
                'my-other-server' = @{ type = 'stdio'; command = '/bin/echo' }
            }
        } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $cfg

        Invoke-RfMainPs -Items @('--yes', '--host=cursor-desktop') | Should -Be 0
        Invoke-RfMainPs -Items @('--yes', '--host=cursor-desktop', '--uninstall') | Should -Be 0
        $content = Get-Content -LiteralPath $cfg -Raw
        $content | Should -Not -Match '"roboflow"'
        $content | Should -Match '"my-other-server"'
    }
}

Describe 'claude-desktop adapter (mcp-remote stdio bridge)' {
    BeforeEach {
        $script:rfHome = New-RfIsolatedHome
        $env:ROBOFLOW_API_KEY = 'rf_test_key'
        # Bridge requires npx — stub it.
        New-RfStubCommand -Name 'npx' -ExitCode 0
    }
    AfterEach {
        Remove-Item Env:ROBOFLOW_API_KEY -ErrorAction SilentlyContinue
        Remove-RfIsolatedHome
    }

    It 'writes mcp-remote bridge entry with literal key' {
        Invoke-RfMainPs -Items @('--yes', '--host=claude-desktop') | Should -Be 0
        $cfg = if ($IsMacOS) {
            Join-Path $script:rfHome 'Library/Application Support/Claude/claude_desktop_config.json'
        } elseif ($IsLinux) {
            Join-Path $script:rfHome '.config/Claude/claude_desktop_config.json'
        } else {
            Join-Path $env:APPDATA 'Claude/claude_desktop_config.json'
        }
        Test-Path -LiteralPath $cfg | Should -BeTrue
        $content = Get-Content -LiteralPath $cfg -Raw
        $content | Should -Match '"command": "npx"'
        $content | Should -Match 'mcp-remote@'
        $content | Should -Match 'x-api-key:rf_test_key'
        $content | Should -Not -Match '"type": "http"'
        $content | Should -Not -Match '"url":'
    }

    It '--no-mcp is a no-op' {
        Invoke-RfMainPs -Items @('--yes', '--host=claude-desktop', '--no-mcp') | Should -Be 0
        $cfg = if ($IsMacOS) {
            Join-Path $script:rfHome 'Library/Application Support/Claude/claude_desktop_config.json'
        } elseif ($IsLinux) {
            Join-Path $script:rfHome '.config/Claude/claude_desktop_config.json'
        } else {
            Join-Path $env:APPDATA 'Claude/claude_desktop_config.json'
        }
        Test-Path -LiteralPath $cfg | Should -BeFalse
    }
}

Describe 'copilot-cli adapter' {
    BeforeEach {
        $script:rfHome = New-RfIsolatedHome
        $env:ROBOFLOW_API_KEY = 'rf_test_key'
    }
    AfterEach {
        Remove-Item Env:ROBOFLOW_API_KEY -ErrorAction SilentlyContinue
        Remove-RfIsolatedHome
    }

    It 'writes ~/.copilot/mcp-config.json' {
        Invoke-RfMainPs -Items @('--yes', '--host=copilot-cli') | Should -Be 0
        $cfg = Join-Path $script:rfHome '.copilot/mcp-config.json'
        Test-Path -LiteralPath $cfg | Should -BeTrue
        $content = Get-Content -LiteralPath $cfg -Raw
        $content | Should -Match '"roboflow"'
    }

    It 'preserves existing servers and removes only Roboflow' {
        $cfg = Join-Path $script:rfHome '.copilot/mcp-config.json'
        New-Item -ItemType Directory -Path (Split-Path -Parent $cfg) -Force | Out-Null
        @{
            mcpServers = @{
                existing = @{ type = 'stdio'; command = '/bin/sh' }
            }
        } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $cfg

        Invoke-RfMainPs -Items @('--yes', '--host=copilot-cli') | Should -Be 0
        Invoke-RfMainPs -Items @('--yes', '--host=copilot-cli', '--uninstall') | Should -Be 0
        $content = Get-Content -LiteralPath $cfg -Raw
        $content | Should -Not -Match '"roboflow"'
        $content | Should -Match '"existing"'
    }
}

Describe 'claude-code-cli adapter (plugin path)' {
    BeforeEach {
        $script:rfHome = New-RfIsolatedHome
        $env:ROBOFLOW_API_KEY = 'rf_test_key'
    }
    AfterEach {
        Remove-Item Env:ROBOFLOW_API_KEY -ErrorAction SilentlyContinue
        Remove-RfIsolatedHome
    }

    It 'fails clearly when claude is not on PATH' {
        $code = Invoke-RfMainPs -Items @('--yes', '--host=claude-code-cli')
        $code | Should -Not -Be 0
    }

    It 'dry-run with stub claude prints plan, no plugin commands invoked' {
        New-RfStubCommand -Name 'claude' -ExitCode 0
        Invoke-RfMainPs -Items @('--yes', '--host=claude-code-cli', '--dry-run') | Should -Be 0
        $calls = Get-RfStubCalls -Name 'claude'
        # Detect step calls `claude --version`; that's allowed. We check that
        # no `plugin` argument was sent.
        ($calls -match 'arg: plugin') | Should -BeFalse
    }

    It 'patches cached .mcp.json (stdio shape) with literal key after install' {
        New-RfStubCommand -Name 'claude' -ExitCode 0
        $cacheDir = Join-Path $script:rfHome '.claude/plugins/cache/roboflow/roboflow/0.2.0'
        New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
        $mcpFile = Join-Path $cacheDir '.mcp.json'
        @'
{
  "mcpServers": {
    "roboflow": {
      "command": "npx",
      "args": [
        "-y",
        "mcp-remote@0.1.27",
        "https://mcp.roboflow.com/mcp",
        "--header",
        "x-api-key:${ROBOFLOW_API_KEY}"
      ],
      "note": "Replace ${ROBOFLOW_API_KEY} with your key."
    }
  }
}
'@ | Set-Content -LiteralPath $mcpFile

        Invoke-RfMainPs -Items @('--yes', '--host=claude-code-cli') | Should -Be 0

        $content = Get-Content -LiteralPath $mcpFile -Raw
        $content | Should -Match '"x-api-key:rf_test_key"'
        $content | Should -Not -Match '\$\{ROBOFLOW_API_KEY\}'
        $content | Should -Not -Match '"note":'
    }

    It 'patches legacy http-shape cache for back-compat' {
        New-RfStubCommand -Name 'claude' -ExitCode 0
        $cacheDir = Join-Path $script:rfHome '.claude/plugins/cache/roboflow/roboflow/0.1.0'
        New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
        $mcpFile = Join-Path $cacheDir '.mcp.json'
        @'
{
  "mcpServers": {
    "roboflow": {
      "type": "http",
      "url": "https://mcp.roboflow.com/mcp",
      "headers": {
        "x-api-key": "${ROBOFLOW_API_KEY}",
        "Accept": "application/json, text/event-stream"
      }
    }
  }
}
'@ | Set-Content -LiteralPath $mcpFile

        Invoke-RfMainPs -Items @('--yes', '--host=claude-code-cli') | Should -Be 0

        $content = Get-Content -LiteralPath $mcpFile -Raw
        $content | Should -Match '"x-api-key":\s*"rf_test_key"'
        $content | Should -Not -Match '\$\{ROBOFLOW_API_KEY\}'
    }
}
