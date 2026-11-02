// Authorized synthetic media only: test the exact packaged yt-dlp/FFmpeg binaries.
const {spawn}=require('node:child_process');
const fs=require('node:fs');
const path=require('node:path');
const http=require('node:http');
const assert=require('node:assert/strict');
const tools=path.resolve(process.argv[2]);
const output=path.resolve(process.argv[3]);
fs.mkdirSync(output,{recursive:true});
function run(exe,args){return new Promise((resolve,reject)=>{
  const p=spawn(exe,args,{cwd:output,windowsHide:true});let text='';
  p.stdout.on('data',x=>text+=x);p.stderr.on('data',x=>text+=x);
  p.on('error',reject);p.on('exit',code=>code===0?resolve(text):reject(new Error(text)));
});}
(async()=>{
  const ff=path.join(tools,'FFmpeg');
  await run(path.join(ff,'ffmpeg.exe'),['-hide_banner','-loglevel','error','-y','-f','lavfi','-i','testsrc2=size=320x180:rate=25','-f','lavfi','-i','sine=frequency=440:sample_rate=48000','-t','4','-c:v','mpeg2video','-g','25','-c:a','aac','-f','hls','-hls_time','1','-hls_list_size','0','-hls_segment_filename','segment-%03d.ts','media.m3u8']);
  const server=http.createServer((req,res)=>{
    const name=path.basename(new URL(req.url,'http://localhost').pathname);
    const file=path.join(output,name);
    if(!/^media\.m3u8$|^segment-\d+\.ts$/.test(name)||!fs.existsSync(file)){res.writeHead(404);return res.end();}
    res.setHeader('Content-Type',name.endsWith('.m3u8')?'application/vnd.apple.mpegurl':'video/mp2t');
    fs.createReadStream(file).pipe(res);
  });
  await new Promise(r=>server.listen(0,'127.0.0.1',r));
  try {
    await run(path.join(tools,'yt-dlp.exe'),['--no-config','--no-playlist','--windows-filenames','--continue','--no-overwrites','--newline','--retries','10','--fragment-retries','10','--retry-sleep','2','--concurrent-fragments','4','--ffmpeg-location',ff,'--js-runtimes','deno:'+path.join(tools,'deno.exe'),'--format','bv+ba/b','--merge-output-format','mkv','-o','download.%(ext)s','--',`http://127.0.0.1:${server.address().port}/media.m3u8`]);
    const file=fs.readdirSync(output).find(x=>/^download\.(mp4|mkv|ts)$/.test(x));
    assert.ok(file,'No media download produced');
    const probe=JSON.parse(await run(path.join(ff,'ffprobe.exe'),['-v','quiet','-show_format','-show_streams','-of','json',file]));
    assert.ok(Number(probe.format.duration)>=3.9);
    assert.ok(probe.streams.some(x=>x.codec_type==='video'));
    assert.ok(probe.streams.some(x=>x.codec_type==='audio'));
    await run(path.join(ff,'ffmpeg.exe'),['-v','error','-i',file,'-f','null','-']);
    console.log('PASS: packaged media tools downloaded and decoded 4 seconds of owned synthetic HLS video and audio.');
  } finally {server.closeAllConnections();server.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
