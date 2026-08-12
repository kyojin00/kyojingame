# 도구 쓰기 — 갈기·물주기·심기·베기·캐기·설치.
#
# `use_tool`이 한가운데다. 어느 칸에 무엇을 할지는 `_affected_tiles`가 정하고
# (스프링클러 범위처럼 여러 칸일 수 있다), 실제 타격은 **휘두르는 동작이
# 내려찍히는 순간**에 들어간다 (`swing_at` -> `_land_hit`). 그래서 도끼질과
# 나무가 쓰러지는 시점이 어긋나지 않는다.
#
# main의 것은 `m.`으로 부른다 (m = main.gd).
class_name KyojinTools
extends Node

var m: KyojinMain    # main.gd


func set_tool(t: String) -> void:
	if not GameData.is_tool_unlocked(t):
		m.hud.show_message("아직 열리지 않은 도구다. 목표를 달성하면 해금된다!")
		return
	if not GameData.tool_slots.has(t):
		# 획득 -> 가방(I)에서 슬롯 장착 -> 숫자키 선택 -> 사용 순서를 지킨다
		m.hud.show_message("가방(I)에서 빠른 슬롯에 장착해야 쓸 수 있다!")
		return
	if t != "rod":
		m.fishing.cancel_fishing()
	GameData.tool = t


func build_barn() -> void:
	if GameData.barn_built:
		return
	GameData.barn_built = true
	GameData.money -= GameData.BARN_COST_MONEY
	GameData.wood -= GameData.BARN_COST_WOOD
	m.objnode._place_object(m.BARN_POS, "barn", 0)
	m.worldgen._block_barn_art()
	Sound.play_sfx("sfx_place")
	m.hud.show_message("축사 완공! **농장(맵 서쪽)** 에 세워졌다. 동물 %d마리까지.\n"
		% GameData.BARN_MAX_ANIMALS
		+ "울타리로 빈틈없이 둘러싸 **목초지**를 만들면 알아서 배부르다.", 6.0)
	if Net.is_host():
		m.netsync._broadcast_stats()


func gain_legend(id: String) -> void:
	if int(GameData.items[id]) > 0:
		return  # 각 전설 재료는 하나면 충분하다
	m.doing.gain_item(id, 1)
	Sound.play_sfx("sfx_catch")
	m.hud.show_message("[전설 재료] %s 획득! 연구 노트(N)에 기록됐다." % GameData.ITEMS[id].name)


func gain_skill(id: String, amount: float) -> void:
	if GameData.is_night():
		amount = maxf(1.0, amount * 0.5)  # 밤에는 채집/작업 효율이 떨어진다
	m.float_texts.append({"text": "+%d %s" % [int(amount), GameData.SKILLS[id].name],
		"pos": m.player.position + Vector2(0, -100), "t": 0.0})
	var lv := GameData.add_skill_xp(id, amount)
	if lv > 0:
		Sound.play_sfx("sfx_catch")
		m.hud.show_message("[능력치] %s Lv.%d 달성! (%s)" %
			[GameData.SKILLS[id].name, lv, GameData.SKILLS[id].effect])
	if lv > 0 and Net.is_host():
		m.netsync._broadcast_stats()


func _affected_tiles(base: Vector2i) -> Array:
	# 장비 능력치의 「범위」를 그대로 쓴다 (1=1칸 / 2=전방 3칸 / 3=3x3)
	var lvl := int(GameData.tool_stat(GameData.tool, "reach"))
	if lvl >= 3:
		var out := []
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				out.append(base + Vector2i(dx, dy))
		return out
	if lvl >= 2:
		var perp: Vector2i = m.actions._current_perp()
		return [base, base + perp, base - perp]
	return [base]


func _tool_has_job(t: Vector2i) -> bool:
	if t.x < 0 or t.y < 0 or t.x >= m.MAP_W or t.y >= m.MAP_H:
		return false
	var cell: Dictionary = m.grid[t.y][t.x]
	match GameData.tool:
		"water":
			# 밭이면 언제든 물을 줄 수 있다.
			# 비가 와서 이미 젖어 있어도 「50% 체크포인트」 물주기는 남아 있으므로
			# 젖었는지로 판단하면 안 된다 (물뿌리개를 들었는데 수확이 가로챈다)
			return cell.ground == "soil"
		"hoe":
			return bool(cell.dead)  # 시든 작물 정리
	return false


