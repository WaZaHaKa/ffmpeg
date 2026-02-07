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

$OutDir = Join-Path $Proj "out_wav"
if (-not (Test-Path -LiteralPath $OutDir)) {
  throw "out_wav not found: $OutDir"
}

$ts = Get-Date -Format "yyyyMMdd_HHmmss"
$hashCsv = Join-Path $OutDir ("wav_hashes_" + $ts + ".csv")

LogLine "---- HASHES START ----"
LogLine "out_wav=$OutDir"
LogLine "hash_csv=$hashCsv"

$wavs = Get-ChildItem -LiteralPath $OutDir -Filter "*.wav" -File | Sort-Object Name
if (-not $wavs -or $wavs.Count -eq 0) {
  LogLine "[WARN] No WAV files found to hash."
  # Still write an empty CSV with header for determinism
  @() | Export-Csv -NoTypeInformation -Encoding UTF8 -LiteralPath $hashCsv
  LogLine "[OK] Wrote empty hash CSV: $hashCsv"
  LogLine "---- HASHES END ----"
  exit 0
}

$rows = foreach ($w in $wavs) {
  $h = Get-FileHash -Algorithm SHA256 -LiteralPath $w.FullName
  [pscustomobject]@{
    wav    = $w.FullName
    sha256 = $h.Hash
    bytes  = $w.Length
    mtime_utc = $w.LastWriteTimeUtc.ToString("o")
  }
}

$rows | Export-Csv -NoTypeInformation -Encoding UTF8 -LiteralPath $hashCsv
LogLine "[OK] Wrote hash CSV: $hashCsv"

# Also append a compact summary into the run log (top N lines only to keep logs readable)
LogLine "SHA256 summary (first 25):"
$rows | Select-Object -First 25 | ForEach-Object {
  LogLine ("  " + $_.sha256 + "  " + $_.wav)
}
if ($rows.Count -gt 25) {
  LogLine ("  ... (" + ($rows.Count - 25) + " more)")
}

LogLine "---- HASHES END OK ----"
exit 0
