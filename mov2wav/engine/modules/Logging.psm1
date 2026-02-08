function Get-ToolVersions {
  param(
    [string]$FfmpegPath,
    [string]$FfprobePath,
    [string]$BwfMetaEditPath
  )

  return [pscustomobject]@{
    ffmpeg = $FfmpegPath
    ffprobe = $FfprobePath
    bwfmetaedit = $BwfMetaEditPath
  }
}

Export-ModuleMember -Function Get-ToolVersions
