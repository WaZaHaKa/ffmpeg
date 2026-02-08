param(
  [Parameter(Mandatory = $true)][string]$Root,
  [Parameter(Mandatory = $true)][string]$RenamedDir,
  [Parameter(Mandatory = $true)][string]$Glob,
  [Parameter(Mandatory = $true)][string]$Log
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function LogLine([string]$s) {
  $ts = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss.fff')
  Add-Content -LiteralPath $Log -Value "[$ts] $s"
}

LogLine '---- INJECT REPORT START ----'
LogLine "Root=$Root"
LogLine "RenamedDir=$RenamedDir"
LogLine "Glob=$Glob"
LogLine '[TODO] inject_report.ps1 not implemented yet.'
LogLine '---- INJECT REPORT END ----'
exit 0
