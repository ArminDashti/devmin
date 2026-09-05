#Requires -Version 5.1
<#
.SYNOPSIS
  First-time local Docker install. Errors if stack already exists.
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$DeployDir = $PSScriptRoot
$ConfigPath = Join-Path $DeployDir 'install-on-local-docker.yaml'

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

function Ensure-Docker {
    docker version *> $null
    if ($LASTEXITCODE -ne 0) { throw 'Docker CLI is not available. Start Docker Desktop / daemon.' }
}

function Ensure-Network([string]$NetworkName) {
    docker network inspect $NetworkName *> $null
    if ($LASTEXITCODE -ne 0) {
        Write-Step "Creating network $NetworkName"
        docker network create $NetworkName | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "Failed to create network $NetworkName" }
    }
}

function Test-TcpPortFree([int]$Port) {
    $inUse = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
    return -not [bool]$inUse
}

if ($args.Count -gt 0) {
    Write-Fail 'This script accepts no CLI arguments. Edit install-on-local-docker.yaml instead.'
    exit 1
}

try {
    $cfg = Read-FlatYaml $ConfigPath
    $repoRoot = Require-Key $cfg 'target_repo'
    $stackName = Require-Key $cfg 'stack_name'
    $composeFileRel = Require-Key $cfg 'compose_file'
    $imageTag = Require-Key $cfg 'image_tag'
    $network = Require-Key $cfg 'docker_network'
    $publishPort = if ($cfg.ContainsKey('publish_port')) { [string]$cfg['publish_port'] } else { '' }

    if (Test-Placeholder $repoRoot) { throw 'target_repo is still a placeholder.' }
    if (Test-Placeholder $stackName) { throw 'stack_name is still a placeholder.' }

    $composePath = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $composeFileRel))
    if (-not (Test-Path -LiteralPath $composePath)) { throw "Compose not found: $composePath" }

    Ensure-Docker

    $existingIds = docker ps -aq --filter "label=com.docker.compose.project=$stackName" 2>$null
    if ($existingIds) {
        throw "Already installed: containers exist for stack '$stackName'. Use update or reinstall."
    }

    if ($publishPort -and -not (Test-Placeholder $publishPort)) {
        $pub = [int]$publishPort
        if (-not (Test-TcpPortFree $pub)) {
            throw "Host publish_port $pub is already in use. Re-author scripts with a free port (see create-ps-script-port-selection)."
        }
    }

    Write-Step "Install local Docker stack=$stackName image=$imageTag"
    Ensure-Network $network

    $env:IMAGE_TAG = $imageTag
    $env:DOCKER_NETWORK = $network
    if ($publishPort) { $env:PUBLISH_PORT = $publishPort }
    if ($cfg.ContainsKey('internal_port') -and $cfg['internal_port']) {
        $env:INTERNAL_PORT = [string]$cfg['internal_port']
    }

    docker compose -p $stackName -f $composePath --project-directory $repoRoot up -d --build
    if ($LASTEXITCODE -ne 0) { throw 'docker compose up failed' }

    Write-Ok "Local Docker install complete (publish_port=$publishPort)"
}
catch {
    Write-Fail $_.Exception.Message
    exit 1
}
