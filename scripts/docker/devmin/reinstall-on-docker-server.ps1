#Requires -Version 5.1
<#
.SYNOPSIS
  Reinstall devmin on server Docker: remove volumes/images then install fresh.
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptDir = $PSScriptRoot

function Write-Step([string]$Message) { Write-Host ">> $Message" -ForegroundColor Cyan }
function Write-Ok([string]$Message) { Write-Host "OK  $Message" -ForegroundColor Green }

try {
    Write-Step 'Reinstall: server Docker remove'
    & (Join-Path $ScriptDir 'remove-on-docker-server.ps1')
    if ($LASTEXITCODE -ne 0) { throw 'Remove step failed' }

    Write-Step 'Reinstall: server Docker install'
    & (Join-Path $ScriptDir 'install-on-docker-server.ps1')
    if ($LASTEXITCODE -ne 0) { throw 'Install step failed' }
    Write-Ok 'Server Docker reinstall complete'
}
catch {
    Write-Host "ERR $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
