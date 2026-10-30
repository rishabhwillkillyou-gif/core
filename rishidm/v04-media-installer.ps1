# RishiDM v0.4: bundle audited, pinned Deno and LGPL/shared FFmpeg with the Windows installer.
# Runs after v0.3 media-installer.ps1 and before NSIS template is written.
$tools=Join-Path $PSScriptRoot 'media-tools'
$denoZip=Join-Path $tools 'deno-2.9.8-windows-x64.zip'
$denoUrl='https://github.com/denoland/deno/releases/download/v2.9.8/deno-x86_64-pc-windows-msvc.zip'
Invoke-WebRequest -Uri $denoUrl -OutFile $denoZip -UseBasicParsing
$denoExpected='cba84b26e0df5ae7f74fc66b86a95b866872a86292ebd84fa1e959927edd93bf'
$denoActual=(Get-FileHash -LiteralPath $denoZip -Algorithm SHA256).Hash.ToLowerInvariant()
if($denoActual -ne $denoExpected){throw 'Deno download checksum mismatch'}
$denoExtract=Join-Path $tools 'deno-extracted'
Expand-Archive -LiteralPath $denoZip -DestinationPath $denoExtract -Force
$denoBinary=Get-ChildItem $denoExtract -Filter 'deno.exe' -File -Recurse | Select-Object -First 1
if(!$denoBinary){throw 'Cannot find deno.exe in release archive'}
$denoOut=Join-Path $tools 'deno.exe'
Copy-Item -LiteralPath $denoBinary.FullName -Destination $denoOut -Force

# Fixed FFmpeg source build. Choose LGPL/shared, not GPL/full.
$ffFile='ffmpeg-n9.0.2-36-g6882969ce9-win64-lgpl-shared-9.0.zip'
$ffUrl='https://github.com/BtbN/FFmpeg-Builds/releases/download/autobuild-2026-10-25-13-00/'+$ffFile
$ffZip=Join-Path $tools $ffFile
Invoke-WebRequest -Uri $ffUrl -OutFile $ffZip -UseBasicParsing
$ffExpected='72e3fbaf17f8d5162c3010f9e58872fcb93ba2b03731fd0fff1ca9aabb616ea6'
$ffActual=(Get-FileHash -LiteralPath $ffZip -Algorithm SHA256).Hash.ToLowerInvariant()
if($ffActual -ne $ffExpected){throw 'FFmpeg download checksum mismatch'}
$ffExtract=Join-Path $tools 'ffmpeg-extracted'
Expand-Archive -LiteralPath $ffZip -DestinationPath $ffExtract -Force
$ffExe=Get-ChildItem -LiteralPath $ffExtract -Filter 'ffmpeg.exe' -Recurse -File | Select-Object -First 1
if(!$ffExe){throw 'Cannot find ffmpeg.exe in the LGPL archive'}
$ffBin=$ffExe.Directory.FullName
if(!(Test-Path (Join-Path $ffBin 'ffprobe.exe'))){throw 'ffprobe.exe is required by yt-dlp'}
$ffBinaryFolder=Join-Path $tools 'FFmpeg'
New-Item -ItemType Directory -Path $ffBinaryFolder -Force | Out-Null
Copy-Item -Path (Join-Path $ffBin '*') -Destination $ffBinaryFolder -Force
$ffDlls=Get-ChildItem $ffBinaryFolder -Filter '*.dll' -File
if($ffDlls.Count -lt 3){throw 'Missing shared LGPL FFmpeg DLLs'}

$licenses=@'
RISHIDM MEDIA ENGINE - THIRD PARTY LICENSE / SOURCE INFORMATION

FFmpeg 9.0.2 (LGPL shared build), BtbN fixed build:
https://github.com/BtbN/FFmpeg-Builds/releases/tag/autobuild-2026-10-25-13-00
https://ffmpeg.org/legal.html
https://github.com/FFmpeg/FFmpeg
This is the LGPL-labelled *shared library* variant, not the GPL/full build.
FFmpeg and its shared libraries are distinct subprocess dependencies. Include
the corresponding LGPL notices, version, and source availability when distributing.
Source for the underlying FFmpeg project and BtbN build scripts is linked above.
Do not remove these DLLs or their license information.

Deno v2.9.8, MIT-licensed JavaScript runtime:
https://github.com/denoland/deno/releases/tag/v2.9.8
https://github.com/denoland/deno/blob/v2.9.8/LICENSE.md
The JavaScript runtime executes YouTube challenge solver scripts in a sandboxed
environment as supported by yt-dlp. The runtime is provided as-is.

yt-dlp 2026.10.26:
https://github.com/yt-dlp/yt-dlp/releases/tag/2026.10.26
https://github.com/yt-dlp/yt-dlp/blob/2026.10.26/LICENSE

RishiDM does not authorize downloading protected or unauthorized media and
does not include any DRM circumvention tools.
'@
$licenseFile=Join-Path $tools 'MEDIA_LICENSES_AND_SOURCES.txt'
[IO.File]::WriteAllText($licenseFile,$licenses,$utf8)

# The existing v0.3 NSIS section already sets VideoTools as its output.
$needle='    File "' + (Join-Path $tools 'yt-dlp.exe') + '"'
$idx=$nsisText.IndexOf($needle,[StringComparison]::Ordinal)
if($idx -lt 0){throw 'Cannot find yt-dlp package line in NSIS'}
$end=$nsisText.IndexOf([char]10,$idx)
$package=@'
    File "__DENO__"
    File "__NOTICES__"
    SetOutPath "__DOLLAR__{INSTALL_DIR}\VideoTools\FFmpeg"
    File /r "__FFMPEG__\*.*"
'@
$package=$package.Replace('__DENO__',$denoOut).Replace('__NOTICES__',$licenseFile)
$package=$package.Replace('__DOLLAR__',[string][char]36).Replace('__FFMPEG__',$ffBinaryFolder)
$nsisText=$nsisText.Insert($end+1,$package+[char]10)
Write-Host "Bundled Deno 2.9.8 and LGPL-shared FFmpeg 9.0.2. Deno SHA=$denoActual FFmpeg SHA=$ffActual"
