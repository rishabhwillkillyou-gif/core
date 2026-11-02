$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$src=Join-Path $PSScriptRoot 'rishidm-upstream'
$out=Join-Path $PSScriptRoot 'rishidm-output'
$utf8=New-Object System.Text.UTF8Encoding($false)
New-Item -ItemType Directory -Path $out -Force | Out-Null
git clone --depth 1 --branch v1.11.1 https://github.com/amir1376/ab-download-manager.git $src
if($LASTEXITCODE -ne 0){throw 'Could not download upstream source'}
function Edit([string]$rel,[string]$old,[string]$new){
  $file=Join-Path $src $rel
  $content=[IO.File]::ReadAllText($file).Replace(([char]13).ToString(),'')
  $old=$old.Replace(([char]13).ToString(),'')
  $n=([regex]::Matches($content,[regex]::Escape($old))).Count
  if($n -ne 1){throw "Patch failure: $rel, $n matches for $old"}
  [IO.File]::WriteAllText($file,$content.Replace($old,$new),$utf8)
}
Edit 'settings.gradle.kts' 'rootProject.name = "ABDownloadManager"' 'rootProject.name = "RishiDM"'
Edit 'build.gradle.kts' 'version = (gitVersion.getVersion() ?: fallBackVersion).toVersion()' 'version = "0.9.5".toVersion()'
$v='buildSrc/src/main/kotlin/buildlogic/versioning/VersionUtil.kt'
Edit $v 'return "AB Download Manager"' 'return "RishiDM"'
Edit $v 'return ".abdm"' 'return ".rishidm"'
Edit $v 'return "com.abdownloadmanager"' 'return "com.rishidm"'
Edit 'desktop/app/gradle.properties' '2b3aeac1-271a-4f05-b26e-8e0d2a81b215' 'b9aa03b8-07ef-4f27-98ec-46d0d700f0dd'
$a='desktop/app/src/main/kotlin/com/abdownloadmanager/desktop/utils/AppInfo.kt'
Edit $a 'const val mainApp = "ABDownloadManager"' 'const val mainApp = "RishiDM"'
Edit $a 'const val cliApp = "ABDownloadManagerCli"' 'const val cliApp = "RishiDMCli"'
Edit $a 'const val nativeMessagingHost = "ABDownloadManagerNativeMessagingHost"' 'const val nativeMessagingHost = "RishiDMNativeMessagingHost"'
$b='desktop/app/build.gradle.kts'
Edit $b 'vendor = "abdownloadmanager.com"' 'vendor = "RishiDM"'
Edit $b '"app_publisher" to "abdownloadmanager.com"' '"app_publisher" to "RishiDM"'
Edit $b '"copyright" to "© 2024-present AB Download Manager App"' '"copyright" to "RishiDM fork based on AB Download Manager"'
Edit $b '"project_website" to "www.abdownloadmanager.com"' '"project_website" to "github.com/rishabhwillkillyou-gif/core/tree/rishidm-build"'
$d='shared/app/src/commonMain/kotlin/com/abdownloadmanager/shared/storage/appsettings/DefaultAppSettings.kt'
Edit $d '.resolve("ABDM").canonicalFile.absolutePath' '.resolve("RishiDM").canonicalFile.absolutePath'
Edit $d 'open val apiPort: Int get() = 15151' 'open val apiPort: Int get() = 15152'
Edit $d 'open val apiAuthEnabled: Boolean get() = false' 'open val apiAuthEnabled: Boolean get() = true'
Edit $d 'open val autoStartOnBoot: Boolean get() = true' 'open val autoStartOnBoot: Boolean get() = false'
$c='shared/app/build.gradle.kts'
Edit $c '"https://chromewebstore.google.com/detail/ab-download-manager-brows/bbobopahenonfdgjgaleledndnnfhooj"' '"https://github.com/rishabhwillkillyou-gif/core/tree/rishidm-build"'
Edit $c '"https://addons.mozilla.org/en-US/firefox/addon/ab-download-manager/"' '"https://github.com/rishabhwillkillyou-gif/core/tree/rishidm-build"'
Edit $c '"firefox-integration@abdownloadmanager.com"' '"rishidm-integration@rishidm.local"'
Edit $c '"chrome-extension://bbobopahenonfdgjgaleledndnnfhooj/"' '"chrome-extension://aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/"'
$di='desktop/app/src/main/kotlin/com/abdownloadmanager/desktop/di/Di.kt'
$before=@'
    single<UpdateChecker> {
        GithubUpdateChecker(
            AppVersion.get(),
            githubApi = GithubApi(
                owner = SharedConstants.projectGithubOwner,
                repo = SharedConstants.projectGithubRepo,
                client = OkHttpClient
                    .Builder()
                    .build()
            )
        )
    }
