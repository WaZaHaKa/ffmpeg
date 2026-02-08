param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$Args
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-RepoRoot {
  $root = $null
  try {
    $root = (git -C $PSScriptRoot rev-parse --show-toplevel 2>$null).Trim()
  } catch {
    $root = $null
  }

  if (-not $root) {
    $root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
  }

  return $root
}

function Resolve-ConfigPath([string]$repoRoot) {
  return Join-Path $repoRoot 'mov2wav/apps/desktop/mov2wav_pnp/config/mov2wav.config.json'
}

function Load-Config([string]$configPath) {
  if (-not (Test-Path -LiteralPath $configPath)) {
    throw "Missing config: $configPath"
  }

  return (Get-Content -Raw -LiteralPath $configPath | ConvertFrom-Json)
}

function Resolve-ConfigValue([string]$repoRoot, [string]$value, [string]$default) {
  $resolved = $value
  if ([string]::IsNullOrWhiteSpace($resolved)) {
    $resolved = $default
  }

  if ([string]::IsNullOrWhiteSpace($resolved)) {
    return $null
  }

  if ([IO.Path]::IsPathRooted($resolved)) {
    return $resolved
  }

  return (Join-Path $repoRoot $resolved)
}

function New-RunLog([string]$repoRoot, [string]$command, [string]$runLogsDirOverride) {
  $runLogsDir = Resolve-ConfigValue $repoRoot $runLogsDirOverride '.runlogs'
  if (-not $runLogsDir) {
    $runLogsDir = Join-Path $repoRoot '.runlogs'
  }

  New-Item -ItemType Directory -Force -Path $runLogsDir | Out-Null
  $ts = Get-Date -Format 'yyyyMMdd_HHmmss'
  return Join-Path $runLogsDir ("mov2wav_{0}_{1}.log" -f $command, $ts)
}

function Write-RunLog([string]$logPath, [string]$message) {
  $ts = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss.fff')
  $line = "[$ts] $message"
  $line | Tee-Object -FilePath $logPath -Append | Out-Null
}

function Invoke-LegacyBat([string]$scriptPath, [string[]]$arguments, [string]$workingDir, [string]$runLog) {
  if (-not (Test-Path -LiteralPath $scriptPath)) {
    throw "Legacy script not found: $scriptPath"
  }

  $argString = ($arguments | ForEach-Object {
    if ($_ -match '\s') { '"' + ($_ -replace '"','\"') + '"' } else { $_ }
  }) -join ' '

  Write-RunLog $runLog "Invoking: $scriptPath $argString"

  Push-Location $workingDir
  try {
    $env:RUNLOG = $runLog
    & cmd.exe /c "\"$scriptPath\" $argString" 2>&1 | Tee-Object -FilePath $runLog -Append | Out-Null
    return $LASTEXITCODE
  } finally {
    Pop-Location
  }
}

function Invoke-LegacyPs1([string]$scriptPath, [string[]]$arguments, [string]$runLog) {
  if (-not (Test-Path -LiteralPath $scriptPath)) {
    throw "Legacy script not found: $scriptPath"
  }

  $psArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $scriptPath) + $arguments
  Write-RunLog $runLog "Invoking: powershell $($psArgs -join ' ')"
  & powershell @psArgs 2>&1 | Tee-Object -FilePath $runLog -Append | Out-Null
  return $LASTEXITCODE
}

