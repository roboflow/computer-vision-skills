<#
json_io.ps1 — PowerShell-native JSON I/O.

PowerShell 5+ ships ConvertFrom-Json / ConvertTo-Json, so unlike the Bash side
we don't need a python3/jq fallback. Helpers preserve unrelated keys when
merging, just like the Bash counterparts.
#>

function Read-RfJsonFile {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        return [pscustomobject]@{}
    }
    $raw = Get-Content -LiteralPath $Path -Raw
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return [pscustomobject]@{}
    }
    return $raw | ConvertFrom-Json
}

function Write-RfJsonFile {
    param([string]$Path, $Object)
    $json = $Object | ConvertTo-Json -Depth 64
    # ConvertTo-Json doesn't add a trailing newline; add one for git-friendliness.
    Set-RfFileContent -Path $Path -Content "$json`n"
}

function Set-RfMcpServer {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$ConfigPath,
        [Parameter(Mandatory)] [string]$ServerName,
        [Parameter(Mandatory)] $ServerObject
    )
    $existing = Read-RfJsonFile -Path $ConfigPath

    # Ensure mcpServers exists as an object
    if (-not ($existing.PSObject.Properties.Name -contains 'mcpServers')) {
        $existing | Add-Member -NotePropertyName 'mcpServers' -NotePropertyValue ([pscustomobject]@{})
    } elseif ($null -eq $existing.mcpServers) {
        $existing.mcpServers = [pscustomobject]@{}
    }

    # Replace-or-add the server entry without disturbing other servers.
    if ($existing.mcpServers.PSObject.Properties.Name -contains $ServerName) {
        $existing.mcpServers.$ServerName = $ServerObject
    } else {
        $existing.mcpServers | Add-Member -NotePropertyName $ServerName -NotePropertyValue $ServerObject
    }

    Write-RfJsonFile -Path $ConfigPath -Object $existing
}

function Remove-RfMcpServer {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$ConfigPath,
        [Parameter(Mandatory)] [string]$ServerName
    )
    if (-not (Test-Path -LiteralPath $ConfigPath)) { return }
    $existing = Read-RfJsonFile -Path $ConfigPath
    if (-not ($existing.PSObject.Properties.Name -contains 'mcpServers')) { return }
    if ($null -eq $existing.mcpServers) { return }
    if ($existing.mcpServers.PSObject.Properties.Name -contains $ServerName) {
        $existing.mcpServers.PSObject.Properties.Remove($ServerName)
    }
    # If empty, drop the mcpServers key altogether to keep the file tidy.
    # `.Properties` is an enumerator; force materialization with @(...) and
    # filter out any null entries that the empty enumeration may surface as.
    $remaining = @($existing.mcpServers.PSObject.Properties | Where-Object { $_ })
    if ($remaining.Count -eq 0) {
        $existing.PSObject.Properties.Remove('mcpServers')
    }
    Write-RfJsonFile -Path $ConfigPath -Object $existing
}

# Get-RfJsonField — read a dotted path. URL-key-safe: pass keys that contain
# dots/slashes via Get-RfJsonValue with explicit key list instead.
function Get-RfJsonField {
    param([string]$Path, [string]$Field)
    $obj = Read-RfJsonFile -Path $Path
    $parts = $Field.TrimStart('.').Split('.', [System.StringSplitOptions]::RemoveEmptyEntries)
    foreach ($p in $parts) {
        if ($null -eq $obj) { return $null }
        if ($obj.PSObject.Properties.Name -notcontains $p) { return $null }
        $obj = $obj.$p
    }
    return $obj
}

# Get-RfJsonValue — fetch the value at the given key path. Each $Keys entry is
# a literal property name (URL-safe).
function Get-RfJsonValue {
    param([string]$Path, [string[]]$Keys)
    $obj = Read-RfJsonFile -Path $Path
    foreach ($k in $Keys) {
        if ($null -eq $obj) { return $null }
        if ($obj.PSObject.Properties.Name -notcontains $k) { return $null }
        $obj = $obj.$k
    }
    return $obj
}

function Get-RfJsonKeys {
    param([string]$Path, [string]$Field = '')
    $obj = Read-RfJsonFile -Path $Path
    if ($Field) {
        $parts = $Field.TrimStart('.').Split('.', [System.StringSplitOptions]::RemoveEmptyEntries)
        foreach ($p in $parts) {
            if ($null -eq $obj) { return @() }
            if ($obj.PSObject.Properties.Name -notcontains $p) { return @() }
            $obj = $obj.$p
        }
    }
    if ($null -eq $obj) { return @() }
    return @($obj.PSObject.Properties.Name)
}
