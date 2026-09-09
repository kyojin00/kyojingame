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

# 이번 도구질에 들 기력. 「일이 실제로 일어났을 때」만 빠진다 (`_charge`).
var _pending_cost := 0.0
var _charged := false
var _charge_night := false


# 기력을 뺀다 — 도구질 한 번에 한 번만.
# 휘두르는 동작이 나갔거나(swing_at) 밭이 갈렸거나 물이 들어갔을 때 부른다.
# 「여기는 갈 수 없다」처럼 헛손질로 끝난 경우에는 부르지 않는다.
func _charge() -> void:
	if _charged:
		return
	_charged = true
	if _pending_cost > 0.0:
		GameData.energy = maxf(0.0, GameData.energy - _pending_cost)
	_pending_cost = 0.0
	if _charge_night and randf() < 0.15:
		m.hud.show_message("어두워서 일이 손에 잡히지 않는다... 슬슬 돌아가서 쉬자.")


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
	m.hud.show_message("축사 완공! 농장(맵 서쪽) 에 세워졌다. 동물 %d마리까지.\n"
		% GameData.BARN_MAX_ANIMALS
		+ "울타리로 빈틈없이 둘러싸 목초지를 만들면 알아서 배부르다.", 6.0)
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
	# 레벨업은 **그 자리에서 알리지 않는다.** 하루를 마치고 잠들 때
	# 아침 결산에 「오늘 실력이 늘었다」로 한꺼번에 실린다 (game_data.levelup_report)
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
	# 여기 적히는 값도 잡화점이 실제로 세는 값이어야 한다 (개량 단계 포함)
	var qprice: int = GameData.crop_unit_price(cid, quality)
	match quality:
		2:
			m.hud.show_message("금빛 %s 수확! (판매가 %dG)" % [def.name, qprice])
		1:
			m.hud.show_message("은빛 %s 수확! (판매가 %dG)" % [def.name, qprice])
		_:
			m.hud.show_message("%s 수확! (판매가 %dG)" % [def.name, qprice])
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
	if not m.remote_acting and not GameData.tool_slots.has(GameData.tool):
		m.hud.show_message("가방(I)에서 도구를 슬롯에 장착하고 숫자키로 선택하자!")
		return
	# 도구를 쓰면 장비의 「기력 소모」만큼 힘이 든다.
	# 밤에는 그대로, 낮에는 가볍게. (수확은 맨손이라 들지 않는다)
	#
	# **여기서 바로 빼지 않는다.** 못 쓰는 자리에 헛손질하면 아무 일도 안
	# 일어나는데 기력만 닳는다 — 실제로 일이 됐을 때 `_charge`가 뺀다.
	_pending_cost = 0.0
	_charged = false
	_charge_night = false
	if not m.remote_acting:
		var night := GameData.is_night()
		var cost := GameData.tool_stat(GameData.tool, "stamina") \
			* (GameData.STAMINA_NIGHT_MULT if night else GameData.STAMINA_DAY_MULT) \
			* GameData.gear_stamina_mult()   # 장신구: 기력 절약
		# 컬렉션 「동굴의 광물」 완성 — 다 아는 자의 곡괭이는 가볍다
		if GameData.tool == "pickaxe":
			cost *= GameData.perk_pick_stamina_mult()
		_pending_cost = maxf(0.0, cost)
		_charge_night = night
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
				_charge()
				swing_motion(t)
				Sound.play_sfx("sfx_hoe", 0.1)
				m.hud.show_message("시든 작물을 정리했다.")
			elif obj != null:
				m.hud.show_message("여기는 갈 수 없다.")
				return
			elif cell.ground == "soil" and cell.crop_id == "":
				cell.ground = "grass"
				cell.watered = false
				cell.wet_min = 0.0
				m.dirty_tile(t.x, t.y)   # 그려 둔 그림을 버린다 (둘레 아홉 칸)
				_charge()
				swing_motion(t)
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
					m.dirty_tile(pos.x, pos.y)   # 그려 둔 그림을 버린다
					m.farming.touch(c)   # 갈아 놓은 흙도 「밭」이다 (하루가 넘어갈 때 여기만 돈다)
					if GameData.weather_wet(m.weather_now()):
						m.farming._wet(c, m.WET_ALL_DAY)
					m.renderer.spawn_particles(pos, "dirt")
					worked = true
					# 옛 농지를 다시 가는 일 — 다 갈고 나면 흙 속의 상자가 나온다
					if m.story.story16_dig_box(pos):
						return
					m.story.story16_field_work("till", pos)
					m.story.story20_till(pos)
				if worked:
					_charge()
					swing_motion(t)
					Sound.play_sfx("sfx_hoe", 0.1)
					m.tutorial_notify("till")
				else:
					m.hud.show_message("여기는 갈 곳이 아니다.")
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
					m.story.story20_water(pos)   # 할아버지의 씨앗에 주는 첫 물
					revived = revived or was_thirsty
			if worked:
				_charge()
				swing_motion(t)
				Sound.play_sfx("sfx_water", 0.1)
				m.tutorial_notify("water")
				if revived:
					m.hud.show_message("물을 머금은 작물이 다시 자라기 시작했다!", 4.0)
			elif m.grid[t.y][t.x].ground != "soil":
				m.hud.show_message("물을 줄 곳이 아니다.")
			elif m.grid[t.y][t.x].crop_id != "":
				# 비가 와서 이미 흠뻑 젖은 밭 — 물은 안 들어가도 배움은 넘어간다
				m.tutorial_notify("water")
				m.hud.show_message("이미 촉촉하다. 오늘은 물을 안 줘도 되겠다.")
		"seed":
			var id := m.forced_seed if m.forced_seed != "" else GameData.current_seed_id()
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
			_charge()
			Sound.play_sfx("sfx_seed", 0.1)
			m.renderer.spawn_particles(t, "seed")
			m.tutorial_notify("plant")
			GameData.move_seed_planted()   # 스토리 3-② 「씨앗 한 줌」
			gain_skill("farm", 2.0)
		"axe":
			if obj == null:
				# 벨 것이 없어도 그냥 휘두른다 — 밤 지네가 앞에 있으면
				# 무기처럼 히트박스 판정으로 때린다
				_swing_empty(t)
				return
			if obj.kind == "tree":
				if bool(obj.get("young", false)):
					m.hud.show_message("아직 어린 나무다. 다 자라면 벨 수 있다.")
					return
				if bool(obj.get("fixed", false)):
					# 이야기가 세워 둔 나무 — 베어서 뚫을 수 없다 (길은 정해져 있다)
					m.hud.show_message("나무가 너무 우거져 벨 엄두가 나지 않는다.")
					return
				obj.hp -= int(GameData.tool_stat("axe", "power"))
				Sound.play_sfx("sfx_chop", 0.15)
				var felled: bool = obj.hp <= 0
				# 판정은 여기서 끝난다. 그림이 바뀌는 것은 **날이 닿는 순간**이다 —
				# 마지막 한 방이면 그 박자에 맞춰 나무가 옆으로 쓰러지기 시작한다.
				if felled:
					swing_at(t, "wood", true)
					m.objnode._fell_tree(t, _fall_side(t))
				else:
					swing_at(t, "wood", false,
						func() -> void: m.objnode._refresh_tree_sprite(t))
				if felled:
					# 숲길을 막고 있던 나무는 다시 자라지 않는다 (길이 도로 막히면 안 된다)
					var story_gate: bool = GameData.story_phase != "done" \
						and m.STORY_GATE_XS.has(t.x) \
						and t.y >= m.STORY_ROAD_Y0 and t.y <= m.STORY_ROAD_Y1
					if not story_gate:
						# 3~5일 뒤, 맵의 빈자리 어딘가에서 새 나무가 자란다
						GameData.queue_respawn("tree")
					var wood_got := m.WOOD_PER_TREE
					if randf() < GameData.bonus_drop_chance("forest"):
						wood_got += 1
					GameData.wood += wood_got
					GameData.discover("wood")   # 도감 「기본 재료」 등록
					GameData.trees_chopped += 1
					m.hud.show_message("목재를 얻었다!")
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
				_charge()
				Sound.play_sfx("sfx_place")
				m.hud.show_message("울타리를 회수했다.")
			else:
				m.hud.show_message("도끼로 벨 수 없다.")
		"pickaxe":
			if obj == null:
				# 캘 것이 없어도 그냥 휘두른다 (히트박스 판정)
				_swing_empty(t)
				return
			if obj.kind == "rock":
				obj.hp -= int(GameData.tool_stat("pickaxe", "power"))
				Sound.play_sfx("sfx_pick", 0.15)
				swing_at(t, "stone")
				if obj.hp <= 0:
					# 돌도 곡괭이 날이 닿는 순간에 맞춰 튄다 (main.HIT_AT)
					m.objnode._remove_object(t, true, m.HIT_AT)
					GameData.queue_respawn("rock")   # 3~5일 뒤 다른 빈자리에서
					var stone_got := m.STONE_PER_ROCK
					if randf() < GameData.bonus_drop_chance("mine"):
						stone_got += 1
					GameData.stone += stone_got
					GameData.discover("stone")   # 도감 「기본 재료」 등록
					GameData.rocks_mined += 1
					m.hud.show_message("석재를 얻었다!")
					m.doing._maybe_drop_recipe("rock")
					m.tutorial_notify("mine")
					gain_skill("mine", 6.0)
				else:
					m.hud.show_message("돌을 내리쳤다.")
			elif obj.kind == "bigrock":
				# 길목의 바위 (스토리 1 바위 / 바닷길 바위 — 여러 번 캐야 부서진다)
				# 붙박이 바위는 이야기가 그 자리에 오기 전까지만 단단하다.
				# **바닷길이 이미 열렸다면 언제든 캘 수 있다** — 열린 뒤에 다시
				# 굴러든 바위가 길을 영영 막던 버그를 여기서 막는다.
				if bool(obj.get("fixed", false)) and GameData.fisher_quest != "open" \
						and not (GameData.sea_open and t in m.SEA_GATE):
					m.hud.show_message("바위가 어찌나 단단한지 곡괭이가 튕겨 나온다. 지금은 캘 도리가 없다.")
					return
				obj.hp -= 1
				Sound.play_sfx("sfx_pick", 0.15)
				swing_at(t, "stone", true)
				if obj.hp <= 0:
					# 돌도 곡괭이 날이 닿는 순간에 맞춰 튄다 (main.HIT_AT)
					m.objnode._remove_object(t, true, m.HIT_AT)
					GameData.stone += m.BIGROCK_STONE
					m.hud.show_message("석재를 얻었다!")
					m.doing._maybe_drop_recipe("bigrock")
					gain_skill("mine", 4.0)
					m.story._story_rock_mined()
					m.story._sea_gate_mined()
				else:
					m.hud.show_message("커다란 바위를 내리쳤다.")
			elif obj.kind == "sprinkler":
				m.objnode._remove_object(t)
				GameData.wood += GameData.SPRINKLER_COST_WOOD
				GameData.stone += GameData.SPRINKLER_COST_STONE
				_charge()
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
			_charge()
			Sound.play_sfx("sfx_place")
			var was: int = m.pasture.size()
			m.farming._recount_pasture()
			if m.pasture.size() > was:
				m.hud.event_toast("목초지 완성!")
				m.hud.show_message(
					"울타리가 닫혔다! 목초지 %d칸 — 안에 있는 동물은 알아서 배부르고 "
					% m.pasture.size() + "생산물도 더 준다.", 5.0)
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
			_charge()
			Sound.play_sfx("sfx_place")
			m.hud.show_message("스프링클러 설치! 주변 4칸에 계속 물을 준다.")
		"spear", "sword":
			_weapon_swing(t)
		"rod":
			if not GameData.can_fish():
				m.hud.show_message("낚시대가 없다...")
				return
			match m.fishing_state:
				"":
					_charge()
					m.fishing._start_fishing()
				"waiting":
					m.fishing_state = ""
					m.hud.show_message("아직 입질이 없다...")
				"bite":
					m.fishing_state = ""
					m.pending_fish = GameData.pick_fish()
					# 용식 호감도 50+ 특전: 판정 구간 25% 확대
					var zone: float = float(m.pending_fish.zone)
					if GameData.aff("fisher") >= 50:
						zone *= 1.25
					# 값이 나갈수록 손맛이 맵다 — 판매가에 비례해
					# 초록 판정 바가 확 좁아지고 커서가 훨씬 빨라진다
					var price := int(GameData.ITEMS.get(
						str(m.pending_fish.id), {}).get("sell", 0))
					var rare := clampf(float(price) / 800.0, 0.0, 1.0)
					zone *= 1.0 - 0.55 * rare
					var spd := float(m.pending_fish.speed) * (1.0 + 1.1 * rare)
					m.fishing_ui.start(zone, int(m.pending_fish.stages),
						spd, str(m.pending_fish.hint))
	# 멀티: 내 행동을 다른 플레이어에게 반영 (낚싯대는 로컬 진행)
	if not m.remote_acting:
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


