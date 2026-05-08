<#
skills.ps1 — install Roboflow skill directories into agent skill paths.
PowerShell port of installer/lib/skills.sh.
#>

function Get-RfSkillsSourceDir { return Join-Path $Script:RfRepoDir 'skills' }

function Test-RfSkillsSourceAvailable { return Test-Path -LiteralPath (Get-RfSkillsSourceDir) }

function Get-RfUpstreamSkills {
    $src = Get-RfSkillsSourceDir
    if (-not (Test-Path -LiteralPath $src)) { return @() }
    $names = @()
    foreach ($dir in (Get-ChildItem -LiteralPath $src -Directory)) {
        $skillFile = Join-Path $dir.FullName 'SKILL.md'
        if (Test-Path -LiteralPath $skillFile) { $names += $dir.Name }
    }
    return $names
}

function Get-RfSkillContentHash {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return 'missing' }
    # Sort-stable list of files relative to $Path, excluding the sidecar +
    # platform metadata, then concat (relpath + sha256) and hash again.
    $files = @(Get-ChildItem -LiteralPath $Path -Recurse -File `
        | Where-Object { $_.Name -ne '.roboflow-install-manifest.json' -and $_.Name -ne '.DS_Store' } `
        | ForEach-Object {
            $rel = [System.IO.Path]::GetRelativePath($Path, $_.FullName) -replace '\\', '/'
            [pscustomobject]@{ Rel = $rel; Full = $_.FullName }
        } | Sort-Object Rel)
    $combined = New-Object System.Text.StringBuilder
    foreach ($f in $files) {
        $h = (Get-FileHash -LiteralPath $f.Full -Algorithm SHA256).Hash.ToLower()
        [void]$combined.Append("$($f.Rel) $h`n")
    }
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($combined.ToString())
    $sha = [System.Security.Cryptography.SHA256]::Create().ComputeHash($bytes)
    return ([System.BitConverter]::ToString($sha) -replace '-', '').ToLower()
}

function Get-RfSkillSidecarPath {
    param([string]$Dir)
    return Join-Path $Dir '.roboflow-install-manifest.json'
}

function Write-RfSkillSidecar {
    param(
        [string]$Dest,
        [string]$Skill,
        [string]$HostId,
        [string]$Scope,
        [string]$UpstreamSha,
        [string]$ContentHash
    )
    $now = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    $obj = [pscustomobject]@{
        schema_version    = 1
        skill_name        = $Skill
        host_id           = $HostId
        scope             = $Scope
        upstream_sha      = $UpstreamSha
        content_hash      = "sha256:$ContentHash"
        installer_version = $Script:RfInstallerVersion
        installed_at      = $now
        updated_at        = $now
    }
    Write-RfJsonFile -Path (Get-RfSkillSidecarPath -Dir $Dest) -Object $obj
}

function Test-RfForceSkill {
    param([string]$Name)
    if (-not $Script:RfOptForceSkills) { return $false }
    return ($Script:RfOptForceSkills -contains $Name)
}

function Get-RfDetectedUpstreamSha {
    if ((Get-Command git -ErrorAction SilentlyContinue) -and (Test-Path (Join-Path $Script:RfRepoDir '.git'))) {
        try {
            $sha = (& git -C $Script:RfRepoDir rev-parse HEAD 2>$null).Trim()
            if ($sha) { return $sha }
        } catch { }
    }
    return 'local'
}

