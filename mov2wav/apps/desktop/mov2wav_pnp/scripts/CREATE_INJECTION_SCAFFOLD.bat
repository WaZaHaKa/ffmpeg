@echo off
setlocal EnableExtensions

REM ============================================================
REM CREATE_INJECTION_SCAFFOLD.bat
REM - Creates injection phase folder structure
REM - Writes placeholder scripts into:
REM   C:\Users\theon\Downloads\2026-02-07_1802_split_by_lalalai\mov2wav_p&p\scripts
REM ============================================================

set "BASE=C:\Users\theon\Downloads\2026-02-07_1802_split_by_lalalai\mov2wav_p&p"
set "SCRIPTS=%BASE%\scripts"

REM Create folder structure
for %%D in ("%BASE%" "%SCRIPTS%" "%BASE%\tools" "%BASE%\logs" "%BASE%\dist" "%BASE%\build" "%BASE%\src" "%BASE%\renamed_mov") do (
  if not exist "%%~D" mkdir "%%~D" >nul 2>nul
)

echo [OK] Folders created (or already exist).
echo      %SCRIPTS%

REM Helper to write a file only if it does not exist
call :ensure_file "%SCRIPTS%\main_injection.bat" ^
"@echo off
setlocal EnableExtensions EnableDelayedExpansion
REM main_injection.bat (placeholder)
REM Orchestrates injection pipeline.
REM TODO: call inject_config.bat, inject_rename.bat, inject_report.ps1, inject_hashes.ps1, inject_versions.ps1
echo [TODO] Implement main injection orchestration here.
exit /b 0
"

call :ensure_file "%SCRIPTS%\inject_config.bat" ^
"@echo off
REM inject_config.bat (placeholder)
REM Central configuration for injection naming scheme and toggles.

REM Root where MOV files live (default: folder you run from)
set ""INJECT_ROOT=%CD%""

REM Input glob
set ""INJECT_GLOB=*.mov""

REM Output folder for renamed/mapped files
set ""RENAMED_DIR=%INJECT_ROOT%\renamed_mov""

REM Logs folder
set ""LOG_DIR=%INJECT_ROOT%\logs""

REM Naming template tokens: {date} {time} {n} {stem} {reel}
set ""NAME_TEMPLATE={date}_{time}_{n}_{stem}""

REM Toggles
set ""DO_RENAME=1""
set ""DO_CSV=1""
set ""DO_HASH=1""
set ""DO_VERSIONS=1""

REM Optional tools folder to prepend to PATH
set ""TOOLS_DIR=%INJECT_ROOT%\tools""
"

call :ensure_file "%SCRIPTS%\inject_rename.bat" ^
"@echo off
setlocal EnableExtensions EnableDelayedExpansion
REM inject_rename.bat (placeholder)
REM TODO: rename/move files using NAME_TEMPLATE with collision safety.
echo [TODO] Implement rename injection here.
exit /b 0
"

call :ensure_file "%SCRIPTS%\inject_report.ps1" ^
"param(
  [Parameter(Mandatory=`$true)][string]`$Root,
  [Parameter(Mandatory=`$true)][string]`$RenamedDir,
  [Parameter(Mandatory=`$true)][string]`$Glob,
  [Parameter(Mandatory=`$true)][string]`$Log
)
# inject_report.ps1 (placeholder)
# TODO: generate Resolve-friendly CSV mapping and metadata.
Write-Host '[TODO] inject_report.ps1 not implemented yet.'
exit 0
"

call :ensure_file "%SCRIPTS%\inject_hashes.ps1" ^
"param(
  [Parameter(Mandatory=`$true)][string]`$RenamedDir,
  [Parameter(Mandatory=`$true)][string]`$Log
)
# inject_hashes.ps1 (placeholder)
# TODO: compute SHA256 hashes CSV for renamed files.
Write-Host '[TODO] inject_hashes.ps1 not implemented yet.'
exit 0
"

call :ensure_file "%SCRIPTS%\inject_versions.ps1" ^
"param(
  [Parameter(Mandatory=`$true)][string]`$Log,
  [Parameter(Mandatory=`$true)][string]`$Root,
  [Parameter(Mandatory=`$true)][string]`$ToolsDir
)
# inject_versions.ps1 (placeholder)
# TODO: capture tool versions (ffmpeg/ffprobe/bwfmetaedit/python/powershell).
Write-Host '[TODO] inject_versions.ps1 not implemented yet.'
exit 0
"

call :ensure_file "%SCRIPTS%\diag_wrapper.bat" ^
"@echo off
setlocal EnableExtensions EnableDelayedExpansion
REM diag_wrapper.bat (placeholder)
REM TODO: monitor main_injection.bat and log from 0 byte.
echo [TODO] Implement diagnostic wrapper here.
exit /b 0
"

echo.
echo [DONE] Injection scaffold created in:
echo        %SCRIPTS%
echo.
echo Next step:
echo - Open %SCRIPTS% in Notepad++ and implement each placeholder.
echo - Run main_injection.bat from the MOV folder.
echo.
pause
exit /b 0

:ensure_file
set "FILE=%~1"
set "CONTENT=%~2"

if exist "%FILE%" (
  echo [SKIP] %FILE% already exists
  exit /b 0
)

REM Write content safely via PowerShell to avoid cmd-escaping issues
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$p = '%FILE%';" ^
  "$c = @'
%CONTENT%
'@;" ^
  "Set-Content -LiteralPath $p -Value $c -Encoding UTF8"

if exist "%FILE%" (
  echo [OK] Created %FILE%
) else (
  echo [ERR] Failed to create %FILE%
  exit /b 1
)

exit /b 0