'@
$after=@'
    single<UpdateChecker> {
        RishiDMNoUpdateChecker(AppVersion.get())
    }
'@
Edit $di $before $after
Edit $di 'import com.abdownloadmanager.updatechecker.GithubUpdateChecker' 'import com.abdownloadmanager.updatechecker.RishiDMNoUpdateChecker'
Edit 'shared/updater/src/commonMain/kotlin/com/abdownloadmanager/updatechecker/UpdateChecker.kt' 'require(latest.updateSource.isNotEmpty()) { "There is no release for this platform" }' 'if (latest.updateSource.isEmpty()) return null'
$newfile=Join-Path $src 'shared/updater/src/commonMain/kotlin/com/abdownloadmanager/updatechecker/RishiDMNoUpdateChecker.kt'
[IO.File]::WriteAllText($newfile,@'
package com.abdownloadmanager.updatechecker
import io.github.z4kn4fein.semver.Version
import ir.amirab.util.platform.Arch
import ir.amirab.util.platform.Platform
/** The fork must never install an AB Download Manager upstream update. */
class RishiDMNoUpdateChecker(currentVersion: Version) : UpdateChecker(currentVersion) {
    override suspend fun getMyPlatformLatestVersion() = UpdateInfo(
        version = currentVersion,
        platform = Platform.getCurrentPlatform(),
        arch = Arch.getCurrentArch(),
        updateSource = emptyList(),
        changeLog = "RishiDM auto-updates are not configured."
    )
}
'@,$utf8)
$reg='desktop/app/src/main/kotlin/com/abdownloadmanager/desktop/nativemessaging/NativeMessagingManifestApplier.kt'
$old='    private val chromeRegistryPath get() = "HKCU\\SOFTWARE\\Google\\Chrome\\NativeMessagingHosts\\${AppInfo.packageName}"'
$new='    private val edgeRegistryPath get() = "HKCU\\SOFTWARE\\Microsoft\\Edge\\NativeMessagingHosts\\${AppInfo.packageName}"'
Edit $reg $old ($old + [char]10 + $new)
$old=@'
        WindowsRegistry.setValueInRegistry(
            path = chromeRegistryPath,
            key = null,
            value = chromeManifestFile.toString()
        )
'@
$new=@'
        WindowsRegistry.setValueInRegistry(
            path = edgeRegistryPath,
            key = null,
            value = chromeManifestFile.toString()
        )
'@
Edit $reg $old ($old + [char]10 + $new)
$old=@'
        WindowsRegistry.removePathInRegistry(
            path = chromeRegistryPath,
        )
'@
$new=@'
        WindowsRegistry.removePathInRegistry(
            path = edgeRegistryPath,
        )
'@
Edit $reg $old ($old + [char]10 + $new)

# ---- RishiDM v0.2 preview: ship the browser extension WITH the installer ----
# Browser consent remains explicit. Windows installer registers the native bridge;
# browser store approval is the production one-click path, not force-install policies.
$extensionRoot = Join-Path $PSScriptRoot 'extension-upstream'
git clone --depth 1 --branch v1.5.0 https://github.com/amir1376/ab-download-manager-browser-integration.git $extensionRoot
if($LASTEXITCODE -ne 0){throw 'Could not fetch pinned AB browser extension source'}
function EditExtension([string]$rel,[string]$old,[string]$new){
 $file=Join-Path $extensionRoot $rel
 $data=[IO.File]::ReadAllText($file).Replace(([char]13).ToString(),'')
 if(([regex]::Matches($data,[regex]::Escape($old))).Count -ne 1){throw "Extension patch mismatch: $rel, $old"}
 [IO.File]::WriteAllText($file,$data.Replace($old,$new),$utf8)
}
EditExtension 'src/utils/Constants.ts' 'packageName: "com.abdownloadmanager"' 'packageName: "com.rishidm"'
EditExtension 'src/utils/Constants.ts' 'defaultPort: 15151' 'defaultPort: 15152'
EditExtension 'src/manifest/shared.ts' 'default_title: "AB Download Manager"' 'default_title: "RishiDM"'
EditExtension 'src/manifest/manifest.firefox.ts' 'firefox-integration@abdownloadmanager.com' 'rishidm-integration@rishidm.local'
EditExtension 'src/manifest/manifest.chrome.ts' 'manifest_version: 3,' ('manifest_version: 3,' + [char]10 + '        key: "__PUBLIC_KEY__",'.Replace('__PUBLIC_KEY__','MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAsTV0YepsrO6N5hMpTO9mufCDUOVcYlJxpkBjOmQ1DKuFhmX6CyJpkzDXuMzeRONrA5rXr65sjb+h7FGFyDRar3D6GxLFRsBtcFtnVCxcyuc6CxEa5oy4EYhBE8I1X2ZaT8WN8U3QpAXuRapCsTJpHVFuPSdFgFQy39HT+rCN6aVsfS9+pPTxBssD0o65vmcYh91ZrFUNj4URupyQdgPlWeVTxFLLZojp0+INMtNjsKjSBPTeIrGhWyZBEbVqVS+1G7T52jzzBFakyXLfpa4QIuzaZe72sBZUBJm945v2vF1Aurq/cMZgmBIjGkcIOniMqjJ4ntLxsSU6eDCnGEOEoQIDAQAB'))
$manifestPath=Join-Path $extensionRoot 'src/manifest/manifest.chrome.ts'
$manifestText=[IO.File]::ReadAllText($manifestPath).Replace('MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAsTV0YepsrO6N5hMpTO9mufCDUOVcYlJxpkBjOmQ1DKuFhmX6CyJpkzDXuMzeRONrA5rXr65sjb+h7FGFyDRar3D6GxLFRsBtcFtnVCxcyuc6CxEa5oy4EYhBE8I1X2ZaT8WN8U3QpAXuRapCsTJpHVFuPSdFgFQy39HT+rCN6aVsfS9+pPTxBssD0o65vmcYh91ZrFUNj4URupyQdgPlWeVTxFLLZojp0+INMtNjsKjSBPTeIrGhWyZBEbVqVS+1G7T52jzzBFakyXLfpa4QIuzaZe72sBZUBJm945v2vF1Aurq/cMZgmBIjGkcIOniMqjJ4ntLxsSU6eDCnGEOEoQIDAQAB','MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAsTV0YepsrO6N5hMpTO9mufCDUOVcYlJxpkBjOmQ1DKuFhmX6CyJpkzDXuMzeRONrA5rXr65sjb+h7FGFyDRar3D6GxLFRsBtcFtnVCxcyuc6CxEa5oy4EYhBE8I1X2ZaT8WN8U3QpAXuRapCsTJpHVFuPSdFgFQy39HT+rCN6aVsfS9+pPTxBssD0o65vmcYh91ZrFUNj4URupyQdgPlWeVTxFLLZojp0+INMtNjsKjSBPTeIrGhWyZBEbVqVS+1G7T52jzzBFakyXLfpa4QIuzaZe72sBZUBJm945v2vF1Aurq/cMZgmBIjGkcIOniMqjJ4ntLxsSU6eDCnGEOEoQIDAQAB')
[IO.File]::WriteAllText($manifestPath,$manifestText,$utf8)
$pkgPath=Join-Path $extensionRoot 'package.json'
$pkg=Get-Content -LiteralPath $pkgPath -Raw | ConvertFrom-Json
$pkg.displayName='RishiDM Browser Integration'
$pkg.description='Capture downloads with the RishiDM Windows application'
$pkg.version='0.9.5'
[IO.File]::WriteAllText($pkgPath,($pkg | ConvertTo-Json -Depth 20),$utf8)
foreach($loc in Get-ChildItem (Join-Path $extensionRoot 'public/_locales') -Filter 'messages.json' -Recurse -File){
 $c=[IO.File]::ReadAllText($loc.FullName)
 [IO.File]::WriteAllText($loc.FullName,$c.Replace('AB Download Manager','RishiDM').Replace('AB DM','RishiDM'),$utf8)
}
. (Join-Path $PSScriptRoot 'v03-media-source.ps1')
. (Join-Path $PSScriptRoot 'v04-browser-source.ps1')
. (Join-Path $PSScriptRoot 'v051-browser-source.ps1')
. (Join-Path $PSScriptRoot 'v052-shortform-source.ps1')
. (Join-Path $PSScriptRoot 'v06-media-source.ps1')
. (Join-Path $PSScriptRoot 'v08-frame-diagnostics.ps1')
. (Join-Path $PSScriptRoot 'v091-media-inspector.ps1')
. (Join-Path $PSScriptRoot 'v092-media-stages.ps1')
. (Join-Path $PSScriptRoot 'v093-hls-failure-diagnostics.ps1')
. (Join-Path $PSScriptRoot 'v094-public-hls.ps1')
. (Join-Path $PSScriptRoot 'v095-dropbox-safe-handoff.ps1')
. (Join-Path $PSScriptRoot 'v05-integrate-source.ps1')
# Apply original RishiDM identity to every visible surface before packaging.
$brandGenerator=Join-Path $PSScriptRoot 'branding/generate_brand_assets.py'
& python $brandGenerator --source-root $src --extension-root $extensionRoot
if($LASTEXITCODE -ne 0){throw 'RishiDM icon asset generation failed'}
$nativeIcon=Join-Path $src 'shared/resources/src/commonMain/kotlin/com/abdownloadmanager/resources/icons/AppIcon.kt'
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'branding/RishiDMAppIcon.kt') -Destination $nativeIcon -Force
if(!(Test-Path (Join-Path $src 'desktop/app/icons/icon.ico'))){throw 'RishiDM Windows icon missing'}
Write-Host 'Original RishiDM icon applied: Windows EXE, installer, native UI, browser extension.'
$toolbarSrc=Join-Path $PSScriptRoot 'v09/RishiDMAddUrlButton.kt'
$toolbarDst=Join-Path $src 'shared/app/src/commonMain/kotlin/com/abdownloadmanager/shared/ui/widget/AddUrlButton.kt'
Copy-Item -LiteralPath $toolbarSrc -Destination $toolbarDst -Force
Write-Host 'RishiDM v0.9: native toolbar call-to-action styled with original gradient.'

