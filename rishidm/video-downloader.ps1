param([string]$Url = '')
# RishiDM Video Download Assistant (v0.3 preview)
# Uses the pinned official yt-dlp binary; no browser cookies or private session headers.
# The browser has to explicitly request this action.
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $MyInvocation.MyCommand.Path
$binary=Join-Path $root 'VideoTools\yt-dlp.exe'
if(-not (Test-Path -LiteralPath $binary)){
 [System.Windows.Forms.MessageBox]::Show("The yt-dlp video engine is missing. Please reinstall the complete RishiDM v0.3 package.",'RishiDM', 'OK','Error') | Out-Null
 exit 1
}
$ffmpeg=Join-Path $root 'VideoTools\ffmpeg.exe'
if(-not (Test-Path -LiteralPath $ffmpeg)){
 $ffmpegCmd=Get-Command ffmpeg.exe -ErrorAction SilentlyContinue
 if($ffmpegCmd){$ffmpeg=$ffmpegCmd.Source}else{$ffmpeg=$null}
}
$font=New-Object System.Drawing.Font('Segoe UI',10)
$form=New-Object System.Windows.Forms.Form
$form.Text='RishiDM - Video Downloader'
$form.StartPosition='CenterScreen'
$form.FormBorderStyle='FixedDialog'
$form.MaximizeBox=$false
$form.Width=710;$form.Height=540;$form.Font=$font
$head=New-Object System.Windows.Forms.Label
$head.Text='Download video with RishiDM';$head.Font=New-Object System.Drawing.Font('Segoe UI',16,[System.Drawing.FontStyle]::Bold)
$head.Location=New-Object System.Drawing.Point(22,18);$head.Size=New-Object System.Drawing.Size(650,40);$form.Controls.Add($head)
$sub=New-Object System.Windows.Forms.Label
$sub.Text='Supports public or otherwise authorized, unprotected videos on yt-dlp-supported sites.'
$sub.Location=New-Object System.Drawing.Point(24,60);$sub.Size=New-Object System.Drawing.Size(650,25);$form.Controls.Add($sub)

function AddLabel($title,$x,$y,$w){
 $l=New-Object System.Windows.Forms.Label;$l.Text=$title
 $l.Location=New-Object System.Drawing.Point($x,$y);$l.Size=New-Object System.Drawing.Size($w,23)
 $form.Controls.Add($l)
}
AddLabel 'Video or page URL' 24 94 210
$urlInput=New-Object System.Windows.Forms.TextBox
$urlInput.Location=New-Object System.Drawing.Point(24,119);$urlInput.Size=New-Object System.Drawing.Size(646,28)
$urlInput.Text=$Url;$form.Controls.Add($urlInput)
AddLabel 'Quality' 24 161 220
$quality=New-Object System.Windows.Forms.ComboBox
$quality.Location=New-Object System.Drawing.Point(24,184);$quality.Size=New-Object System.Drawing.Size(390,30)
$quality.DropDownStyle='DropDownList'
[void]$quality.Items.AddRange([object[]]@(
 'Best single-file video (works without FFmpeg)',
 'Up to 720p single-file video',
 'Up to 1080p video + audio (requires FFmpeg)',
 'Best video + audio, no resolution limit (requires FFmpeg)',
 'Audio only MP3 (requires FFmpeg)'
))
$quality.SelectedIndex=0;$form.Controls.Add($quality)

