@echo off
setlocal EnableExtensions EnableDelayedExpansion

call "%~dp0env.bat"

REM If wrapper already set RUNLOG, keep it. Otherwise create our own.
if defined RUNLOG (
  set "RUNLOG=%RUNLOG%"
) else (
  for /f %%t in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "TS=%%t"
  set "RUNLOG=%LOGS%\run_%TS%.log"
)

REM Ensure base folders exist
for %%D in ("%TOOLS%" "%LOGS%" "%OUT_WAV%" "%DIST%" "%BUILD%" "%SRC%") do (
  if not exist "%%~D" mkdir "%%~D" >nul 2>nul
)

REM Create 0-byte runlog only if it does not exist yet
if not exist "%RUNLOG%" break > "%RUNLOG%"


call :log "============================================================"
call :log "MOV2WAV MAIN START"
call :log "PROJ=%PROJ%"
call :log "INPUT_DIR=%INPUT_DIR%"
call :log "OUT_WAV=%OUT_WAV%"
call :log "RUNLOG=%RUNLOG%"
call :log "============================================================"

REM --- Step order (each is modular) ---
REM 1) preflight (checks inputs/tools)
call :log "STEP 1: preflight"
call "%~dp0step_preflight.bat" "%RUNLOG%"
if errorlevel 1 exit /b 10

REM 2) ensure tools (download portable binaries if missing)
call :log "STEP 2: ensure_tools"
call "%~dp0step_ensure_tools.bat" "%RUNLOG%"
if errorlevel 1 exit /b 20

REM 3) versions snapshot
if "%DO_VERSIONS%"=="1" (
  call :log "STEP 3: versions"
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0step_versions.ps1" -Proj "%PROJ%" -Log "%RUNLOG%" >> "%RUNLOG%" 2>&1
)

REM 4) convert (MOV -> WAV + metadata + CSV)
call :log "STEP 4: convert"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0step_convert.ps1" -Proj "%PROJ%" -Input "%INPUT_DIR%" -Log "%RUNLOG%" >> "%RUNLOG%" 2>&1
if errorlevel 1 exit /b 40

REM 5) hashes
if "%DO_HASH%"=="1" (
  call :log "STEP 5: hashes"
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0step_hashes.ps1" -Proj "%PROJ%" -Log "%RUNLOG%" >> "%RUNLOG%" 2>&1
  if errorlevel 1 exit /b 50
)

call :log "============================================================"
call :log "MOV2WAV MAIN END OK"
call :log "============================================================"
echo [DONE] Log: "%RUNLOG%"
exit /b 0

:log
>>"%RUNLOG%" echo [%DATE% %TIME%] %~1
echo [%DATE% %TIME%] %~1
exit /b 0

