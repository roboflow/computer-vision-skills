<#
windsurf_desktop.ps1 — install Roboflow MCP into Windsurf.
#>

$Script:RfHostId    = 'windsurf-desktop'
$Script:RfHostLabel = 'Windsurf'

function Get-RfWindsurfConfigPath {
    return Join-Path $HOME '.codeium/windsurf/mcp_config.json'
}

function Install-RfHostWindsurfDesktop {
    Write-RfHeader "Configuring Roboflow MCP for $Script:RfHostLabel"
    if (-not $Script:RfDoMcp) {
        Write-RfDim "  MCP disabled by --no-mcp; nothing to do (Windsurf MCP only)"
        return $true
    }
    $configPath = Get-RfWindsurfConfigPath
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
    Write-RfDim "Restart Windsurf for the change to take effect."
    if (-not $env:ROBOFLOW_API_KEY -and -not $Script:RfOptInlineKey) {
        Write-RfDim "Reminder: ROBOFLOW_API_KEY must be in the environment that launches Windsurf."
    }
    return $true
}

function Uninstall-RfHostWindsurfDesktop {
    Write-RfHeader "Removing Roboflow MCP from $Script:RfHostLabel"
    if (-not $Script:RfDoMcp) { return $true }
    $configPath = Get-RfWindsurfConfigPath
    Uninstall-RfMcp -ConfigPath $configPath
    Remove-RfManifestEntry -HostId $Script:RfHostId -Component 'mcp' -Scope $Script:RfOptScope
    return $true
}
