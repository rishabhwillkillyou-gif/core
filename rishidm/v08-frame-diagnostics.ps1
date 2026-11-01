# RishiDM 0.8: single tab-scoped media snapshot, frame-safe download action,
# plus local privacy-preserving diagnostics for unsupported embedded players.
# Called after v06 media patches, before the extension build.
$utf8=New-Object System.Text.UTF8Encoding($false)
function Replace-Once([string]$file,[string]$before,[string]$after) {
  $code=[IO.File]::ReadAllText($file).Replace(([char]13).ToString(),'')
  $before=$before.Replace(([char]13).ToString(),'').TrimEnd([char]10)
  $after=$after.Replace(([char]13).ToString(),'').TrimEnd([char]10)
  $count=([regex]::Matches($code,[regex]::Escape($before))).Count
  if($count -ne 1){throw "RishiDM v0.8 patch mismatch ($count): $file -> $before"}
  [IO.File]::WriteAllText($file,$code.Replace($before,$after),$utf8)
}

$registry=Join-Path $extensionRoot 'src/media/MediaRegistry.ts'
Replace-Once $registry 'export class MediaRegistry implements OnMediaInterceptedFromRequestListener {' @'
const rishiTabMedia = new Map<number, DownloadableMedia[]>();

/** The entire tab shares one registry, even when its player is in a cross-origin iframe. */
export function getRishiDMTabMedia(tabId: number): DownloadableMedia[] {
    return rishiTabMedia.get(tabId) ?? [];
}

