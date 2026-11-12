// Walking Star Academy — ใช้งานออฟไลน์: เก็บไฟล์หลักไว้ในเครื่อง แล้วอัปเดตเบื้องหลังเมื่อมีเน็ต
const V='ws-v214.0', CORE=['./','./index.html','./manifest.json','./icon-192.png','./icon-512.png','./icon-180.png','./logo-96.png','./logo.svg','./favicon-32.png','./pay/qr199.jpg','./pay/qr1590.jpg','./audio/interstellar.mp3'];
self.addEventListener('install',e=>{ e.waitUntil(caches.open(V).then(c=>Promise.all(CORE.map(u=>c.add(u).catch(()=>null)))).then(()=>self.skipWaiting())); });
self.addEventListener('activate',e=>{ e.waitUntil(caches.keys().then(ks=>Promise.all(ks.filter(k=>k!==V).map(k=>caches.delete(k)))).then(()=>self.clients.claim())); });
self.addEventListener('fetch',e=>{ const r=e.request; if(r.method!=='GET') return; const u=new URL(r.url); if(/supabase\.co$/.test(u.hostname)) return;
  if(r.mode==='navigate'){ e.respondWith(fetch(r).then(res=>{ const cp=res.clone(); caches.open(V).then(c=>c.put('./index.html',cp)); return res; }).catch(()=>caches.match('./index.html',{ignoreSearch:true}))); return; }
  if(r.headers.get('range')) return;
  e.respondWith(caches.match(r,{ignoreSearch:u.origin===location.origin}).then(hit=>{ const net=fetch(r).then(res=>{ if(res&&(res.ok||res.type==='opaque')){ const cp=res.clone(); caches.open(V).then(c=>c.put(r,cp)); } return res; }).catch(()=>hit); return hit||net; })); });

self.addEventListener('notificationclick',e=>{ e.notification.close(); const u=(e.notification.data&&e.notification.data.url)||'./?scan=1'; e.waitUntil(self.clients.matchAll({type:'window',includeUncontrolled:true}).then(cs=>{ for(const c of cs){ if('focus' in c){ c.postMessage({rk166:1}); return c.focus(); } } return self.clients.openWindow(u); })); });
