#Requires -Version 5.1
<#
.SYNOPSIS
  Activate Windows Mobile Hotspot in any workable condition.

.DESCRIPTION
  Silent SoftAP start (no Settings UI). Never disconnects VPN.
  - Already On  -> leave On, exit 0
  - Repairs Wi-Fi radio best-effort (PnP enable/restart, WLAN ext DLLs from DriverStore)
  - OpenVPN TAP Up -> share from TAP (VPN egress)
  - TAP down     -> share from best other upstream (Ethernet / Wi-Fi)
  - Ensures StartHotspot4.exe under %LOCALAPPDATA%\Armin\MobileHotspot
  - Re-pins PreferredPublicInterface after start; invokes Ensure-SoftApDhcp when present

.NOTES
  Run elevated. SoftAP needs a working Wi-Fi radio (TP-Link USB on PC-ARMIN).
  Exit codes: 0=On, 2=helper missing, 4=Wi-Fi radio dead, 5=tether start failed
#>
[CmdletBinding()]
param(
    [int]$VpnWaitSeconds = 30
)

$ErrorActionPreference = 'Continue'
Set-StrictMode -Version Latest

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$logDir = Join-Path $env:LOCALAPPDATA 'Armin\MobileHotspot'
$logPath = Join-Path $logDir 'activate.log'
New-Item -ItemType Directory -Path $logDir -Force | Out-Null

function Write-Log {
    param([string]$Message)
    $line = '{0} {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Add-Content -Path $logPath -Value $line -Encoding utf8
    Write-Host $line
}

function Get-HotspotStatusText {
    param([string]$ExePath)
    if (-not (Test-Path -LiteralPath $ExePath)) { return 'MISSING_EXE' }
    try {
        return ((& $ExePath status 2>&1) | Out-String).Trim()
    } catch {
        return ('STATUS_ERR: ' + $_.Exception.Message)
    }
}

function Test-HotspotOn {
    param([string]$StatusText)
    return (
        $StatusText -match '(?m)^state=On\b' -or
        $StatusText -match '\bstateAfter=On\b' -or
        $StatusText -match '\bALREADY_ON\b'
    )
}

function Ensure-StartHotspotHelper {
    $exePath = Join-Path $logDir 'StartHotspot4.exe'
    $csPath = Join-Path $scriptDir 'StartHotspot4.cs'
    $needsCompile = -not (Test-Path -LiteralPath $exePath)
    if (-not $needsCompile -and (Test-Path -LiteralPath $csPath)) {
        if ((Get-Item -LiteralPath $csPath).LastWriteTimeUtc -gt (Get-Item -LiteralPath $exePath).LastWriteTimeUtc) {
            $needsCompile = $true
        }
    }
    if (-not $needsCompile) { return $exePath }
    if (-not (Test-Path -LiteralPath $csPath)) {
        Write-Log "FAIL: missing $exePath and $csPath"
        return $null
    }

    $frameworkDir = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319'
    $cscPath = Join-Path $frameworkDir 'csc.exe'
    $winMetadata = Join-Path $env:WINDIR 'System32\WinMetadata'
    $systemRuntime = 'C:\Program Files (x86)\Reference Assemblies\Microsoft\Framework\.NETFramework\v4.8\Facades\System.Runtime.dll'
    if (-not (Test-Path -LiteralPath $cscPath)) {
        Write-Log "FAIL: missing csc.exe at $cscPath"
        return $null
    }

    Write-Log "Compiling StartHotspot4.exe from $csPath"
    & $cscPath /nologo /nostdlib+ /t:exe /out:$exePath `
        /r:"$frameworkDir\mscorlib.dll" `
        /r:$systemRuntime `
        /r:"$frameworkDir\System.Runtime.WindowsRuntime.dll" `
        /r:"$winMetadata\Windows.Foundation.winmd" `
        /r:"$winMetadata\Windows.Networking.winmd" `
        $csPath | ForEach-Object { Write-Log $_ }
    if (-not (Test-Path -LiteralPath $exePath)) {
        Write-Log 'FAIL: compile did not produce StartHotspot4.exe'
        return $null
    }
    return $exePath
}

function Test-WirelessInterfacePresent {
    $netshOut = (netsh wlan show drivers 2>&1 | Out-String)
    if ($netshOut -match 'There is no wireless interface') { return $false }
    if ($netshOut -match 'Interface name|Driver\s+:') { return $true }
    $wifi = Get-NetAdapter -ErrorAction SilentlyContinue |
        Where-Object { $_.InterfaceDescription -match 'Wireless|Wi-Fi|802\.11|RTL8192|TP-Link' -and $_.ifOperStatus -ne 'NotPresent' }
    foreach ($adapter in @($wifi)) {
        if ($adapter -and $adapter.ifOperStatus -ne 'Down') { return $true }
        # Disconnected is OK for SoftAP (radio up, not associated)
        if ($adapter -and $adapter.Status -eq 'Disconnected') { return $true }
        if ($adapter -and $adapter.MediaConnectionState -eq 'Connected') { return $true }
    }
    return $false
}