Push-Location $extensionRoot
try {
 npm ci --no-audit --no-fund
 if($LASTEXITCODE -ne 0){throw 'Extension npm ci failed'}
 node (Join-Path $PSScriptRoot 'tests/hls-regression.cjs') $extensionRoot
 if($LASTEXITCODE -ne 0){throw 'HLS regressions failed'}
 node (Join-Path $PSScriptRoot 'tests/dropbox-regression.cjs') $extensionRoot
 if($LASTEXITCODE -ne 0){throw 'Dropbox regressions failed'}
 if($LASTEXITCODE -ne 0){throw 'Public HLS regression checks failed'}
 npm run build
 if($LASTEXITCODE -ne 0){throw 'Extension build failed'}
}finally{Pop-Location}
$chromeOut=Join-Path $extensionRoot 'dist/chrome'
$firefoxOut=Join-Path $extensionRoot 'dist/firefox'
if(!(Test-Path (Join-Path $chromeOut 'manifest.json')) -or !(Test-Path (Join-Path $firefoxOut 'manifest.json'))){throw 'Expected extension manifests missing'}
$chromeManifest=Get-Content (Join-Path $chromeOut 'manifest.json') -Raw | ConvertFrom-Json
if($chromeManifest.key -ne 'MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAsTV0YepsrO6N5hMpTO9mufCDUOVcYlJxpkBjOmQ1DKuFhmX6CyJpkzDXuMzeRONrA5rXr65sjb+h7FGFyDRar3D6GxLFRsBtcFtnVCxcyuc6CxEa5oy4EYhBE8I1X2ZaT8WN8U3QpAXuRapCsTJpHVFuPSdFgFQy39HT+rCN6aVsfS9+pPTxBssD0o65vmcYh91ZrFUNj4URupyQdgPlWeVTxFLLZojp0+INMtNjsKjSBPTeIrGhWyZBEbVqVS+1G7T52jzzBFakyXLfpa4QIuzaZe72sBZUBJm945v2vF1Aurq/cMZgmBIjGkcIOniMqjJ4ntLxsSU6eDCnGEOEoQIDAQAB'){throw 'Chrome extension stable ID key is missing'}
Edit 'shared/app/build.gradle.kts' '"chrome-extension://aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/"' '"chrome-extension://fflnlejbfglkcpigedkajcpilphkkmib/"'
$nsis=Join-Path $src 'desktop/app/resources/installer/nsis-script-template.nsi'
$nsisText=[IO.File]::ReadAllText($nsis).Replace(([char]13).ToString(),'')
$marker='    File /nonfatal /r '
$idx=$nsisText.IndexOf($marker,[StringComparison]::Ordinal)
if($idx -lt 0 -or $nsisText.IndexOf($marker,$idx+1,[StringComparison]::Ordinal) -ge 0){throw 'Cannot identify unique installer File block'}
$lineEnd=$nsisText.IndexOf([char]10,$idx)
$extra=@'
    SetOutPath "__DOLLAR__{INSTALL_DIR}\BrowserExtension\Chrome"
    File /r "__CHROME__\*.*"
    SetOutPath "__DOLLAR__{INSTALL_DIR}\BrowserExtension\Firefox"
    File /r "__FIREFOX__\*.*"
    SetOutPath "__DOLLAR__{INSTALL_DIR}"
    File "__WIZARD__"
    File "__CMD__"
    CreateDirectory "__DOLLAR__SMPROGRAMS\__DOLLAR__{APP_DISPLAY_NAME}"
    CreateShortCut "__DOLLAR__SMPROGRAMS\__DOLLAR__{APP_DISPLAY_NAME}\Connect Browser.lnk" "__DOLLAR__{INSTALL_DIR}\BrowserSetup.cmd"
