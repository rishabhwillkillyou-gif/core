# RishiDM v0.9.1 -- user-initiated, sanitized media inspector.
# Applied after v0.8 diagnostics, before the extension npm build.
# No signed URLs, authentication data or player keys are collected or copied.
$utf8 = New-Object System.Text.UTF8Encoding($false)
function Patch091([string]$file, [string]$old, [string]$new) {
    $data = [IO.File]::ReadAllText($file).Replace(([char]13).ToString(), '')
    $old = $old.Replace(([char]13).ToString(), '').TrimEnd([char]10)
    $new = $new.Replace(([char]13).ToString(), '').TrimEnd([char]10)
    $matches = ([regex]::Matches($data, [regex]::Escape($old))).Count
    if ($matches -ne 1) { throw "v0.9.1 patch mismatch ($matches) in $file" }
    [IO.File]::WriteAllText($file, $data.Replace($old, $new), $utf8)
}

$bg = Join-Path $extensionRoot 'src/background/background.ts'
# Popup has no sender.tab. For popup-originated inspect/download requests we
# explicitly supply the active tab ID; normal content scripts retain sender.tab.
$tabOld = '        const tabId = sender?.tab?.id;'
$tabNew = '        const tabId = sender?.tab?.id ?? (Number.isInteger(message.tabId) ? message.tabId : undefined);'
$bgText = [IO.File]::ReadAllText($bg).Replace(([char]13).ToString(), '')
if (([regex]::Matches($bgText, [regex]::Escape($tabOld))).Count -ne 2) {
    throw 'v0.9.1 expected two tab-scoped background message handlers'
}
[IO.File]::WriteAllText($bg, $bgText.Replace($tabOld, $tabNew), $utf8)

Patch091 $bg @'
        const candidates = sources.slice(0, 30).map((item, index) => ({
            index, type: item.type, extension: item.extension || "",
            resolution: item.resolution || "",
            duration: item.duration || "",
            size: item.size || "",
            host: (() => { try { return new URL(item.uri).hostname; } catch { return "unknown"; } })()
        }));
        return Promise.resolve({candidates, observations: rishidmObservedMedia[tabId] || {}});
'@ @'
        const candidates = sources.slice(0, 30).map((item, index) => {
            const ext = (item.extension || "").toLowerCase();
            const eligibleType = item.type === "hls" ||
                (item.type === "http" && ["mp4", "webm", "mkv", "mov", "m4v"].includes(ext));
            const authenticated = Object.keys(item.requestHeaders || {}).some(
                key => /^(cookie|authorization|proxy-authorization|x-api-key)$/i.test(key)
            );
            const validUrl = /^https?:\/\//i.test(item.uri);
            return {
                index, type: item.type, extension: ext,
                resolution: item.resolution || "", duration: item.duration || "",
                size: item.size || "",
                host: (() => { try { return new URL(item.uri).hostname; }
                    catch { return "unknown"; } })(),
                downloadable: eligibleType && validUrl && !authenticated,
                reason: !validUrl ? "no-http-url" :
                    authenticated ? "requires-authorization" :
                    !eligibleType ? "unsupported-format" : "eligible"
            };
        });
        return Promise.resolve({candidates, observations: rishidmObservedMedia[tabId] || {}});
'@

# Explicit page-URL actions are limited to sites supported by the existing
# extractor. Other pages must produce a supported tab-registry media candidate.
# This prevents generic 404 jobs from player shells / watch pages.
Patch091 $bg @'
    if (!message || message.rishidmVideoAction !== "open") return undefined;
    return rishidmOpenVideo(message.url);
'@ @'
    if (!message || message.rishidmVideoAction !== "open") return undefined;
    if (typeof message.url !== "string") return Promise.resolve(false);
    try {
        const parsed = new URL(message.url);
        const host = parsed.hostname.toLowerCase();
        const supportedSite = /(^|\.)(youtube\.com|youtu\.be|instagram\.com|vimeo\.com|tiktok\.com|dailymotion\.com)$/.test(host);
        const directVideo = /\.(mp4|webm|mkv|mov|m4v|m3u8)$/i.test(parsed.pathname);
        if (parsed.protocol !== "https:" && parsed.protocol !== "http:")
            return Promise.resolve(false);
        if (!supportedSite && !directVideo) return Promise.resolve(false);
    } catch { return Promise.resolve(false); }
    return rishidmOpenVideo(message.url);
'@

$popupFile = Join-Path $extensionRoot 'src/browseractionpopup/BrowserAction.tsx'
$popup = [IO.File]::ReadAllText($popupFile).Replace(([char]13).ToString(), '')
$buttonStart = '            <div className="px-4 py-3">'
$buttonEnd = '            <AutoCaptureSection enabled={vm.autoCaptureLinks}'
$start = $popup.IndexOf($buttonStart, [StringComparison]::Ordinal)
$end = $popup.IndexOf($buttonEnd, [StringComparison]::Ordinal)
if ($start -lt 0 -or $end -le $start -or $popup.IndexOf($buttonStart,$start+1,[StringComparison]::Ordinal) -ge 0) {
    throw 'v0.9.1 cannot locate the unique legacy popup download button'
}
$popup = $popup.Substring(0,$start) + '            <RishiDMMediaInspector/>' + [char]10 + $popup.Substring($end)

$component = @'
type RishiDMMediaItem = {
    index: number; type: string; extension?: string; resolution?: string;
    size?: string; host: string; downloadable: boolean; reason: string;
};
type RishiDMSnapshot = {
    candidates: RishiDMMediaItem[];
    observations: Record<string, number>;
};