function Repair-WifiRadioBestEffort {
    Write-Log 'Repairing Wi-Fi radio (best effort)'

    # Restore WLAN extensibility DLLs from DriverStore when missing (common SoftAP break)
    $driverStorePkg = Get-ChildItem 'C:\Windows\System32\DriverStore\FileRepository' -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like 'netrtwlanu.inf_amd64_*' } |
        Sort-Object { (Get-Item (Join-Path $_.FullName 'rtwlanu.sys') -ErrorAction SilentlyContinue).Length } -Descending |
        Select-Object -First 1
    if ($driverStorePkg) {
        foreach ($fileName in @('RTUWPWlanExt.dll', 'RTUWPSrvcLib.dll', 'RTUWPUsbSwExt.dll', 'RTUWPSrvcMain.exe')) {
            $fromPath = Join-Path $driverStorePkg.FullName $fileName
            $toPath = Join-Path $env:WINDIR "System32\$fileName"
            if ((Test-Path -LiteralPath $fromPath) -and -not (Test-Path -LiteralPath $toPath)) {
                Copy-Item -LiteralPath $fromPath -Destination $toPath -Force -ErrorAction SilentlyContinue
                Write-Log "Copied $fileName -> System32"
            }
        }
        $legacyPath = Join-Path $env:WINDIR 'System32\Rtlihvs.dll'
        $modernPath = Join-Path $env:WINDIR 'System32\RTUWPWlanExt.dll'
        if ((Test-Path -LiteralPath $modernPath) -and -not (Test-Path -LiteralPath $legacyPath)) {
            Copy-Item -LiteralPath $modernPath -Destination $legacyPath -Force -ErrorAction SilentlyContinue
            Write-Log 'Copied RTUWPWlanExt.dll as Rtlihvs.dll'
        }
    }

    $wifiDevices = @(Get-PnpDevice -Class Net -ErrorAction SilentlyContinue |
        Where-Object {
            $_.FriendlyName -match 'TP-Link Wireless USB Adapter' -or
            $_.FriendlyName -match 'Realtek RTL8192'
        })

    foreach ($wifiDevice in $wifiDevices) {
        Write-Log ("PnP {0} Status={1} Problem={2}" -f $wifiDevice.FriendlyName, $wifiDevice.Status, $wifiDevice.Problem)
        if ($wifiDevice.Problem -eq 'CM_PROB_PHANTOM') { continue }
        try {
            Enable-PnpDevice -InstanceId $wifiDevice.InstanceId -Confirm:$false -ErrorAction SilentlyContinue
            pnputil /enable-device "$($wifiDevice.InstanceId)" 2>&1 | Out-Null
            pnputil /restart-device "$($wifiDevice.InstanceId)" 2>&1 | Out-Null
        } catch {
            Write-Log ("PnP repair: " + $_.Exception.Message)
        }
    }

    $wifiAdapter = Get-NetAdapter -ErrorAction SilentlyContinue |
        Where-Object { $_.InterfaceDescription -match 'RTL8192|TP-Link' -or $_.Name -match '^Wi-Fi' } |
        Select-Object -First 1
    if ($wifiAdapter) {
        try {
            Enable-NetAdapter -Name $wifiAdapter.Name -Confirm:$false -ErrorAction SilentlyContinue
            Write-Log ("Enabled NetAdapter {0} AdminStatus={1} ifOperStatus={2}" -f $wifiAdapter.Name, $wifiAdapter.AdminStatus, $wifiAdapter.ifOperStatus)
        } catch {
            Write-Log ("NetAdapter enable: " + $_.Exception.Message)
        }
    }

    Restart-Service WlanSvc -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3

    $after = Get-PnpDevice -Class Net -ErrorAction SilentlyContinue |
        Where-Object { $_.FriendlyName -match 'TP-Link Wireless USB Adapter' -and $_.Problem -ne 'CM_PROB_PHANTOM' } |
        Select-Object -First 1
    if ($after) {
        Write-Log ("Wi-Fi after repair Status={0} Problem={1}" -f $after.Status, $after.Problem)
        if ($after.Problem -eq 'CM_PROB_FAILED_START') {
            Write-Log 'Wi-Fi driver FAILED_START (often RtlWlanu 5006: version number incorrect). SoftAP cannot start until the radio loads.'
            return $false
        }
    }

    if (-not (Test-WirelessInterfacePresent)) {
        Write-Log 'netsh: no wireless interface on the system'
        return $false
    }
    Write-Log 'Wireless interface present'
    return $true
}

