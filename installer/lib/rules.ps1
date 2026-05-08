<#
rules.ps1 — install / remove a Roboflow managed block in a markdown rules file.
PowerShell port of installer/lib/rules.sh.
#>

$Script:RfRulesBeginMarker = '<!-- BEGIN ROBOFLOW -->'
$Script:RfRulesEndMarker   = '<!-- END ROBOFLOW -->'

function Get-RfRulesTemplatePath {
    param([Parameter(Mandatory)] [string]$Flavor)
    switch ($Flavor) {
        'claude' { return Join-Path $Script:RfRepoDir 'templates/rules/CLAUDE.roboflow.md' }
        'agents' { return Join-Path $Script:RfRepoDir 'templates/rules/AGENTS.roboflow.md' }
        'gemini' { return Join-Path $Script:RfRepoDir 'templates/rules/GEMINI.roboflow.md' }
        'cursor' { return Join-Path $Script:RfRepoDir 'templates/rules/cursor-roboflow.mdc' }
        default { throw "unknown rules flavor: $Flavor" }
    }
}

function Install-RfRulesManagedBlock {
    param(
        [Parameter(Mandatory)] [string]$Target,
        [Parameter(Mandatory)] [string]$Flavor
    )
    $tpl = Get-RfRulesTemplatePath -Flavor $Flavor
    if (-not (Test-Path -LiteralPath $tpl)) {
        Write-RfWarn "rules template not found: $tpl"
        return $false
    }
    if ($Script:RfOptDryRun) {
        Write-RfInfo "[dry-run] would update Roboflow managed block in $Target"
        return $true
    }

    $dir = Split-Path -Parent $Target
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    $body = Get-Content -LiteralPath $tpl -Raw
    $body = $body.TrimEnd("`r", "`n")
    $newBlock = "$Script:RfRulesBeginMarker`n$body`n$Script:RfRulesEndMarker"

    if (Test-Path -LiteralPath $Target) {
        Backup-RfFile -Path $Target | Out-Null
        $existing = Get-Content -LiteralPath $Target -Raw
        if ($existing -match [regex]::Escape($Script:RfRulesBeginMarker)) {
            # Replace existing block.
            $pattern = [regex]::Escape($Script:RfRulesBeginMarker) + '.*?' + [regex]::Escape($Script:RfRulesEndMarker)
            $updated = [regex]::Replace($existing, $pattern, $newBlock, [System.Text.RegularExpressions.RegexOptions]::Singleline)
        } else {
            # Append a new block.
            $existingTrimmed = $existing.TrimEnd("`r", "`n")
            $updated = "$existingTrimmed`n`n$newBlock`n"
        }
        Set-RfFileContent -Path $Target -Content $updated
    } else {
        Set-RfFileContent -Path $Target -Content "$newBlock`n"
    }
    Write-RfOk "wrote Roboflow managed block to $Target"
    return $true
}

function Install-RfCursorMdc {
    param([Parameter(Mandatory)] [string]$Target)
    $tpl = Get-RfRulesTemplatePath -Flavor 'cursor'
    if (-not (Test-Path -LiteralPath $tpl)) {
        Write-RfWarn "rules template not found: $tpl"
        return $false
    }
    if ($Script:RfOptDryRun) {
        Write-RfInfo "[dry-run] would write Cursor rule file at $Target"
        return $true
    }
    $dir = Split-Path -Parent $Target
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    if (Test-Path -LiteralPath $Target) { Backup-RfFile -Path $Target | Out-Null }
    Copy-Item -LiteralPath $tpl -Destination $Target -Force
    Write-RfOk "wrote Cursor rule file at $Target"
    return $true
}

function Uninstall-RfRulesManagedBlock {
    param([Parameter(Mandatory)] [string]$Target)
    if (-not (Test-Path -LiteralPath $Target)) { return $true }
    if ($Script:RfOptDryRun) {
        Write-RfInfo "[dry-run] would strip Roboflow managed block from $Target"
        return $true
    }
    Backup-RfFile -Path $Target | Out-Null

    $existing = Get-Content -LiteralPath $Target -Raw
    $pattern = '\n*' + [regex]::Escape($Script:RfRulesBeginMarker) + '.*?' + [regex]::Escape($Script:RfRulesEndMarker) + '\n*'
    $updated = [regex]::Replace($existing, $pattern, "`n", [System.Text.RegularExpressions.RegexOptions]::Singleline)
    $updated = $updated.Trim("`r", "`n")
    if ($updated) { $updated += "`n" }

    if ([string]::IsNullOrWhiteSpace($updated)) {
        Remove-Item -LiteralPath $Target -Force
        Write-RfOk "removed empty $Target"
    } else {
        Set-RfFileContent -Path $Target -Content $updated
        Write-RfOk "stripped Roboflow managed block from $Target"
    }
    return $true
}

function Uninstall-RfCursorMdc {
    param([Parameter(Mandatory)] [string]$Target)
    if (-not (Test-Path -LiteralPath $Target)) { return $true }
    if ($Script:RfOptDryRun) {
        Write-RfInfo "[dry-run] would remove $Target"
        return $true
    }
    Backup-RfFile -Path $Target | Out-Null
    Remove-Item -LiteralPath $Target -Force
    Write-RfOk "removed $Target"
    return $true
}
