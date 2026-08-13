# 하루가 넘어가는 흐름과 밤.
#
# 잠들면 하루가 넘어가고, 그 사이에 작물이 자라고 자원이 되살아나고 날씨가
# 바뀐다 (`_next_day`). 밤에는 화면이 어두워지고 지네가 돌아다닌다.
#
# main의 것은 `m.`으로 부른다 (m = main.gd).
class_name KyojinDayCycle
extends Node

var m: KyojinMain    # main.gd


func request_sleep() -> void:
	if not GameData.has_bed:
		m.hud.show_message("잘 침대가 없다. 침대 자리에서 침대를 만들자 (목재 %d)." %
			GameData.BED_WOOD)
		return
	if Net.is_guest():
		m.hud.show_message("하루는 호스트가 잠자리에 들어야 넘어간다.")
	else:
		m.sleep_dialog.popup_centered()


func _update_night_mobs(delta: float) -> void:
	m._mob_hit_cd = maxf(0.0, m._mob_hit_cd - delta)
	var outdoors := not m.interior.visible and not m.cave.visible \
		and GameData.story_phase == "done" and not Net.is_guest()
	if not GameData.is_deep_night() or not outdoors:
		if not m.night_mobs.is_empty():
			for mob in m.night_mobs:
				mob.node.queue_free()
			m.night_mobs.clear()
		return
	# 최대 2마리, 플레이어에서 조금 떨어진 곳에서 스멀스멀 나타난다
	m._mob_spawn_cd -= delta
	if m.night_mobs.size() < 2 and m._mob_spawn_cd <= 0.0:
		m._mob_spawn_cd = 6.0
		var ang := randf() * TAU
		var node := Node2D.new()
		node.position = m.player.position + Vector2.from_angle(ang) * 380.0
		var spr := Sprite2D.new()
		spr.texture = m.tex["mob_centipede_0"]
		spr.scale = Vector2(1.4, 1.4)
		node.add_child(spr)
		m.world.add_child(node)
		# hp: 돌 창(강타)은 한 방, 돌 검(연격)은 두 번 휘둘러야 잡는다
		m.night_mobs.append({"node": node, "spr": spr, "anim": 0.0, "hp": 4.0})
		m.hud.show_message("어둠 속에서 무언가 기어오는 소리가 들린다...", 4.0)
	# 루프 변수 이름을 mob으로 둔다. 예전에는 이것도 `m`이었는데, 모듈에서는
	# `m`이 main이라 안쪽에서 main을 통째로 가려 버린다.
	for mob in m.night_mobs:
		mob.anim += delta
		var to: Vector2 = m.player.position - mob.node.position
		if to.length() > 8.0:
			mob.node.position += to.normalized() * 55.0 * delta
		mob.spr.texture = m.tex["mob_centipede_%d" % (int(mob.anim * 8.0) % 2)]
		mob.spr.flip_h = to.x > 0.0  # 머리가 진행 방향을 향한다
		# 접촉 피해
		if to.length() < 22.0 and m._mob_hit_cd <= 0.0 and not m.ui_open():
			m._mob_hit_cd = 1.2
			GameData.energy = maxf(0.0, GameData.energy - 10.0)
			Sound.play_sfx("sfx_chop", 0.2)
			m.renderer.spawn_particles(m.player_tile(), "stone")
			m.hud.show_message("지네에게 물렸다! 밤의 숲은 위험하다...", 3.0)
			m.player.position += (m.player.position - mob.node.position).normalized() * 36.0
			if GameData.energy <= 0.0 and not m.day_transitioning:
				m.hud.show_message("정신을 잃고 쓰러졌다...")
				# 밤 몬스터에게 당해 기절 — 다음 날 아침 이장이 찾아온다 (서브퀘)
				if GameData.spear_quest == "":
					GameData.spear_quest = "pending"
				_fade_next_day(true)


func _fade_next_day(passed_out: bool) -> void:
	if m.day_transitioning:
		return
	m.day_transitioning = true
	var tw := create_tween()
	tw.tween_property(m.fade_rect, "color:a", 1.0, 0.4)
	tw.tween_callback(_next_day.bind(passed_out))
	tw.tween_property(m.fade_rect, "color:a", 0.0, 0.4)
	tw.tween_callback(func() -> void: m.day_transitioning = false)


