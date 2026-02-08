param(
  [Parameter(Mandatory=$true)][string]$Proj,
  [Parameter(Mandatory=$true)][string]$Log
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

function LogLine([string]$s) {
  $ts = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff")
  Add-Content -LiteralPath $Log -Value "[$ts] $s"
}

function Sha256([string]$path) {
  try {
    if (-not (Test-Path -LiteralPath $path)) { return $null }
    return (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash
  } catch { return $null }
}

function FirstLine([string[]]$lines) {
  if (-not $lines) { return $null }
  return ($lines | Select-Object -First 1)
}

function TryRun([string]$label, [scriptblock]$sb) {
  try {
    $out = & $sb 2>&1
    $line = FirstLine $out
    if ($line) {
      LogLine "[VER] $label: $line"
      return [string]$line
    } else {
      LogLine "[VER] $label: (no output)"
      return $null
    }
  } catch {
    LogLine "[WARN] $label failed: $($_.Exception.Message)"
    return $null
  }
}

$toolsDir = Join-Path $Proj "tools"
$logsDir  = Join-Path $Proj "logs"
New-Item -ItemType Directory -Force -Path $logsDir | Out-Null

$ts = Get-Date -Format "yyyyMMdd_HHmmss"
$outJson = Join-Path $logsDir ("versions_" + $ts + ".json")

$ffmpegExe  = Join-Path $toolsDir "ffmpeg.exe"
$ffprobeExe = Join-Path $toolsDir "ffprobe.exe"
$bwfExe     = Join-Path $toolsDir "bwfmetaedit.exe"

LogLine "---- VERSIONS START ----"
LogLine "Proj=$Proj"
LogLine "toolsDir=$toolsDir"

# PowerShell + OS info
$psVer = $PSVersionTable.PSVersion.ToString()
LogLine "[VER] PowerShell: $psVer"

TryRun "Windows" { cmd /c ver }

# Tool versions: prefer portable paths, fall back to PATH resolution
$ffmpegLine = $null
if (Test-Path -LiteralPath $ffmpegExe) {
  $ffmpegLine = TryRun "ffmpeg (portable)" { & $ffmpegExe -version | Select-Object -First 1 }
} else {
  $ffmpegLine = TryRun "ffmpeg (PATH)" { ffmpeg -version | Select-Object -First 1 }
}

$ffprobeLine = $null
if (Test-Path -LiteralPath $ffprobeExe) {
  $ffprobeLine = TryRun "ffprobe (portable)" { & $ffprobeExe -version | Select-Object -First 1 }
} else {
  $ffprobeLine = TryRun "ffprobe (PATH)" { ffprobe -version | Select-Object -First 1 }
}

$bwfLine = $null
if (Test-Path -LiteralPath $bwfExe) {
  $bwfLine = TryRun "bwfmetaedit (portable)" { & $bwfExe --version | Select-Object -First 1 }
} else {
  $bwfLine = TryRun "bwfmetaedit (PATH)" { bwfmetaedit --version | Select-Object -First 1 }
}

# Python (optional; EXE build later may remove need)
$pyLine = TryRun "python" { python --version }

# Hashes of portable tools (useful for reproducibility)
$hashes = [ordered]@{
  "tools_dir"   = $toolsDir
  "ffmpeg.exe"  = @{ path = $ffmpegExe;  sha256 = (Sha256 $ffmpegExe) }
  "ffprobe.exe" = @{ path = $ffprobeExe; sha256 = (Sha256 $ffprobeExe) }
  "bwfmetaedit.exe" = @{ path = $bwfExe; sha256 = (Sha256 $bwfExe) }
}

# Persist a JSON artifact for audit
$artifact = [ordered]@{
  timestamp_utc = (Get-Date).ToUniversalTime().ToString("o")
  project_root  = $Proj
  powershell    = $psVer
  windows       = (TryRun "Windows (repeat)" { cmd /c ver })
  versions      = [ordered]@{
    ffmpeg      = $ffmpegLine
    ffprobe     = $ffprobeLine
    bwfmetaedit = $bwfLine
    python      = $pyLine
  }
  hashes = $hashes
}

try {
  ($artifact | ConvertTo-Json -Depth 6) | Set-Content -LiteralPath $outJson -Encoding UTF8
  LogLine "[OK] Versions JSON: $outJson"
} catch {
  LogLine "[WARN] Could not write versions JSON: $($_.Exception.Message)"
}

LogLine "---- VERSIONS END ----"
exit 0
