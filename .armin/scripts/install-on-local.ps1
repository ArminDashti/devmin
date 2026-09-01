#Requires -Version 5.1
<#
.SYNOPSIS
  Install devmin stack natively on Windows (Postgres in Docker, API + WebUI on host).
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
$ApiDir = Join-Path $ProjectRoot 'devmin-api'
$WebUiDir = Join-Path $ProjectRoot 'devmin-webui'
$EnvExample = Join-Path $ApiDir '.env.example'
$EnvFile = Join-Path $ApiDir '.env'
$PostgresContainer = "$StackName-postgres-native"
$PostgresVolume = "$StackName-postgres-native-data"
$StateDir = Join-Path $ProjectRoot '.armin' 'state'
$ApiPidFile = Join-Path $StateDir 'api.pid'
$WebUiPidFile = Join-Path $StateDir 'webui.pid'

function Write-Step([string]$Message) { Write-Host ">> $Message" -ForegroundColor Cyan }
function Write-Ok([string]$Message) { Write-Host "OK  $Message" -ForegroundColor Green }

function Ensure-Docker {
    docker version *> $null
    if ($LASTEXITCODE -ne 0) { throw 'Docker is required for native Postgres. Start Docker Desktop.' }
}

function Ensure-Postgres {
    Ensure-Docker
    $existing = docker ps -a --filter "name=^/${PostgresContainer}$" --format '{{.Names}}'
    if ($existing -eq $PostgresContainer) {
        $running = docker ps --filter "name=^/${PostgresContainer}$" --format '{{.Names}}'
        if ($running -ne $PostgresContainer) {
            Write-Step "Starting existing Postgres container $PostgresContainer"
            docker start $PostgresContainer | Out-Null
        }
        return
    }
    Write-Step "Creating Postgres container $PostgresContainer on port $PostgresPort"
    docker run -d `
        --name $PostgresContainer `
        -e POSTGRES_USER=localapps `
        -e POSTGRES_PASSWORD=localapps `
        -e POSTGRES_DB=localapps `
        -p "${PostgresPort}:5432" `
        -v "${PostgresVolume}:/var/lib/postgresql/data" `
        postgres:16-alpine | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Failed to create Postgres container' }
    $deadline = (Get-Date).AddSeconds(60)
    do {
        docker exec $PostgresContainer pg_isready -U localapps -d localapps *> $null
        if ($LASTEXITCODE -eq 0) { return }
        Start-Sleep -Seconds 2
    } while ((Get-Date) -lt $deadline)
    throw 'Postgres did not become ready in time'
}

function Ensure-EnvFile {
    if (-not (Test-Path -LiteralPath $EnvFile)) {
        if (-not (Test-Path -LiteralPath $EnvExample)) { throw "Missing $EnvExample" }
        Write-Step 'Copying .env.example to .env'
        Copy-Item -LiteralPath $EnvExample -Destination $EnvFile
    }
}

function Start-Api {
    if (-not (Get-Command go -ErrorAction SilentlyContinue)) { throw 'Go is required on PATH' }
    New-Item -ItemType Directory -Force -Path $StateDir | Out-Null
    if (Test-Path -LiteralPath $ApiPidFile) {
        $oldPid = Get-Content -LiteralPath $ApiPidFile -ErrorAction SilentlyContinue
        if ($oldPid -and (Get-Process -Id $oldPid -ErrorAction SilentlyContinue)) {
            Write-Step "API already running (pid $oldPid)"
            return
        }
    }
    Write-Step 'Installing API dependencies'
    Push-Location $ApiDir
    try {
        go mod download
        if ($LASTEXITCODE -ne 0) { throw 'go mod download failed' }
        Write-Step "Starting API on port $ApiPort"
        $proc = Start-Process -FilePath 'go' -ArgumentList 'run', './cmd/server' -WorkingDirectory $ApiDir -PassThru -WindowStyle Hidden
        $proc.Id | Set-Content -LiteralPath $ApiPidFile
    }
    finally {
        Pop-Location
    }
}

function Start-WebUi {
    if (-not (Get-Command npm -ErrorAction SilentlyContinue)) { throw 'npm is required on PATH' }
    New-Item -ItemType Directory -Force -Path $StateDir | Out-Null
    if (Test-Path -LiteralPath $WebUiPidFile) {
        $oldPid = Get-Content -LiteralPath $WebUiPidFile -ErrorAction SilentlyContinue
        if ($oldPid -and (Get-Process -Id $oldPid -ErrorAction SilentlyContinue)) {
            Write-Step "WebUI already running (pid $oldPid)"
            return
        }
    }
    Write-Step 'Installing WebUI dependencies'
    Push-Location $WebUiDir
    try {
        npm install --no-fund --no-audit
        if ($LASTEXITCODE -ne 0) { throw 'npm install failed' }
        Write-Step "Starting WebUI on port $WebUiPort"
        $env:VITE_DEV_PORT = "$WebUiPort"
        $env:VITE_API_PROXY_TARGET = "http://127.0.0.1:$ApiPort"
        $proc = Start-Process -FilePath 'npm' -ArgumentList 'run', 'dev', '--', '--host', '127.0.0.1', '--port', "$WebUiPort", '--strictPort' -WorkingDirectory $WebUiDir -PassThru -WindowStyle Hidden
        $proc.Id | Set-Content -LiteralPath $WebUiPidFile
    }
    finally {
        Pop-Location
    }
}

try {
    Write-Step "Installing stack $StackName (native)"
    Ensure-EnvFile
    Ensure-Postgres
    Start-Api
    Start-WebUi
    Write-Ok "Native install complete. WebUI: http://127.0.0.1:$WebUiPort/apps  API: http://127.0.0.1:$ApiPort/health"
}
catch {
    Write-Host "ERR $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
