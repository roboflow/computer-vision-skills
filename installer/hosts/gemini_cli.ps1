<#
gemini_cli.ps1 — install Roboflow MCP into Gemini CLI.
#>

$Script:RfHostId    = 'gemini-cli'
$Script:RfHostLabel = 'Gemini CLI'

function Get-RfGeminiConfigPath {
    return Join-Path $HOME '.gemini/settings.json'
}

function Install-RfHostGeminiCli {
    Write-RfHeader "Configuring Roboflow MCP for $Script:RfHostLabel"
    if (-not $Script:RfDoMcp) {
        Write-RfDim "  MCP disabled by --no-mcp; nothing to do (Gemini CLI has no skills support)"
        return $true
    }
    $configPath = Get-RfGeminiConfigPath
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
    return $true
}

function Uninstall-RfHostGeminiCli {
    Write-RfHeader "Removing Roboflow MCP from $Script:RfHostLabel"
    if (-not $Script:RfDoMcp) { return $true }
    $configPath = Get-RfGeminiConfigPath
    Uninstall-RfMcp -ConfigPath $configPath
    Remove-RfManifestEntry -HostId $Script:RfHostId -Component 'mcp' -Scope $Script:RfOptScope
    return $true
}
