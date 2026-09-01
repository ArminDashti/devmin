#Requires -Version 5.1
<#
.SYNOPSIS
  Update devmin on bare server: sync latest code without wiping deploy root.
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

$InstallScript = Join-Path $PSScriptRoot 'install-on-server.ps1'

try {
    & $InstallScript -ProjectRoot $ProjectRoot -StackName $StackName -Server $Server -Ssh $Ssh -DeployRoot $DeployRoot
    exit $LASTEXITCODE
}
catch {
    Write-Host "ERR $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
