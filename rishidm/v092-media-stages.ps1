# RishiDM v0.9.2: read-only media pipeline stage diagnostics.
# Runs AFTER v0.9.1 patches and BEFORE npm build.
# Observes request metadata only; never logs URLs, headers, cookies, tokens or keys.
$utf8 = New-Object System.Text.UTF8Encoding($false)
function Edit092([string]$path,[string]$old,[string]$new) {
  $src=[IO.File]::ReadAllText($path).Replace(([char]13).ToString(),'')
  $old=$old.Replace(([char]13).ToString(),'').TrimEnd([char]10)
  $new=$new.Replace(([char]13).ToString(),'').TrimEnd([char]10)
  $n=([regex]::Matches($src,[regex]::Escape($old))).Count
  if($n -ne 1){throw "RishiDM v0.9.2 patch mismatch ($n) in $path"}
  [IO.File]::WriteAllText($path,$src.Replace($old,$new),$utf8)
}

$registry = Join-Path $extensionRoot 'src/media/MediaRegistry.ts'
Edit092 $registry 'const rishiTabMedia = new Map<number, DownloadableMedia[]>();' @'
const rishiTabMedia = new Map<number, DownloadableMedia[]>();
type RishiMediaStage = {
    interceptedHLS: number; interceptedHTTP: number;
    publishedLists: number; currentCandidateCount: number;
};
const rishiStageStats = new Map<number, RishiMediaStage>();
function rishiStats(tabId: number): RishiMediaStage {
    let s = rishiStageStats.get(tabId);
    if (!s) {
        s = {interceptedHLS: 0, interceptedHTTP: 0,
            publishedLists: 0, currentCandidateCount: 0};
        rishiStageStats.set(tabId, s);
    }
    return s;
}
export function getRishiDMStageCounts(tabId: number): RishiMediaStage {
    const s = rishiStageStats.get(tabId);
    return s ? {...s} : {interceptedHLS: 0, interceptedHTTP: 0,
        publishedLists: 0, currentCandidateCount: 0};
}
'@

$old = '                rishiTabMedia.delete(tabId);'
$new = @'
                rishiTabMedia.delete(tabId);
                rishiStageStats.delete(tabId);
'@
$code = [IO.File]::ReadAllText($registry).Replace(([char]13).ToString(),'')
$n=([regex]::Matches($code,[regex]::Escape($old))).Count
if($n -ne 2){throw "Expected two existing v0.8 tab media cleanup sites; found $n"}
[IO.File]::WriteAllText($registry,$code.Replace($old,$new.TrimEnd([char]10)),$utf8)

Edit092 $registry @'
        await (
            this
                .getOrCreateMediaInPage(tabId)
                .process(mediaResult)
        )
'@ @'
        const stage = rishiStats(tabId);
        if (mediaResult.mediaType === "hls") stage.interceptedHLS++;
        else if (mediaResult.mediaType === "http") stage.interceptedHTTP++;
        await (
            this
                .getOrCreateMediaInPage(tabId)
                .process(mediaResult)
        )
'@

Edit092 $registry '    rishiTabMedia.set(tabId, downloadableMedia.slice(0, 100));' @'
    rishiTabMedia.set(tabId, downloadableMedia.slice(0, 100));
    const stage = rishiStats(tabId);
    stage.publishedLists++;
    stage.currentCandidateCount = downloadableMedia.length;
'@

$bg = Join-Path $extensionRoot 'src/background/background.ts'
Edit092 $bg 'import {getRishiDMTabMedia} from "~/media/MediaRegistry";' @'
import {getRishiDMTabMedia, getRishiDMStageCounts} from "~/media/MediaRegistry";
'@
Edit092 $bg 'return Promise.resolve({candidates, observations: rishidmObservedMedia[tabId] || {}});' @'
return Promise.resolve({
            candidates,
            observations: rishidmObservedMedia[tabId] || {},
            stages: getRishiDMStageCounts(tabId)
        });
'@

# The original observation counter recognizes both MIME and path evidence.
# The upstream actual interceptor only handles a narrower subset of URLs.
# Count those discrepancies without re-fetching any content.
Edit092 $bg @'
        if (kind) {
            const counters = rishidmObservedMedia[tabId] ||= {};
            counters[kind] = Math.min(999, (counters[kind] || 0) + 1);
        }
'@ @'
        if (kind) {
            const counters = rishidmObservedMedia[tabId] ||= {};
            const count = (label: string) => {
                counters[label] = Math.min(999, (counters[label] || 0) + 1);
            };
            count(kind);
            if (kind === "HLS manifest") {
                count(path.endsWith(".m3u8") ?
                    "HLS URL ending .m3u8" :
                    "HLS response with non-m3u8 path");
                count(details.type === "xmlhttprequest" ?
                    "HLS request type: XHR/fetch" :
                    "HLS request type: other");
                if (details.statusCode < 200 || details.statusCode >= 300)
                    count("HLS non-2xx response");
            } else if (kind === "Video response") {
                count(details.type === "media" ?
                    "Video response type: media" :
                    "Video response type: XHR/other");
            }
        }
'@

# Connect new source-backed numeric counters to the popup and copied report.
$popup = Join-Path $extensionRoot 'src/browseractionpopup/BrowserAction.tsx'
Edit092 $popup @'
type RishiDMSnapshot = {
    candidates: RishiDMMediaItem[];
    observations: Record<string, number>;
};
'@ @'
type RishiDMSnapshot = {
    candidates: RishiDMMediaItem[];
    observations: Record<string, number>;
    stages: Record<string, number>;
};
'@
Edit092 $popup @'
                observations: result.observations || {}
'@ @'
                observations: result.observations || {},
                stages: result.stages || {}
'@
Edit092 $popup @'
            counts: snapshot?.observations || {},
'@ @'
            counts: snapshot?.observations || {},
            stages: snapshot?.stages || {},
'@
Edit092 $popup '    const observed = Object.entries(snapshot?.observations || {});' @'
    const observed = Object.entries(snapshot?.observations || {});
    const stages = snapshot?.stages || {};
    const possibleMissedHLS = (snapshot?.observations?.["HLS response with non-m3u8 path"] || 0) > 0;
'@
Edit092 $popup @'
        {snapshot && snapshot.candidates.length > 0 &&
'@ @'
        {snapshot && <div className="rounded bg-base-300 px-2 py-2 text-xs space-y-1">
            <strong>Detection stages</strong>
            <div>HLS requests forwarded: {stages.interceptedHLS || 0}</div>
            <div>HTTP media forwarded: {stages.interceptedHTTP || 0}</div>
            <div>Registry updates: {stages.publishedLists || 0}</div>
            <div>Current candidates: {stages.currentCandidateCount || 0}</div>
            {possibleMissedHLS && <div className="text-amber-300">
                Possible legacy URL-filter gap: an HLS response used a path without .m3u8.
                This alone does not prove it is downloadable.
            </div>}
        </div>}
        {snapshot && snapshot.candidates.length > 0 &&
'@
Write-Host 'RishiDM v0.9.2 pipeline counters connected: observed responses -> intercept -> registry -> candidates.'
