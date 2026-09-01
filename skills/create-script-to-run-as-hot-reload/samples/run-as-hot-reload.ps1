#Requires -Version 5.1
<#
.SYNOPSIS
  Start API + WebUI on the host with hot-reload using sibling YAML only.

.DESCRIPTION
  Sample for devmin/scripts/local/<repo_name>/run-as-hot-reload.ps1.
  Reads run-as-hot-reload.yaml — no CLI -- flags.
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptsDir = $PSScriptRoot
$ConfigPath = Join-Path $ScriptsDir 'run-as-hot-reload.yaml'

function Write-Step([string]$Message) { Write-Host ">> $Message" -ForegroundColor Cyan }
function Write-Ok([string]$Message) { Write-Host "OK  $Message" -ForegroundColor Green }
function Write-Fail([string]$Message) { Write-Host "ERR $Message" -ForegroundColor Red }

function Show-Help {
    Write-Host @"
run-as-hot-reload.ps1 — local (non-Docker) hot-reload (YAML-only)

USAGE:
  .\.armin\scripts\local\run-as-hot-reload.ps1

CONFIG (sibling run-as-hot-reload.yaml):
  project_name, api_dir, webui_dir, api_port, webui_port,
  api_command, webui_command, cors_origin, pid_file

NOTES:
  - No CLI -- flags. Host processes only (not Docker API/WebUI).
  - If a preferred port is busy, the script picks the next free port in-band.
"@ -ForegroundColor Cyan
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

function Get-ListenPorts {
    $ports = New-Object 'System.Collections.Generic.HashSet[int]'
    try {
        Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
            ForEach-Object { [void]$ports.Add([int]$_.LocalPort) }
    }
    catch { }
    try {
        $dockerOut = docker ps --format "{{.Ports}}" 2>$null
        if ($LASTEXITCODE -eq 0 -and $dockerOut) {
            foreach ($line in $dockerOut) {
                [regex]::Matches($line, ':(\d+)->') | ForEach-Object {
                    [void]$ports.Add([int]$_.Groups[1].Value)
                }
            }
        }
    }
    catch { }
    return $ports
}

function Get-FreePort([int]$Preferred, [int]$BandStart, [int]$BandEnd, $Used) {
    if ($Preferred -ge 1024 -and -not $Used.Contains($Preferred)) { return $Preferred }
    for ($p = $BandStart; $p -le $BandEnd; $p++) {
        if ($p -ge 1024 -and -not $Used.Contains($p)) { return $p }
    }
    throw "No free port in $BandStart-$BandEnd"
}

function Start-LoggedProcess([string]$Dir, [string]$Command, [string]$LogPath, [hashtable]$ExtraEnv) {
    if (-not (Test-Path -LiteralPath $Dir)) { throw "Directory not found: $Dir" }
    foreach ($k in $ExtraEnv.Keys) {
        Set-Item -Path "Env:$k" -Value ([string]$ExtraEnv[$k])
    }
    $stdout = "$LogPath.out.log"
    $stderr = "$LogPath.err.log"
    $p = Start-Process -FilePath 'powershell.exe' -ArgumentList @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command',
        "Set-Location -LiteralPath '$Dir'; $Command"
    ) -WorkingDirectory $Dir -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    return $p
}

if ($args.Count -gt 0) {
    Write-Fail 'This script accepts no CLI arguments. Edit run-as-hot-reload.yaml instead.'
    Show-Help
    exit 1
}

try {
    $cfg = Read-FlatYaml $ConfigPath
    $projectName = Require-Key $cfg 'project_name'
    $apiRel = Require-Key $cfg 'api_dir'
    $webuiRel = Require-Key $cfg 'webui_dir'
    $apiPortPref = [int](Require-Key $cfg 'api_port')
    $webuiPortPref = [int](Require-Key $cfg 'webui_port')
    $apiCommand = Require-Key $cfg 'api_command'
    $webuiCommand = Require-Key $cfg 'webui_command'
    $corsOrigin = if ($cfg.ContainsKey('cors_origin')) { [string]$cfg['cors_origin'] } else { '' }
    $pidName = if ($cfg.ContainsKey('pid_file') -and -not [string]::IsNullOrWhiteSpace([string]$cfg['pid_file'])) {
        [string]$cfg['pid_file']
    } else { 'run-as-hot-reload.pids' }

    if (Test-Placeholder $projectName) { throw 'project_name is still a placeholder.' }
    if ($apiPortPref -lt 1024 -or $webuiPortPref -lt 1024) { throw 'Ports must be unprivileged (>= 1024).' }

    $apiDir = Resolve-FromScripts $apiRel
    $webuiDir = Resolve-FromScripts $webuiRel
    $used = Get-ListenPorts
    $apiPort = Get-FreePort $apiPortPref 8171 8302 $used
    $used.Add($apiPort) | Out-Null
    $webuiPort = Get-FreePort $webuiPortPref 5173 5299 $used
    $origin = if ([string]::IsNullOrWhiteSpace($corsOrigin)) { "http://127.0.0.1:$webuiPort" } else { $corsOrigin }

    $webuiCommand = $webuiCommand -replace '--port\s+\d+', "--port $webuiPort"

    Write-Step "Hot-reload (host): $projectName  API=$apiPort  WebUI=$webuiPort"

    $envExtra = @{
        PORT              = "$apiPort"
        API_PORT          = "$apiPort"
        WEBUI_PORT        = "$webuiPort"
        CORS_ORIGIN       = $origin
        VITE_API_BASE_URL = "http://127.0.0.1:$apiPort"
    }

    $logDir = Join-Path $ScriptsDir '.run-as-hot-reload-logs'
    if (-not (Test-Path -LiteralPath $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }

    $apiProc = Start-LoggedProcess $apiDir $apiCommand (Join-Path $logDir 'api') $envExtra
    Start-Sleep -Seconds 1
    $webuiProc = Start-LoggedProcess $webuiDir $webuiCommand (Join-Path $logDir 'webui') $envExtra

    $pidPath = Join-Path $ScriptsDir $pidName
    @(
        "project=$projectName"
        "api_pid=$($apiProc.Id)"
        "webui_pid=$($webuiProc.Id)"
        "api_url=http://127.0.0.1:$apiPort"
        "webui_url=http://127.0.0.1:$webuiPort"
    ) | Set-Content -LiteralPath $pidPath -Encoding UTF8

    Write-Ok "API PID $($apiProc.Id)  http://127.0.0.1:$apiPort"
    Write-Ok "WebUI PID $($webuiProc.Id)  http://127.0.0.1:$webuiPort"
    Write-Host "Stop: Stop-Process -Id $($apiProc.Id),$($webuiProc.Id) -ErrorAction SilentlyContinue"
    Write-Host "PIDs file: $pidPath"
    exit 0
}
catch {
    Write-Fail $_.Exception.Message
    exit 1
}