func _next_day(passed_out: bool) -> void:
	# 밤사이 밭은 마른다 (성장은 실시간 _growth_tick에서)
	for y in m.MAP_H:
		for x in m.MAP_W:
			var cell: Dictionary = m.grid[y][x]
			cell.watered = false
			cell.wet_min = 0.0

	if m.cave.visible:
		m.cave.visible = false  # 새벽이 되면 동굴에서 나온다
	var stats := [GameData.today_harvest, GameData.today_earned, GameData.today_spent]
	var prev_season := GameData.season()
	GameData.day += 1
	GameData.minutes = GameData.DAY_START
	# 침대가 좋을수록 잘 잔다 — 낡은 침대 70% · 나무 100% · 푹신 100%(+쓰러짐 완화)
	GameData.energy = GameData.ENERGY_MAX * GameData.bed_wake_mult(passed_out)
	GameData.reset_daily()
	m.worldgen._advance_tree_growth()

	# 계절이 바뀌면 제철 아닌 작물은 시든다
	var season_changed := GameData.season() != prev_season
	var wilted := 0
	if season_changed:
		for y in m.MAP_H:
			for x in m.MAP_W:
				var cell: Dictionary = m.grid[y][x]
				if cell.crop_id != "" and not cell.dead \
						and GameData.season() not in GameData.CROPS[cell.crop_id].seasons \
						and not m.village.in_greenhouse(Vector2i(x, y)):
					cell.dead = true
					wilted += 1
		m.objnode._apply_season_visuals()

	# 폭풍이 지나간 아침: 자란 작물 일부가 상하고, 대신 목재가 잔뜩 떨어져 있다
	var storm_hurt := 0
	var storm_wood := 0
	if m.weather_now() == GameData.WEATHER_STORM:
		for y in m.MAP_H:
			for x in m.MAP_W:
				var sc: Dictionary = m.grid[y][x]
				if sc.crop_id != "" and not sc.dead and randf() < m.STORM_CROP_HURT:
					sc.crop_day = maxf(0.0, float(sc.crop_day) - 60.0 * 12.0)
					storm_hurt += 1
		storm_wood = randi_range(m.STORM_WOOD_MIN, m.STORM_WOOD_MAX)
		GameData.wood += storm_wood

	# 비·폭풍이 온 날은 밭이 하루 종일 젖어 있다
	if GameData.weather_wet(m.weather_now()):
		for y in m.MAP_H:
			for x in m.MAP_W:
				if m.grid[y][x].ground == "soil":
					m.farming._wet(m.grid[y][x], m.WET_ALL_DAY)

	m.farming._sprinkler_tick()

	# 축사가 있으면 굳은 날씨에도 동물들이 알아서 배부르다
	if GameData.barn_built and GameData.weather_harsh(m.weather_now()):
		for a2 in m.animals:
			a2.fed = true

	# 목초지(울타리로 둘러싼 곳)의 동물은 알아서 배부르다
	m.farming._recount_pasture()
	var penned := 0
	for a3 in m.animals:
		if m.farming.in_pasture(Vector2i(int(a3.position.x / m.TILE), int(a3.position.y / m.TILE))):
			a3.fed = true
			penned += 1

	# 동물 생산물 수거
	var collected := {}
	for a in m.animals:
		if a.fed:
			var in_pen: bool = m.farming.in_pasture(Vector2i(int(a.position.x / m.TILE),
				int(a.position.y / m.TILE)))
			var product: String = GameData.ANIMALS[a.type].product
			var n_out := 2 if (in_pen and randf() < m.PASTURE_BONUS) else 1
			GameData.items[product] += n_out
			collected[product] = int(collected.get(product, 0)) + n_out
			GameData.discover(product)
			var egg_chance: float = m.PASTURE_GOLDEN_EGG if in_pen else 0.03
			if a.type == "chicken" and randf() < egg_chance \
					and int(GameData.items["golden_egg"]) == 0:
				GameData.items["golden_egg"] += 1
				collected["golden_egg"] = 1
				GameData.discover("golden_egg")
		a.fed = false

	# 나무/돌이 조금씩 다시 자란다
	m.worldgen._respawn_resources()
	m.worldgen._respawn_forage()
	m.worldgen._spawn_bugs()

	m.tutorial_notify("slept")

	# NPC 일일 상태 리셋 + 새 의뢰
	for n in m.npcs:
		n.talked_today = false
	GameData.gifted_today.clear()
	var spouse_note := _spouse_morning()
	# 수락해 둔 의뢰는 다음 날까지 이어진다. 안 골랐으면 새로 세 건이 붙는다
	if GameData.quest.is_empty():
		GameData.make_daily_quest()
	# 민지의 해변 노점: 오늘 나와 있을 시각(하루 3번, 1시간씩)을 새로 뽑는다
	GameData.roll_stall_hours()

	m.saveio.save_now()

	var note := ""
	for product in collected:
		note += "\n%s %d개를 얻었다!" % [GameData.ITEMS[product].name, collected[product]]
	if season_changed:
		note += "\n%s이 시작됐다!" % GameData.season_name()
	# 오늘 축제가 있으면 아침에 알려 준다 (하루 계획을 세울 수 있게)
	GameData.reset_festival_state()
	var fest: Dictionary = GameData.festival_today()
	if not fest.is_empty():
		note += "\n\n★ 오늘은 %s! (9시~18시, %s)\n%s" % [fest.name,
			"낚시터" if str(fest.place) == "pier" else "마을 광장", fest.goal]
	if wilted > 0:
		note += "\n작물 %d개가 시들어버렸다..." % wilted
	if storm_hurt > 0:
		note += "\n폭풍에 작물 %d개가 주저앉았다 (성장이 되돌아갔다)." % storm_hurt
	if storm_wood > 0:
		note += "\n부러진 가지를 주웠다. 목재 +%d" % storm_wood
	if penned > 0:
		note += "\n목초지의 동물 %d마리는 알아서 배불리 먹었다." % penned
	var wnote: String = str(GameData.weather_def(m.weather_now()).note)
	if wnote != "":
		note += "\n%s %s" % [GameData.weather_icon(m.weather_now()), wnote]
	if passed_out:
		note += "\n쓰러져서 기력이 절반만 회복됐다..."
	if spouse_note != "":
		note += "\n\n" + spouse_note

	var s_title := "- %s %d일 아침 -" % [GameData.season_name(), GameData.day_in_season()]
	var s_body := "어제 수확: %d개\n판매 수입: +%dG\n지출: -%dG\n소지금: %dG\n%s" \
		% [stats[0], stats[1], stats[2], GameData.money, note]
	m.summary.open(s_title, s_body)
	if Net.is_host():
		m.netsync._net_new_day.rpc(m.netsync._make_snapshot_json(), s_title, s_body)
	m.queue_redraw()
	# 밤새 물기가 마르고 작물이 자랐다 — 「돌아가는 칸」 목록을 다시 만든다.
	# 어딘가에서 touch를 빠뜨려도 여기서 하루 안에 저절로 맞춰진다.
	m.farming.rebuild()

