#Requires -Version 5.1
<#
.SYNOPSIS
  Remove devmin local Docker stack: compose down, delete volumes and images.
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$DeployDir = $PSScriptRoot
$RepoRoot = [System.IO.Path]::GetFullPath((Join-Path $DeployDir '../..'))
$ConfigPath = Join-Path $DeployDir 'remove-on-docker-local.yaml'
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

function Test-Truthy([string]$Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) { return $false }
    return $Value.Trim().ToLowerInvariant() -in @('yes', 'true', '1', 'y', 'on')
}

try {
    $cfg = Read-FlatYaml $ConfigPath
    $stackName = Require-Key $cfg 'stack_name'
    $composeFileRel = Require-Key $cfg 'compose_file'
    $composePath = Resolve-DeployPath $composeFileRel
    $deleteVolume = Test-Truthy ($(if ($cfg.ContainsKey('delete_volume')) { [string]$cfg['delete_volume'] } else { 'yes' }))
    $deleteImage = Test-Truthy ($(if ($cfg.ContainsKey('delete_image')) { [string]$cfg['delete_image'] } else { 'yes' }))
    $apiImage = if ($cfg.ContainsKey('api_image_tag')) { [string]$cfg['api_image_tag'] } else { 'pc-armin/devmin-api:latest' }
    $webuiImage = if ($cfg.ContainsKey('webui_image_tag')) { [string]$cfg['webui_image_tag'] } else { 'pc-armin/devmin-webui:latest' }

    docker version *> $null
    if ($LASTEXITCODE -ne 0) { throw 'Docker CLI is not available.' }

    Write-Step "Local Docker remove stack=$stackName"
    if ($deleteVolume) {
        docker compose -p $stackName -f $composePath --project-directory $ComposeProjectDir down -v
    }
    else {
        docker compose -p $stackName -f $composePath --project-directory $ComposeProjectDir down
    }
    if ($deleteImage) {
        docker image rm -f $apiImage $webuiImage 2>$null | Out-Null
    }
    Write-Ok 'Local Docker remove complete'
}
catch {
    Write-Fail $_.Exception.Message
    exit 1
}
