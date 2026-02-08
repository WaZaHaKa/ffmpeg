@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM ============================================================
REM step_ensure_tools.bat
REM - Ensures portable tools exist in .\tools:
REM   ffmpeg.exe, ffprobe.exe, bwfmetaedit.exe
REM - Delegates download/extract to PowerShell (robust on Windows)
REM Exit codes:
REM   0  OK
REM   21 PowerShell downloader failed
REM ============================================================

set "RUNLOG=%~1"
if "%RUNLOG%"=="" (
  echo [ensure_tools][ERR] RUNLOG argument missing
  exit /b 99
)

call "%~dp0env.bat"

>>"%RUNLOG%" echo [%DATE% %TIME%] ---- ENSURE_TOOLS ----
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0step_ensure_tools.ps1" -Proj "%PROJ%" -Log "%RUNLOG%"
set "EC=%ERRORLEVEL%"

>>"%RUNLOG%" echo [%DATE% %TIME%] ensure_tools exit=%EC%
if not "%EC%"=="0" exit /b 21
exit /b 0