function Get-ShareSourceAdapter {
    param([int]$WaitSeconds)

    $deadline = (Get-Date).AddSeconds([Math]::Max(0, $WaitSeconds))
    do {
        $openVpnTap = Get-NetAdapter -Name 'Local Area Connection' -ErrorAction SilentlyContinue
        if ($openVpnTap -and $openVpnTap.Status -eq 'Up') {
            Write-Log "Share source: OpenVPN TAP ($($openVpnTap.Name))"
            return $openVpnTap
        }
        if ((Get-Date) -ge $deadline) { break }
        Start-Sleep -Seconds 3
    } while ($true)

    Write-Log 'OpenVPN TAP not Up - falling back (VPN left alone)'
    $fallback = Get-NetAdapter -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Status -eq 'Up' -and
            $_.Name -notmatch 'Loopback|vEthernet|Bluetooth|Wi-Fi Direct' -and
            $_.InterfaceDescription -notmatch 'Virtual|Hyper-V|TAP-Windows|Wi-Fi Direct'
        } |
        Sort-Object {
            if ($_.Name -match '^Ethernet') { 0 }
            elseif ($_.Name -match '^Wi-Fi') { 1 }
            else { 2 }
        } |
        Select-Object -First 1

    if ($fallback) {
        Write-Log "Share source fallback: $($fallback.Name)"
        return $fallback
    }
    Write-Log 'WARN: no Up upstream adapter'
    return $null
}

function Set-PreferredPublicInterface {
    param($NetAdapter)
    if (-not $NetAdapter) { return }
    try {
        $interfaceGuid = [guid]$NetAdapter.InterfaceGuid.Trim('{}')
        $registryPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\icssvc\Settings'
        if (-not (Test-Path -LiteralPath $registryPath)) {
            New-Item -Path $registryPath -Force | Out-Null
        }
        New-ItemProperty -Path $registryPath -Name PreferredPublicInterface -PropertyType Binary -Value $interfaceGuid.ToByteArray() -Force | Out-Null
        Write-Log "PreferredPublicInterface={$interfaceGuid} ($($NetAdapter.Name))"
    } catch {
        Write-Log ("PreferredPublicInterface: " + $_.Exception.Message)
    }
}

function Enable-IcsPublicOnAdapter {
    param([string]$AdapterName)
    if ([string]::IsNullOrWhiteSpace($AdapterName)) { return }
    try {
        $share = New-Object -ComObject HNetCfg.HNetShare
        foreach ($connection in @($share.EnumEveryConnection())) {
            $properties = $share.NetConnectionProps.Invoke($connection)
            $configuration = $share.INetSharingConfigurationForINetConnection.Invoke($connection)
            if ($properties.Name -eq $AdapterName -and -not $configuration.SharingEnabled) {
                $configuration.EnableSharing(0)
                Write-Log "ICS Public enabled on $AdapterName"
            }
        }
        Restart-Service icssvc -Force -ErrorAction SilentlyContinue
    } catch {
        Write-Log ("ICS: " + $_.Exception.Message)
    }
}

# --- main ---
Write-Log '=== activate begin ==='

$exePath = Ensure-StartHotspotHelper
if (-not $exePath) {
    Write-Log '=== activate failed (helper) ==='
    exit 2
}

$statusBefore = Get-HotspotStatusText -ExePath $exePath
Write-Log ("status: " + ($statusBefore -replace '\r?\n', ' | '))
if (Test-HotspotOn $statusBefore) {
    Write-Log 'Already On - nothing to do'
    Write-Log '=== activate success ==='
    exit 0
}

if (-not (Repair-WifiRadioBestEffort)) {
    Write-Log '=== activate failed (Wi-Fi radio not usable) ==='
    exit 4
}

$shareSource = Get-ShareSourceAdapter -WaitSeconds $VpnWaitSeconds
Set-PreferredPublicInterface -NetAdapter $shareSource
if ($shareSource) {
    Enable-IcsPublicOnAdapter -AdapterName $shareSource.Name
}

$startOutput = ((& $exePath 2>&1) | Out-String)
Write-Log ("start: " + ($startOutput.Trim() -replace '\r?\n', ' | '))
Write-Log ("exitCode=" + $LASTEXITCODE)
Set-PreferredPublicInterface -NetAdapter $shareSource

$ensureDhcp = Join-Path $logDir 'Ensure-SoftApDhcp.ps1'
if (Test-Path -LiteralPath $ensureDhcp) {
    try {
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $ensureDhcp
        Write-Log 'Ensure-SoftApDhcp invoked'
    } catch {
        Write-Log ("Ensure-SoftApDhcp: " + $_.Exception.Message)
    }
}

$statusAfter = Get-HotspotStatusText -ExePath $exePath
Write-Log ("statusAfter: " + ($statusAfter -replace '\r?\n', ' | '))

if (Test-HotspotOn $statusAfter -or $startOutput -match 'stateAfter=On|ALREADY_ON|startStatus=Success') {
    Write-Log '=== activate success ==='
    exit 0
}

Write-Log '=== activate failed ==='
exit 5
