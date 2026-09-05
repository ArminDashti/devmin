#Requires -Version 5.1
<#
.SYNOPSIS
  First-time native Windows install. Errors if already installed.
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$DeployDir = $PSScriptRoot
$ConfigPath = Join-Path $DeployDir 'install-on-local-windows.yaml'

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

function Test-Placeholder([string]$Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) { return $true }
    return $Value -match '<[^>]+>'
}

function Test-PidAlive([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return $false }
    $pidText = Get-Content -LiteralPath $Path -ErrorAction SilentlyContinue
    if (-not $pidText) { return $false }
    return [bool](Get-Process -Id ([int]$pidText) -ErrorAction SilentlyContinue)
}

function Test-PortInUse([int]$Port) {
    $listeners = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
    return [bool]$listeners
}

function Test-TcpPortFree([int]$Port) { return -not (Test-PortInUse $Port) }

if ($args.Count -gt 0) {
    Write-Fail 'This script accepts no CLI arguments. Edit install-on-local-windows.yaml instead.'
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
    $postgresPort = [int](Require-Key $cfg 'postgres_port')
    $stateDirRel = Require-Key $cfg 'state_dir'
    $postgresContainer = Require-Key $cfg 'postgres_container'
    $postgresVolume = Require-Key $cfg 'postgres_volume'

    if (Test-Placeholder $repoRoot) { throw 'target_repo is still a placeholder.' }
    if (Test-Placeholder $stackName) { throw 'stack_name is still a placeholder.' }

    $apiDir = Join-Path $repoRoot $apiDirRel
    $webuiDir = Join-Path $repoRoot $webuiDirRel
    $stateDir = Join-Path $repoRoot $stateDirRel
    $apiPidFile = Join-Path $stateDir 'api.pid'
    $webuiPidFile = Join-Path $stateDir 'webui.pid'

    if ((Test-PidAlive $apiPidFile) -or (Test-PidAlive $webuiPidFile)) {
        throw "Already installed: stack '$stackName' appears running. Use update or reinstall."
    }
    if (-not (Test-TcpPortFree $apiPort)) {
        throw "api_port $apiPort is already in use. Re-author scripts with a free port (see create-ps-script-port-selection)."
    }
    if (-not (Test-TcpPortFree $webuiPort)) {
        throw "webui_port $webuiPort is already in use. Re-author scripts with a free port (see create-ps-script-port-selection)."
    }
    if (-not (Test-TcpPortFree $postgresPort)) {
        throw "postgres_port $postgresPort is already in use. Re-author scripts with a free port (see create-ps-script-port-selection)."
    }

    Write-Step "Install local Windows stack=$stackName"

    docker version *> $null
    if ($LASTEXITCODE -ne 0) { throw 'Docker is required for native Postgres. Start Docker Desktop.' }

    $existing = docker ps -a --filter "name=^/${postgresContainer}$" --format '{{.Names}}'
    if ($existing -eq $postgresContainer) {
        throw "Already installed: Postgres container '$postgresContainer' exists. Use update or reinstall."
    }

    Write-Step "Creating Postgres container $postgresContainer on port $postgresPort"
    docker run -d `
        --name $postgresContainer `
        -e POSTGRES_USER=localapps `
        -e POSTGRES_PASSWORD=localapps `
        -e POSTGRES_DB=localapps `
        -p "${postgresPort}:5432" `
        -v "${postgresVolume}:/var/lib/postgresql/data" `
        postgres:16-alpine | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Failed to create Postgres container' }

    New-Item -ItemType Directory -Force -Path $stateDir | Out-Null

    $envExample = Join-Path $apiDir '.env.example'
    $envFile = Join-Path $apiDir '.env'
    if (-not (Test-Path -LiteralPath $envFile)) {
        if (-not (Test-Path -LiteralPath $envExample)) { throw "Missing $envExample" }
        Copy-Item -LiteralPath $envExample -Destination $envFile
    }

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

    Write-Ok "Local Windows install complete (api:$apiPort webui:$webuiPort)"
}
catch {
    Write-Fail $_.Exception.Message
    exit 1
}
