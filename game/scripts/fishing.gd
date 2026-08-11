# 낚시 — 물가에 서서 던지고, 미니게임(fishing_ui.gd)으로 끌어올린다.
#
# 여기는 「언제 던질 수 있고, 끝나면 무엇을 주는가」까지만 본다.
# 잡는 동안의 게이지는 fishing_ui.gd에 있다.
#
# main의 것은 `m.`으로 부른다 (m = main.gd).
class_name KyojinFishing
extends Node

var m: KyojinMain    # main.gd


func cancel_fishing() -> void:
	m.fishing_state = ""


func at_fishing_spot() -> bool:
	return m.FISH_SPOT.has_point(m.player_tile())


func fishing_spot_center() -> Vector2:
	var p: Vector2i = m.FISH_PIERS[0]
	return Vector2(p.x * m.TILE + 16, (m.VILLAGE_RIVER_Y + m.RIVER_ROWS - 2) * m.TILE + 16)


func _start_fishing() -> void:
	var t: Vector2i = m.actions.target_tile()
	if t.x < 0 or t.y < 0 or t.x >= m.MAP_W or t.y >= m.MAP_H \
			or m.grid[t.y][t.x].ground != "water":
		m.hud.show_message("물가를 보고 낚싯대를 던지자.")
		return
	# 「낚시」 목표를 받은 동안에는 마을 남쪽 낚시터에서 배운다.
	# (목표를 끝낸 뒤에는 어느 물가에서든 낚을 수 있다)
	if GameData.tutorial_current_flag() == "fish" and not at_fishing_spot():
		m.hud.show_message("마을 남쪽 강가의 낚시터로 가자! 부두에서 낚싯대를 던진다. (지도 M)", 4.0)
		return
	if not m.actions.can_use_tile(t):
		m.hud.show_message("아직 구입하지 않은 부지의 물이다. 표지판(E)에서 구입하자!")
		return
	m.fishing_state = "waiting"
	m.fishing_timer = randf_range(1.5, 4.0) * GameData.fish_wait_mult()
	Sound.play_sfx("sfx_cast")


func _update_fishing(delta: float) -> void:
	if m.fishing_state == "waiting":
		m.fishing_timer -= delta
		if m.fishing_timer <= 0.0:
			m.fishing_state = "bite"
			m.fishing_timer = 0.9
			Sound.play_sfx("sfx_bite")
	elif m.fishing_state == "bite":
		m.fishing_timer -= delta
		if m.fishing_timer <= 0.0:
			m.fishing_state = ""
			m.hud.show_message("물고기가 도망갔다...")


func _on_fishing_finished(success: bool) -> void:
	if m.pending_fish.is_empty():
		return          # 무엇이 물었는지 모르는 채로 끝났다 (있어선 안 되는 경우)
	if success:
		var id: String = m.pending_fish[0]
		var def: Dictionary = GameData.ITEMS[id]
		GameData.items[id] += 1
		GameData.fish_caught[id] = int(GameData.fish_caught.get(id, 0)) + 1
		GameData.today_harvest += 1
		Sound.play_sfx("sfx_catch")
		m.renderer.spawn_particles(m.player_tile(), "sparkle")
		m.hud.show_message("%s를 낚았다! (%dG)" % [def.name, def.sell])
		m.tutorial_notify("fish")
		# 여름 낚시대회: 대회 시간 안에 낚시터에서 낚은 것만 센다
		if GameData.festival_open() and str(GameData.festival_today().id) == "fishing" \
				and at_fishing_spot():
			GameData.fest_fish += 1
			if GameData.fest_fish == 5:
				m.hud.show_message("5마리! 이장에게 결과를 알리자.", 4.0)
		m.toolwork.gain_skill("fish", 10.0)
		if Net.is_guest():
			# 로컬 반영분은 호스트 통계 브로드캐스트로 덮어써 수렴한다
			GameData.items[id] -= 1
			GameData.fish_caught[id] = int(GameData.fish_caught[id]) - 1
			m.netsync._req_gain.rpc_id(1, id, 1)
		elif Net.is_host():
			m.netsync._broadcast_stats()
	else:
		Sound.play_sfx("sfx_miss")
		m.hud.show_message("놓쳤다...")
