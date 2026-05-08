<#
opencode_cli.ps1 — install Roboflow MCP into OpenCode CLI.

OpenCode's config at ~/.config/opencode/opencode.json uses an `mcp` container
key (not `mcpServers`) and `type: "remote"` for HTTP-based MCP servers. The
file is technically JSONC; we refuse to edit it if comments are detected
unless --force.
#>

$Script:RfHostId    = 'opencode-cli'
$Script:RfHostLabel = 'OpenCode CLI'

function Get-RfOpencodeConfigPath {
    return Join-Path $HOME '.config/opencode/opencode.json'
}

function Test-RfOpencodeHasComments {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $false }
    $raw = Get-Content -LiteralPath $Path -Raw
    # Strip strings to avoid false positives on URLs / paths.
    $stripped = [regex]::Replace($raw, '"(?:\\.|[^"\\])*"', '')
    return ($stripped -match '//' -or $stripped -match '/\*')
}

function Install-RfHostOpencodeCli {
    Write-RfHeader "Configuring Roboflow MCP for $Script:RfHostLabel"
    if (-not $Script:RfDoMcp) {
        Write-RfDim "  MCP disabled by --no-mcp; nothing to do (OpenCode MCP only)"
        return $true
    }
    $configPath = Get-RfOpencodeConfigPath

    $jsoncPresent = $false
    if (Test-RfOpencodeHasComments -Path $configPath) {
        if (-not $Script:RfOptForce) {
            Write-RfErr "$configPath contains JSONC comments; refusing to overwrite without --force"
            Write-RfDim "Add the Roboflow entry manually, or run with --force to drop comments."
            return $false
        }
        Write-RfWarn "JSONC comments + any non-roboflow content will be lost (--force was passed)"
        $jsoncPresent = $true
    }

    if ($Script:RfOptDryRun) {
        Write-RfInfo "[dry-run] would write Roboflow MCP entry (mcp/remote schema) to $configPath"
        return $true
    }

    Write-RfStep "MCP → $configPath"

    # The existing file isn't parseable JSON when --force overrides JSONC.
    # Back it up and start from empty so the merge succeeds.
    if ($jsoncPresent) {
        Backup-RfFile -Path $configPath | Out-Null
        $dir = Split-Path -Parent $configPath
        if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        Set-Content -LiteralPath $configPath -Value "{}`n"
    }

    Install-RfMcp -ConfigPath $configPath -ContainerKey 'mcp' -Type 'remote'

    if (-not $Script:RfOptDryRun) {
        $now = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
        Add-RfManifestEntry -Entry ([pscustomobject]@{
            host_id           = $Script:RfHostId
            component         = 'mcp'
            scope             = $Script:RfOptScope
            config_path       = $configPath
            server_name       = 'roboflow'
            container_key     = 'mcp'
            installer_version = $Script:RfInstallerVersion
            installed_at      = $now
        })
    }
    Write-RfOk "Roboflow MCP configured for $Script:RfHostLabel"
    if (-not $env:ROBOFLOW_API_KEY -and -not $Script:RfOptInlineKey) {
        Write-RfDim "Reminder: export ROBOFLOW_API_KEY in the shell that launches ``opencode``."
    }
    return $true
}

function Uninstall-RfHostOpencodeCli {
    Write-RfHeader "Removing Roboflow MCP from $Script:RfHostLabel"
    if (-not $Script:RfDoMcp) { return $true }
    $configPath = Get-RfOpencodeConfigPath
    Uninstall-RfMcp -ConfigPath $configPath -ContainerKey 'mcp'
    Remove-RfManifestEntry -HostId $Script:RfHostId -Component 'mcp' -Scope $Script:RfOptScope
    return $true
}