# 나무는 도끼질한 사람의 **반대쪽**으로 넘어간다 (내 쪽으로 덮치면 이상하다).
# 정면에서 딱 맞춰 찍어 좌우가 갈리지 않으면 칸마다 정해진 쪽으로 넘긴다 —
# randf()를 쓰면 같은 나무가 볼 때마다 다른 쪽으로 쓰러진다.
func _fall_side(t: Vector2i) -> float:
	# 함께하기: 다른 사람이 벤 나무다. 여기 내 캐릭터 자리를 보면 엉뚱한 쪽으로
	# 넘어가니 칸으로만 정한다 (어느 화면에서 보든 같은 쪽으로 쓰러진다)
	if m.player == null or m.remote_acting:
		return 1.0 if m._hash01(t.x * 17 + 2, t.y * 23 + 9) > 0.5 else -1.0
	var d: float = float(t.x * m.TILE + 16) - m.player.position.x
	if absf(d) < 1.0:
		return 1.0 if m._hash01(t.x * 17 + 2, t.y * 23 + 9) > 0.5 else -1.0
	return signf(d)


# 도구를 휘두른다. `after`는 **날이 닿는 순간**에 한 번 불린다 —
# 손상 단계 그림 교체처럼 「눈에 보이는 일」을 여기 실어 보낸다.
func swing_at(t: Vector2i, particle: String, heavy: bool = false,
		after: Callable = Callable()) -> void:
	# 휘두르는 동작이 나갔다 = 일을 했다. 여기서 기력을 뺀다
	# (헛손질로 끝나는 길에서는 아예 여기까지 오지 않는다)
	_charge()
	swing_motion(t)
	m._pending_hits.append({"t": m.HIT_AT, "tile": t, "particle": particle,
		"heavy": heavy, "after": after})


