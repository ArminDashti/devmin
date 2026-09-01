#Requires -Version 5.1
<#
.SYNOPSIS
  Remove devmin from server Docker: compose down with volumes and images.
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$DeployDir = $PSScriptRoot
$ConfigPath = Join-Path $DeployDir 'remove-on-docker-server.yaml'

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
    $fullPath = [System.IO.Path]::GetFullPath((Join-Path $DeployDir $RelativePath))
    if (-not (Test-Path -LiteralPath $fullPath)) { throw "Path not found: $fullPath" }
    return $fullPath
}

function Test-Truthy([string]$Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) { return $false }
    return $Value.Trim().ToLowerInvariant() -in @('yes', 'true', '1', 'y', 'on')
}

function Parse-SshTarget([string]$SshValue) {
    if ($SshValue.Trim() -match '^(?i)ssh\s+(?<alias>\S+)$') {
        return @{ Alias = $Matches['alias']; LogTarget = "ssh $($Matches['alias'])" }
    }
    throw 'ssh must be "ssh <alias>".'
}

function Invoke-Remote($Target, [string]$RemoteCommand) {
    & ssh -o BatchMode=yes $Target.Alias $RemoteCommand
    if ($LASTEXITCODE -ne 0) { throw "Remote command failed on $($Target.LogTarget)" }
}

function Remove-Component($Target, [hashtable]$Cfg, [string]$ComposeRel, [string]$ImageTag, [bool]$DeleteVolume, [bool]$DeleteImage) {
    $stackName = Require-Key $Cfg 'stack_name'
    $volumeDir = Require-Key $Cfg 'volume_dir'
    $composePath = Resolve-DeployPath $ComposeRel
    $composeFileName = Split-Path -Leaf $composePath
    $remoteCompose = "$volumeDir/$composeFileName"
    $downFlags = if ($DeleteVolume) { '-v' } else { '' }
    Invoke-Remote -Target $Target -RemoteCommand "docker compose -p '$stackName' -f '$remoteCompose' --project-directory '$volumeDir' down $downFlags >/dev/null 2>&1 || true"
    if ($DeleteImage) {
        Invoke-Remote -Target $Target -RemoteCommand "docker image rm -f '$ImageTag' || true"
    }
}

try {
    $cfg = Read-FlatYaml $ConfigPath
    $target = Parse-SshTarget -SshValue (Require-Key $cfg 'ssh')
    $deleteVolume = Test-Truthy ($(if ($cfg.ContainsKey('delete_volume')) { [string]$cfg['delete_volume'] } else { 'yes' }))
    $deleteImage = Test-Truthy ($(if ($cfg.ContainsKey('delete_image')) { [string]$cfg['delete_image'] } else { 'yes' }))

    Write-Step "Server Docker remove on $($target.LogTarget)"
    Remove-Component -Target $target -Cfg $cfg `
        -ComposeRel (Require-Key $cfg 'webui_compose_file') `
        -ImageTag (Require-Key $cfg 'webui_image_tag') `
        -DeleteVolume $deleteVolume -DeleteImage $deleteImage
    Remove-Component -Target $target -Cfg $cfg `
        -ComposeRel (Require-Key $cfg 'api_compose_file') `
        -ImageTag (Require-Key $cfg 'api_image_tag') `
        -DeleteVolume $deleteVolume -DeleteImage $deleteImage
    Write-Ok 'Server Docker remove complete'
}
catch {
    Write-Fail $_.Exception.Message
    exit 1
}
