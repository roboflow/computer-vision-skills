<#
vscode_copilot.ps1 — install Roboflow MCP into VS Code Copilot.

Schema:
  {
    "servers": { "<name>": { ... } },
    "inputs":  [{ "id": ..., "type": "promptString", ... }]
  }

Default project scope writes to .vscode/mcp.json with an inputs[] entry so
VS Code prompts for the API key on first use.
#>

$Script:RfHostId    = 'vscode-copilot'
$Script:RfHostLabel = 'VS Code Copilot'

function Get-RfVscodeConfigPath {
    if ($Script:RfOptScope -eq 'project') {
        $project = if ($Script:RfProjectDir) { $Script:RfProjectDir } else { (Get-Location).Path }
        return Join-Path $project '.vscode/mcp.json'
    }
    if (Test-RfMacOS) {
        return Join-Path $HOME 'Library/Application Support/Code/User/mcp.json'
    } elseif (Test-RfLinux) {
        return Join-Path $HOME '.config/Code/User/mcp.json'
    } else {
        $appdata = if ($env:APPDATA) { $env:APPDATA } else { Join-Path $HOME 'AppData/Roaming' }
        return Join-Path $appdata 'Code/User/mcp.json'
    }
}

function Add-RfVscodeInput {
    param([string]$ConfigPath)
    $inputId = 'roboflow_api_key'
    if (-not (Test-Path -LiteralPath (Split-Path -Parent $ConfigPath))) {
        New-Item -ItemType Directory -Path (Split-Path -Parent $ConfigPath) -Force | Out-Null
    }
    $existing = Read-RfJsonFile -Path $ConfigPath
    if (-not ($existing.PSObject.Properties.Name -contains 'inputs')) {
        $existing | Add-Member -NotePropertyName 'inputs' -NotePropertyValue @()
    } elseif ($null -eq $existing.inputs) {
        $existing.inputs = @()
    }
    $present = $false
    foreach ($i in $existing.inputs) {
        if ($i -and ($i.PSObject.Properties.Name -contains 'id') -and $i.id -eq $inputId) { $present = $true; break }
    }
    if (-not $present) {
        $existing.inputs = @($existing.inputs) + @([pscustomobject]@{
            id          = $inputId
            type        = 'promptString'
            description = 'Roboflow API key (https://app.roboflow.com/settings/api)'
            password    = $true
        })
    }
    Write-RfJsonFile -Path $ConfigPath -Object $existing
    return $inputId
}

function Install-RfHostVscodeCopilot {
    Write-RfHeader "Configuring Roboflow MCP for $Script:RfHostLabel"
    if (-not $Script:RfDoMcp) {
        Write-RfDim "  MCP disabled by --no-mcp; nothing to do (VS Code Copilot has no skills support)"
        return $true
    }
    $configPath = Get-RfVscodeConfigPath

    if ($Script:RfOptDryRun) {
        Write-RfInfo "[dry-run] would write Roboflow MCP entry (servers/inputs schema) to $configPath"
        return $true
    }

    Write-RfStep "MCP → $configPath"

    $inputId = Add-RfVscodeInput -ConfigPath $configPath

    $keyValue = '${input:' + $inputId + '}'
    if ($Script:RfOptInlineKey -and $Script:RfApiKey) {
        Write-RfWarn "--inline-key with vscode-copilot embeds the literal key in .vscode/mcp.json (project files are commit-able — make sure that's intentional)"
        $keyValue = $Script:RfApiKey
    }
    Install-RfMcp -ConfigPath $configPath -ContainerKey 'servers' -KeyValue $keyValue

    if (-not $Script:RfOptDryRun) {
        $now = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
        Add-RfManifestEntry -Entry ([pscustomobject]@{
            host_id           = $Script:RfHostId
            component         = 'mcp'
            scope             = $Script:RfOptScope
            config_path       = $configPath
            server_name       = 'roboflow'
            container_key     = 'servers'
            input_id          = $inputId
            installer_version = $Script:RfInstallerVersion
            installed_at      = $now
        })
    }
    Write-RfDim "VS Code will prompt you for the API key when you first use Roboflow MCP."
    return $true
}

function Uninstall-RfHostVscodeCopilot {
    Write-RfHeader "Removing Roboflow MCP from $Script:RfHostLabel"
    if (-not $Script:RfDoMcp) { return $true }
    $configPath = Get-RfVscodeConfigPath
    Uninstall-RfMcp -ConfigPath $configPath -ContainerKey 'servers'

    # Drop the inputs[] entry too (best-effort).
    if (Test-Path -LiteralPath $configPath) {
        $existing = Read-RfJsonFile -Path $configPath
        if (($existing.PSObject.Properties.Name -contains 'inputs') -and $existing.inputs) {
            $kept = @()
            foreach ($i in $existing.inputs) {
                if ($i -and $i.PSObject.Properties.Name -contains 'id' -and $i.id -eq 'roboflow_api_key') { continue }
                $kept += $i
            }
            if ($kept.Count -eq 0) {
                $existing.PSObject.Properties.Remove('inputs')
            } else {
                $existing.inputs = $kept
            }
            Write-RfJsonFile -Path $configPath -Object $existing
        }
    }
    Remove-RfManifestEntry -HostId $Script:RfHostId -Component 'mcp' -Scope $Script:RfOptScope
    return $true
}
