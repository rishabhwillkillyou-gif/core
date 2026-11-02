# v0.9.5 Dropbox file-download safety: no blind capture of temporary CDN URLs.
# Keep Chrome's original transfer intact; user may explicitly queue a canonical
# Dropbox public file share through the RishiDM extension popup.
# Applied after v0.9.4, before extension npm build.
$utf8 = New-Object System.Text.UTF8Encoding($false)
$utilFile=Join-Path $extensionRoot 'src/utils/RishiDropbox.ts'
$util=@'
/**
 * Dropbox shared FILE links can be downloaded by replacing dl=0 with dl=1.
 * Temporary dropboxusercontent CDN URLs must not be replayed as independent
 * downloads: they may be short-lived or require browser request context.
 */
export function isRishiDropboxResourceUrl(raw: string | null | undefined): boolean {
    if (!raw) return false;
    try {
        const parsed = new URL(raw);
        if (parsed.protocol !== "https:" && parsed.protocol !== "http:") return false;
        const h = parsed.hostname.toLowerCase();
        return ["dropbox.com", "dropboxusercontent.com", "dropboxstatic.com"].some(
            domain => h === domain || h.endsWith("." + domain));
    } catch { return false; }
}

export function shouldRishiDropboxUseBrowser(
    ...urls: Array<string | null | undefined>
): boolean {
    return urls.some(isRishiDropboxResourceUrl);
}

export function rishiDropboxDirectShareUrl(raw: string | null | undefined): string | null {
    if (!raw) return null;
    try {
        const url = new URL(raw);
        if (url.protocol !== "https:") return null;
        if (!["dropbox.com", "www.dropbox.com"].includes(url.hostname.toLowerCase())) return null;
        // Shared file links only. Folders and unrelated pages are unsupported.
        const segs = url.pathname.split("/").filter(Boolean);
        const modernFile = segs.length === 4 && segs[0] === "scl" && segs[1] === "fi" &&
            segs[2].length > 0 && segs[3].length > 0;
        const legacyFile = segs.length >= 2 && segs.length <= 3 &&
            segs[0] === "s" && segs[1].length > 0;
        if (!modernFile && !legacyFile) return null;
        url.searchParams.set("dl", "1");
        url.hash = "";
        return url.toString();
    } catch { return null; }
}
'@
if(Test-Path $utilFile){throw 'RishiDropbox helper already exists; refusing to overwrite'}
[IO.File]::WriteAllText($utilFile,$util,$utf8)

$interceptor=Join-Path $extensionRoot 'src/linkgrabber/DownloadLinkInterceptor.ts'
Edit093 $interceptor 'import * as BackgroundSharedState from "~/background/BackgroundSharedState";' @'
import * as BackgroundSharedState from "~/background/BackgroundSharedState";
import {shouldRishiDropboxUseBrowser} from "~/utils/RishiDropbox";
'@
# Guard both interception mechanisms. The browser must keep the original job
# when it originates from Dropbox, even if Chrome has followed redirects.
Edit093 $interceptor @'
                    request.finalResponse = details
                    const result = this.shouldHandleRequestForDirectDownload(details);
'@ @'
                    request.finalResponse = details
                    if (shouldRishiDropboxUseBrowser(
                        details.url, details.originUrl, details.documentUrl,
                        request.initialRequest.url, request.finalRequest.url,
                        this.getDownloadPage(request.finalRequest))) {
                        return this.passResponse()
                    }
                    const result = this.shouldHandleRequestForDirectDownload(details);