function Install-RfSkill {
    param(
        [string]$SkillName,
        [string]$BaseDir,
        [string]$HostId,
        [string]$Scope
    )
    $src = Join-Path (Get-RfSkillsSourceDir) $SkillName
    $dest = Join-Path $BaseDir $SkillName
    $sidecar = Get-RfSkillSidecarPath -Dir $dest

    if (-not (Test-Path -LiteralPath $src)) {
        Write-RfWarn "skill $SkillName not found in source ($src)"
        return $false
    }

    if ($Script:RfOptDryRun) {
        Write-RfInfo "[dry-run] would install skill $SkillName → $dest"
        return $true
    }

    if (Test-Path -LiteralPath $dest) {
        if (Test-Path -LiteralPath $sidecar) {
            $currentHash = Get-RfSkillContentHash -Path $dest
            $manifestHashRaw = (Read-RfJsonFile -Path $sidecar).content_hash
            $manifestHash = if ($manifestHashRaw) { $manifestHashRaw -replace '^sha256:', '' } else { '' }
            if ($manifestHash -and $currentHash -ne $manifestHash -and -not (Test-RfForceSkill -Name $SkillName)) {
                Write-RfWarn "skill $SkillName has local edits; keeping them (run with --force-skill=$SkillName to overwrite)"
                return $true
            }
        } else {
            if (-not (Test-RfForceSkill -Name $SkillName)) {
                Write-RfWarn "$dest exists but has no Roboflow sidecar; not touching it (use --force-skill=$SkillName to overwrite)"
                return $true
            }
        }
    }

    if (-not (Test-Path -LiteralPath $BaseDir)) {
        New-Item -ItemType Directory -Path $BaseDir -Force | Out-Null
    }
    if (Test-Path -LiteralPath $dest) {
        Remove-Item -LiteralPath $dest -Recurse -Force
    }
    Copy-Item -LiteralPath $src -Destination $dest -Recurse -Force

    Get-ChildItem -LiteralPath $dest -Recurse -Force -Filter '.DS_Store' -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue

    $upstreamSha = Get-RfDetectedUpstreamSha
    $contentHash = Get-RfSkillContentHash -Path $dest
    Write-RfSkillSidecar -Dest $dest -Skill $SkillName -HostId $HostId -Scope $Scope -UpstreamSha $upstreamSha -ContentHash $contentHash

    $now = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    $entry = [pscustomobject]@{
        host_id           = $HostId
        component         = 'skill'
        scope             = $Scope
        skill_name        = $SkillName
        skill_path        = $dest
        upstream_sha      = $upstreamSha
        content_hash      = "sha256:$contentHash"
        installer_version = $Script:RfInstallerVersion
        installed_at      = $now
    }
    Add-RfManifestEntry -Entry $entry

    Write-RfOk "installed skill $SkillName → $dest"
    return $true
}

function Install-RfAllSkills {
    param([string]$BaseDir, [string]$HostId, [string]$Scope)
    if (-not (Test-RfSkillsSourceAvailable)) {
        Invoke-RfDie "skills source dir missing: $(Get-RfSkillsSourceDir)"
    }
    foreach ($skill in (Get-RfUpstreamSkills)) {
        Install-RfSkill -SkillName $skill -BaseDir $BaseDir -HostId $HostId -Scope $Scope | Out-Null
    }
    Sync-RfRemovedSkills -BaseDir $BaseDir -HostId $HostId -Scope $Scope
}

function Sync-RfRemovedSkills {
    param([string]$BaseDir, [string]$HostId, [string]$Scope)
    if (-not (Test-Path -LiteralPath $BaseDir)) { return }
    $upstream = @(Get-RfUpstreamSkills)
    foreach ($dir in (Get-ChildItem -LiteralPath $BaseDir -Directory -ErrorAction SilentlyContinue)) {
        $sidecar = Get-RfSkillSidecarPath -Dir $dir.FullName
        if (-not (Test-Path -LiteralPath $sidecar)) { continue }
        if ($upstream -contains $dir.Name) { continue }
        if ($Script:RfOptDryRun) {
            Write-RfInfo "[dry-run] would remove obsolete skill $($dir.Name)"
            continue
        }
        $stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
        $bak = "$($dir.FullName).bak.$stamp"
        Move-Item -LiteralPath $dir.FullName -Destination $bak -Force
        Write-RfWarn "removed obsolete skill $($dir.Name) (backup: $bak)"
        Remove-RfManifestEntry -HostId $HostId -Component 'skill' -Scope $Scope -SkillName $dir.Name
    }
}

function Uninstall-RfAllSkills {
    param([string]$BaseDir, [string]$HostId, [string]$Scope)
    if (-not (Test-Path -LiteralPath $BaseDir)) { return }
    foreach ($dir in (Get-ChildItem -LiteralPath $BaseDir -Directory -ErrorAction SilentlyContinue)) {
        $sidecar = Get-RfSkillSidecarPath -Dir $dir.FullName
        if (-not (Test-Path -LiteralPath $sidecar)) { continue }
        if ($Script:RfOptDryRun) {
            Write-RfInfo "[dry-run] would remove skill $($dir.Name)"
            continue
        }
        $currentHash = Get-RfSkillContentHash -Path $dir.FullName
        $manifestHashRaw = (Read-RfJsonFile -Path $sidecar).content_hash
        $manifestHash = if ($manifestHashRaw) { $manifestHashRaw -replace '^sha256:', '' } else { '' }
        if ($manifestHash -and $currentHash -ne $manifestHash -and -not $Script:RfOptForce) {
            Write-RfWarn "skill $($dir.Name) has local edits; not removing (use --force to override)"
            continue
        }
        $stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
        $bak = "$($dir.FullName).bak.$stamp"
        Move-Item -LiteralPath $dir.FullName -Destination $bak -Force
        Write-RfOk "removed skill $($dir.Name) (backup: $bak)"
        Remove-RfManifestEntry -HostId $HostId -Component 'skill' -Scope $Scope -SkillName $dir.Name
    }
}
