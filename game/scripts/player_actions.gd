# 플레이어가 하는 일 — 먹기·요리·조합·마시기·아이템 얻기·처치 기록.
#
# 전부 **함께하기에서 호스트에게 물어봐야 하는 것들**이다. 게스트면
# `m.netsync._req_*`로 넘기고, 호스트면 여기서 처리한 뒤 결과를 뿌린다.
#
# main의 것은 `m.`으로 부른다 (m = main.gd).
class_name KyojinDoing
extends Node

var m: KyojinMain    # main.gd


func net_shop(op: String, id: String, qty := -1) -> void:
	if Net.is_host():
		m.netsync._broadcast_stats()
	elif Net.is_guest():
		m.netsync._req_shop.rpc_id(1, op, id, qty)


func record_kill(mob: String) -> void:
	GameData.mob_kills[mob] = int(GameData.mob_kills.get(mob, 0)) + 1
	GameData._check_collections()   # 「동굴 관찰자」는 처치 기록으로 찬다
	_maybe_drop_recipe("mob")
	if Net.is_guest():
		m.netsync._req_kill.rpc_id(1, mob)
	elif Net.is_host():
		m.netsync._broadcast_stats()


func gain_item(id: String, count: int) -> void:
	if id in ["ore", "gem"]:
		GameData.minerals_found[id] = true
	# 처음 얻은 것이면 도감에 자리가 열린다 (상점 진열도 여기서 갈린다)
	if GameData.discover(id) and GameData.ITEMS.has(id):
		m.hud.show_message("★ %s — 도감에 기록했다! (N)" % GameData.ITEMS[id].name, 2.6)
	if Net.is_guest():
		GameData.items[id] += count  # 낙관적 반영, 통계 브로드캐스트로 수렴
		m.netsync._req_gain.rpc_id(1, id, count)
		return
	GameData.items[id] += count
	if Net.is_host():
		m.netsync._broadcast_stats()


func do_cook(id: String) -> void:
	if not GameData.cook(id):
		m.hud.show_message("재료가 부족하다.")
		return
	Sound.play_sfx("sfx_buy")
	m.hud.show_message("'%s' 완성!" % GameData.ITEMS[id].name)
	m.toolwork.gain_skill("cook", 8.0)
	if Net.is_guest():
		m.netsync._req_cook.rpc_id(1, id)
	elif Net.is_host():
		m.netsync._broadcast_stats()


func do_brew(ids: Array) -> Dictionary:
	if ids.size() != GameData.ALCHEMY_SLOTS:
		return {}
	for id: String in ids:
		if GameData.ingredient_count(id) <= 0:
			m.hud.show_message("재료가 부족하다.")
			return {}
	for id: String in ids:
		if GameData.CROPS.has(id):
			GameData.consume_produce(id, 1)
		else:
			GameData.items[id] -= 1
	var fid := GameData.match_formula(ids)
	if fid == "":
		GameData.items[GameData.ALCHEMY_FAIL] += 1
		GameData.alchemy_fails += 1
		Sound.play_sfx("sfx_ui")
		m.saveio.save_now()
		return {"ok": false, "fid": GameData.ALCHEMY_FAIL, "ids": ids.duplicate(),
			"name": "탁한 앙금", "effect": "", "first": false,
			"hint": GameData.brew_hint(ids)}
	GameData.items[fid] += 1
	GameData.alchemy_brews[fid] = int(GameData.alchemy_brews.get(fid, 0)) + 1
	Sound.play_sfx("sfx_buy")
	var first := GameData.learn_formula(fid)
	if first:
		# 처음 맞힌 순간이 이 시스템의 알맹이다 — 크게 알린다
		m.hud.event_toast("새 조합법 발견!")
		m.dialog.open("연금술 — 새 조합법",
			"**%s** 을(를) 만들어냈다!\n\n%s\n\n필요한 속성: %s\n조합법이 연구 노트(N)에 적혔다."
				% [GameData.FORMULAS[fid].name, GameData.FORMULAS[fid].effect,
				GameData.formula_need_text(fid)],
			[["좋아", null]])
	m.toolwork.gain_skill("cook", 6.0)
	m.saveio.save_now()
	return {"ok": true, "fid": fid, "ids": ids.duplicate(),
		"name": str(GameData.FORMULAS[fid].name),
		"effect": str(GameData.FORMULAS[fid].effect), "first": first, "hint": ""}


func do_drink(fid: String) -> void:
	if int(GameData.items[fid]) <= 0:
		return
	GameData.items[fid] -= 1
	var def: Dictionary = GameData.FORMULAS[fid]
	Sound.play_sfx("sfx_harvest")
	if fid == "potion_energy":
		GameData.energy = minf(GameData.ENERGY_MAX,
			GameData.energy + GameData.POTION_ENERGY_HEAL)
	elif fid == "potion_moon":
		var wet := 0
		for y in m.MAP_H:
			for x in m.MAP_W:
				var cell: Dictionary = m.grid[y][x]
				if cell.ground == "soil" and not cell.watered:
					m.farming._wet(cell, m.WET_ALL_DAY)
					wet += 1
		m.hud.show_message("달빛이 밭 %d칸을 적셨다." % wet, 3.0)
	var key: String = str(def.get("today", ""))
	if key != "":
		GameData.potion_today[key] = true
	m.hud.show_message("%s을(를) 마셨다 — %s" % [def.name, def.effect], 4.0)
	m.queue_redraw()


func _maybe_drop_recipe(source: String) -> void:
	var left: Array = GameData.unknown_formulas()
	if left.is_empty():
		return
	if randf() >= float(GameData.ALCHEMY_DROP.get(source, 0.0)):
		return
	var fid: String = left[randi() % left.size()]
	GameData.learn_formula(fid)
	Sound.play_sfx("sfx_ui")
	m.hud.event_toast("낡은 조합법을 주웠다")
	m.hud.show_message("「%s」 조합법을 알아냈다! (%s) — 집 조합대에서 만들 수 있다"
		% [GameData.FORMULAS[fid].name, GameData.formula_need_text(fid)], 5.0)


func do_eat(id: String) -> void:
	if int(GameData.items[id]) <= 0:
		return
	GameData.items[id] -= 1
	var e: float = float(GameData.RECIPES[id].energy) * GameData.cook_energy_mult()
	GameData.energy = minf(GameData.ENERGY_MAX, GameData.energy + e)
	Sound.play_sfx("sfx_harvest")
	m.hud.show_message("%s를 먹었다! 체력 +%d" % [GameData.ITEMS[id].name, int(e)])
	if Net.is_guest():
		m.netsync._req_eat.rpc_id(1, id)
	elif Net.is_host():
		m.netsync._broadcast_stats()


func sync_furniture(money_delta: int) -> void:
	if Net.is_guest():
		m.netsync._req_furniture.rpc_id(1, JSON.stringify(GameData.furniture), money_delta)
	elif Net.is_host():
		m.netsync._broadcast_stats()