export class MediaRegistry implements OnMediaInterceptedFromRequestListener {
'@
Replace-Once $registry '                page.close()' @'
                rishiTabMedia.delete(tabId);
                page.close()
'@
Replace-Once $registry '                    mediaOnTab.reset()' @'
                    rishiTabMedia.delete(tabId);
                    mediaOnTab.reset()
'@
Replace-Once $registry @'
    await sendMessage(
        DefinedCommands.DOWNLOADABLE_MEDIA_DETECTED,
'@ @'
    rishiTabMedia.set(tabId, downloadableMedia.slice(0, 100));
    await sendMessage(
        DefinedCommands.DOWNLOADABLE_MEDIA_DETECTED,
'@

# The previous generic overlay could only see candidates delivered to its
# own content-script frame. Give it a background query keyed by sender.tab.id.
$bg=Join-Path $extensionRoot 'src/background/background.ts'
Replace-Once $bg 'import {initializeOptions} from "~/contextmenus/ContextMenus";' @'
import {initializeOptions} from "~/contextmenus/ContextMenus";
import {getRishiDMTabMedia} from "~/media/MediaRegistry";
'@
$bgNeedle='    if (!message || message.rishidmVideoAction !== "open") return undefined;'
$bgReplacement=@'
    if (message?.rishidmMediaAction === "inspect") {
        const tabId = sender?.tab?.id;
        if (typeof tabId !== "number") return Promise.resolve({candidates: [], observations: {}});
        const sources = getRishiDMTabMedia(tabId);
        // Only sanitized diagnostics leave the background service. No URLs,
        // query strings, cookies, session tokens, or authentication headers.
        const candidates = sources.slice(0, 30).map((item, index) => ({
            index, type: item.type, extension: item.extension || "",
            resolution: item.resolution || "",
            duration: item.duration || "",
            size: item.size || "",
            host: (() => { try { return new URL(item.uri).hostname; } catch { return "unknown"; } })()
        }));
        return Promise.resolve({candidates, observations: rishidmObservedMedia[tabId] || {}});
    }
    if (message?.rishidmMediaAction === "downloadCandidate") {
        const tabId = sender?.tab?.id;
        const index = message.index;
        if (typeof tabId !== "number" || !Number.isInteger(index)) return Promise.resolve(false);
        const item = getRishiDMTabMedia(tabId)[index];
        if (!item || !/^https?:\/\//i.test(item.uri)) return Promise.resolve(false);
        if (item.type !== "hls" && item.type !== "http") return Promise.resolve(false);
        if (item.type === "http" && !["mp4", "webm", "mkv", "mov", "m4v"].includes((item.extension || "").toLowerCase()))
            return Promise.resolve(false);
        // Never send browser authentication or session headers to the helper.
        const headers = Object.keys(item.requestHeaders || {});
        if (headers.some(name => /^(authorization|cookie|proxy-authorization|x-api-key)$/i.test(name)))
            return Promise.resolve(false);
        return rishidmOpenVideo(item.uri);
    }
    if (!message || message.rishidmVideoAction !== "open") return undefined;
'@
Replace-Once $bg $bgNeedle $bgReplacement
Replace-Once $bg 'browser.runtime.onMessage.addListener((message: any) => {' @'
const rishidmObservedMedia: Record<number, Record<string, number>> = {};
// Detect DASH and HLS response evidence without collecting URLs or headers.
try {
    browser.webRequest.onHeadersReceived.addListener((details: any) => {
        const tabId = details.tabId;
        if (typeof tabId !== "number" || tabId < 0) return;
        const ct = (details.responseHeaders || []).find((h: any) =>
            typeof h.name === "string" && h.name.toLowerCase() === "content-type"
        )?.value?.toLowerCase() || "";
        const path = (() => { try { return new URL(details.url).pathname.toLowerCase(); }
            catch { return ""; } })();
        let kind: string | null = null;
        if (ct.includes("dash+xml") || path.endsWith(".mpd")) kind = "DASH manifest";
        else if (ct.includes("mpegurl") || path.endsWith(".m3u8")) kind = "HLS manifest";
        else if (ct.startsWith("video/") || /\.(mp4|webm|m4v)$/.test(path)) kind = "Video response";
        if (kind) {
            const counters = rishidmObservedMedia[tabId] ||= {};
            counters[kind] = Math.min(999, (counters[kind] || 0) + 1);
        }
    }, {urls: ["<all_urls>"]}, ["responseHeaders"]);
    browser.tabs.onUpdated.addListener((id, change) => {
        if (change.status === "loading" || change.url) delete rishidmObservedMedia[id];
    });
    browser.tabs.onRemoved.addListener(id => { delete rishidmObservedMedia[id]; });
} catch (error) {
    console.warn("RishiDM read-only media diagnostics are unavailable", error);
}

browser.runtime.onMessage.addListener((message: any, sender: any) => {
'@

$content=Join-Path $extensionRoot 'src/contentscripts/ContentScript.ts'
$old=@'
            const candidate = rishidmMediaCandidates.find(item => {
                const extension = (item.extension || "").toLowerCase();
                const isVideo = item.type === "hls" ||
                    ["mp4", "m4v", "webm", "mkv", "mov"].includes(extension);
                const keys = Object.keys(item.requestHeaders || {});
                // Don't silently forward or depend on authenticated cookies.
                const needsCredentials = keys.some(key =>
                    /^(cookie|authorization|proxy-authorization)$/i.test(key));
                return isVideo && !needsCredentials &&
                    /^https?:\/\//i.test(item.uri);
            });
            const selectedUrl = instagramReel
              ? location.origin + location.pathname
              : (candidate?.uri ||
                 (mediaUrl && /^https?:\/\//i.test(mediaUrl) ? mediaUrl : null) ||
                 (video ? page : null));
            if (!selectedUrl) {
                control.textContent = "No supported stream detected";
                window.setTimeout(() => {
                    if (control.isConnected)
                        control.textContent = "↓ Download with RishiDM";
                }, 4000);
                return;
            }
'@
$new=@'
            const snapshot = await browser.runtime.sendMessage({rishidmMediaAction:"inspect"});
            const candidates = Array.isArray(snapshot?.candidates) ? snapshot.candidates : [];
            const supported = candidates.find((item: any) => item.type === "hls" ||
                (item.type === "http" && ["mp4", "webm", "mkv", "mov", "m4v"].includes(
                    (item.extension || "").toLowerCase())));
            // Reels use a first-class site extractor. For generic players,
            // use a candidate held by the shared BACKGROUND tab registry.
            if (!instagramReel && supported) {
                const ok = await browser.runtime.sendMessage({
                    rishidmMediaAction: "downloadCandidate", index: supported.index
                });
                control.textContent = ok ? "✓ Added to RishiDM" : "Media found but not accessible";
                window.setTimeout(() => {
                    if (control.isConnected) { control.disabled = false; control.textContent = "↓ Download with RishiDM"; }
                }, 3500);
                return;
            }
            const selectedUrl = instagramReel
                ? location.origin + location.pathname
                : (mediaUrl && /^https?:\/\//i.test(mediaUrl) ? mediaUrl : (video ? page : null));
            if (!selectedUrl) {
                const observed = snapshot?.observations || {};
                const evidence = Object.entries(observed)
                    .map(([kind, count]) => kind + ": " + count).join(", ");
                const hint = evidence.length
                    ? "Player traffic seen (" + evidence + "), but no supported unprotected source is available."
                    : "No recognizable media responses were captured. This may be a frame, permissions, or protected-media limitation.";
                control.textContent = "No supported stream detected";
                control.title = hint;
                // Click the same button again to view the sanitized diagnostics.
                window.setTimeout(() => {
                    if (control.isConnected) {
                        control.disabled = false;
                        control.textContent = "Inspect media diagnostics";
                    }
                }, 450);
                control.dataset.rishidmDiagnostics = hint;
                return;
            }
'@
Replace-Once $content $old $new
Replace-Once $content '        control.addEventListener("click", async event => {' @'
        control.addEventListener("click", async event => {
            if (control.dataset.rishidmDiagnostics) {
                alert("RishiDM Media Diagnostics\n" + control.dataset.rishidmDiagnostics +
                    "\n\nNo DRM circumvention or automatic login-cookie access.");
                delete control.dataset.rishidmDiagnostics;
                control.textContent = "↓ Download with RishiDM";
                return;
            }
'@
Write-Host 'RishiDM v0.8: tab-wide snapshot + frame-safe candidate actions + local MIME diagnostics connected.'
