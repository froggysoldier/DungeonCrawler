extends RefCounted
## Techniken: über Skill-Stufen und Werte gelernt, mit Kosten, Abklingzeit
## und Wirkung. Dazu der Rundenablauf: Die eigene Aktion beendet die Runde
## nie, ein Erstschlag lässt die Gegner nicht sofort antworten.

var _tree: SceneTree


func setup(_data) -> void:
	_tree = Engine.get_main_loop()


## Spielbereit, ein wacher Gegner (ohne Fähigkeiten, viel Leben) daneben.
func _fight(seed: int, id: String = "kellerratte") -> Array:
	var s := TH.make(seed, {"beruf": 1})
	var m := TH.foe(s, id, 1)
	m.hp = 500
	m.maxHp = 500
	m.ausweichen = -200
	s.player.ausdauer = Player.max_ausdauer(s)
	return [s, m]


func _learn(s: Dictionary, ids: Array) -> void:
	for id in ids:
		if not s.player.techniques.has(id):
			s.player.techniques.append(id)


func test_daten_vollstaendig(t) -> void:
	var stats := ["str", "ges", "kon", "int", "cha"]
	for d in Techniques.all():
		t.ok(["ausfuehrung", "angriff", "selbst"].has(d.art), "%s: Art" % d.id)
		t.ok(not d.needs.is_empty(), "%s: Bedingung" % d.id)
		t.ok(String(d.description) != "", "%s: Beschreibung" % d.id)
		for n in d.needs:
			if n.has("skill"):
				t.ok(Db.skill(String(n.skill)) != null, "%s: Skill %s gibt es" % [d.id, n.skill])
			else:
				t.has(stats, n.stat, "%s: Wert" % d.id)
		if d.get("part") != null:
			t.has(Combat.ATTACK_PARTS, d.part, "%s: Körperteil" % d.id)
		if d.get("zone") != null:
			t.ok(Combat.ZONES.has(d.zone), "%s: Zone" % d.id)
	# Jeder Kampfskill schaltet etwas frei
	for sk in Db.t("skills", "SKILLS"):
		if sk.category == "kampf" or sk.category == "verteidigung":
			t.ok(J.some(Techniques.all(), func(d): return J.some(d.needs, func(n): return n.get("skill") == sk.id)), "%s schaltet eine Technik frei" % sk.id)


func test_ausfuehrungen_erst_lernen(t) -> void:
	var s := TH.make(7001, {"beruf": 1})
	var m := TH.spawn_near(s)
	m.downed = 2
	t.matches(Combat.technique_blocker(s, m, {"part": "tritt", "move": "stampfen"}), "gelernt")
	t.matches(Combat.technique_blocker(s, m, {"part": "tritt", "move": "sprung"}), "Treten Stufe 2")
	Skills.learn_skill(s, "treten", 1, true)
	Techniques.check(s)
	t.ok(Techniques.known(s, "stampfen"), "Treten Stufe 1: Stampfen gelernt")
	t.is_null(Combat.technique_blocker(s, m, {"part": "tritt", "move": "stampfen"}), "Stampfen geht jetzt")
	t.ok(not Techniques.known(s, "sprung"), "Sprung noch nicht")
	s.player.stats.ges = 11
	Techniques.check(s)
	t.ok(Techniques.known(s, "sprung"), "Geschick 11: Sprung gelernt")
	t.ok(J.some(s.log, func(l): return String(l.text).begins_with("NEUE TECHNIK: Sprung")), "Meldung im Chat")


func test_skill_und_wert_schalten_frei(t) -> void:
	var s := TH.make(7002, {"beruf": 1})
	t.ok(not Techniques.known(s, "maechtiger_schlag"), "am Anfang nicht")
	Skills.learn_skill(s, "faustkampf", 2, true)
	s.player.stats.int = 10
	Techniques.check(s)
	t.ok(Techniques.known(s, "maechtiger_schlag"), "Faustkampf 2: Mächtiger Schlag")
	t.ok(not Techniques.known(s, "schlaghagel"), "Schlaghagel erst ab Stufe 4")
	t.ok(Techniques.known(s, "finte"), "Intelligenz 10: Finte")
	# Einmal gelernt, bleibt die Technik
	s.player.stats.int = 5
	Techniques.check(s)
	t.ok(Techniques.known(s, "finte"), "bleibt gelernt")


