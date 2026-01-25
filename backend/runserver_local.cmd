@echo off
setlocal
set REPO_ROOT=%~dp0..
set VENV_PY=%REPO_ROOT%\.venv\Scripts\python.exe

if not exist "%VENV_PY%" (
  echo Venv python not found at: %VENV_PY%
  exit /b 1
)

cd /d "%~dp0"
"%VENV_PY%" manage.py runserver 8000
