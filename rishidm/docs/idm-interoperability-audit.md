# RishiDM: independent compatibility analysis of IDM 6.42 build 26

Status: **research only**; no native code copied, no installer executed, no RishiDM code changed.

## Evidence and constraints
- User-provided file: `idman642build26f.exe`, SHA-256 `b962f449d86400fda79113174ced7466b6008c8d01de95ed8e0bd5bc85e39a56`.
- Static PE inspection indicates a Win32 installer, PE build timestamp 2024-12-10.
- Embedded browser-integration JavaScript was partially recoverable by parsing ZIP-style entries within the installer and decompressing deflate streams **without running the executable**.
- The examined minified background script is approximately 58 KB, near-complete; this does not provide the complete native IDM implementation and was not executed. Some embedded archives did not unpack cleanly.
- Browser integration code registers network lifecycle observers including `onBeforeRequest`, `onBeforeSendHeaders`, `onHeadersReceived`, `onResponseStarted`, and `onBeforeRedirect`. Its observed filters include `xmlhttprequest` and other browser resource types; it connects to a native host.
- Static MIME maps include HLS `M3U8`, DASH `MPD`, MPEG-TS `video/mp2t`, and fragmented MP4 `video/mp4`/`M4S`.
- No literal `autoembed` appeared in the recovered browser background script. This does **not** prove that the native program has no provider-specific behavior.
- No evidence yet identifies how IDM assembled the exact user's recent AutoEmbed download. We cannot assume identical implementation from shared syntax or supported format names.

## Comparison with RishiDM v0.9.6
- v0.9.6 counts video responses observed by the browser and safely classifies XHR requests as segment-like/partial/standalone candidates.
- The example observed **19 segment-like responses** and **one unknown-size response**, but no independently downloadable source. HLS playlist independent fetch returned **403**.
- Other player server observed six HLS responses, four processing attempts, and **403/404** outcomes. Different stages have different filters, so counts need not match exactly.
- Important difference to investigate on legitimate test streams: whether independent media discovery can identify a master playlist, relate observed fragments to a source, and hand off a standard, public playlist to the HLS-capable downloader, instead of treating individual fragments as complete files.
- Chrome `webRequest` supplies network request/response **metadata**, not complete response bodies. See https://developer.chrome.com/docs/extensions/reference/api/webRequest . Do not assume the extension possesses media bytes simply because it observed a segment.
- Another potential difference is the behavior of IDM's native integration component, but the recovered extension alone cannot establish its algorithm.

## Clean-room next engineering experiments
1. Use a locally controlled, unprotected synthetic media service with test fixtures for MPEG-TS, fMP4/CMAF, HLS media/master playlists, relative and redirected playlist paths, byte-range fragments, and MIME-only playlist URLs.
2. Build a behavior matrix for RishiDM v0.9.6: browser event type, MIME, metadata, classification, presence of a permitted downloadable URL, HLS parsing and final FFmpeg output.
3. Separate **discovery** from **downloadability**. A segment request count is never proof of a complete file; never fabricate a candidate. Require independently accessible (200) playlist or complete resource.
4. Only fix cases where a reproducible test fails on the baseline. Preserve Dropbox v0.9.5 fallback, branded desktop UI and YouTube/Instagram behavior.
5. Verify in isolated Chromium and with packaged native tools before any prerelease. No site-specific build justified based on the current AutoEmbed 403.

## Constraints
- Do not copy or redistribute IDM proprietary source/binaries, patch activation, or load the untrusted installer.
- Do not bypass DRM, browser authentication, signed-link restrictions or server access controls.
- Do not access or save private movie/stream URLs, credentials, session headers or keys.
- The user reports IDM downloaded an AutoEmbed video recently, but without authorized comparative traces the exact mechanism is **unverified**.

## Decision
The inspection supports further **general segmented-stream interoperability** work, not an immediate assertion of AutoEmbed compatibility. The best next step is a controlled cross-implementation comparison, then a small regression-driven RishiDM patch only if a material reproducible defect is found.