'@
Edit093 $interceptor @'
            if (details.byExtensionId) {
'@ @'
            // Dropbox preview/CDN links must finish in Chrome instead of being
            // cancelled before RishiDM has successfully fetched their content.
            if (shouldRishiDropboxUseBrowser(details.url, details.referrer)) return
            if (details.byExtensionId) {
'@
Edit093 $interceptor @'
            const interceptedRequest = this
                .getInterceptedRequestByUrl(details.url)

            if (!interceptedRequest && this.shouldSkipUninterceptedDownloads()) {
'@ @'
            const interceptedRequest = this
                .getInterceptedRequestByUrl(details.url)

            if (interceptedRequest && shouldRishiDropboxUseBrowser(
                interceptedRequest.initialRequest.url,
                interceptedRequest.finalRequest.url,
                this.getDownloadPage(interceptedRequest.finalRequest))) return

            if (!interceptedRequest && this.shouldSkipUninterceptedDownloads()) {
'@

$bg=Join-Path $extensionRoot 'src/background/background.ts'
Edit093 $bg 'import {getRishiDMTabMedia, getRishiDMStageCounts, getRishiHlsReasons} from "~/media/MediaRegistry";' @'
import {getRishiDMTabMedia, getRishiDMStageCounts, getRishiHlsReasons} from "~/media/MediaRegistry";
import {rishiDropboxDirectShareUrl} from "~/utils/RishiDropbox";
import {addDownload as rishiDropboxAddDownload} from "~/background/actions";
'@
Edit093 $bg @'
    if (message?.rishidmMediaAction === "inspect") {
'@ @'
    if (message?.rishidmDropboxAction === "queue-share") {
        // Re-read the real active tab URL, never trust a URL supplied by a webpage.
        // The explicit action is permitted only for original Dropbox file shares.
        const requestedTabId = message.tabId;
        if (!Number.isInteger(requestedTabId)) return Promise.resolve(false);
        return browser.tabs.get(requestedTabId).then(async tab => {
            if (!tab.active) return false;
            const direct = rishiDropboxDirectShareUrl(tab.url);
            if (!direct) return false;
            return !!(await rishiDropboxAddDownload([{
                link: direct,
                downloadPage: tab.url || null,
                headers: {}, description: null, suggestedName: null, type: "http"
            }]));
        }).catch(() => false);
    }
    if (message?.rishidmMediaAction === "inspect") {
'@

$popup=Join-Path $extensionRoot 'src/browseractionpopup/BrowserAction.tsx'
Edit093 $popup 'import {DefinedCommands} from "~/message/Commands";' @'
import {DefinedCommands} from "~/message/Commands";
import {rishiDropboxDirectShareUrl} from "~/utils/RishiDropbox";
'@
Edit093 $popup @'
    const observed = Object.entries(snapshot?.observations || {});
'@ @'
    const dropboxShare = rishiDropboxDirectShareUrl(pageUrl) !== null;
    const queueDropbox = async () => {
        if (busy || tabId === null || !dropboxShare) return;
        setBusy(true);
        try {
            const ok = await browser.runtime.sendMessage({
                rishidmDropboxAction: "queue-share", tabId
            });
            setMessage(ok
                ? "Dropbox share queued in RishiDM. Chrome still handles ordinary Dropbox downloads."
                : "RishiDM could not queue this share. Chrome download remains available.");
        } catch {
            setMessage("RishiDM is unavailable. Use the regular Dropbox Download button.");
        } finally {
            setBusy(false);
        }
    };
    const observed = Object.entries(snapshot?.observations || {});
'@
Edit093 $popup @'
        <div className="flex justify-between items-center gap-2">
            <strong className="text-violet-300">Media Detector</strong>
'@ @'
        {dropboxShare && <div className="rounded border border-violet-500/40 bg-base-300 p-2 space-y-2">
            <strong className="text-violet-300">Dropbox file</strong>
            <div className="text-xs opacity-75">
                Chrome keeps the default Dropbox download. Or queue this shared file in RishiDM.
            </div>
            <button className="btn btn-primary w-full" disabled={busy}
                onClick={() => void queueDropbox()}>
                Download Dropbox file with RishiDM
            </button>
        </div>}
        <div className="flex justify-between items-center gap-2">
            <strong className="text-violet-300">Media Detector</strong>
'@
Edit093 $popup 'app: "RishiDM 0.9.4"' 'app: "RishiDM 0.9.5"'
Write-Host 'RishiDM v0.9.5: Dropbox share one-click queue; native Chrome fallback for CDN redirects.'
