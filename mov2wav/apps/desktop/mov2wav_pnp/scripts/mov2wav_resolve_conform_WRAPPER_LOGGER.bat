@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM ============================================================
REM SAFE WRAPPER LOGGER
REM - Runs inner BAT in a clean cmd.exe
REM - Captures 100% stdout + stderr
REM - Avoids CMD parser corruption
REM ============================================================

set "WORKDIR=%CD%"
set "INNER_BAT=%WORKDIR%\mov2wav_resolve_conform.bat"
set "LOGDIR=%WORKDIR%\logs"

if not exist "%LOGDIR%" mkdir "%LOGDIR%" >nul 2>nul

for /f %%t in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "TS=%%t"
set "LOGFILE=%LOGDIR%\mov2wav_resolve_conform_%TS%.log"

if not exist "%INNER_BAT%" (
  echo [ERROR] Inner BAT not found: "%INNER_BAT%"
  pause
  exit /b 2
)

echo.
echo [INFO] Logging to: "%LOGFILE%"
echo [INFO] Starting wrapper...
echo.

(
  echo ============================================================
  echo WRAPPER START
  echo Timestamp   : %DATE% %TIME%
  echo Workdir     : "%WORKDIR%"
  echo Inner bat   : "%INNER_BAT%"
  echo Computer    : %COMPUTERNAME%
  echo User        : %USERNAME%
  echo OS          : %OS%
  echo ============================================================
  echo.
) >> "%LOGFILE%"

REM ============================================================
REM KEY FIX:
REM - Run inner BAT in its OWN cmd.exe
REM - Disable echo nesting
REM - Disable delayed expansion leakage
REM ============================================================

cmd.exe /d /s /c ^
  "set NO_PAUSE=1 ^& call "%INNER_BAT%"" ^
  >> "%LOGFILE%" 2>&1

set "EXITCODE=%ERRORLEVEL%"

(
  echo.
  echo ============================================================
  echo WRAPPER END
  echo Timestamp   : %DATE% %TIME%
  echo Exit code   : %EXITCODE%
  echo Log file    : "%LOGFILE%"
  echo ============================================================
) >> "%LOGFILE%"

echo.
if not "%EXITCODE%"=="0" (
  echo [DONE WITH ERRORS] Exit code: %EXITCODE%
  echo [LOG] "%LOGFILE%"
  pause
  exit /b %EXITCODE%
)

echo [DONE] Exit code: %EXITCODE%
echo [LOG] "%LOGFILE%"
pause
exit /b 0
