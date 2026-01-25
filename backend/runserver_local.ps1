$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$venvPython = Join-Path $repoRoot '.venv\Scripts\python.exe'

if (-not (Test-Path $venvPython)) {
  throw "Venv python not found at: $venvPython"
}

Set-Location $PSScriptRoot
& $venvPython manage.py runserver 0.0.0.0:8000
