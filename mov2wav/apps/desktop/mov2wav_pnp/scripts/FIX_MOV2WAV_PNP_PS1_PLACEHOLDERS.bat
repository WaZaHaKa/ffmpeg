@echo off
setlocal EnableExtensions

set "ROOT=C:\Users\theon\Downloads\2026-02-07_1802_split_by_lalalai\mov2wav_pnp"
set "SCRIPTS=%ROOT%\scripts"

if not exist "%SCRIPTS%" (
  echo [ERR] Missing scripts folder: "%SCRIPTS%"
  exit /b 1
)

echo [INFO] Fixing missing PS1 placeholders in:
echo        "%SCRIPTS%"

call :WritePs1IfMissing "%SCRIPTS%\inject_report.ps1"
call :WritePs1IfMissing "%SCRIPTS%\inject_hashes.ps1"
call :WritePs1IfMissing "%SCRIPTS%\inject_versions.ps1"

echo.
echo [DONE] PS1 placeholders ensured.
echo Verify:
echo   dir "%SCRIPTS%\*.ps1"
echo.
exit /b 0

REM ------------------------------------------------------------
REM WritePs1IfMissing <filepath>
REM Writes file using PowerShell [IO.File]::WriteAllLines to avoid quoting issues
REM ------------------------------------------------------------
:WritePs1IfMissing
set "FILE=%~1"

if exist "%FILE%" (
  echo [SKIP] "%FILE%" already exists
  exit /b 0
)

if /I "%~nx1"=="inject_report.ps1" (
  powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$p='%FILE%';" ^
    "$lines=@(" ^
    "'param('," ^
    "'  [Parameter(Mandatory=$true)][string]$Root,'," ^
    "'  [Parameter(Mandatory=$true)][string]$RenamedDir,'," ^
    "'  [Parameter(Mandatory=$true)][string]$Glob,'," ^
    "'  [Parameter(Mandatory=$true)][string]$Log'," ^
    "' )'," ^
    "'# inject_report.ps1 (placeholder)'," ^
    "'# TODO: generate Resolve-friendly CSV mapping and metadata fields.'," ^
    "'Write-Host ""[TODO] inject_report.ps1 not implemented yet.""'," ^
    "'exit 0'" ^
    ");" ^
    "[IO.File]::WriteAllLines($p,$lines,[Text.Encoding]::UTF8)"
) else if /I "%~nx1"=="inject_hashes.ps1" (
  powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$p='%FILE%';" ^
    "$lines=@(" ^
    "'param('," ^
    "'  [Parameter(Mandatory=$true)][string]$RenamedDir,'," ^
    "'  [Parameter(Mandatory=$true)][string]$Log'," ^
    "' )'," ^
    "'# inject_hashes.ps1 (placeholder)'," ^
    "'# TODO: compute SHA256 manifest CSV for injected outputs.'," ^
    "'Write-Host ""[TODO] inject_hashes.ps1 not implemented yet.""'," ^
    "'exit 0'" ^
    ");" ^
    "[IO.File]::WriteAllLines($p,$lines,[Text.Encoding]::UTF8)"
) else if /I "%~nx1"=="inject_versions.ps1" (
  powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$p='%FILE%';" ^
    "$lines=@(" ^
    "'param('," ^
    "'  [Parameter(Mandatory=$true)][string]$Log,'," ^
    "'  [Parameter(Mandatory=$true)][string]$Root,'," ^
    "'  [Parameter(Mandatory=$true)][string]$ToolsDir'," ^
    "' )'," ^
    "'# inject_versions.ps1 (placeholder)'," ^
    "'# TODO: capture tool versions (ffmpeg/ffprobe/bwfmetaedit/python/powershell).'," ^
    "'Write-Host ""[TODO] inject_versions.ps1 not implemented yet.""'," ^
    "'exit 0'" ^
    ");" ^
    "[IO.File]::WriteAllLines($p,$lines,[Text.Encoding]::UTF8)"
) else (
  echo [ERR] Unknown file: "%FILE%"
  exit /b 2
)

if exist "%FILE%" (
  echo [OK] Created "%FILE%"
  exit /b 0
) else (
  echo [ERR] Failed to create "%FILE%"
  exit /b 1
)
