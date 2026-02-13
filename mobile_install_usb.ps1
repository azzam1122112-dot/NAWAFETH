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

function Assert-AdbDeviceOnline {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Id
    )

    $state = $null
    try {
        $state = (& adb -s $Id get-state 2>$null | Select-Object -First 1)
    } catch {
        $state = $null
    }

    if ($state -ne 'device') {
        throw "Android device '$Id' is not online (adb state: '$state'). Unplug/replug USB, unlock phone, and accept the USB debugging prompt, then retry."
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

    Assert-AdbDeviceOnline -Id $DeviceId

    Write-Host "Uninstalling old app '$PackageName' from device '$DeviceId'..." -ForegroundColor Cyan
    & adb -s $DeviceId uninstall $PackageName | Out-Host
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Uninstall step failed (exit code $LASTEXITCODE). App may not be installed or device had a transient issue. Continuing..."
    }

    Write-Host "Running flutter pub get..." -ForegroundColor Cyan
    flutter pub get

    $modeFlag = "--$Mode"
    Write-Host "Building APK ($Mode)..." -ForegroundColor Cyan
    flutter build apk $modeFlag
    if ($LASTEXITCODE -ne 0) {
        throw "flutter build apk failed (exit code $LASTEXITCODE)."
    }

    $apkName = switch ($Mode) {
        'debug' { 'app-debug.apk' }
        'profile' { 'app-profile.apk' }
        'release' { 'app-release.apk' }
        default { throw "Unsupported Mode: $Mode" }
    }
    $apkPath = Join-Path (Join-Path (Join-Path (Join-Path 'build' 'app') 'outputs') 'flutter-apk') $apkName
    if (-not (Test-Path $apkPath)) {
        throw "Built APK not found at: $apkPath"
    }

    Write-Host "Installing APK to device '$DeviceId'..." -ForegroundColor Cyan
    & adb -s $DeviceId install -r $apkPath | Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "adb install failed (exit code $LASTEXITCODE)."
    }
} finally {
    Pop-Location
}
