// เรนเดอร์คลิปท้องฟ้า 10 วินาที 1080×1080 → MP4
// ใช้: node render.js <ไฟล์-sky-clip.html> [ชื่อไฟล์ mp4]
// ต้องมี ffmpeg/ffprobe · ถ้าไม่มี puppeteer จะติดตั้งให้ (หรือใช้ puppeteer-core + Chromium ในเครื่องผ่าน CHROME_PATH)
const fs=require('fs'), path=require('path'), {execSync}=require('child_process');
function need(m){ try{ return require(m); }catch(_){ return null; } }
let pp=need('puppeteer'); if(!pp&&!process.env.CHROME_PATH){ console.log('ติดตั้ง puppeteer…'); execSync('npm i puppeteer',{stdio:'inherit',cwd:__dirname}); pp=require(path.join(__dirname,'node_modules','puppeteer')); }
if(!pp) pp=need('puppeteer-core')||require(path.join(__dirname,'node_modules','puppeteer-core'));
const HTML=path.resolve(process.argv[2]||path.join(__dirname,'sky-clip.html')), OUT=path.resolve(process.argv[3]||HTML.replace(/\.html$/,'.mp4'));
const FPS=30, SEC=10, NF=FPS*SEC, FR=path.join(path.dirname(OUT),'.frames-'+path.basename(OUT,'.mp4'));
const LOCAL=process.env.LOCAL_MODULES; // ถ้าออฟไลน์: โฟลเดอร์ node_modules ที่มี three@0.160 และ @fontsource/kanit
(async()=>{ fs.rmSync(FR,{recursive:true,force:true}); fs.mkdirSync(FR,{recursive:true});
  const br=await pp.launch({headless:'new',executablePath:process.env.CHROME_PATH||undefined,args:['--no-sandbox','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader','--ignore-gpu-blocklist','--hide-scrollbars']});
  const pg=await br.newPage(); await pg.setViewport({width:1080,height:1080,deviceScaleFactor:1});
  if(LOCAL){ await pg.setRequestInterception(true); pg.on('request',r=>{ const u=r.url(); let m;
    if((m=u.match(/cdn\.jsdelivr\.net\/npm\/three@0\.160\.0\/(.*)$/))) return r.respond({headers:{'Access-Control-Allow-Origin':'*'},contentType:'application/javascript',body:fs.readFileSync(path.join(LOCAL,'three',m[1]))});
    if(/fonts\.googleapis\.com\/css2/.test(u)){ const f=w=>['thai','latin'].map(s=>`@font-face{font-family:'Kanit';font-weight:${w};src:url(data:font/woff2;base64,${fs.readFileSync(path.join(LOCAL,'@fontsource/kanit/files',`kanit-${s}-${w}-normal.woff2`)).toString('base64')}) format('woff2');unicode-range:${s==='thai'?'U+0E01-0E5B,U+200C-200D,U+25CC':'U+0000-00FF,U+2000-206F'}}`).join(''); return r.respond({headers:{'Access-Control-Allow-Origin':'*'},contentType:'text/css',body:[300,400,500,600].map(f).join('')}); }
    if(/fonts\.gstatic|fonts\.googleapis/.test(u)) return r.abort(); r.continue(); }); }
  const errs=[]; pg.on('pageerror',e=>errs.push(e.message));
  await pg.goto('file://'+HTML,{waitUntil:'load'}); await pg.waitForFunction('window.__ready===true',{timeout:120000}); await pg.evaluate(()=>document.fonts.ready.then(()=>true));
  await pg.evaluate(()=>window.__seek(0));
  const t0=Date.now(); for(let i=0;i<NF;i++){ await pg.evaluate(t=>window.__seek(t),i/FPS); await pg.screenshot({path:path.join(FR,`f${String(i).padStart(4,'0')}.png`),fullPage:true}); if(i%30===0) console.log(`เฟรม ${i}/${NF} · ${((Date.now()-t0)/1000).toFixed(0)} วิ`); }
  await br.close(); if(errs.length) console.log('ข้อผิดพลาดในหน้า:',errs.slice(0,3));
  execSync(`ffmpeg -y -loglevel error -framerate ${FPS} -i "${FR}/f%04d.png" -frames:v ${NF} -c:v libx264 -preset slow -crf 17 -pix_fmt yuv420p -r ${FPS} -movflags +faststart "${OUT}"`,{stdio:'inherit'});
  const pr=execSync(`ffprobe -v error -select_streams v:0 -count_frames -show_entries stream=width,height,nb_read_frames,r_frame_rate,pix_fmt,codec_name -of default=nw=1 "${OUT}"`).toString(); console.log(pr);
  const ok=/width=1080/.test(pr)&&/height=1080/.test(pr)&&new RegExp('nb_read_frames='+NF).test(pr); console.log(ok?`ผ่าน: 1080×1080 · ${NF} เฟรม → ${OUT}`:'ไม่ผ่านการตรวจ'); fs.rmSync(FR,{recursive:true,force:true}); process.exit(ok?0:1); })();
