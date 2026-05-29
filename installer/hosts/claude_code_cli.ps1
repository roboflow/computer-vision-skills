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

function Get-RfClaudeCodePluginMarketplaceDir {
    # Mirror of the source repo that `claude plugin marketplace add` clones
    # to. Field debugging on a real install showed Claude Code loads the
    # plugin's MCP config from this mirror (with the source's
    # ${ROBOFLOW_API_KEY} placeholder intact), NOT from the cache, so the
    # patcher has to hit both.
    return Join-Path $HOME '.claude/plugins/marketplaces/roboflow'
}

# Try to embed $Script:RfApiKey into a single roboflow MCP entry inside
# the JSON object $Data. Returns a hashtable with keys:
#   Status: 'patched' | 'already' | 'noop' (no roboflow entry / unknown shape)
function Edit-RfRoboflowMcpEntry {
    param([Parameter(Mandatory)] [psobject]$Data)
    if (-not ($Data.PSObject.Properties.Name -contains 'mcpServers')) {
        return @{ Status = 'noop' }
    }
    if (-not ($Data.mcpServers.PSObject.Properties.Name -contains 'roboflow')) {
        return @{ Status = 'noop' }
    }
    $entry  = $Data.mcpServers.roboflow
    $target = 'x-api-key:' + $Script:RfApiKey

    # Current shape: stdio + mcp-remote bridge in args[].
    if ($entry.PSObject.Properties.Name -contains 'args' -and $entry.args -is [System.Collections.IList]) {
        $argsArr = @($entry.args)
        for ($i = 0; $i -lt $argsArr.Length; $i++) {
            $a = $argsArr[$i]
            if ($a -is [string] -and $a.StartsWith('x-api-key:')) {
                if ($a -eq $target) { return @{ Status = 'already' } }
                $argsArr[$i] = $target
                $entry.args = $argsArr
                if ($entry.PSObject.Properties.Name -contains 'note') {
                    $entry.PSObject.Properties.Remove('note')
                }
                return @{ Status = 'patched' }
            }
        }
    }

    # Legacy 0.1.x shape: type:http + headers["x-api-key"].
    if ($entry.PSObject.Properties.Name -contains 'headers' -and $entry.headers) {
        if ($entry.headers.PSObject.Properties.Name -contains 'x-api-key') {
            if ($entry.headers.'x-api-key' -eq $Script:RfApiKey) {
                return @{ Status = 'already' }
            }
            $entry.headers.'x-api-key' = $Script:RfApiKey
            if ($entry.PSObject.Properties.Name -contains 'note') {
                $entry.PSObject.Properties.Remove('note')
            }
            return @{ Status = 'patched' }
        }
    }

    return @{ Status = 'noop' }
}

