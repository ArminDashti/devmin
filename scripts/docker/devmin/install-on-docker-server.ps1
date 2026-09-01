#Requires -Version 5.1
<#
.SYNOPSIS
  Install devmin on server Docker (API + WebUI) via SSH. Keeps existing volumes.
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$DeployDir = $PSScriptRoot
$RepoRoot = [System.IO.Path]::GetFullPath((Join-Path $DeployDir '../..'))
$ConfigPath = Join-Path $DeployDir 'install-on-docker-server.yaml'

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
    $value = $SshValue.Trim()
    if ($value -match '^(?i)ssh\s+(?<alias>\S+)$') {
        return @{ Mode = 'alias'; Alias = $Matches['alias']; LogTarget = "ssh $($Matches['alias'])" }
    }
    throw 'ssh must be "ssh <alias>".'
}

function Invoke-Remote($Target, [string]$RemoteCommand) {
    & ssh -o BatchMode=yes $Target.Alias $RemoteCommand
    if ($LASTEXITCODE -ne 0) { throw "Remote command failed on $($Target.LogTarget)" }
}

function Copy-ToRemote($Target, [string]$LocalPath, [string]$RemotePath) {
    & scp -o BatchMode=yes $LocalPath "$($Target.Alias):$RemotePath"
    if ($LASTEXITCODE -ne 0) { throw "SCP failed to $($Target.LogTarget):$RemotePath" }
}

function Build-ComposeEnvPrefix([hashtable]$Values, [string]$PublishPort) {
    $pairs = New-Object System.Collections.Generic.List[string]
    $escapedPublish = $PublishPort.Replace("'", "'\\''")
    [void]$pairs.Add("PUBLISH_PORT='$escapedPublish'")
    foreach ($entry in $Values.GetEnumerator()) {
        if ([string]::IsNullOrWhiteSpace([string]$entry.Value)) { continue }
        $escaped = ([string]$entry.Value).Replace("'", "'\\''")
        [void]$pairs.Add("$($entry.Key)='$escaped'")
    }
    return ($pairs -join ' ') + ' '
}

function Deploy-Component {
    param(
        $Target,
        [hashtable]$Cfg,
        [string]$ComponentName,
        [string]$ImageTag,
        [string]$ComposeRel,
        [string]$DockerfileRel,
        [string]$InternalPort,
        [string]$PublishPort,
        [bool]$DeleteVolume,
        [bool]$DeleteImage
    )

    $stackName = Require-Key $Cfg 'stack_name'
    $network = Require-Key $Cfg 'docker_network'
    $volumeDir = Require-Key $Cfg 'volume_dir'
    $composePath = Resolve-DeployPath $ComposeRel
    $dockerfile = Resolve-DeployPath $DockerfileRel
    $composeFileName = Split-Path -Leaf $composePath
    $remoteCompose = "$volumeDir/$composeFileName"
    $projectDir = Split-Path -Parent $composePath

    Write-Step "[$ComponentName] Building $ImageTag locally"
    docker build -f $dockerfile -t $ImageTag $projectDir
    if ($LASTEXITCODE -ne 0) { throw "docker build failed for $ComponentName" }

    $tarName = ($ImageTag -replace '[:/]', '_') + '.tar'
    $tarPath = Join-Path $env:TEMP $tarName
    docker save -o $tarPath $ImageTag
    if ($LASTEXITCODE -ne 0) { throw "docker save failed for $ComponentName" }

    $remoteTar = "/tmp/$tarName"
    Copy-ToRemote -Target $Target -LocalPath $tarPath -RemotePath $remoteTar
    Invoke-Remote -Target $Target -RemoteCommand "docker load -i $remoteTar && rm -f $remoteTar"
    Remove-Item -LiteralPath $tarPath -Force -ErrorAction SilentlyContinue

    Copy-ToRemote -Target $Target -LocalPath $composePath -RemotePath $remoteCompose

    if ($DeleteVolume -or $DeleteImage) {
        $downFlags = if ($DeleteVolume) { '-v' } else { '' }
        Invoke-Remote -Target $Target -RemoteCommand "docker compose -p '$stackName' -f '$remoteCompose' --project-directory '$volumeDir' down $downFlags >/dev/null 2>&1 || true"
        if ($DeleteImage) {
            Invoke-Remote -Target $Target -RemoteCommand "docker image rm -f '$ImageTag' || true"
        }
    }

    Invoke-Remote -Target $Target -RemoteCommand "docker network inspect '$network' >/dev/null 2>&1 || docker network create '$network'"
    $envPrefix = Build-ComposeEnvPrefix @{
        IMAGE_TAG      = $ImageTag
        DOCKER_NETWORK = $network
        INTERNAL_PORT  = $InternalPort
    } $PublishPort
    Invoke-Remote -Target $Target -RemoteCommand "${envPrefix}docker compose -p '$stackName' -f '$remoteCompose' --project-directory '$volumeDir' up -d"
    Write-Ok "[$ComponentName] deployed"
}

try {
    docker version *> $null
    if ($LASTEXITCODE -ne 0) { throw 'Docker CLI is required locally for build_image_on=local.' }

    $cfg = Read-FlatYaml $ConfigPath
    $target = Parse-SshTarget -SshValue (Require-Key $cfg 'ssh')
    $volumeDir = Require-Key $cfg 'volume_dir'
    $deleteVolume = Test-Truthy ($(if ($cfg.ContainsKey('delete_volume')) { [string]$cfg['delete_volume'] } else { 'no' }))
    $deleteImage = Test-Truthy ($(if ($cfg.ContainsKey('delete_image')) { [string]$cfg['delete_image'] } else { 'no' }))
    $publishPort = if ($cfg.ContainsKey('publish_port')) { [string]$cfg['publish_port'] } else { '' }

    Write-Step "Server Docker install on $($target.LogTarget)"
    Invoke-Remote -Target $target -RemoteCommand "mkdir -p '$volumeDir'"

    Deploy-Component -Target $target -Cfg $cfg -ComponentName 'api' `
        -ImageTag (Require-Key $cfg 'api_image_tag') `
        -ComposeRel (Require-Key $cfg 'api_compose_file') `
        -DockerfileRel (Require-Key $cfg 'api_dockerfile') `
        -InternalPort (Require-Key $cfg 'api_internal_port') `
        -PublishPort $publishPort `
        -DeleteVolume $deleteVolume -DeleteImage $deleteImage

    Deploy-Component -Target $target -Cfg $cfg -ComponentName 'webui' `
        -ImageTag (Require-Key $cfg 'webui_image_tag') `
        -ComposeRel (Require-Key $cfg 'webui_compose_file') `
        -DockerfileRel (Require-Key $cfg 'webui_dockerfile') `
        -InternalPort (Require-Key $cfg 'webui_internal_port') `
        -PublishPort $publishPort `
        -DeleteVolume $false -DeleteImage $false

    Write-Ok "Server Docker install complete at $volumeDir"
}
catch {
    Write-Fail $_.Exception.Message
    exit 1
}
