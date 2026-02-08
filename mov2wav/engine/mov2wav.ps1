param(
  [Parameter(Mandatory = $true)]
  [string]$InputPath,
  [Parameter(Mandatory = $true)]
  [string]$OutputPath,
  [switch]$DryRun
)

Set-StrictMode -Version Latest

$RunId = (Get-Date -Format "yyyyMMdd_HHmmss")
$RunRoot = Join-Path -Path $PSScriptRoot -ChildPath "..\logs\run_$RunId"
$LogPath = Join-Path -Path $RunRoot -ChildPath "run.log"

New-Item -ItemType Directory -Path $RunRoot -Force | Out-Null
New-Item -ItemType File -Path $LogPath -Force | Out-Null

function Write-RunLog {
  param([string]$Message)
  $timestamp = Get-Date -Format "HH:mm:ss"
  Add-Content -Path $LogPath -Value "[$timestamp] $Message"
}

Write-RunLog "MOV2WAV run starting. DryRun=${DryRun}."
Write-RunLog "Input: $InputPath"
Write-RunLog "Output: $OutputPath"

Write-RunLog "TODO: integrate ffprobe/ffmpeg/bwfmetaedit processing."
Write-RunLog "Run complete."
