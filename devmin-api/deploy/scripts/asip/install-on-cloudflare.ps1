#Requires -Version 5.1
<#
.SYNOPSIS
  First-time Cloudflare Workers install. Errors if Workers already exist.
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$DeployDir = $PSScriptRoot
$ConfigPath = Join-Path $DeployDir 'install-on-cloudflare.yaml'

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

function Test-WorkerDeployed([string]$WorkerRoot) {
    if (-not (Test-Path -LiteralPath $WorkerRoot)) { return $false }
    Push-Location $WorkerRoot
    try {
        $out = & npx --yes wrangler deployments list 2>&1 | Out-String
        if ($LASTEXITCODE -eq 0 -and $out -match '(Created|Version|Deployment|\d{4}-\d{2}-\d{2})') {
            return $true
        }
        return $false
    }
    finally { Pop-Location }
}

function Invoke-WranglerDeploy([string]$WorkerRoot, [string]$Label) {
    Write-Step "Deploy $Label from $WorkerRoot"
    Push-Location $WorkerRoot
    try {
        if (-not (Test-Path -LiteralPath 'node_modules')) {
            throw "node_modules missing in $WorkerRoot. Ask the user before npm install."
        }
        & npx wrangler deploy
        if ($LASTEXITCODE -ne 0) { throw "wrangler deploy failed for $Label" }
    }
    finally { Pop-Location }
}

if ($args.Count -gt 0) {
    Write-Fail 'This script accepts no CLI arguments. Edit install-on-cloudflare.yaml instead.'
    exit 1
}

try {
    $cfg = Read-FlatYaml $ConfigPath
    $repoRoot = Require-Key $cfg 'target_repo'
    $apiRootRel = Require-Key $cfg 'api_worker_root'
    $apiName = Require-Key $cfg 'api_worker_name'
    $webuiRootRel = Require-Key $cfg 'webui_worker_root'
    $webuiName = Require-Key $cfg 'webui_worker_name'
    $d1Name = if ($cfg.ContainsKey('d1_database_name')) { [string]$cfg['d1_database_name'] } else { '' }
    $webuiBuild = if ($cfg.ContainsKey('webui_build_command')) { [string]$cfg['webui_build_command'] } else { 'npm run build' }
    $apiUrl = Require-Key $cfg 'api_url'
    $webuiUrl = Require-Key $cfg 'webui_url'

    if (Test-Placeholder $repoRoot) { throw 'target_repo is still a placeholder.' }

    $apiRoot = Join-Path $repoRoot $apiRootRel
    $webuiRoot = Join-Path $repoRoot $webuiRootRel

    if ((Test-WorkerDeployed $apiRoot) -or (Test-WorkerDeployed $webuiRoot)) {
        throw "Already installed: Worker '$apiName' and/or '$webuiName' already deployed. Use update or reinstall."
    }

    Write-Step "Install Cloudflare Workers api=$apiName webui=$webuiName"

    if ($d1Name -and -not (Test-Placeholder $d1Name)) {
        Push-Location $apiRoot
        try {
            Write-Step "Apply D1 migrations for $d1Name (remote)"
            & npx wrangler d1 migrations apply $d1Name --remote
            if ($LASTEXITCODE -ne 0) { throw "D1 migrate failed for $d1Name" }
        }
        finally { Pop-Location }
    }

    Invoke-WranglerDeploy -WorkerRoot $apiRoot -Label $apiName

    Push-Location $webuiRoot
    try {
        if (-not (Test-Path -LiteralPath 'node_modules')) {
            throw "node_modules missing in $webuiRoot. Ask the user before npm install."
        }
        Write-Step "Build WebUI: $webuiBuild"
        cmd /c $webuiBuild
        if ($LASTEXITCODE -ne 0) { throw 'WebUI build failed' }
        $assetsDir = Join-Path $webuiRoot 'dist'
        if (-not (Test-Path -LiteralPath $assetsDir)) {
            throw "assets.directory missing: $assetsDir (narrow build output required)"
        }
    }
    finally { Pop-Location }

    Invoke-WranglerDeploy -WorkerRoot $webuiRoot -Label $webuiName

    Write-Ok "Cloudflare install complete`n  API:   $apiUrl`n  WebUI: $webuiUrl"
}
catch {
    Write-Fail $_.Exception.Message
    exit 1
}
