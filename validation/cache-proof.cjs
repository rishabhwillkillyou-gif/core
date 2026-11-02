// Negative control: ordinary browser-managed cache revalidation alone need not
// cause the copied-header defect. Do not conflate it with explicit validators.
const {chromium}=require('../rishidm/tests/node_modules/playwright');
const http=require('node:http'),fs=require('node:fs'),path=require('node:path'),os=require('node:os'),assert=require('node:assert/strict');
const ext=path.resolve(process.argv[2]);
const expected=1;
const body='#EXTM3U\n#EXT-X-TARGETDURATION:4\n#EXTINF:4,\nsegment.ts\n#EXT-X-ENDLIST\n';
const outcomes=[];
const server=http.createServer((req,res)=>{
  if(req.url==='/player'){res.setHeader('Content-Type','text/html');return res.end('<title>Owned cache fixture</title>');}
  res.setHeader('Content-Type','application/vnd.apple.mpegurl');
  res.setHeader('ETag','"fixture-v1"');res.setHeader('Cache-Control','no-cache');
  const status=req.headers['if-none-match']?304:200;outcomes.push(status);
  res.writeHead(status);res.end(status===200?body:undefined);
});
(async()=>{
  await new Promise(r=>server.listen(0,'127.0.0.1',r));
  const profile=fs.mkdtempSync(path.join(os.tmpdir(),'rishidm-cache-'));
  let ctx;
  try {
    ctx=await chromium.launchPersistentContext(profile,{headless:true,channel:'chromium',args:[`--disable-extensions-except=${ext}`,`--load-extension=${ext}`]});
    const worker=ctx.serviceWorkers()[0]||await ctx.waitForEvent('serviceworker');
    // Wait for extension APIs and startup; browser storage is disposable.
    for(let i=0;i<50;i++){if(await worker.evaluate(()=>!!chrome.storage))break;await new Promise(r=>setTimeout(r,100));}
    await new Promise(r=>setTimeout(r,1500));
    await worker.evaluate(()=>chrome.storage.local.set({popupEnabled:false}));
    await new Promise(r=>setTimeout(r,300));
    const page=await ctx.newPage(), cdp=await ctx.newCDPSession(page),worlds=[];
    cdp.on('Runtime.executionContextCreated',({context})=>worlds.push(context));await cdp.send('Runtime.enable');
    await page.goto(`http://127.0.0.1:${server.address().port}/player`);
    const first=await page.evaluate(async()=>{const r=await fetch('/cached.m3u8');return {status:r.status,body:await r.text()};});
    assert.equal(first.status,200);assert.equal(first.body,body);
    await worker.evaluate(()=>chrome.storage.local.set({popupEnabled:true}));
    await new Promise(r=>setTimeout(r,300));
    const replay=await page.evaluate(async()=>{const r=await fetch('/cached.m3u8');return {status:r.status,body:await r.text()};});
    assert.equal(replay.status,200);assert.equal(replay.body,body);
    await new Promise(r=>setTimeout(r,600));
    const world=worlds.find(w=>w.origin.startsWith('chrome-extension://'));
    assert.ok(world);
    const response=await cdp.send('Runtime.evaluate',{contextId:world.id,expression:"chrome.runtime.sendMessage({rishidmMediaAction:'inspect'})",awaitPromise:true,returnByValue:true});
    const snapshot=response.result.value;
    assert.equal(snapshot.candidates.length,expected,JSON.stringify(snapshot));
    console.log(JSON.stringify({browserStatus:replay.status,browserHasPlaylist:replay.body===body,httpOutcomes:outcomes,candidates:snapshot.candidates.length,reasons:snapshot.hlsReasons}));
  } finally {if(ctx)await ctx.close();server.closeAllConnections();server.close();fs.rmSync(profile,{recursive:true,force:true});}
})().catch(e=>{console.error(e);process.exitCode=1;});
