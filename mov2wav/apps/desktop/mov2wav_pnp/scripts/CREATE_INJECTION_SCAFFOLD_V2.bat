@echo off
setlocal EnableExtensions

REM ============================================================
REM CREATE_INJECTION_SCAFFOLD_V2.bat
REM - Reliable on paths containing '&'
REM - Creates injection placeholder scripts in:
REM   ...\mov2wav_p&p\scripts
REM ============================================================

set "BASE=C:\Users\theon\Downloads\2026-02-07_1802_split_by_lalalai\mov2wav_p&p"
set "SCRIPTS=%BASE%\scripts"

REM Create folder structure
for %%D in ("%BASE%" "%SCRIPTS%" "%BASE%\tools" "%BASE%\logs" "%BASE%\dist" "%BASE%\build" "%BASE%\src" "%BASE%\renamed_mov") do (
  if not exist "%%~D" mkdir "%%~D" >nul 2>nul
)

echo [OK] Folders ensured:
echo      "%SCRIPTS%"

REM --- Create placeholders (only if missing) ---
call :WriteIfMissing "%SCRIPTS%\main_injection.bat" ^
  "@echo off" ^
  "setlocal EnableExtensions EnableDelayedExpansion" ^
  "REM main_injection.bat (placeholder)" ^
  "REM Orchestrates injection pipeline modules." ^
  "echo [TODO] Implement orchestration: inject_config -> inject_rename -> inject_report -> inject_hashes -> inject_versions" ^
  "exit /b 0"

call :WriteIfMissing "%SCRIPTS%\inject_config.bat" ^
  "@echo off" ^
  "REM inject_config.bat (placeholder)" ^
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
  "REM TODO: rename/move files using NAME_TEMPLATE with collision safety." ^
  "echo [TODO] Implement rename injection here." ^
  "exit /b 0"

call :WriteIfMissing "%SCRIPTS%\inject_report.ps1" ^
  "param(" ^
  "  [Parameter(Mandatory=$true)][string]$Root," ^
  "  [Parameter(Mandatory=$true)][string]$RenamedDir," ^
  "  [Parameter(Mandatory=$true)][string]$Glob," ^
  "  [Parameter(Mandatory=$true)][string]$Log" ^
  ")" ^
  "# inject_report.ps1 (placeholder)" ^
  "# TODO: generate Resolve-friendly CSV mapping and metadata." ^
  "Write-Host '[TODO] inject_report.ps1 not implemented yet.'" ^
  "exit 0"

call :WriteIfMissing "%SCRIPTS%\inject_hashes.ps1" ^
  "param(" ^
  "  [Parameter(Mandatory=$true)][string]$RenamedDir," ^
  "  [Parameter(Mandatory=$true)][string]$Log" ^
  ")" ^
  "# inject_hashes.ps1 (placeholder)" ^
  "# TODO: compute SHA256 hashes CSV for renamed files." ^
  "Write-Host '[TODO] inject_hashes.ps1 not implemented yet.'" ^
  "exit 0"

call :WriteIfMissing "%SCRIPTS%\inject_versions.ps1" ^
  "param(" ^
  "  [Parameter(Mandatory=$true)][string]$Log," ^
  "  [Parameter(Mandatory=$true)][string]$Root," ^
  "  [Parameter(Mandatory=$true)][string]$ToolsDir" ^
  ")" ^
  "# inject_versions.ps1 (placeholder)" ^
  "# TODO: capture tool versions (ffmpeg/ffprobe/bwfmetaedit/python/powershell)." ^
  "Write-Host '[TODO] inject_versions.ps1 not implemented yet.'" ^
  "exit 0"

call :WriteIfMissing "%SCRIPTS%\diag_wrapper.bat" ^
  "@echo off" ^
  "setlocal EnableExtensions EnableDelayedExpansion" ^
  "REM diag_wrapper.bat (placeholder)" ^
  "REM TODO: monitor main_injection.bat and log from 0 byte." ^
  "echo [TODO] Implement diagnostic wrapper here." ^
  "exit /b 0"

echo.
echo [DONE] Injection placeholders created (if missing) in:
echo        "%SCRIPTS%"
echo.
echo Verify:
echo   tree "%BASE%" /F
echo.
exit /b 0

REM ============================================================
REM WriteIfMissing <file> <line1> <line2> ...
REM Writes via PowerShell using a string array (safe with '&')
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
REM remove trailing comma safely by adding empty then trimming in PS
set "PSCMD=%PSCMD% ''); $lines=$lines[0..($lines.Count-2)]; Set-Content -LiteralPath $p -Value $lines -Encoding UTF8"

powershell -NoProfile -ExecutionPolicy Bypass -Command "%PSCMD%"
if exist "%FILE%" (
  echo [OK] Created "%FILE%"
  exit /b 0
) else (
  echo [ERR] Failed to create "%FILE%"
  exit /b 1
)