func test_maechtiger_schlag_kosten_und_abklingzeit(t) -> void:
	var pair := _fight(7003)
	var s: Dictionary = pair[0]
	var m: Dictionary = pair[1]
	t.matches(Game.use_technique(s, "maechtiger_schlag", m.uid, {"part": "faust"}).get("message", ""), "gelernt")
	_learn(s, ["maechtiger_schlag"])
	var st0: int = s.player.ausdauer
	var res := Game.use_technique(s, "maechtiger_schlag", m.uid, {"part": "faust"})
	t.ok(res.ok, "eingesetzt")
	t.eq(s.player.ausdauer, st0 - 3, "kostet 3 Ausdauer")
	t.eq(Techniques.cooldown(s, "maechtiger_schlag"), 3, "Abklingzeit 3")
	t.ok(J.some(s.log, func(l): return String(l.text).contains("Dein Mächtiger Schlag")), "im Chat beim Namen genannt")
	t.ok(s.round.acted, "Aktion der Runde verbraucht")
	t.matches(Game.use_technique(s, "maechtiger_schlag", m.uid, {"part": "faust"}).get("message", ""), "braucht noch")


func test_maechtiger_schlag_mehr_schaden(t) -> void:
	var normal := 0
	var strong := 0
	for i in 30:
		var pair := _fight(7100 + i)
		var s: Dictionary = pair[0]
		var m: Dictionary = pair[1]
		m.ruestung = 0
		Combat.player_attack(s, m, {"part": "faust", "move": "normal", "zone": "koerper"})
		normal += 500 - m.hp
		var pair2 := _fight(7100 + i)
		var s2: Dictionary = pair2[0]
		var m2: Dictionary = pair2[1]
		m2.ruestung = 0
		_learn(s2, ["maechtiger_schlag"])
		Game.use_technique(s2, "maechtiger_schlag", m2.uid, {"part": "faust"})
		strong += 500 - m2.hp
	t.gt(strong, normal * 1.5, "Mächtiger Schlag macht deutlich mehr Schaden (%d gegen %d)" % [strong, normal])


func test_finte_oeffnet_deckung(t) -> void:
	var opened := false
	for i in 20:
		var pair := _fight(7200 + i)
		var s: Dictionary = pair[0]
		var m: Dictionary = pair[1]
		m.ausweichen = 30
		_learn(s, ["finte"])
		var before := Combat.hit_chance(s, m, {"part": "faust", "move": "normal", "zone": "koerper"})
		Game.use_technique(s, "finte", m.uid, {"part": "faust"})
		if J.num(m, "exposed") > 0:
			opened = true
			t.gt(Combat.hit_chance(s, m, {"part": "faust", "move": "normal", "zone": "koerper"}), before, "danach trifft man leichter")
			t.gt(J.num(m, "weakened"), 0, "und er schlägt schwächer zu")
			break
	t.ok(opened, "Finte öffnet die Deckung")


func test_beinfeger_wirft_um(t) -> void:
	var down := false
	for i in 20:
		var pair := _fight(7300 + i)
		var s: Dictionary = pair[0]
		var m: Dictionary = pair[1]
		_learn(s, ["beinfeger"])
		Game.use_technique(s, "beinfeger", m.uid, {"part": "faust"})
		if m.downed > 0:
			down = true
			break
	t.ok(down, "Beinfeger wirft um")


func test_wegstossen_schiebt_zurueck(t) -> void:
	var pushed := false
	for i in 20:
		var pair := _fight(7400 + i)
		var s: Dictionary = pair[0]
		var m: Dictionary = pair[1]
		var from := J.pcopy(m.pos)
		_learn(s, ["wegstossen"])
		Game.use_technique(s, "wegstossen", m.uid, {"part": "faust"})
		if J.cheb(m.pos, s.player.pos) > 1 or m.hp < 500 - 30:
			pushed = J.cheb(m.pos, from) >= 1 or m.hp < 500
			break
	t.ok(pushed, "Wegstoßen schiebt den Gegner weg (oder er prallt gegen die Wand)")


