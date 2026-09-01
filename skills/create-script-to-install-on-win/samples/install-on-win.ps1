#Requires -Version 5.1
<#
.SYNOPSIS
  Non-Docker local update using sibling YAML only.

.DESCRIPTION
  Sample for devmin/scripts/local/<repo_name>/install-on-win.ps1.
  Reads install-on-win.yaml — no CLI -- flags.
  Refreshes deps without wiping .env or local DB.
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptsDir = $PSScriptRoot
$ConfigPath = Join-Path $ScriptsDir 'install-on-win.yaml'

function Write-Step([string]$Message) { Write-Host ">> $Message" -ForegroundColor Cyan }
function Write-Ok([string]$Message) { Write-Host "OK  $Message" -ForegroundColor Green }
function Write-Fail([string]$Message) { Write-Host "ERR $Message" -ForegroundColor Red }

function Show-Help {
    Write-Host @"
install-on-win.ps1 — local (non-Docker) install-on-win (YAML-only)

USAGE:
  .\.armin\scripts\local\install-on-win.ps1

CONFIG (sibling install-on-win.yaml):
  project_name, repo_root, api_dir, webui_dir, package_manager,
  wipe_deps (must stay no), wipe_local_db (must stay no), env_example

NOTES:
  - No CLI -- flags. Change behavior only via YAML.
  - Preserves .env and local DB. For a fresh wipe use install-on-local.ps1.
"@ -ForegroundColor Cyan
}

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
        $val = $Matches['val'].Trim()
        if (($val.StartsWith('"') -and $val.EndsWith('"')) -or ($val.StartsWith("'") -and $val.EndsWith("'"))) {
            $val = $val.Substring(1, $val.Length - 2)
        }
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

function Resolve-FromScripts([string]$RelativePath) {
    if ([string]::IsNullOrWhiteSpace($RelativePath)) { return $null }
    return [System.IO.Path]::GetFullPath((Join-Path $ScriptsDir $RelativePath))
}

function Install-Go([string]$Dir) {
    if (-not (Test-Path -LiteralPath (Join-Path $Dir 'go.mod'))) { return }
    Write-Step "go mod download in $Dir"
    Push-Location $Dir
    try {
        & go mod download
        if ($LASTEXITCODE -ne 0) { throw "go mod download failed in $Dir" }
    }
    finally { Pop-Location }
}

function Install-Node([string]$Dir) {
    $pkg = Join-Path $Dir 'package.json'
    if (-not (Test-Path -LiteralPath $pkg)) { return }
    Write-Step "npm/pnpm/yarn install in $Dir"
    Push-Location $Dir
    try {
        if (Test-Path -LiteralPath (Join-Path $Dir 'pnpm-lock.yaml')) { & pnpm install }
        elseif (Test-Path -LiteralPath (Join-Path $Dir 'yarn.lock')) { & yarn install }
        else { & npm install }
        if ($LASTEXITCODE -ne 0) { throw "Node install failed in $Dir" }
    }
    finally { Pop-Location }
}

function Install-Python([string]$Dir) {
    $req = Join-Path $Dir 'requirements.txt'
    if (-not (Test-Path -LiteralPath $req)) { return }
    $venv = Join-Path $Dir '.venv'
    $pip = Join-Path $venv 'Scripts\pip.exe'
    if (-not (Test-Path -LiteralPath $pip)) { $pip = Join-Path $venv 'bin/pip' }
    if (-not (Test-Path -LiteralPath $pip)) {
        throw "Missing .venv in $Dir — run install-on-local.ps1 first"
    }
    Write-Step "pip install -r requirements.txt in $Dir"
    & $pip install -r $req
    if ($LASTEXITCODE -ne 0) { throw "pip install failed in $Dir" }
}

function Install-Cargo([string]$Dir) {
    if (-not (Test-Path -LiteralPath (Join-Path $Dir 'Cargo.toml'))) { return }
    Write-Step "cargo fetch in $Dir"
    Push-Location $Dir
    try {
        & cargo fetch
        if ($LASTEXITCODE -ne 0) { throw "cargo fetch failed in $Dir" }
    }
    finally { Pop-Location }
}

if ($args.Count -gt 0) {
    Write-Fail 'This script accepts no CLI arguments. Edit install-on-win.yaml instead.'
    Show-Help
    exit 1
}

try {
    $cfg = Read-FlatYaml $ConfigPath
    $projectName = Require-Key $cfg 'project_name'
    $repoRootRel = Require-Key $cfg 'repo_root'
    $apiRel = if ($cfg.ContainsKey('api_dir')) { [string]$cfg['api_dir'] } else { '' }
    $webuiRel = if ($cfg.ContainsKey('webui_dir')) { [string]$cfg['webui_dir'] } else { '' }
    $wipeDeps = if ($cfg.ContainsKey('wipe_deps')) { Test-Truthy ([string]$cfg['wipe_deps']) } else { $false }
    $wipeDb = if ($cfg.ContainsKey('wipe_local_db')) { Test-Truthy ([string]$cfg['wipe_local_db']) } else { $false }

    if (Test-Placeholder $projectName) { throw 'project_name is still a placeholder.' }
    if ($wipeDeps) { throw 'install-on-win must keep wipe_deps no (use install-on-local to wipe).' }
    if ($wipeDb) { throw 'install-on-win must keep wipe_local_db no (use install-on-local to wipe DB).' }

    $repoRoot = Resolve-FromScripts $repoRootRel
    $apiDir = Resolve-FromScripts $apiRel
    $webuiDir = Resolve-FromScripts $webuiRel
    if (-not (Test-Path -LiteralPath $repoRoot)) { throw "repo_root not found: $repoRoot" }

    Write-Step "Install on win (non-Docker): $projectName"

    foreach ($dir in @($apiDir, $webuiDir, $repoRoot)) {
        if (-not $dir -or -not (Test-Path -LiteralPath $dir)) { continue }
        Install-Go $dir
        Install-Node $dir
        Install-Python $dir
        Install-Cargo $dir
    }

    Write-Ok "Install-on-win complete for $projectName"
    exit 0
}
catch {
    Write-Fail $_.Exception.Message
    exit 1
}
