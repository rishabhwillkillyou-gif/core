# Focused correction for independently accessible, unprotected HLS.
# Apply after v093; never replay the player's cookies, conditional or range headers.
$media=Join-Path $extensionRoot 'src/media/MediaOnTab.ts'
Edit093 $media 'request = new Request(url, {headers: requestHeaders});' @'
request = new Request(url, {credentials: "omit", cache: "no-store"});
'@
Edit093 $media '        let content: string | null;' '        let content: {text: string, url: string} | null;'
Edit093 $media @'
        const playlist = this.parseHLS(content)
'@ @'
        // A navigation while fetch was pending must not populate the next page.
        if (this.isCanceled(mediaToProcess)) return;
        // Relative URIs belong to the final response URL, including redirects.
        request = new Request(content.url, {credentials: "omit", cache: "no-store"});
        const playlist = this.parseHLS(content.text)
'@
Edit093 $media @'
                const processingMedia = this.getOrCreateProcessingMedia(variant.uri);
'@ @'
                const processingMedia = this.getOrCreateProcessingMedia(new URL(variant.uri, request.url).href);
'@
Edit093 $media @'
            applyHeadersToProcessingItem(mediaToProcess, requestHeaders)
            this.onMediaProcessed(mediaToProcess)
'@ @'
            // Candidate was verified anonymously. Do not forward captured headers.
            applyHeadersToProcessingItem(mediaToProcess, new Headers())
            this.onMediaProcessed(mediaToProcess)
'@
Edit093 $media @'
        note("manifest-http-non2xx");
'@ @'
        note("manifest-http-non2xx");
        note(`manifest-http-${response.status}`);
'@
Edit093 $media @'
        return await response.text();
'@ @'
        return {text: await response.text(), url: response.url};
'@
Write-Host 'RishiDM: public HLS uses unconditional anonymous GETs and final redirect URLs.'
Edit093 (Join-Path $extensionRoot 'src/browseractionpopup/BrowserAction.tsx') 'app: "RishiDM 0.9.3"' 'app: "RishiDM 0.9.4"'
