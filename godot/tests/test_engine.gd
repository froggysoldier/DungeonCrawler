extends RefCounted
## Grundlegende Spielabläufe (Port von tests/engine.test.ts).


func _reachable(s: Dictionary, from: Dictionary) -> Dictionary:
	var m: Dictionary = s.map
	var seen := {MapGen.idx(m, from.x, from.y): true}
	var q: Array = [from]
	while not q.is_empty():
		var c: Dictionary = q.pop_front()
		for d in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
			var n := {"x": c.x + d[0], "y": c.y + d[1]}
			if not MapGen.in_bounds(m, n.x, n.y):
				continue
			var i := MapGen.idx(m, n.x, n.y)
			# Geschlossene Türen zählen als Durchgang (man kann sie öffnen)
			if (not MapGen.is_walkable(m, n.x, n.y) and m.tiles[i] != "door") or seen.has(i):
				continue
			seen[i] = true
			q.append(n)
	return seen


func test_neues_spiel(t) -> void:
	var s := TH.make()
	t.eq(s.status, "playing", "Status")
	t.ok(MapGen.is_walkable(s.map, s.player.pos.x, s.player.pos.y), "Start begehbar")
	t.gt(s.player.hp, 0, "HP")
	t.has(s.achievements, "willkommen", "Willkommen")
	t.gt(s.player.boxes.size(), 0, "Boxen")
	t.lacks(s.unlocks, "inventar", "Inventar gesperrt")


func test_interview_katze_bademantel(t) -> void:
	var s := TH.make(5, [3, 0, 0, 0, 1])
	t.eq(s.player.pet.species, "Katze", "Katze")
	t.eq(s.player.equipment.brust.baseId, "bademantel", "Bademantel")
	t.has(s.achievements, "katzenlady")
	t.has(s.achievements, "bademantel")
	t.has(s.player.skills.map(func(k): return k.id), "faustkampf")


func test_karten_zusammenhaengend(t) -> void:
	for seed in [1, 2, 3, 42, 999, 31337]:
		var s := TH.make(seed)
		var reach := _reachable(s, s.player.pos)
		var bad := 0
		for i in s.map.tiles.size():
			if s.map.tiles[i] != "wall" and not reach.has(i):
				bad += 1
		t.eq(bad, 0, "Seed %d: alles erreichbar" % seed)
		var kinds: Array = s.map.rooms.map(func(r): return r.kind)
		t.ge(kinds.count("guild"), 1, "Gilde")
		t.ge(kinds.count("safe"), 4, "Safe Rooms")
		t.eq(kinds.count("boss"), 4, "Boss-Kammern")
		t.ge(s.map.tiles.count("stairs"), 2, "Treppen")
		t.eq(s.monsters.filter(func(m): return m.rank == "nachbarschaftsboss").size(), 4, "Nachbarschaftsbosse")
		t.eq(s.monsters.filter(func(m): return m.rank == "boroughboss").size(), 1, "Borough-Boss")


func test_faust_toetet_und_gibt_xp(t) -> void:
	var s := TH.make(77)
	var rat := TH.spawn_near(s)
	rat.hp = 1
	rat.ausweichen = -200
	# Trefferchance ist höchstens 95 % – ein paar Versuche erlauben
	for i in 5:
		if not J.has_same(s.monsters, rat):
			break
		t.ok(Game.attack(s, rat.uid, {"part": "faust", "move": "normal"}).ok, "Angriff möglich")
	t.ok(not J.has_same(s.monsters, rat), "Ratte besiegt")
	t.eq(s.counters.kills, 1, "Kills")
	t.has(s.achievements, "erstes_blut")
	t.eq(s.player.techniqueKills.get("faust+normal"), 1, "Technik-Kill")


func test_stampfen_nur_auf_liegende(t) -> void:
	var s := TH.make(78)
	var rat := TH.spawn_near(s)
	rat.size = "klein"
	t.matches(Combat.technique_blocker(s, rat, {"part": "tritt", "move": "stampfen"}), "Boden")
	rat.downed = 2
	t.is_null(Combat.technique_blocker(s, rat, {"part": "tritt", "move": "stampfen"}))


