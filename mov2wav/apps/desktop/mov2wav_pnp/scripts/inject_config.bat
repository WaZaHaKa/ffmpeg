@echo off
setlocal EnableExtensions
REM inject_config.bat
REM Loads injection configuration from config/mov2wav.config.json.

set "CONFIG_FILE=%~dp0..\config\mov2wav.config.json"
for %%I in ("%CONFIG_FILE%") do set "CONFIG_FILE=%%~fI"

if not exist "%CONFIG_FILE%" (
  echo [ERR] Missing config: "%CONFIG_FILE%"
  exit /b 1
)

set "TMPFILE=%TEMP%\mov2wav_inject_%RANDOM%.bat"

powershell -NoProfile -Command ^
  "$cfg = Get-Content -Raw -LiteralPath '%CONFIG_FILE%' | ConvertFrom-Json;" ^
  "$inj = $cfg.injection;" ^
  "$root = $inj.root;" ^
  "if ([string]::IsNullOrWhiteSpace($root)) { $root = (Get-Location).Path }" ^
  "$glob = if ($inj.glob) { $inj.glob } else { '*.mov' };" ^
  "$renamed = if ($inj.renamedDir) { $inj.renamedDir } else { 'renamed_mov' };" ^
  "$logDir = if ($inj.logDir) { $inj.logDir } else { 'logs' };" ^
  "$nameTemplate = if ($inj.nameTemplate) { $inj.nameTemplate } else { '{date}_{time}_{n}_{stem}' };" ^
  "$tools = if ($inj.toolsDir) { $inj.toolsDir } else { 'tools' };" ^
  "if (-not [IO.Path]::IsPathRooted($renamed)) { $renamed = Join-Path $root $renamed }" ^
  "if (-not [IO.Path]::IsPathRooted($logDir)) { $logDir = Join-Path $root $logDir }" ^
  "if (-not [IO.Path]::IsPathRooted($tools)) { $tools = Join-Path $root $tools }" ^
  "$lines = @(" ^
  "  'set \"INJECT_ROOT=' + $root + '\"'," ^
  "  'set \"INJECT_GLOB=' + $glob + '\"'," ^
  "  'set \"RENAMED_DIR=' + $renamed + '\"'," ^
  "  'set \"LOG_DIR=' + $logDir + '\"'," ^
  "  'set \"NAME_TEMPLATE=' + $nameTemplate + '\"'," ^
  "  'set \"DO_RENAME=' + ($(if ($inj.doRename -ne $false) { 1 } else { 0 })) + '\"'," ^
  "  'set \"DO_CSV=' + ($(if ($inj.doCsv -ne $false) { 1 } else { 0 })) + '\"'," ^
  "  'set \"DO_HASH=' + ($(if ($inj.doHash -ne $false) { 1 } else { 0 })) + '\"'," ^
  "  'set \"DO_VERSIONS=' + ($(if ($inj.doVersions -ne $false) { 1 } else { 0 })) + '\"'," ^
  "  'set \"TOOLS_DIR=' + $tools + '\"'" ^
  ");" ^
  "Set-Content -LiteralPath $env:TMPFILE -Value $lines -Encoding ASCII"

call "%TMPFILE%"
del "%TMPFILE%" >nul 2>nul

endlocal & (
  set "INJECT_ROOT=%INJECT_ROOT%"
  set "INJECT_GLOB=%INJECT_GLOB%"
  set "RENAMED_DIR=%RENAMED_DIR%"
  set "LOG_DIR=%LOG_DIR%"
  set "NAME_TEMPLATE=%NAME_TEMPLATE%"
  set "DO_RENAME=%DO_RENAME%"
  set "DO_CSV=%DO_CSV%"
  set "DO_HASH=%DO_HASH%"
  set "DO_VERSIONS=%DO_VERSIONS%"
  set "TOOLS_DIR=%TOOLS_DIR%"
)