func test_schnellangriff_kostet_keine_aktion(t) -> void:
	var pair := _fight(7500)
	var s: Dictionary = pair[0]
	var m: Dictionary = pair[1]
	_learn(s, ["schnellangriff"])
	Game.attack(s, m.uid, {"part": "faust", "move": "normal", "zone": "koerper"})
	t.ok(Rounds.active(s), "Kampf läuft")
	var n: int = s.round.n
	s.round.acted = false
	t.ok(Game.use_technique(s, "schnellangriff", m.uid, {"part": "faust"}).ok, "Schnellangriff")
	t.ok(not s.round.acted, "Aktion noch frei")
	t.eq(s.round.n, n, "dieselbe Runde")


func test_selbsttechniken(t) -> void:
	var pair := _fight(7600)
	var s: Dictionary = pair[0]
	_learn(s, ["notverband", "ausweichrolle"])
	s.player.hp = 5
	t.ok(Game.use_technique(s, "notverband").ok, "Notverband")
	t.gt(s.player.hp, 5, "heilt")
	s.round = {"move": 0, "max": 6, "n": 1, "acted": false}
	t.ok(Game.use_technique(s, "ausweichrolle").ok, "Ausweichrolle")
	t.eq(int(s.round.move), 3, "drei Felder mehr Bewegung")
	t.ok(J.some(s.player.buffs, func(b): return b.name == "Ausweichrolle"), "schwerer zu treffen")


func test_erstschlag_ohne_gegenantwort(t) -> void:
	var s := TH.make(7700, {"beruf": 1})
	var m := TH.foe(s, "kellerratte", 1)
	m.aware = false
	m.hp = 500
	m.maxHp = 500
	var hp0: int = s.player.hp
	var turn0: int = s.turn
	t.ok(not Rounds.active(s), "noch kein Kampf")
	t.ok(Game.attack(s, m.uid, {"part": "faust", "move": "normal", "zone": "koerper"}).ok, "Erstschlag")
	t.ok(Rounds.active(s), "eröffnet die Runde")
	t.ok(s.round.acted, "Aktion der ersten Runde verbraucht")
	t.eq(s.turn, turn0, "keine Zeit vergangen")
	t.eq(s.player.hp, hp0, "der Gegner hat nicht geantwortet")


func test_aktion_beendet_runde_nicht(t) -> void:
	var pair := _fight(7800)
	var s: Dictionary = pair[0]
	var m: Dictionary = pair[1]
	s.round = {"move": 0, "max": 6, "n": 4, "acted": false}
	var hp0: int = s.player.hp
	Game.attack(s, m.uid, {"part": "faust", "move": "normal", "zone": "koerper"})
	t.ok(Rounds.active(s), "Runde läuft weiter")
	t.eq(s.round.n, 4, "gleiche Runde, obwohl die Bewegung verbraucht ist")
	t.ok(Rounds.spent(s), "Aktion und Bewegung verbraucht")
	t.eq(s.player.hp, hp0, "Gegner noch nicht dran")
	Game.wait(s)
	t.eq(s.round.n, 5, "erst „Runde beenden“ lässt die Gegner ran")


## Oberfläche: Ist die Aktion verbraucht, endet erst die Runde (Gegnerzug),
## dann folgt der neue Angriff; eine verbrauchte Runde endet von selbst.
func test_oberflaeche_wartet_auf_gegnerzug(t) -> void:
	var pair := _fight(7900)
	var s: Dictionary = pair[0]
	var m: Dictionary = pair[1]
	var meta := Meta.empty_meta()
	meta["guide"] = {"step": 99, "fight": true}
	var modals := Modals.new()
	_tree.root.add_child(modals)
	var gv := GameView.new(s, meta)
	_tree.root.add_child(gv)
	modals.close_all()
	s.pendingDialogs.clear()
	gv.wait_for_enemies = false
	await _tree.process_frame
	s.round = {"move": 3, "max": 6, "n": 2, "acted": true}
	gv.attack_monster(m.uid)
	t.eq(int(s.round.n), 3, "erst endet die Runde")
	t.ok(not s.round.acted, "der Angriff wartet noch")
	for i in 5:
		await _tree.process_frame
	t.ok(s.round.acted, "nach dem Gegnerzug folgt der Angriff")
	s.round.move = 0
	gv.act(func(): return {"ok": true})
	var n: int = s.round.n
	var until := Time.get_ticks_msec() + 2000
	while Time.get_ticks_msec() < until and int(s.round.n) == n:
		await _tree.process_frame
	t.eq(int(s.round.n), n + 1, "verbrauchte Runde endet von selbst")
	modals.close_all()
	await _tree.process_frame
	gv.free()
	modals.free()