function Update-RfClaudeCodePluginCache {
    if (-not $Script:RfApiKey) {
        Write-RfWarn 'no API key resolved — Roboflow MCP will keep ${ROBOFLOW_API_KEY} placeholder'
        Write-RfDim '  set ROBOFLOW_API_KEY in your shell, or re-run with --api-key=<key>'
        return $true
    }

    # Walk every .mcp.json under both the cache tree AND the marketplace
    # clone -- Claude Code reads from at least the marketplace mirror when
    # the plugin is enabled, so missing it leaves the placeholder live.
    # Recurse so future layouts that move .mcp.json under .claude-plugin/
    # also get caught.
    $roots = @(
        (Get-RfClaudeCodePluginCacheDir),
        (Get-RfClaudeCodePluginMarketplaceDir)
    )
    $existingRoots = @($roots | Where-Object { Test-Path -LiteralPath $_ })
    if ($existingRoots.Count -eq 0) {
        Write-RfWarn ("plugin cache + marketplace not found under {0}" -f ($roots -join ', '))
        return $false
    }

    $mcpFiles = @()
    foreach ($root in $existingRoots) {
        # -Force so dot-prefixed files (hidden on macOS/Linux) are included;
        # the file is literally .mcp.json so without -Force the recursion
        # silently returns zero matches under HOME on Unix.
        $mcpFiles += @(Get-ChildItem -LiteralPath $root -Recurse -File -Force -Filter '.mcp.json' -ErrorAction SilentlyContinue)
    }
    if ($mcpFiles.Count -eq 0) {
        Write-RfWarn ("no plugin .mcp.json found under: {0}" -f ($existingRoots -join ', '))
        return $true
    }

    $patched = 0
    foreach ($f in $mcpFiles) {
        $mcpFile = $f.FullName
        if ($Script:RfOptDryRun) {
            Write-RfInfo "[dry-run] would embed API key in $mcpFile"
            $patched++
            continue
        }

        $data = Read-RfJsonFile -Path $mcpFile
        $result = Edit-RfRoboflowMcpEntry -Data $data
        switch ($result.Status) {
            'already' {
                Write-RfDim "  already up to date: $mcpFile"
                $patched++
            }
            'patched' {
                Write-RfJsonFile -Path $mcpFile -Object $data
                Write-RfDim "  embedded API key in $mcpFile"
                $patched++
            }
            'noop' {
                # File has no roboflow entry or an unrecognized shape. Skip
                # silently for the no-roboflow case (could be an unrelated
                # plugin's .mcp.json that happens to live under this tree);
                # warn loudly only if the file mentions roboflow at all so
                # users get a signal when their config drifted off-spec.
                $raw = Get-Content -LiteralPath $mcpFile -Raw -ErrorAction SilentlyContinue
                if ($raw -and $raw -match 'roboflow') {
                    Write-RfWarn "unrecognized .mcp.json shape in $mcpFile — run \`claude plugin uninstall roboflow\` and re-run agents.ps1 to refresh"
                }
            }
        }
    }

    if ($patched -eq 0) {
        Write-RfWarn ("no roboflow MCP entry found in any of {0} .mcp.json file(s)" -f $mcpFiles.Count)
    }
    return $true
}

# Write-RfHostShellHintWindows — Claude Code's plugin/git operations on
# Windows shell out to a POSIX-ish environment: it wants either Git for
# Windows (which bundles bash) or PowerShell 7+ (pwsh). Windows PowerShell
# 5.1 alone isn't enough, and claude's own error ("requires either Git for
# Windows (for bash) or PowerShell") is the tell. When `claude plugin
# install` fails on Windows and neither is present, surface the fix instead
# of leaving claude's raw error as the last word. Silent when a shell is
# present (the failure was something else) or off-Windows.
function Write-RfHostShellHintWindows {
    if (-not (Test-RfWindows)) { return }
    if ((Test-RfOnPath 'git') -or (Test-RfOnPath 'pwsh')) { return }
    Write-RfWarn 'Claude Code needs a POSIX shell for plugin/git operations on Windows.'
    Write-RfInfo 'Install one of these, then re-run agents.ps1:'
    Write-RfInfo '  - Git for Windows (bundles bash):  winget install Git.Git'
    Write-RfInfo '  - PowerShell 7+ (pwsh):            winget install Microsoft.PowerShell'
    Write-RfDim '  (claude-desktop chat-tab MCP was configured regardless — it does not need this.)'
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
    $code = Invoke-RfNative -FilePath $claude -Arguments @('plugin', 'marketplace', 'add', $repo)
    if ($code -ne 0) {
        Write-RfWarn 'marketplace add reported a non-zero exit (may already be registered); continuing'
    }

    Write-RfStep ("claude plugin install roboflow {0}" -f ($scopeFlags -join ' '))
    $code = Invoke-RfNative -FilePath $claude -Arguments (@('plugin', 'install', 'roboflow') + $scopeFlags)
    if ($code -ne 0) {
        Write-RfErr 'claude plugin install failed'
        Write-RfHostShellHintWindows
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
    $code = Invoke-RfNative -FilePath $claude -Arguments @('plugin', 'remove', 'roboflow')
    if ($code -eq 0) {
        Write-RfOk "removed Roboflow plugin from $Script:RfHostLabel"
    } else {
        Write-RfWarn 'claude plugin remove reported a non-zero exit (plugin may not have been installed)'
    }
    Remove-RfManifestEntry -HostId $Script:RfHostId -Component 'plugin' -Scope $Script:RfOptScope
    return $true
}
