param(
  [Parameter(Mandatory=$true)][string]$Proj,
  [Parameter(Mandatory=$true)][string]$Input,
  [Parameter(Mandatory=$true)][string]$Log
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function LogLine([string]$s) {
  $ts = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff")
  Add-Content -LiteralPath $Log -Value "[$ts] $s"
}

function EnsureDir([string]$p) {
  New-Item -ItemType Directory -Force -Path $p | Out-Null
}

function FirstOrNull($arr) {
  if ($null -eq $arr) { return $null }
  $a = @($arr)
  if ($a.Count -gt 0) { return $a[0] }
  return $null
}

function SafeFileStem([string]$s) {
  # Keep filename stable but avoid illegal chars on Windows
  $bad = [IO.Path]::GetInvalidFileNameChars()
  foreach ($c in $bad) { $s = $s.Replace([string]$c, "_") }
  return $s.Trim()
}

function ResolveTool([string]$toolsDir, [string]$exeName) {
  $p = Join-Path $toolsDir $exeName
  if (Test-Path -LiteralPath $p) { return $p }
  $cmd = Get-Command $exeName -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  return $null
}

function RunExe([string]$exe, [string[]]$args) {
  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = $exe
  $psi.Arguments = ($args | ForEach-Object {
    if ($_ -match '\s') { '"' + ($_ -replace '"','\"') + '"' } else { $_ }
  }) -join ' '
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  $psi.UseShellExecute = $false
  $psi.CreateNoWindow = $true

  $p = New-Object System.Diagnostics.Process
  $p.StartInfo = $psi
  [void]$p.Start()
  $stdout = $p.StandardOutput.ReadToEnd()
  $stderr = $p.StandardError.ReadToEnd()
  $p.WaitForExit()

  return [pscustomobject]@{
    ExitCode = $p.ExitCode
    StdOut   = $stdout
    StdErr   = $stderr
    CmdLine  = $psi.FileName + " " + $psi.Arguments
  }
}

function ParseRational([string]$s) {
  if (-not $s) { return $null }
  if ($s -eq "0/0") { return $null }
  if ($s -match '^(?<a>\d+)\s*/\s*(?<b>\d+)$') {
    $a = [int64]$Matches.a
    $b = [int64]$Matches.b
    if ($b -eq 0) { return $null }
    return [pscustomobject]@{ Num=$a; Den=$b }
  }
  if ($s -match '^\d+(\.\d+)?$') {
    $v = [double]$s
    return [pscustomobject]@{ Num=[int64]($v*1000000); Den=1000000 }
  }
  return $null
}

function RationalToDouble($r) {
  if (-not $r) { return $null }
  return [double]$r.Num / [double]$r.Den
}

function GetTagsFromProbe($probe) {
  $tags = @{}
  if ($probe.format -and $probe.format.tags) {
    $probe.format.tags.PSObject.Properties | ForEach-Object {
      $tags[$_.Name.ToLower()] = [string]$_.Value
    }
  }
  foreach ($st in @($probe.streams)) {
    if ($st.tags) {
      $st.tags.PSObject.Properties | ForEach-Object {
        $k = $_.Name.ToLower()
        if (-not $tags.ContainsKey($k)) { $tags[$k] = [string]$_.Value }
      }
    }
  }
  return $tags
}

function PickVideoFpsRational($probe) {
  foreach ($st in @($probe.streams)) {
    if ($st.codec_type -eq "video") {
      $r = ParseRational $st.avg_frame_rate
      if (-not $r) { $r = ParseRational $st.r_frame_rate }
      if ($r -and $r.Num -gt 0 -and $r.Den -gt 0) { return $r }
    }
  }
  return $null
}

function ExtractTimecode($tags) {
  foreach ($k in @("timecode","com.apple.quicktime.timecode","smpte_tc","tc")) {
    if ($tags.ContainsKey($k) -and $tags[$k]) { return $tags[$k].Trim() }
  }
  foreach ($kv in $tags.GetEnumerator()) {
    $v = ($kv.Value ?? "").Trim()
    if ($v -match '^\d{2}:\d{2}:\d{2}[:;]\d{2}$') { return $v }
  }
  return $null
}

function ExtractCreationUtc($tags) {
  if (-not $tags.ContainsKey("creation_time")) { return $null }
  $ct = $tags["creation_time"]
  if (-not $ct) { return $null }
  try {
    $s = $ct.Trim()
    if ($s.EndsWith("Z")) { $s = $s.Substring(0,$s.Length-1) + "+00:00" }
    return ([DateTimeOffset]::Parse($s)).ToUniversalTime()
  } catch {
    return $null
  }
}

function ExtractReel($tags, [string]$fallback) {
  foreach ($k in @("reel_name","reel","tape","roll","camera_roll","com.apple.quicktime.reel","com.apple.quicktime.tape","com.apple.quicktime.roll")) {
    if ($tags.ContainsKey($k) -and $tags[$k]) { return $tags[$k].Trim() }
  }
  return $fallback
}

function TcToFrames_NDF([string]$tc, [int]$fpsNominal) {
  # tc "HH:MM:SS:FF" or "HH:MM:SS;FF" (we ignore ';' here)
  if (-not ($tc -match '^(?<h>\d{2}):(?<m>\d{2}):(?<s>\d{2})[:;](?<f>\d{2})$')) { return $null }
  $h=[int]$Matches.h; $m=[int]$Matches.m; $s=[int]$Matches.s; $f=[int]$Matches.f
  return (($h*3600 + $m*60 + $s) * $fpsNominal) + $f
}

function TcToFrames_DF([string]$tc, [int]$fpsNominal) {
  # Drop-frame for 29.97 (nominal 30) or 59.94 (nominal 60)
  # Formula: drop 2 frames per minute, except every 10th minute (for 30df).
  if (-not ($tc -match '^(?<h>\d{2}):(?<m>\d{2}):(?<s>\d{2});(?<f>\d{2})$')) { return $null }
  $h=[int]$Matches.h; $m=[int]$Matches.m; $s=[int]$Matches.s; $f=[int]$Matches.f

  $totalMinutes = $h*60 + $m

  if ($fpsNominal -eq 30) {
    $drop = 2
    $dropped = $drop * ($totalMinutes - [math]::Floor($totalMinutes/10))
    $frames = (($h*3600 + $m*60 + $s) * $fpsNominal) + $f
    return ($frames - $dropped)
  }

  if ($fpsNominal -eq 60) {
    # 60df drops 4 frames per minute except every 10th
    $drop = 4
    $dropped = $drop * ($totalMinutes - [math]::Floor($totalMinutes/10))
    $frames = (($h*3600 + $m*60 + $s) * $fpsNominal) + $f
    return ($frames - $dropped)
  }

  return $null
}

function ComputeTimeReferenceSamples([string]$tc, $fpsRat, [int]$sr) {
  if (-not $tc -or -not $fpsRat) { return $null }

  $fps = RationalToDouble $fpsRat
  if (-not $fps -or $fps -le 0) { return $null }

  $isDF = ($tc -like "*;*")

  # Choose nominal fps for frame counting:
  # - for ~29.97 use 30
  # - for ~59.94 use 60
  # - else round to nearest int
  $fpsNom = [int][math]::Round($fps)
  if ([math]::Abs($fps - 29.97) -lt 0.02) { $fpsNom = 30 }
  if ([math]::Abs($fps - 59.94) -lt 0.02) { $fpsNom = 60 }

  $frames = $null
  if ($isDF -and ($fpsNom -eq 30 -or $fpsNom -eq 60)) {
    $frames = TcToFrames_DF $tc $fpsNom
  } else {
    $frames = TcToFrames_NDF $tc $fpsNom
  }
  if ($null -eq $frames) { return $null }

  # Convert frames to seconds using the *real* fps (e.g., 30000/1001)
  $sec = [double]$frames / [double]$fps
  if ($sec -lt 0) { $sec = 0 }

  return [int64][math]::Round($sec * $sr)
}

function BuildIxml([string]$fileName, [string]$reel, [string]$tc, $fpsRat, [int]$sr, [int]$ch, $creationUtc) {
  $fps = RationalToDouble $fpsRat
  $fpsStr = ""
  if ($fps) { $fpsStr = ([math]::Round($fps,6)).ToString("0.######") }

  $tcStr = if ($tc) { $tc } else { "00:00:00:00" }
  $flag = if ($tc -like "*;*") { "DF" } else { "NDF" }

  $dateStr = ""
  $timeStr = ""
  if ($creationUtc) {
    $dateStr = $creationUtc.ToString("yyyy-MM-dd")
    $timeStr = $creationUtc.ToString("HH:mm:ss")
  }

  # Keep it simple + compatible: "richer" but not weird.
  @"
<?xml version="1.0" encoding="UTF-8"?>
<IXML>
  <IXML_VERSION>1.5</IXML_VERSION>
  <PROJECT>Resolve_Conform</PROJECT>
  <TAPE>$reel</TAPE>
  <FILE_NAME>$fileName</FILE_NAME>
  <SPEED>
    <TIMECODE_RATE>$fpsStr</TIMECODE_RATE>
    <TIMECODE_FLAG>$flag</TIMECODE_FLAG>
  </SPEED>
  <TIMECODE>
    <TIMECODE_START>$tcStr</TIMECODE_START>
  </TIMECODE>
  <BWF>
    <BWF_SAMPLE_RATE>$sr</BWF_SAMPLE_RATE>
    <BWF_CHANNEL_COUNT>$ch</BWF_CHANNEL_COUNT>
    <BWF_ORIGINATION_DATE>$dateStr</BWF_ORIGINATION_DATE>
    <BWF_ORIGINATION_TIME>$timeStr</BWF_ORIGINATION_TIME>
  </BWF>
</IXML>
"@
}

function TryBwfMetaWrite([string]$bwfExe, [string]$wavPath, [hashtable]$fields, [string]$ixmlPath) {
  # Write BWF fields first, then try iXML with multiple flags.
  $argsBase = @()

  foreach ($k in $fields.Keys) {
    $argsBase += "--$k=$($fields[$k])"
  }
  $argsBase += $wavPath

  $r1 = RunExe $bwfExe $argsBase
  if ($r1.ExitCode -ne 0) {
    return [pscustomobject]@{ ok=$false; msg=("BWF write failed: " + $r1.StdErr + "`n" + $r1.StdOut); cmd=$r1.CmdLine }
  }

  if (-not $ixmlPath) {
    return [pscustomobject]@{ ok=$true; msg="BWF ok (no iXML)"; cmd=$r1.CmdLine }
  }

  $flags = @("--inxml=", "--ixml=", "--iXML=", "--IXML=")
  $ok = $false
  $last = $null

  foreach ($f in $flags) {
    $r2 = RunExe $bwfExe @("$($f)$ixmlPath", $wavPath)
    $last = $r2
    if ($r2.ExitCode -eq 0) { $ok = $true; break }
  }

  if ($ok) {
    return [pscustomobject]@{ ok=$true; msg="BWF ok + iXML ok"; cmd=($r1.CmdLine + " ; " + $last.CmdLine) }
  } else {
    return [pscustomobject]@{ ok=$true; msg=("BWF ok; iXML failed/not supported: " + ($last.StdErr + "`n" + $last.StdOut)); cmd=($r1.CmdLine + " ; " + $last.CmdLine) }
  }
}

# ------------------------------------------------------------
# Paths / tools
# ------------------------------------------------------------
$toolsDir = Join-Path $Proj "tools"
$outDir   = Join-Path $Proj "out_wav"
$logsDir  = Join-Path $Proj "logs"
EnsureDir $outDir
EnsureDir $logsDir

$ffmpeg = ResolveTool $toolsDir "ffmpeg.exe"
$ffprobe = ResolveTool $toolsDir "ffprobe.exe"
$bwfmeta = ResolveTool $toolsDir "bwfmetaedit.exe"  # optional

if (-not $ffmpeg) { throw "ffmpeg not found (portable tools preferred). Put ffmpeg.exe in $toolsDir" }
if (-not $ffprobe) { throw "ffprobe not found (portable tools preferred). Put ffprobe.exe in $toolsDir" }

# Read conversion parameters from env (set by env.bat) if present, else defaults
$sr = [int]($env:AUDIO_SR  ?? "48000")
$ch = [int]($env:AUDIO_CH  ?? "2")
$codec = ($env:AUDIO_CODEC ?? "pcm_s24le")

$ts = Get-Date -Format "yyyyMMdd_HHmmss"
$csvPath = Join-Path $outDir ("resolve_conform_report_" + $ts + ".csv")

LogLine "---- CONVERT START ----"
LogLine "Input=$Input"
LogLine "OutDir=$outDir"
LogLine "CSV=$csvPath"
LogLine "ffmpeg=$ffmpeg"
LogLine "ffprobe=$ffprobe"
LogLine ("bwfmetaedit=" + ($bwfmeta ?? "(missing)"))
LogLine "sr=$sr ch=$ch codec=$codec"

# ------------------------------------------------------------
# Enumerate MOVs (non-recursive for determinism)
# ------------------------------------------------------------
if (-not (Test-Path -LiteralPath $Input)) { throw "Input directory not found: $Input" }

$movs = Get-ChildItem -LiteralPath $Input -Filter "*.mov" -File | Sort-Object Name
if (-not $movs -or $movs.Count -eq 0) { throw "No .mov files found in: $Input" }

# CSV rows
$rows = New-Object System.Collections.Generic.List[object]

foreach ($mov in $movs) {
  $movPath = $mov.FullName
  $stem = SafeFileStem ([IO.Path]::GetFileNameWithoutExtension($mov.Name))
  $wavBase = Join-Path $outDir ($stem + ".wav")

  # Collision-safe deterministic suffixing
  $wavPath = $wavBase
  $i = 0
  while (Test-Path -LiteralPath $wavPath) {
    $i++
    $wavPath = Join-Path $outDir ($stem + "_" + $i + ".wav")
  }

  LogLine "---- FILE ----"
  LogLine ("MOV=" + $movPath)
  LogLine ("WAV=" + $wavPath)

  # Probe
  $probeRun = RunExe $ffprobe @("-v","error","-print_format","json","-show_format","-show_streams","--",$movPath)
  if ($probeRun.ExitCode -ne 0) {
    LogLine "[ERR] ffprobe failed"
    LogLine $probeRun.CmdLine
    LogLine $probeRun.StdErr
    throw "ffprobe failed for: $movPath"
  }

  $probe = $probeRun.StdOut | ConvertFrom-Json
  $tags = GetTagsFromProbe $probe
  $fpsRat = PickVideoFpsRational $probe
  $fps = RationalToDouble $fpsRat
  $tc = ExtractTimecode $tags
  $creationUtc = ExtractCreationUtc $tags
  $reel = ExtractReel $tags $stem

  LogLine ("tc=" + ($tc ?? ""))
  LogLine ("fps=" + ($(if($fps){[math]::Round($fps,6)}else{""})))
  LogLine ("reel=" + $reel)
  LogLine ("creation_utc=" + ($(if($creationUtc){$creationUtc.ToString("o")}else{""})))

  # Convert with ffmpeg
  $ffArgs = @(
    "-y",
    "-hide_banner",
    "-loglevel","error",
    "-i", $movPath,
    "-vn",
    "-ac", "$ch",
    "-ar", "$sr",
    "-c:a", $codec,
    $wavPath
  )
  $conv = RunExe $ffmpeg $ffArgs
  if ($conv.ExitCode -ne 0) {
    LogLine "[ERR] ffmpeg conversion failed"
    LogLine $conv.CmdLine
    LogLine $conv.StdErr
    throw "ffmpeg failed for: $movPath"
  }

  # Preserve filesystem timestamps for editing workflows (match MOV times)
  try {
    $wavItem = Get-Item -LiteralPath $wavPath
    $wavItem.CreationTimeUtc = $mov.CreationTimeUtc
    $wavItem.LastWriteTimeUtc = $mov.LastWriteTimeUtc
  } catch {
    LogLine "[WARN] Could not mirror filesystem timestamps: $($_.Exception.Message)"
  }

  # Compute BWF TimeReference (samples)
  $tref = ComputeTimeReferenceSamples $tc $fpsRat $sr
  if ($null -ne $tref) { LogLine ("TimeReferenceSamples=" + $tref) }

  $metadataWritten = $false
  $metadataMsg = "metadata skipped"
  $ixmlMsg = ""
  $ixmlTemp = $null

  if ($bwfmeta) {
    # Build iXML temp file
    if ($env:DO_IXML -eq "1") {
      try {
        $ixmlContent = BuildIxml $mov.Name $reel $tc $fpsRat $sr $ch $creationUtc
        $ixmlTemp = Join-Path ([IO.Path]::GetTempPath()) ("ixml_" + [guid]::NewGuid().ToString("N") + ".xml")
        Set-Content -LiteralPath $ixmlTemp -Value $ixmlContent -Encoding UTF8
      } catch {
        $ixmlTemp = $null
        LogLine "[WARN] Could not create iXML temp file: $($_.Exception.Message)"
      }
    }

    # Mirror filename/reel into BWF fields (Description + OriginatorReference)
    $desc = "$($mov.Name) | REEL=$reel"
    $bwfFields = @{}
    if ($creationUtc) {
      $bwfFields["OriginationDate"] = $creationUtc.ToString("yyyy-MM-dd")
      $bwfFields["OriginationTime"] = $creationUtc.ToString("HH:mm:ss")
    }
    if ($null -ne $tref) { $bwfFields["TimeReference"] = "$tref" }

    $bwfFields["Description"] = $desc
    $bwfFields["OriginatorReference"] = $reel

    $write = TryBwfMetaWrite $bwfmeta $wavPath $bwfFields $ixmlTemp
    $metadataWritten = $true
    $metadataMsg = $write.msg
    LogLine ("[META] " + $metadataMsg)

    if ($ixmlTemp) {
      try { Remove-Item -Force -LiteralPath $ixmlTemp -ErrorAction SilentlyContinue } catch {}
    }
  } else {
    LogLine "[WARN] bwfmetaedit not found; skipping BWF/iXML metadata injection."
  }

  # Add CSV row for conform
  $rows.Add([pscustomobject]@{
    input_mov = $movPath
    output_wav = $wavPath
    file_name = $mov.Name
    reel_name = $reel
    timecode = ($tc ?? "")
    fps = ($(if($fps){([math]::Round($fps,6)).ToString("0.######")}else{""}))
    sample_rate = $sr
    channels = $ch
    bwf_time_reference_samples = ($(if($null -ne $tref){$tref}else{""}))
    metadata_written = $metadataWritten
    metadata_message = $metadataMsg
  }) | Out-Null
}

# Write CSV
$rows | Export-Csv -NoTypeInformation -Encoding UTF8 -LiteralPath $csvPath
LogLine "[OK] Wrote CSV: $csvPath"
LogLine "---- CONVERT END OK ----"
exit 0
