param(
  [Parameter(Mandatory=$true)][string]$Proj,
  [Parameter(Mandatory=$true)][string]$Log
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function LogLine([string]$s) {
  $ts = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff")
  Add-Content -LiteralPath $Log -Value "[$ts] $s"
}

function Sha256([string]$path) {
  if (-not (Test-Path -LiteralPath $path)) { return $null }
  return (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash
}

function EnsureDir([string]$p) {
  New-Item -ItemType Directory -Force -Path $p | Out-Null
}

function TestUrl([string]$url) {
  try {
    $r = Invoke-WebRequest -Uri $url -Method Head -UseBasicParsing -TimeoutSec 20
    return ($r.StatusCode -ge 200 -and $r.StatusCode -lt 400)
  } catch {
    return $false
  }
}

function DownloadFile([string]$url, [string]$dest) {
  EnsureDir (Split-Path -Parent $dest)
  LogLine "[DL] $url"
  LogLine "     -> $dest"
  try {
    Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing
  } catch {
    LogLine "[WARN] Invoke-WebRequest failed, retrying with BITS: $($_.Exception.Message)"
    Start-BitsTransfer -Source $url -Destination $dest
  }
}

function ExpandZip([string]$zip, [string]$destDir) {
  EnsureDir $destDir
  LogLine "[ZIP] Expand: $zip -> $destDir"
  Expand-Archive -LiteralPath $zip -DestinationPath $destDir -Force
}

function FindFirst([string]$root, [string]$name) {
  Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -ieq $name } |
    Select-Object -First 1
}

# ------------------------------------------------------------
# Portable tools targets
# ------------------------------------------------------------
$toolsDir = Join-Path $Proj "tools"
$tempDir  = Join-Path $Proj "build\_downloads"
EnsureDir $toolsDir
EnsureDir $tempDir

$ffmpegExe  = Join-Path $toolsDir "ffmpeg.exe"
$ffprobeExe = Join-Path $toolsDir "ffprobe.exe"
$bwfExe     = Join-Path $toolsDir "bwfmetaedit.exe"

LogLine "---- ENSURE_TOOLS (portable) ----"
LogLine "Proj=$Proj"
LogLine "toolsDir=$toolsDir"

# ------------------------------------------------------------
# 1) FFmpeg/ffprobe (Gyan.dev essentials ZIP)
# ------------------------------------------------------------
$needFfmpeg = -not (Test-Path -LiteralPath $ffmpegExe) -or -not (Test-Path -LiteralPath $ffprobeExe)
if ($needFfmpeg) {
  $ffZip = Join-Path $tempDir "ffmpeg_release.zip"
  $ffExtract = Join-Path $tempDir "ffmpeg_extract"
  $ffUrl = "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip"

  DownloadFile $ffUrl $ffZip

  if (Test-Path -LiteralPath $ffExtract) { Remove-Item -Recurse -Force -LiteralPath $ffExtract }
  ExpandZip $ffZip $ffExtract

  $foundFfmpeg  = FindFirst $ffExtract "ffmpeg.exe"
  $foundFfprobe = FindFirst $ffExtract "ffprobe.exe"

  if (-not $foundFfmpeg -or -not $foundFfprobe) {
    throw "FFmpeg ZIP extracted but ffmpeg.exe/ffprobe.exe not found."
  }

  Copy-Item -LiteralPath $foundFfmpeg.FullName  -Destination $ffmpegExe  -Force
  Copy-Item -LiteralPath $foundFfprobe.FullName -Destination $ffprobeExe -Force

  LogLine "[OK] Installed ffmpeg.exe -> $ffmpegExe (sha256=$(Sha256 $ffmpegExe))"
  LogLine "[OK] Installed ffprobe.exe -> $ffprobeExe (sha256=$(Sha256 $ffprobeExe))"
} else {
  LogLine "[OK] ffmpeg/ffprobe already present."
  LogLine "     ffmpeg sha256=$(Sha256 $ffmpegExe)"
  LogLine "     ffprobe sha256=$(Sha256 $ffprobeExe)"
}

# ------------------------------------------------------------
# 2) BWF MetaEdit (Windows CLI ZIP)
# We try a small ordered list of known-good URLs (newest first).
# Current Windows download page lists CLI v26.01. :contentReference[oaicite:1]{index=1}
# ------------------------------------------------------------
$needBwf = -not (Test-Path -LiteralPath $bwfExe)
if ($needBwf) {
  $bwfZip = Join-Path $tempDir "bwfmetaedit_win.zip"
  $bwfExtract = Join-Path $tempDir "bwfmetaedit_extract"

  $candidates = @(
    "https://mediaarea.net/download/binary/bwfmetaedit/26.01/BWFMetaEdit_CLI_26.01_Windows_x64.zip",
    "https://mediaarea.net/download/binary/bwfmetaedit/25.04/BWFMetaEdit_CLI_25.04_Windows_x64.zip",
    "https://mediaarea.net/download/binary/bwfmetaedit/24.10/BWFMetaEdit_CLI_24.10_Windows_x64.zip"
  )

  $picked = $null
  foreach ($u in $candidates) {
    LogLine "[INFO] Testing URL: $u"
    if (TestUrl $u) { $picked = $u; break }
  }
  if (-not $picked) {
    throw "Could not find a working BWF MetaEdit CLI URL. MediaArea may have changed paths."
  }

  DownloadFile $picked $bwfZip

  if (Test-Path -LiteralPath $bwfExtract) { Remove-Item -Recurse -Force -LiteralPath $bwfExtract }
  ExpandZip $bwfZip $bwfExtract

  $foundBwf = FindFirst $bwfExtract "bwfmetaedit.exe"
  if (-not $foundBwf) {
    throw "BWF MetaEdit ZIP extracted but bwfmetaedit.exe not found."
  }

  Copy-Item -LiteralPath $foundBwf.FullName -Destination $bwfExe -Force
  LogLine "[OK] Installed bwfmetaedit.exe -> $bwfExe (sha256=$(Sha256 $bwfExe))"
} else {
  LogLine "[OK] bwfmetaedit already present."
  LogLine "     bwfmetaedit sha256=$(Sha256 $bwfExe)"
}

# ------------------------------------------------------------
# Sanity: run versions (best effort)
# ------------------------------------------------------------
LogLine "---- TOOL VERSION CHECK (best effort) ----"
try { LogLine ("[VER] ffmpeg: " + (& $ffmpegExe -version 2>&1 | Select-Object -First 1)) } catch { LogLine "[WARN] ffmpeg version check failed." }
try { LogLine ("[VER] ffprobe: " + (& $ffprobeExe -version 2>&1 | Select-Object -First 1)) } catch { LogLine "[WARN] ffprobe version check failed." }
try { LogLine ("[VER] bwfmetaedit: " + (& $bwfExe --version 2>&1 | Select-Object -First 1)) } catch { LogLine "[WARN] bwfmetaedit version check failed." }

LogLine "---- ENSURE_TOOLS OK ----"
exit 0
