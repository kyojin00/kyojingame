// 오래된 책 — 풀숲에 반쯤 묻힌 낡은 가죽 장정 책 (32x32 도트).
// 메인 스토리 6의 발견 오브젝트 겸 아이템 아이콘.
const fs = require('fs'), { PNG } = require('pngjs');
const S = 32;
const out = new PNG({ width: S, height: S });
function px(x, y, r, g, b, a = 255) {
  if (x < 0 || y < 0 || x >= S || y >= S) return;
  const i = (y * S + x) * 4;
  out.data[i] = r; out.data[i+1] = g; out.data[i+2] = b; out.data[i+3] = a;
}
function rect(x0, y0, w, h, r, g, b) {
  for (let y = y0; y < y0 + h; y++)
    for (let x = x0; x < x0 + w; x++) px(x, y, r, g, b);
}
// 비스듬히 놓인 책: 표지(낡은 밤색 가죽) + 책배(누런 종이) + 띠(청록 헝겊)
rect(5, 12, 22, 13, 74, 46, 30);        // 표지 밑판 (그림자 톤)
rect(6, 11, 20, 12, 104, 64, 38);       // 표지
rect(6, 11, 20, 3, 122, 78, 46);        // 표지 윗면 하이라이트
rect(8, 23, 18, 3, 226, 208, 160);      // 책배 (종이 단면)
for (let x = 8; x < 26; x += 2) px(x, 24, 196, 178, 132);  // 종이 결
rect(13, 10, 4, 15, 32, 84, 88);        // 띠 (청록 헝겊)
rect(13, 10, 4, 2, 52, 112, 112);
rect(6, 10, 20, 1, 58, 36, 22);         // 윗 테두리
rect(5, 25, 22, 1, 46, 28, 18);         // 아랫 테두리
// 모서리 금속 장식 (닳아서 어둡다)
rect(6, 11, 2, 2, 150, 128, 70); rect(24, 11, 2, 2, 150, 128, 70);
rect(6, 21, 2, 2, 120, 100, 56); rect(24, 21, 2, 2, 120, 100, 56);
// 반쯤 덮은 풀잎
px(4, 24, 84, 128, 60); px(5, 23, 96, 142, 66); px(5, 22, 84, 128, 60);
px(27, 23, 84, 128, 60); px(28, 24, 96, 142, 66); px(27, 25, 74, 112, 52);
px(26, 10, 84, 128, 60); px(27, 11, 96, 142, 66);
fs.writeFileSync(__dirname + '/../sprites/old_book.png', PNG.sync.write(out));
console.log('old_book.png 32x32 완료');
