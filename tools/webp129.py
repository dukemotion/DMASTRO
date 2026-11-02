# แปลง app/shots/*.png → .webp (กว้างไม่เกิน 760px) แล้วเขียนรายชื่อลง SHOTS129 ใน index.html
import glob,os,re
from PIL import Image
D='/home/claude/myhora/app/shots'
for f in glob.glob(D+'/*.png'):
    im=Image.open(f).convert('RGB')
    if im.width>760: im=im.resize((760,round(im.height*760/im.width)),Image.LANCZOS)
    im.save(f[:-4]+'.webp','WEBP',quality=58,method=6); os.remove(f)
keys=sorted(os.path.basename(x)[:-5] for x in glob.glob(D+'/*.webp'))
P='/home/claude/myhora/app/index.html'; s=open(P,encoding='utf-8').read()
s,n=re.subn(r"const SHOTS129=\[[^\]]*\];","const SHOTS129="+str(keys).replace(' ','')+";",s); assert n==1
open(P,'w',encoding='utf-8').write(s)
print(len(keys),'shots', sum(os.path.getsize(x) for x in glob.glob(D+'/*.webp'))//1024,'KB')
