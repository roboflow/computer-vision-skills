<#
manifest.ps1 — read/write the Roboflow installer manifest at
$ROBOFLOW_CONFIG_DIR/installations.json (mirrors the Bash side).
#>

$Script:RfInstallerVersion = '0.1.0'

function Get-RfManifestPath {
    return Join-Path (Get-RfSdkConfigDir) 'installations.json'
}

function Initialize-RfManifest {
    $path = Get-RfManifestPath
    if (Test-Path -LiteralPath $path) { return }
    $obj = [pscustomobject]@{
        schema_version    = 1
        installer_version = $Script:RfInstallerVersion
        installations     = @()
    }
    Write-RfJsonFile -Path $path -Object $obj
    if ((Test-RfLinux) -or (Test-RfMacOS)) {
        try { & chmod 600 $path 2>$null } catch { }
    }
}

function Add-RfManifestEntry {
    param([Parameter(Mandatory)] $Entry)
    Initialize-RfManifest
    $path = Get-RfManifestPath
    $obj  = Read-RfJsonFile -Path $path

    if (-not ($obj.PSObject.Properties.Name -contains 'installations')) {
        $obj | Add-Member -NotePropertyName 'installations' -NotePropertyValue @()
    }

    # Match key: host_id + component + scope + skill_name (skill_name is null
    # for non-skill entries — that's how plugin/mcp entries dedupe correctly).
    $newKey = @(
        ($Entry.host_id),
        ($Entry.component),
        ($(if ($Entry.PSObject.Properties.Name -contains 'scope' -and $Entry.scope) { $Entry.scope } else { 'global' })),
        ($(if ($Entry.PSObject.Properties.Name -contains 'skill_name') { $Entry.skill_name } else { $null }))
    )
    $kept = @()
    foreach ($item in $obj.installations) {
        $itemKey = @(
            ($item.host_id),
            ($item.component),
            ($(if ($item.PSObject.Properties.Name -contains 'scope' -and $item.scope) { $item.scope } else { 'global' })),
            ($(if ($item.PSObject.Properties.Name -contains 'skill_name') { $item.skill_name } else { $null }))
        )
        $same = $true
        for ($i = 0; $i -lt $newKey.Count; $i++) {
            if ($itemKey[$i] -ne $newKey[$i]) { $same = $false; break }
        }
        if (-not $same) { $kept += $item }
    }
    $kept += $Entry
    $obj.installations = $kept
    if ($Entry.PSObject.Properties.Name -contains 'installer_version' -and $Entry.installer_version) {
        $obj.installer_version = $Entry.installer_version
    }
    Write-RfJsonFile -Path $path -Object $obj
}

function Remove-RfManifestEntry {
    param(
        [Parameter(Mandatory)] [string]$HostId,
        [Parameter(Mandatory)] [string]$Component,
        [string]$Scope = 'global',
        [string]$SkillName = ''
    )
    $path = Get-RfManifestPath
    if (-not (Test-Path -LiteralPath $path)) { return }
    $obj = Read-RfJsonFile -Path $path
    if (-not ($obj.PSObject.Properties.Name -contains 'installations')) { return }
    $kept = @()
    foreach ($item in $obj.installations) {
        $itemScope = if ($item.PSObject.Properties.Name -contains 'scope' -and $item.scope) { $item.scope } else { 'global' }
        $itemSkill = if ($item.PSObject.Properties.Name -contains 'skill_name' -and $item.skill_name) { $item.skill_name } else { '' }
        if ($item.host_id -eq $HostId -and
            $item.component -eq $Component -and
            $itemScope -eq $Scope -and
            $itemSkill -eq $SkillName) {
            continue
        }
        $kept += $item
    }
    $obj.installations = $kept
    Write-RfJsonFile -Path $path -Object $obj
}

function Get-RfManifestList {
    param([string]$HostId = '')
    $path = Get-RfManifestPath
    if (-not (Test-Path -LiteralPath $path)) { return @() }
    $obj = Read-RfJsonFile -Path $path
    if (-not ($obj.PSObject.Properties.Name -contains 'installations')) { return @() }
    $items = @($obj.installations)
    if ($HostId) {
        $items = @($items | Where-Object { $_.host_id -eq $HostId })
    }
    return $items
}