/** Popup shows ONLY sanitized media metadata; media URIs stay in the background. */
function RishiDMMediaInspector() {
    const [snapshot, setSnapshot] = React.useState<RishiDMSnapshot | null>(null);
    const [tabId, setTabId] = React.useState<number | null>(null);
    const [pageUrl, setPageUrl] = React.useState("");
    const [busy, setBusy] = React.useState(false);
    const [message, setMessage] = React.useState("");

    const refresh = async () => {
        setMessage("");
        setBusy(true);
        try {
            const [tab] = await browser.tabs.query({active: true, currentWindow: true});
            if (typeof tab?.id !== "number") throw new Error("No active browser tab");
            setTabId(tab.id);
            setPageUrl(tab.url || "");
            const result: any = await browser.runtime.sendMessage({
                rishidmMediaAction: "inspect", tabId: tab.id
            });
            if (!result || !Array.isArray(result.candidates))
                throw new Error("Media diagnostics unavailable");
            setSnapshot({
                candidates: result.candidates,
                observations: result.observations || {}
            });
        } catch (error) {
            setSnapshot(null);
            setMessage("Cannot inspect this tab. Try refreshing the page.");
        } finally {
            setBusy(false);
        }
    };

    React.useEffect(() => { void refresh(); }, []);

    const candidate = snapshot?.candidates.find(c => c.downloadable);
    const supportedSite = (() => {
        try {
            const host = new URL(pageUrl).hostname.toLowerCase();
            return /(^|\.)(youtube\.com|youtu\.be|instagram\.com|vimeo\.com|tiktok\.com|dailymotion\.com)$/.test(host);
        } catch { return false; }
    })();
    const observed = Object.entries(snapshot?.observations || {});
    const download = async () => {
        if (busy || tabId === null) return;
        setBusy(true);
        try {
            let ok = false;
            if (candidate) {
                ok = !!(await browser.runtime.sendMessage({
                    rishidmMediaAction: "downloadCandidate",
                    tabId, index: candidate.index
                }));
            } else if (supportedSite) {
                ok = !!(await browser.runtime.sendMessage({
                    rishidmVideoAction: "open", url: pageUrl
                }));
            }
            setMessage(ok ? "Added to RishiDM." :
                "No accessible supported source was queued.");
        } catch {
            setMessage("RishiDM could not queue this media.");
        } finally {
            setBusy(false);
        }
    };
    const copyDiagnostics = async () => {
        const report = JSON.stringify({
            app: "RishiDM 0.9.1",
            counts: snapshot?.observations || {},
            candidates: (snapshot?.candidates || []).map(
                ({type, extension, resolution, host, downloadable, reason}) =>
                    ({type, extension, resolution, host, downloadable, reason})
            ),
            note: "Sanitized: no URLs, cookies, authentication, or signed tokens."
        }, null, 2);
        try {
            await navigator.clipboard.writeText(report);
            setMessage("Sanitized diagnostics copied.");
        } catch {
            window.prompt("Copy sanitized diagnostics", report);
        }
    };

    return <div className="w-80 px-4 py-3 space-y-2 border-b border-base-content/10 text-sm">
        <div className="flex justify-between items-center gap-2">
            <strong className="text-violet-300">Media Detector</strong>
            <button className="btn btn-xs" disabled={busy} onClick={() => void refresh()}>
                Refresh
            </button>
        </div>
        <div className="text-xs opacity-80">
            {busy && !snapshot ? "Inspecting tab..." :
                candidate ? "Supported media candidate detected" :
                supportedSite ? "Supported site: extractor can check this page" :
                observed.length ? "Media traffic observed, but no supported unprotected source identified" :
                "No supported media detected in this tab"}
        </div>
        <div className="text-xs opacity-75">
            {observed.length ? observed.map(([kind, count]) =>
                <div key={kind}>{kind}: {count}</div>
            ) : <div>No recognized media responses yet.</div>}
        </div>
        {snapshot && snapshot.candidates.length > 0 &&
            <div className="max-h-36 overflow-y-auto space-y-1">
                {snapshot.candidates.map(c =>
                    <div key={c.index} className="rounded bg-base-300 px-2 py-1 text-xs">
                        <div className="font-semibold break-all">
                            {c.type.toUpperCase()} {c.extension ? "(" + c.extension + ")" : ""}
                            {" · "}{c.downloadable ? "Eligible" : c.reason}
                        </div>
                        <div className="opacity-75 break-all">
                            {c.host}{c.resolution ? " · " + c.resolution : ""}
                        </div>
                    </div>
                )}
            </div>}
        <button className="btn btn-primary w-full"
            disabled={busy || (!candidate && !supportedSite)}
            onClick={() => void download()}>
            {candidate ? "Download detected media" :
                supportedSite ? "Check supported site download" : "No supported download"}
        </button>
        <button className="btn btn-xs w-full" onClick={() => void copyDiagnostics()}>
            Copy sanitized diagnostics
        </button>
        {message && <div className="text-xs break-words">{message}</div>}
        <div className="text-xs opacity-60">
            Network traffic alone does not prove a downloadable stream. No DRM bypass.
        </div>
    </div>;
}

'@
$insert = 'const BrowserActionUi: React.FC<{'
if (([regex]::Matches($popup, [regex]::Escape($insert))).Count -ne 1) {
    throw 'v0.9.1 cannot locate popup component injection point'
}
$popup = $popup.Replace($insert, $component + [char]10 + $insert)
[IO.File]::WriteAllText($popupFile, $popup, $utf8)
Write-Host 'RishiDM v0.9.1: user-initiated media list, sanitized diagnostics and guarded webpage downloads installed.'
