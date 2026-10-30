# RishiDM v0.4 Chrome/Edge/Firefox browser-video controls.
# Run after v0.3 source patch and before npm run build.
$bgFile=Join-Path $extensionRoot 'src/background/background.ts'
$bg=[IO.File]::ReadAllText($bgFile).Replace(([char]13).ToString(),'')
$marker='run(async () => {'
$addon=@'
/** Explicit page/video action, not automatic browser-wide media interception. */
async function rishidmOpenVideo(url: unknown): Promise<boolean> {
    if (typeof url !== "string" || url.length > 2048 || !/^https?:\/\//i.test(url)) {
        return false;
    }
    try {
        const response = await browser.runtime.sendNativeMessage("com.rishidm", {
            id: "B_VIDEO_" + Date.now(),
            content: {
                action: "rishidm-video",
                isError: false,
                payload: JSON.stringify({url})
            }
        });
        return !!response && !response.content?.isError;
    } catch (error) {
        console.error("RishiDM video assistant is unavailable", error);
        return false;
    }
}
browser.runtime.onMessage.addListener((message: any) => {
    if (!message || message.rishidmVideoAction !== "open") return undefined;
    return rishidmOpenVideo(message.url);
});

'@
if(!$bg.Contains($marker)){throw 'Cannot find background bootstrap'}
$bg=$bg.Replace($marker,$addon+$marker)
$bg=$bg.Replace('import {initializeOptions} from "~/contextmenus/ContextMenus";','import {initializeOptions} from "~/contextmenus/ContextMenus";'+[char]10+'import browser from "webextension-polyfill";')
[IO.File]::WriteAllText($bgFile,$bg,$utf8)

$popupFile=Join-Path $extensionRoot 'src/browseractionpopup/BrowserAction.tsx'
$popup=[IO.File]::ReadAllText($popupFile).Replace(([char]13).ToString(),'')
$marker='            <AutoCaptureSection enabled={vm.autoCaptureLinks}'
$button=@'
            <div className="px-4 py-3">
              <button className="btn btn-primary w-full" onClick={async () => {
                try {
                  const [tab] = await browser.tabs.query({active:true,currentWindow:true});
                  const url = tab?.url;
                  if (!url || !/^https?:\/\//i.test(url)) {
                    alert("Open a video webpage in a normal browser tab first.");
                    return;
                  }
                  const ok = await browser.runtime.sendMessage({rishidmVideoAction:"open",url});
                  if (ok) window.close();
                  else alert("RishiDM is not connected. Open the desktop application and retry.");
                } catch (e) {
                  alert("Could not connect to the RishiDM video assistant.");
                }
              }}>Download video from this tab</button>
            </div>
'@
if(!$popup.Contains($marker)){throw 'Cannot identify extension popup action area'}
$popup=$popup.Replace($marker,$button+[char]10+$marker)
[IO.File]::WriteAllText($popupFile,$popup,$utf8)

$contentFile=Join-Path $extensionRoot 'src/contentscripts/ContentScript.ts'
$cs=[IO.File]::ReadAllText($contentFile).Replace(([char]13).ToString(),'')
$addon=@'
/**
 * YouTube replaces the browser's right-click menu over its video player.
 * Offer a separate explicit, user-initiated overlay, without scraping streams.
 */
function setupRishiDMYouTubeOverlay() {
    if (!/(^|\.)youtube\.com$/i.test(location.hostname)) return;
    let button: HTMLButtonElement | null = null;
    const render = () => {
        const watching = location.pathname === "/watch" && !!new URLSearchParams(location.search).get("v");
        const player = document.querySelector<HTMLElement>("#movie_player");
        if (!watching || !player) {
            button?.remove(); button = null;
            return;
        }
        if (button && !button.isConnected) button = null;
        if (button && button.parentElement === player) return;
        button?.remove();
        button = document.createElement("button");
        button.type = "button";
        button.textContent = "↓ Download with RishiDM";
        button.title = "Open RishiDM Video Downloader for this YouTube page";
        button.style.cssText = "position:absolute;top:12px;right:12px;z-index:9999;" +
            "font-family:Arial,sans-serif;font-size:13px;font-weight:bold;" +
            "border-radius:7px;padding:9px 13px;background:#532ad2;color:#fff;" +
            "border:1px solid #a899ff;cursor:pointer;box-shadow:0 2px 8px #0008;";
        button.addEventListener("click", async event => {
            event.preventDefault();
            event.stopPropagation();
            const url = location.href;
            const ok = await browser.runtime.sendMessage({rishidmVideoAction:"open",url});
            if (!ok) alert("RishiDM desktop connection is unavailable. Start RishiDM and retry.");
        });
        player.appendChild(button);
    };
    render();
    window.addEventListener("yt-navigate-finish", render);
    window.addEventListener("popstate", render);
    window.setInterval(render, 1800);
}
'@
$marker='const showPopupDelayed = debounce(500)'
if(!$cs.Contains($marker)){throw 'Cannot find content bootstrap'}
$cs=$cs.Replace($marker,$addon+[char]10+$marker)
$marker='    await Configs.boot()'
if(!$cs.Contains($marker)){throw 'Cannot find content boot'}
$cs=$cs.Replace($marker,$marker+[char]10+'    setupRishiDMYouTubeOverlay()')
[IO.File]::WriteAllText($contentFile,$cs,$utf8)
Write-Host 'RishiDM v0.4 toolbar video action and YouTube floating control added.'
