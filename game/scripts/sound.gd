# 사운드 매니저 (오토로드): BGM/SFX 재생, 볼륨 설정 저장
extends Node

const SETTINGS_PATH := "user://kyojin_settings.json"
const SFX_NAMES := [
	"sfx_hoe", "sfx_water", "sfx_seed", "sfx_harvest", "sfx_chop", "sfx_pick",
	"sfx_place", "sfx_cast", "sfx_bite", "sfx_catch", "sfx_miss", "sfx_ui",
	"sfx_coin", "sfx_heart", "sfx_sleep", "sfx_step0", "sfx_step1",
]
# 계절 넷 + 장소·상황 여섯. 예전에는 계절 넷뿐이었고 각 20초였다.
# 브금은 전부 ogg다. 낮(bgm_main)과 밤(bgm_night)은 받은 곡으로,
# 각각 2분 53초짜리 한 곡을 되감아 쓴다.
const BGM_NAMES := ["bgm_spring", "bgm_summer", "bgm_fall", "bgm_winter",
	"bgm_village", "bgm_cave", "bgm_shop", "bgm_night", "bgm_festival", "bgm_title",
	"bgm_main"]

var streams := {}
var bgm_player: AudioStreamPlayer
var sfx_pool: Array = []
var sfx_index := 0
var current_bgm := ""
var _fade: Tween = null

# ---- 브금 이음매 ----
#
# ogg 자체는 샘플 하나 어긋나지 않고 되감긴다. 그런데도 「뚝」 하고
# 끊겨 들리는 것은, 곡의 **끝맺음과 첫 마디가 원래 이어 붙으라고 만든
# 소리가 아니기** 때문이다. 그래서 끝나기를 기다리지 않고 **미리 겹쳐 튼다** —
# 마지막 몇 초 동안 지금 곡은 서서히 줄이고, 두 번째 플레이어가 같은 곡을
# 처음부터 서서히 키운다. 다 넘어가면 둘의 역할을 맞바꿔 다음 바퀴를 준비한다.
# (스트림의 loop는 그대로 켜 둔다 — 겹치기가 어떤 이유로 어긋나도
#  소리가 아예 멎지는 않게 하는 안전망이다)
const LOOP_XFADE := 2.2
var _bgm_b: AudioStreamPlayer = null
var _xfade: Tween = null
var _xfading := false

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
		streams[n] = load("res://assets/audio/%s.ogg" % n)
	# BGM 루프 설정 (형마다 다르다)
	for n in BGM_NAMES:
		var st: AudioStream = streams[n]
		if st is AudioStreamOggVorbis or st is AudioStreamMP3:
			st.loop = true
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
	add_child(bgm_player)
	# 이음매용 두 번째 플레이어 (같은 곡을 겹쳐 트는 데 쓴다)
	_bgm_b = AudioStreamPlayer.new()
	_bgm_b.bus = "BGM"
	add_child(_bgm_b)
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
	"bgm_cave": 3.6, "bgm_fall": 1.6, "bgm_festival": 0.5, "bgm_night": -2.5,
	"bgm_shop": 1.4, "bgm_spring": 2.1, "bgm_summer": 1.1, "bgm_title": 0.2,
	"bgm_village": 2.5, "bgm_winter": -0.4, "bgm_main": 0.0,
}
# 밤 곡만 이 표를 벗어난다. 낮 곡과 실측 크기가 같아서(둘 다 -14.3dBFS)
# 0으로 두면 해가 져도 소리가 그대로다 — 밤은 조금 더 낮게 깔려야 한다.


# 곡을 바꾼다. 뚝 끊으면 귀에 거슬려서 0.6초에 걸쳐 갈아 끼운다.
func play_track(name: String) -> void:
	if not streams.has(name):
		return
	var gain: float = float(TRACK_GAIN.get(name, 0.0))
	if name == current_bgm:
		# 같은 곡인데 소리가 멎어 있으면(어떤 이유로든) 조용히 다시 건다 —
		# 예전에는 여기서 그냥 돌아가서, 한 번 멎은 브금이 영영 안 돌아왔다
		if not bgm_player.playing and not _xfading:
			bgm_player.stream = streams[name]
			bgm_player.volume_db = gain
			bgm_player.play()
		return
	current_bgm = name
	_cancel_xfade()
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
	_cancel_xfade()
	bgm_player.stop()


# 이어 붙이던 것을 접는다 (곡을 바꾸거나 멈출 때)
func _cancel_xfade() -> void:
	if _xfade != null and _xfade.is_valid():
		_xfade.kill()
	_xfading = false
	if _bgm_b != null:
		_bgm_b.stop()


func _process(_delta: float) -> void:
	if current_bgm == "" or bgm_player == null or not bgm_player.playing:
		return
	if _xfading or (_fade != null and _fade.is_valid()):
		return          # 곡을 갈아 끼우는 중이면 이음매는 신경 쓰지 않는다
	var st: AudioStream = bgm_player.stream
	if st == null:
		return
	var length := st.get_length()
	if length <= LOOP_XFADE * 2.0:
		return          # 너무 짧은 곡은 그냥 되감는다
	if bgm_player.get_playback_position() < length - LOOP_XFADE:
		return
	_start_loop_xfade()


func _start_loop_xfade() -> void:
	var gain: float = float(TRACK_GAIN.get(current_bgm, 0.0))
	_xfading = true
	_bgm_b.stream = bgm_player.stream
	_bgm_b.volume_db = gain - 40.0
	_bgm_b.play()
	_xfade = create_tween()
	_xfade.set_parallel(true)
	_xfade.tween_property(bgm_player, "volume_db", gain - 40.0, LOOP_XFADE)
	_xfade.tween_property(_bgm_b, "volume_db", gain, LOOP_XFADE)
	_xfade.chain().tween_callback(_finish_loop_xfade)


func _finish_loop_xfade() -> void:
	# 역할을 맞바꾼다 — 지금 울리고 있는 쪽이 bgm_player가 된다
	var gain: float = float(TRACK_GAIN.get(current_bgm, 0.0))
	var old := bgm_player
	old.stop()
	old.volume_db = gain
	bgm_player = _bgm_b
	_bgm_b = old
	_xfading = false


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
