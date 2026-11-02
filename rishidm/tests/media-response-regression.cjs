// Deterministic regression tests for response classification, no external streams.
const assert=require('node:assert/strict');
const path=require('node:path');
const fs=require('node:fs');
const root=path.resolve(process.argv[2]);
async function main(){
  const {build}=require(path.join(root,'node_modules/vite'));
  const output=path.join(root,'.rishi-response-test.cjs');
  await build({configFile:false,root,logLevel:'error',
    build:{emptyOutDir:false,outDir:root,minify:false,
      lib:{entry:path.join(root,'src/media/RishiResponseInsight.ts'),formats:['cjs'],
        fileName:()=>'.rishi-response-test.cjs'}}});
  try {
    const {classifyRishiResponse,recordRishiResponseKind,getRishiResponseInsights,
      clearRishiResponseInsights}=require(output);
    const h=(obj)=>Object.entries(obj).map(([name,value])=>({name,value:String(value)}));
    const r=(url,statusCode,ct,extra={},type='xmlhttprequest')=>({
      url,type,statusCode,method:'GET',
      responseHeaders:h({'Content-Type':ct,...extra})
    });
    const q={requestHeaders:[]};
    assert.equal(classifyRishiResponse(r('https://example.org/api/stream',200,
      'application/vnd.apple.mpegurl'),q),'hls-nonstandard-path');
    assert.equal(classifyRishiResponse(r('https://example.org/movie.m3u8',200,
      'application/vnd.apple.mpegurl'),q),'none'); // already handled upstream
    assert.equal(classifyRishiResponse(r('https://example.org/playback',200,
      'application/dash+xml'),q),'dash-observed');
    assert.equal(classifyRishiResponse(r('https://example.org/movie.mp4',200,
      'video/mp4',{'Content-Length': '2000000'}),q),'xhr-standalone-video');
    assert.equal(classifyRishiResponse(r('https://example.org/media?id=4',200,
      'video/webm',{'Content-Length':'2000000'}),q),'xhr-standalone-video');
    assert.equal(classifyRishiResponse(r('https://example.org/movie.mp4',206,
      'video/mp4',{'Content-Length':'2000000','Content-Range':'bytes 0-999/2000000'}),q),'xhr-partial');
    assert.equal(classifyRishiResponse(r('https://example.org/movie.mp4',200,
      'video/mp4',{'Content-Length':'2000000','Content-Range':'bytes 0-999/2000000'}),q),'xhr-partial');
    assert.equal(classifyRishiResponse(r('https://example.org/movie.m4s',200,
      'video/mp4',{'Content-Length':'2000000'}),q),'xhr-segment');
    assert.equal(classifyRishiResponse(r('https://example.org/chunk',200,
      'video/mp2t',{'Content-Length':'2000000'}),q),'xhr-segment');
    assert.equal(classifyRishiResponse(r('https://example.org/stream',200,
      'video/mp4',{}),q),'xhr-unknown-size');
    assert.equal(classifyRishiResponse(r('https://example.org/stream',200,
      'video/mp4',{'Content-Length':'3000'}),q),'xhr-unknown-size');
    assert.equal(classifyRishiResponse(r('https://example.org/stream',200,
      'video/mp4',{'Content-Length':'2000000'}),{requestHeaders:h({'Cookie':'private=value'})}),'xhr-private');
    assert.equal(classifyRishiResponse(r('https://example.org/stream',200,
      'video/mp4',{'Content-Length':'2000000'}),{requestHeaders:h({'Authorization':'Bearer private'})}),'xhr-private');
    assert.equal(classifyRishiResponse(r('https://example.org/stream',403,
      'video/mp4',{'Content-Length':'2000000'}),q),'none');
    assert.equal(classifyRishiResponse(r('https://example.org/tone.mp3',200,
      'audio/mpeg',{'Content-Length':'2000000'}),q),'none');
    assert.equal(classifyRishiResponse(r('https://example.org/movie.mp4',200,
      'video/mp4',{'Content-Length':'2000000'},'media'),q),'none'); // existing path
    assert.equal(classifyRishiResponse({...r('https://example.org/movie.mp4',200,'video/mp4',
      {'Content-Length':'2000000'}),method:'POST'},q),'none');
    assert.equal(classifyRishiResponse(r('https://example.org/movie.mp4',200,
      'text/html',{'Content-Length':'2000000'}),q),'none');
    recordRishiResponseKind(92,'xhr-partial');
    recordRishiResponseKind(92,'xhr-standalone-video');
    recordRishiResponseKind(92,'none');
    assert.deepEqual(getRishiResponseInsights(92),{'xhr-partial':1,'xhr-standalone-video':1});
    clearRishiResponseInsights(92);
    assert.deepEqual(getRishiResponseInsights(92),{});
    const i=fs.readFileSync(path.join(root,'src/linkgrabber/DownloadLinkInterceptor.ts'),'utf8');
    assert.match(i,/classifyRishiResponse\(details, request\)/);
    assert.match(i,/if \(kind === "hls-nonstandard-path"\)/);
    assert.match(i,/if \(item\) this\.onMediaDetected\(details\.tabId, item\)/);
    const bg=fs.readFileSync(path.join(root,'src/background/background.ts'),'utf8');
    assert.match(bg,/responseAnalysis: getRishiResponseInsights\(tabId\)/);
    assert.match(bg,/clearRishiResponseInsights\(id\)/);
    console.log('PASS: full XHR video, MIME-only HLS, DASH classification, partial/segment/private/unknown-size rejection, navigation cleanup.');
  } finally {try{fs.unlinkSync(output)}catch{}}
}
main().catch(e=>{console.error(e);process.exitCode=1});
