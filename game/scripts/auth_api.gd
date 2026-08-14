# 익명 로그인 — 아무것도 묻지 않고 신원을 얻는다.
#
# 장터는 바깥 서버라 「누가 올렸는가」를 가려야 하는데, 예전에는 게임이
# 스스로 만든 farm_id를 이름표처럼 들고 다녔다. 그 값이 새어 나가면 남의
# 대금을 받아 갈 수 있고, 파일을 지우면 등록 한도도 초기화됐다.
#
# 이제 게임을 처음 켤 때 서버에서 **익명 계정**을 하나 받아 온다. 플레이어는
# 아무것도 입력하지 않는다. 이후 요청에는 그 계정의 토큰을 실어 보내고,
# 서버는 클라이언트가 뭐라 주장하든 **토큰의 주인**을 신원으로 삼는다.
#
# 서버에서 익명 로그인이 꺼져 있거나 인터넷이 없으면, 예전처럼 farm_id로
# 굴러간다 — 로그인 때문에 게임이 멈추지는 않는다.
extends Node

signal ready_changed(ok: bool)   # 인자 이름은 함수명(signed_in)과 겹치지 않게

const URL := "https://crtjpqlseizzwzkrctte.supabase.co"
const KEY := "sb_publishable_1mNGh1HIXYxaS6D9TYAkvw_jHW_xGDQ"
const AUTH := URL + "/auth/v1/"
const PATH := "user://kyojin_auth.json"

var access_token := ""
var refresh_token := ""
var uid := ""              # 서버가 발급한 계정 id (신원)
var _expires_at := 0.0     # 만료 시각 (Unix 초)
var _busy := false


func _ready() -> void:
	_load()
	# 토큰이 없으면 계정을 받고, 있으면 필요할 때 갱신한다
	if refresh_token == "":
		_sign_in_anonymously()
	elif _expires_soon():
		_refresh()


func signed_in() -> bool:
	return access_token != "" and uid != ""


# 장터 요청에 실을 인증 헤더. 로그인 전이면 공개 키를 그대로 쓴다
# (그때는 예전처럼 farm_id로 신원을 가린다)
func bearer() -> String:
	return access_token if signed_in() else KEY


func _expires_soon() -> bool:
	return Time.get_unix_time_from_system() > _expires_at - 120.0


func _headers() -> PackedStringArray:
	return PackedStringArray([
		"apikey: " + KEY,
		"Content-Type: application/json",
	])


func _send(url: String, body: Dictionary, done: Callable) -> void:
	var req := HTTPRequest.new()
	req.timeout = 10.0
	add_child(req)
	req.request_completed.connect(func(_r: int, code: int, _h: PackedStringArray,
			data: PackedByteArray) -> void:
		var parsed: Variant = null
		if data.size() > 0:
			parsed = JSON.parse_string(data.get_string_from_utf8())
		req.queue_free()
		_busy = false
		done.call(code, parsed))
	if req.request(url, _headers(), HTTPClient.METHOD_POST,
			JSON.stringify(body)) != OK:
		req.queue_free()
		_busy = false
		done.call(0, null)


func _sign_in_anonymously() -> void:
	if _busy:
		return
	_busy = true
	# 이메일도 비밀번호도 없이 부르면 익명 계정이 만들어진다
	# (서버에서 「Anonymous sign-ins」가 켜져 있어야 한다)
	_send(AUTH + "signup", {}, func(code: int, res: Variant) -> void:
		if code == 200 and typeof(res) == TYPE_DICTIONARY:
			_apply(res)
		else:
			# 꺼져 있거나 못 닿았다 — farm_id로 계속 간다
			ready_changed.emit(false))


func _refresh() -> void:
	if _busy or refresh_token == "":
		return
	_busy = true
	_send(AUTH + "token?grant_type=refresh_token",
		{"refresh_token": refresh_token},
		func(code: int, res: Variant) -> void:
			if code == 200 and typeof(res) == TYPE_DICTIONARY:
				_apply(res)
				return
			# 토큰이 상했다 — 계정을 새로 받는다 (예전 등록 글과는 끊긴다)
			access_token = ""
			refresh_token = ""
			uid = ""
			_sign_in_anonymously())


func _apply(res: Dictionary) -> void:
	access_token = str(res.get("access_token", ""))
	refresh_token = str(res.get("refresh_token", refresh_token))
	var expires_in := float(res.get("expires_in", 3600))
	_expires_at = Time.get_unix_time_from_system() + expires_in
	var user: Variant = res.get("user", null)
	if typeof(user) == TYPE_DICTIONARY:
		uid = str((user as Dictionary).get("id", ""))
	_save()
	ready_changed.emit(signed_in())


# 토큰이 만료되기 전에 슬며시 갱신한다 (장터를 쓰는 도중 끊기지 않게)
func _process(_delta: float) -> void:
	if refresh_token != "" and not _busy and _expires_soon():
		_refresh()


func _save() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({
			"access_token": access_token, "refresh_token": refresh_token,
			"uid": uid, "expires_at": _expires_at,
		}))


func _load() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var d: Variant = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY:
		return
	access_token = str(d.get("access_token", ""))
	refresh_token = str(d.get("refresh_token", ""))
	uid = str(d.get("uid", ""))
	_expires_at = float(d.get("expires_at", 0.0))
