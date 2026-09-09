# NPC: 하루 일과에 따라 마을을 오가고, E로 대화/선물을 받는다.
#
# 일과는 main.NPC_SCHEDULE이 정한다. 시간대가 바뀌면 새 목적지까지
# 길찾기로 걸어가고, 도착한 뒤에는 그 둘레를 어슬렁거린다.
extends Node2D

var main: Node2D
var id := "merchant"
var region := Rect2i(46, 2, 13, 15)  # 배회 구역 (타일 단위)
var talked_today := false
var sprite: Sprite2D
var dir := "down"
var anim_time := 0.0
var moving := false
var target: Vector2
var wait := 0.0

# 하루 일과
var place := ""              # 지금 향하는(또는 머무는) 장소 이름
var dest := Vector2i(-999, -999)   # 그 장소의 타일
var route: Array = []        # 남은 길 (월드 좌표)
var _route_cd := 0.0         # 길찾기 재시도 간격
var scripted := false        # 스토리 연출이 직접 움직인다 — 일과·배회 정지
# 성능(S4a) — 일과 지터: 자리가 바뀐 뒤 사람마다 0~20 게임분을 기다렸다 움직인다(같은 시각에
# 온 마을이 한꺼번에 길을 찾지 않게). 거리 LOD: 아무 플레이어에게서 맨해튼 80칸 밖이면 길을
# 안 찾고 목적지에 옮겨 선다(보이지 않는 걸음은 계산하지 않는다)
const LOD_TILES := 80
var _jitter_min := -1
var _pending_place := ""
var _pending_at := -1.0


func _ready() -> void:
	sprite = Sprite2D.new()
	sprite.centered = false
	sprite.offset = Vector2(-16, -47)
	sprite.scale = Vector2(2, 2)
	add_child(sprite)
	target = position
	wait = randf_range(0.5, 2.0)
	_update_sprite()


func _draw() -> void:
	# 발밑 그림자
	draw_rect(Rect2(-4, -2, 8, 3), Color(0, 0, 0, 0.22))


func _process(delta: float) -> void:
	# NPC 일정: 저녁(19시)이 되면 집으로 돌아가 아침까지 만날 수 없다.
	# (이장은 스토리 편지 전달~집 인사 동안에는 남아 있는다)
	var home_time: bool = GameData.is_evening() \
		and not (id == "chief" and (scripted
			or GameData.story2_phase == "farm_talk"
			or GameData.story_phase in ["travel", "deliver", "home_open", "greet"])) \
		and not (id == "fisher"
			and GameData.fisher_quest in ["meet", "follow", "open"]) \
		and not GameData.night_owl(id) \
		and not GameData.constable_on_duty(id)   # 밤 사람은 22시까지, 밤 교대 순경은 24시까지 밖에 남는다
	if GameData.constable_off_duty(id):
		home_time = true   # 비번 순경은 경찰서 안 — 보이지도, 보지도 않는다(S4f)
	if visible == home_time:
		visible = not home_time
	if home_time:
		return
	if scripted:
		return   # 위치·방향·걸음은 스토리 연출(story.gd)이 직접 움직인다
	if main.ui_open():
		return
	anim_time += delta
	_route_cd = maxf(_route_cd - delta, 0.0)
	_update_schedule()
	if moving:
		var d := target - position
		if d.length() < 2.0:
			position = target
			if route.is_empty():
				moving = false
				wait = randf_range(0.4, 1.8)   # 잠깐 멈췄다가 다시 걷는다
			else:
				target = route.pop_front()     # 길을 따라 다음 칸으로
		else:
			var speed := 74.0 if not route.is_empty() else 52.0   # 이동 중엔 조금 빠르게
			var step := d.normalized() * speed * delta
			if absf(step.x) > absf(step.y):
				dir = "right" if step.x > 0 else "left"
			else:
				dir = "down" if step.y > 0 else "up"
			position += step
	else:
		wait -= delta
		if wait <= 0.0:
			_pick_target()
	_update_sprite()


