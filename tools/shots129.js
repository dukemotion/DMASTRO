// สร้างภาพหน้าจอให้ทุกรายการใน CHG110 ที่ยังไม่มีภาพ (หรือ --all / --v=129,128) → app/shots/<key>.png (แปลง webp ภายหลัง)
const {chromium}=require('playwright'); const fs=require('fs'); const path=require('path');
const APP='/home/claude/myhora/app', OUT=APP+'/shots'; const args=process.argv.slice(2), ALL=args.includes('--all'), ONLY=(args.find(a=>a.startsWith('--v='))||'').slice(4).split(',').filter(Boolean);
(async()=>{ const b=await chromium.launch(); const p=await b.newPage({viewport:{width:1180,height:900},deviceScaleFactor:1}); const errs=[]; p.on('pageerror',e=>errs.push(e.message));
  await p.goto('file://'+APP+'/index.html'); await p.waitForTimeout(3000);
  await p.evaluate(()=>{ try{ LAY.tr=true; }catch(e){} fillForm(loadProfiles()[0]); compute(); const st=document.createElement('style'); st.textContent='.mnav,#tkFloat117,#lagFloat128,#lb129,.pl76{visibility:hidden!important}*{animation:none!important;transition:none!important}'; document.head.appendChild(st); });
  await p.waitForTimeout(800);
  const list=await p.evaluate(()=>CHG110.map(e=>({v:String(e.v),k:shotKey129(e.v),T:tgt129(e)})));
  const done=[];
  for(const it of list){ if(!it.T||it.T.cat==='sky') continue; const f=OUT+'/'+it.k+'.png', w=OUT+'/'+it.k+'.webp'; if(ONLY.length&&!ONLY.includes(it.v)) continue; if(!ALL&&!ONLY.length&&fs.existsSync(w)) continue;
    try{ await p.evaluate(v=>{ const e=CHG110.find(x=>String(x.v)===v); go129(e,true); },it.v); await p.waitForTimeout(1300);
      const box=await p.evaluate(T=>{ let el=T.sel?document.querySelector(T.sel):document.querySelector('#catP29 .cbody29'); if(el&&T.sel&&T.cat&&!el.classList.contains('panel')) el=el.closest('.panel')||el; if(!el) return null; if(T.sel==='#sv128'){ const cb=el.closest('.chartbox')||el; el.scrollIntoView({block:'end'}); const r=el.getBoundingClientRect(), q=cb.getBoundingClientRect(); const top=Math.max(0,r.bottom-640); return {x:Math.max(0,q.left),y:top,w:Math.min(q.width,1180),h:r.bottom-top}; } el.scrollIntoView({block:'start'}); const r=el.getBoundingClientRect(); return {x:Math.max(0,r.left),y:Math.max(0,r.top),w:Math.min(r.width,1180),h:Math.min(r.height,760)}; },it.T);
      if(!box||box.w<20||box.h<20){ console.log('skip',it.v); continue; } await p.waitForTimeout(250);
      await p.screenshot({path:f,clip:{x:box.x,y:box.y,width:box.w,height:box.h}}); done.push(it.k); console.log('ok',it.v); }catch(e){ console.log('err',it.v,e.message); } }
  console.log('DONE',done.length,'errors',errs.slice(0,3)); await b.close(); })();
