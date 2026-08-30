#Requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet('Install', 'Uninstall', 'Update', 'Reinstall')]
    [string]$Action = 'Install'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$DeployDir = $PSScriptRoot
$ConfigPath = Join-Path $DeployDir 'run-on-server.yaml'

function Read-FlatYaml([string]$Path) {
    $map = @{}
    foreach ($raw in Get-Content -LiteralPath $Path) {
        $line = $raw.Trim()
        if ($line -eq '' -or $line.StartsWith('#')) { continue }
        if ($line -notmatch '^(?<key>[^:#]+):\s*(?<val>.*)$') { continue }
        $key = $Matches['key'].Trim()
        $val = $Matches['val'].Trim().Trim('"').Trim("'")
        $map[$key] = $val
    }
    return $map
}

$cfg = Read-FlatYaml $ConfigPath
$ssh = $cfg['ssh']
$deployRoot = $cfg['deploy_root']
$stackName = $cfg['stack_name']

if ([string]::IsNullOrWhiteSpace($ssh) -or [string]::IsNullOrWhiteSpace($deployRoot)) {
    throw 'run-on-server.yaml requires ssh and deploy_root'
}

$remoteCmd = switch ($Action) {
    'Uninstall' { "rm -rf '$deployRoot' && echo removed" }
    'Update' { "mkdir -p '$deployRoot' && echo updated" }
    'Reinstall' { "rm -rf '$deployRoot' && mkdir -p '$deployRoot' && echo reinstalled" }
    default { "mkdir -p '$deployRoot' && echo installed" }
}

if ($ssh.Trim().ToLower().StartsWith('ssh ')) {
    $parts = $ssh.Trim().Split(' ')
    & $parts[0] $parts[1] $remoteCmd
}
else {
    ssh $ssh $remoteCmd
}

if ($LASTEXITCODE -ne 0) { throw "server action $Action failed for $stackName" }
