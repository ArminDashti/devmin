#Requires -Version 5.1
<#
.SYNOPSIS
  Remove devmin from bare server: deletes deploy directory and remote app data.
#>
[CmdletBinding()]
param(
    [string]$StackName = 'devmin',
    [string]$Server = 'irancell-t3',
    [string]$Ssh = 'ssh t3',
    [string]$DeployRoot = '/cloud-admin/apps/devmin'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

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
    Write-Step "Removing $StackName from server $Server ($DeployRoot)"
    Invoke-Ssh "rm -rf '$DeployRoot'"
    Write-Ok 'Server remove complete'
}
catch {
    Write-Host "ERR $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
