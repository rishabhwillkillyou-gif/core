# RishiDM v0.9.3: classify why an intercepted HLS manifest produced no candidate.
# Read-only counters only: no new network requests, manifest persistence,
# URLs, authentication headers, keys, or DRM workaround.
$utf8 = New-Object System.Text.UTF8Encoding($false)
function Edit093([string]$path,[string]$old,[string]$new) {
    $src=[IO.File]::ReadAllText($path).Replace(([char]13).ToString(),'')
    $old=$old.Replace(([char]13).ToString(),'').TrimEnd([char]10)
    $new=$new.Replace(([char]13).ToString(),'').TrimEnd([char]10)
    $count=([regex]::Matches($src,[regex]::Escape($old))).Count
    if ($count -ne 1) {throw "RishiDM v0.9.3 patch mismatch ($count): $path"}
    [IO.File]::WriteAllText($path,$src.Replace($old,$new),$utf8)
}

$media=Join-Path $extensionRoot 'src/media/MediaOnTab.ts'
Edit093 $media 'export class MediaOnTab {' @'
const rishiHlsReasons = new Map<number, Record<string, number>>();
function countRishiHls(tabId: number, code: string) {
    const counts = rishiHlsReasons.get(tabId) || {};
    counts[code] = Math.min(999, (counts[code] || 0) + 1);
    rishiHlsReasons.set(tabId, counts);
}
export function getRishiHlsReasons(tabId: number): Record<string, number> {
    return {...(rishiHlsReasons.get(tabId) || {})};
}
export function clearRishiHlsReasons(tabId: number) {
    rishiHlsReasons.delete(tabId);
}