function Test-TrackedOutputs([string]$repoRoot, [string]$runLog) {
  $patterns = @(
    'node_modules/',
    'dist/',
    'build/',
    'out/',
    'release/',
    '.vite/',
    '.turbo/',
    '.cache/',
    '.next/',
    '.runlogs/',
    'out_wav/',
    'logs/',
    'tools/',
    'renamed_mov/'
  )

  $tracked = & git -C $repoRoot ls-files 2>$null
  if (-not $tracked) {
    return
  }

  $hits = @()
  foreach ($file in $tracked) {
    foreach ($pattern in $patterns) {
      if ($file.Replace('\\','/') -like "*$pattern*") {
        $hits += $file
        break
      }
    }
  }

  if ($hits.Count -gt 0) {
    Write-RunLog $runLog "[WARN] Tracked build outputs detected:"
    foreach ($hit in ($hits | Sort-Object -Unique)) {
      Write-RunLog $runLog "  - $hit"
    }
    Write-RunLog $runLog "Remediation: git rm -r --cached $($hits[0])"
  } else {
    Write-RunLog $runLog '[OK] No tracked build outputs detected.'
  }
}

function Invoke-Injection([string]$repoRoot, $config, [string]$runLog) {
  $scriptsRoot = Join-Path $repoRoot 'mov2wav/apps/desktop/mov2wav_pnp/scripts'
  $injectConfig = $config.injection

  $root = Resolve-ConfigValue $repoRoot $injectConfig.root $null
  if (-not $root) {
    $root = (Get-Location).Path
  }

  $renamedDir = Resolve-ConfigValue $repoRoot $injectConfig.renamedDir 'renamed_mov'
  if (-not [IO.Path]::IsPathRooted($renamedDir)) {
    $renamedDir = Join-Path $root $renamedDir
  }

  $logDir = Resolve-ConfigValue $repoRoot $injectConfig.logDir 'logs'
  if (-not [IO.Path]::IsPathRooted($logDir)) {
    $logDir = Join-Path $root $logDir
  }

  $toolsDir = Resolve-ConfigValue $repoRoot $injectConfig.toolsDir 'tools'
  if (-not [IO.Path]::IsPathRooted($toolsDir)) {
    $toolsDir = Join-Path $root $toolsDir
  }

  New-Item -ItemType Directory -Force -Path $logDir | Out-Null
  Write-RunLog $runLog "Injection root: $root"

  $glob = if ($injectConfig.glob) { $injectConfig.glob } else { '*.mov' }

  Invoke-LegacyPs1 (Join-Path $scriptsRoot 'inject_report.ps1') @(
    '-Root', $root,
    '-RenamedDir', $renamedDir,
    '-Glob', $glob,
    '-Log', $runLog
  ) $runLog | Out-Null

  Invoke-LegacyPs1 (Join-Path $scriptsRoot 'inject_hashes.ps1') @(
    '-RenamedDir', $renamedDir,
    '-Log', $runLog
  ) $runLog | Out-Null

  Invoke-LegacyPs1 (Join-Path $scriptsRoot 'inject_versions.ps1') @(
    '-Log', $runLog,
    '-Root', $root,
    '-ToolsDir', $toolsDir
  ) $runLog | Out-Null
}

function Show-Usage {
  Write-Host 'Usage:'
  Write-Host '  tools/mov2wav.ps1 doctor'
  Write-Host '  tools/mov2wav.ps1 convert --in <path> --out <path>'
  Write-Host '  tools/mov2wav.ps1 run'
}

$repoRoot = Resolve-RepoRoot
$configPath = Resolve-ConfigPath $repoRoot
$config = Load-Config $configPath

if (-not $Args -or $Args.Count -eq 0) {
  Show-Usage
  exit 1
}

$command = $Args[0]
$remaining = if ($Args.Count -gt 1) { $Args[1..($Args.Count - 1)] } else { @() }
$runLog = New-RunLog $repoRoot $command $config.conversion.runLogsDir

Write-RunLog $runLog "Repo root: $repoRoot"
Write-RunLog $runLog "Config: $configPath"
Write-RunLog $runLog "Command: $command"

