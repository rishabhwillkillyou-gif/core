# RishiDM v0.5: replace short-lived video PowerShell dialog with in-app queue.
# Execute after v03-media-source.ps1 and before Kotlin/Gradle build.
$kotlinDir=Join-Path $src 'desktop/app/src/main/kotlin/com/abdownloadmanager/desktop'
$mediaDir=Join-Path $kotlinDir 'media'
New-Item -ItemType Directory -Path $mediaDir -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'v05/RishiDMVideoQueue.kt') -Destination (Join-Path $mediaDir 'RishiDMVideoQueue.kt') -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'v05/RishiDMVideoPane.kt') -Destination (Join-Path $kotlinDir 'pages/home/RishiDMVideoPane.kt') -Force
$utf8=New-Object System.Text.UTF8Encoding($false)

# The native host runs in a separate process. Route its message into the
# running application through the existing kotlinx-RPC service.
$interface='desktop/app/src/main/kotlin/com/abdownloadmanager/desktop/utils/singleInstance/service/IDefaultAppIPCService.kt'
Edit $interface '    suspend fun addDownloadByGui(request: AddDownloadsFromIntegration)' @'
    suspend fun addDownloadByGui(request: AddDownloadsFromIntegration)
    suspend fun enqueueRishiDMVideo(url: String): Boolean
'@
$implementation='desktop/app/src/main/kotlin/com/abdownloadmanager/desktop/utils/singleInstance/service/DefaultAppIPCServiceImpl.kt'
Edit $implementation '    override suspend fun addDownload(request: NewDownloadTask): Long {' @'
    override suspend fun enqueueRishiDMVideo(url: String): Boolean {
        awaitAppBoot()
        val queued = com.abdownloadmanager.desktop.media.RishiDMVideoQueue.enqueue(url)
        if (queued) {
            appComponent.activateHomeIfNotOpen()
        }
        return queued
    }

    override suspend fun addDownload(request: NewDownloadTask): Long {
'@
$def=Join-Path $src 'desktop/app/src/main/kotlin/com/abdownloadmanager/desktop/nativemessaging/host/DefinedHandlers.kt'
$contents=[IO.File]::ReadAllText($def).Replace(([char]13).ToString(),'')
$start=$contents.IndexOf('class RishiDMVideoNativeHandler(')
$end=$contents.IndexOf('object DefinedNativeMessagingHandlers {',$start)
if($start -lt 0 -or $end -le $start){throw 'Video native handler was not found'}
$replacement=@'
class RishiDMVideoNativeHandler(
    private val json: Json,
    private val appIPC: IPCServiceProviderAwakerSupport<IDefaultAppIPCService>
) : NativeMessagingMessageHandler {
    override fun accept(request: NativeMessagingMessage.Content): Boolean =
        request.action == "rishidm-video"

    override suspend fun handle(request: NativeMessagingMessage.Content): NativeMessagingMessage.Content {
        val url = json.decodeFromString<RishiDMVideoRequest>(request.payload).url
        require(url.length in 8..2048) { "Invalid video URL" }
        val uri = java.net.URI(url)
        require(uri.scheme?.lowercase() in listOf("http", "https") &&
            !uri.host.isNullOrBlank() && uri.rawUserInfo == null) { "Unsupported URL" }
        val queued = appIPC.getService().useService {
            it.enqueueRishiDMVideo(url)
        }
        return context(json) { NativeMessagingMessage.Content.boolean(queued) }
    }
}

'@
$contents=$contents.Substring(0,$start)+$replacement+$contents.Substring($end)
$before='            RishiDMVideoNativeHandler(json),'
if(!$contents.Contains($before)){throw 'Native handler registration mismatch'}
$contents=$contents.Replace($before,'            RishiDMVideoNativeHandler(json, appIPC),')
[IO.File]::WriteAllText($def,$contents,$utf8)

$homeRel='desktop/app/src/main/kotlin/com/abdownloadmanager/desktop/pages/home/HomePage.kt'
Edit $homeRel '                    var lastSelected by remember { mutableStateOf(null as Long?) }' @'
                    // In-app video jobs, controlled by the same desktop process as normal downloads.
                    RishiDMVideoPane()
                    var lastSelected by remember { mutableStateOf(null as Long?) }
'@

Write-Host 'RishiDM v0.5: video tasks now travel through main-app IPC and appear in the native home screen.'
