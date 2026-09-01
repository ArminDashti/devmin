#Requires -Version 5.1
<#
.SYNOPSIS
  Reinstall devmin native stack: full remove (including DB) then fresh install.
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

function Write-Step([string]$Message) { Write-Host ">> $Message" -ForegroundColor Cyan }
function Write-Ok([string]$Message) { Write-Host "OK  $Message" -ForegroundColor Green }

try {
    Write-Step 'Reinstall: remove with database wipe'
    & (Join-Path $ScriptDir 'remove-on-local.ps1') -ProjectRoot $ProjectRoot -StackName $StackName -PostgresPort $PostgresPort
    if ($LASTEXITCODE -ne 0) { throw 'Remove step failed' }

    Write-Step 'Reinstall: fresh install'
    & (Join-Path $ScriptDir 'install-on-local.ps1') -ProjectRoot $ProjectRoot -StackName $StackName -ApiPort $ApiPort -WebUiPort $WebUiPort -PostgresPort $PostgresPort
    if ($LASTEXITCODE -ne 0) { throw 'Install step failed' }
    Write-Ok 'Native reinstall complete'
}
catch {
    Write-Host "ERR $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
