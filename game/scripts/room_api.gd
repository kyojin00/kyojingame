# 방 코드 — IP 대신 여섯 글자로 만나기.
#
# 호스트가 방을 열면 서버가 코드를 만들어 주고(그때 우리 공인 주소도 서버가
# 직접 본다), 손님은 그 코드만 치면 주소를 받아 붙는다. 접속 자체는 예전처럼
# ENet 직결이라, 이 파일은 **주소를 알려 주는 안내판** 노릇만 한다.
#
# 신호
#   opened(ok, code, msg)     방 열기 결과
#   found(ok, ip, port, msg)  코드로 찾은 결과
extends Node

signal opened(ok: bool, room_code: String, msg: String)   # 인자 이름은 멤버(code)와 겹치지 않게
signal found(ok: bool, ip: String, port: int, msg: String)

const URL := "https://crtjpqlseizzwzkrctte.supabase.co"
const KEY := "sb_publishable_1mNGh1HIXYxaS6D9TYAkvw_jHW_xGDQ"
const REST := URL + "/rest/v1/rpc/"
const BEAT_SEC := 40.0        # 살아 있음을 알리는 간격 (서버는 2분까지 기다린다)

var code := ""                # 열어 둔 방 코드 (호스트만)
var _beat := 0.0


# 로그인했으면 그 계정 토큰, 아니면 공개 키 (오토로드는 실행할 때 집는다)
func _bearer() -> String:
	var a := get_node_or_null("/root/Auth")
	return str(a.bearer()) if a != null else KEY


func _headers() -> PackedStringArray:
	return PackedStringArray([
		"apikey: " + KEY,
		"Authorization: Bearer " + _bearer(),
		"Content-Type: application/json",
	])


func _send(fn: String, body: Dictionary, done: Callable) -> void:
	var req := HTTPRequest.new()
	req.timeout = 10.0
	add_child(req)
	req.request_completed.connect(func(_r: int, code_: int, _h: PackedStringArray,
			data: PackedByteArray) -> void:
		var parsed: Variant = null
		if data.size() > 0:
			parsed = JSON.parse_string(data.get_string_from_utf8())
		req.queue_free()
		done.call(code_, parsed))
	if req.request(REST + fn, _headers(), HTTPClient.METHOD_POST,
			JSON.stringify(body)) != OK:
		req.queue_free()
		done.call(0, null)


# 같은 공유기 안 손님을 위해 우리 집 안 주소도 함께 알려 준다
func _lan_ip() -> String:
	for a in IP.get_local_addresses():
		var s := str(a)
		if s.begins_with("192.168.") or s.begins_with("10.") \
				or s.begins_with("172.16.") or s.begins_with("172.17."):
			return s
	return ""


func open_room(host_name: String, port := 7777) -> void:
	_send("farm_room_open",
		{"p_host_name": host_name, "p_lan_ip": _lan_ip(), "p_port": port},
		func(http: int, res: Variant) -> void:
			if http != 200 or typeof(res) != TYPE_DICTIONARY:
				opened.emit(false, "", "장터 서버에 닿지 못했다... 인터넷을 확인하자.")
				return
			if not bool(res.get("ok", false)):
				opened.emit(false, "", str(res.get("msg", "방을 열지 못했다")))
				return
			code = str(res.get("code", ""))
			opened.emit(true, code, ""))


func find_room(room_code: String) -> void:
	_send("farm_room_find", {"p_code": room_code.strip_edges().to_upper()},
		func(http: int, res: Variant) -> void:
			if http != 200 or typeof(res) != TYPE_DICTIONARY:
				found.emit(false, "", 0, "장터 서버에 닿지 못했다... 인터넷을 확인하자.")
				return
			if not bool(res.get("ok", false)):
				found.emit(false, "", 0, str(res.get("msg", "방을 찾지 못했다")))
				return
			found.emit(true, str(res.get("ip", "")), int(res.get("port", 7777)), ""))


func close_room() -> void:
	if code == "":
		return
	_send("farm_room_close", {"p_code": code}, func(_a: int, _b: Variant) -> void: pass)
	code = ""


# 방을 열어 둔 동안 살아 있음을 알린다 (끊기면 서버가 2분 뒤 치운다)
func _process(delta: float) -> void:
	if code == "":
		return
	_beat -= delta
	if _beat <= 0.0:
		_beat = BEAT_SEC
		_send("farm_room_beat", {"p_code": code, "p_players": 1 + _guest_count()},
			func(_a: int, _b: Variant) -> void: pass)


func _guest_count() -> int:
	if not Net.is_host() or multiplayer.multiplayer_peer == null:
		return 0
	return multiplayer.get_peers().size()