export class MediaOnTab {
'@

Edit093 $media @'
        mediaToProcess.isProcessed = true // even if it fails!
        const request = new Request(url, {
            headers: requestHeaders
        });
        const content = await fetchHSLText(request)
'@ @'
        mediaToProcess.isProcessed = true // even if it fails!
        countRishiHls(this.tabId, "manifest-processing-started");
        let request: Request;
        try {
            request = new Request(url, {headers: requestHeaders});
        } catch {
            countRishiHls(this.tabId, "request-creation-failed");
            return;
        }
        let content: string | null;
        try {
            content = await fetchHSLText(request, code => countRishiHls(this.tabId, code));
        } catch {
            countRishiHls(this.tabId, "manifest-body-read-failed");
            return;
        }
'@

Edit093 $media @'
        if (playlist == null) {
            return
        }
        if (playlist.isMasterPlaylist) {
'@ @'
        if (playlist == null) {
            countRishiHls(this.tabId, "playlist-parse-failed");
            return
        }
        if (playlist.isMasterPlaylist) {
            countRishiHls(this.tabId, "master-playlist-parsed");
            if (playlist.variants.length === 0)
                countRishiHls(this.tabId, "master-playlist-no-variants");
'@

Edit093 $media @'
            if (playListEncrypted) {
                return
            }
            playlist.variants.forEach(variant => {
'@ @'
            if (playListEncrypted) {
                countRishiHls(this.tabId, "master-playlist-encrypted");
                return
            }
            countRishiHls(this.tabId, "master-variant-lookups-started");
            playlist.variants.forEach(variant => {
'@

Edit093 $media @'
            if (playlist.segments.length == 0) {
                return // empty list?
            }
'@ @'
            countRishiHls(this.tabId, "media-playlist-parsed");
            if (playlist.segments.length == 0) {
                countRishiHls(this.tabId, "media-playlist-empty");
                return // empty list?
            }
'@

Edit093 $media @'
            if (!["ts", "m4s", "mp4", "aac"].includes(extension ?? "")) {
                return // unrecognized HLS segment type, not a proven video
            }
'@ @'
            if (!["ts", "m4s", "mp4", "aac"].includes(extension ?? "")) {
                countRishiHls(this.tabId, "unsupported-segment-extension");
                return // unrecognized HLS segment type, not a proven video
            }
'@

Edit093 $media @'
            mediaToProcess.isEncrypted = mediaToProcess.isEncrypted || HLSUtils.isMediaPlayListEncrypted(playlist)
            // it only needed for media playlist
            applyHeadersToProcessingItem(mediaToProcess, requestHeaders)
            this.onMediaProcessed(mediaToProcess)
'@ @'
            mediaToProcess.isEncrypted = mediaToProcess.isEncrypted || HLSUtils.isMediaPlayListEncrypted(playlist)
            // it only needed for media playlist
            if (mediaToProcess.isEncrypted)
                countRishiHls(this.tabId, "media-playlist-encrypted");
            else
                countRishiHls(this.tabId, "media-playlist-accepted");
            applyHeadersToProcessingItem(mediaToProcess, requestHeaders)
            this.onMediaProcessed(mediaToProcess)
'@

Edit093 $media @'
        const tab = await this.getTab()
        if (!tab) {
            return
        }
        const tabTitle = tab.title
        const tabUrl = tab.url
        if (!tabTitle || !tabUrl) {
            return
'@ @'
        const tab = await this.getTab()
        if (!tab) {
            countRishiHls(this.tabId, "registry-tab-not-available");
            return
        }
        const tabTitle = tab.title
        const tabUrl = tab.url
        if (!tabTitle || !tabUrl) {
            countRishiHls(this.tabId, "registry-page-metadata-missing");
            return
'@

Edit093 $media @'
async function fetchHSLText(
    request: Request
) {
'@ @'
async function fetchHSLText(
    request: Request,
    note: (code: string) => void = () => {}
) {
'@

Edit093 $media @'
    if (!response) {
        return null
    }
    if (!inRange(response.status, 200, 299)) {
        return null;
    }
'@ @'
    if (!response) {
        note("manifest-fetch-failed");
        return null
    }
    if (!inRange(response.status, 200, 299)) {
        note("manifest-http-non2xx");
        return null;
    }
'@

Edit093 $media @'
    if (!contentType) {
        return null
    }
'@ @'
    if (!contentType) {
        note("manifest-missing-content-type");
        return null
    }
'@

Edit093 $media @'
    if (contentTypeMatch || !largeOrUnknownSize) {
        return await response.text();
    }
    return null
'@ @'
    if (contentTypeMatch || !largeOrUnknownSize) {
        return await response.text();
    }
    note("manifest-rejected-content-type-or-size");
    return null
'@

$registry=Join-Path $extensionRoot 'src/media/MediaRegistry.ts'
Edit093 $registry 'import {DownloadableMedia, MediaOnTab} from "~/media/MediaOnTab";' @'
import {DownloadableMedia, MediaOnTab, getRishiHlsReasons, clearRishiHlsReasons} from "~/media/MediaOnTab";
'@
# There are exactly two existing v0.9.2 registry cleanup sites.
$code=[IO.File]::ReadAllText($registry).Replace(([char]13).ToString(),'')
$before='                rishiStageStats.delete(tabId);'
$after=$before + [char]10 + '                clearRishiHlsReasons(tabId);'
if(([regex]::Matches($code,[regex]::Escape($before))).Count -ne 2) {
    throw 'v0.9.3 expected two tab cleanup sites'
}
[IO.File]::WriteAllText($registry,$code.Replace($before,$after),$utf8)
Edit093 $registry 'export function getRishiDMStageCounts(tabId: number): RishiMediaStage {' @'
export {getRishiHlsReasons};
export function getRishiDMStageCounts(tabId: number): RishiMediaStage {
'@

$bg=Join-Path $extensionRoot 'src/background/background.ts'
Edit093 $bg 'import {getRishiDMTabMedia, getRishiDMStageCounts} from "~/media/MediaRegistry";' @'
import {getRishiDMTabMedia, getRishiDMStageCounts, getRishiHlsReasons} from "~/media/MediaRegistry";
'@
Edit093 $bg @'
            stages: getRishiDMStageCounts(tabId)
'@ @'
            stages: getRishiDMStageCounts(tabId),
            hlsReasons: getRishiHlsReasons(tabId)
'@

$popup=Join-Path $extensionRoot 'src/browseractionpopup/BrowserAction.tsx'
Edit093 $popup @'
    stages: Record<string, number>;
};
'@ @'
    stages: Record<string, number>;
    hlsReasons: Record<string, number>;
};
'@
Edit093 $popup @'
                stages: result.stages || {}
'@ @'
                stages: result.stages || {},
                hlsReasons: result.hlsReasons || {}
'@
Edit093 $popup 'app: "RishiDM 0.9.2"' 'app: "RishiDM 0.9.3"'
Edit093 $popup @'
            stages: snapshot?.stages || {},
'@ @'
            stages: snapshot?.stages || {},
            hlsReasons: snapshot?.hlsReasons || {},
'@
Edit093 $popup @'
            <div>Current candidates: {stages.currentCandidateCount || 0}</div>
'@ @'
            <div>Current candidates: {stages.currentCandidateCount || 0}</div>
            <div className="mt-1 font-semibold">Manifest processing results</div>
            {Object.keys(snapshot.hlsReasons).length === 0
                ? <div>No detailed results yet.</div>
                : Object.entries(snapshot.hlsReasons).map(([reason, count]) =>
                    <div key={reason}>{reason}: {count}</div>)}
'@

Write-Host 'RishiDM v0.9.3: read-only HLS fetch/parse/encryption/segment diagnostics added.'
