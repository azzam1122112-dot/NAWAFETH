[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$DeviceId,

    [Parameter(Mandatory = $false)]
    [ValidateSet('debug', 'profile', 'release')]
    [string]$Mode = 'release'
)

$ErrorActionPreference = 'Stop'

$mobilePath = Join-Path $PSScriptRoot 'mobile'
if (-not (Test-Path $mobilePath)) {
    throw "Could not find 'mobile' directory at: $mobilePath"
}

Push-Location $mobilePath
try {
    $devices = @()
    try {
        $devices = (flutter devices --machine | ConvertFrom-Json)
    } catch {
        Write-Warning "Could not parse 'flutter devices --machine'. Falling back to manual device id." 
        $devices = @()
    }

    if (-not $DeviceId) {
        $androidDevices = @($devices | Where-Object { $_.targetPlatform -like 'android-*' })
        if ($androidDevices.Count -eq 0) {
            Write-Host "No Android device detected. Connect the phone via USB and enable USB debugging." -ForegroundColor Yellow
            flutter devices
            exit 1
        }

        $DeviceId = $androidDevices[0].id
        Write-Host "Using detected Android device: $DeviceId" -ForegroundColor Cyan
    }

    Write-Host "Running flutter pub get..." -ForegroundColor Cyan
    flutter pub get

    $modeFlag = "--$Mode"
    Write-Host "Installing ($Mode) to device '$DeviceId'..." -ForegroundColor Cyan
    flutter install -d $DeviceId $modeFlag
} finally {
    Pop-Location
}
