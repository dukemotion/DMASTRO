# คลิปท้องฟ้า 10 วินาที (1080×1080)

หน้าคลิปไดโอรามาท้องฟ้าของดวงในระบบ ดวงสุริยยาตร์ — Three.js 0.160 (import map), RoundedBoxGeometry, MeshStandardMaterial, แสงอาทิตย์ + เงานุ่ม + HemisphereLight, ACES, GTAO
ทุกภาพ (ฉาก 3D และการ์ด HTML) คำนวณจากเวลา `t` ค่าเดียวผ่าน `window.__seek(t)` — ไม่มี CSS animation / transition / timer / สุ่มรายเฟรม

## ใช้ในแอป
ท้องฟ้า 3D → ปุ่ม **คลิปไดโอรามา 1:1** → ได้ไฟล์ `คลิปท้องฟ้า-<ชื่อ>.html` เปิดในเบราว์เซอร์เล่นอัตโนมัติ 10 วินาที

## เรนเดอร์เป็น MP4
```bash
cd tools/skyclip
node build.js ../../index.html "ชื่อดวง" sky-clip.html   # สร้างหน้าคลิปจากดวงในระบบ
node render.js sky-clip.html sky-clip.mp4               # 300 เฟรม → H.264 yuv420p 30fps + ตรวจด้วย ffprobe
```
- ต้องมี `ffmpeg` และ `ffprobe` · ถ้าไม่มี puppeteer สคริปต์จะ `npm i puppeteer` ให้
- ใช้ Chromium ในเครื่อง: `CHROME_PATH=/path/to/chrome`
- ออฟไลน์: `LOCAL_MODULES=/path/to/node_modules` (ต้องมี `three@0.160.0` และ `@fontsource/kanit`)
