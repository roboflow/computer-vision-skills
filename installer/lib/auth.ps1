<#
auth.ps1 — resolve the user's Roboflow API key.

Same precedence as the Bash side:
  1. --api-key=<key>           (Script:RfOptApiKey from main.ps1)
  2. $env:ROBOFLOW_API_KEY
  3. SDK config.json (~/.config/roboflow on mac/linux, ~/roboflow on Windows;
     overridable via $env:ROBOFLOW_CONFIG_DIR)
  4. interactive prompt
#>

function Get-RfSdkConfigDir {
    if ($env:ROBOFLOW_CONFIG_DIR) { return $env:ROBOFLOW_CONFIG_DIR }
    if (Test-RfMacOS -or Test-RfLinux) {
        return Join-Path $HOME '.config/roboflow'
    }
    return Join-Path $HOME 'roboflow'
}

function Get-RfSdkConfigPath {
    return Join-Path (Get-RfSdkConfigDir) 'config.json'
}

function Resolve-RfAuthFromSdkConfig {
    $configPath = Get-RfSdkConfigPath
    if (-not (Test-Path -LiteralPath $configPath)) { return $false }

    $config = Read-RfJsonFile -Path $configPath
    if (-not ($config.PSObject.Properties.Name -contains 'workspaces')) { return $false }
    if ($null -eq $config.workspaces) { return $false }

    $urls = @($config.workspaces.PSObject.Properties.Name)
    if ($urls.Count -eq 0) { return $false }

    $defaultUrl = if ($config.PSObject.Properties.Name -contains 'RF_WORKSPACE') { $config.RF_WORKSPACE } else { $null }

    $targetUrl = ''
    if ($Script:RfOptWorkspace) {
        # Explicit flag wins, no prompt.
        $targetUrl = $Script:RfOptWorkspace
    } elseif ($urls.Count -eq 1) {
        # Single workspace, no prompt.
        $targetUrl = $urls[0]
    } elseif ($Script:RfYes) {
        # Non-interactive: use RF_WORKSPACE default if set, else fail.
        if ($defaultUrl) {
            $targetUrl = $defaultUrl
        } else {
            Write-RfWarn "multiple workspaces in $configPath; pass --workspace=<url> to choose one"
            return $false
        }
    } else {
        # Interactive: always prompt with $defaultUrl as the default selection.
        Write-RfInfo "Multiple Roboflow workspaces found:"
        $i = 1
        $defaultIdx = 1
        foreach ($url in $urls) {
            $ws = $config.workspaces.$url
            $name = if ($ws -and $ws.PSObject.Properties.Name -contains 'name' -and $ws.name) { $ws.name } else { $url }
            $marker = ''
            if ($url -eq $defaultUrl) {
                $marker = '  (default)'
                $defaultIdx = $i
            }
            Write-RfInfo ("  [{0}] {1}{2}" -f $i, $name, $marker)
            Write-RfDim ("      {0}" -f $url)
            $i++
        }
        $choice = Read-RfPrompt -Prompt "Pick workspace [1-$($urls.Count)]:" -Default "$defaultIdx"
        if ($choice -match '^[0-9]+$' -and [int]$choice -ge 1 -and [int]$choice -le $urls.Count) {
            $targetUrl = $urls[[int]$choice - 1]
        } else {
            return $false
        }
    }

    if (-not $targetUrl) { return $false }
    if (-not ($config.workspaces.PSObject.Properties.Name -contains $targetUrl)) {
        Write-RfWarn "workspace not found in SDK config: $targetUrl"
        return $false
    }
    $ws = $config.workspaces.$targetUrl
    if (-not $ws -or -not ($ws.PSObject.Properties.Name -contains 'apiKey') -or -not $ws.apiKey) {
        return $false
    }
    $Script:RfApiKey       = $ws.apiKey
    $Script:RfApiKeySource = "sdk-config:$targetUrl"
    return $true
}

function Resolve-RfAuth {
    $Script:RfApiKey       = ''
    $Script:RfApiKeySource = ''

    if ($Script:RfOptAuthSkip) {
        $Script:RfApiKeySource = 'skipped'
        return
    }
    if ($Script:RfOptApiKey) {
        $Script:RfApiKey       = $Script:RfOptApiKey
        $Script:RfApiKeySource = '--api-key flag'
        return
    }
    if ($env:ROBOFLOW_API_KEY) {
        $Script:RfApiKey       = $env:ROBOFLOW_API_KEY
        $Script:RfApiKeySource = 'ROBOFLOW_API_KEY env'
        return
    }
    if (Resolve-RfAuthFromSdkConfig) { return }

    if ($Script:RfYes) {
        Write-RfWarn "no API key found (env, SDK config, flag); installs will skip auth wiring"
        $Script:RfApiKeySource = 'missing'
        return
    }

    Write-RfInfo "Roboflow MCP authenticates via the ROBOFLOW_API_KEY environment variable."
    Write-RfInfo "Get yours at https://app.roboflow.com/settings/api"
    $key = Read-RfSecret -Prompt "Paste your Roboflow API key (or press Enter to skip)"
    if ($key) {
        $Script:RfApiKey       = $key
        $Script:RfApiKeySource = 'prompt'
    } else {
        $Script:RfApiKeySource = 'skipped'
    }
}

function Show-RfAuthExportHint {
    if (-not $Script:RfApiKey) { return }
    if ($env:ROBOFLOW_API_KEY -eq $Script:RfApiKey) { return }
    Write-RfInfo ""
    Write-RfInfo "Add this to your shell profile so agents can authenticate:"
    if (Test-RfWindows) {
        Write-RfInfo "  setx ROBOFLOW_API_KEY ******** "
    } else {
        Write-RfInfo "  export ROBOFLOW_API_KEY=********"
    }
    Write-RfDim "  (use the key you just provided; we don't echo it back)"
}
