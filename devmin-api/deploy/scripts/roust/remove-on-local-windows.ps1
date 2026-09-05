#Requires -Version 5.1
<#
.SYNOPSIS
  Remove native Windows stack completely, including local data.
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$DeployDir = $PSScriptRoot
$ConfigPath = Join-Path $DeployDir 'remove-on-local-windows.yaml'

function Write-Step([string]$Message) { Write-Host ">> $Message" -ForegroundColor Cyan }
function Write-Ok([string]$Message) { Write-Host "OK  $Message" -ForegroundColor Green }
function Write-Fail([string]$Message) { Write-Host "ERR $Message" -ForegroundColor Red }

function Read-FlatYaml([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { throw "Missing config: $Path" }
    $map = @{}
    foreach ($raw in Get-Content -LiteralPath $Path) {
        $line = $raw.Trim()
        if ($line -eq '' -or $line.StartsWith('#')) { continue }
        if ($line -notmatch '^(?<key>[^:#]+):\s*(?<val>.*)$') { continue }
        $map[$Matches['key'].Trim()] = $Matches['val'].Trim().Trim('"').Trim("'")
    }
    return $map
}

function Require-Key($Map, [string]$Key) {
    if (-not $Map.ContainsKey($Key) -or [string]::IsNullOrWhiteSpace([string]$Map[$Key])) {
        throw "YAML missing required key: $Key"
    }
    return [string]$Map[$Key]
}

function Stop-PidFile([string]$Path, [string]$Label) {
    if (-not (Test-Path -LiteralPath $Path)) { return }
    $pidText = Get-Content -LiteralPath $Path -ErrorAction SilentlyContinue
    if ($pidText) {
        $procId = [int]$pidText
        if (Get-Process -Id $procId -ErrorAction SilentlyContinue) {
            Write-Step "Stopping $Label (pid $procId)"
            & taskkill.exe /PID $procId /T /F 2>$null | Out-Null
            Stop-Process -Id $procId -Force -ErrorAction SilentlyContinue
        }
    }
    Remove-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
}

function Stop-ListenersOnPort([int]$Port, [string]$Label) {
    $owners = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty OwningProcess -Unique
    foreach ($procId in $owners) {
        if ($procId -and (Get-Process -Id $procId -ErrorAction SilentlyContinue)) {
            Write-Step "Stopping $Label listener on port $Port (pid $procId)"
            & taskkill.exe /PID $procId /T /F 2>$null | Out-Null
        }
    }
}

if ($args.Count -gt 0) {
    Write-Fail 'This script accepts no CLI arguments. Edit remove-on-local-windows.yaml instead.'
    exit 1
}

try {
    $cfg = Read-FlatYaml $ConfigPath
    $repoRoot = Require-Key $cfg 'target_repo'
    $stackName = Require-Key $cfg 'stack_name'
    $apiPort = 0
    $webuiPort = 0
    if ($cfg.ContainsKey('api_port')) { $apiPort = [int]$cfg['api_port'] }
    if ($cfg.ContainsKey('webui_port')) { $webuiPort = [int]$cfg['webui_port'] }
    $stateDirRel = Require-Key $cfg 'state_dir'
    $postgresContainer = Require-Key $cfg 'postgres_container'
    $postgresVolume = Require-Key $cfg 'postgres_volume'

    $stateDir = Join-Path $repoRoot $stateDirRel
    $apiPidFile = Join-Path $stateDir 'api.pid'
    $webuiPidFile = Join-Path $stateDir 'webui.pid'

    Write-Step "Removing local Windows stack=$stackName (including data)"
    Stop-PidFile -Path $webuiPidFile -Label 'WebUI'
    Stop-PidFile -Path $apiPidFile -Label 'API'
    if ($webuiPort -gt 0) { Stop-ListenersOnPort -Port $webuiPort -Label 'WebUI' }
    if ($apiPort -gt 0) { Stop-ListenersOnPort -Port $apiPort -Label 'API' }

    docker version *> $null
    if ($LASTEXITCODE -eq 0) {
        $existing = docker ps -a --filter "name=^/${postgresContainer}$" --format '{{.Names}}'
        if ($existing -eq $postgresContainer) {
            Write-Step "Removing Postgres container and volume"
            docker rm -f $postgresContainer | Out-Null
            docker volume rm -f $postgresVolume 2>$null | Out-Null
        }
    }

    if (Test-Path -LiteralPath $stateDir) {
        Remove-Item -LiteralPath $stateDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    Write-Ok 'Local Windows remove complete'
}
catch {
    Write-Fail $_.Exception.Message
    exit 1
}