func _try_harvest(t: Vector2i) -> bool:
	if t.x < 0 or t.y < 0 or t.x >= m.MAP_W or t.y >= m.MAP_H:
		return false
	var cell: Dictionary = m.grid[t.y][t.x]
	if cell.crop_id == "":
		return false
	if cell.dead:
		m.hud.show_message("시들어버렸다... 호미로 정리하자.")
		return true
	var cid: String = cell.crop_id
	var def: Dictionary = GameData.CROPS[cid]
	if float(cell.crop_day) < m.farming._grow_total(def):
		m.hud.show_message("아직 다 자라지 않았다.")
		return true
	var quality := GameData.roll_quality(GameData.total_luck())
	GameData.add_produce(cid, quality)
	GameData.today_harvest += 1
	match quality:
		2:
			m.hud.show_message("금빛 %s 수확! (판매가 %dG)" % [def.name, int(def.sell_price * 1.5)])
		1:
			m.hud.show_message("은빛 %s 수확! (판매가 %dG)" % [def.name, int(def.sell_price * 1.25)])
		_:
			m.hud.show_message("%s 수확! (판매가 %dG)" % [def.name, def.sell_price])
	cell.crop_id = ""
	cell.crop_day = 0.0
	cell.half_fed = false
	Sound.play_sfx("sfx_harvest")
	m.renderer.spawn_particles(t, "sparkle")
	m.tutorial_notify("harvest")
	gain_skill("farm", 8.0)
	if int(GameData.crops_harvested.get(cid, 0)) == 0:
		m.hud.show_message("연구 노트에 '%s' 기록이 추가됐다! (N)" % def.name)
	GameData.crops_harvested[cid] = int(GameData.crops_harvested.get(cid, 0)) + 1
	if randf() < 0.02:
		gain_legend("gold_crop")
	m.queue_redraw()
	return true


