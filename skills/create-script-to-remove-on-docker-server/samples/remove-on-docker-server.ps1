<#
.SYNOPSIS
  Deploy stack to a remote host over SSH using sibling YAML only.

.DESCRIPTION
  Sample for devmin/scripts/docker/<repo_name>/remove-on-docker-server.ps1.
  Reads remove-on-docker-server.yaml — no CLI -- flags except optional -Stop.
  Flow when build_image_on is local: N/A for remove → docker save → SCP → remote docker load → sync files → remote compose up -d.
  Flow when build_image_on is server: sync repo to remote → remote docker build → remote compose up -d.
#>
[CmdletBinding()]
param(
    [switch]$Stop
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$DeployDir = $PSScriptRoot
$RepoRoot = (Resolve-Path (Join-Path $DeployDir '../../..')).Path
$ConfigPath = Join-Path $DeployDir 'remove-on-docker-server.yaml'

function Write-Step([string]$Message) {
    Write-Host ">> $Message" -ForegroundColor Cyan
}

function Write-Ok([string]$Message) {
    Write-Host "OK  $Message" -ForegroundColor Green
}

function Write-Fail([string]$Message) {
    Write-Host "ERR $Message" -ForegroundColor Red
}

function Show-Help {
    Write-Host @"
remove-on-docker-server.ps1 — remote Docker remove (tear down only) (YAML-only)

USAGE:
  .\.armin\scripts\docker\remove-on-docker-server.ps1

CONFIG:
  Sibling file: remove-on-docker-server.yaml

  stack_name          Compose project name (-p)
  image_tag           Image tag for build and compose; overrides compose when set
  compose_file        Compose path relative to target_repo
  dockerfile          Dockerfile path relative to target_repo
  docker_network      External Docker network on remote
  publish_port        Optional host bind port; omit or empty = no host bind
  internal_port       Container listen port; overrides compose when set
  delete_volume       yes/true/1/y/on → remove volumes before up (install sample forces yes)
  delete_image        yes/true/1/y/on → remove image during teardown (install sample forces yes)
  build_image_on      local = build here and upload; server = build on remote
  ssh                 "ssh <alias>" or "host@user@password"
  volume_dir          Absolute remote directory for project + compose files

NOTES:
  - Install is always a fresh wipe for this stack on the remote: compose down -v, remove image, then build + up.
  - No CLI -- flags. Change behavior only via YAML (wipe keys must stay yes for install).
  - Non-empty override fields replace compose / Dockerfile values via env vars.
  - Alias mode uses ~/.ssh/config (no ssh_key field).
  - Rejects placeholder ssh values at runtime.
  - Never prints the password segment of host@user@password.
  - build_image_on=local requires Docker on this machine.
  - build_image_on=server syncs the repo to volume_dir and builds there.
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
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Missing config: $Path"
    }
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

function Resolve-DeployPath([string]$RelativePath) {
    $candidate = Join-Path $DeployDir $RelativePath
    return (Resolve-Path -LiteralPath $candidate).Path
}

function Get-RepoRelativePath([string]$AbsolutePath) {
    $root = $RepoRoot.TrimEnd('\', '/')
    $path = $AbsolutePath.TrimEnd('\', '/')
    if (-not $path.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Path is outside repo root: $AbsolutePath"
    }
    $relative = $path.Substring($root.Length).TrimStart('\', '/')
    return ($relative -replace '\\', '/')
}

function Build-ComposeEnvPrefix([hashtable]$Cfg, [string]$PublishPort) {
    $pairs = New-Object System.Collections.Generic.List[string]
    $escapedPublish = $PublishPort.Replace("'", "'\\''")
    [void]$pairs.Add("PUBLISH_PORT='$escapedPublish'")

    $mapping = @{
        image_tag       = 'IMAGE_TAG'
        docker_network  = 'DOCKER_NETWORK'
        internal_port   = 'INTERNAL_PORT'
    }
    foreach ($entry in $mapping.GetEnumerator()) {
        if (-not $Cfg.ContainsKey($entry.Key)) { continue }
        $value = [string]$Cfg[$entry.Key]
        if ([string]::IsNullOrWhiteSpace($value)) { continue }
        $escaped = $value.Replace("'", "'\\''")
        [void]$pairs.Add("$($entry.Value)='$escaped'")
    }
    return ($pairs -join ' ') + ' '
}

function Ensure-Docker {
    docker version *> $null
    if ($LASTEXITCODE -ne 0) { throw 'Docker CLI is not available. Start Docker Desktop / daemon.' }
}

function Parse-SshTarget([string]$SshValue) {
    $value = $SshValue.Trim()
    if ($value -match '^(?i)ssh\s+(?<alias>\S+)$') {
        $alias = $Matches['alias']
        return @{
            Mode      = 'alias'
            Alias     = $alias
            LogTarget = "ssh $alias"
        }
    }

    $parts = $value.Split('@')
    if ($parts.Count -eq 3) {
        $hostName = $parts[0]
        $userName = $parts[1]
        $password = $parts[2]
        if ((Test-Placeholder $hostName) -or (Test-Placeholder $userName) -or [string]::IsNullOrWhiteSpace($password)) {
            throw 'ssh password mode still has placeholders. Fill host@user@password in YAML.'
        }
        return @{
            Mode      = 'password'
            Host      = $hostName
            User      = $userName
            Password  = $password
            LogTarget = "$userName@$hostName"
        }
    }

    throw 'ssh must be "ssh <alias>" or "host@user@password".'
}

function Invoke-Remote {
    param($Target, [string]$RemoteCommand)

    if ($Target.Mode -eq 'alias') {
        & ssh -o BatchMode=yes $Target.Alias $RemoteCommand
        if ($LASTEXITCODE -ne 0) { throw "Remote command failed on $($Target.LogTarget)" }
        return
    }

    if (-not (Get-Command sshpass -ErrorAction SilentlyContinue)) {
        throw 'Password mode requires sshpass on PATH (or switch YAML to ssh alias mode).'
    }
    $env:SSHPASS = $Target.Password
    try {
        & sshpass -e ssh -o StrictHostKeyChecking=accept-new "$($Target.User)@$($Target.Host)" $RemoteCommand
        if ($LASTEXITCODE -ne 0) { throw "Remote command failed on $($Target.LogTarget)" }
    }
    finally {
        Remove-Item Env:SSHPASS -ErrorAction SilentlyContinue
    }
}

function Copy-ToRemote {
    param($Target, [string]$LocalPath, [string]$RemotePath)

    if ($Target.Mode -eq 'alias') {
        & scp -o BatchMode=yes $LocalPath "$($Target.Alias):$RemotePath"
        if ($LASTEXITCODE -ne 0) { throw "SCP failed to $($Target.LogTarget):$RemotePath" }
        return
    }

    if (-not (Get-Command sshpass -ErrorAction SilentlyContinue)) {
        throw 'Password mode requires sshpass on PATH (or switch YAML to ssh alias mode).'
    }
    $env:SSHPASS = $Target.Password
    try {
        & sshpass -e scp -o StrictHostKeyChecking=accept-new $LocalPath "$($Target.User)@$($Target.Host):$RemotePath"
        if ($LASTEXITCODE -ne 0) { throw "SCP failed to $($Target.LogTarget):$RemotePath" }
    }
    finally {
        Remove-Item Env:SSHPASS -ErrorAction SilentlyContinue
    }
}

function Copy-DirToRemote {
    param($Target, [string]$LocalDir, [string]$RemoteDir)

    if ($Target.Mode -eq 'alias') {
        & scp -r -o BatchMode=yes "$LocalDir/." "$($Target.Alias):$RemoteDir/"
        if ($LASTEXITCODE -ne 0) { throw "SCP directory failed to $($Target.LogTarget):$RemoteDir" }
        return
    }

    if (-not (Get-Command sshpass -ErrorAction SilentlyContinue)) {
        throw 'Password mode requires sshpass on PATH (or switch YAML to ssh alias mode).'
    }
    $env:SSHPASS = $Target.Password
    try {
        & sshpass -e scp -r -o StrictHostKeyChecking=accept-new "$LocalDir/." "$($Target.User)@$($Target.Host):$RemoteDir/"
        if ($LASTEXITCODE -ne 0) { throw "SCP directory failed to $($Target.LogTarget):$RemoteDir" }
    }
    finally {
        Remove-Item Env:SSHPASS -ErrorAction SilentlyContinue
    }
}

if ($args.Count -gt 0) {
    Write-Fail 'Unknown CLI arguments. Use optional -Stop or edit remove-on-docker-server.yaml.'
    Show-Help
    exit 1
}

try {
    $cfg = Read-FlatYaml $ConfigPath
    $stackName = Require-Key $cfg 'stack_name'
    $imageTag = Require-Key $cfg 'image_tag'
    $composeFileRel = Require-Key $cfg 'compose_file'
    $dockerfileRel = Require-Key $cfg 'dockerfile'
    $network = Require-Key $cfg 'docker_network'
    $publishPort = if ($cfg.ContainsKey('publish_port')) { [string]$cfg['publish_port'] } else { '' }
    $internalPort = if ($cfg.ContainsKey('internal_port')) { [string]$cfg['internal_port'] } else { '' }
    # Remove skill contract: always wipe this stack’s containers, volumes/DB, and image.
    $deleteVolume = $true
    $deleteImage = $true
    $buildImageOn = if ($cfg.ContainsKey('build_image_on')) { [string]$cfg['build_image_on'] } else { 'local' }
    $buildImageOn = $buildImageOn.Trim().ToLowerInvariant()
    $sshValue = Require-Key $cfg 'ssh'
    $volumeDir = Require-Key $cfg 'volume_dir'

    if (Test-Placeholder $sshValue) {
        throw 'ssh still has placeholders. Fill remove-on-docker-server.yaml before server deploy.'
    }
    if (Test-Placeholder $volumeDir) {
        throw 'volume_dir still has placeholders. Fill a real absolute remote path.'
    }

    $target = Parse-SshTarget -SshValue $sshValue
    $composePath = Resolve-DeployPath $composeFileRel
    $dockerfile = Resolve-DeployPath $dockerfileRel
    $composeFileName = Split-Path -Leaf $composePath
    $remoteDockerfile = Get-RepoRelativePath $dockerfile
    $remoteCompose = "$volumeDir/$composeFileName"

    if ($Stop) {
        Write-Step "Remote fresh stop (stack=$stackName)"
        Invoke-Remote -Target $target -RemoteCommand "docker compose -p '$stackName' -f '$remoteCompose' --project-directory '$volumeDir' down -v >/dev/null 2>&1 || docker compose -p '$stackName' down -v >/dev/null 2>&1 || true"
        Write-Step "Removing remote image $imageTag"
        Invoke-Remote -Target $target -RemoteCommand "docker image rm -f '$imageTag' || true"
        Invoke-Remote -Target $target -RemoteCommand "docker ps -aq --filter label=com.docker.compose.project=$stackName | xargs -r docker rm -f >/dev/null 2>&1 || true"
        Invoke-Remote -Target $target -RemoteCommand "docker volume ls -q --filter name=$stackName | xargs -r docker volume rm -f >/dev/null 2>&1 || true"
        Write-Ok "Stack wiped/stopped: $stackName on $($target.LogTarget)"
        exit 0
    }

    if ($buildImageOn -notin @('local', 'server')) {
        throw "build_image_on must be 'local' or 'server'."
    }
    if ($buildImageOn -eq 'local') {
        Ensure-Docker
    }

    Write-Step "Remote target: $($target.LogTarget)"
    Write-Step "Stack=$stackName image=$imageTag build_image_on=$buildImageOn volume_dir=$volumeDir publish_port='$publishPort' internal_port='$internalPort' (full remove)"

    Write-Step "Ensuring remote volume dir $volumeDir"
    Invoke-Remote -Target $target -RemoteCommand "mkdir -p '$volumeDir'"

    # Sync compose first so down -v can use the remote compose file when present.
    Write-Step "Sync $composeFileName for wipe/up"
    Copy-ToRemote -Target $target -LocalPath $composePath -RemotePath $remoteCompose

    Write-Step 'Fresh wipe: remote compose down -v'
    Invoke-Remote -Target $target -RemoteCommand "docker compose -p '$stackName' -f '$remoteCompose' --project-directory '$volumeDir' down -v >/dev/null 2>&1 || docker compose -p '$stackName' down -v >/dev/null 2>&1 || true"

    Write-Step "Removing remote image $imageTag"
    Invoke-Remote -Target $target -RemoteCommand "docker image rm -f '$imageTag' || true"

    Write-Step "Removing leftover remote containers/volumes for $stackName"
    Invoke-Remote -Target $target -RemoteCommand "docker ps -aq --filter label=com.docker.compose.project=$stackName | xargs -r docker rm -f >/dev/null 2>&1 || true"
    Invoke-Remote -Target $target -RemoteCommand "docker volume ls -q --filter name=$stackName | xargs -r docker volume rm -f >/dev/null 2>&1 || true"

    Write-Ok "Remove complete (remote stack torn down; no install) on $($target.LogTarget)"
}
catch {
    Write-Fail $_.Exception.Message
    Show-Help
    exit 1
}