func test_tritte_schalten_treten_frei(t) -> void:
	var s := TH.make(79, [1, 0, 3, 0, 0])
	var rat := TH.spawn_near(s)
	for i in 15:
		Events.emit(s, {"type": "attack", "technique": {"part": "tritt", "move": "normal"}, "hit": false, "crit": false, "damage": 0, "target": rat})
	t.has(s.player.skills.map(func(k): return k.id), "treten")
	t.has(s.achievements, "skill1")


func test_werfen_ohne_objekt(t) -> void:
	var s := TH.make(80)
	var rat := TH.spawn_near(s)
	s.items = []
	t.matches(Combat.technique_blocker(s, rat, {"part": "wurf", "move": "normal"}), "nichts zum Werfen")


func test_boxen_nur_im_safe_room(t) -> void:
	var s := TH.make(90)
	s.unlocks.append("inventar")
	var box: Dictionary = s.player.boxes[0]
	t.ok(not Game.open_box(s, box.uid).ok, "außerhalb nicht")
	var safe = TH.room(s, "safe")
	TH.teleport(s, {"x": safe.x + 1, "y": safe.y + 1})
	var res := Game.open_box(s, box.uid)
	t.ok(res.ok, "im Safe Room")
	t.gt(res.contents.size(), 0, "Inhalt")
	t.has(s.achievements, "unboxing")


func test_mobs_im_safe_room_weggebeamt(t) -> void:
	var s := TH.make(91)
	var safe = TH.room(s, "safe")
	TH.teleport(s, {"x": safe.x + 1, "y": safe.y + 1})
	s.monsters = []
	var m := Monsters.spawn_monster(s, Db.t("monsters", "MONSTERS")[2], 2, {"x": safe.x + 2, "y": safe.y + 1}, 0)
	m.aware = true
	s.monsters.append(m)
	var hp: int = s.player.hp
	Ai.monster_turn(s, m)
	t.eq(s.player.hp, hp, "kein Schaden")
	t.gt(TH.cheb(m.pos, s.player.pos), 1, "weggebeamt")


func test_schlafen_heilt(t) -> void:
	var s := TH.make(92)
	var safe = TH.room(s, "safe")
	TH.teleport(s, {"x": safe.x + 1, "y": safe.y + 1})
	s.player.hp = 1
	var turn: int = s.turn
	t.ok(Game.sleep(s).ok, "Schlafen")
	t.gt(s.turn, turn + 100, "Zeit vergeht")
	t.gt(s.player.hp, 1, "geheilt")


func test_gilde_schaltet_inventar_frei(t) -> void:
	var s := TH.make(100)
	Game.pickup(s)
	s.player.hand = s.items[0].item if not s.items.is_empty() else null
	var guild = TH.room(s, "guild")
	TH.teleport(s, {"x": guild.x + 1, "y": guild.y + 1})
	s.monsters = []
	Game.move_step(s, {"x": guild.x + 2, "y": guild.y + 1})
	t.has(s.unlocks, "inventar")
	t.is_null(s.player.hand, "Hand leer")
	t.ok(J.some(s.pendingDialogs, func(d): return d.title == "Gilde der Einweisung"), "Dialog")
	var potion = J.find(s.player.inventory, func(i): return i.baseId == "kleiner_heiltrank")
	t.not_null(potion, "Heiltrank")
	s.player.hp = 1
	t.ok(Game.use_item(s, potion.uid).ok, "trinken")
	t.gt(s.player.hp, 1, "geheilt")


func test_etage_stuerzt_ein(t) -> void:
	var s := TH.make(101)
	s.monsters = []
	s.collapseAt = s.turn + 2
	Game.wait(s)
	Game.wait(s)
	t.eq(s.status, "dead", "tot")
	t.matches(s.deathCause, "einstürzenden")


