// Offline regression tests of the exact Dropbox helper compiled into the extension.
// No Dropbox credentials, private links, or live requests used.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(process.argv[2]);
async function main() {
  const {build} = require(path.join(root, 'node_modules/vite'));
  const output = path.join(root, '.dropbox-test.cjs');
  await build({
    configFile:false,root,logLevel:'error',
    build:{emptyOutDir:false,outDir:root,minify:false,
      lib:{entry:path.join(root,'src/utils/RishiDropbox.ts'),
        formats:['cjs'],fileName:()=>'.dropbox-test.cjs'}}
  });
  try {
    const {isRishiDropboxResourceUrl,shouldRishiDropboxUseBrowser,
      rishiDropboxDirectShareUrl} = require(output);

    const shared = 'https://www.dropbox.com/scl/fi/abc123/Prompt-Guide.pdf?rlkey=fixture-key&st=fixture&dl=0';
    const canonical = rishiDropboxDirectShareUrl(shared);
    assert.ok(canonical);
    const parsed = new URL(canonical);
    assert.equal(parsed.searchParams.get('dl'),'1');
    assert.equal(parsed.searchParams.get('rlkey'),'fixture-key');
    assert.equal(parsed.searchParams.get('st'),'fixture');
    assert.equal(parsed.pathname,'/scl/fi/abc123/Prompt-Guide.pdf');
    assert.equal(rishiDropboxDirectShareUrl(canonical),canonical);
    assert.equal(rishiDropboxDirectShareUrl('https://dropbox.com/s/abc123/report.pdf?dl=0'),
      'https://dropbox.com/s/abc123/report.pdf?dl=1');
    assert.equal(rishiDropboxDirectShareUrl('https://www.dropbox.com/scl/fi/abc123/file.pdf#fragment'),
      'https://www.dropbox.com/scl/fi/abc123/file.pdf?dl=1');
    for(const notFile of [
      'https://dropbox.com/scl/fo/folder/foldername?dl=0',
      'https://dropbox.com/home',
      'https://www.dropbox.com/preview',
      'https://mydropbox.com/scl/fi/abc/file.pdf?dl=0',
      'https://dropbox.com.evil.invalid/scl/fi/abc/file.pdf?dl=0',
      'http://www.dropbox.com/scl/fi/abc/file.pdf?dl=0',
      'https://dl.dropboxusercontent.com/cd/0/get/file.pdf',
      'file:///scl/fi/abc/file.pdf',
      '',
      null
    ]) assert.equal(rishiDropboxDirectShareUrl(notFile),null,String(notFile));
    assert.equal(shouldRishiDropboxUseBrowser('https://uc123.dl.dropboxusercontent.com/cd/0/get/fixture?token=private'),true);
    assert.equal(shouldRishiDropboxUseBrowser('https://www.dropbox.com/scl/fi/abc/file.pdf?dl=1'),true);
    assert.equal(shouldRishiDropboxUseBrowser('https://assets.dropboxstatic.com/static/logo.png'),true);
    assert.equal(shouldRishiDropboxUseBrowser('https://example.org/download?id=1','https://www.dropbox.com/scl/fi/abc/file.pdf'),true);
    assert.equal(shouldRishiDropboxUseBrowser('https://example.org/a.pdf','https://othersite.invalid/page'),false);
    assert.equal(isRishiDropboxResourceUrl('https://dropbox.com.evil.invalid/cd/file'),false);
    assert.equal(isRishiDropboxResourceUrl('https://mydropbox.com/file'),false);
    assert.equal(isRishiDropboxResourceUrl('ftp://www.dropbox.com/file'),false);
    // Inspect the actual extension call sites to guard against accidental
    // reintroduction of cancelling Dropbox browser downloads.
    const interceptor=fs.readFileSync(path.join(root,'src/linkgrabber/DownloadLinkInterceptor.ts'),'utf8');
    assert.ok(interceptor.includes('shouldRishiDropboxUseBrowser(details.url, details.referrer) return') === false);
    assert.match(interceptor,/if\s*\(shouldRishiDropboxUseBrowser\(details\.url,\s*details\.referrer\)\)\s*return/);
    assert.match(interceptor,/request\.finalResponse = details[\s\S]*?if\s*\(shouldRishiDropboxUseBrowser\(/);
    const background=fs.readFileSync(path.join(root,'src/background/background.ts'),'utf8');
    assert.match(background,/rishidmDropboxAction === "queue-share"/);
    assert.match(background,/const direct = rishiDropboxDirectShareUrl\(tab\.url\)/);
    assert.match(background,/headers: \{\}, description: null, suggestedName: null, type: "http"/);
    const popup=fs.readFileSync(path.join(root,'src/browseractionpopup/BrowserAction.tsx'),'utf8');
    assert.match(popup,/Download Dropbox file with RishiDM/);
    console.log('PASS: original share rewrite, validation, CDN fallback guards, explicit queue action and normal non-Dropbox capture.');
  } finally {
    try{fs.unlinkSync(output)}catch{}
  }
}
main().catch(e=>{console.error(e);process.exitCode=1});
