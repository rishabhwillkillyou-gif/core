# RishiDM 0.9.7: standard HLS fragmented MP4 with extensionless segment URIs.
# Scope: publicly retrievable, unencrypted HLS playlists containing a valid
# EXT-X-MAP pointing to MP4 initialization data. No segment data is captured.
# This does NOT change HTTP 403/404 outcomes or bypass authentication.
$utf8 = New-Object System.Text.UTF8Encoding($false)
$media=Join-Path $extensionRoot 'src/media/MediaOnTab.ts'
Edit093 $media @'
            const filename = getFileFromUrl(playlist.segments[0].uri)
            const extension = filename && getFileExtension(filename)
            if (!["ts", "m4s", "mp4", "aac"].includes(extension ?? "")) {
                countRishiHls(this.tabId, "unsupported-segment-extension");
                return // unrecognized HLS segment type, not a proven video
            }
'@ @'
            const filename = getFileFromUrl(playlist.segments[0].uri)
            let extension = filename && getFileExtension(filename)
            if (!["ts", "m4s", "mp4", "aac"].includes(extension ?? "")) {
                // RFC 8216 permits fMP4 segment URIs without a filename suffix.
                // Only infer fMP4 when EVERY fragment lacks a suffix AND every
                // fragment has an EXT-X-MAP URI naming an MP4 initialization
                // section. No speculative segment downloading is attempted.
                const allFragmentsExtensionless = playlist.segments.every(segment => {
                    const partName = getFileFromUrl(segment.uri);
                    return !!partName && !/\.[a-z0-9]{1,8}$/i.test(partName);
                });
                const allHaveMp4Initialization = playlist.segments.every(segment => {
                    const mapName = segment.map?.uri && getFileFromUrl(segment.map.uri);
                    return !!mapName && ["mp4", "m4s"].includes(getFileExtension(mapName));
                });
                if (allFragmentsExtensionless && allHaveMp4Initialization) {
                    // This extension labels the HLS source in media results.
                    // The native yt-dlp/FFmpeg pipeline handles assembly.
                    extension = "mp4";
                    countRishiHls(this.tabId, "extensionless-fmp4-map-accepted");
                } else {
                    countRishiHls(this.tabId, "unsupported-segment-extension");
                    return
                }
            }
'@
Edit093 (Join-Path $extensionRoot 'src/browseractionpopup/BrowserAction.tsx') 'app: "RishiDM 0.9.6"' 'app: "RishiDM 0.9.7"'
Write-Host 'RishiDM 0.9.7: EXT-X-MAP fMP4 playlists with extensionless segment URIs supported.'
