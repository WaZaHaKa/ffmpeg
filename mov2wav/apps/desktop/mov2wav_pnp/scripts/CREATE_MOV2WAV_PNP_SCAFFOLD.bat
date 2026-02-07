@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM ============================================================
REM CREATE_MOV2WAV_PNP_SCAFFOLD.bat
REM - Creates a compatibility-safe project folder: mov2wav_pnp
REM - Creates folder structure + placeholder scripts (modular)
REM - No '&' in paths, no here-strings passed via CMD args
REM ============================================================

set "ROOT=C:\Users\theon\Downloads\2026-02-07_1802_split_by_lalalai"
set "BASE=%ROOT%\mov2wav_pnp"
set "SCRIPTS=%BASE%\scripts"

REM --- Create directories (idempotent) ---
for %%D in ("%BASE%" "%SCRIPTS%" "%BASE%\tools" "%BASE%\logs" "%BASE%\dist" "%BASE%\build" "%BASE%\src" "%BASE%\renamed_mov" "%BASE%\out_wav") do (
  if not exist "%%~D" mkdir "%%~D" >nul 2>nul
)

echo [OK] Folder structure ensured:
echo      "%BASE%"

REM --- Create placeholder scripts (only if missing) ---
call :WriteIfMissing "%SCRIPTS%\diag_wrapper.bat" ^
  "@echo off" ^
  "setlocal EnableExtensions EnableDelayedExpansion" ^
  "REM diag_wrapper.bat (placeholder)" ^
  "REM Design: wrapper logs from 0 bytes and monitors main orchestration." ^
  "echo [TODO] Implement diagnostic wrapper that calls main_injection.bat/main.bat with full logging." ^
  "exit /b 0"

call :WriteIfMissing "%SCRIPTS%\main_injection.bat" ^
  "@echo off" ^
  "setlocal EnableExtensions EnableDelayedExpansion" ^
  "REM main_injection.bat (placeholder)" ^
  "REM Design: modular injection pipeline orchestrator." ^
  "REM Steps: inject_config -> inject_rename -> inject_report -> inject_hashes -> inject_versions" ^
  "echo [TODO] Implement injection orchestration here." ^
  "exit /b 0"

call :WriteIfMissing "%SCRIPTS%\inject_config.bat" ^
  "@echo off" ^
  "REM inject_config.bat (placeholder)" ^
  "REM Central config for naming scheme + toggles." ^
  "set ""INJECT_ROOT=%%CD%%""" ^
  "set ""INJECT_GLOB=*.mov""" ^
  "set ""RENAMED_DIR=%%INJECT_ROOT%%\renamed_mov""" ^
  "set ""LOG_DIR=%%INJECT_ROOT%%\logs""" ^
  "set ""NAME_TEMPLATE={date}_{time}_{n}_{stem}""" ^
  "set ""DO_RENAME=1""" ^
  "set ""DO_CSV=1""" ^
  "set ""DO_HASH=1""" ^
  "set ""DO_VERSIONS=1""" ^
  "set ""TOOLS_DIR=%%INJECT_ROOT%%\tools"""

call :WriteIfMissing "%SCRIPTS%\inject_rename.bat" ^
  "@echo off" ^
  "setlocal EnableExtensions EnableDelayedExpansion" ^
  "REM inject_rename.bat (placeholder)" ^
  "REM Design: safe rename/move with collision avoidance + deterministic numbering." ^
  "echo [TODO] Implement renaming injection logic here." ^
  "exit /b 0"

call :WriteIfMissing "%SCRIPTS%\inject_report.ps1" ^
  "param(" ^
  "  [Parameter(Mandatory=$true)][string]$Root," ^
  "  [Parameter(Mandatory=$true)][string]$RenamedDir," ^
  "  [Parameter(Mandatory=$true)][string]$Glob," ^
  "  [Parameter(Mandatory=$true)][string]$Log" ^
  ")" ^
  "# inject_report.ps1 (placeholder)" ^
  "# Design: produce Resolve-friendly CSV mapping + metadata fields." ^
  "Write-Host '[TODO] inject_report.ps1 not implemented yet.'" ^
  "exit 0"

call :WriteIfMissing "%SCRIPTS%\inject_hashes.ps1" ^
  "param(" ^
  "  [Parameter(Mandatory=$true)][string]$RenamedDir," ^
  "  [Parameter(Mandatory=$true)][string]$Log" ^
  ")" ^
  "# inject_hashes.ps1 (placeholder)" ^
  "# Design: compute SHA256 manifest CSV for injected outputs." ^
  "Write-Host '[TODO] inject_hashes.ps1 not implemented yet.'" ^
  "exit 0"

call :WriteIfMissing "%SCRIPTS%\inject_versions.ps1" ^
  "param(" ^
  "  [Parameter(Mandatory=$true)][string]$Log," ^
  "  [Parameter(Mandatory=$true)][string]$Root," ^
  "  [Parameter(Mandatory=$true)][string]$ToolsDir" ^
  ")" ^
  "# inject_versions.ps1 (placeholder)" ^
  "# Design: capture tool versions (ffmpeg/ffprobe/bwfmetaedit/python/powershell)." ^
  "Write-Host '[TODO] inject_versions.ps1 not implemented yet.'" ^
  "exit 0"

REM Optional: main build orchestrator placeholder (keeps system modular)
call :WriteIfMissing "%SCRIPTS%\mov2wavconverter_main.bat" ^
  "@echo off" ^
  "setlocal EnableExtensions EnableDelayedExpansion" ^
  "REM mov2wavconverter_main.bat (placeholder)" ^
  "REM Design: downloads tools, builds MOV2WAV.exe, runs pipeline." ^
  "echo [TODO] Implement build pipeline here." ^
  "exit /b 0"

echo.
echo [DONE] mov2wav_pnp scaffold created.
echo Base:
echo   "%BASE%"
echo Scripts:
echo   "%SCRIPTS%"
echo.
echo Verify with:
echo   tree "%BASE%" /F
echo.
exit /b 0

REM ============================================================
REM WriteIfMissing <file> <line1> <line2> ...
REM Writes files via PowerShell using string arrays (robust).
REM ============================================================
:WriteIfMissing
set "FILE=%~1"
shift

if exist "%FILE%" (
  echo [SKIP] "%FILE%" already exists
  exit /b 0
)

set "PSCMD=$p='%FILE%'; $lines=@("
:collect
if "%~1"=="" goto write
set "PSCMD=%PSCMD% '%~1',"
shift
goto collect

:write
set "PSCMD=%PSCMD% ''); $lines=$lines[0..($lines.Count-2)]; Set-Content -LiteralPath $p -Value $lines -Encoding UTF8"

powershell -NoProfile -ExecutionPolicy Bypass -Command "%PSCMD%"
if exist "%FILE%" (
  echo [OK] Created "%FILE%"
  exit /b 0
) else (
  echo [ERR] Failed to create "%FILE%"
  exit /b 1
)