'@
$extra=$extra.Replace('__DOLLAR__',[string][char]36).Replace('__CHROME__',$chromeOut).Replace('__FIREFOX__',$firefoxOut).Replace('__WIZARD__',(Join-Path $PSScriptRoot 'browser-setup.ps1')).Replace('__CMD__',(Join-Path $PSScriptRoot 'BrowserSetup.cmd'))
$nsisText=$nsisText.Insert($lineEnd+1,$extra+[char]10)
$cleanMarker='    RmDir /r "' + [char]36 + '{INSTALL_DIR}\runtime"'
if(!$nsisText.Contains($cleanMarker)){throw 'Installer uninstall cleanup marker missing'}
$remove= '    RmDir /r "' + [char]36 + '{INSTALL_DIR}\BrowserExtension"' + [char]10 + '    Delete "' + [char]36 + '{INSTALL_DIR}\browser-setup.ps1"' + [char]10 + '    Delete "' + [char]36 + '{INSTALL_DIR}\BrowserSetup.cmd"'
$nsisText=$nsisText.Replace($cleanMarker,$cleanMarker+[char]10+$remove)
# Open browser guide once when the interactive installer finishes, never force-install an extension.
$successBlock=@'
Function .onInstSuccess
    ; Check if the installer is running in silent mode
    ${If} ${Silent}
        ; In silent mode, always run the app
        Call RunMainBinary
    ${Endif}