func test_treppen_bis_etage_3(t) -> void:
	var s := TH.make(102)
	TH.teleport(s, TH.stairs(s))
	t.ok(Game.descend(s, {"ghosts": []}).ok, "hinab")
	t.eq(s.floor, 2, "Etage 2")
	t.has(s.achievements, "absteiger")
	for fl in [3, 4]:
		TH.teleport(s, TH.stairs(s))
		s.pendingSelection = false
		Game.descend(s, {"ghosts": []})
		if fl == 3:
			t.eq(s.floor, 3, "Etage 3")
	t.eq(s.status, "victory", "Sieg")


func test_tod_hinterlaesst_geist(t) -> void:
	var meta := Meta.empty_meta()
	var s := Game.new_game({"name": "Erna", "answers": [0, 0, 0, 0, 0], "seed": 5, "meta": meta})
	s.status = "dead"
	s.deathCause = "Test"
	Meta.record_run_end(meta, s)
	t.eq(meta.season, 1, "Staffel")
	t.eq(meta.ghosts[0].name, "Erna", "Geist")
	t.eq(meta.hallOfFame.size(), 1, "Hall of Fame")
	var s2 := Game.new_game({"name": "Nachfolger", "answers": [0, 0, 0, 0, 0], "seed": 6, "meta": meta})
	t.eq(s2.season, 2, "nächste Staffel")
	t.ok(J.some(s2.monsters, func(m): return m.rank == "geist" and m.get("ghostOf") == "Erna"), "Geist spawnt")
	t.eq(s2.player.boxes[0].box.tier, "bronze", "nicht mehr erstmalig")


func test_vertrag_macht_guide(t) -> void:
	var meta := Meta.empty_meta()
	var s := Game.new_game({"name": "Mira", "answers": [0, 0, 0, 0, 0], "seed": 7, "meta": meta})
	s.contractSigned = true
	s.status = "dead"
	Meta.record_run_end(meta, s)
	t.eq(meta.guides[0].name, "Mira", "Guide")
	t.eq(meta.ghosts.size(), 0, "kein Geist")
	var s2 := Game.new_game({"name": "Neu", "answers": [0, 0, 0, 0, 0], "seed": 8, "meta": meta})
	t.eq(s2.guideName, "Mira", "Guide in nächster Staffel")


func test_pfade_nur_ueber_bekannte_felder(t) -> void:
	var s := TH.make(103)
	t.is_null(Game.plan_path(s, {"x": s.map.width - 2, "y": s.map.height - 2}))


func test_robust_bei_zufallsaktionen(t) -> void:
	for seed in [11, 12, 13]:
		var s := TH.make(seed, [seed % 9, 1, seed % 4, 2, 3])
		var rng := {"v": seed}
		var rand := func() -> float:
			rng.v = (rng.v * 1103515245 + 12345) & 0x7fffffff
			return rng.v / float(0x7fffffff)
		var parts := ["faust", "tritt", "knie", "ellbogen", "kopf"]
		for i in 3000:
			if s.status != "playing":
				break
			var adj = J.find(s.monsters, func(m): return TH.cheb(m.pos, s.player.pos) <= 1)
			if adj != null and rand.call() < 0.8:
				var r := Game.attack(s, adj.uid, {"part": parts[floori(rand.call() * parts.size())], "move": "sprung" if rand.call() < 0.2 else "normal"})
				if not r.ok:
					Game.wait(s)
				continue
			var dx := floori(rand.call() * 3) - 1
			var dy := floori(rand.call() * 3) - 1
			var r2 := Game.move_step(s, {"x": s.player.pos.x + dx, "y": s.player.pos.y + dy})
			if not r2.ok:
				Game.end_turn(s)
			if rand.call() < 0.05:
				Game.pickup(s)
		t.has(["playing", "dead"], s.status, "Seed %d: Status" % seed)
		t.eq(JSON.parse_string(JSON.stringify(s)).floor, s.floor, "Zustand serialisierbar")
