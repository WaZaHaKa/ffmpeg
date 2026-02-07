@echo off
setlocal EnableExtensions EnableDelayedExpansion
REM ============================================================
REM env.bat
REM - Centralizes paths/toggles for the mov2wav system
REM - Safe folder name (no &), safe quoting everywhere
REM - Called by main.bat / diag_wrapper.bat
REM ============================================================

REM Project root = parent of scripts\
set "PROJ=%~dp0.."
for %%I in ("%PROJ%") do set "PROJ=%%~fI"

REM Core directories
set "TOOLS=%PROJ%\tools"
set "LOGS=%PROJ%\logs"
set "OUT_WAV=%PROJ%\out_wav"
set "DIST=%PROJ%\dist"
set "BUILD=%PROJ%\build"
set "SRC=%PROJ%\src"

REM Inputs (default: run in the folder that contains MOV files)
REM If you want the system to always run on a specific folder, set INPUT_DIR explicitly.
set "INPUT_DIR=%CD%"

REM Conversion defaults
set "AUDIO_SR=48000"
set "AUDIO_CH=2"
set "AUDIO_CODEC=pcm_s24le"

REM Behavior toggles
set "DO_METADATA=1"   REM uses bwfmetaedit if present
set "DO_IXML=1"       REM embed richer iXML where supported
set "DO_CSV=1"
set "DO_HASH=1"
set "DO_VERSIONS=1"

REM Prefer portable tools folder
if exist "%TOOLS%" set "PATH=%TOOLS%;%PATH%"

endlocal & (
  set "PROJ=%PROJ%"
  set "TOOLS=%TOOLS%"
  set "LOGS=%LOGS%"
  set "OUT_WAV=%OUT_WAV%"
  set "DIST=%DIST%"
  set "BUILD=%BUILD%"
  set "SRC=%SRC%"
  set "INPUT_DIR=%INPUT_DIR%"
  set "AUDIO_SR=%AUDIO_SR%"
  set "AUDIO_CH=%AUDIO_CH%"
  set "AUDIO_CODEC=%AUDIO_CODEC%"
  set "DO_METADATA=%DO_METADATA%"
  set "DO_IXML=%DO_IXML%"
  set "DO_CSV=%DO_CSV%"
  set "DO_HASH=%DO_HASH%"
  set "DO_VERSIONS=%DO_VERSIONS%"
)
