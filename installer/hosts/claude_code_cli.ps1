<#
claude_code_cli.ps1 — install Roboflow into Claude Code via plugin marketplace.

Mirrors the Bash adapter: shell out to `claude plugin marketplace add` +
`claude plugin install`, then patch the cached plugin's .mcp.json to embed
the resolved API key inline. Same plugin install also feeds Claude Code in
Claude Desktop (the Code/CCD tab).
#>

$Script:RfHostId    = 'claude-code-cli'
$Script:RfHostLabel = 'Claude Code'

function Get-RfClaudeCodePluginCacheDir {
    return Join-Path $HOME '.claude/plugins/cache/roboflow/roboflow'
}

function Update-RfClaudeCodePluginCache {
    if (-not $Script:RfApiKey) {
        Write-RfWarn 'no API key resolved — Roboflow MCP will keep ${ROBOFLOW_API_KEY} placeholder'
        Write-RfDim '  set ROBOFLOW_API_KEY in your shell, or re-run with --api-key=<key>'
        return $true
    }

    $cacheDir = Get-RfClaudeCodePluginCacheDir
    if (-not (Test-Path -LiteralPath $cacheDir)) {
        Write-RfWarn "plugin cache not found at $cacheDir"
        return $false
    }

    $patched = 0
    foreach ($dir in (Get-ChildItem -LiteralPath $cacheDir -Directory)) {
        $mcpFile = Join-Path $dir.FullName '.mcp.json'
        if (-not (Test-Path -LiteralPath $mcpFile)) { continue }
        if ($Script:RfOptDryRun) {
            Write-RfInfo "[dry-run] would embed API key in $mcpFile"
            $patched++
            continue
        }

        # Idempotent re-runs detect the literal key already in place and skip.
        # Supports both shapes the plugin's .mcp.json has ever shipped:
        #   stdio (current 0.2+): args[] element of form "x-api-key:<key>"
        #   http  (legacy 0.1.x): headers["x-api-key"] = "<key>"
        $data = Read-RfJsonFile -Path $mcpFile
        if (-not ($data.PSObject.Properties.Name -contains 'mcpServers')) { continue }
        if (-not ($data.mcpServers.PSObject.Properties.Name -contains 'roboflow')) { continue }
        $entry  = $data.mcpServers.roboflow
        $target = 'x-api-key:' + $Script:RfApiKey
        $patchedThis = $false
        $alreadyThis = $false

        # Current shape: stdio + mcp-remote bridge in args[].
        if ($entry.PSObject.Properties.Name -contains 'args' -and $entry.args -is [System.Collections.IList]) {
            $argsArr = @($entry.args)
            for ($i = 0; $i -lt $argsArr.Length; $i++) {
                $a = $argsArr[$i]
                if ($a -is [string] -and $a.StartsWith('x-api-key:')) {
                    if ($a -eq $target) {
                        $alreadyThis = $true
                    } else {
                        $argsArr[$i] = $target
                        $entry.args = $argsArr
                        $patchedThis = $true
                    }
                    break
                }
            }
        }

        # Legacy 0.1.x shape: type:http + headers["x-api-key"].
        if (-not $patchedThis -and -not $alreadyThis -and
            $entry.PSObject.Properties.Name -contains 'headers' -and $entry.headers) {
            if ($entry.headers.PSObject.Properties.Name -contains 'x-api-key') {
                if ($entry.headers.'x-api-key' -eq $Script:RfApiKey) {
                    $alreadyThis = $true
                } else {
                    $entry.headers.'x-api-key' = $Script:RfApiKey
                    $patchedThis = $true
                }
            }
        }

        if ($alreadyThis) {
            Write-RfDim "  already up to date: $mcpFile"
            $patched++
            continue
        }
        if (-not $patchedThis) {
            Write-RfWarn "unrecognized .mcp.json shape in $mcpFile — run \`claude plugin uninstall roboflow\` and re-run agents.ps1 to refresh"
            continue
        }
        if ($entry.PSObject.Properties.Name -contains 'note') {
            $entry.PSObject.Properties.Remove('note')
        }
        Write-RfJsonFile -Path $mcpFile -Object $data
        Write-RfDim "  embedded API key in $mcpFile"
        $patched++
    }

    if ($patched -eq 0) {
        Write-RfWarn "no plugin .mcp.json found to patch under $cacheDir"
    }
    return $true
}