# 시간대가 바뀌면 새 목적지로 길을 잡는다
func _update_schedule() -> void:
	var want: String = main.npcmgr.npc_place_now(id)
	if want == "":
		return
	if want != place:
		# 지터 — 자리가 바뀐 순간부터 제 몫의 분을 기다린다. 시계가 되감기면(새벽) 바로 간다
		if _jitter_min < 0:
			_jitter_min = posmod(hash(id), 21)
		if _pending_place != want:
			_pending_place = want
			_pending_at = GameData.minutes
		if GameData.minutes >= _pending_at and GameData.minutes - _pending_at < float(_jitter_min):
			return
		place = want
		dest = main.npcmgr.npc_place_tile(id, place)
		_route_cd = 0.0
	# 쫓는 중이면 목적지가 움직인다 — 길이 끝날 때마다 다시 잡는다(사회 S2b, 박 순경)
	if place == "chase" and route.is_empty():
		dest = main.npcmgr.npc_place_tile(id, place)
	if dest.x == -999 or not route.is_empty():
		return
	var ts: int = main.TILE
	var t := Vector2i(int(floor(position.x / ts)), int(floor(position.y / ts)))
	# 목적지 근처(어슬렁 반경)에 있으면 다 온 것이다
	if absi(t.x - dest.x) <= main.NPC_WANDER and absi(t.y - dest.y) <= main.NPC_WANDER:
		return
	if _route_cd > 0.0:
		return
	# 거리 LOD — 아무 플레이어에게서도 80칸 밖이면 걷지 않고 목적지에 선다(쫓는 중은 예외)
	if place != "chase" and _far_from_players(t):
		position = Vector2(dest.x * ts + ts / 2.0, dest.y * ts + ts / 2.0)
		route = []
		moving = false
		return
	# 프레임 예산 — 이 프레임의 길찾기 몫이 찼으면 다음 프레임에
	if not main.npcmgr.path_slot():
		_route_cd = 0.05
		return
	_route_cd = 2.0   # 길이 막혀 있으면 잠시 뒤 다시 시도한다
	var p: Array = main.npcmgr._tile_path(t, dest)
	if p.is_empty():
		# 못 찾았다는 것은 대개 **닿을 수 없다**는 뜻이다 (잠긴 구역, 건물에
		# 둘러싸인 칸). 그걸 2초마다 다시 찾으면 실패하는 값만 계속 문다 —
		# 실패한 자리는 한참 뒤에 다시 본다
		_route_cd = 15.0
		return
	route = p
	target = route.pop_front()
	moving = true


# 이 칸이 모든 플레이어(나·같이 노는 사람들)에게서 LOD 거리 밖인가
func _far_from_players(t: Vector2i) -> bool:
	var pt: Vector2i = main.player_tile()
	if absi(t.x - pt.x) + absi(t.y - pt.y) <= LOD_TILES:
		return false
	for pid in main.remote_players:
		var rp: Node2D = main.remote_players[pid]
		var rt := Vector2i(int(floor(rp.position.x / main.TILE)), int(floor(rp.position.y / main.TILE)))
		if absi(t.x - rt.x) + absi(t.y - rt.y) <= LOD_TILES:
			return false
	return true


# 목적지 둘레를 어슬렁거린다 (타일 크기는 main.TILE 기준)
func _pick_target() -> void:
	var ts: int = main.TILE
	var t := Vector2i(int(floor(position.x / ts)), int(floor(position.y / ts)))
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	dirs.shuffle()
	for d: Vector2i in dirs:
		# 한 번에 1~3칸씩 이어서 걷는다 (가다 서다 하는 모습이 자연스럽다)
		var n := t
		var steps := 0
		for i in randi_range(1, 3):
			var nx: Vector2i = n + d
			if not region.has_point(nx) or not main.is_passable(nx):
				break
			# 일과 목적지가 있으면 그 둘레를 벗어나지 않는다
			if dest.x != -999 and (absi(nx.x - dest.x) > main.NPC_WANDER
					or absi(nx.y - dest.y) > main.NPC_WANDER):
				break
			n = nx
			steps += 1
		if steps > 0:
			target = Vector2(n.x * ts + ts / 2.0, n.y * ts + ts / 2.0)
			moving = true
			return
	wait = 0.6


func _update_sprite() -> void:
	var frame := (int(anim_time * 5.0) % 2) if moving else 0
	var key := ""
	sprite.flip_h = false
	match dir:
		"down":
			key = "down_%d" % frame
		"up":
			key = "up_%d" % frame
		_:
			key = "side_%d" % frame
			sprite.flip_h = dir == "left"
	sprite.texture = main.tex["npc_%s_%s" % [id, key]]