func use_tool() -> void:
	# 수확은 무엇을 들고 있든 된다.
	# 단 지금 든 도구가 그 칸에서 할 일이 있으면 도구가 먼저다 —
	# 물뿌리개로 덜 자란 작물에 물을 주려는데 "아직 다 자라지 않았다"로
	# 막히면 안 된다.
	if not _tool_has_job(m.actions.target_tile()) and _try_harvest(m.actions.target_tile()):
		return
	# 그 밖의 도구는 슬롯에 장착하고 직접 선택해 손에 든 상태여야만 쓸 수 있다
	if not m._remote_acting and not GameData.tool_slots.has(GameData.tool):
		m.hud.show_message("가방(I)에서 도구를 슬롯에 장착하고 숫자키로 선택하자!")
		return
	# 도구를 쓰면 장비의 「기력 소모」만큼 힘이 든다.
	# 밤에는 그대로, 낮에는 가볍게. (수확은 맨손이라 들지 않는다)
	if not m._remote_acting:
		var night := GameData.is_night()
		var cost := GameData.tool_stat(GameData.tool, "stamina") \
			* (GameData.STAMINA_NIGHT_MULT if night else GameData.STAMINA_DAY_MULT) \
			* GameData.gear_stamina_mult()   # 장신구: 기력 절약
		if cost > 0.0:
			GameData.energy = maxf(0.0, GameData.energy - cost)
		if night and randf() < 0.15:
			m.hud.show_message("어두워서 일이 손에 잡히지 않는다... 슬슬 돌아가서 쉬자.")
	var t: Vector2i = m.actions.target_tile()
	if t.x < 0 or t.y < 0 or t.x >= m.MAP_W or t.y >= m.MAP_H:
		return
	var cell: Dictionary = m.grid[t.y][t.x]
	var obj: Variant = m.objects.get(t)
	var seed_now := GameData.current_seed_id()

	match GameData.tool:
		"hoe":
			if cell.crop_id != "" and cell.dead:
				# 시든 작물 정리
				cell.crop_id = ""
				cell.crop_day = 0
				cell.dead = false
				cell.half_fed = false
				Sound.play_sfx("sfx_hoe", 0.1)
				m.hud.show_message("시든 작물을 정리했다.")
			elif obj != null:
				m.hud.show_message("여기는 갈 수 없다.")
				return
			elif cell.ground == "soil" and cell.crop_id == "":
				cell.ground = "grass"
				cell.watered = false
				cell.wet_min = 0.0
				Sound.play_sfx("sfx_hoe", 0.1)
			else:
				var worked := false
				for pos: Vector2i in _affected_tiles(t):
					if pos.x < 0 or pos.y < 0 or pos.x >= m.MAP_W or pos.y >= m.MAP_H:
						continue
					var c: Dictionary = m.grid[pos.y][pos.x]
					if m.objects.has(pos) or c.ground != "grass":
						continue
					c.ground = "soil"
					if GameData.weather_wet(m.weather_now()):
						m.farming._wet(c, m.WET_ALL_DAY)
					m.renderer.spawn_particles(pos, "dirt")
					worked = true
				if worked:
					Sound.play_sfx("sfx_hoe", 0.1)
					m.tutorial_notify("till")
		"water":
			var worked := false
			var revived := false
			for pos: Vector2i in _affected_tiles(t):
				if pos.x < 0 or pos.y < 0 or pos.x >= m.MAP_W or pos.y >= m.MAP_H:
					continue
				var c: Dictionary = m.grid[pos.y][pos.x]
				var was_thirsty: bool = m.farming._crop_thirsty(c)
				if c.ground == "soil" and not m.objects.has(pos) \
						and (float(c.wet_min) < m.WET_MANUAL - 1.0 or was_thirsty):
					m.farming._wet(c, m.WET_MANUAL)
					m.renderer.spawn_particles(pos, "water")
					worked = true
					revived = revived or was_thirsty
			if worked:
				Sound.play_sfx("sfx_water", 0.1)
				m.tutorial_notify("water")
				if revived:
					m.hud.show_message("물을 머금은 작물이 다시 자라기 시작했다!", 4.0)
			elif m.grid[t.y][t.x].ground != "soil":
				m.hud.show_message("물을 줄 곳이 아니다.")
		"seed":
			var id := m._forced_seed if m._forced_seed != "" else GameData.current_seed_id()
			if id == "":
				m.hud.show_message("씨앗이 없다. 마을 잡화점에서 사자.")
				return
			if cell.ground != "soil" or obj != null:
				m.hud.show_message("먼저 호미로 밭을 갈자.")
				return
			if cell.crop_id != "":
				m.hud.show_message("이미 작물이 자라고 있다.")
				return
			var def: Dictionary = GameData.CROPS[id]
			if GameData.season() not in def.seasons and not m.village.in_greenhouse(t):
				m.hud.show_message("%s은(는) 지금 계절에 자라지 않는다. (온실에서는 된다)"
					% def.name)
				return
			GameData.seeds[id] -= 1
			cell.crop_id = id
			m.farming.touch(cell)
			cell.crop_day = 0.0
			cell.dead = false
			cell.half_fed = false
			if GameData.weather_wet(m.weather_now()):
				m.farming._wet(cell, m.WET_ALL_DAY)
			Sound.play_sfx("sfx_seed", 0.1)
			m.renderer.spawn_particles(t, "seed")
			m.tutorial_notify("plant")
			gain_skill("farm", 2.0)
		"axe":
			if obj == null:
				m.hud.show_message("벨 것이 없다.")
				return
			if obj.kind == "tree":
				if bool(obj.get("young", false)):
					m.hud.show_message("아직 어린 나무다. 다 자라면 벨 수 있다.")
					return
				obj.hp -= int(GameData.tool_stat("axe", "power"))
				Sound.play_sfx("sfx_chop", 0.15)
				swing_at(t, "wood")
				m.objnode._refresh_tree_sprite(t)
				if obj.hp <= 0:
					m.objnode._remove_object(t, true)
					# 숲길을 막고 있던 나무는 다시 자라지 않는다 (길이 도로 막히면 안 된다)
					var story_gate: bool = GameData.story_phase != "done" \
						and m.STORY_GATE_XS.has(t.x) \
						and t.y >= m.STORY_ROAD_Y0 and t.y <= m.STORY_ROAD_Y1
					if not story_gate:
						GameData.tree_regrow.append([t.x, t.y, 1])  # 다음 날 어린 나무
					var wood_got := m.WOOD_PER_TREE
					if randf() < GameData.bonus_drop_chance("forest"):
						wood_got += 1
					GameData.wood += wood_got
					GameData.trees_chopped += 1
					m.hud.show_message("나무를 베었다! 목재 +%d" % wood_got)
					m.doing._maybe_drop_recipe("tree")
					# 길목을 뚫었다면 진행도를 갱신한다
					if story_gate:
						var before_gates := int(GameData.story_gates_left)
						m.story._refresh_story_gates()
						if GameData.story_gates_left < before_gates:
							if GameData.story_gates_left > 0:
								m.hud.show_message("길이 뚫렸다! (남은 길목 %d곳)"
									% GameData.story_gates_left, 4.0)
							else:
								m.hud.show_message("숲길이 끝까지 열렸다!", 4.0)
					m.story._story_tree_chopped()
					m.tutorial_notify("chop")
					gain_skill("forest", 3.0)
					# 15그루째: 우체부 아저씨가 능력치 창(U)을 알려준다
					if GameData.u_intro_state == 0 and GameData.trees_chopped >= 15 \
							and m.story._postman != null and m.story._postman_state == "follow":
						GameData.u_intro_state = 1
						get_tree().create_timer(1.0).timeout.connect(m.story._start_u_intro_dialog)
					if randf() < 0.02:
						gain_legend("world_branch")
				elif obj.hp == 2:
					m.hud.show_message("나무를 베었다! (1/%d)" % m.TREE_HP)
				else:
					m.hud.show_message("나무가 쓰러지기 직전이다! (2/%d)" % m.TREE_HP)
			elif obj.kind == "fence":
				if bool(obj.get("fixed", false)):
					m.hud.show_message("단단히 박힌 울타리다. 길을 따라 가야 한다.")
					return
				m.objnode._remove_object(t)
				GameData.wood += GameData.FENCE_COST_WOOD
				m.farming._recount_pasture()   # 울타리를 걷으면 목초지가 풀린다
				Sound.play_sfx("sfx_place")
				m.hud.show_message("울타리를 회수했다.")
			else:
				m.hud.show_message("도끼로 벨 수 없다.")
		"pickaxe":
			if obj == null:
				m.hud.show_message("캘 것이 없다.")
				return
			if obj.kind == "rock":
				obj.hp -= int(GameData.tool_stat("pickaxe", "power"))
				Sound.play_sfx("sfx_pick", 0.15)
				swing_at(t, "stone")
				if obj.hp <= 0:
					m.objnode._remove_object(t, true)
					var stone_got := m.STONE_PER_ROCK
					if randf() < GameData.bonus_drop_chance("mine"):
						stone_got += 1
					GameData.stone += stone_got
					m.hud.show_message("돌을 캤다! 석재 +%d" % stone_got)
					m.doing._maybe_drop_recipe("rock")
					m.tutorial_notify("mine")
					gain_skill("mine", 6.0)
				else:
					m.hud.show_message("돌을 내리쳤다. (%d/%d)" % [m.ROCK_HP - obj.hp, m.ROCK_HP])
			elif obj.kind == "bigrock":
				# 길목의 바위 (스토리 1 바위 / 바닷길 바위 — 여러 번 캐야 부서진다)
				if bool(obj.get("fixed", false)) and GameData.fisher_quest != "open":
					m.hud.show_message("바위가 어찌나 단단한지 곡괭이가 튕겨 나온다. 지금은 캘 도리가 없다.")
					return
				obj.hp -= 1
				Sound.play_sfx("sfx_pick", 0.15)
				swing_at(t, "stone", true)
				if obj.hp <= 0:
					m.objnode._remove_object(t, true)
					GameData.stone += m.BIGROCK_STONE
					m.hud.show_message("커다란 바위를 캐냈다! 돌 +%d" % m.BIGROCK_STONE)
					m.doing._maybe_drop_recipe("bigrock")
					gain_skill("mine", 4.0)
					m.story._story_rock_mined()
					m.story._sea_gate_mined()
				else:
					m.hud.show_message("커다란 바위를 내리쳤다. (%d/%d)" %
						[m.BIGROCK_HP - obj.hp, m.BIGROCK_HP])
			elif obj.kind == "sprinkler":
				m.objnode._remove_object(t)
				GameData.wood += GameData.SPRINKLER_COST_WOOD
				GameData.stone += GameData.SPRINKLER_COST_STONE
				Sound.play_sfx("sfx_place")
				m.hud.show_message("스프링클러를 회수했다.")
			else:
				m.hud.show_message("곡괭이로 캘 수 없다.")
		"fence":
			if obj != null or cell.ground == "water" or cell.crop_id != "" \
					or m.actions._tile_overlaps_player(t):
				m.hud.show_message("여기에는 설치할 수 없다.")
				return
			if GameData.wood < GameData.FENCE_COST_WOOD:
				m.hud.show_message("목재가 부족하다. (목재 %d 필요)" % GameData.FENCE_COST_WOOD)
				return
			GameData.wood -= GameData.FENCE_COST_WOOD
			m.objnode._place_object(t, "fence", 0)
			Sound.play_sfx("sfx_place")
			var was: int = m.pasture.size()
			m.farming._recount_pasture()
			if m.pasture.size() > was:
				m.hud.quest_toast("목초지 완성!")
				m.hud.show_message(
					"울타리가 닫혔다! 목초지 %d칸 — 안에 있는 동물은 알아서 배부르고 "
					% m.pasture.size() + "생산물도 더 준다.", 5.0)
			m.tutorial_notify("build")
		"sprinkler":
			if obj != null or cell.ground == "water" or cell.crop_id != "" \
					or m.actions._tile_overlaps_player(t):
				m.hud.show_message("여기에는 설치할 수 없다.")
				return
			if GameData.wood < GameData.SPRINKLER_COST_WOOD or GameData.stone < GameData.SPRINKLER_COST_STONE:
				m.hud.show_message("재료 부족: 목재 %d + 석재 %d 필요" %
					[GameData.SPRINKLER_COST_WOOD, GameData.SPRINKLER_COST_STONE])
				return
			GameData.wood -= GameData.SPRINKLER_COST_WOOD
			GameData.stone -= GameData.SPRINKLER_COST_STONE
			m.objnode._place_object(t, "sprinkler", 0)
			m.farming._sprinkle(t)                      # 설치하자마자 바로 적신다
			Sound.play_sfx("sfx_place")
			m.hud.show_message("스프링클러 설치! 주변 4칸에 계속 물을 준다.")
			m.tutorial_notify("build")
		"rod":
			match m.fishing_state:
				"":
					m.fishing._start_fishing()
				"waiting":
					m.fishing_state = ""
					m.hud.show_message("아직 입질이 없다...")
				"bite":
					m.fishing_state = ""
					m.pending_fish = GameData.pick_fish()
					# 철수 호감도 50+ 특전: 판정 구간 25% 확대
					var zone: float = float(m.pending_fish.zone)
					if int(GameData.affinity["fisher"]) >= 50:
						zone *= 1.25
					# 귀한 물고기일수록 여러 번 · 좁게 · 빠르게 (game_data.FISH)
					m.fishing_ui.start(zone, int(m.pending_fish.stages),
						float(m.pending_fish.speed), str(m.pending_fish.hint))
	# 멀티: 내 행동을 다른 플레이어에게 반영 (낚싯대는 로컬 진행)
	if not m._remote_acting:
		if Net.is_guest() and GameData.tool != "rod":
			m.netsync._req_tool.rpc_id(1, t.x, t.y, GameData.tool, seed_now,
				m.actions._current_perp().x, m.actions._current_perp().y)
		elif Net.is_host():
			m.netsync._broadcast_area(t)
			m.netsync._broadcast_stats()
	m.queue_redraw()


