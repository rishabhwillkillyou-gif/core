# RishiDM v0.5.2 -- site-aware short-video browser controls.
# Run after v051-browser-source.ps1, prior to npm build.
$utf8=New-Object System.Text.UTF8Encoding($false)
$scriptFile=Join-Path $extensionRoot 'src/contentscripts/ContentScript.ts'
$source=[IO.File]::ReadAllText($scriptFile).Replace(([char]13).ToString(),'')
$old='            const selectedUrl = mediaUrl && /^https?:\/\//i.test(mediaUrl) ? mediaUrl : page;'
$new=@'
            // Instagram Reel pages have a first-class yt-dlp extractor. Their CDN
            // currentSrc links are often temporary or require session headers.
            // Prefer the canonical Reel page URL and never read browser cookies.
            const instagramReel =
              /(^|\.)instagram\.com$/i.test(location.hostname) &&
              /^\/reel\/[^/]+\/?$/i.test(location.pathname);
            const selectedUrl = instagramReel
              ? location.origin + location.pathname
              : (mediaUrl && /^https?:\/\//i.test(mediaUrl) ? mediaUrl : page);
'@
if(([regex]::Matches($source,[regex]::Escape($old))).Count -ne 1){throw 'Could not locate generic media URL selection'}
$source=$source.Replace($old,$new.Replace(([char]13).ToString(),''))
$marker='function setupRishiDMYouTubeOverlay() {'
$shorts=@'
/**
 * YouTube Shorts use /shorts/ID and a separate player hierarchy rather than
 * /watch?v=ID and #movie_player. A fixed button avoids dependence on the
 * frequently changing Shorts DOM. Only a direct user click sends the URL.
 */
function setupRishiDMShortsControl() {
    if (!/(^|\.)youtube\.com$/i.test(location.hostname)) return;
    if (window.top !== window) return;
    let control: HTMLButtonElement | null = null;
    const paint = () => {
        const isShorts = /^\/shorts\/[a-zA-Z0-9_-]+\/?$/.test(location.pathname);
        if (!isShorts) {
            control?.remove();
            control = null;
            return;
        }
        if (control?.isConnected) return;
        control = document.createElement("button");
        control.type = "button";
        control.textContent = "↓ Download Short with RishiDM";
        control.title = "Add this YouTube Short to the RishiDM video queue";
        control.style.cssText = "position:fixed;top:108px;right:24px;z-index:2147483000;" +
            "font:600 13px Arial,sans-serif;padding:10px 14px;" +
            "color:white;background:#532ad2;border:1px solid #a899ff;" +
            "border-radius:8px;cursor:pointer;box-shadow:0 2px 8px #0008;";
        const button = control;
        button.addEventListener("click", async event => {
            event.preventDefault();
            event.stopPropagation();
            button.disabled = true;
            button.textContent = "Connecting to RishiDM…";
            try {
                // Re-read the URL at click time because Shorts navigate without
                // a full browser page reload.
                const canonicalUrl = location.origin + location.pathname;
                const accepted = await browser.runtime.sendMessage({
                    rishidmVideoAction: "open",
                    url: canonicalUrl
                });
                button.textContent = accepted ? "✓ Added to RishiDM" : "⚠ Could not queue Short";
                if (!accepted) alert("RishiDM did not accept the Short. Check the desktop app's video queue.");
            } catch (error) {
                button.textContent = "⚠ Connection failed";
                console.error("RishiDM Shorts handoff failed", error);
            } finally {
                window.setTimeout(() => {
                    if (button.isConnected) {
                        button.disabled = false;
                        button.textContent = "↓ Download Short with RishiDM";
                    }
                }, 3200);
            }
        });
        document.body.appendChild(control);
    };
    paint();
    window.addEventListener("yt-navigate-finish", paint);
    window.addEventListener("popstate", paint);
    window.setInterval(paint, 1200);
}

'@
if(([regex]::Matches($source,[regex]::Escape($marker))).Count -ne 1){throw 'Missing YouTube overlay insertion point'}
$source=$source.Replace($marker,$shorts.Replace(([char]13).ToString(),'')+$marker)
$init='    setupRishiDMGenericMediaControl()'
if(([regex]::Matches($source,[regex]::Escape($init))).Count -ne 1){throw 'Missing media initialization marker'}
$source=$source.Replace($init,$init+[char]10+'    setupRishiDMShortsControl()')
[IO.File]::WriteAllText($scriptFile,$source,$utf8)
Write-Host 'Short-form browser support: YouTube Shorts button and canonical Instagram Reel page URL.'
