# 탈 것 — 말을 타고 내린다 (F).
#
# 탄 동안에는 도구를 쓸 수 없다. 내리면 말은 옆 빈 칸에 서 있는다
# (`_free_spot_near`) — 벽에 끼어 사라지는 일이 없게.
#
# main의 것은 `m.`으로 부른다 (m = main.gd).
class_name KyojinRiding
extends Node

var m: KyojinMain    # main.gd


func toggle_ride() -> void:
	if GameData.riding:
		dismount_horse()
		return
	if not GameData.has_horse:
		m.hud.show_message("아직 말이 없다. 목장 상회에서 살 수 있다.")
		return
	# 가까이 있는 말에 올라탄다 (정확히 그 칸에 서 있지 않아도 된다)
	var here := m.player_tile()
	for r in range(0, 3):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var t: Vector2i = here + Vector2i(dx, dy)
				var o: Variant = m.objects.get(t)
				if o != null and o.kind == "horse":
					_mount_horse(t)
					return
	m.hud.show_message("말이 근처에 없다. 말을 세워 둔 곳으로 가자.")


func _mount_horse(t: Vector2i) -> void:
	m.objects.erase(t)
	if m.obj_nodes.has(t):
		m.obj_nodes[t].queue_free()
		m.obj_nodes.erase(t)
	GameData.riding = true
	Sound.play_sfx("sfx_place")
	m.hud.show_message("말에 올라탔다! F로 내린다.", 3.0)
	m.queue_redraw()


func place_horse() -> void:
	var spot := m.HORSE_HOME if not m.objects.has(m.HORSE_HOME) and m.is_passable(m.HORSE_HOME) \
		else _free_spot_near(m.HORSE_HOME)
	GameData.horse_tile = spot
	m.objects[spot] = {"kind": "horse", "hp": 0}
	m.objnode._spawn_object_node(spot, "horse")
	m.queue_redraw()


func _free_spot_near(from: Vector2i) -> Vector2i:
	for r in range(1, 6):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if absi(dx) != r and absi(dy) != r:
					continue          # 껍질만 훑는다 (가까운 곳부터)
				var t: Vector2i = from + Vector2i(dx, dy)
				if not m.objects.has(t) and m.is_passable(t):
					return t
	return from


func dismount_horse() -> void:
	if not GameData.riding:
		return
	GameData.riding = false
	# 지금 자리 근처의 빈 칸에 말을 세운다
	var here := m.player_tile()
	var spot: Vector2i = here if not m.objects.has(here) else _free_spot_near(here)
	GameData.horse_tile = spot
	m.objects[spot] = {"kind": "horse", "hp": 0}
	m.objnode._spawn_object_node(spot, "horse")
	Sound.play_sfx("sfx_place")
	m.hud.show_message("말에서 내렸다.", 2.0)
	m.queue_redraw()
