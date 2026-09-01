#Requires -Version 5.1
<#
.SYNOPSIS
  Reinstall devmin on bare server: remove deploy root then install fresh copy.
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

function Write-Step([string]$Message) { Write-Host ">> $Message" -ForegroundColor Cyan }
function Write-Ok([string]$Message) { Write-Host "OK  $Message" -ForegroundColor Green }

try {
    Write-Step 'Reinstall: remote remove'
    & (Join-Path $ScriptDir 'remove-on-server.ps1') -StackName $StackName -Server $Server -Ssh $Ssh -DeployRoot $DeployRoot
    if ($LASTEXITCODE -ne 0) { throw 'Remove step failed' }

    Write-Step 'Reinstall: remote install'
    & (Join-Path $ScriptDir 'install-on-server.ps1') -ProjectRoot $ProjectRoot -StackName $StackName -Server $Server -Ssh $Ssh -DeployRoot $DeployRoot
    if ($LASTEXITCODE -ne 0) { throw 'Install step failed' }
    Write-Ok 'Server reinstall complete'
}
catch {
    Write-Host "ERR $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
