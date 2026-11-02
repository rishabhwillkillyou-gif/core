# RishiDM v0.9.6: independently designed, evidence-driven XHR media classification.
# Does not interfere with existing "media" / .m3u8 handlers or Dropbox fallback.
# No protected sessions, private request replay, keys, or DRM handling.
$utf8 = New-Object System.Text.UTF8Encoding($false)
$helperPath=Join-Path $extensionRoot 'src/media/RishiResponseInsight.ts'
if(Test-Path $helperPath){throw 'v0.9.6 helper already exists'}
$helper=@'
/** RishiDM: classify browser response metadata without fetching or exporting URLs. */
type Header = {name: string; value?: string};
type ResponseFacts = {
    url: string; type?: string; statusCode: number; method?: string;
    responseHeaders?: Header[];
};
type RequestFacts = { requestHeaders?: Header[] };
export type RishiResponseKind =
    "xhr-standalone-video" | "xhr-segment" | "xhr-partial" |
    "xhr-private" | "xhr-unknown-size" | "hls-nonstandard-path" |
    "dash-observed" | "none";
const mimeHls = new Set([
    "application/vnd.apple.mpegurl", "application/x-mpegurl",
    "audio/mpegurl", "audio/x-mpegurl"
]);
const standAloneMimes = new Set([
    "video/mp4", "video/webm", "video/quicktime",
    "video/x-matroska", "video/x-msvideo"
]);
const segmentMimes = new Set([
    "video/mp2t", "video/iso.segment", "application/mp4"
]);
function header(list: Header[] | undefined, key: string): string {
    return list?.find(h => h.name.toLowerCase() === key)?.value || "";
}
function suffixPath(raw: string): string {
    try {return new URL(raw).pathname.toLowerCase();} catch {return "";}
}
export function classifyRishiResponse(
    response: ResponseFacts, request?: RequestFacts
): RishiResponseKind {
    if (!["xmlhttprequest", "other"].includes(response.type || "") ||
        response.method !== "GET") return "none";
    const path=suffixPath(response.url);
    const mime=header(response.responseHeaders,"content-type").toLowerCase().split(";")[0].trim();
    const hlsPath=path.endsWith(".m3u8");
    // Existing legacy listener handles .m3u8. Here we only fix MIME-only HLS.
    if (response.statusCode >= 200 && response.statusCode < 300 &&
        !hlsPath && mimeHls.has(mime)) return "hls-nonstandard-path";
    if (mime === "application/dash+xml" || path.endsWith(".mpd"))
        return "dash-observed"; // detection only; never offer as a download.
    const segmentPath=/\.(?:ts|m4s|cmfv|cmfa|m4a|aac)$/.test(path);
    const isVideo = standAloneMimes.has(mime) ||
        /\.(?:mp4|webm|m4v|mov|mkv|avi)$/.test(path) ||
        segmentMimes.has(mime) || segmentPath;
    if (!isVideo) return "none";
    if (segmentPath || segmentMimes.has(mime)) return "xhr-segment";
    if (response.statusCode === 206 ||
        !!header(response.responseHeaders,"content-range")) return "xhr-partial";
    if (response.statusCode !== 200) return "none";
    const headers=request?.requestHeaders || [];
    // The independent helper must not attempt replay of browser authentication.
    if (headers.some(h => /^(?:cookie|authorization|proxy-authorization|x-api-key)$/i.test(h.name)))
        return "xhr-private";
    const size=Number(header(response.responseHeaders,"content-length"));
    // A single standalone video is not inferred from a small/unknown chunk.
    if (!Number.isFinite(size) || size < 512*1024)
        return "xhr-unknown-size";
    if (!standAloneMimes.has(mime)) return "none";
    return "xhr-standalone-video";
}
const tabs=new Map<number,Record<string,number>>();
export function recordRishiResponseKind(tabId:number,kind:RishiResponseKind):void {
    if(!Number.isInteger(tabId) || tabId<0 || kind === "none") return;
    const items=tabs.get(tabId)||{};
    items[kind]=Math.min(999,(items[kind]||0)+1);
    tabs.set(tabId,items);
}
export function getRishiResponseInsights(tabId:number):Record<string,number> {
    return {...(tabs.get(tabId)||{})};
}
export function clearRishiResponseInsights(tabId:number):void {tabs.delete(tabId);}
'@
[IO.File]::WriteAllText($helperPath,$helper,$utf8)

