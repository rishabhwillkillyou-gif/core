# RishiDM v0.3 video packaging.
# Runs after the base NSIS template is modified but BEFORE it is written.
# Downloads ONLY the pinned yt-dlp Windows executable from its official release.
$ytVersion='2026.10.26'
$toolDir=Join-Path $PSScriptRoot 'media-tools'
New-Item -ItemType Directory -Path $toolDir -Force | Out-Null
$ytExe=Join-Path $toolDir 'yt-dlp.exe'
$checksumFile=Join-Path $toolDir 'SHA2-256SUMS'
$assetBase='https://github.com/yt-dlp/yt-dlp/releases/download/'+$ytVersion+'/'
Invoke-WebRequest -Uri ($assetBase+'yt-dlp.exe') -OutFile $ytExe -UseBasicParsing
Invoke-WebRequest -Uri ($assetBase+'SHA2-256SUMS') -OutFile $checksumFile -UseBasicParsing
if(!(Test-Path $ytExe) -or (Get-Item $ytExe).Length -lt 1000000){throw 'Official yt-dlp download is empty or too small'}
$sumLine=Get-Content -LiteralPath $checksumFile | Where-Object {$_ -match '^[0-9a-fA-F]{64}\s+\*?yt-dlp\.exe$'} | Select-Object -First 1
if(!$sumLine){throw 'No official yt-dlp.exe checksum found'}
$expected=($sumLine -split '\s+')[0].ToLowerInvariant()
$actual=(Get-FileHash -LiteralPath $ytExe -Algorithm SHA256).Hash.ToLowerInvariant()
if($expected -ne $actual){throw "yt-dlp checksum mismatch. Expected $expected, received $actual"}
$notices=@'
RishiDM Video Module - Third-party components and provenance

yt-dlp version 2026.10.26
Executable: official yt-dlp.exe from https://github.com/yt-dlp/yt-dlp/releases/tag/2026.10.26
Source code: https://github.com/yt-dlp/yt-dlp/tree/2026.10.26
License information: https://github.com/yt-dlp/yt-dlp/blob/2026.10.26/LICENSE
yt-dlp's original code is public domain / Unlicense; the Windows executable
may contain components subject to additional third-party licenses.
Inspect the official source and release notes before further redistribution.

No FFmpeg binary is bundled in this RishiDM preview. If you already have an
appropriately licensed FFmpeg installed, the video helper can use it for
higher-resolution audio/video merging and MP3 conversion.

Only download media you own or are authorized to save.
This software does not circumvent DRM or access controls.
'@
$noticeFile=Join-Path $toolDir 'THIRD_PARTY_NOTICES.txt'
[IO.File]::WriteAllText($noticeFile,$notices,$utf8)
$cmdFile=Join-Path $PSScriptRoot 'VideoDownloader.cmd'
$psFile=Join-Path $PSScriptRoot 'video-downloader.ps1'
if(!(Test-Path $cmdFile) -or !(Test-Path $psFile)){throw 'The video helper scripts are missing'}
$marker='    File "' + (Join-Path $PSScriptRoot 'BrowserSetup.cmd') + '"'
$idx=$nsisText.IndexOf($marker,[StringComparison]::Ordinal)
if($idx -lt 0){throw 'Could not locate browser setup packaging line in NSIS'}
$end=$nsisText.IndexOf([char]10,$idx)
$section=@'
    ; RishiDM site-aware video assistant. Deliberately separate from HTTP queue.
    SetOutPath "__DOLLAR__{INSTALL_DIR}\VideoTools"
    File "__YT__"
    File "__NOTICES__"
    SetOutPath "__DOLLAR__{INSTALL_DIR}"
    File "__PS__"
    File "__CMD__"
    CreateDirectory "__DOLLAR__SMPROGRAMS\__DOLLAR__{APP_DISPLAY_NAME}"
    CreateShortCut "__DOLLAR__SMPROGRAMS\__DOLLAR__{APP_DISPLAY_NAME}\Video Downloader.lnk" "__DOLLAR__{INSTALL_DIR}\VideoDownloader.cmd"
'@
$section=$section.Replace('__DOLLAR__',[string][char]36).Replace('__YT__',$ytExe).Replace('__NOTICES__',$noticeFile).Replace('__PS__',$psFile).Replace('__CMD__',$cmdFile)
$nsisText=$nsisText.Insert($end+1,$section+[char]10)
$cleanupMarker='    Delete "' + [char]36 + '{INSTALL_DIR}\BrowserSetup.cmd"'
if(!$nsisText.Contains($cleanupMarker)){throw 'Missing NSIS uninstall cleanup marker'}
$cleanup='    RmDir /r "'+[char]36+'{INSTALL_DIR}\VideoTools"'+[char]10+'    Delete "'+[char]36+'{INSTALL_DIR}\video-downloader.ps1"'+[char]10+'    Delete "'+[char]36+'{INSTALL_DIR}\VideoDownloader.cmd"'
$nsisText=$nsisText.Replace($cleanupMarker,$cleanupMarker+[char]10+$cleanup)
Write-Host "Bundled official yt-dlp $ytVersion (verified SHA256 $actual), video assistant and context-menu integration."
