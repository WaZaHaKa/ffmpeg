@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM ============================================================
REM step_preflight.bat
REM - Validates environment + inputs before any downloads/conversion
REM - Writes status lines into the main run log
REM Exit codes:
REM   0  OK
REM   2  No input MOVs found
REM   3  No PowerShell
REM   4  No write access / cannot create output dirs
REM   5  Invalid INPUT_DIR
REM ============================================================

set "RUNLOG=%~1"
if "%RUNLOG%"=="" (
  echo [preflight][ERR] RUNLOG argument missing
  exit /b 99
)

call "%~dp0env.bat"

call :log "---- PREFLIGHT ----"

REM 1) Check PowerShell availability
where powershell >nul 2>nul
if errorlevel 1 (
  call :log "[FAIL] PowerShell not found in PATH."
  exit /b 3
)
call :log "[OK] PowerShell available."

REM 2) Validate INPUT_DIR exists
if not exist "%INPUT_DIR%\" (
  call :log "[FAIL] INPUT_DIR does not exist: %INPUT_DIR%"
  exit /b 5
)
call :log "[OK] INPUT_DIR exists: %INPUT_DIR%"

REM 3) Ensure project dirs exist (write permission sanity)
for %%D in ("%LOGS%" "%OUT_WAV%" "%TOOLS%" "%DIST%" "%BUILD%" "%SRC%") do (
  if not exist "%%~D" (
    mkdir "%%~D" >nul 2>nul
    if errorlevel 1 (
      call :log "[FAIL] Cannot create directory: %%~D"
      exit /b 4
    )
  )
)
call :log "[OK] Project directories writable."

REM 4) Ensure we can write inside INPUT_DIR (for out_wav/logs if user runs in media folder)
REM    We DON'T create output there; we just test a temp write.
set "TMPTEST=%INPUT_DIR%\.__mov2wav_write_test__.tmp"
> "%TMPTEST%" (echo test) 2>nul
if not exist "%TMPTEST%" (
  call :log "[WARN] Cannot write in INPUT_DIR (may be read-only). INPUT_DIR=%INPUT_DIR%"
) else (
  del "%TMPTEST%" >nul 2>nul
  call :log "[OK] INPUT_DIR write test passed."
)

REM 5) Find MOV files (non-recursive, deterministic)
set "MOVCOUNT=0"
for %%F in ("%INPUT_DIR%\*.mov") do (
  if exist "%%~fF" (
    set /a MOVCOUNT+=1
  )
)

if "%MOVCOUNT%"=="0" (
  call :log "[FAIL] No .mov files found in INPUT_DIR: %INPUT_DIR%"
  exit /b 2
)

call :log "[OK] Found %MOVCOUNT% MOV file(s)."

REM 6) Tool presence report (no download here; just visibility)
call :log "---- TOOL PRESENCE (report only) ----"
call :toolline "ffmpeg"     "%TOOLS%\ffmpeg.exe"
call :toolline "ffprobe"    "%TOOLS%\ffprobe.exe"
call :toolline "bwfmetaedit" "%TOOLS%\bwfmetaedit.exe"

REM 7) Quick PATH report (first match)
for /f "delims=" %%P in ('where ffmpeg 2^>nul ^| powershell -NoProfile -Command "$input | Select-Object -First 1"') do set "FFP=%%P"
if defined FFP (
  call :log "[INFO] ffmpeg resolves to: %FFP%"
) else (
  call :log "[INFO] ffmpeg not found in PATH (yet)."
)

call :log "---- PREFLIGHT OK ----"
exit /b 0

:toolline
REM %1 label, %2 expected path
set "LBL=%~1"
set "PTH=%~2"
if exist "%PTH%" (
  call :log "[OK] %LBL% present: %PTH%"
) else (
  call :log "[MISS] %LBL% missing: %PTH%"
)
exit /b 0

:log
>>"%RUNLOG%" echo [%DATE% %TIME%] %~1
exit /b 0