func _tool_target_nearby() -> Vector2i:
	if m.player == null:
		return Vector2i(-999, -999)
	var want: Array = []
	match GameData.tool:
		"axe":
			want = ["tree"]
		"pickaxe":
			want = ["rock", "bigrock"]
		_:
			return Vector2i(-999, -999)
	# 두 칸까지 본다. 커다란 바위는 충돌 박스가 넓어 한 칸 밖에 못 서는 경우가 있다.
	var pt := m.player_tile()
	var best := Vector2i(-999, -999)
	var best_d := 1e9
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var n: Vector2i = pt + Vector2i(dx, dy)
			var obj: Variant = m.objects.get(n)
			if obj == null or not want.has(obj.kind) or bool(obj.get("young", false)):
				continue
			var d: float = (Vector2(n.x * m.TILE + 16, n.y * m.TILE + 16) - m.player.position).length()
			if d < best_d:
				best_d = d
				best = n
	return best


func swing_at(t: Vector2i, particle: String, heavy: bool = false) -> void:
	var here := m.player_tile()
	var face := Vector2(t.x - here.x, t.y - here.y)
	if face == Vector2.ZERO:
		face = _dir_to_vec(m.player.dir)
	m.player.start_swing(GameData.tool, face.normalized(), m.SWING_TIME)
	m._pending_hits.append({"t": m.HIT_AT, "tile": t, "particle": particle, "heavy": heavy})


