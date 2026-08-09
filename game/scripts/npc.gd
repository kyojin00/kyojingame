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
	# (이장은 스토리 1 편지 전달 중에는 남아 있는다)
	var home_time: bool = GameData.is_evening() \
		and not (id == "chief" and GameData.story_phase == "travel")
	if visible == home_time:
		visible = not home_time
	if home_time:
		return
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
	var want: String = main.npc_place_now(id)
	if want == "":
		return
	if want != place:
		place = want
		dest = main.npc_place_tile(id, place)
		_route_cd = 0.0
	if dest.x == -999 or not route.is_empty():
		return
	var ts: int = main.TILE
	var t := Vector2i(int(floor(position.x / ts)), int(floor(position.y / ts)))
	# 목적지 근처(어슬렁 반경)에 있으면 다 온 것이다
	if absi(t.x - dest.x) <= main.NPC_WANDER and absi(t.y - dest.y) <= main.NPC_WANDER:
		return
	if _route_cd > 0.0:
		return
	_route_cd = 2.0   # 길이 막혀 있으면 잠시 뒤 다시 시도한다
	var p: Array = main._tile_path(t, dest)
	if p.is_empty():
		return
	route = p
	target = route.pop_front()
	moving = true


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