FunctionEnd
'@
$successReplacement=@'
Function .onInstSuccess
    ; Silent installations must never open an interactive setup dialog.
    ${If} ${Silent}
        Call RunMainBinary
    ${Else}
        ; Install the desktop side automatically; let the user approve the browser extension.
        IfFileExists "$INSTDIR\BrowserSetup.cmd" 0 +2
        ExecShell "open" "$INSTDIR\BrowserSetup.cmd"
    ${Endif}
FunctionEnd
'@
$successBlock=$successBlock.Replace(([char]13).ToString(),'')
$successReplacement=$successReplacement.Replace(([char]13).ToString(),'')
if (-not $nsisText.Contains($successBlock)) { throw "Cannot find NSIS completion block" }
$nsisText=$nsisText.Replace($successBlock,$successReplacement)
$nsisText=$nsisText.Replace('Connect Browser.lnk','Connect RishiDM to Chrome or Edge.lnk')
. (Join-Path $PSScriptRoot 'v03-media-installer.ps1')
. (Join-Path $PSScriptRoot 'v04-media-installer.ps1')
# RishiDM v0.9: explicit icon assignment to avoid stale Windows shortcuts.
$iconSource=Join-Path $src 'desktop/app/icons/icon.ico'
if(!(Test-Path $iconSource)){throw 'RishiDM icon not generated'}
$nsisLine='    File /nonfatal /r '
if(([regex]::Matches($nsisText,[regex]::Escape($nsisLine))).Count -ne 1){
  throw 'Expected unique application File line in NSIS template'
}
$nsisText=$nsisText.Replace($nsisLine,
   ('    File /oname=RishiDM-v09.ico "'+$iconSource+'"' + [char]10 + $nsisLine))
