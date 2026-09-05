#Requires -Version 5.1
<#
.SYNOPSIS
  Update native Windows stack: refresh code/deps; keep database and .env.
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$DeployDir = $PSScriptRoot
$ConfigPath = Join-Path $DeployDir 'update-on-local-windows.yaml'

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
            Stop-Process -Id $procId -Force -ErrorAction SilentlyContinue
        }
    }
    Remove-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
}

if ($args.Count -gt 0) {
    Write-Fail 'This script accepts no CLI arguments. Edit update-on-local-windows.yaml instead.'
    exit 1
}

try {
    $cfg = Read-FlatYaml $ConfigPath
    $repoRoot = Require-Key $cfg 'target_repo'
    $stackName = Require-Key $cfg 'stack_name'
    $apiDirRel = Require-Key $cfg 'api_dir'
    $webuiDirRel = Require-Key $cfg 'webui_dir'
    $apiPort = [int](Require-Key $cfg 'api_port')
    $webuiPort = [int](Require-Key $cfg 'webui_port')
    $stateDirRel = Require-Key $cfg 'state_dir'
    $postgresContainer = Require-Key $cfg 'postgres_container'

    $apiDir = Join-Path $repoRoot $apiDirRel
    $webuiDir = Join-Path $repoRoot $webuiDirRel
    $stateDir = Join-Path $repoRoot $stateDirRel
    $apiPidFile = Join-Path $stateDir 'api.pid'
    $webuiPidFile = Join-Path $stateDir 'webui.pid'

    Write-Step "Update local Windows stack=$stackName (data preserved)"
    Stop-PidFile -Path $webuiPidFile -Label 'WebUI'
    Stop-PidFile -Path $apiPidFile -Label 'API'

    docker version *> $null
    if ($LASTEXITCODE -eq 0) {
        $existing = docker ps -a --filter "name=^/${postgresContainer}$" --format '{{.Names}}'
        if ($existing -eq $postgresContainer) {
            $running = docker ps --filter "name=^/${postgresContainer}$" --format '{{.Names}}'
            if ($running -ne $postgresContainer) {
                docker start $postgresContainer | Out-Null
            }
        }
    }

    New-Item -ItemType Directory -Force -Path $stateDir | Out-Null

    if (Test-Path -LiteralPath (Join-Path $apiDir 'go.mod')) {
        Push-Location $apiDir
        try {
            go mod download
            if ($LASTEXITCODE -ne 0) { throw 'go mod download failed' }
            $proc = Start-Process -FilePath 'go' -ArgumentList 'run', './cmd/server' -WorkingDirectory $apiDir -PassThru -WindowStyle Hidden
            $proc.Id | Set-Content -LiteralPath $apiPidFile
        }
        finally { Pop-Location }
    }

    if (Test-Path -LiteralPath (Join-Path $webuiDir 'package.json')) {
        Push-Location $webuiDir
        try {
            npm install
            if ($LASTEXITCODE -ne 0) { throw 'npm install failed' }
            # Use npm.cmd via cmd.exe — Start-Process 'npm' opens the extensionless bash shim in VS Code.
            $npmCmd = (Get-Command npm.cmd -ErrorAction Stop).Source
            $webOut = Join-Path $stateDir 'webui.out.log'
            $webErr = Join-Path $stateDir 'webui.err.log'
            $inner = "`"$npmCmd`" run dev -- --host 127.0.0.1 --port $webuiPort --strictPort"
            $proc = Start-Process -FilePath 'cmd.exe' -ArgumentList @('/d', '/c', $inner) `
                -WorkingDirectory $webuiDir -PassThru `
                -RedirectStandardOutput $webOut -RedirectStandardError $webErr -WindowStyle Hidden
            $proc.Id | Set-Content -LiteralPath $webuiPidFile
            $deadline = (Get-Date).AddSeconds(120)
            while ((Get-Date) -lt $deadline) {
                if (Get-NetTCPConnection -LocalPort $webuiPort -State Listen -ErrorAction SilentlyContinue) { break }
                Start-Sleep -Seconds 1
            }
            if (-not (Get-NetTCPConnection -LocalPort $webuiPort -State Listen -ErrorAction SilentlyContinue)) {
                throw "WebUI did not listen on port $webuiPort. See $webErr"
            }
        }
        finally { Pop-Location }
    }

    Write-Ok "Local Windows update complete (api:$apiPort webui:$webuiPort)"
}
catch {
    Write-Fail $_.Exception.Message
    exit 1
}
