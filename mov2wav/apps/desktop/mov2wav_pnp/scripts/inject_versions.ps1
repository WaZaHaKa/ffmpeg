param(
  [Parameter(Mandatory = $true)][string]$Log,
  [Parameter(Mandatory = $true)][string]$Root,
  [Parameter(Mandatory = $true)][string]$ToolsDir
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function LogLine([string]$s) {
  $ts = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss.fff')
  Add-Content -LiteralPath $Log -Value "[$ts] $s"
}

LogLine '---- INJECT VERSIONS START ----'
LogLine "Root=$Root"
LogLine "ToolsDir=$ToolsDir"
LogLine '[TODO] inject_versions.ps1 not implemented yet.'
LogLine '---- INJECT VERSIONS END ----'
exit 0
