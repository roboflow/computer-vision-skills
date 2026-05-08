# Pester tests for installer/lib/json_io.ps1.

BeforeAll {
    . (Join-Path $PSScriptRoot 'helpers/Setup.ps1')
    . (Join-Path $Script:RfRepoRoot 'installer/lib/common.ps1')
    . (Join-Path $Script:RfRepoRoot 'installer/lib/json_io.ps1')
}

Describe 'json_io.ps1 — MCP merge / remove' {
    BeforeEach { $script:rfHome = New-RfIsolatedHome }
    AfterEach  { Remove-RfIsolatedHome }

    It 'Set-RfMcpServer creates a new file' {
        $cfg = Join-Path $script:rfHome 'cfg.json'
        $server = [pscustomobject]@{ type = 'http'; url = 'https://mcp.roboflow.com/mcp' }
        Set-RfMcpServer -ConfigPath $cfg -ServerName 'roboflow' -ServerObject $server
        Test-Path -LiteralPath $cfg | Should -BeTrue
        $content = Get-Content -LiteralPath $cfg -Raw
        $content | Should -Match '"roboflow"'
        $content | Should -Match 'mcp.roboflow.com/mcp'
    }

    It 'Set-RfMcpServer preserves existing servers' {
        $cfg = Join-Path $script:rfHome 'cfg.json'
        @{
            mcpServers = @{
                other = @{ type = 'stdio'; command = '/usr/local/bin/other' }
            }
            someOtherKey = 42
        } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $cfg

        $server = [pscustomobject]@{ type = 'http'; url = 'https://mcp.roboflow.com/mcp' }
        Set-RfMcpServer -ConfigPath $cfg -ServerName 'roboflow' -ServerObject $server

        $content = Get-Content -LiteralPath $cfg -Raw
        $content | Should -Match '"other"'
        $content | Should -Match '"roboflow"'
        $content | Should -Match 'someOtherKey'
    }

    It 'Set-RfMcpServer replaces existing roboflow entry' {
        $cfg = Join-Path $script:rfHome 'cfg.json'
        @{
            mcpServers = @{
                roboflow = @{ type = 'stdio'; command = '/old/path' }
            }
        } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $cfg

        $server = [pscustomobject]@{ type = 'http'; url = 'https://mcp.roboflow.com/mcp' }
        Set-RfMcpServer -ConfigPath $cfg -ServerName 'roboflow' -ServerObject $server

        $content = Get-Content -LiteralPath $cfg -Raw
        $content | Should -Match 'mcp.roboflow.com'
        $content | Should -Not -Match '/old/path'
    }

    It 'Remove-RfMcpServer drops named server only' {
        $cfg = Join-Path $script:rfHome 'cfg.json'
        @{
            mcpServers = @{
                roboflow = @{ type = 'http' }
                other    = @{ type = 'stdio' }
            }
        } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $cfg

        Remove-RfMcpServer -ConfigPath $cfg -ServerName 'roboflow'
        $content = Get-Content -LiteralPath $cfg -Raw
        $content | Should -Not -Match '"roboflow"'
        $content | Should -Match '"other"'
    }

    It 'Remove-RfMcpServer drops mcpServers when emptied' {
        $cfg = Join-Path $script:rfHome 'cfg.json'
        @{
            mcpServers = @{
                roboflow = @{ type = 'http' }
            }
            keepMe = 1
        } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $cfg

        Remove-RfMcpServer -ConfigPath $cfg -ServerName 'roboflow'
        $content = Get-Content -LiteralPath $cfg -Raw
        $content | Should -Not -Match 'mcpServers'
        $content | Should -Match 'keepMe'
    }
}
