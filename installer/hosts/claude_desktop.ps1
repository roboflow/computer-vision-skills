<#
claude_desktop.ps1 — install Roboflow MCP into Claude Desktop's chat tab.

Claude Desktop's claude_desktop_config.json schema only accepts stdio MCPs
({command, args, env, extensionId} per its bundled validator). To run an HTTP
MCP from the chat tab we bridge through the npm package `mcp-remote`, which
requires Node + npx on PATH and inlines the literal API key.

Note: this only configures the chat tab. The Code tab (Claude Code in Claude
Desktop) reads the Claude Code plugin system, which is covered by the
claude-code-cli host without any bridge or Node dependency.
#>

$Script:RfHostId    = 'claude-desktop'
$Script:RfHostLabel = 'Claude Desktop'

# Pinned version of the bridge so behavior is reproducible across installs.
$Script:RfMcpRemoteVersion = '0.1.27'

function Get-RfClaudeDesktopConfigPath {
    if (Test-RfMacOS) {
        return Join-Path $HOME 'Library/Application Support/Claude/claude_desktop_config.json'
    } elseif (Test-RfLinux) {
        return Join-Path $HOME '.config/Claude/claude_desktop_config.json'
    } else {
        $appdata = if ($env:APPDATA) { $env:APPDATA } else { Join-Path $HOME 'AppData/Roaming' }
        return Join-Path $appdata 'Claude/claude_desktop_config.json'
    }
}

function Get-RfClaudeDesktopBridgeServer {
    param([Parameter(Mandatory)] [string]$Key)
    return [pscustomobject]@{
        command = 'npx'
        args    = @(
            '-y',
            ("mcp-remote@" + $Script:RfMcpRemoteVersion),
            'https://mcp.roboflow.com/mcp',
            '--header',
            ("x-api-key:" + $Key)
        )
    }
}

function Install-RfHostClaudeDesktop {
    Write-RfHeader "Configuring Roboflow MCP for $Script:RfHostLabel (chat tab)"
    if (-not $Script:RfDoMcp) {
        Write-RfDim '  MCP disabled by --no-mcp; nothing to do (Claude Desktop has no skills support)'
        return $true
    }

    if (-not (Test-RfOnPath 'npx')) {
        Write-RfErr "npx (Node.js) is required for Claude Desktop's chat tab MCP bridge"
        Write-RfDim 'Install Node.js: https://nodejs.org — then re-run agents.ps1.'
        Write-RfDim 'If you only need Roboflow in Claude Code (CLI / Claude Desktop''s Code tab),'
        Write-RfDim 'use --host=claude-code-cli — that path doesn''t need Node.'
        return $false
    }

    if (-not $Script:RfApiKey) {
        Write-RfErr "Claude Desktop's chat tab needs a literal API key (it doesn't expand env vars in MCP args)."
        Write-RfDim 'Re-run with --api-key=<key>, set ROBOFLOW_API_KEY, or skip with --auth-skip / --no-mcp.'
        return $false
    }

    $configPath = Get-RfClaudeDesktopConfigPath

    if ($Script:RfOptDryRun) {
        Write-RfInfo "[dry-run] would write Roboflow MCP (mcp-remote stdio bridge) to $configPath"
        return $true
    }

    Write-RfStep "MCP → $configPath"
    if (Test-Path -LiteralPath $configPath) {
        $bak = Backup-RfFile -Path $configPath
        if ($bak) { Write-RfDim "  backup: $bak" }
    }
    $server = Get-RfClaudeDesktopBridgeServer -Key $Script:RfApiKey
    Set-RfMcpServer -ConfigPath $configPath -ServerName 'roboflow' -ServerObject $server
    Write-RfOk "wrote Roboflow MCP entry (mcp-remote@$Script:RfMcpRemoteVersion bridge) to $configPath"
    Write-RfDim 'Restart Claude Desktop for the change to take effect.'

    $now = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    Add-RfManifestEntry -Entry ([pscustomobject]@{
        host_id           = $Script:RfHostId
        component         = 'mcp'
        scope             = $Script:RfOptScope
        config_path       = $configPath
        server_name       = 'roboflow'
        transport         = 'stdio-bridge'
        bridge            = "mcp-remote@$Script:RfMcpRemoteVersion"
        api_key_mode      = 'inlined'
        installer_version = $Script:RfInstallerVersion
        installed_at      = $now
    })
    return $true
}

function Uninstall-RfHostClaudeDesktop {
    Write-RfHeader "Removing Roboflow MCP from $Script:RfHostLabel"
    if (-not $Script:RfDoMcp) { return $true }
    $configPath = Get-RfClaudeDesktopConfigPath
    Uninstall-RfMcp -ConfigPath $configPath
    Remove-RfManifestEntry -HostId $Script:RfHostId -Component 'mcp' -Scope $Script:RfOptScope
    return $true
}
