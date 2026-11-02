# RishiDM independent HLS review — 2 November 2026

## Finding and scope

Two reproducible implementation defects are fixed on `codex/public-hls-request-fix`: replaying conditional request headers without the browser's cached response body, and resolving child playlists against a pre-redirect URL. This is a functional correction, not another diagnostic-only build.

**The exact HTTP status/reason for the two original AutoEmbed requests remains unknown.** The supplied report discards the status number and contains neither request-header names nor correlated response metadata. It cannot distinguish 304 from 401, 403, 404, 429 or a server error. These fixes must not be described as verified support for that site. No requests were made to that site or to the movie mentioned in the handover.

Reviewed baseline: [`fdb5dc1a035aa516144318188ee7992d09b4fe59`](https://github.com/rishabhwillkillyou-gif/core/tree/fdb5dc1a035aa516144318188ee7992d09b4fe59).
Pinned extension tag resolves to `fe1c01928e8702282ef36f2726bc793423f5dc77`; desktop tag resolves to `08bfd440a30d367ae369739d866d30f8c1d4b3af`.
The actual source was reconstructed by running the branding/source edits and the complete ordered v03 → v04 → v051 → v052 → v06 → v08 → v091 → v092 → v093 → v05 patch sequence. Review was not limited to the handover's simplified code.

## Root-cause tree

| Explanation | Evidence | Relationship to original failure |
|---|---|---|
| Conditional header replay produces 304 without a cached body | Reproduced against v0.9.3 with an owned HTTP fixture; public unconditional control succeeds | A concrete, plausible explanation for `manifest-http-non2xx`; original header/status evidence is absent |
| Extension request has different browser context, credentials or referrer | Source constructs a new background `Request`; this does not clone the player's security context | Possible 401/403 or deliberately concealed 404; not established, and not a justification to impersonate the player |
| Expired URL, rate limiting, transient server failure | Compatible with generic non-2xx counter | Unproven; no blind retries or URL/token manipulation added |
| Redirected master resolves relative variant against old URL | Reproduced: `/start.m3u8` redirects to `/cdn/master.m3u8`, old code fetches `/media.m3u8` (404) | Separate downstream bug; does not explain the original trace, which never reached master parsing |
| Parser, encryption or segment filtering | Those code paths require successful manifest fetch | Not the immediate cause in the supplied trace |
| Missing interception | Both requests reached processing | Ruled out for those two requests, not for every possible source on the page |

Playback is not a correlation ID: it does not prove that the two observed playlists are the ones supplying the advancing video, or that they are independently downloadable.

## File/function review

1. **`DownloadLinkInterceptor.redirectDownloadsToExtension`, `checkForHLS`.** `onSendHeaders` retains the final request's headers, including Chrome `extraHeaders`; the HLS listener forwards them with the response URL. It observes metadata, not the response body. `isHLSRequest` does not establish successful status or parseability. See [upstream interceptor](https://github.com/amir1376/ab-download-manager-browser-integration/blob/fe1c01928e8702282ef36f2726bc793423f5dc77/src/linkgrabber/DownloadLinkInterceptor.ts).
2. **`MediaOnTab.processHLS` / `fetchHSLText` — fixed.** v0.9.3 recreates a request with captured headers, then throws away every non-2xx outcome. A copied `If-None-Match` or `If-Modified-Since` asks for revalidation; 304 is meaningful only with an existing representation. RishiDM has no retained playlist body. Copying range headers likewise is not a request for a complete playlist. See [the applied v0.9.3 request patch](https://github.com/rishabhwillkillyou-gif/core/blob/fdb5dc1a035aa516144318188ee7992d09b4fe59/rishidm/v093-hls-failure-diagnostics.ps1#L31) and [status handling](https://github.com/rishabhwillkillyou-gif/core/blob/fdb5dc1a035aa516144318188ee7992d09b4fe59/rishidm/v093-hls-failure-diagnostics.ps1#L155).
3. **`resolveVariantUrl` / variant metadata — fixed.** The fetched final response URL was discarded; relative child URLs used the original `Request.url`. Metadata was also stored under raw relative `variant.uri` while processing used an absolute key. The patch uses the final response URL and absolute keys. See [upstream processor](https://github.com/amir1376/ab-download-manager-browser-integration/blob/fe1c01928e8702282ef36f2726bc793423f5dc77/src/media/MediaOnTab.ts).
4. **Navigation cancellation — partially addressed.** A pending old-page master could create child processing entries after `reset()`, giving those entries the new page index. The added cancellation check stops that after the manifest fetch. This is not a comprehensive rewrite of every async publication race or service-worker persistence behavior.
5. **Failure deduplication — retained, documented limitation.** `isProcessed=true` precedes fetch. A failure suppresses another attempt at the same URL until navigation/reset. This also prevents repeated denials and request loops. No automated retries were added: transient retry handling should classify outcomes and honor `Retry-After`, rather than retry 401/403/404 or silently reset all failures. The popup's Refresh reads a snapshot; it is not a network retry.
6. **Two HLS delivery engines — existing mismatch.** v06 accepts `ts/m4s/mp4/aac` in the extension. The older content-script MediaPopup calls ordinary `addDownloads(type="hls")`, whose pinned native `HLSResponseInfo` rejects non-TS segments. The newer inspector/overlay sends eligible URLs to the yt-dlp-backed video queue. See [v06 format expansion](https://github.com/rishabhwillkillyou-gif/core/blob/fdb5dc1a035aa516144318188ee7992d09b4fe59/rishidm/v06-media-source.ps1#L49), [native TS-only check](https://github.com/amir1376/ab-download-manager/blob/08bfd440a30d367ae369739d866d30f8c1d4b3af/downloader/core/src/commonMain/kotlin/ir/amirab/downloader/downloaditem/hls/HLSResponseInfo.kt#L53), and [video queue subprocess](https://github.com/rishabhwillkillyou-gif/core/blob/fdb5dc1a035aa516144318188ee7992d09b4fe59/rishidm/v05/RishiDMVideoQueue.kt#L154). Expanded detection alone is not universal fMP4 support.
7. **Privacy claims need scope.** Sanitized inspector exports omit URLs/credentials. The inherited interceptor still holds request headers in memory for ordinary downloads, and the existing content-script media message includes `requestHeaders`. The video queue persists job URLs and excerpts of extractor errors; those can contain signed query strings. Thus “no credentials or URLs anywhere” would be inaccurate. This patch stops HLS discovery from replaying/forwarding captured headers; it does not change ordinary authenticated file downloads or silently migrate persisted history.
8. **Resource limits — deferred.** `MAX_HLS_PLAYLIST_SIZE` is not a hard streamed-body cap: an accepted MIME can lead to unbounded `response.text()`. Recursive master traversal and total candidate work also deserve explicit budgets. These are independent hardening tasks, not explanations for the observed non-2xx responses.

## Implemented behavior

[`rishidm/v094-public-hls.ps1`](https://github.com/rishabhwillkillyou-gif/core/blob/codex/public-hls-request-fix/rishidm/v094-public-hls.ps1) is applied after v093 using exact-one-match patch assertions.

- Fetch each HLS manifest with an unconditional anonymous GET (`credentials: "omit"`, `cache: "no-store"`), without copying player headers. This avoids replaying validators/ranges and tests independent accessibility. Servers requiring credentials or a particular player context remain unsupported by this path.
- Preserve the response URL and use it to resolve variants and publish the media playlist URL; preserve quality metadata under the matching absolute key.
- Retain all encryption checks. No keys, login cookies, authorization headers, forged Origin/Referer or extra permissions are added.
- Keep generic non-2xx counts and add a numeric `manifest-http-<status>` reason. No URL, query, response body or header values are added to diagnostics.
- Drop old-navigation work before it can spawn children.
- Keep the UI, native queue, app identity, stable extension ID, installer identifiers, ordinary download handler and site-specific extractors unchanged. Version labels advance to 0.9.4 to distinguish the functional package.

Chrome MV3's `webRequest` listener does not supply a general response-body API. Host-permitted service-worker fetch is a separate request, not a clone of the page context. Injecting player hooks or adding debugger/traffic-manipulation permissions would be a much larger design change and is unnecessary for the public-media correction. See [Chrome network requests](https://developer.chrome.com/docs/extensions/develop/concepts/network-requests), [webRequest](https://developer.chrome.com/docs/extensions/reference/api/webRequest), and [HLS relative-URI rules](https://www.rfc-editor.org/rfc/rfc8216#section-4.1).

## Reproduction and validation

Tests use owned loopback fixtures; no private browsing data or disputed media is needed.

```powershell
# With the v0.9.3 generated extension and its npm ci dependencies:
node rishidm/tests/hls-regression.cjs <generated-extension-root> --baseline
# With the v094 patch applied:
node rishidm/tests/hls-regression.cjs <generated-extension-root>
npm ci --prefix rishidm/tests
node rishidm/tests/node_modules/playwright/cli.js install chromium
node rishidm/tests/browser-regression.cjs <generated-extension-root>/dist/chrome
```

The processor test uses the real generated `MediaOnTab` and the production Vite/Rollup dependency resolution. Only `browser.tabs.get` is stubbed. The baseline reproduces zero candidates for conditional 304 and redirected-master 404 while ordinary public HLS succeeds. The patched suite checks those fixes, metadata, 401/403/404/429/503 rejection without repeated fetch, encryption rejection, anonymous outgoing headers, navigation cancellation, ordinary HTTP-video candidate handling and small-audio filtering.

An additional negative control, `validation/cache-proof.cjs`, warmed the browser cache with detection disabled, enabled detection, and re-fetched normally. **Both v0.9.3 and the fix succeeded**: the page received a usable cached 200 response, and the extension obtained a playlist. Thus ordinary browser-managed revalidation alone is not demonstrated to be broken. The confirmed defect requires validators actually present in the headers RishiDM copies. The real Chromium regression suite intentionally fails on v0.9.3's explicit-validator fixture with `manifest-http-non2xx`, and passes after the fix. This distinction further limits any inference about the original site's unknown status.

The Chromium test loads the actual built MV3 extension in a disposable profile. It exercises `webRequest`, iframe tab attribution, the background registry and the real content-script inspection message. It checks candidates for public/conditional/redirected playlists and rejection for 401/403/404/encryption. The popup page is loaded, but inspection is sent from the content-script world: opening a popup as an ordinary browser tab changes `sender.tab` and is not equivalent to a toolbar popup. Fixtures test manifest detection, not browser video playback.

The Windows workflow compiles both browser targets and the desktop app, extracts the resulting NSIS EXE, checks payload/identity/version, runs the packaged extension tests, then uses the packaged yt-dlp/FFmpeg/Deno to download four seconds of synthetic video/audio HLS generated by FFmpeg. `ffprobe` checks streams/duration and FFmpeg decodes the result. A checksum is generated only after those gates pass.

Standalone `tsc --noEmit` is not clean: both reconstructed v0.9.3 and the patched source have the same 36 diagnostics after normalizing line offsets. These include `webext-bridge`/`type-fest` declarations, the missing `BackendProvider` import, message typing, manifest author typing and an existing nullable segment-extension assignment. Production Vite builds pass, but that is not a claim of a clean TypeScript check. These pre-existing errors were not concealed by changing compiler settings or dependencies.

No claim is made that YouTube/Shorts/Instagram were downloaded in this session, that every Chrome/Brave/Firefox version was exercised, or that the original site's access decision changed. Those implementation paths and desktop/UI persistence sources are unchanged; source preservation is distinct from a live integration regression pass. Installer extraction/media validation is also distinct from an interactive install/upgrade test on the user's existing profile.

## Delivery record

Implementation commit: `5390246b076ad2e27a27647ed012a40906dde4ed`.
Windows validation run: [41388507012](https://github.com/rishabhwillkillyou-gif/core/actions/runs/41388507012).
**Result: all Windows workflow steps passed**, including extracted-payload media download/decode and packaged Chromium tests. Artifact: [RishiDM-0.9.4-validated-public-HLS](https://github.com/rishabhwillkillyou-gif/core/actions/runs/41388507012/artifacts/13116458685), available until 2 December 2026 under the current retention setting. A copy of the EXE and checksums is also delivered locally.

Installer: `RishiDM_Setup_0.9.4_x64.exe` (unsigned experimental Windows x64 preview).
SHA-256, independently checked after downloading the artifact:
`6ec015cb8bcbf1630c2adcc32211d26cee8560e630129ddd499efd4ef2564a81`.

No existing release has been overwritten and the v0.9.3 branch remains available for rollback. No installation or upgrade was performed against the user's personal RishiDM settings/profile.
