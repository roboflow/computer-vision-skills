<#
mcp.ps1 — write/remove the Roboflow MCP server entry in a host's config.
#>

function Get-RfMcpServerObject {
    param([switch]$Inline)
    $keyValue = '${ROBOFLOW_API_KEY}'
    if ($Inline -and $Script:RfApiKey) {
        $keyValue = $Script:RfApiKey
    }
    return [pscustomobject]@{
        type    = 'http'
        url     = 'https://mcp.roboflow.com/mcp'
        headers = [pscustomobject]@{
            'x-api-key' = $keyValue
            Accept      = 'application/json, text/event-stream'
        }
    }
}

function Install-RfMcp {
    param([Parameter(Mandatory)] [string]$ConfigPath)
    if ($Script:RfOptDryRun) {
        Write-RfInfo "[dry-run] would write Roboflow MCP entry to $ConfigPath"
        return
    }
    if (Test-Path -LiteralPath $ConfigPath) {
        $bak = Backup-RfFile -Path $ConfigPath
        if ($bak) { Write-RfDim "  backup: $bak" }
    }

    $server = Get-RfMcpServerObject -Inline:($Script:RfOptInlineKey)
    Set-RfMcpServer -ConfigPath $ConfigPath -ServerName 'roboflow' -ServerObject $server
    Write-RfOk "wrote Roboflow MCP entry to $ConfigPath"
}

function Uninstall-RfMcp {
    param([Parameter(Mandatory)] [string]$ConfigPath)
    if (-not (Test-Path -LiteralPath $ConfigPath)) {
        Write-RfDim "  ${ConfigPath}: nothing to remove"
        return
    }
    if ($Script:RfOptDryRun) {
        Write-RfInfo "[dry-run] would remove Roboflow MCP entry from $ConfigPath"
        return
    }
    $bak = Backup-RfFile -Path $ConfigPath
    if ($bak) { Write-RfDim "  backup: $bak" }

    Remove-RfMcpServer -ConfigPath $ConfigPath -ServerName 'roboflow'
    Write-RfOk "removed Roboflow MCP entry from $ConfigPath"
}
