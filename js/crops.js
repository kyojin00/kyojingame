// 작물 정의: 씨앗 가격, 판매 가격, 성장 일수
const CROPS = {
  potato: {
    name: '감자',
    icon: '🥔',
    seedPrice: 30,
    sellPrice: 80,
    growDays: 4,
    matureSprite: 'maturePotato',
  },
  carrot: {
    name: '당근',
    icon: '🥕',
    seedPrice: 40,
    sellPrice: 110,
    growDays: 5,
    matureSprite: 'matureCarrot',
  },
  strawberry: {
    name: '딸기',
    icon: '🍓',
    seedPrice: 60,
    sellPrice: 170,
    growDays: 6,
    matureSprite: 'matureStrawberry',
  },
  pumpkin: {
    name: '호박',
    icon: '🎃',
    seedPrice: 100,
    sellPrice: 320,
    growDays: 9,
    matureSprite: 'maturePumpkin',
  },
};

const CROP_IDS = Object.keys(CROPS);

// 성장 진행도에 따른 스프라이트 선택
function cropSpriteFor(cropId, day) {
  const def = CROPS[cropId];
  if (day >= def.growDays) return SPRITES[def.matureSprite];
  const t = day / def.growDays;
  if (t < 0.34) return SPRITES.cropSprout;
  if (t < 0.67) return SPRITES.cropSmall;
  return SPRITES.cropMedium;
}