function Install-RfHostClaudeCodeCli {
    Write-RfHeader "Installing Roboflow plugin for $Script:RfHostLabel"

    $claude = Resolve-RfClaudeCliPath
    if (-not $claude) {
        Write-RfErr 'claude not found (PATH or any known install location)'
        Write-RfDim 'Install Claude Code: https://docs.claude.com/claude-code'
        return $false
    }
    if ($claude -ne 'claude' -and -not (Get-Command -Name 'claude' -CommandType Application, ExternalScript -ErrorAction SilentlyContinue)) {
        Write-RfDim "using claude at: $claude (not on PATH)"
    }

    $repo = if ($env:ROBOFLOW_AGENTS_REPO) { $env:ROBOFLOW_AGENTS_REPO } else { 'roboflow/computer-vision-skills' }
    $scopeFlags = @()
    if ($Script:RfOptScope -eq 'project') { $scopeFlags += @('--scope', 'local') }

    if ($Script:RfOptDryRun) {
        Write-RfInfo "[dry-run] would run: claude plugin marketplace add $repo"
        Write-RfInfo ("[dry-run] would run: claude plugin install roboflow {0}" -f ($scopeFlags -join ' '))
        Update-RfClaudeCodePluginCache | Out-Null
        return $true
    }

    Write-RfStep "claude plugin marketplace add $repo"
    & $claude plugin marketplace add $repo 2>&1 | ForEach-Object { Write-Host $_ }
    if ($LASTEXITCODE -ne 0) {
        Write-RfWarn 'marketplace add reported a non-zero exit (may already be registered); continuing'
    }

    Write-RfStep ("claude plugin install roboflow {0}" -f ($scopeFlags -join ' '))
    & $claude plugin install roboflow @scopeFlags 2>&1 | ForEach-Object { Write-Host $_ }
    if ($LASTEXITCODE -ne 0) {
        Write-RfErr 'claude plugin install failed'
        return $false
    }

    # Embed the resolved API key into the cached plugin's .mcp.json so the
    # MCP authenticates without ROBOFLOW_API_KEY needing to be in env.
    Update-RfClaudeCodePluginCache | Out-Null

    $now = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    $apiKeyMode = if ($Script:RfApiKey) { 'inlined' } else { 'placeholder' }
    Add-RfManifestEntry -Entry ([pscustomobject]@{
        host_id           = $Script:RfHostId
        component         = 'plugin'
        scope             = $Script:RfOptScope
        marketplace       = $repo
        plugin_name       = 'roboflow'
        api_key_mode      = $apiKeyMode
        installer_version = $Script:RfInstallerVersion
        installed_at      = $now
        updated_at        = $now
    })

    Write-RfOk "Roboflow plugin installed for $Script:RfHostLabel"
    Write-RfDim 'Also enables Roboflow in the Code tab of Claude Desktop (same plugin system).'
    return $true
}

function Uninstall-RfHostClaudeCodeCli {
    Write-RfHeader "Removing Roboflow plugin from $Script:RfHostLabel"
    $claude = Resolve-RfClaudeCliPath
    if (-not $claude) {
        Write-RfWarn 'claude not found; skipping uninstall (run `claude plugin remove roboflow` manually)'
        return $true
    }
    if ($Script:RfOptDryRun) {
        Write-RfInfo '[dry-run] would run: claude plugin remove roboflow'
        return $true
    }
    & $claude plugin remove roboflow 2>&1 | ForEach-Object { Write-Host $_ }
    if ($LASTEXITCODE -eq 0) {
        Write-RfOk "removed Roboflow plugin from $Script:RfHostLabel"
    } else {
        Write-RfWarn 'claude plugin remove reported a non-zero exit (plugin may not have been installed)'
    }
    Remove-RfManifestEntry -HostId $Script:RfHostId -Component 'plugin' -Scope $Script:RfOptScope
    return $true
}
