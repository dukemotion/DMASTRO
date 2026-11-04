// สร้างหน้าคลิปจากดวงในระบบ: เปิดแอป → เลือกดวงตามชื่อ → ฝังข้อมูลลงเทมเพลต → sky-clip.html
// ใช้: node build.js <app/index.html> <ชื่อดวง> [ไฟล์ออก]
const fs=require('fs'), path=require('path'); let pp; try{ pp=require('puppeteer'); }catch(_){ pp=require(path.join(__dirname,'node_modules','puppeteer-core')); }
(async()=>{ const APP=path.resolve(process.argv[2]), NAME=process.argv[3]||'', OUT=path.resolve(process.argv[4]||path.join(__dirname,'sky-clip.html'));
  const br=await pp.launch({headless:'new',executablePath:process.env.CHROME_PATH||undefined,args:['--no-sandbox']}); const pg=await br.newPage(); await pg.goto('file://'+APP); await new Promise(r=>setTimeout(r,3500));
  const html=await pg.evaluate(n=>{ const ps=loadProfiles(); const i=ps.findIndex(x=>x.name===n||(n&&x.name.includes(n))); fillForm(ps[i>=0?i:0]); compute(); return skyClipHTML67(); },NAME); await br.close();
  fs.writeFileSync(OUT,html); console.log('เขียน',OUT,(html.length/1024).toFixed(0)+' KB'); })();
