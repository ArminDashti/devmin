#Requires -Version 5.1
<#
.SYNOPSIS
  Reinstall devmin local Docker: remove volumes/images then fresh install.
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptDir = $PSScriptRoot

function Write-Step([string]$Message) { Write-Host ">> $Message" -ForegroundColor Cyan }
function Write-Ok([string]$Message) { Write-Host "OK  $Message" -ForegroundColor Green }

try {
    Write-Step 'Reinstall: local Docker remove'
    & (Join-Path $ScriptDir 'remove-on-docker-local.ps1')
    if ($LASTEXITCODE -ne 0) { throw 'Remove step failed' }

    Write-Step 'Reinstall: local Docker install'
    & (Join-Path $ScriptDir 'install-on-docker-local.ps1')
    if ($LASTEXITCODE -ne 0) { throw 'Install step failed' }
    Write-Ok 'Local Docker reinstall complete'
}
catch {
    Write-Host "ERR $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
