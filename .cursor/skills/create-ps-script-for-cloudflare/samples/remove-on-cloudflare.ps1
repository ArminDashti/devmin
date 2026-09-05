#Requires -Version 5.1
<#
.SYNOPSIS
  Remove Cloudflare Workers and project-owned D1 data.
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$DeployDir = $PSScriptRoot
$ConfigPath = Join-Path $DeployDir 'remove-on-cloudflare.yaml'

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

if ($args.Count -gt 0) {
    Write-Fail 'This script accepts no CLI arguments. Edit remove-on-cloudflare.yaml instead.'
    exit 1
}

try {
    $cfg = Read-FlatYaml $ConfigPath
    $repoRoot = Require-Key $cfg 'target_repo'
    $apiRoot = Join-Path $repoRoot (Require-Key $cfg 'api_worker_root')
    $webuiRoot = Join-Path $repoRoot (Require-Key $cfg 'webui_worker_root')
    $apiName = Require-Key $cfg 'api_worker_name'
    $webuiName = Require-Key $cfg 'webui_worker_name'
    $d1Name = if ($cfg.ContainsKey('d1_database_name')) { [string]$cfg['d1_database_name'] } else { '' }

    Write-Step "Remove Cloudflare Workers $webuiName then $apiName (including D1 data)"

    if (Test-Path -LiteralPath $webuiRoot) {
        Push-Location $webuiRoot
        try {
            Write-Step "Deleting Worker $webuiName"
            & npx wrangler delete --force --yes 2>$null
            if ($LASTEXITCODE -ne 0) {
                & npx wrangler delete --force
            }
            $global:LASTEXITCODE = 0
        }
        finally { Pop-Location }
    }

    if (Test-Path -LiteralPath $apiRoot) {
        Push-Location $apiRoot
        try {
            Write-Step "Deleting Worker $apiName"
            & npx wrangler delete --force --yes 2>$null
            if ($LASTEXITCODE -ne 0) {
                & npx wrangler delete --force
            }
            $global:LASTEXITCODE = 0

            if ($d1Name -and -not (Test-Placeholder $d1Name)) {
                Write-Step "Deleting D1 database $d1Name"
                & npx wrangler d1 delete $d1Name --force
                $global:LASTEXITCODE = 0
            }
        }
        finally { Pop-Location }
    }

    Write-Ok 'Cloudflare remove complete'
}
catch {
    Write-Fail $_.Exception.Message
    exit 1
}
