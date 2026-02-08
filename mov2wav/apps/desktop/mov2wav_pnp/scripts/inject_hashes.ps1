param(
  [Parameter(Mandatory = $true)][string]$RenamedDir,
  [Parameter(Mandatory = $true)][string]$Log
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function LogLine([string]$s) {
  $ts = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss.fff')
  Add-Content -LiteralPath $Log -Value "[$ts] $s"
}

LogLine '---- INJECT HASHES START ----'
LogLine "RenamedDir=$RenamedDir"
LogLine '[TODO] inject_hashes.ps1 not implemented yet.'
LogLine '---- INJECT HASHES END ----'
exit 0
