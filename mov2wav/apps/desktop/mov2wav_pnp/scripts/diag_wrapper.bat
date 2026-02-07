@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM ============================================================
REM diag_wrapper.bat
REM - Creates a 0-byte log immediately
REM - Runs main.bat and captures ALL stdout+stderr to the log
REM - Creates per-run artifact folder and copies outputs
REM Exit codes:
REM   returns main.bat exit code
REM ============================================================

call "%~dp0env.bat"

REM Ensure base folders exist
for %%D in ("%LOGS%" "%OUT_WAV%" "%TOOLS%" "%DIST%" "%BUILD%" "%SRC%") do (
  if not exist "%%~D" mkdir "%%~D" >nul 2>nul
)

REM Timestamp / Run ID
for /f %%t in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "TS=%%t"
set "RUNID=%TS%_%RANDOM%%RANDOM%"

set "RUNROOT=%LOGS%\run_%RUNID%"
set "RUNLOG=%RUNROOT%\diag_%RUNID%.log"

mkdir "%RUNROOT%" >nul 2>nul

REM Create 0-byte log from byte 0
break > "%RUNLOG%"

call :log "============================================================"
call :log "DIAG WRAPPER START"
call :log "RUNID=%RUNID%"
call :log "PROJ=%PROJ%"
call :log "INPUT_DIR=%INPUT_DIR%"
call :log "RUNROOT=%RUNROOT%"
call :log "RUNLOG=%RUNLOG%"
call :log "============================================================"
call :log "TIP: If you run from PowerShell, call:  .\scripts\diag_wrapper.bat"
call :log ""

REM Run main.bat and capture everything
call :log "---- INVOKING MAIN ----"
call :log "CMD: %~dp0main.bat"
call :log ""

REM We must call via cmd /c to reliably capture the full stream into a file
cmd /c ""%~dp0main.bat"" >> "%RUNLOG%" 2>&1
set "EC=%ERRORLEVEL%"

call :log ""
call :log "---- MAIN EXIT CODE: %EC% ----"
call :log "---- COLLECTING ARTIFACTS ----"

REM Artifacts folder within per-run folder
set "ART=%RUNROOT%\artifacts"
mkdir "%ART%" >nul 2>nul

REM Copy latest Resolve CSV + hashes CSV generated during this run (best effort)
call :copy_latest "%OUT_WAV%" "resolve_conform_report_*.csv" "%ART%"
call :copy_latest "%OUT_WAV%" "wav_hashes_*.csv" "%ART%"

REM Copy latest versions JSON (best effort)
call :copy_latest "%LOGS%" "versions_*.json" "%ART%"

REM Snapshot key scripts used (optional but useful)
set "SCRIPTSNAP=%RUNROOT%\scripts_snapshot"
mkdir "%SCRIPTSNAP%" >nul 2>nul
copy /y "%~dp0env.bat" "%SCRIPTSNAP%\" >nul 2>nul
copy /y "%~dp0main.bat" "%SCRIPTSNAP%\" >nul 2>nul
copy /y "%~dp0step_preflight.bat" "%SCRIPTSNAP%\" >nul 2>nul
copy /y "%~dp0step_ensure_tools.bat" "%SCRIPTSNAP%\" >nul 2>nul
copy /y "%~dp0step_ensure_tools.ps1" "%SCRIPTSNAP%\" >nul 2>nul
copy /y "%~dp0step_versions.ps1" "%SCRIPTSNAP%\" >nul 2>nul
copy /y "%~dp0step_convert.ps1" "%SCRIPTSNAP%\" >nul 2>nul
copy /y "%~dp0step_hashes.ps1" "%SCRIPTSNAP%\" >nul 2>nul

call :log "[OK] Artifacts folder: %ART%"
call :log "[OK] Wrapper log     : %RUNLOG%"
call :log "============================================================"
call :log "DIAG WRAPPER END"
call :log "============================================================"

echo.
echo [DONE] RunID: %RUNID%
echo [DONE] Log  : "%RUNLOG%"
echo [DONE] Art  : "%ART%"
echo [DONE] Exit : %EC%
echo.

exit /b %EC%

REM ---------------- helpers ----------------

:log
>>"%RUNLOG%" echo [%DATE% %TIME%] %~1
exit /b 0

:copy_latest
REM args: %1=dir, %2=pattern, %3=dest
set "SRCD=%~1"
set "PATT=%~2"
set "DEST=%~3"

if not exist "%SRCD%\" (
  call :log "[WARN] Missing folder: %SRCD%"
  exit /b 0
)

set "LATEST="
for /f "delims=" %%F in ('dir /b /a:-d /o:-d "%SRCD%\%PATT%" 2^>nul') do (
  set "LATEST=%%F"
  goto :copy_do
)

call :log "[WARN] No match: %SRCD%\%PATT%"
exit /b 0

:copy_do
copy /y "%SRCD%\%LATEST%" "%DEST%\" >nul 2>nul
if errorlevel 1 (
  call :log "[WARN] Copy failed: %SRCD%\%LATEST% -> %DEST%"
) else (
  call :log "[OK] Copied: %LATEST% -> %DEST%"
)
exit /b 0
