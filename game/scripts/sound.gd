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
	"bgm_main", "bgm_night2", "bgm_night3"]   # 받은 곡(mp3)
const MP3_NAMES := ["bgm_main", "bgm_night2", "bgm_night3"]
# ---- 밤 브금은 한 곡이 아니라 세 곡이 이어진다 ----
#
# 밤은 길다. 한 곡을 계속 되감으면 두 바퀴째부터 「아까 그 소절」이 도드라져서
# 오히려 조용한 밤이 지겨워진다. 그래서 밤에는 세 곡을 **이어** 튼다 —
# 한 곡이 끝나면 다음 곡이 스르르 올라온다 (뚝 끊기지 않게 서서히 켠다).
#
# 밤 곡만 루프를 끈다. 루프가 걸려 있으면 끝나지 않아서 다음 곡으로 넘어갈
# 때(`finished`)를 알 수가 없다.
const NIGHT_TRACKS := ["bgm_night", "bgm_night2", "bgm_night3"]
const NIGHT_FADE := 1.6          # 다음 곡이 올라오는 시간(초)
var _night_i := 0

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

	# 효과음은 wav (짧아서 그대로 두는 편이 낫다), BGM은 ogg.
	# BGM을 wav로 두면 47MB인데 ogg로는 6MB다. 게다가 wav는 들여올 때 어차피
	# 손실 압축(QOA)되므로, ogg 쪽이 용량도 작고 음질도 낫다.
	for n in SFX_NAMES:
		streams[n] = load("res://assets/audio/%s.wav" % n)
	for n in BGM_NAMES:
		var ext := "mp3" if n in MP3_NAMES else "ogg"
		streams[n] = load("res://assets/audio/%s.%s" % [n, ext])
	# BGM 루프 설정 (형마다 다르다)
	for n in BGM_NAMES:
		var st: AudioStream = streams[n]
		if st is AudioStreamOggVorbis or st is AudioStreamMP3:
			# 밤 곡만 루프를 끈다 — 끝까지 가야 다음 밤 곡으로 넘어간다
			st.loop = n not in NIGHT_TRACKS
		elif st is AudioStreamWAV:
			# 혹시 wav를 도로 넣었을 때를 위해 남겨 둔다.
			# 끝은 **길이(초) x 초당 프레임**으로 잡아야 한다. 예전엔
			# `data.size() / 2`(16bit니까 2바이트 = 1프레임)로 셌는데, 들여올 때
			# 압축되면 data가 압축된 바이트라 그 셈이 안 맞는다 — 열 곡이 전부
			# 5분의 1 지점에서 되감겼다.
			var w: AudioStreamWAV = st
			w.loop_mode = AudioStreamWAV.LOOP_FORWARD
			w.loop_begin = 0
			w.loop_end = int(round(w.get_length() * float(w.mix_rate)))

	bgm_player = AudioStreamPlayer.new()
	bgm_player.bus = "BGM"
	bgm_player.finished.connect(_on_bgm_finished)
	add_child(bgm_player)
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		sfx_pool.append(p)

	load_settings()
	apply_settings()


# pitch_base로 같은 소리를 굵게/가늘게 쓴다 — 도끼질(1.0)과 나무가 쓰러지며
# 나는 「쿵」(0.55)은 같은 sfx_chop이지만 음높이만 다르다.
func play_sfx(name: String, pitch_jitter := 0.0, pitch_base := 1.0) -> void:
	if not streams.has(name):
		return
	var p: AudioStreamPlayer = sfx_pool[sfx_index]
	sfx_index = (sfx_index + 1) % sfx_pool.size()
	p.stream = streams[name]
	p.pitch_scale = maxf(0.05, pitch_base + randf_range(-pitch_jitter, pitch_jitter))
	p.play()


func play_bgm(season_key: String) -> void:
	play_track("bgm_" + season_key)


# 곡마다 녹음(마스터링) 크기가 제각각이라, 곡이 바뀌는 순간 갑자기
# 작아지거나 커지게 들렸다 — 동굴 곡이 기본 곡보다 3.6dB나 작았다.
# 실측 RMS 기준으로 기본 곡(bgm_main, -14.6dB)에 맞춰 보정한다.
const TRACK_GAIN := {
	"bgm_cave": 3.6, "bgm_fall": 1.6, "bgm_festival": 0.5, "bgm_night": 0.0,
	"bgm_shop": 1.4, "bgm_spring": 2.1, "bgm_summer": 1.1, "bgm_title": 0.2,
	"bgm_village": 2.5, "bgm_winter": -0.4, "bgm_main": 0.0,
	# 받은 밤 곡 두 개 — 기존 밤 곡과 같은 크기로 들리게 맞춘다
	"bgm_night2": 0.0, "bgm_night3": 0.0,
}


# 밤 곡이 끝났다 — 다음 밤 곡으로 이어 간다.
# (밤 곡 말고는 전부 루프라 여기까지 오지 않는다)
func _on_bgm_finished() -> void:
	if current_bgm not in NIGHT_TRACKS:
		return
	_night_i = (_night_i + 1) % NIGHT_TRACKS.size()
	var nxt: String = NIGHT_TRACKS[_night_i]
	current_bgm = nxt
	if _fade != null and _fade.is_valid():
		_fade.kill()
	# 앞 곡은 이미 끝나 조용하다 — 겹칠 것이 없으니 다음 곡을 서서히 켠다.
	# 갑자기 제 크기로 튀어나오면 「곡이 바뀌었다」가 먼저 들린다.
	var gain: float = float(TRACK_GAIN.get(nxt, 0.0))
	bgm_player.stream = streams[nxt]
	bgm_player.volume_db = gain - 24.0
	bgm_player.play()
	_fade = create_tween()
	_fade.tween_property(bgm_player, "volume_db", gain, NIGHT_FADE)


# 곡을 바꾼다. 뚝 끊으면 귀에 거슬려서 0.6초에 걸쳐 갈아 끼운다.
func play_track(name: String) -> void:
	# 「밤 브금」은 한 곡이 아니라 세 곡짜리 묶음이다. 밤마다 다른 곡으로
	# 시작하고, 이미 밤 곡이 돌고 있으면 건드리지 않는다 (한 곡 끝날 때마다
	# `_on_bgm_finished`가 다음 곡으로 넘긴다).
	if name == "bgm_night":
		if current_bgm in NIGHT_TRACKS and bgm_player.playing:
			return
		_night_i = randi() % NIGHT_TRACKS.size()
		name = NIGHT_TRACKS[_night_i]
	if not streams.has(name):
		return
	var gain: float = float(TRACK_GAIN.get(name, 0.0))
	if name == current_bgm:
		# 같은 곡인데 소리가 멎어 있으면(어떤 이유로든) 조용히 다시 건다 —
		# 예전에는 여기서 그냥 돌아가서, 한 번 멎은 브금이 영영 안 돌아왔다
		if not bgm_player.playing:
			bgm_player.stream = streams[name]
			bgm_player.volume_db = gain
			bgm_player.play()
		return
	current_bgm = name
	if _fade != null and _fade.is_valid():
		_fade.kill()
	if not bgm_player.playing:
		bgm_player.stream = streams[name]
		bgm_player.volume_db = gain
		bgm_player.play()
		return
	_fade = create_tween()
	_fade.tween_property(bgm_player, "volume_db", gain - 40.0, 0.3)
	_fade.tween_callback(func() -> void:
		bgm_player.stream = streams[name]
		bgm_player.play())
	_fade.tween_property(bgm_player, "volume_db", gain, 0.3)


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
