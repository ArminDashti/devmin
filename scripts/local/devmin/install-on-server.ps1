#Requires -Version 5.1
<#
.SYNOPSIS
  Install devmin on bare server (SSH). Creates deploy directory; does not wipe remote data.
#>
[CmdletBinding()]
param(
    [string]$ProjectRoot = '',
    [string]$StackName = 'devmin',
    [string]$Server = 'irancell-t3',
    [string]$Ssh = 'ssh t3',
    [string]$DeployRoot = '/cloud-admin/apps/devmin'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptDir = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = [System.IO.Path]::GetFullPath((Join-Path $ScriptDir '../..'))
}

function Write-Step([string]$Message) { Write-Host ">> $Message" -ForegroundColor Cyan }
function Write-Ok([string]$Message) { Write-Host "OK  $Message" -ForegroundColor Green }

function Invoke-Ssh([string]$RemoteCommand) {
    if ($Ssh.Trim().ToLower().StartsWith('ssh ')) {
        $parts = $Ssh.Trim().Split(' ', 2)
        & $parts[0] $parts[1] $RemoteCommand
    }
    else {
        ssh $Ssh $RemoteCommand
    }
    if ($LASTEXITCODE -ne 0) { throw "Remote command failed: $RemoteCommand" }
}

try {
    Write-Step "Installing $StackName on server $Server at $DeployRoot"
    Invoke-Ssh "mkdir -p '$DeployRoot'"
    Write-Step 'Syncing monorepo to server (excluding node_modules and tmp)'
    if ($Ssh.Trim().ToLower().StartsWith('ssh ')) {
        $alias = ($Ssh.Trim().Split(' ', 2))[1]
        & scp -r -o BatchMode=yes `
            "$ProjectRoot/devmin-api" `
            "$ProjectRoot/devmin-webui" `
            "${alias}:$DeployRoot/"
        & ssh -o BatchMode=yes $alias "mkdir -p '$DeployRoot/.armin'"
        & scp -o BatchMode=yes "$ProjectRoot/.armin/devmin.yaml" "${alias}:$DeployRoot/.armin/devmin.yaml"
    }
    else {
        throw 'Only ssh alias mode is supported for server sync in this script'
    }
    Invoke-Ssh "test -d '$DeployRoot/devmin-api' && test -d '$DeployRoot/devmin-webui'"
    Write-Ok "Server install staged at $DeployRoot (start services separately on server)"
}
catch {
    Write-Host "ERR $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
