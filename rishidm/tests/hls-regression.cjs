// Runs the actual generated MediaOnTab, with only browser.tabs mocked.
const assert = require('node:assert/strict');
const http = require('node:http');
const path = require('node:path');
const fs = require('node:fs');
const root = path.resolve(process.argv[2]);
const baseline = process.argv.includes('--baseline');
async function main() {
const {build} = require(path.join(root, 'node_modules/vite'));
const bundle = path.join(root, '.hls-test.cjs');
await build({configFile:false,root,logLevel:'error',resolve:{alias:{
  '~':path.join(root,'src'),'webextension-polyfill':path.join(__dirname,'browser-stub.cjs')}},
  build:{emptyOutDir:false,outDir:root,minify:false,lib:{entry:path.join(root,'src/media/MediaOnTab.ts'),formats:['cjs'],fileName:()=>'.hls-test.cjs'}}});
global.self=globalThis;
const {MediaOnTab, getRishiHlsReasons} = require(bundle);
const media = '#EXTM3U\n#EXT-X-TARGETDURATION:4\n#EXT-X-MEDIA-SEQUENCE:0\n#EXTINF:4,\nsegment.ts\n#EXT-X-ENDLIST\n';
const master = '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=100000,RESOLUTION=640x360\nmedia.m3u8\n';
const requests=[];
const server=http.createServer((req,res)=>{
  const url=new URL(req.url,'http://localhost'); requests.push({path:url.pathname,headers:req.headers});
  res.setHeader('Content-Type','application/vnd.apple.mpegurl');
  if(url.pathname==='/cached.m3u8' && req.headers['if-none-match']) {res.writeHead(304);return res.end();}
  if(url.pathname==='/start.m3u8') {res.writeHead(302,{Location:'/cdn/master.m3u8'});return res.end();}
  if(url.pathname==='/cdn/master.m3u8') return res.end(master);
  if(url.pathname==='/media.m3u8') {res.writeHead(404);return res.end();}
  if(/^\/status\//.test(url.pathname)) {res.writeHead(Number(url.pathname.split('/')[2]));return res.end();}
  if(url.pathname==='/encrypted.m3u8') return res.end(media.replace('#EXTINF:', '#EXT-X-KEY:METHOD=AES-128,URI="key.bin"\n#EXTINF:'));
  if(url.pathname==='/delayed.m3u8') return setTimeout(()=>res.end(master),40);
  res.end(media);
});
let tab=0;
async function detect(base,route,headers={}) {
  const id=++tab; let list=[];
  const processor=new MediaOnTab(id,{onListUpdated(value){list=value;}});
  await processor.process({mediaType:'hls',url:base+route,requestHeaders:new Headers(headers),responseHeaders:new Headers()});
  await new Promise(resolve=>setTimeout(resolve,100));
  return {list,processor,id};
}
  await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
  const base=`http://127.0.0.1:${server.address().port}`;
  try {
    await fetch(base+'/health');
    const control=await detect(base,'/public.m3u8');
    assert.equal(control.list.length,1,JSON.stringify(getRishiHlsReasons(control.id)));
    const cached=await detect(base,'/cached.m3u8',{'If-None-Match':'"fixture-v1"'});
    assert.equal(cached.list.length,baseline?0:1);
    if(baseline) assert.equal(getRishiHlsReasons(cached.id)['manifest-http-non2xx'],1);
    const redirected=await detect(base,'/start.m3u8');
    assert.equal(redirected.list.length,baseline?0:1);
    if(!baseline) {
      assert.equal(redirected.list[0].uri,base+'/cdn/media.m3u8');
      assert.equal(redirected.list[0].bandwidth,'100kbps');
      assert.ok(redirected.list[0].resolution);
    }
    for(const status of [401,403,404,429,503]) {
      const r=await detect(base,`/status/${status}/media.m3u8`);
      assert.equal(r.list.length,0);
      await r.processor.process({mediaType:'hls',url:`${base}/status/${status}/media.m3u8`,requestHeaders:new Headers(),responseHeaders:new Headers()});
      assert.equal(requests.filter(x=>x.path===`/status/${status}/media.m3u8`).length,1);
      if(!baseline) assert.equal(getRishiHlsReasons(r.id)[`manifest-http-${status}`],1);
    }
    assert.equal((await detect(base,'/encrypted.m3u8')).list.length,0);
    if(!baseline) {
      const r=await detect(base,'/anonymous.m3u8',{'Authorization':'Bearer test-only','Cookie':'fixture=1','X-Api-Key':'test-only','Range':'bytes=0-10','If-Modified-Since':'Wed, 21 Oct 2015 07:28:00 GMT'});
      assert.equal(r.list.length,1);
      const sent=requests.find(x=>x.path==='/anonymous.m3u8').headers;
      for(const header of ['authorization','cookie','x-api-key','range','if-modified-since']) assert.equal(sent[header],undefined);
      assert.deepEqual(r.list[0].requestHeaders,{});
      let list=[]; const p=new MediaOnTab(++tab,{onListUpdated(v){list=v;}});
      const pending=p.process({mediaType:'hls',url:base+'/delayed.m3u8',requestHeaders:new Headers(),responseHeaders:new Headers()});
      p.reset(); await pending; await new Promise(r=>setTimeout(r,100));
      assert.equal(list.length,0);
    }
    // Existing direct HTTP path and notification-tone filter.
    const p=new MediaOnTab(++tab,{onListUpdated(v){global.httpList=v;}});
    global.httpList=[];
    await p.process({mediaType:'http',url:base+'/tone.mp3',requestHeaders:new Headers(),responseHeaders:new Headers({'Content-Type':'audio/mpeg','Content-Length':'1000'})});
    assert.equal(global.httpList.length,0);
    await p.process({mediaType:'http',url:base+'/video.mp4',requestHeaders:new Headers({'X-Fixture':'preserved'}),responseHeaders:new Headers({'Content-Type':'video/mp4','Content-Length':'1000000'})});
    await new Promise(r=>setTimeout(r,10));
    assert.equal(global.httpList.length,1); assert.equal(global.httpList[0].requestHeaders['x-fixture'],'preserved');
    console.log(baseline?'BASELINE: reproduced conditional-request 304 and redirected-master 404; public control and denial/encryption checks passed.':'PASS: public HLS, conditional headers, redirects, variant metadata, 401/403/404/429/503, encryption, anonymous requests, navigation cancellation, HTTP video and tone filtering.');
  } finally {server.closeAllConnections();server.close();fs.unlinkSync(bundle);}
}
main().catch(e=>{console.error(e);process.exitCode=1;});
