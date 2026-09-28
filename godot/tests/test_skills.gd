extends RefCounted
## Skills (Port von tests/skills.test.ts).


func _make(seed: int = 7300) -> Dictionary:
	return TH.make(seed, {"beruf": 1})


func _arena(s: Dictionary) -> Dictionary:
	var r := TH.ready(s)
	return {"x": r.x + 2, "y": r.y + 1}


func test_schwache_gegner_lehren_wenig(t) -> void:
	var s := _make()
	s.player.level = 10
	t.lt(Skills.learn_factor(s, 2), 0.2, "viel schwächer")
	t.eq(Skills.learn_factor(s, 10), 1.0, "gleich")
	t.gt(Skills.learn_factor(s, 13), 1.0, "stärker")


func test_stufen_werden_teurer(t) -> void:
	t.gt(Rules.skill_xp_needed(10), Rules.skill_xp_needed(2) * 2, "teurer")


func test_wirkung_pro_stufe(t) -> void:
	for def in Db.t("skills", "SKILLS"):
		t.gt(Skills.effect_text(def, 3).length(), 3, def.id)


func test_erste_hilfe(t) -> void:
	var s := _make()
	_arena(s)
	s.player.skills = s.player.skills.filter(func(k): return k.id != "erste_hilfe")
	for i in 8:
		var it := Items.create_item(s, "pflaster")
		s.player.inventory.append(it)
		s.monsters = []
		Game.use_item(s, it.uid)
	t.ok(J.some(s.player.skills, func(k): return k.id == "erste_hilfe"), "gelernt")


func test_giftfestigkeit(t) -> void:
	var plain := _make()
	_arena(plain)
	var tough := _make()
	_arena(tough)
	Skills.learn_skill(tough, "giftfestigkeit", 10, true)
	var lost := []
	for s in [plain, tough]:
		s.player.hp = Player.max_hp(s)
		var before: int = s.player.hp
		Abilities.poison(s, "Test", 4)
		s.monsters = []
		Game.wait(s)
		lost.append(before - s.player.hp)
	t.lt(lost[1], lost[0], "weniger Giftschaden")


func test_abwehr(t) -> void:
	var s := _make()
	_arena(s)
	Skills.learn_skill(s, "abwehr", 9, true)
	s.monsters = []
	Game.defend(s)
	t.ok(Skills.effect_text(Db.skill("abwehr"), 9).contains("38 %"), "Text")


func test_feilschen(t) -> void:
	var s := _make()
	var it := Items.create_item(s, "bauhelm")
	var before := Shop.sell_price(it, s)
	Skills.learn_skill(s, "feilschen", 15, true)
	t.gt(Shop.sell_price(it, s), before, "besserer Preis")


func test_schleichen(t) -> void:
	var quiet := _make(7400)
	var spot := _arena(quiet)
	Skills.learn_skill(quiet, "schleichen", 15, true)
	var noticed := 0
	for i in 40:
		var m := Monsters.spawn_monster(quiet, Db.monster("ghul"), 2, {"x": spot.x + 3, "y": spot.y}, 0)
		if not MapGen.is_walkable(quiet.map, m.pos.x, m.pos.y):
			m.pos = spot.duplicate()
		quiet.monsters = [m]
		Ai.monster_turn(quiet, m)
		if m.aware:
			noticed += 1
	t.lt(noticed, 40, "nicht immer entdeckt")


func test_konter(t) -> void:
	var countered := false
	for seed in 15:
		if countered:
			break
		var s := _make(7500 + seed)
		var spot := _arena(s)
		Skills.learn_skill(s, "konter", 15, true)
		var m := Monsters.spawn_monster(s, Db.monster("ghul"), 2, spot, 0)
		m.treffer = -500
		m.aware = true
		m.hp = 500
		m.maxHp = 500
		m.abilities = []
		s.monsters = [m]
		for i in 10:
			Ai.monster_turn(s, m)
		countered = m.hp < 500
	t.ok(countered, "Konter")


func test_ausloeser_ohne_kampf(t) -> void:
	var s := _make()
	for i in 3:
		Skills.train_skill(s, "haggle", 1)
	t.ok(J.some(s.player.skills, func(k): return k.id == "feilschen"), "Feilschen")
	Skills.on_event(s, {"type": "spellCast", "spell": "heilen", "kills": 0})
	t.eq(s.player.techniqueUses.get("_cast"), 1, "gezählt")