$int=Join-Path $extensionRoot 'src/linkgrabber/DownloadLinkInterceptor.ts'
Edit093 $int 'import {run} from "~/utils/ScopeFunctions";' @'
import {run} from "~/utils/ScopeFunctions";
import {classifyRishiResponse, recordRishiResponseKind} from "~/media/RishiResponseInsight";
'@
Edit093 $int @'
        browser.webRequest.onCompleted.addListener(
'@ @'
        // Additional, non-blocking observation for XHR/fetch streams. The
        // upstream media listener sees only browser "media" requests, and its
        // HLS listener only matches URLs ending in .m3u8. Keep both unchanged.
        browser.webRequest.onResponseStarted.addListener(
            (details) => {
                const prior = this.pendingRequests[details.requestId];
                const request = prior?.finalRequest;
                const kind = classifyRishiResponse(details, request);
                recordRishiResponseKind(details.tabId, kind);
                if (!request || !this.shouldProcessMedia(details)) return;
                if (kind === "hls-nonstandard-path") {
                    this.checkForHLS(details, request);
                } else if (kind === "xhr-standalone-video") {
                    // Explicitly require full 200, video MIME, known size and
                    // no session credentials before a direct download candidate.
                    const item = this.isDirectMedia(
                        details.url, getHeaders(request.requestHeaders),
                        getHeaders(details.responseHeaders));
                    if (item) this.onMediaDetected(details.tabId, item);
                }
                // DASH, fragments, range responses, unknown-sized objects
                // and access-dependent requests remain observations only.
            },
            {types: ["xmlhttprequest", "other"], urls: ["*://*/*"]},
            ["responseHeaders"]
        );
        browser.webRequest.onCompleted.addListener(
'@

$bg=Join-Path $extensionRoot 'src/background/background.ts'
Edit093 $bg 'import {rishiDropboxDirectShareUrl} from "~/utils/RishiDropbox";' @'
import {rishiDropboxDirectShareUrl} from "~/utils/RishiDropbox";
import {getRishiResponseInsights,clearRishiResponseInsights} from "~/media/RishiResponseInsight";
'@
Edit093 $bg @'
            hlsReasons: getRishiHlsReasons(tabId)
'@ @'
            hlsReasons: getRishiHlsReasons(tabId),
            responseAnalysis: getRishiResponseInsights(tabId)
'@
Edit093 $bg @'
        if (change.status === "loading" || change.url) delete rishidmObservedMedia[id];
'@ @'
        if (change.status === "loading" || change.url) {
            delete rishidmObservedMedia[id];
            clearRishiResponseInsights(id);
        }
'@
Edit093 $bg @'
    browser.tabs.onRemoved.addListener(id => { delete rishidmObservedMedia[id]; });
'@ @'
    browser.tabs.onRemoved.addListener(id => {
        delete rishidmObservedMedia[id];
        clearRishiResponseInsights(id);
    });
'@

$popup=Join-Path $extensionRoot 'src/browseractionpopup/BrowserAction.tsx'
Edit093 $popup @'
    hlsReasons: Record<string, number>;
};
'@ @'
    hlsReasons: Record<string, number>;
    responseAnalysis: Record<string, number>;
};
'@
Edit093 $popup @'
                hlsReasons: result.hlsReasons || {}
'@ @'
                hlsReasons: result.hlsReasons || {},
                responseAnalysis: result.responseAnalysis || {}
'@
Edit093 $popup 'app: "RishiDM 0.9.5"' 'app: "RishiDM 0.9.6"'
Edit093 $popup @'
            hlsReasons: snapshot?.hlsReasons || {},
'@ @'
            hlsReasons: snapshot?.hlsReasons || {},
            responseAnalysis: snapshot?.responseAnalysis || {},
'@
Edit093 $popup @'
            <div className="mt-1 font-semibold">Manifest processing results</div>
'@ @'
            <div className="mt-1 font-semibold">XHR/fetch media analysis</div>
            {Object.keys(snapshot.responseAnalysis || {}).length === 0
                ? <div>No additional XHR media evidence yet.</div>
                : Object.entries(snapshot.responseAnalysis).map(([kind,count]) =>
                    <div key={kind}>{kind}: {count}</div>)}
            <div className="mt-1 font-semibold">Manifest processing results</div>
'@
Write-Host 'RishiDM 0.9.6: XHR direct-file detection, MIME-only HLS, fragment/range classification and sanitized insights.'
