const {chromium}=require('playwright');
const assert=require('node:assert/strict');
const http=require('node:http');
const fs=require('node:fs');
const path=require('node:path');
const os=require('node:os');
const ext=path.resolve(process.argv[2]);
const manifest=JSON.parse(fs.readFileSync(path.join(ext,'manifest.json')));
const media='#EXTM3U\n#EXT-X-TARGETDURATION:4\n#EXTINF:4,\nsegment.ts\n#EXT-X-ENDLIST\n';
const server=http.createServer((req,res)=>{
  const u=new URL(req.url,'http://localhost');
  res.setHeader('Access-Control-Allow-Origin','*');
  if(u.pathname==='/player') {
    res.setHeader('Content-Type','text/html');
    return res.end(`<title>RishiDM authorized fixture</title><iframe src="/frame?route=${encodeURIComponent(u.searchParams.get('route'))}"></iframe>`);
  }
  if(u.pathname==='/frame') {
    res.setHeader('Content-Type','text/html');
    return res.end('<title>Authorized iframe</title>');
  }
  res.setHeader('Content-Type','application/vnd.apple.mpegurl');
  if(u.pathname==='/cached.m3u8' && req.headers['if-none-match']) {res.writeHead(304);return res.end();}
  if(u.pathname==='/start.m3u8') {res.writeHead(302,{Location:'/cdn/master.m3u8'});return res.end();}
  if(u.pathname==='/cdn/master.m3u8') return res.end('#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=100000,RESOLUTION=640x360\nmedia.m3u8\n');
  if(u.pathname==='/media.m3u8') {res.writeHead(404);return res.end();}
  if(u.pathname.startsWith('/status/')) {res.writeHead(Number(u.pathname.split('/')[2]));return res.end();}
  if(u.pathname==='/encrypted.m3u8') return res.end(media.replace('#EXTINF:','#EXT-X-KEY:METHOD=AES-128,URI="key.bin"\n#EXTINF:'));
  res.end(media);
});
(async()=>{
  await new Promise(r=>server.listen(0,'127.0.0.1',r));
  const base=`http://127.0.0.1:${server.address().port}`;
  const profile=fs.mkdtempSync(path.join(os.tmpdir(),'rishidm-browser-'));
  let context;
  try {
    context=await chromium.launchPersistentContext(profile,{headless:true,channel:'chromium',args:[`--disable-extensions-except=${ext}`,`--load-extension=${ext}`]});
    const worker=context.serviceWorkers()[0] || await context.waitForEvent('serviceworker');
    if(process.env.RISHIDM_TEST_DEBUG) {
      context.on('console',m=>console.log(m.type(),m.text()));
      console.log(worker.url(),await worker.evaluate(()=>({keys:Object.keys(chrome),listeners:chrome.webRequest?.onHeadersReceived.hasListeners()})));
    }
    const id=new URL(worker.url()).host;
    assert.equal(id,'fflnlejbfglkcpigedkajcpilphkkmib');
    const popup=await context.newPage();
    await popup.goto(`chrome-extension://${id}/${manifest.action.default_popup}`);
    await new Promise(r=>setTimeout(r,1500));
    if(process.env.RISHIDM_TEST_DEBUG) {
      console.log('ready',await worker.evaluate(()=>({keys:Object.keys(chrome),listeners:chrome.webRequest?.onHeadersReceived.hasListeners()})));
      console.log('popup permissions',await popup.evaluate(()=>chrome.permissions.getAll()));
      await worker.evaluate(()=>{globalThis.testSenders=[];chrome.runtime.onMessage.addListener((m,s)=>{if(m.rishidmMediaAction==='inspect')globalThis.testSenders.push({tab:s.tab?.id,requested:m.tabId});});});
    }
    for(const [route,accepted] of [['/public.m3u8',true],['/cached.m3u8',true],['/start.m3u8',true],['/status/401/file.m3u8',false],['/status/403/file.m3u8',false],['/status/404/file.m3u8',false],['/encrypted.m3u8',false]]) {
      const page=await context.newPage();
      const cdp=await context.newCDPSession(page);
      const worlds=[];
      cdp.on('Runtime.executionContextCreated',({context})=>worlds.push(context));
      await cdp.send('Runtime.enable');
      await page.goto(base+'/player?route='+encodeURIComponent(route));
      await page.frames()[1].evaluate(async route=>{
        await fetch(route,{headers:{'If-None-Match':'"fixture-v1"'}}).then(r=>r.text());
      },route);
      let snapshot;
      for(let i=0;i<50;i++) {
        const world=worlds.find(w=>w.origin===`chrome-extension://${id}` || w.name===manifest.name);
        if(!world) {await new Promise(r=>setTimeout(r,100));continue;}
        const result=await cdp.send('Runtime.evaluate',{contextId:world.id,expression:"chrome.runtime.sendMessage({rishidmMediaAction:'inspect'})",awaitPromise:true,returnByValue:true});
        snapshot=result.result.value;
        if(accepted ? snapshot?.candidates?.some(x=>x.downloadable) : Object.keys(snapshot?.hlsReasons||{}).some(x=>/manifest-http-non2xx|media-playlist-encrypted/.test(x))) break;
        await new Promise(r=>setTimeout(r,100));
      }
      if(process.env.RISHIDM_TEST_DEBUG) console.log('senders',await worker.evaluate(()=>globalThis.testSenders.slice(-2)));
      assert.equal(snapshot.candidates.some(x=>x.downloadable),accepted,JSON.stringify({route,snapshot}));
      assert.ok(snapshot.stages.interceptedHLS>0);
      console.log('Chromium iframe:',route,accepted?'candidate published':'correctly rejected');
      await page.close();
    }
    console.log('PASS: packaged MV3 worker, webRequest interception, iframe attribution, popup messaging, public/conditional/redirected HLS and denial/encryption gates.');
  } finally {
    if(context) await context.close();
    server.closeAllConnections();server.close();
    fs.rmSync(profile,{recursive:true,force:true});
  }
})().catch(e=>{console.error(e);process.exitCode=1;});
