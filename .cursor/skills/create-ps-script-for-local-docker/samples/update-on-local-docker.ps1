#Requires -Version 5.1
<#
.SYNOPSIS
  Update local Docker stack: rebuild/recreate; keep volumes.
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$DeployDir = $PSScriptRoot
$ConfigPath = Join-Path $DeployDir 'update-on-local-docker.yaml'

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

function Ensure-Docker {
    docker version *> $null
    if ($LASTEXITCODE -ne 0) { throw 'Docker CLI is not available.' }
}

function Ensure-Network([string]$NetworkName) {
    docker network inspect $NetworkName *> $null
    if ($LASTEXITCODE -ne 0) {
        docker network create $NetworkName | Out-Null
    }
}

if ($args.Count -gt 0) {
    Write-Fail 'This script accepts no CLI arguments. Edit update-on-local-docker.yaml instead.'
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

    $composePath = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $composeFileRel))
    if (-not (Test-Path -LiteralPath $composePath)) { throw "Compose not found: $composePath" }

    Write-Step "Update local Docker stack=$stackName (volumes preserved)"
    Ensure-Docker
    Ensure-Network $network

    $env:IMAGE_TAG = $imageTag
    $env:DOCKER_NETWORK = $network
    if ($publishPort) { $env:PUBLISH_PORT = $publishPort }
    if ($cfg.ContainsKey('internal_port') -and $cfg['internal_port']) {
        $env:INTERNAL_PORT = [string]$cfg['internal_port']
    }

    docker compose -p $stackName -f $composePath --project-directory $repoRoot up -d --build --force-recreate
    if ($LASTEXITCODE -ne 0) { throw 'docker compose up failed' }

    Write-Ok 'Local Docker update complete'
}
catch {
    Write-Fail $_.Exception.Message
    exit 1
}