# 판정 없이 **동작만**. 호미·물뿌리개처럼 「날이 닿는 순간」이 따로 없는
# 도구도 팔은 휘둘러야 한다 — 안 그러면 기력만 닳고 가만히 서 있다.
func swing_motion(t: Vector2i) -> void:
	if m.player == null:
		return
	var here := m.player_tile()
	var face := Vector2(t.x - here.x, t.y - here.y)
	if face == Vector2.ZERO:
		face = _dir_to_vec(m.player.dir)
	m.player.start_swing(GameData.tool, face.normalized(), m.SWING_TIME)


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
		_end_shake(node)   # 연타로 흔들림이 겹치면 기준 크기·자리가 밀린다
		var here := m.player_tile()
		var dir := Vector2(t.x - here.x, t.y - here.y)
		var spr: Sprite2D = node.get_child(0) as Sprite2D
		m._obj_shakes.append({"node": node, "base": node.position,
			"t": m.SHAKE_TIME,
			"dir": (dir.normalized() if dir != Vector2.ZERO else Vector2.DOWN),
			"spr": spr, "sc": (spr.scale if spr != null else Vector2.ONE)})
		# 나무는 맞을 때마다 우듬지에서 잎이 떨어진다
		if str(m.objects.get(t, {}).get("kind", "")) == "tree":
			m.renderer.spawn_burst(node.position + Vector2(16, -86), "leaf", 0.5, 14.0)
	# 그림 쪽 마무리 (손상 단계 교체 · 쓰러지기 시작)
	var after: Variant = h.get("after", null)
	if after is Callable and (after as Callable).is_valid():
		(after as Callable).call()
	if bool(h.heavy):
		m._cam_shake = 0.18
		m._cam_shake_amp = 3.0


