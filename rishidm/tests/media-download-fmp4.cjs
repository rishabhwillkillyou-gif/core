// RishiDM v0.9.7: end-to-end test of authorized synthetic HLS/fMP4,
// where EXT-X-MAP declares an MP4 initialization segment and segment URLs
// have NO filename extensions. Uses the exact packaged yt-dlp + FFmpeg.
const {spawn}=require('node:child_process');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const http=require('node:http');
const tools=path.resolve(process.argv[2]);
const out=path.resolve(process.argv[3]);
fs.mkdirSync(out,{recursive:true});
function run(bin,args) {return new Promise((resolve,reject)=>{
  const p=spawn(bin,args,{cwd:out,windowsHide:true});
  let messages='';
  p.stdout.on('data',buf=>messages+=buf);
  p.stderr.on('data',buf=>messages+=buf);
  p.on('error',reject);
  p.on('exit',code=>code===0?resolve(messages):reject(new Error(
    path.basename(bin)+' failed: '+messages.slice(-6000))));
});}
(async()=>{
  const ff=path.join(tools,'FFmpeg');
  const ffmpeg=path.join(ff,'ffmpeg.exe');
  await run(ffmpeg,[
    '-hide_banner','-loglevel','error','-y',
    '-f','lavfi','-i','testsrc2=size=320x180:rate=25',
    '-f','lavfi','-i','sine=frequency=440:sample_rate=48000',
    '-t','4','-c:v','libx264','-preset','ultrafast','-crf','28',
    '-g','25','-sc_threshold','0','-pix_fmt','yuv420p',
    '-c:a','aac','-f','hls','-hls_time','1','-hls_list_size','0',
    '-hls_segment_type','fmp4','-hls_fmp4_init_filename','init.mp4',
    '-hls_segment_filename','chunk-%03d.m4s','video.m3u8'
  ]);
  const original=fs.readFileSync(path.join(out,'video.m3u8'),'utf8');
  assert.match(original,/#EXT-X-MAP:URI="init.mp4"/);
  let rewritten=original;
  const parts=fs.readdirSync(out).filter(name=>/^chunk-\d{3}\.m4s$/.test(name));
  assert.ok(parts.length>=2,'Need at least two fMP4 fragments');
  for(const file of parts) {
    const extless=file.replace(/\.m4s$/,'');
    fs.copyFileSync(path.join(out,file),path.join(out,extless));
    rewritten=rewritten.replaceAll(file,extless);
  }
  fs.writeFileSync(path.join(out,'video.m3u8'),rewritten);
  assert.doesNotMatch(rewritten,/chunk-\d+\.m4s/);
  const server=http.createServer((req,res)=>{
    const name=path.basename(new URL(req.url,'http://localhost').pathname);
    if(!/^(?:video\.m3u8|init\.mp4|chunk-\d{3})$/.test(name)) {
      res.writeHead(404);return res.end();
    }
    const target=path.join(out,name);
    if(!fs.existsSync(target)){res.writeHead(404);return res.end();}
    res.setHeader('Content-Type',name.endsWith('.m3u8')?
      'application/vnd.apple.mpegurl':'video/mp4');
    res.setHeader('Content-Length',String(fs.statSync(target).size));
    fs.createReadStream(target).pipe(res);
  });
  await new Promise(r=>server.listen(0,'127.0.0.1',r));
  try{
    const url='http://127.0.0.1:'+server.address().port+'/video.m3u8';
    await run(path.join(tools,'yt-dlp.exe'),[
      '--no-config','--no-playlist','--windows-filenames','--continue',
      '--no-overwrites','--newline','--retries','3','--fragment-retries','3',
      '--concurrent-fragments','4','--ffmpeg-location',ff,
      '--js-runtimes','deno:'+path.join(tools,'deno.exe'),
      '--format','bv+ba/b','--merge-output-format','mkv',
      '-o','download.%(ext)s','--',url
    ]);
    const file=fs.readdirSync(out).find(name=>/^download\.(?:mp4|mkv|ts)$/.test(name));
    assert.ok(file,'Missing completed video from extensionless fMP4 playlist');
    const probe=JSON.parse(await run(path.join(ff,'ffprobe.exe'),[
      '-v','quiet','-show_format','-show_streams','-of','json',file
    ]));
    assert.ok(Number(probe.format.duration)>3.5,'Downloaded video is incomplete');
    assert.ok(probe.streams.some(x=>x.codec_type==='video'));
    assert.ok(probe.streams.some(x=>x.codec_type==='audio'));
    await run(ffmpeg,['-v','error','-i',file,'-f','null','-']);
    console.log('PASS: bundled yt-dlp/FFmpeg assembled and decoded synthetic extensionless fMP4 HLS, video and audio.');
  } finally {server.closeAllConnections();server.close();}
})().catch(e=>{console.error(e);process.exitCode=1});
