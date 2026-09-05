#Requires -Version 5.1
<#
.SYNOPSIS
  Remove local Docker stack completely, including volumes and image.
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$DeployDir = $PSScriptRoot
$ConfigPath = Join-Path $DeployDir 'remove-on-local-docker.yaml'

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

if ($args.Count -gt 0) {
    Write-Fail 'This script accepts no CLI arguments. Edit remove-on-local-docker.yaml instead.'
    exit 1
}

try {
    $cfg = Read-FlatYaml $ConfigPath
    $repoRoot = Require-Key $cfg 'target_repo'
    $stackName = Require-Key $cfg 'stack_name'
    $composeFileRel = Require-Key $cfg 'compose_file'
    $imageTag = Require-Key $cfg 'image_tag'

    $composePath = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $composeFileRel))

    Write-Step "Remove local Docker stack=$stackName (including volumes)"
    Ensure-Docker

    if (Test-Path -LiteralPath $composePath) {
        docker compose -p $stackName -f $composePath --project-directory $repoRoot down -v
        $global:LASTEXITCODE = 0
    }

    Write-Step "Removing image $imageTag"
    cmd /c "docker image rm -f `"$imageTag`" >nul 2>&1"
    $global:LASTEXITCODE = 0

    $leftoverIds = docker ps -aq --filter "label=com.docker.compose.project=$stackName" 2>$null
    if ($leftoverIds) {
        foreach ($id in ($leftoverIds | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })) {
            docker rm -f $id *> $null
        }
    }
    $global:LASTEXITCODE = 0

    $leftoverVolumes = docker volume ls -q --filter "name=$stackName" 2>$null
    if ($leftoverVolumes) {
        foreach ($vol in ($leftoverVolumes | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })) {
            docker volume rm -f $vol *> $null
        }
    }
    $global:LASTEXITCODE = 0

    Write-Ok 'Local Docker remove complete'
}
catch {
    Write-Fail $_.Exception.Message
    exit 1
}
