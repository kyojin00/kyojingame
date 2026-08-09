const fs=require('fs'),{PNG}=require('pngjs');
const B='/home/user/kyojingame/game/assets/ref/new_boy/';
const OUT='/home/user/kyojingame/game/assets/sprites/';
const FW=128, FH=192;          // 게임의 기존 캐릭터 규격과 동일
const FOOT_Y=190;              // 발이 놓이는 행
const HAIR_H=163;              // 머리(앞머리 덩어리) 꼭대기 -> 발바닥 = 공통 기준 높이
const load=f=>PNG.sync.read(fs.readFileSync(B+f));

function scan(p,x0,x1){
  const {width:W,height:H,data:D}=p; x0=x0??0; x1=x1??W-1;
  const rw=[]; let y0=-1,y1=-1;
  for(let y=0;y<H;y++){let l=1e9,r=-1;
    for(let x=x0;x<=x1;x++) if(D[((y*W+x)*4)+3]>=128){if(x<l)l=x;if(x>r)r=x;}
    rw[y]=r<0?0:r-l+1; if(r>=0){if(y0<0)y0=y;y1=y;}}
  const maxW=Math.max(...rw);
  let hairTop=y0; for(let y=y0;y<=y1;y++) if(rw[y]>=maxW*0.55){hairTop=y;break;}
  return {y0,y1,hairTop,hairH:y1-hairTop+1};
}
// 무게중심 x (rows 구간)
function cx(p,x0,x1,ya,yb){
  const {width:W,data:D}=p; let sx=0,n=0;
  for(let y=ya;y<=yb;y++)for(let x=x0;x<=x1;x++) if(D[((y*W+x)*4)+3]>=128){sx+=x;n++;}
  return n?sx/n:(x0+x1)/2;
}
// 원본 박스 하나 -> 출력 픽셀 하나 (굵은 버킷의 최빈색). 안티에일리어싱 없음.
function sample(p,x0,x1,ax,ay,s,tx,ty,anchorX){
  const {width:W,height:H,data:D}=p;
  const sx0=ax+(tx-anchorX)/s, sx1=ax+(tx+1-anchorX)/s;
  const sy0=ay+(ty-FOOT_Y)/s,  sy1=ay+(ty+1-FOOT_Y)/s;
  const ix0=Math.max(x0,Math.floor(sx0)), ix1=Math.min(x1,Math.ceil(sx1)-1);
  const iy0=Math.max(0,Math.floor(sy0)),  iy1=Math.min(H-1,Math.ceil(sy1)-1);
  let tot=0,op=0; const bk={};
  for(let y=iy0;y<=iy1;y++)for(let x=ix0;x<=ix1;x++){
    tot++; const i=(y*W+x)*4; if(D[i+3]<128) continue; op++;
    const k=((D[i]>>4)<<8)|((D[i+1]>>4)<<4)|(D[i+2]>>4);
    const b=bk[k]||(bk[k]=[0,0,0,0]); b[0]+=D[i];b[1]+=D[i+1];b[2]+=D[i+2];b[3]++;
  }
  if(tot===0||op/tot<0.5) return null;
  let best=null; for(const k in bk) if(!best||bk[k][3]>best[3]) best=bk[k];
  return [Math.round(best[0]/best[3]),Math.round(best[1]/best[3]),Math.round(best[2]/best[3])];
}
function render(p,x0,x1,ax,ay,s,anchorX){
  const px=[]; for(let ty=0;ty<FH;ty++)for(let tx=0;tx<FW;tx++) px.push(sample(p,x0,x1,ax,ay,s,tx,ty,anchorX));
  return px;
}

const jobs=[];
// ---- 서기 3종: 발 무게중심을 x 64에 맞춘다 ----
for(const [file,name] of [['front_idle.png','new_boy_down_idle'],['back_idle.png','new_boy_up_idle'],['side_idle.png','new_boy_side_idle']]){
  const p=load(file), m=scan(p), s=HAIR_H/m.hairH;
  const footTop=m.y1-Math.round((m.y1-m.y0)*0.08);
  jobs.push({name,px:render(p,0,p.width-1,cx(p,0,p.width-1,footTop,m.y1),m.y1,s,64)});
}
// ---- 걷기 4프레임: 한 배율/한 바닥선, 머리 중심을 x 64에 고정 ----
const wp=load('walk_src.png'), RUNS=[[28,363],[414,746],[795,1129],[1181,1514]];
const w0=scan(wp,RUNS[0][0],RUNS[0][1]);
const ws=HAIR_H/w0.hairH, groundY=w0.y1;
const walk=RUNS.map((r,i)=>{
  const m=scan(wp,r[0],r[1]);
  const headBot=m.y0+Math.round((m.y1-m.y0)*0.15);
  return render(wp,r[0],r[1],cx(wp,r[0],r[1],m.y0,headBot),groundY,ws,64);
});
walk.forEach((px,i)=>jobs.push({name:'new_boy_down_walk_'+i,px}));

