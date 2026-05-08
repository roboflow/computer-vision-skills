<#
claude_desktop.ps1 — install Roboflow MCP into Claude Desktop.
MCP only; Claude Desktop does not consume SKILL.md files.
#>

$Script:RfHostId    = 'claude-desktop'
$Script:RfHostLabel = 'Claude Desktop'

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

function Install-RfHostClaudeDesktop {
    Write-RfHeader "Configuring Roboflow MCP for $Script:RfHostLabel"
    if (-not $Script:RfDoMcp) {
        Write-RfDim "  MCP disabled by --no-mcp; nothing to do (Claude Desktop has no skills support)"
        return $true
    }
    $configPath = Get-RfClaudeDesktopConfigPath
    Write-RfStep "MCP → $configPath"
    Install-RfMcp -ConfigPath $configPath
    if (-not $Script:RfOptDryRun) {
        $now = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
        Add-RfManifestEntry -Entry ([pscustomobject]@{
            host_id           = $Script:RfHostId
            component         = 'mcp'
            scope             = $Script:RfOptScope
            config_path       = $configPath
            server_name       = 'roboflow'
            installer_version = $Script:RfInstallerVersion
            installed_at      = $now
        })
    }
    Write-RfOk "Roboflow MCP configured for $Script:RfHostLabel"
    Write-RfDim "Restart Claude Desktop for the change to take effect."
    if (-not $env:ROBOFLOW_API_KEY -and -not $Script:RfOptInlineKey) {
        Write-RfDim "Reminder: ROBOFLOW_API_KEY must be exported in the launchd / shell environment Claude Desktop inherits."
    }
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
