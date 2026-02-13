[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$DeviceId,

    [Parameter(Mandatory = $false)]
    [string]$PackageName = 'com.nawafeth.app',

    [Parameter(Mandatory = $false)]
    [ValidateSet('debug', 'profile', 'release')]
    [string]$Mode = 'release'
)

$ErrorActionPreference = 'Stop'

function Get-AdbDeviceId {
    try {
        $lines = & adb devices 2>$null
        if (-not $lines) {
            return $null
        }

        $deviceLines = @($lines | Select-Object -Skip 1 | Where-Object { $_ -match '\S+' })
        $online = @(
            foreach ($line in $deviceLines) {
                if ($line -match '^(\S+)\s+device\s*$') {
                    $Matches[1]
                }
            }
        )

        if ($online.Count -eq 1) { return $online[0] }
        if ($online.Count -gt 1) {
            throw "Multiple Android devices detected via adb. Please pass -DeviceId. Devices: $($online -join ', ')"
        }
        return $null
    } catch {
        return $null
    }
}

$mobilePath = Join-Path $PSScriptRoot 'mobile'
if (-not (Test-Path $mobilePath)) {
    throw "Could not find 'mobile' directory at: $mobilePath"
}

Push-Location $mobilePath
try {
    if (-not $DeviceId) {
        $DeviceId = Get-AdbDeviceId
        if ($DeviceId) {
            Write-Host "Using detected Android device via adb: $DeviceId" -ForegroundColor Cyan
        }
    }

    if (-not $DeviceId) {
        $devices = @()
        try {
            $devices = (flutter devices --machine | ConvertFrom-Json)
        } catch {
            Write-Warning "Could not parse 'flutter devices --machine'." 
            $devices = @()
        }

        $androidDevices = @($devices | Where-Object { $_.targetPlatform -like 'android-*' })
        if ($androidDevices.Count -eq 0) {
            Write-Host "No Android device detected. Connect the phone via USB, enable USB debugging, then re-run." -ForegroundColor Yellow
            Write-Host "Tip: ensure Android SDK platform-tools (adb) is installed and on PATH." -ForegroundColor Yellow
            try { flutter devices } catch {}
            try { adb devices } catch {}
            exit 1
        }

        $DeviceId = $androidDevices[0].id
        Write-Host "Using detected Android device via flutter: $DeviceId" -ForegroundColor Cyan
    }

    Write-Host "Uninstalling old app '$PackageName' from device '$DeviceId'..." -ForegroundColor Cyan
    try {
        & adb -s $DeviceId uninstall $PackageName | Out-Host
    } catch {
        Write-Warning "Uninstall step failed (app may not be installed). Continuing..."
    }

    Write-Host "Running flutter pub get..." -ForegroundColor Cyan
    flutter pub get

    $modeFlag = "--$Mode"
    Write-Host "Installing ($Mode) to device '$DeviceId'..." -ForegroundColor Cyan
    flutter install -d $DeviceId $modeFlag
} finally {
    Pop-Location
}
