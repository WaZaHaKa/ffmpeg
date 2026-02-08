@echo off
setlocal EnableExtensions EnableDelayedExpansion
REM main_injection.bat
REM Orchestrates injection pipeline steps.

call "%~dp0inject_config.bat"
if errorlevel 1 exit /b 10

if not exist "%LOG_DIR%" mkdir "%LOG_DIR%" >nul 2>nul
for /f %%t in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "TS=%%t"
set "RUNLOG=%LOG_DIR%\injection_%TS%.log"
break > "%RUNLOG%"

call :log "============================================================"
call :log "INJECTION START"
call :log "INJECT_ROOT=%INJECT_ROOT%"
call :log "RENAMED_DIR=%RENAMED_DIR%"
call :log "LOG_DIR=%LOG_DIR%"
call :log "TOOLS_DIR=%TOOLS_DIR%"
call :log "============================================================"

if "%DO_RENAME%"=="1" (
  call :log "STEP: inject_rename"
  call "%~dp0inject_rename.bat" >> "%RUNLOG%" 2>&1
)

if "%DO_CSV%"=="1" (
  call :log "STEP: inject_report"
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0inject_report.ps1" ^
    -Root "%INJECT_ROOT%" ^
    -RenamedDir "%RENAMED_DIR%" ^
    -Glob "%INJECT_GLOB%" ^
    -Log "%RUNLOG%" >> "%RUNLOG%" 2>&1
)

if "%DO_HASH%"=="1" (
  call :log "STEP: inject_hashes"
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0inject_hashes.ps1" ^
    -RenamedDir "%RENAMED_DIR%" ^
    -Log "%RUNLOG%" >> "%RUNLOG%" 2>&1
)

if "%DO_VERSIONS%"=="1" (
  call :log "STEP: inject_versions"
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0inject_versions.ps1" ^
    -Log "%RUNLOG%" ^
    -Root "%INJECT_ROOT%" ^
    -ToolsDir "%TOOLS_DIR%" >> "%RUNLOG%" 2>&1
)

call :log "============================================================"
call :log "INJECTION END"
call :log "============================================================"

echo [DONE] Injection log: "%RUNLOG%"
exit /b 0

:log
>>"%RUNLOG%" echo [%DATE% %TIME%] %~1
exit /b 0
