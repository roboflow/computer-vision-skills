<#
codex_cli.ps1 — register Roboflow as a Codex marketplace source.
Mirrors installer/hosts/codex_cli.sh.
#>

$Script:RfHostId    = 'codex-cli'
$Script:RfHostLabel = 'Codex CLI'

function Install-RfHostCodexCli {
    Write-RfHeader "Registering Roboflow marketplace source for $Script:RfHostLabel"

    if (-not (Test-RfOnPath 'codex')) {
        Write-RfErr "codex not found on PATH"
        Write-RfDim "Install Codex CLI: https://github.com/openai/codex"
        return $false
    }

    $repo = if ($env:ROBOFLOW_AGENTS_REPO) { $env:ROBOFLOW_AGENTS_REPO } else { 'roboflow/computer-vision-skills' }

    if ($Script:RfOptDryRun) {
        Write-RfInfo "[dry-run] would run: codex plugin marketplace add $repo"
        return $true
    }

    Write-RfStep "codex plugin marketplace add $repo"
    & codex plugin marketplace add $repo 2>&1 | ForEach-Object { Write-Host $_ }
    if ($LASTEXITCODE -ne 0) {
        Write-RfWarn "marketplace add reported a non-zero exit (may already be registered); continuing"
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
        manual_step       = 'open Codex, run /plugins, install the Roboflow plugin'
    })

    Write-RfOk "Roboflow marketplace registered for $Script:RfHostLabel"
    Write-RfInfo ""
    Write-RfInfo "Finish installation:"
    Write-RfInfo "  1. Restart Codex (close and reopen)"
    Write-RfInfo "  2. Run /plugins in Codex"
    Write-RfInfo "  3. Pick the Roboflow source, then install the Roboflow plugin"
    Write-RfInfo "  4. Press Space if it shows installed-but-disabled"
    if (-not $env:ROBOFLOW_API_KEY -and $Script:RfApiKey) {
        Write-RfInfo ""
        Write-RfDim "Reminder: export ROBOFLOW_API_KEY in the shell that launches ``codex``."
    }
    return $true
}

function Uninstall-RfHostCodexCli {
    Write-RfHeader "Removing Roboflow from $Script:RfHostLabel"
    if (-not (Test-RfOnPath 'codex')) {
        Write-RfWarn "codex not on PATH; skipping (you can run ``codex plugin marketplace remove roboflow`` manually)"
        return $true
    }
    if ($Script:RfOptDryRun) {
        Write-RfInfo "[dry-run] would run: codex plugin marketplace remove roboflow"
        return $true
    }
    & codex plugin marketplace remove roboflow 2>&1 | ForEach-Object { Write-Host $_ }
    if ($LASTEXITCODE -eq 0) {
        Write-RfOk "removed Roboflow marketplace from $Script:RfHostLabel"
    } else {
        Write-RfWarn "codex plugin marketplace remove reported a non-zero exit (may not have been registered)"
    }
    Write-RfDim "If the plugin itself is still installed, remove it from ``codex /plugins``."
    Remove-RfManifestEntry -HostId $Script:RfHostId -Component 'plugin' -Scope $Script:RfOptScope
    return $true
}
