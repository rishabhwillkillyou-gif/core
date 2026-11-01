# RishiDM — Visual Identity & Media Diagnostics Roadmap

## Final product name
**RishiDM** (consistent spelling, no space). Name of the app, Windows installer,
browser extension, native messaging host, and visual branding.

## Visual identity (prototype on branch `rishidm-v07-polish-diagnostics`)
- Original bold R + downward arrow mark, designed for Windows 16–256 px.
- Dark navy background, ice-white R, blue-to-violet download arrow.
- Editable source: `rishidm/branding/rishidm-logo.svg`.
- Reproducible app/installer/extension icons: `generate_brand_assets.py`.
- Matching Compose vector icon: `RishiDMAppIcon.kt`.
- Preserve OS icon identity; don't change extension ID/native-host identity.
- Add small-size readability checks at 16, 24, 32, 48 and 128 pixels.
- Treat brand artwork as a **proposal until approved**; don't release publicly by default.

## Media Diagnostics — next separate engineering milestone

### Architecture
1. Browser background service maintains one **tab-scoped media registry** with
   optional `frameId`, `parentFrameId`, `documentId` and request initiator.
   Content scripts query this common registry. Do not keep independent media
   source arrays within isolated iframes.
2. Parse permitted response metadata for:
   direct MP4/WebM, unencrypted HLS (m3u8), and MPEG-DASH (mpd).
   Keep parsers in the extension; native app uses a structured candidate record.
3. Maintain a short TTL and clear stale candidates when a tab navigates or
   switches servers. Distinguish an actual media request from page/logo/UI audio.
4. Rank candidates by video evidence, media duration, MIME type, real player
   attachment and frame ancestry—not merely URL extensions. Avoid mislabeling
   a video as downloadable based on an unrelated resource.
5. Show **Detecting / Supported / Protected / Inaccessible / Unknown** states
   with technical reason codes. The download action stays disabled for
   unsupported and protected media.

### Diagnostics
- User-initiated diagnostics panel shows frame count, media candidates and
  anonymized host + MIME/manifest type; never record full signed media URLs,
  cookies, auth headers, private tokens or browsing history.
- Provide local `Copy sanitized diagnostics`, no auto-uploads.
- For unsupported site: display `No supported unprotected source found`
  rather than submitting generic player URL to yt-dlp.
- No DRM circumvention, license server emulation, key extraction or cookie
  harvesting; do not claim universal download support.

### Acceptance checks before a release
- Windows icon is visible in title bar, taskbar, Start menu, installer, and
  Add/Remove Programs. Extension icon is consistent in Chrome and Brave.
- Existing HTML, file, YouTube, Shorts, Instagram Reels and 4K tasks remain
  functional after in-place upgrade; queue/history preserved.
- Known open-source, unencrypted HLS iframe produces a candidate shared with
  the top-level page (no cross-frame disconnect).
- Known open-source DASH demo is recognized as DASH.
- Notification sounds on WhatsApp Web are not promoted as video downloads.
- Protected or inaccessible streams show a diagnosis, never false success.
- AutoEmbed test is *diagnostic only* until we have a confirmed unprotected,
  authorized media source; no claim that every player is downloadable.

### Staged implementation
- **v0.7:** visual identity + UI clarity + opt-in diagnostics structure.
- **v0.8:** tab-wide registry, frame-aware media records and DASH support.
- **v0.9:** integrated media candidate/format chooser and unified task list
  once in-the-wild browser tests pass.

## Project safeguards
Keep Apache-2.0 notices and attributions for the AB base. Maintain the
independent preview branch, don't overwrite the last confirmed working build,
and package only signed-off sources without browser-policy force installs.