// ---- 모든 그림이 같은 색을 쓰도록 팔레트를 한 번에 줄인다 (k-means) ----
const all=[]; jobs.forEach(j=>j.px.forEach(c=>{if(c)all.push(c);}));
const seen=new Map();
for(const c of all){const k=(c[0]>>3)+','+(c[1]>>3)+','+(c[2]>>3); seen.set(k,(seen.get(k)||0)+1);}
let cent=[...seen.entries()].sort((a,b)=>b[1]-a[1]).slice(0,26).map(([k])=>k.split(',').map(v=>parseInt(v)*8+4));
for(let it=0;it<30;it++){
  const acc=cent.map(()=>[0,0,0,0]);
  for(const c of all){let bi=0,bd=1e18;
    for(let i=0;i<cent.length;i++){const d=(c[0]-cent[i][0])**2+(c[1]-cent[i][1])**2+(c[2]-cent[i][2])**2;if(d<bd){bd=d;bi=i;}}
    acc[bi][0]+=c[0];acc[bi][1]+=c[1];acc[bi][2]+=c[2];acc[bi][3]++;}
  for(let i=0;i<cent.length;i++) if(acc[i][3]) cent[i]=[0,1,2].map(j=>Math.round(acc[i][j]/acc[i][3]));
}
const snap=c=>{let bi=0,bd=1e18;for(let i=0;i<cent.length;i++){const d=(c[0]-cent[i][0])**2+(c[1]-cent[i][1])**2+(c[2]-cent[i][2])**2;if(d<bd){bd=d;bi=i;}}return cent[bi];};

function write(name,px){
  const o=new PNG({width:FW,height:FH}); o.data.fill(0);
  for(let i=0;i<FW*FH;i++){const c=px[i]; if(!c) continue; const q=snap(c);
    o.data[i*4]=q[0];o.data[i*4+1]=q[1];o.data[i*4+2]=q[2];o.data[i*4+3]=255;}
  fs.writeFileSync(OUT+name+'.png',PNG.sync.write(o)); return o;
}
const imgs={}; jobs.forEach(j=>imgs[j.name]=write(j.name,j.px));

// ---- 걷기 4프레임 가로 시트 (512x192) ----
const sheet=new PNG({width:FW*4,height:FH}); sheet.data.fill(0);
for(let f=0;f<4;f++){const src=imgs['new_boy_down_walk_'+f];
  for(let y=0;y<FH;y++)for(let x=0;x<FW;x++){
    const si=(y*FW+x)*4, di=(y*FW*4+f*FW+x)*4;
    for(let k=0;k<4;k++) sheet.data[di+k]=src.data[si+k];}}
fs.writeFileSync(OUT+'new_walk_sheet.png',PNG.sync.write(sheet));

// ---- 미리보기 ----
function preview(name,list,cols){
  const Z=3,w=FW*cols*Z,h=FH*Math.ceil(list.length/cols)*Z;
  const pv=new PNG({width:w,height:h});
  for(let y=0;y<h;y++)for(let x=0;x<w;x++){
    const cxx=Math.floor(x/Z/FW), cyy=Math.floor(y/Z/FH), idx=cyy*cols+cxx;
    const di=(y*w+x)*4, chk=((Math.floor(x/Z/8)+Math.floor(y/Z/8))%2)?58:38;
    let r=chk,g=chk,b=chk;
    if(idx<list.length){const im=imgs[list[idx]], sx=Math.floor(x/Z)%FW, sy=Math.floor(y/Z)%FH, si=(sy*FW+sx)*4;
      if(im.data[si+3]){r=im.data[si];g=im.data[si+1];b=im.data[si+2];}}
    pv.data[di]=r;pv.data[di+1]=g;pv.data[di+2]=b;pv.data[di+3]=255;}
  fs.writeFileSync(B+name,PNG.sync.write(pv));
}
preview('preview_walk.png',['new_boy_down_walk_0','new_boy_down_walk_1','new_boy_down_walk_2','new_boy_down_walk_3'],4);
preview('preview_idle.png',['new_boy_down_idle','new_boy_side_idle','new_boy_up_idle'],3);
console.log('walk scale',ws.toFixed(4),'palette',cent.length,'files',jobs.length);
