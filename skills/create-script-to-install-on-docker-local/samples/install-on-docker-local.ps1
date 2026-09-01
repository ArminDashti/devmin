#Requires -Version 5.1
<#
.SYNOPSIS
  Deploy stack to the local Docker daemon using sibling YAML only.

.DESCRIPTION
  Sample for devmin/scripts/docker/<repo_name>/install-on-docker-local.ps1.
  Reads install-on-docker-local.yaml — no CLI -- flags.
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$DeployDir = $PSScriptRoot
$ConfigPath = Join-Path $DeployDir 'install-on-docker-local.yaml'

function Write-Step([string]$Message) { Write-Host ">> $Message" -ForegroundColor Cyan }
function Write-Ok([string]$Message) { Write-Host "OK  $Message" -ForegroundColor Green }
function Write-Fail([string]$Message) { Write-Host "ERR $Message" -ForegroundColor Red }

function Test-Truthy([string]$Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) { return $false }
    return $Value.Trim().ToLowerInvariant() -in @('yes', 'true', '1', 'y', 'on')
}

function Test-Placeholder([string]$Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) { return $true }
    return $Value -match '<[^>]+>'
}

function Read-FlatYaml([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { throw "Missing config: $Path" }
    $map = @{}
    foreach ($raw in Get-Content -LiteralPath $Path) {
        $line = $raw.Trim()
        if ($line -eq '' -or $line.StartsWith('#')) { continue }
        if ($line -match '^\s*-') { continue }
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

function Resolve-TargetPath([string]$RepoRoot, [string]$RelativePath) {
    $fullPath = [System.IO.Path]::GetFullPath((Join-Path $RepoRoot $RelativePath))
    if (-not (Test-Path -LiteralPath $fullPath)) { throw "Path not found: $fullPath" }
    return $fullPath
}

function Ensure-Docker {
    docker version *> $null
    if ($LASTEXITCODE -ne 0) { throw 'Docker CLI is not available. Start Docker Desktop / daemon.' }
}

function Ensure-Network([string]$NetworkName) {
    docker network inspect $NetworkName *> $null
    if ($LASTEXITCODE -ne 0) {
        Write-Step "Creating network $NetworkName"
        docker network create $NetworkName *> $null
        if ($LASTEXITCODE -ne 0) { throw "Failed to create network $NetworkName" }
    }
}

if ($args.Count -gt 0) {
    Write-Fail 'This script accepts no CLI arguments. Edit install-on-docker-local.yaml instead.'
    exit 1
}

try {
    $cfg = Read-FlatYaml $ConfigPath
    $repoRoot = Require-Key $cfg 'target_repo'
    $stackName = Require-Key $cfg 'stack_name'
    $imageTag = Require-Key $cfg 'image_tag'
    $composeFileRel = Require-Key $cfg 'compose_file'
    $dockerfileRel = Require-Key $cfg 'dockerfile'
    $network = Require-Key $cfg 'docker_network'
    $publishPort = if ($cfg.ContainsKey('publish_port')) { [string]$cfg['publish_port'] } else { '' }
    $internalPort = if ($cfg.ContainsKey('internal_port')) { [string]$cfg['internal_port'] } else { '' }
    $deleteVolume = $true
    $deleteImage = $true

    if (Test-Placeholder $composeFileRel) { throw 'compose_file is still a placeholder.' }
    if (Test-Placeholder $dockerfileRel) { throw 'dockerfile is still a placeholder.' }

    $composePath = Resolve-TargetPath $repoRoot $composeFileRel
    $dockerfile = Resolve-TargetPath $repoRoot $dockerfileRel

    Write-Step "target_repo=$repoRoot stack=$stackName image=$imageTag"

    Ensure-Docker
    Ensure-Network $network

    Write-Step 'Fresh wipe: stopping stack and removing volumes'
    docker compose -p $stackName -f $composePath --project-directory $repoRoot down -v
    $global:LASTEXITCODE = 0

    Write-Step "Removing local image $imageTag"
    cmd /c "docker image rm -f `"$imageTag`" >nul 2>&1"
    $global:LASTEXITCODE = 0

    Write-Step "Building image $imageTag"
    docker build -f $dockerfile -t $imageTag $repoRoot
    if ($LASTEXITCODE -ne 0) { throw 'docker build failed' }

    Write-Step 'Starting stack (fresh)'
    $env:IMAGE_TAG = $imageTag
    $env:DOCKER_NETWORK = $network
    if (-not [string]::IsNullOrWhiteSpace($internalPort)) { $env:INTERNAL_PORT = $internalPort }
    if (-not [string]::IsNullOrWhiteSpace($publishPort)) { $env:PUBLISH_PORT = $publishPort }
    docker compose -p $stackName -f $composePath --project-directory $repoRoot up -d
    if ($LASTEXITCODE -ne 0) { throw 'docker compose up failed' }

    Write-Ok 'Fresh install complete'
}
catch {
    Write-Fail $_.Exception.Message
    exit 1
}
