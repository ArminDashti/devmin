#Requires -Version 5.1
<#
.SYNOPSIS
  Remove devmin native stack. Drops Postgres data unless -KeepDatabase is set.
#>
[CmdletBinding()]
param(
    [string]$ProjectRoot = '',
    [string]$StackName = 'devmin',
    [int]$PostgresPort = 5455,
    [switch]$KeepDatabase
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptDir = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = [System.IO.Path]::GetFullPath((Join-Path $ScriptDir '../..'))
}
$StateDir = Join-Path $ProjectRoot '.armin' 'state'
$ApiPidFile = Join-Path $StateDir 'api.pid'
$WebUiPidFile = Join-Path $StateDir 'webui.pid'
$PostgresContainer = "$StackName-postgres-native"
$PostgresVolume = "$StackName-postgres-native-data"

function Write-Step([string]$Message) { Write-Host ">> $Message" -ForegroundColor Cyan }
function Write-Ok([string]$Message) { Write-Host "OK  $Message" -ForegroundColor Green }

function Stop-PidFile([string]$Path, [string]$Label) {
    if (-not (Test-Path -LiteralPath $Path)) { return }
    $pidText = Get-Content -LiteralPath $Path -ErrorAction SilentlyContinue
    if ($pidText) {
        $procId = [int]$pidText
        $proc = Get-Process -Id $procId -ErrorAction SilentlyContinue
        if ($proc) {
            Write-Step "Stopping $Label (pid $procId)"
            Stop-Process -Id $procId -Force -ErrorAction SilentlyContinue
        }
    }
    Remove-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
}

try {
    Write-Step "Removing native stack $StackName"
    Stop-PidFile -Path $WebUiPidFile -Label 'WebUI'
    Stop-PidFile -Path $ApiPidFile -Label 'API'

    docker version *> $null
    if ($LASTEXITCODE -eq 0) {
        $existing = docker ps -a --filter "name=^/${PostgresContainer}$" --format '{{.Names}}'
        if ($existing -eq $PostgresContainer) {
            if ($KeepDatabase) {
                Write-Step 'Stopping Postgres container (data kept)'
                docker stop $PostgresContainer | Out-Null
            }
            else {
                Write-Step 'Removing Postgres container and volume'
                docker rm -f $PostgresContainer | Out-Null
                docker volume rm -f $PostgresVolume 2>$null | Out-Null
            }
        }
    }
    Write-Ok 'Native remove complete'
}
catch {
    Write-Host "ERR $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
