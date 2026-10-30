# Source-level additions for RishiDM v0.3 video support.
# Invoked after both pinned upstream repositories are cloned and BEFORE npm build.
$handlersRel='desktop/app/src/main/kotlin/com/abdownloadmanager/desktop/nativemessaging/host/DefinedHandlers.kt'
$handlerFile=Join-Path $src $handlersRel
$kotlin=[IO.File]::ReadAllText($handlerFile).Replace(([char]13).ToString(),'')
if($kotlin.Contains('class RishiDMVideoNativeHandler')){throw 'Video native handler already exists'}
$videoHandler=@'
@kotlinx.serialization.Serializable
private data class RishiDMVideoRequest(val url: String)

/**
 * Opens the isolated video assistant without changing AB's HTTP download engine.
 * Browser-provided URLs are validated and passed as a distinct process argument.
 * This never forwards cookies, credentials or DRM keys.
 */
class RishiDMVideoNativeHandler(
    private val json: Json
) : NativeMessagingMessageHandler {
    override fun accept(request: NativeMessagingMessage.Content): Boolean =
        request.action == "rishidm-video"

    override suspend fun handle(request: NativeMessagingMessage.Content): NativeMessagingMessage.Content {
        val url = json.decodeFromString<RishiDMVideoRequest>(request.payload).url
        require(url.length in 8..2048) { "Invalid video URL length" }
        val uri = java.net.URI(url)
        require(uri.scheme?.lowercase() in listOf("http", "https") &&
            !uri.host.isNullOrBlank() && uri.rawUserInfo == null) {
            "Only public HTTP(S) video-page URLs are accepted"
        }
        val folder = com.abdownloadmanager.desktop.utils.AppInfo.installationFolder
            ?: error("Video helper requires a packaged Windows installation")
        val root = java.io.File(folder)
        val helper = java.io.File(root, "video-downloader.ps1")
        check(helper.isFile) { "Video helper is missing. Reinstall the full RishiDM package." }
        ProcessBuilder(
            "powershell.exe", "-NoProfile", "-STA", "-ExecutionPolicy", "Bypass",
            "-File", helper.absolutePath, "-Url", url
        ).directory(root).start()
        return context(json) {
            NativeMessagingMessage.Content.boolean(true)
        }
    }
}

'@
$marker='object DefinedNativeMessagingHandlers {'
if(!$kotlin.Contains($marker)){throw 'Native handler definition marker missing'}
$kotlin=$kotlin.Replace($marker,$videoHandler+$marker)
$old='            AddDownloadNativeRequestHandler(json, appIPC),'
if(!$kotlin.Contains($old)){throw 'Native handler registry marker missing'}
$kotlin=$kotlin.Replace($old,$old+[char]10+'            RishiDMVideoNativeHandler(json),')
[IO.File]::WriteAllText($handlerFile,$kotlin,$utf8)

$menuFile=Join-Path $extensionRoot 'src/contextmenus/ContextMenus.ts'
$menu=[IO.File]::ReadAllText($menuFile).Replace(([char]13).ToString(),'')
$old='    downloadSelectedWithAbDm: "download-selected-with-ab-dm",'
if(!$menu.Contains($old)){throw 'Context menu IDs have changed'}
$menu=$menu.Replace($old,$old+[char]10+'    downloadVideoWithRishiDM: "rishidm-download-video",')
$marker='    browser.contextMenus.create({'+[char]10+'        id: optionIds.downloadWithAbDm,'
$videoMenu=@'
    browser.contextMenus.create({
        id: optionIds.downloadVideoWithRishiDM,
        title: "Download video with RishiDM",
        contexts: ["page", "link", "video"]
    })
'@
if(!$menu.Contains($marker)){throw 'Context menu creation marker missing'}
$menu=$menu.Replace($marker,$videoMenu+[char]10+$marker)
$marker='        switch (args.menuItemId) {'
$videoAction=@'
            case optionIds.downloadVideoWithRishiDM: {
                // No silent session/cookie harvesting. User explicitly chooses the action.
                const videoUrl = args.linkUrl || args.srcUrl || args.pageUrl;
                if (!videoUrl || !/^https?:\/\//i.test(videoUrl)) break;
                try {
                    const response = await browser.runtime.sendNativeMessage("com.rishidm", {
                        id: "B_VIDEO_" + Date.now(),
                        content: {
                            action: "rishidm-video",
                            isError: false,
                            payload: JSON.stringify({url: videoUrl})
                        }
                    });
                    if (!response || response.content?.isError) {
                        console.error("RishiDM media helper was rejected", response);
                    }
                } catch (e) {
                    console.error("Could not reach RishiDM's video helper", e);
                }
                break;
            }
'@
if(!$menu.Contains($marker)){throw 'Context menu switch marker missing'}
$menu=$menu.Replace($marker,$marker+[char]10+$videoAction+[char]10)
[IO.File]::WriteAllText($menuFile,$menu,$utf8)

Write-Host "RishiDM v0.3 native video handler + browser context menu patched."