func _update_night() -> void:
	var start := 18.0 * 60.0
	var a := clampf((GameData.minutes - start) / (6.0 * 60.0), 0.0, 1.0)
	var c := Color(1, 1, 1).lerp(Color(0.5, 0.48, 0.72), a)
	if m.weather_now() in [GameData.WEATHER_RAIN, GameData.WEATHER_STORM]:
		c *= Color(0.78, 0.8, 0.88)  # 비 오는 날은 어둑하게
	elif m.weather_now() == GameData.WEATHER_FOG:
		c *= Color(0.86, 0.88, 0.9)  # 안개 낀 날은 색이 옅다
	m.night.color = c


# 배우자의 아침 — 함께 눈을 뜬다.
#
# 마을을 걸어다니는 NPC를 집 안으로 옮기려면 실내 장면과 길찾기를 새로
# 짜야 한다. 그래서 「집에 사는 사람」을 따로 세우는 대신, 아침 결산에
# 한마디를 얹고 이틀에 한 번 뭔가를 남겨 두는 것으로 했다.
func _spouse_morning() -> String:
	var sid := GameData.spouse
	if sid == "" or not GameData.NPCS.has(sid):
		return ""
	var def: Dictionary = GameData.NPCS[sid]
	var lines: Array = def.get("married", [])
	var line: String = str(lines[randi() % lines.size()]) if not lines.is_empty() else "잘 잤어?"
	var out := "%s: \"%s\"" % [def.name, line]
	if GameData.is_birthday(sid):
		return out + "\n(오늘은 %s의 생일이다. 선물을 준비하자.)" % def.name
	# 이틀에 한 번, 자기 일에서 나온 것을 남겨 둔다
	if GameData.day - GameData.spouse_gift_day >= 2:
		GameData.spouse_gift_day = GameData.day
		var give := str(SPOUSE_GIFTS.get(sid, "egg"))
		GameData.items[give] = int(GameData.items[give]) + 1
		GameData.discover(give)
		out += "\n머리맡에 %s을(를) 두고 갔다." % GameData.ITEMS[give].name
	return out


# 배우자가 아침에 두고 가는 것 — 각자 자기 일에서 나오는 것이라야 말이 된다
const SPOUSE_GIFTS := {
	"merchant": "dish_jam", "fisher": "fish_carp", "rancher": "milk",
}
