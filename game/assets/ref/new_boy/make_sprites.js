const fs=require('fs'),{PNG}=require('pngjs');
const REF='/home/user/kyojingame/game/assets/ref/new_boy/';
const OUT='/home/user/kyojingame/game/assets/sprites/';
const FW=128, FH=192;
const HAIR_TOP_Y=27;   // 앞머리 덩어리 꼭대기가 놓일 행
const HAIR_H=163;      // 앞머리 꼭대기 ~ 발바닥 (모든 방향 공통 기준)
const load=f=>PNG.sync.read(fs.readFileSync(REF+f));

// 세로로 빈 칸을 찾아 프레임을 나눈다
function columns(p){
  const {width:W,height:H,data:D}=p; const col=new Array(W).fill(0);
  for(let y=0;y<H;y++)for(let x=0;x<W;x++) if(D[((y*W+x)*4)+3]>=128) col[x]++;
  const runs=[]; let s=-1;
  for(let x=0;x<W;x++){ if(col[x]>0&&s<0)s=x; else if(col[x]===0&&s>=0){runs.push([s,x-1]);s=-1;} }
  if(s>=0) runs.push([s,W-1]);
  return runs;
}
function scan(p,x0,x1){
  const {width:W,height:H,data:D}=p; const rw=[]; let y0=-1,y1=-1;
  for(let y=0;y<H;y++){ let l=1e9,r=-1;
    for(let x=x0;x<=x1;x++) if(D[((y*W+x)*4)+3]>=128){ if(x<l)l=x; if(x>r)r=x; }
    rw[y]=r<0?0:r-l+1; if(r>=0){ if(y0<0)y0=y; y1=y; } }
  const maxW=Math.max(...rw);
  let hairTop=y0; for(let y=y0;y<=y1;y++) if(rw[y]>=maxW*0.55){ hairTop=y; break; }
  return {y0,y1,hairTop,hairH:y1-hairTop+1};
}
// 허리(반바지) 띠의 무게중심 x — 걷는 동안 가장 덜 흔들리는 기준점
function hipX(p,x0,x1,m){
  const {width:W,data:D}=p; const a=m.hairTop+Math.round(m.hairH*0.60), b=m.hairTop+Math.round(m.hairH*0.72);
  let sx=0,n=0;
  for(let y=a;y<=b;y++)for(let x=x0;x<=x1;x++) if(D[((y*W+x)*4)+3]>=128){ sx+=x; n++; }
  return n?sx/n:(x0+x1)/2;
}
function sample(p,x0,x1,ax,ay,s,tx,ty){
  const {width:W,height:H,data:D}=p;
  const sx0=ax+(tx-64)/s, sx1=ax+(tx+1-64)/s;
  const sy0=ay+(ty-HAIR_TOP_Y)/s, sy1=ay+(ty+1-HAIR_TOP_Y)/s;
  const ix0=Math.max(x0,Math.floor(sx0)), ix1=Math.min(x1,Math.ceil(sx1)-1);
  const iy0=Math.max(0,Math.floor(sy0)), iy1=Math.min(H-1,Math.ceil(sy1)-1);
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
function render(p,x0,x1,ax,ay,s){
  const px=[]; for(let ty=0;ty<FH;ty++)for(let tx=0;tx<FW;tx++) px.push(sample(p,x0,x1,ax,ay,s,tx,ty));
  return px;
}

const jobs=[];
function addSheet(file,names){
  const p=load(file), runs=columns(p);
  if(runs.length!==names.length) throw new Error(file+' 프레임 수 '+runs.length);
  const ms=runs.map(r=>scan(p,r[0],r[1]));
  const s=HAIR_H/Math.max(...ms.map(m=>m.hairH));       // 시트 안에서 한 배율
  runs.forEach((r,i)=>jobs.push({name:names[i],px:render(p,r[0],r[1],hipX(p,r[0],r[1],ms[i]),ms[i].hairTop,s)}));
}
function addOne(file,name){
  const p=load(file), m=scan(p,0,p.width-1), s=HAIR_H/m.hairH;
  jobs.push({name,px:render(p,0,p.width-1,hipX(p,0,p.width-1,m),m.hairTop,s)});
}
addOne('front_idle.png','new_boy_down_idle');
addOne('back_idle.png','new_boy_up_idle');
addOne('side_idle.png','new_boy_side_idle');
addSheet('walk_src.png',[0,1,2,3].map(i=>'new_boy_down_walk_'+i));
addSheet('side_walk_src.png',[0,1,2,3].map(i=>'new_boy_side_walk_'+i));
addSheet('back_walk_src.png',[0,1,2,3].map(i=>'new_boy_up_walk_'+i));

// 15장이 같은 색을 쓰도록 팔레트를 한 번에 줄인다
const all=[]; jobs.forEach(j=>j.px.forEach(c=>{ if(c) all.push(c); }));
const seen=new Map();
for(const c of all){ const k=(c[0]>>3)+','+(c[1]>>3)+','+(c[2]>>3); seen.set(k,(seen.get(k)||0)+1); }
let cent=[...seen.entries()].sort((a,b)=>b[1]-a[1]).slice(0,28).map(([k])=>k.split(',').map(v=>parseInt(v)*8+4));
for(let it=0;it<30;it++){
  const acc=cent.map(()=>[0,0,0,0]);
  for(const c of all){ let bi=0,bd=1e18;
    for(let i=0;i<cent.length;i++){ const d=(c[0]-cent[i][0])**2+(c[1]-cent[i][1])**2+(c[2]-cent[i][2])**2; if(d<bd){bd=d;bi=i;} }
    acc[bi][0]+=c[0];acc[bi][1]+=c[1];acc[bi][2]+=c[2];acc[bi][3]++; }
  for(let i=0;i<cent.length;i++) if(acc[i][3]) cent[i]=[0,1,2].map(j=>Math.round(acc[i][j]/acc[i][3]));
}
const snap=c=>{ let bi=0,bd=1e18; for(let i=0;i<cent.length;i++){ const d=(c[0]-cent[i][0])**2+(c[1]-cent[i][1])**2+(c[2]-cent[i][2])**2; if(d<bd){bd=d;bi=i;} } return cent[bi]; };

const imgs={};
for(const j of jobs){
  const o=new PNG({width:FW,height:FH}); o.data.fill(0);
  for(let i=0;i<FW*FH;i++){ const c=j.px[i]; if(!c) continue; const q=snap(c);
    o.data[i*4]=q[0];o.data[i*4+1]=q[1];o.data[i*4+2]=q[2];o.data[i*4+3]=255; }
  fs.writeFileSync(OUT+j.name+'.png',PNG.sync.write(o)); imgs[j.name]=o;
}
function preview(name,list){
  const Z=3,w=FW*list.length*Z,h=FH*Z,pv=new PNG({width:w,height:h});
  for(let y=0;y<h;y++)for(let x=0;x<w;x++){
    const im=imgs[list[Math.floor(x/Z/FW)]], sx=Math.floor(x/Z)%FW, sy=Math.floor(y/Z), si=(sy*FW+sx)*4;
    const di=(y*w+x)*4, chk=((Math.floor(x/Z/8)+Math.floor(y/Z/8))%2)?58:38, a=im.data[si+3];
    pv.data[di]=a?im.data[si]:chk; pv.data[di+1]=a?im.data[si+1]:chk; pv.data[di+2]=a?im.data[si+2]:chk; pv.data[di+3]=255;
  }
  fs.writeFileSync(REF+name,PNG.sync.write(pv));
}
preview('preview_idle.png',['new_boy_down_idle','new_boy_side_idle','new_boy_up_idle']);
preview('preview_walk.png',[0,1,2,3].map(i=>'new_boy_down_walk_'+i));
preview('preview_side_walk.png',[0,1,2,3].map(i=>'new_boy_side_walk_'+i));
preview('preview_up_walk.png',[0,1,2,3].map(i=>'new_boy_up_walk_'+i));
console.log('frames',jobs.length,'palette',cent.length);
