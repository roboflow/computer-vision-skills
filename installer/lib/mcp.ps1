<#
mcp.ps1 — write/remove the Roboflow MCP server entry in a host's config.
#>

function Get-RfMcpServerObject {
    param(
        [switch]$Inline,
        # Server type — most hosts want "http"; OpenCode wants "remote".
        [string]$Type = 'http',
        # Override the api-key value entirely (e.g. "${input:roboflow_api_key}"
        # for VS Code Copilot's prompt-string mechanism). Wins over -Inline.
        [string]$KeyValue = ''
    )
    if ($KeyValue) {
        $keyToUse = $KeyValue
    } elseif ($Inline -and $Script:RfApiKey) {
        $keyToUse = $Script:RfApiKey
    } else {
        $keyToUse = '${ROBOFLOW_API_KEY}'
    }
    return [pscustomobject]@{
        type    = $Type
        url     = 'https://mcp.roboflow.com/mcp'
        headers = [pscustomobject]@{
            'x-api-key' = $keyToUse
            Accept      = 'application/json, text/event-stream'
        }
    }
}

function Install-RfMcp {
    param(
        [Parameter(Mandatory)] [string]$ConfigPath,
        # Where to put the server inside the config. mcpServers (default) /
        # servers / mcp.
        [string]$ContainerKey = 'mcpServers',
        # Pass-through to Get-RfMcpServerObject.
        [string]$Type = 'http',
        [string]$KeyValue = ''
    )
    if ($Script:RfOptDryRun) {
        Write-RfInfo "[dry-run] would write Roboflow MCP entry to $ConfigPath"
        return
    }
    if (Test-Path -LiteralPath $ConfigPath) {
        $bak = Backup-RfFile -Path $ConfigPath
        if ($bak) { Write-RfDim "  backup: $bak" }
    }

    $server = Get-RfMcpServerObject -Inline:($Script:RfOptInlineKey) -Type $Type -KeyValue $KeyValue
    Set-RfMcpServer -ConfigPath $ConfigPath -ServerName 'roboflow' -ServerObject $server -ContainerKey $ContainerKey
    Write-RfOk "wrote Roboflow MCP entry to $ConfigPath"
}

function Uninstall-RfMcp {
    param(
        [Parameter(Mandatory)] [string]$ConfigPath,
        [string]$ContainerKey = 'mcpServers'
    )
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

    Remove-RfMcpServer -ConfigPath $ConfigPath -ServerName 'roboflow' -ContainerKey $ContainerKey
    Write-RfOk "removed Roboflow MCP entry from $ConfigPath"
}