func _dir_to_vec(d: String) -> Vector2:
	match d:
		"up":
			return Vector2.UP
		"left":
			return Vector2.LEFT
		"right":
			return Vector2.RIGHT
		_:
			return Vector2.DOWN


func _land_hit(h: Dictionary) -> void:
	var t: Vector2i = h.tile
	m.renderer.spawn_particles(t, str(h.particle))
	if m.obj_nodes.has(t):
		var node: Node2D = m.obj_nodes[t]
		var here := m.player_tile()
		var dir := Vector2(t.x - here.x, t.y - here.y)
		m._obj_shakes.append({"node": node, "base": node.position,
			"t": m.SHAKE_TIME, "dir": (dir.normalized() if dir != Vector2.ZERO else Vector2.DOWN)})
	if bool(h.heavy):
		m._cam_shake = 0.18
		m._cam_shake_amp = 3.0


func _update_hit_fx(delta: float) -> void:
	for h in m._pending_hits:
		h.t -= delta
	for h in m._pending_hits.duplicate():
		if h.t <= 0.0:
			m._pending_hits.erase(h)
			_land_hit(h)
	for sh in m._obj_shakes.duplicate():
		sh.t -= delta
		# 흔들리는 도중에 다 캐서 노드가 사라질 수 있다.
		# 형을 붙여 받으면 **대입하는 순간** 오류가 나므로 Variant로 먼저 받는다.
		var nv: Variant = sh.node
		if not is_instance_valid(nv):
			m._obj_shakes.erase(sh)
			continue
		var node: Node2D = nv
		if sh.t <= 0.0:
			node.position = sh.base
			m._obj_shakes.erase(sh)
			continue
		var p: float = sh.t / m.SHAKE_TIME
		node.position = sh.base + sh.dir * sin(p * PI * 5.0) * 3.5 * p
	# 화면 흔들림 (커다란 바위처럼 묵직한 것만)
	var cam := m.player.get_node_or_null("Camera") as Camera2D
	if cam != null:
		if m._cam_shake > 0.0:
			m._cam_shake = maxf(0.0, m._cam_shake - delta)
			var k: float = m._cam_shake_amp * (m._cam_shake / 0.18)
			cam.offset = Vector2(randf_range(-k, k), randf_range(-k, k))
		elif cam.offset != Vector2.ZERO:
			cam.offset = Vector2.ZERO
