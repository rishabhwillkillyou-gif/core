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
Edit 'build.gradle.kts' 'version = (gitVersion.getVersion() ?: fallBackVersion).toVersion()' 'version = "0.1.0".toVersion()'
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
$target=Join-Path $out 'RishiDM_Setup_0.1.0_x64.exe'
Copy-Item $exe.FullName $target -Force
$stream=[IO.File]::OpenRead($target)
try{
  $a=$stream.ReadByte();$b=$stream.ReadByte()
}finally{$stream.Dispose()}
if($a -ne 77 -or $b -ne 90 -or (Get-Item $target).Length -lt 1000000){throw 'Installer failed basic PE size/signature check'}
Write-Host "Installer created: $target"
