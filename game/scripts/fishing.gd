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
	# 강가 잔디밭 한가운데 (부두는 없어졌다 — 물가에 서서 던진다)
	var cx := (m.FISH_YARD_X0 + m.FISH_YARD_X1) / 2
	return Vector2(cx * m.TILE + 16, m.DOCK_Y * m.TILE + 16)


func _start_fishing() -> void:
	var t: Vector2i = m.actions.target_tile()
	if t.x < 0 or t.y < 0 or t.x >= m.MAP_W or t.y >= m.MAP_H \
			or m.grid[t.y][t.x].ground != "water":
		m.hud.show_message("물가를 보고 낚싯대를 던지자.")
		return
	# 「낚시」 목표를 받은 동안에는 마을 남쪽 낚시터에서 배운다.
	# (목표를 끝낸 뒤에는 어느 물가에서든 낚을 수 있다)
	if GameData.tutorial_current_flag() == "fish" and not at_fishing_spot():
		m.hud.show_message("마을 남쪽 강가의 낚시터로 가자! 물가에 서서 낚싯대를 던진다. (지도 M)", 4.0)
		return
	if not m.actions.can_use_tile(t):
		m.hud.show_message("아직 구입하지 않은 부지의 물이다. 표지판(E)에서 구입하자!")
		return
	m.fishing_state = "waiting"
	m.fishing_timer = randf_range(1.5, 4.0) * GameData.fish_wait_mult()
	# 해변 노점에서 산 미끼 — 던질 때 하나씩 쓰고, 입질이 훨씬 빨리 온다
	if int(GameData.items.get("bait", 0)) > 0:
		GameData.items["bait"] = int(GameData.items["bait"]) - 1
		m.fishing_timer *= 0.45
		m.hud.show_message("미끼를 꿰었다 — 입질이 빨리 온다! (남은 미끼 %d)"
			% int(GameData.items["bait"]))
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
		# 특별한 입질 (메인 스토리 13) — 두 분의 바위 곁에서는 물고기 대신
		# 바다가 간직해 온 「낡은 작은 상자」가 올라온다
		if m.story.story13_special_bite():
			m.toolwork.gain_skill("fish", 10.0)
			return
		var id: String = str(m.pending_fish.id)
		var def: Dictionary = GameData.ITEMS[id]
		GameData.items[id] += 1
		GameData.discover(id)
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
