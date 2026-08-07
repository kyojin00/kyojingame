// 교진 팜 - 메인 게임 로직
(function () {
  'use strict';

  const canvas = document.getElementById('game');
  const ctx = canvas.getContext('2d');

  // ---- 상수 ----
  const MAP_W = 30;          // 타일 수 (가로)
  const MAP_H = 20;          // 타일 수 (세로)
  const TILE = 32;           // 타일 하나의 캔버스 픽셀 크기
  const PX = TILE / 16;      // 아트 1픽셀 = 캔버스 2픽셀
  const SAVE_KEY = 'kyojin-farm-save-v1';

  const DAY_START = 6 * 60;    // 오전 6시
  const DAY_END = 26 * 60;     // 새벽 2시(다음날)에 강제 취침
  const MIN_PER_SEC = 10 / 7;  // 실제 7초 = 게임 10분

  const ENERGY_MAX = 100;
  const ENERGY_COST = { hoe: 2, water: 1, seed: 1, hand: 1 };

  // ---- 게임 상태 ----
  const state = {
    day: 1,
    minutes: DAY_START,
    money: 500,
    energy: ENERGY_MAX,
    tool: 'hoe',
    seedIndex: 0, // CROP_IDS 인덱스
    seeds: { potato: 5, carrot: 0, strawberry: 0, pumpkin: 0 },
    produce: { potato: 0, carrot: 0, strawberry: 0, pumpkin: 0 },
    paused: false,
  };

  // 타일: { ground: 'grass'|'soil'|'water', watered: bool, crop: {id, day} | null }
  let grid = [];
  // 장애물/오브젝트: 키 "x,y" -> 'tree'|'rock'|'house'|'bin'
  let objects = {};

  const player = {
    x: 10 * TILE + TILE / 2, // 발 밑 중심 좌표
    y: 9 * TILE + TILE / 2,
    dir: 'down',
    moving: false,
    animTime: 0,
    speed: 150, // px/sec
  };

  // ---- 맵 생성 ----
  function buildMap() {
    grid = [];
    objects = {};
    for (let y = 0; y < MAP_H; y++) {
      const row = [];
      for (let x = 0; x < MAP_W; x++) {
        row.push({ ground: 'grass', watered: false, crop: null });
      }
      grid.push(row);
    }

    // 연못 (오른쪽 아래)
    for (let y = 13; y <= 17; y++) {
      for (let x = 23; x <= 27; x++) {
        grid[y][x].ground = 'water';
      }
    }

    // 집 (왼쪽 위, 2..6 x 1..4)
    for (let y = 1; y <= 4; y++) {
      for (let x = 2; x <= 6; x++) {
        objects[x + ',' + y] = 'house';
      }
    }

    // 출하 상자
    objects['9,4'] = 'bin';

    // 테두리 나무 울타리 (집 주변 제외)
    for (let x = 0; x < MAP_W; x++) {
      if (tileHash(x, 0) < 0.75 && !objects[x + ',0']) objects[x + ',0'] = 'tree';
      if (tileHash(x, MAP_H - 1) < 0.75) objects[x + ',' + (MAP_H - 1)] = 'tree';
    }
    for (let y = 0; y < MAP_H; y++) {
      if (tileHash(0, y) < 0.75 && !objects['0,' + y]) objects['0,' + y] = 'tree';
      if (tileHash(MAP_W - 1, y) < 0.75 && !objects[(MAP_W - 1) + ',' + y]) {
        objects[(MAP_W - 1) + ',' + y] = 'tree';
      }
    }

    // 흩어진 나무/돌
    const decor = [
      [12, 2, 'tree'], [18, 3, 'tree'], [24, 2, 'tree'], [21, 7, 'tree'],
      [3, 12, 'tree'], [5, 16, 'tree'], [16, 16, 'rock'], [8, 8, 'rock'],
      [19, 12, 'rock'], [26, 8, 'rock'], [13, 6, 'rock'],
    ];
    for (const [x, y, kind] of decor) {
      if (!objects[x + ',' + y] && grid[y][x].ground === 'grass') {
        objects[x + ',' + y] = kind;
      }
    }
  }

  // ---- 유틸 ----
  function inBounds(tx, ty) {
    return tx >= 0 && ty >= 0 && tx < MAP_W && ty < MAP_H;
  }

  function isPassable(tx, ty) {
    if (!inBounds(tx, ty)) return false;
    if (grid[ty][tx].ground === 'water') return false;
    if (objects[tx + ',' + ty]) return false;
    return true;
  }

  function playerTile() {
    return { x: Math.floor(player.x / TILE), y: Math.floor(player.y / TILE) };
  }

  function targetTile() {
    const p = playerTile();
    const d = { down: [0, 1], up: [0, -1], left: [-1, 0], right: [1, 0] }[player.dir];
    return { x: p.x + d[0], y: p.y + d[1] };
  }

  let msgTimer = null;
  function showMessage(text) {
    const el = document.getElementById('message');
    el.textContent = text;
    el.classList.add('show');
    clearTimeout(msgTimer);
    msgTimer = setTimeout(() => el.classList.remove('show'), 2000);
  }

  function currentSeedId() {
    return CROP_IDS[state.seedIndex];
  }

  // ---- 도구 사용 ----
  function useTool() {
    const t = targetTile();
    if (!inBounds(t.x, t.y)) return;
    const tile = grid[t.y][t.x];
    const obj = objects[t.x + ',' + t.y];
    const cost = ENERGY_COST[state.tool] || 0;

    if (state.energy < cost) {
      showMessage('너무 지쳤다... 자러 가야 할 것 같다.');
      return;
    }

    switch (state.tool) {
      case 'hoe':
        if (obj) { showMessage('여기는 갈 수 없다.'); return; }
        if (tile.ground === 'grass') {
          tile.ground = 'soil';
          state.energy -= cost;
        } else if (tile.ground === 'soil' && !tile.crop) {
          tile.ground = 'grass';
          tile.watered = false;
          state.energy -= cost;
        }
        break;

      case 'water':
        if (tile.ground === 'soil') {
          if (!tile.watered) {
            tile.watered = true;
            state.energy -= cost;
          }
        } else {
          showMessage('물을 줄 곳이 아니다.');
        }
        break;

      case 'seed': {
        const id = currentSeedId();
        if (tile.ground !== 'soil') { showMessage('먼저 호미로 밭을 갈자.'); return; }
        if (tile.crop) { showMessage('이미 작물이 자라고 있다.'); return; }
        if (state.seeds[id] <= 0) { showMessage(CROPS[id].name + ' 씨앗이 없다. 상점(B)에서 사자.'); return; }
        state.seeds[id]--;
        tile.crop = { id: id, day: 0 };
        state.energy -= cost;
        break;
      }

      case 'hand':
        if (tile.crop && tile.crop.day >= CROPS[tile.crop.id].growDays) {
          const def = CROPS[tile.crop.id];
          state.produce[tile.crop.id]++;
          tile.crop = null;
          state.energy -= cost;
          showMessage(def.icon + ' ' + def.name
            + ' 수확! (판매가 ' + def.sellPrice + 'G)');
        } else if (tile.crop) {
          showMessage('아직 다 자라지 않았다.');
        }
        break;
    }
    syncHud();
  }

  // ---- 상호작용 (E) ----
  function interact() {
    const t = targetTile();
    const p = playerTile();
    const candidates = [t, p];
    for (const c of candidates) {
      const obj = objects[c.x + ',' + c.y];
      if (obj === 'bin') { openShop('sell'); return; }
      if (obj === 'house') { openSleepModal(); return; }
    }
    showMessage('집 문 앞에서 E: 취침 · 출하 상자 앞에서 E: 판매');
  }

  // ---- 하루 넘기기 ----
  function nextDay(passedOut) {
    for (let y = 0; y < MAP_H; y++) {
      for (let x = 0; x < MAP_W; x++) {
        const tile = grid[y][x];
        if (tile.crop && tile.watered) tile.crop.day++;
        tile.watered = false;
      }
    }
    state.day++;
    state.minutes = DAY_START;
    state.energy = passedOut ? Math.floor(ENERGY_MAX * 0.5) : ENERGY_MAX;
    saveGame(true);
    showMessage(passedOut
      ? '쓰러진 채 아침을 맞았다... 기력이 절반만 회복됐다.'
      : state.day + '일차 아침. 상쾌하다!');
    syncHud();
  }

  // ---- 시간 ----
  function tickTime(dt) {
    state.minutes += dt * MIN_PER_SEC;
    if (state.minutes >= DAY_END) {
      closeAllModals();
      nextDay(true);
    }
  }

  function clockText() {
    let m = Math.floor(state.minutes);
    let h = Math.floor(m / 60) % 24;
    const mm = m % 60;
    const ampm = h < 12 ? '오전' : '오후';
    let h12 = h % 12;
    if (h12 === 0) h12 = 12;
    return ampm + ' ' + h12 + ':' + String(Math.floor(mm / 10) * 10).padStart(2, '0');
  }

  // ---- HUD ----
  function syncHud() {
    document.getElementById('hud-day').textContent = state.day + '일차 (봄)';
    document.getElementById('hud-clock').textContent = clockText();
    document.getElementById('hud-money').textContent = state.money + 'G';
    document.getElementById('energy-fill').style.width =
      Math.max(0, (state.energy / ENERGY_MAX) * 100) + '%';

    document.querySelectorAll('.tool-slot').forEach((el) => {
      el.classList.toggle('active', el.dataset.tool === state.tool);
    });
    const seedId = currentSeedId();
    document.getElementById('seed-name').textContent = CROPS[seedId].name + ' 씨앗';
    document.getElementById('seed-count').textContent = state.seeds[seedId];
  }

  // ---- 상점 ----
  let shopTab = 'buy';

  function openShop(tab) {
    shopTab = tab || 'buy';
    state.paused = true;
    document.getElementById('shop-modal').classList.remove('hidden');
    renderShop();
  }

  function closeShop() {
    document.getElementById('shop-modal').classList.add('hidden');
    state.paused = false;
  }

  function renderShop() {
    document.querySelectorAll('.shop-tab').forEach((el) => {
      el.classList.toggle('active', el.dataset.tab === shopTab);
    });
    const list = document.getElementById('shop-list');
    list.innerHTML = '';

    if (shopTab === 'buy') {
      for (const id of CROP_IDS) {
        const def = CROPS[id];
        const item = document.createElement('div');
        item.className = 'shop-item';
        item.innerHTML =
          '<div class="shop-item-icon">' + def.icon + '</div>' +
          '<div class="shop-item-info">' +
            '<div class="shop-item-name">' + def.name + ' 씨앗 (보유 ' + state.seeds[id] + ')</div>' +
            '<div class="shop-item-desc">성장 ' + def.growDays + '일 · 판매가 ' + def.sellPrice + 'G</div>' +
          '</div>' +
          '<div class="shop-item-price">' + def.seedPrice + 'G</div>';
        const btn = document.createElement('button');
        btn.textContent = '구매';
        btn.disabled = state.money < def.seedPrice;
        btn.addEventListener('click', () => {
          if (state.money < def.seedPrice) return;
          state.money -= def.seedPrice;
          state.seeds[id]++;
          syncHud();
          renderShop();
        });
        item.appendChild(btn);
        list.appendChild(item);
      }
    } else {
      let any = false;
      for (const id of CROP_IDS) {
        const count = state.produce[id];
        if (count <= 0) continue;
        any = true;
        const def = CROPS[id];
        const item = document.createElement('div');
        item.className = 'shop-item';
        item.innerHTML =
          '<div class="shop-item-icon">' + def.icon + '</div>' +
          '<div class="shop-item-info">' +
            '<div class="shop-item-name">' + def.name + ' × ' + count + '</div>' +
            '<div class="shop-item-desc">개당 ' + def.sellPrice + 'G</div>' +
          '</div>' +
          '<div class="shop-item-price">' + (def.sellPrice * count) + 'G</div>';
        const btn = document.createElement('button');
        btn.textContent = '전부 판매';
        btn.addEventListener('click', () => {
          state.money += def.sellPrice * state.produce[id];
          state.produce[id] = 0;
          syncHud();
          renderShop();
        });
        item.appendChild(btn);
        list.appendChild(item);
      }
      if (!any) {
        list.innerHTML = '<div class="shop-empty">팔 수 있는 작물이 없다.<br>수확한 작물이 여기에 표시된다.</div>';
      }
    }
  }

  // ---- 취침 ----
  function openSleepModal() {
    state.paused = true;
    document.getElementById('sleep-modal').classList.remove('hidden');
  }

  function closeSleepModal() {
    document.getElementById('sleep-modal').classList.add('hidden');
    state.paused = false;
  }

  function closeAllModals() {
    closeShop();
    closeSleepModal();
  }

  // ---- 저장/불러오기 ----
  function saveGame(silent) {
    const data = {
      day: state.day,
      minutes: state.minutes,
      money: state.money,
      energy: state.energy,
      seeds: state.seeds,
      produce: state.produce,
      player: { x: player.x, y: player.y, dir: player.dir },
      grid: grid.map((row) => row.map((t) => ({
        g: t.ground, w: t.watered ? 1 : 0,
        c: t.crop ? { i: t.crop.id, d: t.crop.day } : 0,
      }))),
    };
    try {
      localStorage.setItem(SAVE_KEY, JSON.stringify(data));
      if (!silent) showMessage('저장했다!');
    } catch (e) {
      if (!silent) showMessage('저장에 실패했다.');
    }
  }

  function loadGame() {
    let raw;
    try { raw = localStorage.getItem(SAVE_KEY); } catch (e) { return false; }
    if (!raw) return false;
    try {
      const data = JSON.parse(raw);
      state.day = data.day;
      state.minutes = data.minutes;
      state.money = data.money;
      state.energy = data.energy;
      Object.assign(state.seeds, data.seeds);
      Object.assign(state.produce, data.produce);
      player.x = data.player.x;
      player.y = data.player.y;
      player.dir = data.player.dir;
      for (let y = 0; y < MAP_H; y++) {
        for (let x = 0; x < MAP_W; x++) {
          const s = data.grid[y][x];
          const t = grid[y][x];
          // 물/장애물 배치는 buildMap 결과를 유지하고 경작 상태만 복원
          if (t.ground !== 'water') t.ground = s.g === 'water' ? t.ground : s.g;
          t.watered = !!s.w;
          t.crop = s.c ? { id: s.c.i, day: s.c.d } : null;
        }
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  // ---- 입력 ----
  const keys = {};

  window.addEventListener('keydown', (e) => {
    const shopOpen = !document.getElementById('shop-modal').classList.contains('hidden');
    const sleepOpen = !document.getElementById('sleep-modal').classList.contains('hidden');

    if (e.key === 'Escape') {
      if (shopOpen || sleepOpen) { closeAllModals(); e.preventDefault(); }
      return;
    }
    if (shopOpen || sleepOpen) return;

    keys[e.key.toLowerCase()] = true;

    switch (e.key.toLowerCase()) {
      case '1': state.tool = 'hoe'; syncHud(); break;
      case '2': state.tool = 'water'; syncHud(); break;
      case '3': state.tool = 'seed'; syncHud(); break;
      case '4': state.tool = 'hand'; syncHud(); break;
      case 'tab':
        e.preventDefault();
        state.seedIndex = (state.seedIndex + 1) % CROP_IDS.length;
        state.tool = 'seed';
        syncHud();
        break;
      case ' ':
      case 'enter':
        e.preventDefault();
        useTool();
        break;
      case 'e':
        interact();
        break;
      case 'b':
        openShop('buy');
        break;
    }
    if (['arrowup', 'arrowdown', 'arrowleft', 'arrowright'].includes(e.key.toLowerCase())) {
      e.preventDefault();
    }
  });

  window.addEventListener('keyup', (e) => {
    keys[e.key.toLowerCase()] = false;
  });

  // 마우스: 플레이어 인접 타일 클릭으로 도구 사용
  canvas.addEventListener('click', (e) => {
    if (state.paused) return;
    const rect = canvas.getBoundingClientRect();
    const cx = (e.clientX - rect.left) * (canvas.width / rect.width);
    const cy = (e.clientY - rect.top) * (canvas.height / rect.height);
    const tx = Math.floor(cx / TILE);
    const ty = Math.floor(cy / TILE);
    const p = playerTile();
    const dx = tx - p.x;
    const dy = ty - p.y;
    if (Math.abs(dx) + Math.abs(dy) === 1) {
      player.dir = dx === 1 ? 'right' : dx === -1 ? 'left' : dy === 1 ? 'down' : 'up';
      useTool();
    } else if (dx === 0 && dy === 0) {
      useTool();
    }
  });

  // 툴바 클릭
  document.querySelectorAll('.tool-slot').forEach((el) => {
    el.addEventListener('click', () => {
      if (el.dataset.tool === 'seed' && state.tool === 'seed') {
        state.seedIndex = (state.seedIndex + 1) % CROP_IDS.length;
      }
      state.tool = el.dataset.tool;
      syncHud();
    });
  });

  document.getElementById('btn-shop').addEventListener('click', () => openShop('buy'));
  document.getElementById('btn-save').addEventListener('click', () => saveGame(false));
  document.getElementById('shop-close').addEventListener('click', closeShop);
  document.querySelectorAll('.shop-tab').forEach((el) => {
    el.addEventListener('click', () => { shopTab = el.dataset.tab; renderShop(); });
  });
  document.getElementById('sleep-yes').addEventListener('click', () => {
    closeSleepModal();
    nextDay(false);
  });
  document.getElementById('sleep-no').addEventListener('click', closeSleepModal);

  // ---- 이동 ----
  function updatePlayer(dt) {
    let vx = 0, vy = 0;
    if (keys['w'] || keys['arrowup']) vy -= 1;
    if (keys['s'] || keys['arrowdown']) vy += 1;
    if (keys['a'] || keys['arrowleft']) vx -= 1;
    if (keys['d'] || keys['arrowright']) vx += 1;

    player.moving = vx !== 0 || vy !== 0;
    if (!player.moving) return;

    if (Math.abs(vx) > Math.abs(vy)) player.dir = vx > 0 ? 'right' : 'left';
    else if (vy !== 0) player.dir = vy > 0 ? 'down' : 'up';
    else if (vx !== 0) player.dir = vx > 0 ? 'right' : 'left';

    const len = Math.hypot(vx, vy);
    const step = player.speed * dt;
    const nx = player.x + (vx / len) * step;
    const ny = player.y + (vy / len) * step;

    // 축별 충돌 검사 (발 밑 8px 반경)
    const R = 7;
    function blocked(px, py) {
      const corners = [
        [px - R, py - R], [px + R, py - R],
        [px - R, py + R], [px + R, py + R],
      ];
      return corners.some(([qx, qy]) =>
        !isPassable(Math.floor(qx / TILE), Math.floor(qy / TILE)));
    }
    if (!blocked(nx, player.y)) player.x = nx;
    if (!blocked(player.x, ny)) player.y = ny;

    player.animTime += dt;
  }

  // ---- 렌더링 ----
  function groundColor(x, y, tile) {
    const h = tileHash(x, y);
    if (tile.ground === 'water') {
      return h < 0.5 ? '#3b6ea5' : '#356598';
    }
    if (tile.ground === 'soil') {
      if (tile.watered) return h < 0.5 ? '#5a4028' : '#513a24';
      return h < 0.5 ? '#8a6a42' : '#80613c';
    }
    // grass
    return h < 0.33 ? '#63a84f' : h < 0.66 ? '#5da04a' : '#68ad54';
  }

  function drawTiles() {
    for (let y = 0; y < MAP_H; y++) {
      for (let x = 0; x < MAP_W; x++) {
        const tile = grid[y][x];
        ctx.fillStyle = groundColor(x, y, tile);
        ctx.fillRect(x * TILE, y * TILE, TILE, TILE);

        const h = tileHash(x * 7 + 3, y * 11 + 5);
        if (tile.ground === 'grass' && h < 0.25) {
          // 풀 디테일
          ctx.fillStyle = '#4c8f3d';
          const gx = x * TILE + Math.floor(h * 12) * PX;
          const gy = y * TILE + Math.floor(h * 9) * PX + 8;
          ctx.fillRect(gx, gy, PX, PX * 2);
          ctx.fillRect(gx + PX * 2, gy + PX, PX, PX);
        }
        if (tile.ground === 'soil') {
          // 밭고랑 라인
          ctx.fillStyle = tile.watered ? '#48331f' : '#755835';
          ctx.fillRect(x * TILE, y * TILE + TILE / 2 - 1, TILE, 2);
        }
        if (tile.ground === 'water') {
          // 물결
          if (h < 0.3) {
            ctx.fillStyle = '#5b8cc0';
            ctx.fillRect(x * TILE + 6, y * TILE + 10 + Math.floor(h * 10), 10, 2);
          }
        }
      }
    }
  }

  function drawCrops() {
    for (let y = 0; y < MAP_H; y++) {
      for (let x = 0; x < MAP_W; x++) {
        const c = grid[y][x].crop;
        if (!c) continue;
        drawSprite(ctx, cropSpriteFor(c.id, c.day), x * TILE, y * TILE, PX, false);
      }
    }
  }

  function drawHouse(tx, ty) {
    // 5x4 타일 크기의 집. tx,ty = 좌상단 타일
    const x = tx * TILE, y = ty * TILE;
    const w = 5 * TILE, hh = 4 * TILE;
    // 벽
    ctx.fillStyle = '#c9a56b';
    ctx.fillRect(x + 8, y + TILE, w - 16, hh - TILE - 4);
    // 지붕
    ctx.fillStyle = '#a5402f';
    ctx.beginPath();
    ctx.moveTo(x - 2, y + TILE + 6);
    ctx.lineTo(x + w / 2, y - 6);
    ctx.lineTo(x + w + 2, y + TILE + 6);
    ctx.closePath();
    ctx.fill();
    ctx.fillStyle = '#8c3325';
    ctx.fillRect(x - 2, y + TILE + 2, w + 4, 6);
    // 문
    ctx.fillStyle = '#6b4423';
    ctx.fillRect(x + w / 2 - 12, y + hh - 40, 24, 36);
    ctx.fillStyle = '#ffd75e';
    ctx.fillRect(x + w / 2 + 4, y + hh - 24, 4, 4);
    // 창문
    ctx.fillStyle = '#9ecbe8';
    ctx.fillRect(x + 22, y + TILE + 20, 18, 16);
    ctx.fillRect(x + w - 40, y + TILE + 20, 18, 16);
    ctx.strokeStyle = '#6b4423';
    ctx.lineWidth = 2;
    ctx.strokeRect(x + 22, y + TILE + 20, 18, 16);
    ctx.strokeRect(x + w - 40, y + TILE + 20, 18, 16);
  }

  function drawObjects() {
    // y 순서로 정렬해 그리기 (플레이어와의 앞뒤 관계)
    const items = [];
    let houseDrawn = false;
    for (const key in objects) {
      const [x, y] = key.split(',').map(Number);
      const kind = objects[key];
      if (kind === 'house') {
        if (!houseDrawn) { items.push({ x: 2, y: 4, kind: 'house' }); houseDrawn = true; }
        continue;
      }
      items.push({ x, y, kind });
    }
    items.push({ x: -1, y: -1, kind: 'player', py: player.y });

    items.sort((a, b) => {
      const ay = a.kind === 'player' ? a.py : (a.y + 1) * TILE;
      const by = b.kind === 'player' ? b.py : (b.y + 1) * TILE;
      return ay - by;
    });

    for (const it of items) {
      if (it.kind === 'tree') {
        drawSprite(ctx, SPRITES.tree, it.x * TILE, (it.y - 1) * TILE, PX, false);
      } else if (it.kind === 'rock') {
        drawSprite(ctx, SPRITES.rock, it.x * TILE, it.y * TILE, PX, false);
      } else if (it.kind === 'bin') {
        drawSprite(ctx, SPRITES.bin, it.x * TILE, it.y * TILE, PX, false);
      } else if (it.kind === 'house') {
        drawHouse(2, 1);
      } else if (it.kind === 'player') {
        drawPlayer();
      }
    }
  }

  function drawPlayer() {
    const frame = player.moving ? (Math.floor(player.animTime * 6) % 2) : 0;
    let rows, flip = false;
    if (player.dir === 'down') rows = frame ? SPRITES.playerDown1 : SPRITES.playerDown0;
    else if (player.dir === 'up') rows = frame ? SPRITES.playerUp1 : SPRITES.playerUp0;
    else {
      rows = frame ? SPRITES.playerSide1 : SPRITES.playerSide0;
      flip = player.dir === 'left';
    }
    // 아트 12x16 -> 24x32px, 발 밑 기준 배치
    const drawX = player.x - 12;
    const drawY = player.y - 30;
    drawSprite(ctx, rows, drawX, drawY, PX, flip);
  }

  function drawTargetHighlight() {
    const t = targetTile();
    if (!inBounds(t.x, t.y)) return;
    ctx.strokeStyle = 'rgba(255, 255, 255, 0.7)';
    ctx.lineWidth = 2;
    ctx.strokeRect(t.x * TILE + 1, t.y * TILE + 1, TILE - 2, TILE - 2);
  }

  function drawNight() {
    // 오후 6시부터 어두워져서 자정에 최대
    const start = 18 * 60;
    const full = 24 * 60;
    if (state.minutes <= start) return;
    const a = Math.min((state.minutes - start) / (full - start), 1) * 0.55;
    ctx.fillStyle = 'rgba(15, 10, 45, ' + a.toFixed(3) + ')';
    ctx.fillRect(0, 0, canvas.width, canvas.height);
  }

  // ---- 메인 루프 ----
  let lastTime = 0;
  let clockAccum = 0;

  function frame(ts) {
    const dt = Math.min((ts - lastTime) / 1000, 0.1);
    lastTime = ts;

    if (!state.paused) {
      updatePlayer(dt);
      tickTime(dt);
      clockAccum += dt;
      if (clockAccum > 0.5) { // HUD 시계는 0.5초마다 갱신
        clockAccum = 0;
        document.getElementById('hud-clock').textContent = clockText();
      }
    }

    ctx.clearRect(0, 0, canvas.width, canvas.height);
    drawTiles();
    drawCrops();
    drawTargetHighlight();
    drawObjects();
    drawNight();

    requestAnimationFrame(frame);
  }

  // ---- 시작 ----
  buildMap();
  if (loadGame()) {
    showMessage('저장된 농장을 불러왔다!');
  } else {
    showMessage('교진 팜에 온 것을 환영한다! 감자 씨앗 5개로 시작하자.');
  }
  syncHud();
  requestAnimationFrame(frame);
})();
