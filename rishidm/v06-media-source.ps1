# RishiDM v0.6 — reuse AB's upstream per-tab HTTP/HLS media registry.
# Applies after v0.5.2 source patches and before the Chrome/Firefox builds.
$encoding=New-Object System.Text.UTF8Encoding($false)
function Patch-Single([string]$path,[string]$find,[string]$replace){
 $srcText=[IO.File]::ReadAllText($path).Replace(([char]13).ToString(),'')
 $count=([regex]::Matches($srcText,[regex]::Escape($find))).Count
 if($count -ne 1){throw "RishiDM v0.6 patch mismatch ($count matches): $path -- $find"}
 [IO.File]::WriteAllText($path,$srcText.Replace($find,$replace),$encoding)
}

# First fix the ACTUAL source of 'Download With ABDM': the i18n string
# download_media_title. Prior branding patches missed the short 'ABDM' spelling.
$locales=Join-Path $extensionRoot 'public/_locales'
$corrected=0
foreach($languageFile in Get-ChildItem -LiteralPath $locales -Recurse -File -Filter 'messages.json'){
 $original=[IO.File]::ReadAllText($languageFile.FullName)
 $patched=[regex]::Replace($original,'(?i)\bABDM\b','RishiDM')
 $patched=[regex]::Replace($patched,'(?i)\bAB DM\b','RishiDM')
 if($patched -ne $original){
   [IO.File]::WriteAllText($languageFile.FullName,$patched,$encoding)
   $corrected++
 }
}
$english=Get-Content -LiteralPath (Join-Path $locales 'en/messages.json') -Raw | ConvertFrom-Json
if($english.download_media_title.message -notmatch '(?i)RishiDM' -or
   $english.download_media_title.message -match '(?i)ABDM|AB DM'){
 throw 'RishiDM media popup title is not correctly branded'
}
Write-Host "RishiDM v0.6: corrected ABDM i18n leak in $corrected locale files."

# Reuse media registry, but prevent tiny app/UI notification tones from
# appearing as video downloads. Real audio files remain supported.
$mediaFile=Join-Path $extensionRoot 'src/media/MediaOnTab.ts'
Patch-Single $mediaFile @'
        mediaToProcess.isProcessed = true;
        mediaToProcess.type = "http"
'@ @'
        mediaToProcess.isProcessed = true;
        // Don't promote short browser notification sounds and UI bleeps
        // into media-download suggestions. Avoid filtering normal audio.
        const mimeType = getContentType(responseHeaders)?.toLowerCase() ?? "";
        const byteLength = getContentLength(responseHeaders);
        if (mimeType.startsWith("audio/") && byteLength !== null &&
            byteLength < 256 * 1024) {
            return;
        }
        mediaToProcess.type = "http"
'@
# Upstream previously refused HLS with fMP4/CMAF segments.
# Accept common unencrypted HLS segment containers; existing encryption
# checks remain untouched (no DRM/key extraction).
Patch-Single $mediaFile @'
            if (extension !== "ts") {
                return // we only support ts files for now
            }
'@ @'
            if (!["ts", "m4s", "mp4", "aac"].includes(extension ?? "")) {
                return // unrecognized HLS segment type, not a proven video
            }
'@

# The existing registry already broadcasts media records to the content
# script. Use those records when the user explicitly clicks an overlay.
# Never read or transmit browser cookies, Authorization, or private headers.
$content=Join-Path $extensionRoot 'src/contentscripts/ContentScript.ts'
Patch-Single $content @'
function setupRishiDMGenericMediaControl() {
'@ @'
type RishiMediaCandidate = {
    uri: string;
    type: string;
    extension?: string;
    requestHeaders?: Record<string,string>;
};
let rishidmMediaCandidates: RishiMediaCandidate[] = [];

function setupRishiDMGenericMediaControl() {
'@
Patch-Single $content @'
    onMessage(DefinedCommands.DOWNLOADABLE_MEDIA_DETECTED, (msg) => {
        MediaPopup.updatePopup(msg.data)
    })
'@ @'
    onMessage(DefinedCommands.DOWNLOADABLE_MEDIA_DETECTED, (msg) => {
        // AB's existing registry already deduplicates and rejects encrypted
        // HLS. Store only the minimal, non-credentialed fields needed to
        // choose a supported media URL after the USER clicks a button.
        rishidmMediaCandidates = Array.isArray(msg.data) ?
            msg.data.filter((item: any) =>
                typeof item?.uri === "string" && /^https?:\/\//i.test(item.uri) &&
                (item.type === "hls" || item.type === "http")
            ).map((item: any) => ({
                uri: item.uri, type: item.type,
                extension: item.extension,
                requestHeaders: item.requestHeaders
            })).slice(0, 80) : [];
        MediaPopup.updatePopup(msg.data)
    })
'@

# Site-aware candidate selection: the player page is a fallback only when
# the site has an actual HTML video element. An iframe with no detected media
# should NOT send an unrelated, often 404, player webpage to yt-dlp.
$old=@'
            const selectedUrl = instagramReel
              ? location.origin + location.pathname
              : (mediaUrl && /^https?:\/\//i.test(mediaUrl) ? mediaUrl : page);
'@
$new=@'
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
Patch-Single $content $old $new

# Popup uses the upstream registry's per-tab results and encrypted HLS
# checks; its title is now branded, and tiny audio candidates are filtered
# at the source rather than hiding all legitimate audio.
Write-Host 'RishiDM v0.6: browser media registry linked to user-triggered floating control.'
