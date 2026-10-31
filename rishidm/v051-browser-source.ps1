# RishiDM 0.5.1: honest browser acknowledgements + generic video overlay in subframes.
# Run AFTER the v0.4 video extension patch but BEFORE npm build.
$utf8=New-Object System.Text.UTF8Encoding($false)
function ReplaceOnce([string]$file,[string]$old,[string]$new) {
 $c=[IO.File]::ReadAllText($file).Replace(([char]13).ToString(),'')
 $count=([regex]::Matches($c,[regex]::Escape($old))).Count
 if($count -ne 1){throw "Patch failed: $file, matches=$count"}
 [IO.File]::WriteAllText($file,$c.Replace($old,$new),$utf8)
}
$baseManifest=Join-Path $extensionRoot 'src/manifest/shared.ts'
ReplaceOnce $baseManifest '            matches: ["*://*/*"],' @'
            matches: ["*://*/*"],
            all_frames: true,
            match_about_blank: true,
'@
$background=Join-Path $extensionRoot 'src/background/background.ts'
ReplaceOnce $background '        return !!response && !response.content?.isError;' @'
        if (!response?.content) throw new Error("Native host gave no response");
        if (response.content.isError) {
            let message = "RishiDM desktop rejected the video request";
            try {
                const body = JSON.parse(response.content.payload ?? "{}");
                message = body.message || message;
            } catch {}
            throw new Error(message);
        }
        if (response.content.payload !== "true") {
            throw new Error("RishiDM did not add this video to its queue");
        }
        return true;
'@
$content=Join-Path $extensionRoot 'src/contentscripts/ContentScript.ts'
ReplaceOnce $content '            const ok = await browser.runtime.sendMessage({rishidmVideoAction:"open",url});' @'
            button!.textContent = "Connecting to RishiDM…";
            button!.disabled = true;
            const ok = await browser.runtime.sendMessage({rishidmVideoAction:"open",url});
            button!.disabled = false;
            button!.textContent = ok ? "✓ Added to RishiDM" : "⚠ Connection failed";
            window.setTimeout(() => {
              if (button) button.textContent = "↓ Download with RishiDM";
            }, 3500);
'@
ReplaceOnce $content '            if (!ok) alert("RishiDM desktop connection is unavailable. Start RishiDM and retry.");' @'
            if (!ok) alert("RishiDM could not queue this video. Open the RishiDM main window and check the new video panel. If it is empty, inspect the extension service worker for connection errors.");
'@

$generic=@'
/**
 * Generic PLAYER detection (including cross-origin subframes where extension
 * host permissions allow injection). This overlays actual HTML5 video or a
 * visible embedded player, rather than declaring a download available merely
 * because a page happens to contain a video-related URL.
 *
 * A visible button does not imply extractability. Encrypted and unsupported
 * media are never bypassed. The desktop yt-dlp extractor decides availability.
 */
function setupRishiDMGenericMediaControl() {
    if (/(^|\.)youtube\.com$/i.test(location.hostname)) return;
    let button: HTMLButtonElement | null = null;
    let activeTarget: HTMLElement | null = null;
    const isVisible = (node: HTMLElement): boolean => {
        const rect = node.getBoundingClientRect();
        const style = getComputedStyle(node);
        return rect.width >= 260 && rect.height >= 150 &&
          style.display !== "none" && style.visibility !== "hidden";
    };
    const check = () => {
        const video = [...document.querySelectorAll<HTMLVideoElement>("video")].find(isVisible);
        const frame = !video ?
          [...document.querySelectorAll<HTMLIFrameElement>("iframe")].find(isVisible) : undefined;
        const target: HTMLElement | undefined = video || frame;
        if (!target) {
            button?.remove(); button=null; activeTarget=null; return;
        }
        if (activeTarget === target && button?.isConnected) return;
        button?.remove(); activeTarget=target;
        const wrapper = target.parentElement;
        if (!wrapper) return;
        const style = getComputedStyle(wrapper);
        if (style.position === "static") wrapper.style.position = "relative";
        button=document.createElement("button");
        button.type="button";
        button.textContent="↓ Download with RishiDM";
        button.title="Check whether this embedded player exposes an authorized, unprotected downloadable video";
        button.style.cssText="position:absolute;top:10px;right:10px;z-index:2147483000;" +
          "padding:8px 12px;border:1px solid #a899ff;border-radius:7px;" +
          "font:600 12px Arial,sans-serif;color:#fff;background:#532ad2;" +
          "box-shadow:0 2px 8px #0008;cursor:pointer;";
        const control=button;
        control.addEventListener("click", async event => {
            event.preventDefault(); event.stopPropagation();
            const page = location.href;
            const mediaUrl = video?.currentSrc;
            // Prefer ordinary HTTP(S) media elements when available. Browser
            // blobs, encrypted streams and short-lived opaque player references
            // cannot be treated as downloadable files.
            const selectedUrl = mediaUrl && /^https?:\/\//i.test(mediaUrl) ? mediaUrl : page;
            control.disabled=true; control.textContent="Checking RishiDM…";
            try {
                const ok=await browser.runtime.sendMessage({rishidmVideoAction:"open",url:selectedUrl});
                control.textContent=ok ? "✓ Added to RishiDM" : "⚠ Connection unavailable";
                if (!ok) alert("RishiDM could not add this player. Start the desktop app and check browser extension errors.");
            } catch (e) {
                control.textContent="⚠ Unable to connect";
                alert("RishiDM browser connection failed.");
            } finally {
                window.setTimeout(() => {
                    if (control.isConnected) { control.disabled=false; control.textContent="↓ Download with RishiDM"; }
                },3500);
            }
        });
        wrapper.appendChild(control);
    };
    check();
    window.setInterval(check, 1800);
}
'@
$c=[IO.File]::ReadAllText($content).Replace(([char]13).ToString(),'')
$mark='function setupRishiDMYouTubeOverlay() {'
if(!$c.Contains($mark)){throw 'Missing YouTube content script integration marker'}
$c=$c.Replace($mark,$generic+[char]10+$mark)
$run='    setupRishiDMYouTubeOverlay()'
if(!$c.Contains($run)){throw 'Missing YouTube init marker'}
$c=$c.Replace($run,$run+[char]10+'    setupRishiDMGenericMediaControl()')
[IO.File]::WriteAllText($content,$c,$utf8)
Write-Host "RishiDM v0.5.1: native response truth checking, visible status and generic all-frame HTML5 media overlay patched."