# 흔들리던 대상을 원래 자리·크기로 되돌린다
func _restore_shake(sh: Dictionary) -> void:
	var nv: Variant = sh.node
	if is_instance_valid(nv):
		(nv as Node2D).position = sh.base
	var sv: Variant = sh.get("spr", null)
	if sv != null and is_instance_valid(sv):
		(sv as Sprite2D).scale = sh.sc


func _end_shake(node: Node2D) -> void:
	for sh in m._obj_shakes.duplicate():
		# 이미 사라진 대상도 이 김에 걷어낸다 (지운 노드와 비교하지 않으려는 뜻도 있다)
		var nv: Variant = sh.node
		if is_instance_valid(nv) and nv != node:
			continue
		_restore_shake(sh)
		m._obj_shakes.erase(sh)


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
			_restore_shake(sh)
			m._obj_shakes.erase(sh)
			continue
		var p: float = sh.t / m.SHAKE_TIME
		node.position = sh.base + sh.dir * sin(p * PI * 5.0) * 3.5 * p
		# 날이 파고들 때 그림이 납작하게 눌렸다 펴진다.
		# 원점이 밑동이라 위아래로 줄이면 밑동은 그대로 있고 우듬지만 내려앉는다.
		# p는 1(맞는 순간)에서 0으로 줄어든다 — 제일 눌린 곳이 맞는 그 프레임이다.
		var sv: Variant = sh.get("spr", null)
		if sv != null and is_instance_valid(sv):
			var base_sc: Vector2 = sh.sc
			var q: float = p * p * m.HIT_SQUASH
			(sv as Sprite2D).scale = Vector2(base_sc.x * (1.0 + q * 0.55),
				base_sc.y * (1.0 - q))
	# 화면 흔들림 (커다란 바위처럼 묵직한 것만)
	var cam := m.player.get_node_or_null("Camera") as Camera2D
	if cam != null:
		if m._cam_shake > 0.0:
			m._cam_shake = maxf(0.0, m._cam_shake - delta)
			var k: float = m._cam_shake_amp * (m._cam_shake / 0.18)
			cam.offset = Vector2(randf_range(-k, k), randf_range(-k, k))
		elif cam.offset != Vector2.ZERO:
			cam.offset = Vector2.ZERO


