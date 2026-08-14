# 경매장 통신 — 모든 플레이어가 함께 보는 장터의 배관.
#
# 세계(함께하기)와 달리 여기는 **바깥 서버**다. 내 농장이 무엇을 올렸는지
# 다른 농장에서도 보이고, 접속을 꺼도 글이 남는다.
#
# 신원은 로그인 없이 `GameData.farm_id` 하나로 가른다 — 게임을 처음 켤 때
# 만들어 설정 파일에 넣어 두는 무작위 문자열이다. 남의 글을 건드리지
# 못하게 사기·거두기·대금 받기는 전부 서버 함수(rpc)로만 한다.
#
# 신호로 결과를 알린다 — 창(auction_ui)이 받아서 그린다.
#   listed(ok, msg)      등록 끝
#   fetched(rows)        목록 도착
#   bought(ok, msg, row) 삼 (성공하면 row로 물건을 넣어 준다)
#   claimed(count, gold) 대금 수령
extends Node

signal listed(ok: bool, msg: String, fee: int)
signal fetched(rows: Array)
signal bought(ok: bool, msg: String, row: Dictionary)
signal claimed(count: int, gold: int)

const URL := "https://crtjpqlseizzwzkrctte.supabase.co"
# 공개 키 — 읽기/등록만 되는 열쇠다 (고치고 지우는 길은 서버가 막아 뒀다)
const KEY := "sb_publishable_1mNGh1HIXYxaS6D9TYAkvw_jHW_xGDQ"
const REST := URL + "/rest/v1/"
const PAGE := 60          # 한 번에 받아 오는 글 수

var busy := false         # 요청이 하나만 돌게 (버튼 연타 방지)


func _headers(extra := PackedStringArray()) -> PackedStringArray:
	var h := PackedStringArray([
		"apikey: " + KEY,
		"Authorization: Bearer " + KEY,
		"Content-Type: application/json",
	])
	h.append_array(extra)
	return h


# 요청 하나 = HTTPRequest 하나. 끝나면 스스로 사라진다 —
# 창을 닫아도 날아오던 답이 죽은 노드를 건드리지 않는다.
func _send(url: String, method: int, body: Variant, extra: PackedStringArray,
		done: Callable) -> void:
	var req := HTTPRequest.new()
	req.timeout = 12.0
	add_child(req)
	req.request_completed.connect(func(_r: int, code: int, _h: PackedStringArray,
			data: PackedByteArray) -> void:
		var parsed: Variant = null
		if data.size() > 0:
			parsed = JSON.parse_string(data.get_string_from_utf8())
		req.queue_free()
		busy = false
		done.call(code, parsed))
	var err := req.request(url, _headers(extra), method,
		"" if body == null else JSON.stringify(body))
	if err != OK:
		req.queue_free()
		busy = false
		done.call(0, null)


# 서버가 돌려준 잘못을 사람 말로 (없으면 통째로 보여 준다)
func _why(code: int, res: Variant) -> String:
	if code == 0:
		return "장터에 닿지 못했다... 인터넷을 확인하자."
	if typeof(res) == TYPE_DICTIONARY:
		for k in ["message", "hint", "details", "error"]:
			var v: String = str(res.get(k, ""))
			if v != "":
				return v
	return "장터가 거절했다 (%d)" % code


# ---- 목록 ----
#
# 열려 있는 글은 새것부터, 내 글은 팔린 것까지 함께 본다.
func fetch(mine_only := false) -> void:
	if busy:
		return
	busy = true
	if mine_only:
		# 내 글은 함수로 받는다 — 목록에는 seller_id(내 농장 열쇠)가 실리지
		# 않으므로, 열쇠를 아는 사람만 볼 수 있는 이 길로 온다
		_send(REST + "rpc/farm_auction_mine", HTTPClient.METHOD_POST,
			{"p_seller_id": GameData.farm_id}, PackedStringArray(),
			func(code: int, res: Variant) -> void:
				fetched.emit(res if code == 200 and typeof(res) == TYPE_ARRAY else []))
		return
	# 장터 목록 — 볼 수 있는 칸만 골라 받는다 (남의 열쇠는 서버가 안 준다)
	var cols := "id,seller_name,cat,item_id,qty,quality,price,status,created_at"
	_send(REST + "farm_auctions?select=%s&status=eq.open&order=created_at.desc&limit=%d"
		% [cols, PAGE], HTTPClient.METHOD_GET, null, PackedStringArray(),
		func(code: int, res: Variant) -> void:
			fetched.emit(res if code == 200 and typeof(res) == TYPE_ARRAY else []))


# ---- 등록 ----
#
# 직접 넣지 않고 서버 함수를 부른다 — 슬롯 상한·하루 횟수·쿨다운·수수료·
# 가격 상하한을 **서버가** 본다 (고친 게임으로 우회할 수 없게).
func list_item(cat: String, item_id: String, qty: int, quality: int, price: int) -> void:
	if busy:
		return
	busy = true
	_send(REST + "rpc/farm_auction_list", HTTPClient.METHOD_POST, {
			"p_seller_id": GameData.farm_id,
			"p_seller_name": GameData.seller_name(),
			"p_cat": cat, "p_item_id": item_id,
			"p_qty": qty, "p_quality": quality, "p_price": price,
		}, PackedStringArray(),
		func(code: int, res: Variant) -> void:
			if code != 200 or typeof(res) != TYPE_DICTIONARY:
				listed.emit(false, _why(code, res), 0)
				return
			listed.emit(bool(res.get("ok", false)), str(res.get("msg", "")),
				int(res.get("fee", 0))))


# ---- 사기 ----
func buy(id: int) -> void:
	if busy:
		return
	busy = true
	_send(REST + "rpc/farm_auction_buy", HTTPClient.METHOD_POST, {
			"p_id": id, "p_buyer_id": GameData.farm_id,
			"p_buyer_name": GameData.seller_name(),
		}, PackedStringArray(),
		func(code: int, res: Variant) -> void:
			if code == 200 and typeof(res) == TYPE_DICTIONARY:
				bought.emit(true, "샀다!", res)
			else:
				bought.emit(false, _why(code, res), {}))


# ---- 거두기 (안 팔린 내 물건) ----
func cancel(id: int) -> void:
	if busy:
		return
	busy = true
	_send(REST + "rpc/farm_auction_cancel", HTTPClient.METHOD_POST,
		{"p_id": id, "p_seller_id": GameData.farm_id}, PackedStringArray(),
		func(code: int, res: Variant) -> void:
			if code == 200 and typeof(res) == TYPE_DICTIONARY:
				bought.emit(true, "물건을 다시 거뒀다.", res)
			else:
				bought.emit(false, _why(code, res), {}))


# ---- 대금 받기 ----
#
# 팔렸는데 아직 안 받아 간 것을 한 번에 정산한다. 서버가 같은 문장에서
# 받아 감 표시를 세우므로 두 번 받을 수 없다.
func claim() -> void:
	if busy:
		return
	busy = true
	_send(REST + "rpc/farm_auction_claim", HTTPClient.METHOD_POST,
		{"p_seller_id": GameData.farm_id}, PackedStringArray(),
		func(code: int, res: Variant) -> void:
			if code != 200 or typeof(res) != TYPE_ARRAY:
				claimed.emit(0, 0)
				return
			var gold := 0
			for r: Dictionary in res:
				gold += int(r.get("price", 0))
			claimed.emit((res as Array).size(), gold))
