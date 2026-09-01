#Requires -Version 5.1
<#
.SYNOPSIS
    Reinstalls only this project's Windows app: uninstall if present, then install again.

.DESCRIPTION
    Lives at devmin/scripts/local/<repo_name>/reinstall-on-win.ps1. Project root is three levels up.
    Scope: this project only. It never targets another product or repo.
    Reinstall = remove completely, then install again.

    1. Optional -Build runs .\build-installer.ps1 in this project when present.
    2. Finds THIS product in Windows Uninstall registry (baked-in name / AppId).
    3. If found, runs QuietUninstallString or UninstallString with silent flags.
    4. Installs only the Setup package under this project's release\ or dist\.

.EXAMPLE
    .\.armin\scripts\local\reinstall-on-win.ps1

.EXAMPLE
    .\.armin\scripts\local\reinstall-on-win.ps1 -Build
#>
param(
    [switch]$Build
)

$ErrorActionPreference = "Stop"
$ProjectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
Set-Location $ProjectRoot

# Baked for THIS project only — do not turn these into caller params.
$ProductName = "{{PRODUCT_NAME}}"
$AppIdGuid = "{{APP_ID_GUID}}"
$SetupFileName = "{{SETUP_EXE_NAME}}"

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-PathUnderProjectRoot {
    param([string]$CandidatePath)

    $root = (Resolve-Path -LiteralPath $ProjectRoot).Path.TrimEnd('\')
    try {
        $full = (Resolve-Path -LiteralPath $CandidatePath -ErrorAction Stop).Path
    } catch {
        return $false
    }
    return $full.Equals($root, [StringComparison]::OrdinalIgnoreCase) -or
        $full.StartsWith($root + '\', [StringComparison]::OrdinalIgnoreCase)
}

function Get-UninstallEntries {
    $paths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    foreach ($path in $paths) {
        Get-ItemProperty $path -ErrorAction SilentlyContinue
    }
}

function Find-InstalledProduct {
    param(
        [string]$Name,
        [string]$Guid
    )

    $entries = Get-UninstallEntries
    if ($Guid -and $Guid -notmatch '^\{\{') {
        $guidNorm = $Guid.Trim("{}")
        $byGuid = $entries | Where-Object {
            $_.PSChildName -match [regex]::Escape($guidNorm) -or
            ("$($_.UninstallString)$($_.QuietUninstallString)" -match [regex]::Escape($guidNorm))
        }
        if ($byGuid) { return @($byGuid)[0] }
    }

    $byName = $entries | Where-Object {
        $_.DisplayName -and (
            $_.DisplayName -eq $Name -or
            $_.DisplayName.StartsWith("$Name ", [StringComparison]::OrdinalIgnoreCase)
        )
    }
    if ($byName) { return @($byName)[0] }
    return $null
}

function Invoke-UninstallEntry {
    param($Entry)

    $cmd = $Entry.QuietUninstallString
    if (-not $cmd) { $cmd = $Entry.UninstallString }
    if (-not $cmd) {
        throw "Uninstall registry entry has no UninstallString."
    }

    Write-Host "Uninstalling '$($Entry.DisplayName)' (this project only)..." -ForegroundColor Cyan

    if ($cmd -match '^\s*MsiExec\.exe\s+/[Ii]\{') {
        $productCode = [regex]::Match($cmd, '\{[0-9A-Fa-f-]+\}').Value
        $proc = Start-Process -FilePath "msiexec.exe" -ArgumentList "/x $productCode /quiet /norestart" -Wait -PassThru
        if ($proc.ExitCode -ne 0 -and $proc.ExitCode -ne 1605) {
            throw "msiexec uninstall failed with exit code $($proc.ExitCode)."
        }
        return
    }

    if ($cmd -match '^\s*"([^"]+)"\s*(.*)$') {
        $file = $Matches[1]
        $args = $Matches[2].Trim()
    } elseif ($cmd -match '^\s*(\S+)\s*(.*)$') {
        $file = $Matches[1]
        $args = $Matches[2].Trim()
    } else {
        throw "Could not parse uninstall command: $cmd"
    }

    if ($file -match 'unins\d*\.exe$' -and $args -notmatch '/VERYSILENT|/SILENT') {
        $args = (($args + " /VERYSILENT /NORESTART").Trim())
    }

    $proc = Start-Process -FilePath $file -ArgumentList $args -Wait -PassThru
    if ($null -ne $proc.ExitCode -and $proc.ExitCode -ne 0) {
        $stillThere = Find-InstalledProduct -Name $ProductName -Guid $AppIdGuid
        if ($stillThere) {
            throw "Uninstall failed with exit code $($proc.ExitCode)."
        }
    }
}

function Resolve-InstallerPath {
    $candidates = @(
        (Join-Path $ProjectRoot "release\$SetupFileName"),
        (Join-Path $ProjectRoot "dist\$SetupFileName"),
        (Join-Path $ProjectRoot "release\*.msi"),
        (Join-Path $ProjectRoot "dist\*.msi")
    )

    foreach ($pattern in $candidates) {
        $hit = Get-Item -Path $pattern -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($hit -and (Test-PathUnderProjectRoot -CandidatePath $hit.FullName)) {
            return $hit.FullName
        }
    }

    throw "Installer not found under this project ($ProjectRoot). Build first with -Build or place Setup under release\ or dist\."
}

# --- main --------------------------------------------------------------------

Write-Host "Reinstall scope: this project only ($ProjectRoot)" -ForegroundColor DarkCyan

if (-not (Test-IsAdministrator)) {
    Write-Warning "Administrator rights are usually required. Re-run elevated if uninstall/install fails."
}

$buildScript = Join-Path $ProjectRoot "build-installer.ps1"
if ($Build) {
    if (-not (Test-Path -LiteralPath $buildScript)) {
        throw "build-installer.ps1 not found in this project: $buildScript"
    }
    Write-Host "Building installer for this project..." -ForegroundColor Cyan
    & $buildScript
    if ($LASTEXITCODE -ne 0) {
        throw "build-installer.ps1 failed with exit code $LASTEXITCODE."
    }
}

$installed = Find-InstalledProduct -Name $ProductName -Guid $AppIdGuid
if ($installed) {
    Invoke-UninstallEntry -Entry $installed
    Start-Sleep -Seconds 2
} else {
    Write-Host "No installed version of '$ProductName' found. Skipping uninstall." -ForegroundColor Yellow
}

$setup = Resolve-InstallerPath
if (-not (Test-PathUnderProjectRoot -CandidatePath $setup)) {
    throw "Refusing installer outside this project: $setup"
}

Write-Host "Installing from $setup ..." -ForegroundColor Cyan

if ($setup -match '\.msi$') {
    $proc = Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$setup`" /quiet /norestart" -Wait -PassThru
} else {
    $proc = Start-Process -FilePath $setup -ArgumentList "/VERYSILENT /NORESTART" -Wait -PassThru
}

if ($null -ne $proc.ExitCode -and $proc.ExitCode -ne 0) {
    throw "Install failed with exit code $($proc.ExitCode)."
}

$verify = Find-InstalledProduct -Name $ProductName -Guid $AppIdGuid
if (-not $verify) {
    Write-Warning "Installer finished but product was not found in Uninstall registry yet."
} else {
    Write-Host "Reinstall complete (this project only): $($verify.DisplayName) $($verify.DisplayVersion)" -ForegroundColor Green
}