$startOld='createShortCut "$SMPROGRAMS\${APP_DISPLAY_NAME}\${APP_DISPLAY_NAME}.lnk" "${INSTALL_DIR}\${MAIN_BINARY_NAME}.exe"'
$startNew='createShortCut "$SMPROGRAMS\${APP_DISPLAY_NAME}\${APP_DISPLAY_NAME}.lnk" "${INSTALL_DIR}\${MAIN_BINARY_NAME}.exe" "" "${INSTALL_DIR}\RishiDM-v09.ico" 0'
if(!$nsisText.Contains($startOld)){throw 'Start Menu shortcut marker not found'}
$nsisText=$nsisText.Replace($startOld,$startNew)
$deskOld='CreateShortcut "$DESKTOP\${APP_DISPLAY_NAME}.lnk" "${INSTALL_DIR}\${MAIN_BINARY_NAME}.exe"'
$deskNew='CreateShortcut "$DESKTOP\${APP_DISPLAY_NAME}.lnk" "${INSTALL_DIR}\${MAIN_BINARY_NAME}.exe" "" "${INSTALL_DIR}\RishiDM-v09.ico" 0'
if(!$nsisText.Contains($deskOld)){throw 'Desktop shortcut marker not found'}
$nsisText=$nsisText.Replace($deskOld,$deskNew)
$cleanOld='    Delete "${INSTALL_DIR}\${MAIN_BINARY_NAME}.ico"'
if(!$nsisText.Contains($cleanOld)){throw 'Icon cleanup marker not found'}
$nsisText=$nsisText.Replace($cleanOld,$cleanOld+[char]10+'    Delete "${INSTALL_DIR}\RishiDM-v09.ico"')
Write-Host 'RishiDM v0.9 installer writes versioned ICO and resets desktop/start shortcut icon paths.'
[IO.File]::WriteAllText($nsis,$nsisText,$utf8)
Write-Host 'Built Chrome/Firefox extension and embedded it in RishiDM installer.'
# ---- End v0.2 additions ----

Write-Host 'RishiDM rebranding patches applied.'
Push-Location $src
try {
  $env:SKIP_ANDROID_BUILD='true'
  & .\gradlew.bat createReleaseFolderForCi --no-daemon --stacktrace
  if($LASTEXITCODE -ne 0){throw "Gradle compilation error $LASTEXITCODE"}
} finally {Pop-Location}
$bin=Join-Path $src 'build/ci-release/binaries'
$exe=Get-ChildItem $bin -Filter 'RishiDM_*_windows_x64.exe' | Select-Object -First 1
if(-not $exe){throw "No Windows x64 EXE produced"}
$target=Join-Path $out 'RishiDM_Setup_0.9.5_x64.exe'
Copy-Item $exe.FullName $target -Force
$stream=[IO.File]::OpenRead($target)
try{
  $a=$stream.ReadByte();$b=$stream.ReadByte()
}finally{$stream.Dispose()}
if($a -ne 77 -or $b -ne 90 -or (Get-Item $target).Length -lt 1000000){throw 'Installer failed basic PE size/signature check'}
Write-Host "Installer created: $target"
