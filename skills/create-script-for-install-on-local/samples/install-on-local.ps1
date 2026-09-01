#Requires -Version 5.1
<#
.SYNOPSIS
  First-time non-Docker local install using sibling YAML only.

.DESCRIPTION
  Sample for scripts/install-on-local.ps1.
  Reads install-on-local.yaml — no CLI -- flags.
  Wipes listed local deps, then installs clean.
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptsDir = $PSScriptRoot
$ConfigPath = Join-Path $ScriptsDir 'install-on-local.yaml'

function Write-Step([string]$Message) { Write-Host ">> $Message" -ForegroundColor Cyan }
function Write-Ok([string]$Message) { Write-Host "OK  $Message" -ForegroundColor Green }
function Write-Fail([string]$Message) { Write-Host "ERR $Message" -ForegroundColor Red }

function Show-Help {
    Write-Host @"
install-on-local.ps1 — first-time local (non-Docker) install (YAML-only)

USAGE:
  .\scripts\install-on-local.ps1

CONFIG (sibling install-on-local.yaml):
  project_name, repo_root, api_dir, webui_dir, package_manager,
  wipe_deps (install forces yes), wipe_local_db, env_example

NOTES:
  - No CLI -- flags. Change behavior only via YAML.
  - Does not Dockerize the app. For Docker install use install-on-docker-local.
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
    $fullPath = [System.IO.Path]::GetFullPath((Join-Path $ScriptsDir $RelativePath))
    return $fullPath
}

function Remove-DirIfExists([string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path)) { return }
    if (Test-Path -LiteralPath $Path) {
        Write-Step "Removing $Path"
        Remove-Item -LiteralPath $Path -Recurse -Force
    }
}

function Ensure-EnvFromExample([string]$ExamplePath, [string]$TargetDir) {
    if ([string]::IsNullOrWhiteSpace($ExamplePath) -or -not (Test-Path -LiteralPath $ExamplePath)) { return }
    $envPath = Join-Path $TargetDir '.env'
    if (Test-Path -LiteralPath $envPath) {
        Write-Ok ".env already exists (kept): $envPath"
        return
    }
    Copy-Item -LiteralPath $ExamplePath -Destination $envPath
    Write-Ok "Created .env from example: $envPath"
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
    Write-Step "npm install in $Dir"
    Push-Location $Dir
    try {
        if (Test-Path -LiteralPath (Join-Path $Dir 'pnpm-lock.yaml')) {
            & pnpm install
        }
        elseif (Test-Path -LiteralPath (Join-Path $Dir 'yarn.lock')) {
            & yarn install
        }
        else {
            & npm install
        }
        if ($LASTEXITCODE -ne 0) { throw "Node install failed in $Dir" }
    }
    finally { Pop-Location }
}

function Install-Python([string]$Dir) {
    $req = Join-Path $Dir 'requirements.txt'
    if (-not (Test-Path -LiteralPath $req)) { return }
    $venv = Join-Path $Dir '.venv'
    Write-Step "Python venv + pip in $Dir"
    if (-not (Test-Path -LiteralPath $venv)) {
        & python -m venv $venv
        if ($LASTEXITCODE -ne 0) { throw "python -m venv failed in $Dir" }
    }
    $pip = Join-Path $venv 'Scripts\pip.exe'
    if (-not (Test-Path -LiteralPath $pip)) { $pip = Join-Path $venv 'bin/pip' }
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

function Wipe-ProjectDeps([string]$Dir) {
    if ([string]::IsNullOrWhiteSpace($Dir) -or -not (Test-Path -LiteralPath $Dir)) { return }
    Remove-DirIfExists (Join-Path $Dir 'node_modules')
    Remove-DirIfExists (Join-Path $Dir '.venv')
    Remove-DirIfExists (Join-Path $Dir 'vendor')
    Remove-DirIfExists (Join-Path $Dir 'bin')
    Remove-DirIfExists (Join-Path $Dir 'dist')
    Remove-DirIfExists (Join-Path $Dir 'target\debug')
}

if ($args.Count -gt 0) {
    Write-Fail 'This script accepts no CLI arguments. Edit install-on-local.yaml instead.'
    Show-Help
    exit 1
}

try {
    $cfg = Read-FlatYaml $ConfigPath
    $projectName = Require-Key $cfg 'project_name'
    $repoRootRel = Require-Key $cfg 'repo_root'
    $apiRel = if ($cfg.ContainsKey('api_dir')) { [string]$cfg['api_dir'] } else { '' }
    $webuiRel = if ($cfg.ContainsKey('webui_dir')) { [string]$cfg['webui_dir'] } else { '' }
    $envExampleRel = if ($cfg.ContainsKey('env_example')) { [string]$cfg['env_example'] } else { '' }
    $wipeDeps = $true
    $wipeDb = if ($cfg.ContainsKey('wipe_local_db')) { Test-Truthy ([string]$cfg['wipe_local_db']) } else { $false }

    if (Test-Placeholder $projectName) { throw 'project_name is still a placeholder.' }

    $repoRoot = Resolve-FromScripts $repoRootRel
    $apiDir = Resolve-FromScripts $apiRel
    $webuiDir = Resolve-FromScripts $webuiRel
    $envExample = Resolve-FromScripts $envExampleRel

    if (-not (Test-Path -LiteralPath $repoRoot)) { throw "repo_root not found: $repoRoot" }

    Write-Step "Install on local (non-Docker): $projectName"
    if (-not $wipeDeps) { throw 'install-on-local requires wipe_deps yes' }

    foreach ($dir in @($apiDir, $webuiDir, $repoRoot)) {
        if ($dir -and (Test-Path -LiteralPath $dir)) { Wipe-ProjectDeps $dir }
    }

    if ($wipeDb) {
        Write-Step 'wipe_local_db=yes — run only a project-documented local DB reset if adapted in this copy'
        # Adapt per project (migrate down/up, dropdb, etc.). Sample leaves DB alone unless customized.
    }

    $envTarget = if ($apiDir -and (Test-Path -LiteralPath $apiDir)) { $apiDir } else { $repoRoot }
    Ensure-EnvFromExample $envExample $envTarget

    foreach ($dir in @($apiDir, $webuiDir, $repoRoot)) {
        if (-not $dir -or -not (Test-Path -LiteralPath $dir)) { continue }
        Install-Go $dir
        Install-Node $dir
        Install-Python $dir
        Install-Cargo $dir
    }

    Write-Ok "Local install complete for $projectName"
    Write-Host "Next: .\scripts\run-hot-reload.ps1 (after create-script-for-run-hot-reload)"
    exit 0
}
catch {
    Write-Fail $_.Exception.Message
    exit 1
}
