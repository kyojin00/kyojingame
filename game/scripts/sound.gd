# 사운드 매니저 (오토로드): BGM/SFX 재생, 볼륨 설정 저장
extends Node

const SETTINGS_PATH := "user://kyojin_settings.json"
const SFX_NAMES := [
	"sfx_hoe", "sfx_water", "sfx_seed", "sfx_harvest", "sfx_chop", "sfx_pick",
	"sfx_place", "sfx_cast", "sfx_bite", "sfx_catch", "sfx_miss", "sfx_ui",
	"sfx_coin", "sfx_heart", "sfx_sleep", "sfx_step0", "sfx_step1",
]
# 계절 넷 + 장소·상황 여섯. 예전에는 계절 넷뿐이었고 각 20초였다.
const BGM_NAMES := ["bgm_spring", "bgm_summer", "bgm_fall", "bgm_winter",
	"bgm_village", "bgm_cave", "bgm_shop", "bgm_night", "bgm_festival", "bgm_title",
	"bgm_main"]      # bgm_main은 받은 곡(mp3) — 낮의 바깥 기본 배경음

var streams := {}
var bgm_player: AudioStreamPlayer
var sfx_pool: Array = []
var sfx_index := 0
var current_bgm := ""
var _fade: Tween = null

# 설정 (0~100)
var master_volume := 80.0
var bgm_volume := 60.0
var sfx_volume := 80.0


func _ready() -> void:
	# 버스 구성: Master 아래 BGM/SFX
	AudioServer.add_bus()
	AudioServer.set_bus_name(1, "BGM")
	AudioServer.add_bus()
	AudioServer.set_bus_name(2, "SFX")

	for n in SFX_NAMES + BGM_NAMES:
		var ext := "mp3" if n == "bgm_main" else "wav"
		streams[n] = load("res://assets/audio/%s.%s" % [n, ext])
	# BGM 루프 설정 (형마다 다르다)
	for n in BGM_NAMES:
		var st: AudioStream = streams[n]
		if st is AudioStreamWAV:
			st.loop_mode = AudioStreamWAV.LOOP_FORWARD
			st.loop_begin = 0
			st.loop_end = st.data.size() / 2  # 16bit mono
		elif st is AudioStreamMP3:
			st.loop = true

	bgm_player = AudioStreamPlayer.new()
	bgm_player.bus = "BGM"
	add_child(bgm_player)
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		sfx_pool.append(p)

	load_settings()
	apply_settings()


func play_sfx(name: String, pitch_jitter := 0.0) -> void:
	if not streams.has(name):
		return
	var p: AudioStreamPlayer = sfx_pool[sfx_index]
	sfx_index = (sfx_index + 1) % sfx_pool.size()
	p.stream = streams[name]
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.play()


func play_bgm(season_key: String) -> void:
	play_track("bgm_" + season_key)


# 곡을 바꾼다. 뚝 끊으면 귀에 거슬려서 0.6초에 걸쳐 갈아 끼운다.
func play_track(name: String) -> void:
	if name == current_bgm or not streams.has(name):
		return
	current_bgm = name
	if _fade != null and _fade.is_valid():
		_fade.kill()
	if not bgm_player.playing:
		bgm_player.stream = streams[name]
		bgm_player.volume_db = 0.0
		bgm_player.play()
		return
	_fade = create_tween()
	_fade.tween_property(bgm_player, "volume_db", -40.0, 0.3)
	_fade.tween_callback(func() -> void:
		bgm_player.stream = streams[name]
		bgm_player.play())
	_fade.tween_property(bgm_player, "volume_db", 0.0, 0.3)


func stop_bgm() -> void:
	current_bgm = ""
	bgm_player.stop()


# ---- 설정 ----

func apply_settings() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(clampf(master_volume / 100.0, 0.0001, 1.0)))
	AudioServer.set_bus_volume_db(1, linear_to_db(clampf(bgm_volume / 100.0, 0.0001, 1.0)))
	AudioServer.set_bus_volume_db(2, linear_to_db(clampf(sfx_volume / 100.0, 0.0001, 1.0)))
	AudioServer.set_bus_mute(0, master_volume <= 0.5)
	AudioServer.set_bus_mute(1, bgm_volume <= 0.5)
	AudioServer.set_bus_mute(2, sfx_volume <= 0.5)
	# 창/전체화면 모드는 GameData.apply_window_mode()가 담당한다


func save_settings() -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({
			"master": master_volume, "bgm": bgm_volume, "sfx": sfx_volume,
		}))


func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY:
		return
	master_volume = float(d.get("master", master_volume))
	bgm_volume = float(d.get("bgm", bgm_volume))
	sfx_volume = float(d.get("sfx", sfx_volume))
