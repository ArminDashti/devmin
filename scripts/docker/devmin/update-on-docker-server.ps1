#Requires -Version 5.1
<#
.SYNOPSIS
  Update devmin on server Docker: rebuild/upload images, recreate containers, keep volumes.
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$InstallScript = Join-Path $PSScriptRoot 'install-on-docker-server.ps1'

try {
    & $InstallScript
    exit $LASTEXITCODE
}
catch {
    Write-Host "ERR $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
