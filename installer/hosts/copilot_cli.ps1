<#
copilot_cli.ps1 — install Roboflow MCP into GitHub Copilot CLI. MCP only.
#>

$Script:RfHostId    = 'copilot-cli'
$Script:RfHostLabel = 'GitHub Copilot CLI'

function Get-RfCopilotConfigPath {
    return Join-Path $HOME '.copilot/mcp-config.json'
}

function Install-RfHostCopilotCli {
    Write-RfHeader "Configuring Roboflow MCP for $Script:RfHostLabel"
    if (-not $Script:RfDoMcp) {
        Write-RfDim "  MCP disabled by --no-mcp; nothing to do (Copilot CLI has no skills support)"
        return $true
    }
    $configPath = Get-RfCopilotConfigPath
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
    if (-not $env:ROBOFLOW_API_KEY -and -not $Script:RfOptInlineKey) {
        Write-RfDim "Reminder: export ROBOFLOW_API_KEY in your shell so Copilot CLI can authenticate against the MCP."
    }
    return $true
}

function Uninstall-RfHostCopilotCli {
    Write-RfHeader "Removing Roboflow MCP from $Script:RfHostLabel"
    if (-not $Script:RfDoMcp) { return $true }
    $configPath = Get-RfCopilotConfigPath
    Uninstall-RfMcp -ConfigPath $configPath
    Remove-RfManifestEntry -HostId $Script:RfHostId -Component 'mcp' -Scope $Script:RfOptScope
    return $true
}
