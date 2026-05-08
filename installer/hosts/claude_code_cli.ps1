<#
claude_code_cli.ps1 — install Roboflow into Claude Code via plugin marketplace.
Mirrors installer/hosts/claude_code_cli.sh.
#>

$Script:RfHostId    = 'claude-code-cli'
$Script:RfHostLabel = 'Claude Code CLI'

function Install-RfHostClaudeCodeCli {
    Write-RfHeader "Installing Roboflow plugin for $Script:RfHostLabel"

    if (-not (Test-RfOnPath 'claude')) {
        Write-RfErr "claude not found on PATH"
        Write-RfDim "Install Claude Code: https://docs.claude.com/claude-code"
        return $false
    }

    $repo = if ($env:ROBOFLOW_AGENTS_REPO) { $env:ROBOFLOW_AGENTS_REPO } else { 'roboflow/computer-vision-skills' }
    $scopeFlags = @()
    if ($Script:RfOptScope -eq 'project') { $scopeFlags += @('--scope', 'local') }

    if ($Script:RfOptDryRun) {
        Write-RfInfo "[dry-run] would run: claude plugin marketplace add $repo"
        Write-RfInfo ("[dry-run] would run: claude plugin install roboflow {0}" -f ($scopeFlags -join ' '))
        return $true
    }

    Write-RfStep "claude plugin marketplace add $repo"
    & claude plugin marketplace add $repo 2>&1 | ForEach-Object { Write-Host $_ }
    if ($LASTEXITCODE -ne 0) {
        Write-RfWarn "marketplace add reported a non-zero exit (may already be registered); continuing"
    }

    Write-RfStep ("claude plugin install roboflow {0}" -f ($scopeFlags -join ' '))
    & claude plugin install roboflow @scopeFlags 2>&1 | ForEach-Object { Write-Host $_ }
    if ($LASTEXITCODE -ne 0) {
        Write-RfErr "claude plugin install failed"
        return $false
    }

    $now = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    Add-RfManifestEntry -Entry ([pscustomobject]@{
        host_id           = $Script:RfHostId
        component         = 'plugin'
        scope             = $Script:RfOptScope
        marketplace       = $repo
        plugin_name       = 'roboflow'
        installer_version = $Script:RfInstallerVersion
        installed_at      = $now
        updated_at        = $now
    })

    Write-RfOk "Roboflow plugin installed for $Script:RfHostLabel"
    if (-not $env:ROBOFLOW_API_KEY -and $Script:RfApiKey) {
        Write-RfDim "Reminder: export ROBOFLOW_API_KEY in the shell that launches `claude` so the MCP server authenticates."
    }
    return $true
}

function Uninstall-RfHostClaudeCodeCli {
    Write-RfHeader "Removing Roboflow plugin from $Script:RfHostLabel"
    if (-not (Test-RfOnPath 'claude')) {
        Write-RfWarn "claude not on PATH; skipping uninstall (you can run ``claude plugin remove roboflow`` manually)"
        return $true
    }
    if ($Script:RfOptDryRun) {
        Write-RfInfo "[dry-run] would run: claude plugin remove roboflow"
        return $true
    }
    & claude plugin remove roboflow 2>&1 | ForEach-Object { Write-Host $_ }
    if ($LASTEXITCODE -eq 0) {
        Write-RfOk "removed Roboflow plugin from $Script:RfHostLabel"
    } else {
        Write-RfWarn "claude plugin remove reported a non-zero exit (plugin may not have been installed)"
    }
    Remove-RfManifestEntry -HostId $Script:RfHostId -Component 'plugin' -Scope $Script:RfOptScope
    return $true
}
