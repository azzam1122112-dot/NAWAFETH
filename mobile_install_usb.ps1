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

    # Stronger clean: implies -Clean and -UninstallFirst for a 100% fresh install.
    [Parameter(Mandatory = $false)]
    [switch]$FullClean,

    [Parameter(Mandatory = $false)]
    [switch]$UninstallFirst,

    [Parameter(Mandatory = $false)]
    [switch]$GrantPermissions,

    [Parameter(Mandatory = $false)]
    [switch]$AllowDowngrade,

    [Parameter(Mandatory = $false)]
    [switch]$Launch,

    # Build-time API base URL override (passed to Flutter via --dart-define)
    # Example: http://127.0.0.1:8000  (use with adb reverse)
    [Parameter(Mandatory = $false)]
    [string]$ApiBaseUrl,

    # Convenience: Local mode sets ApiBaseUrl=http://127.0.0.1:8000 and enables adb reverse.
    [Parameter(Mandatory = $false)]
    [switch]$Local,

    # Enable adb reverse for local backend reachability from a physical Android device.
    [Parameter(Mandatory = $false)]
    [switch]$AdbReverse,

    # Port used for adb reverse mapping (tcp:<port> -> tcp:<port>)
    [Parameter(Mandatory = $false)]
    [int]$ReversePort = 8000,

    # Optionally start local Django backend (dev server) on 0.0.0.0:<BackendPort>
    [Parameter(Mandatory = $false)]
    [switch]$StartBackend,

    [Parameter(Mandatory = $false)]
    [int]$BackendPort = 8000
)

$ErrorActionPreference = 'Stop'

# Avoid treating native stderr output as terminating errors.
if ($PSVersionTable.PSVersion.Major -ge 7) {
    $PSNativeCommandUseErrorActionPreference = $false
}

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

function Start-AdbServer {
    try {
        # Some environments print daemon startup logs to stderr/stdout; ignore and continue.
        & adb start-server 2>$null | Out-Null
    } catch {
        # Non-fatal: device detection will still fail later with a clearer message.
    }
}

function Remove-PathWithRetry {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $false)]
        [int]$Retries = 4,

        [Parameter(Mandatory = $false)]
        [int]$DelayMs = 250
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }

    for ($attempt = 1; $attempt -le $Retries; $attempt++) {
        try {
            Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
            return
        } catch {
            if ($attempt -eq $Retries) {
                Write-Warn "Failed to remove '$Path' after $Retries attempts. It may be locked by another process."
                return
            }
            Start-Sleep -Milliseconds $DelayMs
        }
    }
}

function Test-LocalPortOpen {
    param(
        [Parameter(Mandatory = $true)]
        [int]$Port
    )

    try {
        return (Test-NetConnection -ComputerName '127.0.0.1' -Port $Port -InformationLevel Quiet)
    } catch {
        return $false
    }
}

function Start-LocalBackendServer {
    param(
        [Parameter(Mandatory = $true)]
        [int]$Port
    )

    if (Test-LocalPortOpen -Port $Port) {
        Write-Warn "Backend already appears to be running on port $Port. Skipping start."
        return
    }

    $repoRoot = $PSScriptRoot
    $backendPath = Join-Path $repoRoot 'backend'
    if (-not (Test-Path $backendPath)) {
        Write-Warn "Backend folder not found at: $backendPath. Skipping backend start."
        return
    }

    $venvPython = Join-Path $repoRoot '.venv\Scripts\python.exe'
    $pythonExe = if (Test-Path $venvPython) { $venvPython } else { 'python' }

    $managePy = Join-Path $backendPath 'manage.py'
    if (-not (Test-Path $managePy)) {
        Write-Warn "manage.py not found at: $managePy. Skipping backend start."
        return
    }

    $processArgs = @('manage.py', 'runserver', "0.0.0.0:$Port")
    Write-Step "Starting local backend on 0.0.0.0:$Port (background)..."
    try {
        $p = Start-Process -FilePath $pythonExe -ArgumentList $processArgs -WorkingDirectory $backendPath -WindowStyle Minimized -PassThru
        Write-Ok "Backend started (PID $($p.Id))."
    } catch {
        Write-Warn "Failed to start backend automatically. You can run: cd backend; python manage.py runserver 0.0.0.0:$Port"
    }
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
    $lines = & adb devices -l 2>&1
    if (-not $lines) {
        return @()
    }

    # Filter out daemon startup noise (e.g., '* daemon not running; starting now...')
    $lines = @($lines | Where-Object { $_ -and ($_ -notmatch '^\*\s+daemon\s+') })

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

Start-AdbServer

if ($FullClean) {
    $Clean = $true
    $UninstallFirst = $true
}

if ($Local) {
    if (-not $ApiBaseUrl) {
        $ApiBaseUrl = 'http://127.0.0.1:8000'
    }
    $AdbReverse = $true
    $StartBackend = $true
    $ReversePort = 8000
    $BackendPort = 8000
}

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

    if ($StartBackend) {
        Start-LocalBackendServer -Port $BackendPort
    }

    if ($AdbReverse) {
        Write-Step "Setting adb reverse tcp:$ReversePort -> tcp:$ReversePort for device '$DeviceId'..."
        try {
            & adb -s $DeviceId reverse "tcp:$ReversePort" "tcp:$ReversePort" | Out-Null
        } catch {
            Write-Warn "adb reverse failed. If you're using a local backend, the phone may not reach it."
        }
    } else {
        # Avoid stale reverse mappings from previous local runs (can cause confusing networking behavior).
        try {
            & adb -s $DeviceId reverse --remove "tcp:$ReversePort" 2>$null | Out-Null
        } catch {
            # Non-fatal
        }
    }

    if ($UninstallFirst) {
        Write-Step "Uninstalling old app '$PackageName' from device '$DeviceId' (will clear app data)..."
        & adb -s $DeviceId uninstall $PackageName | Out-Host
        if ($LASTEXITCODE -ne 0) {
            Write-Warn "Uninstall step failed (exit code $LASTEXITCODE). App may not be installed. Continuing..."
        }
    } else {
        Write-Step "Updating app in-place (no uninstall; keeps app data)."

        if ($Clean) {
            Write-Step "Clearing app data for '$PackageName' (clean install without uninstall)..."
            try {
                & adb -s $DeviceId shell pm clear $PackageName | Out-Host
            } catch {
                Write-Warn "Could not clear app data (pm clear). App may not be installed yet. Continuing..."
            }
        }
    }

    if (-not $ApkPath) {
        if ($Clean) {
            Write-Step "Running flutter clean..."
            flutter clean

            # flutter clean may fail to remove build if files are locked (Windows). Best-effort retry.
            $buildDir = Join-Path $mobilePath 'build'
            if (Test-Path -LiteralPath $buildDir) {
                Write-Step "Removing build folder (best-effort)..."
                Remove-PathWithRetry -Path $buildDir -Retries 6 -DelayMs 350
            }
        }

        Write-Step "Running flutter pub get..."
        flutter pub get

        $modeFlag = "--$Mode"
        Write-Step "Building APK ($Mode)..."
        $buildArgs = @('build', 'apk', $modeFlag)
        if ($ApiBaseUrl -and $ApiBaseUrl.Trim().Length -gt 0) {
            Write-Host "Using API_BASE_URL=$ApiBaseUrl" -ForegroundColor Cyan
            $buildArgs += "--dart-define=API_BASE_URL=$ApiBaseUrl"
        }

        flutter @buildArgs
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
