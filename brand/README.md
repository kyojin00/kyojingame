# 유튜브 · 스팀에 올릴 이미지

게임 자산에서 뽑는다. **결과물은 커밋하지 않는다**(`out/`은 무시) — 캐릭터나
화면이 바뀔 때마다 다시 돌리면 되고, 17MB를 저장소에 넣을 이유가 없다.

```
KYOJIN_SHOT=1 godot --path game     # 스크린샷 60여 장 (1_clean.png 포함)
cd brand && node make_brand.js      # -> brand/out/
```

## 나오는 것

| 파일 | 크기 | 쓰는 곳 |
| --- | --- | --- |
| `yt_profile_800.png` | 800x800 | 유튜브 프로필 (화면에는 98px로 나온다) |
| `yt_banner_2048.png` | 2048x1152 | 유튜브 배너 |
| `yt_thumbnail_1280.png` | 1280x720 | 영상 미리보기 바탕 |
| `steam_header_460.png` | 460x215 | 상점 페이지 머리 |
| `steam_small_462.png` | 462x174 | 검색 결과 줄 |
| `steam_main_616.png` | 616x353 | 특집·추천 |
| `steam_vertical_374.png` | 374x448 | 세로 캡슐 |
| `steam_library_600.png` | 600x900 | 라이브러리 표지 |
| `steam_libhero_3840.png` | 3840x1240 | 라이브러리 배경 |
| `steam_page_bg_1438.png` | 1438x810 | 상점 배경 |
| `steam_ss_1..5.png` | 1920x1080 | 상점 스크린샷 (최소 5장) |

## 알아 둘 것

- **캡슐은 바탕만 나온다.** 게임 이름을 크게 얹어야 하고, 이름 없는 캡슐은
  스팀 심사에서 반려된다. 로고는 따로 만들어 얹을 것
- **유튜브 배너는 가운데 1235x338만 어디서나 보인다.** TV는 전체가, 휴대폰은
  가운데만 나온다. 중요한 것을 가장자리에 두면 휴대폰에서 잘린다
- **캡슐 바탕은 `1_clean.png`을 쓴다** — 하네스 224단계가 UI를 다 끄고 찍는
  화면이다. 보통 스크린샷은 미니맵·퀘스트창·말풍선이 얹혀 있어서 오려 쓸
  빈 띠가 100px대뿐이고, 그걸 늘리면 흐릿해진다
- **도트는 정수배 최근접 확대만.** 보간해서 늘리면 뭉개져 도트 게임으로 안 보인다
- 프로필은 **얼굴만** 자른다. 98px에 전신을 넣으면 아무것도 안 보인다

## 시연 영상 (트레일러 원본)

```
cd game
KYOJIN_SHOT=1 KYOJIN_REEL=1 godot --path . --write-movie /tmp/reel.avi --fixed-fps 60
ffmpeg -i /tmp/reel.avi -vf "scale=1920:1080:flags=neighbor" \
       -c:v libx264 -preset slow -crf 22 -pix_fmt yuv420p \
       -c:a aac -b:a 160k -movflags +faststart reel.mp4
```

20초짜리 여섯 대목 — 농장 걷기 · 밭 갈고 심고 물 주기 · 나무 베기(쓰러지는
모션) · 바위 캐기 · 마을 · 밤. 대목은 `dev_harness.gd`의 `_reel_tick()`에서
프레임 번호로 짠다 (`--fixed-fps 60`이니 **60 = 1초**).

- **`--fixed-fps`가 없으면 못 쓴다.** 헤드리스는 프레임이 들쭉날쭉해서 동작이
  튄다. 이게 붙으면 Godot이 실제 시간과 무관하게 한 장씩 그려 저장한다
- **확대는 `flags=neighbor`.** 기본 보간으로 늘리면 도트가 뭉개진다
- 소지금은 2450G로 낮춰 찍는다 — 개발 빌드 그대로면 1억G이 화면에 나온다
- **튜토리얼은 끄지 않는다.** `tutorial.active = false`로 내리면 대신 할아버지
  편지창이 떠서 20초 내내 화면 한가운데를 덮는다. 목표 상자가 훨씬 낫다
