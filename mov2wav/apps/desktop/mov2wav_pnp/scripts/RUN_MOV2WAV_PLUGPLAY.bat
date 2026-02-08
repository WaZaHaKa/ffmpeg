@echo off
setlocal EnableExtensions

set "ROOT=%CD%"
set "TOOLS=%ROOT%\tools"
set "OUT=%ROOT%\out_wav"
set "LOGS=%ROOT%\logs"
set "PS1=%TOOLS%\mov2wav_portable.ps1"

if not exist "%TOOLS%" mkdir "%TOOLS%" >nul 2>nul
if not exist "%OUT%"   mkdir "%OUT%"   >nul 2>nul
if not exist "%LOGS%"  mkdir "%LOGS%"  >nul 2>nul

REM ------------------------------------------------------------------
REM Write the PowerShell pipeline ONCE (no CMD echo blocks; reliable)
REM ------------------------------------------------------------------
if not exist "%PS1%" (
  powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$p='%PS1%';" ^
    "$s=@'
param(
  [Parameter(Mandatory=$true)][string]$Root
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$tools = Join-Path $Root 'tools'
$out   = Join-Path $Root 'out_wav'
$logs  = Join-Path $Root 'logs'
New-Item -ItemType Directory -Force -Path $tools,$out,$logs | Out-Null

$ts = Get-Date -Format 'yyyyMMdd_HHmmss'
$logFile   = Join-Path $logs ('run_' + $ts + '.log')
$csvReport = Join-Path $out  ('resolve_conform_report_' + $ts + '.csv')
$hashCsv   = Join-Path $out  ('wav_hashes_' + $ts + '.csv')

Start-Transcript -LiteralPath $logFile | Out-Null

function Write-Section([string]$t){
  Write-Host ''
  Write-Host '----------------------------'
  Write-Host $t
  Write-Host '----------------------------'
}

function Get-Exe([string]$name){
  $p = Join-Path $tools $name
  if(Test-Path -LiteralPath $p){ return $p }
  return $null
}

function Download-File([string]$Url, [string]$Dest){
  Write-Host ('[DL] ' + $Url)
  Write-Host (' ->  ' + $Dest)
  $wc = New-Object System.Net.WebClient
  $wc.Headers['User-Agent'] = 'mov2wav-portable'
  $wc.DownloadFile($Url, $Dest)
}

function Expand-Zip([string]$Zip, [string]$DestDir){
  if(Test-Path -LiteralPath $DestDir){ Remove-Item -LiteralPath $DestDir -Recurse -Force }
  New-Item -ItemType Directory -Force -Path $DestDir | Out-Null
  Expand-Archive -LiteralPath $Zip -DestinationPath $DestDir -Force
}

function Ensure-FFmpeg {
  $ffmpeg  = Get-Exe 'ffmpeg.exe'
  $ffprobe = Get-Exe 'ffprobe.exe'
  if($ffmpeg -and $ffprobe){ return }

  Write-Section 'FETCH PORTABLE FFMPEG'
  # gyan.dev release ZIP includes ffmpeg.exe + ffprobe.exe (easy extraction)
  $url = 'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip'
  $zip = Join-Path $tools 'ffmpeg-release-essentials.zip'
  $tmp = Join-Path $tools '_ffmpeg_extract'

  Download-File $url $zip
  Expand-Zip $zip $tmp

  $foundFfmpeg  = Get-ChildItem -Path $tmp -Recurse -Filter 'ffmpeg.exe'  -File | Select-Object -First 1
  $foundFfprobe = Get-ChildItem -Path $tmp -Recurse -Filter 'ffprobe.exe' -File | Select-Object -First 1
  if(-not $foundFfmpeg -or -not $foundFfprobe){
    throw 'Failed to locate ffmpeg.exe/ffprobe.exe inside downloaded ZIP.'
  }

  Copy-Item -LiteralPath $foundFfmpeg.FullName  -Destination (Join-Path $tools 'ffmpeg.exe')  -Force
  Copy-Item -LiteralPath $foundFfprobe.FullName -Destination (Join-Path $tools 'ffprobe.exe') -Force

  Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue
}

function Ensure-BWFMetaEdit {
  $bwf = Get-Exe 'bwfmetaedit.exe'
  if($bwf){ return }

  Write-Section 'FETCH PORTABLE BWF METAEDIT (CLI)'
  # MediaArea official CLI ZIP (Windows x64)
  $url = 'https://mediaarea.net/download/binary/bwfmetaedit/26.01/BWFMetaEdit_CLI_26.01_Windows_x64.zip'
  $zip = Join-Path $tools 'bwfmetaedit_cli.zip'
  $tmp = Join-Path $tools '_bwf_extract'

  Download-File $url $zip
  Expand-Zip $zip $tmp

  $exe = Get-ChildItem -Path $tmp -Recurse -File |
    Where-Object { $_.Name -match '^(bwfmetaedit|BWFMetaEdit)\.exe$' } |
    Select-Object -First 1

  if(-not $exe){
    throw 'Failed to locate bwfmetaedit.exe (or BWFMetaEdit.exe) inside downloaded ZIP.'
  }

  Copy-Item -LiteralPath $exe.FullName -Destination (Join-Path $tools 'bwfmetaedit.exe') -Force

  Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue
}

function Run-Tool([string]$exe, [string[]]$args){
  $p = New-Object System.Diagnostics.Process
  $p.StartInfo.FileName = $exe
  $p.StartInfo.RedirectStandardOutput = $true
  $p.StartInfo.RedirectStandardError  = $true
  $p.StartInfo.UseShellExecute = $false
  foreach($a in $args){ [void]$p.StartInfo.ArgumentList.Add($a) }
  [void]$p.Start()
  $stdout = $p.StandardOutput.ReadToEnd()
  $stderr = $p.StandardError.ReadToEnd()
  $p.WaitForExit()
  if($stdout){ $stdout.TrimEnd() | Write-Host }
  if($stderr){ $stderr.TrimEnd() | Write-Host }
  if($p.ExitCode -ne 0){ throw ('Tool failed (' + $exe + ') exit=' + $p.ExitCode) }
  return $stdout
}

function Parse-TimecodeToSeconds([string]$tc, [double]$fps){
  if([string]::IsNullOrWhiteSpace($tc) -or $fps -le 0){ return $null }
  if($tc -notmatch '^(?<h>\d{2}):(?<m>\d{2}):(?<s>\d{2})([:;])(?<f>\d{2})$'){ return $null }
  $h=[int]$Matches.h; $m=[int]$Matches.m; $s=[int]$Matches.s; $f=[int]$Matches.f
  return ($h*3600)+($m*60)+$s+($f/$fps)
}

function Escape-Xml([string]$s){
  return ($s -replace '&','&amp;' -replace '<','&lt;' -replace '>','&gt;' -replace '"','&quot;' -replace "'","&apos;")
}

function Make-iXML([string]$fileName,[string]$reel,[string]$tc,[string]$fps){
  if(-not $tc){ $tc='00:00:00:00' }
  $fpsStr = if($fps){ $fps } else { '' }
  $flag = if($tc -like '*;*'){ 'DF' } else { 'NDF' }
  return @"
<?xml version=""1.0"" encoding=""UTF-8""?>
<IXML_VERSION>1.5</IXML_VERSION>
<IXML>
  <PROJECT>Resolve_Conform</PROJECT>
  <TAPE>$(Escape-Xml $reel)</TAPE>
  <FILE_NAME>$(Escape-Xml $fileName)</FILE_NAME>
  <SPEED>
    <TIMECODE_RATE>$(Escape-Xml $fpsStr)</TIMECODE_RATE>
    <TIMECODE_FLAG>$flag</TIMECODE_FLAG>
  </SPEED>
  <TIMECODE>
    <TIMECODE_START>$(Escape-Xml $tc)</TIMECODE_START>
  </TIMECODE>
</IXML>
"@
}

Write-Host '============================================================'
Write-Host 'RUN START'
Write-Host ('Workdir: ' + $Root)
Write-Host ('Tools : ' + $tools)
Write-Host ('Out   : ' + $out)
Write-Host ('Log   : ' + $logFile)
Write-Host '============================================================'

Ensure-FFmpeg
Ensure-BWFMetaEdit

$ffmpeg  = Join-Path $tools 'ffmpeg.exe'
$ffprobe = Join-Path $tools 'ffprobe.exe'
$bwf     = Join-Path $tools 'bwfmetaedit.exe'

Write-Section 'TOOL VERSIONS'
Run-Tool $ffmpeg  @('-version') | Out-Null
Run-Tool $ffprobe @('-version') | Out-Null
Run-Tool $bwf     @('--version') | Out-Null

Write-Section 'SCAN MOV FILES'
$movs = Get-ChildItem -LiteralPath $Root -Filter '*.mov' -File
if(-not $movs){ throw 'No .mov files found in this folder.' }
Write-Host ('Found: ' + $movs.Count)

$report = New-Object System.Collections.Generic.List[object]
$hashes = New-Object System.Collections.Generic.List[object]

Write-Section 'CONVERT + METADATA'
foreach($mov in $movs){
  $stem = [IO.Path]::GetFileNameWithoutExtension($mov.Name)
  $wav  = Join-Path $out ($stem + '.wav')

  Write-Host ''
  Write-Host ('[MOV] ' + $mov.Name)

  # ffprobe JSON
  $probeJson = & $ffprobe -v error -print_format json -show_format -show_streams -- $mov.FullName
  $probe = $probeJson | ConvertFrom-Json

  # FPS from first video stream
  $fps = $null
  $v = $probe.streams | Where-Object { $_.codec_type -eq 'video' } | Select-Object -First 1
  if($v){
    $rate = $v.avg_frame_rate
    if(-not $rate -or $rate -eq '0/0'){ $rate = $v.r_frame_rate }
    if($rate -and $rate -match '^(?<a>\d+)\/(?<b>\d+)$'){
      $a=[double]$Matches.a; $b=[double]$Matches.b
      if($b -ne 0){ $fps = [Math]::Round(($a/$b), 6) }
    }
  }

  # Tags
  $tags = @{}
  if($probe.format.tags){
    $probe.format.tags.psobject.Properties | ForEach-Object { $tags[$_.Name.ToLower()] = [string]$_.Value }
  }
  # timecode
  $tc = $null
  foreach($k in @('timecode','com.apple.quicktime.timecode','smpte_tc','tc')){
    if($tags.ContainsKey($k) -and $tags[$k]){ $tc = $tags[$k]; break }
  }
  # reel
  $reel = $stem
  foreach($k in @('reel_name','reel','tape','roll','camera_roll','com.apple.quicktime.reel','com.apple.quicktime.tape','com.apple.quicktime.roll')){
    if($tags.ContainsKey($k) -and $tags[$k]){ $reel = $tags[$k]; break }
  }

  # Convert to WAV (48k, 24-bit, stereo)
  Run-Tool $ffmpeg @('-y','-hide_banner','-loglevel','error','-i', $mov.FullName, '-vn','-ac','2','-ar','48000','-c:a','pcm_s24le', $wav) | Out-Null

  # Compute BWF TimeReference in samples (from TC)
  $timeRef = $null
  if($tc -and $fps){
    $secs = Parse-TimecodeToSeconds $tc $fps
    if($secs -ne $null){
      $timeRef = [int][Math]::Round($secs * 48000)
    }
  }

  # iXML chunk file
  $ixml = Make-iXML $mov.Name $reel $tc $fps
  $ixmlPath = Join-Path $env:TEMP ('ixml_' + [Guid]::NewGuid().ToString('N') + '.xml')
  Set-Content -LiteralPath $ixmlPath -Value $ixml -Encoding UTF8

  # Write BWF + iXML
  $desc = ($mov.Name + ' | REEL=' + $reel)
  $args = @()
  if($timeRef -ne $null){ $args += ('--TimeReference=' + $timeRef) }
  $args += ('--Description=' + $desc)
  $args += ('--OriginatorReference=' + $reel)
  $args += ('--inxml=' + $ixmlPath)
  $args += $wav
  try {
    Run-Tool $bwf $args | Out-Null
    $metaMsg = 'BWF+iXML ok'
    $metaOk = $true
  } catch {
    $metaMsg = ('BWF/iXML write failed: ' + $_.Exception.Message)
    $metaOk = $false
  } finally {
    Remove-Item -LiteralPath $ixmlPath -Force -ErrorAction SilentlyContinue
  }

  # Hash
  $h = Get-FileHash -Algorithm SHA256 -LiteralPath $wav

  $report.Add([pscustomobject]@{
    input_mov=$mov.FullName
    output_wav=$wav
    file_name=$mov.Name
    reel_name=$reel
    timecode=($tc ? $tc : '')
    fps=($fps ? $fps : '')
    sample_rate=48000
    channels=2
    bwf_time_reference_samples=($timeRef -ne $null ? $timeRef : '')
    metadata_written=$metaOk
    metadata_message=$metaMsg
  })

  $hashes.Add([pscustomobject]@{
    wav=$wav
    sha256=$h.Hash
    bytes=(Get-Item -LiteralPath $wav).Length
  })

  Write-Host ('[WAV] ' + (Split-Path -Leaf $wav))
  Write-Host ('[SHA] ' + $h.Hash)
}

Write-Section 'WRITE REPORTS'
$report | Export-Csv -NoTypeInformation -Encoding UTF8 -LiteralPath $csvReport
$hashes | Export-Csv -NoTypeInformation -Encoding UTF8 -LiteralPath $hashCsv
Write-Host ('Resolve CSV: ' + $csvReport)
Write-Host ('Hash   CSV: ' + $hashCsv)

Write-Host ''
Write-Host '============================================================'
Write-Host 'RUN END (OK)'
Write-Host ('Log: ' + $logFile)
Write-Host '============================================================'

Stop-Transcript | Out-Null
'@;" ^
    "Set-Content -LiteralPath $p -Value $s -Encoding UTF8"
)

REM ------------------------------------------------------------------
REM Run the pipeline
REM ------------------------------------------------------------------
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -Root "%ROOT%"
set "EC=%ERRORLEVEL%"

if not "%EC%"=="0" (
  echo.
  echo [ERROR] Failed. Check logs in "%LOGS%"
  pause
  exit /b %EC%
)

echo.
echo [DONE] WAVs in "%OUT%"
echo [DONE] Logs in "%LOGS%"
pause
exit /b 0