# ---- 초반 무기: 돌 창 · 돌 검 ----
#
# 밤에 나타나는 몬스터(지네)를 후려친다.
#   돌 창: 느리지만 한 방이 강하다 (지네를 한 방에)
#   돌 검: 빠르게 두 번 벤다 — 둘째 타는 순수 무기 위력만 (전체 화력은 비슷)
var _weapon_cd := 0.0   # main._process가 매 프레임 줄여 준다


# 허공 휘두르기 — 대상 오브젝트가 없어도 도끼·곡괭이는 그냥 휘둘러진다.
# 앞에 밤 몬스터(지네)가 있으면 무기와 같은 히트박스 판정으로 때린다.
# 순수 도구 위력만 들어간다 (전투 보너스·장비 위력은 무기 몫).
# 동굴 안은 cave_ui의 _attack이 이미 같은 규칙을 쓴다.
func _swing_empty(t: Vector2i) -> void:
	if _weapon_cd > 0.0:
		return
	_weapon_cd = 0.6
	swing_at(t, "dirt")
	_weapon_hit(false)


func _weapon_swing(t: Vector2i) -> void:
	if _weapon_cd > 0.0:
		return
	_weapon_cd = 1.1 if GameData.tool == "spear" else 0.8
	swing_at(t, "wood", GameData.tool == "spear")
	_weapon_hit(true)
	if GameData.tool == "sword":
		get_tree().create_timer(0.16).timeout.connect(_weapon_hit.bind(false))


func _weapon_hit(with_bonus: bool) -> void:
	var dmg: float = GameData.tool_stat(GameData.tool, "power")
	if with_bonus:
		dmg += GameData.combat_bonus() + GameData.gear_stat("power")
	var face: Vector2 = m.FACE_VECS[m.player.dir]
	for mob in m.night_mobs.duplicate():
		if not is_instance_valid(mob.node):
			continue
		var v: Vector2 = mob.node.position - m.player.position
		if v.length() > 74.0:
			continue
		if v.length() > 22.0 and v.normalized().dot(face) < 0.25:
			continue
		mob["hp"] = float(mob.get("hp", 4.0)) - dmg
		if float(mob.hp) <= 0.0:
			mob.node.queue_free()
			m.night_mobs.erase(mob)
			Sound.play_sfx("sfx_pick", 0.2)
			m.renderer.spawn_particles(m.player_tile(), "stone")
			gain_skill("combat", 6.0)
			if randf() < 0.3:
				m.doing.gain_item("arrow", 1)
				m.hud.show_message("지네를 쓰러뜨렸다! 화살을 떨어뜨렸다.")
			else:
				m.hud.show_message("지네를 쓰러뜨렸다!")
		else:
			# 밀려나며 잠시 주춤한다
			mob.node.position += v.normalized() * 44.0
