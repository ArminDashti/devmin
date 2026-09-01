#Requires -Version 5.1
<#
.SYNOPSIS
  Update devmin local Docker stack: rebuild and recreate containers, keep volumes.
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$DeployDir = $PSScriptRoot
$RepoRoot = [System.IO.Path]::GetFullPath((Join-Path $DeployDir '../..'))
$ConfigPath = Join-Path $DeployDir 'update-on-docker-local.yaml'
$ComposeProjectDir = Join-Path $RepoRoot 'devmin-api'

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
        $key = $Matches['key'].Trim()
        $val = $Matches['val'].Trim().Trim('"').Trim("'")
        $map[$key] = $val
    }
    return $map
}

function Require-Key($Map, [string]$Key) {
    if (-not $Map.ContainsKey($Key) -or [string]::IsNullOrWhiteSpace([string]$Map[$Key])) {
        throw "YAML missing required key: $Key"
    }
    return [string]$Map[$Key]
}

function Resolve-DeployPath([string]$RelativePath) {
    $candidate = Join-Path $DeployDir $RelativePath
    $fullPath = [System.IO.Path]::GetFullPath($candidate)
    if (-not (Test-Path -LiteralPath $fullPath)) { throw "Path not found: $fullPath" }
    return $fullPath
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

try {
    $cfg = Read-FlatYaml $ConfigPath
    $stackName = Require-Key $cfg 'stack_name'
    $composeFileRel = Require-Key $cfg 'compose_file'
    $network = Require-Key $cfg 'docker_network'
    $composePath = Resolve-DeployPath $composeFileRel

    Write-Step "Local Docker update stack=$stackName (volumes preserved)"
    Ensure-Docker
    Ensure-Network $network
    docker compose -p $stackName -f $composePath --project-directory $ComposeProjectDir up -d --build --force-recreate
    if ($LASTEXITCODE -ne 0) { throw 'docker compose up failed' }
    Write-Ok 'Local Docker update complete'
}
catch {
    Write-Fail $_.Exception.Message
    exit 1
}
