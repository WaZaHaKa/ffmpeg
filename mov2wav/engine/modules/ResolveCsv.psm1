function New-ResolveCsv {
  param(
    [string]$Path,
    [array]$Rows
  )

  $header = "input_path,output_wav,source_file_name,reel_name,timecode,fps,sample_rate,channels,bwf_time_reference_samples,metadata_written,metadata_message"
  Set-Content -Path $Path -Value $header
  foreach ($row in $Rows) {
    Add-Content -Path $Path -Value $row
  }
}

Export-ModuleMember -Function New-ResolveCsv
