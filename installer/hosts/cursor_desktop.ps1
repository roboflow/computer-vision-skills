<#
cursor_desktop.ps1 — install Roboflow into Cursor (config-file path).
#>

$Script:RfHostId    = 'cursor-desktop'
$Script:RfHostLabel = 'Cursor'

function Get-RfCursorMcpPath {
    if ($Script:RfOptScope -eq 'project') {
        $project = if ($Script:RfProjectDir) { $Script:RfProjectDir } else { (Get-Location).Path }
        return Join-Path $project '.cursor/mcp.json'
    }
    return Join-Path $HOME '.cursor/mcp.json'
}

function Get-RfCursorSkillsDir {
    if ($Script:RfOptScope -eq 'project') {
        $project = if ($Script:RfProjectDir) { $Script:RfProjectDir } else { (Get-Location).Path }
        return Join-Path $project '.claude/skills'
    }
    return Join-Path $HOME '.claude/skills'
}

function Install-RfHostCursorDesktop {
    Write-RfHeader "Configuring Roboflow for $Script:RfHostLabel"

    $mcpPath    = Get-RfCursorMcpPath
    $skillsDir  = Get-RfCursorSkillsDir
    $now        = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')

    if ($Script:RfDoMcp) {
        Write-RfStep "MCP → $mcpPath"
        Install-RfMcp -ConfigPath $mcpPath
        if (-not $Script:RfOptDryRun) {
            Add-RfManifestEntry -Entry ([pscustomobject]@{
                host_id           = $Script:RfHostId
                component         = 'mcp'
                scope             = $Script:RfOptScope
                config_path       = $mcpPath
                server_name       = 'roboflow'
                installer_version = $Script:RfInstallerVersion
                installed_at      = $now
            })
        }
    }

    if ($Script:RfDoSkills) {
        Write-RfStep "Skills → $skillsDir"
        Install-RfAllSkills -BaseDir $skillsDir -HostId $Script:RfHostId -Scope $Script:RfOptScope
    }

    if ($Script:RfDoRules -and $Script:RfOptScope -eq 'project') {
        $project  = if ($Script:RfProjectDir) { $Script:RfProjectDir } else { (Get-Location).Path }
        $rulePath = Join-Path $project '.cursor/rules/roboflow.mdc'
        Write-RfStep "Rules → $rulePath"
        Install-RfCursorMdc -Target $rulePath | Out-Null
        if (-not $Script:RfOptDryRun) {
            Add-RfManifestEntry -Entry ([pscustomobject]@{
                host_id           = $Script:RfHostId
                component         = 'rules'
                scope             = $Script:RfOptScope
                config_path       = $rulePath
                installer_version = $Script:RfInstallerVersion
                installed_at      = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
            })
        }
    }

    Write-RfOk "Roboflow configured for $Script:RfHostLabel"
    return $true
}

function Uninstall-RfHostCursorDesktop {
    Write-RfHeader "Removing Roboflow from $Script:RfHostLabel"
    $mcpPath    = Get-RfCursorMcpPath
    $skillsDir  = Get-RfCursorSkillsDir
    if ($Script:RfDoMcp) {
        Uninstall-RfMcp -ConfigPath $mcpPath
        Remove-RfManifestEntry -HostId $Script:RfHostId -Component 'mcp' -Scope $Script:RfOptScope
    }
    if ($Script:RfDoSkills) {
        Uninstall-RfAllSkills -BaseDir $skillsDir -HostId $Script:RfHostId -Scope $Script:RfOptScope
    }
    if ($Script:RfDoRules -and $Script:RfOptScope -eq 'project') {
        $project  = if ($Script:RfProjectDir) { $Script:RfProjectDir } else { (Get-Location).Path }
        Uninstall-RfCursorMdc -Target (Join-Path $project '.cursor/rules/roboflow.mdc') | Out-Null
        Remove-RfManifestEntry -HostId $Script:RfHostId -Component 'rules' -Scope $Script:RfOptScope
    }
    return $true
}