switch ($command) {
  'doctor' {
    $inputDir = Resolve-ConfigValue $repoRoot $config.conversion.inputDir $repoRoot
    Write-RunLog $runLog "Doctor input dir: $inputDir"

    $scriptsRoot = Join-Path $repoRoot 'mov2wav/apps/desktop/mov2wav_pnp/scripts'
    $preflight = Join-Path $scriptsRoot 'step_preflight.bat'
    $ensureTools = Join-Path $scriptsRoot 'step_ensure_tools.bat'

    $exitPreflight = Invoke-LegacyBat $preflight @($runLog) $inputDir $runLog
    Write-RunLog $runLog "Preflight exit code: $exitPreflight"

    $exitEnsure = Invoke-LegacyBat $ensureTools @($runLog) $inputDir $runLog
    Write-RunLog $runLog "Ensure-tools exit code: $exitEnsure"

    Test-TrackedOutputs $repoRoot $runLog

    if ($exitPreflight -ne 0 -or $exitEnsure -ne 0) {
      Write-RunLog $runLog '[WARN] Doctor reported issues. See log.'
      exit 1
    }

    Write-RunLog $runLog '[OK] Doctor complete.'
    exit 0
  }
  'convert' {
    $inputDir = $null
    $outputDir = $null

    for ($i = 0; $i -lt $remaining.Count; $i++) {
      switch ($remaining[$i]) {
        '--in' {
          $inputDir = $remaining[$i + 1]
          $i++
        }
        '--out' {
          $outputDir = $remaining[$i + 1]
          $i++
        }
      }
    }

    $inputDir = Resolve-ConfigValue $repoRoot $inputDir $config.conversion.inputDir
    $outputDir = Resolve-ConfigValue $repoRoot $outputDir $config.conversion.outputDir

    if (-not $inputDir) {
      throw 'Missing --in <path> for conversion.'
    }
    if (-not $outputDir) {
      throw 'Missing --out <path> for conversion.'
    }

    Write-RunLog $runLog "Convert input: $inputDir"
    Write-RunLog $runLog "Convert output: $outputDir"

    $scriptsRoot = Join-Path $repoRoot 'mov2wav/apps/desktop/mov2wav_pnp/scripts'
    $mainBat = Join-Path $scriptsRoot 'main.bat'

    $exitMain = Invoke-LegacyBat $mainBat @() $inputDir $runLog
    Write-RunLog $runLog "Legacy main exit code: $exitMain"

    $legacyOut = Join-Path $repoRoot 'mov2wav/apps/desktop/mov2wav_pnp/out_wav'
    if (Test-Path -LiteralPath $legacyOut) {
      New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
      Copy-Item -Path (Join-Path $legacyOut '*') -Destination $outputDir -Recurse -Force
      Write-RunLog $runLog "Copied outputs from $legacyOut to $outputDir"
    } else {
      Write-RunLog $runLog "[WARN] Legacy output folder not found: $legacyOut"
    }

    Invoke-Injection $repoRoot $config $runLog
    Test-TrackedOutputs $repoRoot $runLog

    if ($exitMain -ne 0) {
      Write-RunLog $runLog '[WARN] Conversion reported issues.'
      exit $exitMain
    }

    Write-RunLog $runLog '[OK] Conversion complete.'
    exit 0
  }
  'run' {
    $inputDir = Resolve-ConfigValue $repoRoot $config.conversion.inputDir $repoRoot
    Write-RunLog $runLog "Run input dir: $inputDir"

    $scriptsRoot = Join-Path $repoRoot 'mov2wav/apps/desktop/mov2wav_pnp/scripts'
    $plugplay = Join-Path $scriptsRoot 'RUN_MOV2WAV_PLUGPLAY.bat'

    $exitPlug = Invoke-LegacyBat $plugplay @() $inputDir $runLog
    Write-RunLog $runLog "Plugplay exit code: $exitPlug"

    Invoke-Injection $repoRoot $config $runLog
    Test-TrackedOutputs $repoRoot $runLog

    if ($exitPlug -ne 0) {
      Write-RunLog $runLog '[WARN] Plug-and-play run reported issues.'
      exit $exitPlug
    }

    Write-RunLog $runLog '[OK] Plug-and-play run complete.'
    exit 0
  }
  Default {
    Show-Usage
    exit 1
  }
}
