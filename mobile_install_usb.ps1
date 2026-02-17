[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$DeviceId,

    [Parameter(Mandatory = $false)]
    [string]$PackageName,

    [Parameter(Mandatory = $false)]
    [string]$ApkPath,

    [Parameter(Mandatory = $false)]
    [ValidateSet('debug', 'profile', 'release')]
    [string]$Mode = 'release',

    [Parameter(Mandatory = $false)]
    [switch]$Clean,

    [Parameter(Mandatory = $false)]
    [switch]$UninstallFirst,

    [Parameter(Mandatory = $false)]
    [switch]$GrantPermissions,

    [Parameter(Mandatory = $false)]
    [switch]$AllowDowngrade,

    [Parameter(Mandatory = $false)]
    [switch]$Launch
)

$ErrorActionPreference = 'Stop'

function Assert-Command {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string]$InstallHint
    )

    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Missing required command '$Name'. $InstallHint"
    }
}

function Write-Step {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Cyan
}

function Write-Warn {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Yellow
}

function Write-Ok {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Green
}

function Get-PackageNameFromGradle {
    param(
        [Parameter(Mandatory = $true)]
        [string]$GradleFilePath
    )

    if (-not (Test-Path $GradleFilePath)) {
        return $null
    }

    $content = Get-Content -LiteralPath $GradleFilePath -ErrorAction Stop
    foreach ($line in $content) {
        if ($line -match '^\s*applicationId\s*=\s*"([^"]+)"\s*$') {
            return $Matches[1]
        }
    }
    return $null
}

function Get-AdbDevices {
    # Returns array of objects: { Id, State, Raw }
    $lines = & adb devices -l 2>$null
    if (-not $lines) {
        return @()
    }

    $deviceLines = @($lines | Select-Object -Skip 1 | Where-Object { $_ -match '\S+' })
    $devices = @()

    foreach ($line in $deviceLines) {
        # Typical: <serial>\tdevice ...
        if ($line -match '^(\S+)\s+(\S+)') {
            $devices += [pscustomobject]@{
                Id = $Matches[1]
                State = $Matches[2]
                Raw = $line
            }
        }
    }

    return $devices
}

function Get-AdbDeviceId {
    $devices = Get-AdbDevices
    $online = @($devices | Where-Object { $_.State -eq 'device' })

    if ($online.Count -eq 1) { return $online[0].Id }

    if ($online.Count -gt 1) {
        Write-Warn "Multiple Android devices detected. Choose one or pass -DeviceId."
        for ($i = 0; $i -lt $online.Count; $i++) {
            Write-Host "[$($i + 1)] $($online[$i].Id)" -ForegroundColor Yellow
        }
        $choice = Read-Host "Select device number"
        if ($choice -match '^\d+$') {
            $index = [int]$choice - 1
            if ($index -ge 0 -and $index -lt $online.Count) {
                return $online[$index].Id
            }
        }
        throw "Invalid selection. Re-run and pass -DeviceId <serial>."
    }

    return $null
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
        $devices = Get-AdbDevices
        $known = $devices | Where-Object { $_.Id -eq $Id } | Select-Object -First 1
        $knownState = if ($known) { $known.State } else { $null }

        $hint = "Unplug/replug USB, unlock the phone, enable USB debugging, and accept the RSA prompt."
        if ($knownState -eq 'unauthorized') {
            $hint = "Device is unauthorized. Unlock phone and accept 'Allow USB debugging' prompt, then retry."
        } elseif ($knownState -eq 'offline') {
            $hint = "Device is offline. Toggle USB debugging off/on or reconnect USB, then retry."
        }

        throw "Android device '$Id' is not online (adb get-state: '$state', adb devices state: '$knownState'). $hint"
    }
}

$mobilePath = Join-Path $PSScriptRoot 'mobile'
if (-not (Test-Path $mobilePath)) {
    throw "Could not find 'mobile' directory at: $mobilePath"
}

Assert-Command -Name adb -InstallHint "Install Android Platform-Tools (adb) and add it to PATH, then re-run."

if (-not $ApkPath) {
    Assert-Command -Name flutter -InstallHint "Install Flutter and ensure 'flutter' is on PATH, then re-run."
}

Push-Location $mobilePath
try {
    if (-not $PackageName) {
        $gradlePath = Join-Path (Join-Path $mobilePath 'android') (Join-Path 'app' 'build.gradle.kts')
        $PackageName = Get-PackageNameFromGradle -GradleFilePath $gradlePath
        if (-not $PackageName) {
            $PackageName = 'com.nawafeth.app'
        }
        Write-Host "Using package name: $PackageName" -ForegroundColor Cyan
    }

    if (-not $DeviceId) {
        $DeviceId = Get-AdbDeviceId
        if ($DeviceId) {
            Write-Host "Using Android device via adb: $DeviceId" -ForegroundColor Cyan
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
            Write-Warn "No Android device detected. Connect the phone via USB, enable USB debugging, then re-run."
            Write-Warn "Tip: ensure Android SDK platform-tools (adb) is installed and on PATH."
            try { flutter devices } catch {}
            try { adb devices } catch {}
            exit 1
        }

        $DeviceId = $androidDevices[0].id
        Write-Host "Using detected Android device via flutter: $DeviceId" -ForegroundColor Cyan
    }

    Assert-AdbDeviceOnline -Id $DeviceId

    if ($UninstallFirst) {
        Write-Step "Uninstalling old app '$PackageName' from device '$DeviceId' (will clear app data)..."
        & adb -s $DeviceId uninstall $PackageName | Out-Host
        if ($LASTEXITCODE -ne 0) {
            Write-Warn "Uninstall step failed (exit code $LASTEXITCODE). App may not be installed. Continuing..."
        }
    } else {
        Write-Step "Updating app in-place (no uninstall; keeps app data)."
    }

    if (-not $ApkPath) {
        if ($Clean) {
            Write-Step "Running flutter clean..."
            flutter clean
        }

        Write-Step "Running flutter pub get..."
        flutter pub get

        $modeFlag = "--$Mode"
        Write-Step "Building APK ($Mode)..."
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

        $ApkPath = Join-Path (Join-Path (Join-Path (Join-Path 'build' 'app') 'outputs') 'flutter-apk') $apkName
    }

    if (-not (Test-Path -LiteralPath $ApkPath)) {
        throw "APK not found at: $ApkPath"
    }

    $resolvedApkPath = (Resolve-Path -LiteralPath $ApkPath).Path

    $installArgs = @('-s', $DeviceId, 'install', '-r')
    if ($AllowDowngrade) { $installArgs += '-d' }
    if ($GrantPermissions) { $installArgs += '-g' }
    $installArgs += $resolvedApkPath

    Write-Step "Installing APK to device '$DeviceId'..."
    & adb @installArgs | Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "adb install failed (exit code $LASTEXITCODE)."
    }

    if ($Launch) {
        Write-Step "Launching app '$PackageName'..."
        & adb -s $DeviceId shell monkey -p $PackageName -c android.intent.category.LAUNCHER 1 | Out-Host
    }

    Write-Ok "Done."
} finally {
    Pop-Location
}
