"""앞·뒤 휘두르기 — 팔만 골격대로 다시 그린다 (PixelLab animate-with-skeleton + 인페인팅).

글로 동작을 시키면(fetch_swing.py 의 v3) 팔을 옆으로 벌리는 장이 꼭 끼었다. 여기서는
서기 그림(캐릭터 zip 의 rotations/<방향>.png)을 64x64 에 놓고, 어깨~엉덩이 띠와 머리
위만 마스크로 열어 **팔 자리만** 골격 좌표대로 다시 그리게 한다. 얼굴·다리는 원본
그대로라 그림체가 안 흐트러지고, 팔은 몸 앞 좁은 폭에서만 오르내린다.
세 장씩 두 번 부른다(가슴·머리·턱 / 턱·배·허리) — 한 번에 딱 세 장만 받는다.
결과 다섯 장은 swing_src/<kind>/<down|up>/f0..4 로 두고 install_swing.py 에서 0,1,2,3,4 로 고른다.

준비물: <kind>_char.json (GET /v2/characters/<id>) · probe/<kind>/Idle/rotations/*.png (zip 내보내기)
사용: PIXELLAB_API_KEY=… python3 skel_inpaint.py <boy|girl> <south|north> <tag> [guidance=6] [seed=5]"""
import json, urllib.request, os, base64, io, sys
from PIL import Image, ImageDraw
kind, d, tag = sys.argv[1], sys.argv[2], sys.argv[3]
guid = float(sys.argv[4]) if len(sys.argv) > 4 else 6.0
seed = int(sys.argv[5]) if len(sys.argv) > 5 else 5
H={"Authorization":"Bearer "+os.environ["PIXELLAB_API_KEY"],"Content-Type":"application/json","User-Agent":"x"}
c=json.load(open(f'{kind}_char.json')); c=c.get('character',c)
im=Image.open(f'probe/{kind}/Idle/rotations/{d}.png').convert('RGBA'); pad=Image.new('RGBA',(64,64),(0,0,0,0)); pad.paste(im,(8,8),im)
def b64(img):
    buf=io.BytesIO(); img.save(buf,'PNG'); return base64.b64encode(buf.getvalue()).decode()
ref64=b64(pad)
kp0=c['skeletons']['2d_references'][d]['keypoints']
sh_y=(kp0['LEFT SHOULDER']['y']+kp0['RIGHT SHOULDER']['y'])/2; hip_y=(kp0['LEFT HIP']['y']+kp0['RIGHT HIP']['y'])/2
nose_y=kp0['NOSE']['y']
lsx, rsx = kp0['LEFT SHOULDER']['x'], kp0['RIGHT SHOULDER']['x']
def to64(x,y): return ((8+x*48)/64.0, (8+y*48)/64.0)
def pose(hands, elbows, z):
    pts=[]
    for k,v in kp0.items():
        x,y=v['x'],v['y']; zi=0
        if k=='LEFT ARM': x,y=hands[0]; zi=z
        elif k=='RIGHT ARM': x,y=hands[1]; zi=z
        elif k=='LEFT ELBOW': x,y=elbows[0]; zi=z
        elif k=='RIGHT ELBOW': x,y=elbows[1]; zi=z
        X,Y=to64(x,y); pts.append({"x":X,"y":Y,"label":k,"z_index":zi})
    return pts
front = d=='south'; zf = 1 if front else -1; mid=0.5
def hp(dx,y): return [(mid+dx if lsx>rsx else mid-dx, y), (mid-dx if lsx>rsx else mid+dx, y)]
# 팔꿈치는 어깨 폭 안쪽(좁게), 손은 몸 가운데
P={
 'chest': pose(hp(0.03, sh_y+0.12), hp(0.10, sh_y+0.12), zf),
 'over':  pose(hp(0.03, nose_y-0.22), hp(0.08, sh_y-0.12), 1),
 'mid':   pose(hp(0.03, nose_y+0.02), hp(0.10, sh_y+0.00), zf),
 'hips':  pose(hp(0.03, hip_y+0.04), hp(0.10, sh_y+0.16), zf),
 'low':   pose(hp(0.07, hip_y+0.03), hp(0.11, sh_y+0.15), 0),
}
# 마스크: 어깨 위 두 칸부터 엉덩이 아래까지 몸통 띠 + 머리 위 전체 (팔이 지나갈 자리). 얼굴은 남긴다
mask=Image.new('L',(64,64),0); dr=ImageDraw.Draw(mask)
hair_top=min(y for y in range(64) for x in range(64) if pad.getpixel((x,y))[3]>0)
sy=int((8+sh_y*48)); hy=int(8+hip_y*48)
dr.rectangle([0,0,63,max(0,hair_top-1)],fill=255)                    # 머리 위
dr.rectangle([0,sy-4,63,hy+5],fill=255)                              # 어깨~엉덩이 띠 (몸통 포함)
# 얼굴 가운데(눈·코)는 남긴다 — 어깨 띠가 턱에 닿지 않게 위 두 줄만
mask64=b64(mask.convert('RGBA'))
mask.save(f'skel/mask_{kind}_{d}.png')
def call(frames):
    body={"image_size":{"width":64,"height":64},"view":"low top-down","direction":d,
          "reference_image":{"type":"base64","base64":ref64},
          "inpainting_images":[{"type":"base64","base64":ref64}]*3,
          "mask_images":[{"type":"base64","base64":mask64}]*3,
          "color_image":{"type":"base64","base64":ref64},
          "skeleton_keypoints":[P[f] for f in frames],"guidance_scale":guid,"seed":seed}
    try:
        r=json.load(urllib.request.urlopen(urllib.request.Request("https://api.pixellab.ai/v2/animate-with-skeleton",data=json.dumps(body).encode(),headers=H),timeout=300))
    except urllib.error.HTTPError as e:
        print('ERR', e.code, e.read()[:800]); raise SystemExit
    return [Image.open(io.BytesIO(base64.b64decode(im['base64']))).convert('RGBA') for im in r['images']]
os.makedirs(f'skel/{tag}_{kind}_{d}',exist_ok=True)
a=call(['chest','over','mid']); b=call(['mid','hips','low'])
ims=[a[0],a[1],a[2],b[1],b[2]]
for i,im in enumerate(ims): im.save(f'skel/{tag}_{kind}_{d}/f{i}.png')
S=5; w,h=ims[0].size
sheet=Image.new('RGBA',((len(ims)+1)*(w*S+4),h*S),(40,40,48,255))
sheet.paste(pad.resize((w*S,h*S),Image.NEAREST),(0,0))
for i,im in enumerate(ims):
    big=im.resize((w*S,h*S),Image.NEAREST); sheet.paste(big,((i+1)*(w*S+4),0),big)
sheet.save(f'skel/sheet_{tag}_{kind}_{d}.png'); print('ok', tag, kind, d)