AddLabel 'Save folder' 24 226 220
$dest=New-Object System.Windows.Forms.TextBox
$dest.Location=New-Object System.Drawing.Point(24,252);$dest.Size=New-Object System.Drawing.Size(520,28)
$dest.Text=Join-Path ([Environment]::GetFolderPath('UserProfile')) 'Downloads'
$form.Controls.Add($dest)
$browse=New-Object System.Windows.Forms.Button
$browse.Text='Browse';$browse.Location=New-Object System.Drawing.Point(555,250);$browse.Size=New-Object System.Drawing.Size(115,33)
$browse.Add_Click({
 $d=New-Object System.Windows.Forms.FolderBrowserDialog
 $d.Description='Choose a folder for completed video files'
 $d.SelectedPath=$dest.Text
 if($d.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){$dest.Text=$d.SelectedPath}
 $d.Dispose()
});$form.Controls.Add($browse)
$start=New-Object System.Windows.Forms.Button
$start.Text='Start download';$start.Location=New-Object System.Drawing.Point(24,301);$start.Size=New-Object System.Drawing.Size(158,38)
$cancel=New-Object System.Windows.Forms.Button
$cancel.Text='Cancel';$cancel.Enabled=$false
$cancel.Location=New-Object System.Drawing.Point(194,301);$cancel.Size=New-Object System.Drawing.Size(110,38)
$form.Controls.Add($start);$form.Controls.Add($cancel)
$status=New-Object System.Windows.Forms.Label
$status.Text='Ready. Normal file downloads still use the main RishiDM window.'
$status.Location=New-Object System.Drawing.Point(320,309);$status.Size=New-Object System.Drawing.Size(355,30)
$form.Controls.Add($status)
$log=New-Object System.Windows.Forms.TextBox
$log.ReadOnly=$true;$log.Multiline=$true;$log.ScrollBars='Vertical'
$log.Location=New-Object System.Drawing.Point(24,355);$log.Size=New-Object System.Drawing.Size(646,114)
$log.Font=New-Object System.Drawing.Font('Consolas',9)
$form.Controls.Add($log)
$notice=New-Object System.Windows.Forms.Label
$notice.Text='Pause/restart recovery is supported where the media source permits it. No DRM bypass.'
$notice.Location=New-Object System.Drawing.Point(24,480);$notice.Size=New-Object System.Drawing.Size(655,24)
$notice.Font=New-Object System.Drawing.Font('Segoe UI',8)
$form.Controls.Add($notice)
$script:proc=$null;$script:logFile=$null;$script:errorFile=$null;$script:running=$false;$script:userCancelled=$false
$timer=New-Object System.Windows.Forms.Timer
$timer.Interval=800
function RefreshLog {
 if(!$script:logFile){return}
 $lines=@()
 foreach($file in @($script:logFile,$script:errorFile)){
  if($file -and (Test-Path -LiteralPath $file)){
   try{$lines+=@(Get-Content -LiteralPath $file -Tail 9 -ErrorAction Stop)}catch{}
  }
 }
 $tail=($lines | Select-Object -Last 15) -join [Environment]::NewLine
 if($tail -ne $log.Text){$log.Text=$tail;$log.SelectionStart=$log.Text.Length;$log.ScrollToCaret()}
}
function FinishDownload {
 if(!$script:running){return}
 $timer.Stop()
 RefreshLog
 $script:running=$false
 $start.Enabled=$true;$cancel.Enabled=$false;$browse.Enabled=$true
 $quality.Enabled=$true;$urlInput.Enabled=$true;$dest.Enabled=$true
 $exitCode=$null
 try{$script:proc.Refresh();$exitCode=$script:proc.ExitCode}catch{}
 if($script:userCancelled){$status.Text='Download cancelled. Partial data may be resumable.'}
 elseif($exitCode -eq 0){$status.Text='Download finished successfully.'}
 else{$status.Text="Download failed (exit code $exitCode). See details below."}
 if($script:proc){$script:proc.Dispose()}
 $script:proc=$null
}
$timer.Add_Tick({
 if(!$script:running){return}
 RefreshLog
 try{$script:proc.Refresh();if($script:proc.HasExited){FinishDownload}}catch{FinishDownload}
})
function TestUrl([string]$raw){
 if([string]::IsNullOrWhiteSpace($raw) -or $raw.Length -gt 2048 -or $raw -match '[\x00-\x20"<>]'){return $null}
 $uri=$null
 if(-not [Uri]::TryCreate($raw,[UriKind]::Absolute,[ref]$uri)){return $null}
 if($uri.Scheme -notin @('http','https') -or !$uri.Host -or $uri.UserInfo){return $null}
 return $uri.AbsoluteUri
}
$start.Add_Click({
 $url=TestUrl $urlInput.Text.Trim()
 if(-not $url){
  [System.Windows.Forms.MessageBox]::Show('Enter a valid http:// or https:// video page URL.','RishiDM') | Out-Null
  return
 }
 $target=$dest.Text.Trim()
 if(-not (Test-Path -LiteralPath $target -PathType Container)){
  [System.Windows.Forms.MessageBox]::Show('Choose an existing download folder.','RishiDM') | Out-Null
  return
 }
 $idx=$quality.SelectedIndex
 if($idx -ge 2 -and !$ffmpeg){
  [System.Windows.Forms.MessageBox]::Show('This choice needs FFmpeg. Install FFmpeg separately or choose a single-file video format. RishiDM does not silently install external codecs.','RishiDM') | Out-Null
  return
 }
 $fmt=switch($idx){
  0 {'b[ext=mp4]/b'}
  1 {'b[height<=720]/b'}
  2 {'bv[height<=1080]+ba/b[height<=1080]'}
  3 {'bv+ba/b'}
  4 {'ba/b'}
 }
 $argsList=@(
 '--no-playlist','--windows-filenames',
 '--no-overwrites','--continue',
 '--retries','10','--fragment-retries','10',
 '--retry-sleep','2','--concurrent-fragments','4',
 '--newline','--format',$fmt,
 '-o',(Join-Path $target '%(title).150B [%(id)s].%(ext)s')
 )
 if($idx -in @(2,3)){$argsList+=@('--merge-output-format','mp4')}
 if($idx -eq 4){$argsList+=@('--extract-audio','--audio-format','mp3')}
 if($ffmpeg){$argsList+=@('--ffmpeg-location',$ffmpeg)}
 $argsList+=@('--',$url)
 # Validate command-line arguments, quote them and avoid shell execution.
 $quoted=$argsList | ForEach-Object {
  if($_ -match '[\x00-\x1f"]'){throw 'Invalid argument'}
  '"'+$_+'"'
 }
 $logDir=Join-Path $env:TEMP 'RishiDM\VideoLogs'
 [IO.Directory]::CreateDirectory($logDir) | Out-Null
 $id=[guid]::NewGuid().ToString('N')
 $script:logFile=Join-Path $logDir "$id.out.log"
 $script:errorFile=Join-Path $logDir "$id.err.log"
 try{
  # Start-Process handles continuous output redirection; the timer reads the logs.
  $script:proc=Start-Process -FilePath $binary -ArgumentList ($quoted -join ' ') -PassThru -WindowStyle Hidden -RedirectStandardOutput $script:logFile -RedirectStandardError $script:errorFile
  $script:running=$true;$script:userCancelled=$false
  $start.Enabled=$false;$cancel.Enabled=$true;$browse.Enabled=$false
  $quality.Enabled=$false;$urlInput.Enabled=$false;$dest.Enabled=$false
  $status.Text='Downloading…'
  $timer.Start()
 }catch{
  [System.Windows.Forms.MessageBox]::Show("Could not start yt-dlp: $($_.Exception.Message)",'RishiDM') | Out-Null
 }
})
$cancel.Add_Click({
 if(!$script:running){return}
 $script:userCancelled=$true
 try {
  $pidToStop=$script:proc.Id
  & taskkill.exe /F /T /PID $pidToStop *> $null
 }catch{}
 FinishDownload
})
$form.Add_FormClosing({
 param($sender, $eventArgs)
 if($script:running){
  $answer=[System.Windows.Forms.MessageBox]::Show('A video download is running. Cancel it and close?','RishiDM','YesNo','Question')
  if($answer -ne [System.Windows.Forms.DialogResult]::Yes){$eventArgs.Cancel=$true;return}
  $script:userCancelled=$true
  try{& taskkill.exe /F /T /PID $script:proc.Id *> $null}catch{}
 }
 $timer.Stop()
})
[void]$form.ShowDialog()
