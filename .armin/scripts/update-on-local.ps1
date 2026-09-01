#Requires -Version 5.1
<#
.SYNOPSIS
  Update devmin native stack: refresh deps, keep database, restart API + WebUI.
#>
[CmdletBinding()]
param(
    [string]$ProjectRoot = '',
    [string]$StackName = 'devmin',
    [int]$ApiPort = 8195,
    [int]$WebUiPort = 5195,
    [int]$PostgresPort = 5455
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptDir = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = [System.IO.Path]::GetFullPath((Join-Path $ScriptDir '../..'))
}
$RemoveScript = Join-Path $ScriptDir 'remove-on-local.ps1'

function Write-Step([string]$Message) { Write-Host ">> $Message" -ForegroundColor Cyan }
function Write-Ok([string]$Message) { Write-Host "OK  $Message" -ForegroundColor Green }

try {
    Write-Step 'Stopping API and WebUI for update (keeping Postgres data)'
    & $RemoveScript -ProjectRoot $ProjectRoot -StackName $StackName -PostgresPort $PostgresPort -KeepDatabase
    if ($LASTEXITCODE -ne 0) { throw 'Stop step failed' }

    $InstallScript = Join-Path $ScriptDir 'install-on-local.ps1'
    & $InstallScript -ProjectRoot $ProjectRoot -StackName $StackName -ApiPort $ApiPort -WebUiPort $WebUiPort -PostgresPort $PostgresPort
    if ($LASTEXITCODE -ne 0) { throw 'Install step failed' }
    Write-Ok 'Native update complete (database preserved)'
}
catch {
    Write-Host "ERR $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
