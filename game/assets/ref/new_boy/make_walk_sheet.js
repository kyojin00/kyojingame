const fs=require('fs'),{PNG}=require('pngjs');
const src=PNG.sync.read(fs.readFileSync('/home/user/kyojingame/new4.png'));
const {width:W,height:H,data:D}=src;
const A=(x,y)=>D[((y*W+x)*4)+3];
const RUNS=[[28,363],[414,746],[795,1129],[1181,1514]];
const TOP=130, BOT=888;                 // 네 프레임 공통 머리 꼭대기 / 가장 낮은 발
const FW=48, FH=48, CHAR_H=46;          // 출력 프레임 / 캐릭터 높이
const s=CHAR_H/(BOT-TOP+1);             // 축소 배율 (네 프레임 공통)
const ROW_TOP=FH-1-CHAR_H+1;            // 머리 꼭대기가 놓일 출력 행 = 2

// 프레임별 머리 중심 x (좌우 흔들림 없이 몸통 축을 고정한다)
function headX([x0,x1]){
  const hEnd=TOP+Math.round((BOT-TOP)*0.22);
  let sx=0,n=0;
  for(let y=TOP;y<=hEnd;y++)for(let x=x0;x<=x1;x++)if(A(x,y)>=128){sx+=x;n++;}
  return sx/n;
}

// 출력 픽셀 하나 = 원본 박스 하나. 색은 굵은 버킷의 최빈색(평균)으로 뽑아
// 안티에일리어싱 없이 도트의 단색 면을 그대로 살린다.
function samplePixel(x0,x1,hx,tx,ty){
  const sx0=hx+(tx-FW/2)/s, sx1=hx+(tx+1-FW/2)/s;
  const sy0=TOP+(ty-ROW_TOP)/s, sy1=TOP+(ty+1-ROW_TOP)/s;
  const ix0=Math.max(x0,Math.floor(sx0)), ix1=Math.min(x1,Math.ceil(sx1)-1);
  const iy0=Math.max(0,Math.floor(sy0)), iy1=Math.min(H-1,Math.ceil(sy1)-1);
  let tot=0,op=0; const bucket={};
  for(let y=iy0;y<=iy1;y++)for(let x=ix0;x<=ix1;x++){
    tot++;
    const i=(y*W+x)*4;
    if(D[i+3]<128) continue;
    op++;
    const k=((D[i]>>4)<<8)|((D[i+1]>>4)<<4)|(D[i+2]>>4);
    const b=bucket[k]||(bucket[k]=[0,0,0,0]);
    b[0]+=D[i];b[1]+=D[i+1];b[2]+=D[i+2];b[3]++;
  }
  if(tot===0||op/tot<0.5) return null;
  let best=null;
  for(const k in bucket) if(!best||bucket[k][3]>best[3]) best=bucket[k];
  return [Math.round(best[0]/best[3]),Math.round(best[1]/best[3]),Math.round(best[2]/best[3])];
}

const frames=RUNS.map((r,fi)=>{
  const hx=headX(r);
  const px=[];
  for(let ty=0;ty<FH;ty++)for(let tx=0;tx<FW;tx++) px.push(samplePixel(r[0],r[1],hx,tx,ty));
  return px;
});

// 네 프레임이 같은 색을 쓰도록 팔레트를 한 번에 줄인다 (k-means)
const all=[]; frames.forEach(f=>f.forEach(c=>{if(c)all.push(c);}));
let cent=[]; {
  const seen=new Map();
  for(const c of all){const k=(c[0]>>3)+','+(c[1]>>3)+','+(c[2]>>3);seen.set(k,(seen.get(k)||0)+1);}
  const top=[...seen.entries()].sort((a,b)=>b[1]-a[1]).slice(0,22);
  cent=top.map(([k])=>k.split(',').map(v=>parseInt(v)*8+4));
}
for(let it=0;it<24;it++){
  const acc=cent.map(()=>[0,0,0,0]);
  for(const c of all){
    let bi=0,bd=1e18;
    for(let i=0;i<cent.length;i++){const d=(c[0]-cent[i][0])**2+(c[1]-cent[i][1])**2+(c[2]-cent[i][2])**2;if(d<bd){bd=d;bi=i;}}
    acc[bi][0]+=c[0];acc[bi][1]+=c[1];acc[bi][2]+=c[2];acc[bi][3]++;
  }
  for(let i=0;i<cent.length;i++) if(acc[i][3]) cent[i]=[0,1,2].map(j=>Math.round(acc[i][j]/acc[i][3]));
}
const snap=c=>{let bi=0,bd=1e18;for(let i=0;i<cent.length;i++){const d=(c[0]-cent[i][0])**2+(c[1]-cent[i][1])**2+(c[2]-cent[i][2])**2;if(d<bd){bd=d;bi=i;}}return cent[bi];};

const out=new PNG({width:FW*4,height:FH});
out.data.fill(0);
frames.forEach((f,fi)=>{
  for(let ty=0;ty<FH;ty++)for(let tx=0;tx<FW;tx++){
    const c=f[ty*FW+tx]; if(!c) continue;
    const q=snap(c), i=((ty*FW*4)+(fi*FW+tx))*4;
    out.data[i]=q[0];out.data[i+1]=q[1];out.data[i+2]=q[2];out.data[i+3]=255;
  }
});
fs.writeFileSync('new_walk_sheet.png',PNG.sync.write(out));

// 확대 미리보기
const Z=10,pv=new PNG({width:FW*4*Z,height:FH*Z});
for(let y=0;y<FH*Z;y++)for(let x=0;x<FW*4*Z;x++){
  const si=((Math.floor(y/Z))*FW*4+Math.floor(x/Z))*4, di=(y*FW*4*Z+x)*4;
  const a=out.data[si+3];
  const chk=((Math.floor(x/Z/4)+Math.floor(y/Z/4))%2)?60:40;
  pv.data[di]=a?out.data[si]:chk;pv.data[di+1]=a?out.data[si+1]:chk;pv.data[di+2]=a?out.data[si+2]:chk;pv.data[di+3]=255;
}
fs.writeFileSync('new_walk_preview.png',PNG.sync.write(pv));
console.log('scale',s.toFixed(4),'headX',RUNS.map(r=>headX(r).toFixed(1)).join(' '),'palette',cent.length);
