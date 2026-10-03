extends RefCounted
## Highlight-Sendung, Einladungen, Gesprächsformate und die Grube.


func _make(seed: int = 6100) -> Dictionary:
	var s := TH.make(seed, {"beruf": 1})
	TH.tutorial(s)
	s.unlocks.append("zuschauer")
	s.pendingDialogs = []
	return s


func _into_safe(s: Dictionary) -> Dictionary:
	var safe = TH.room(s, "safe")
	s.player.pos = {"x": safe.x + 1, "y": safe.y + 1}
	s.monsters = []
	Game.move_step(s, {"x": safe.x + 2, "y": safe.y + 1})
	s.pendingDialogs = []
	return safe


## Bis 21 Uhr des ersten Tages vorspulen und die Sendung auslösen.
func _air(s: Dictionary) -> void:
	Highlights.state(s)
	s.turn = (1260 - 480) / 3
	Highlights.tick(s)


func test_uhrzeit(t) -> void:
	var s := TH.make(6101)
	s.turn = 0
	t.eq(Highlights.clock_text(s), "Tag 1, 08:00", "Spielbeginn um 8 Uhr")
	s.turn = 260
	t.eq(Highlights.clock_text(s), "Tag 1, 21:00", "13 Stunden später")
	s.turn = 260 + 480
	t.eq(Highlights.clock_text(s), "Tag 2, 21:00", "einen Tag später")


func test_keine_sendung_ohne_publikum(t) -> void:
	var s := TH.make(6102)
	TH.tutorial(s)
	s.turn = 300
	Highlights.tick(s)
	t.eq(s.get("highlights"), null, "Etage 1: keine Highlights")


func test_sendung_ohne_auftritt(t) -> void:
	var s := _make()
	var before: int = s.viewers.follower
	_air(s)
	var h := Highlights.state(s)
	t.not_null(h.current, "Sendung läuft")
	t.ok(not h.current.featured, "nichts Besonderes: nicht dabei")
	t.eq(int(h.featured), 0, "kein Auftritt gezählt")
	t.eq(s.viewers.follower, before, "keine Follower")
	t.ok(Highlights.on_air(s), "bis Mitternacht auf Sendung")
	s.turn += 61
	t.ok(not Highlights.on_air(s), "nach Mitternacht vorbei")


func test_besonderer_kill_kommt_ins_programm(t) -> void:
	var s := _make()
	var m := Monsters.spawn_monster(s, Db.monster("kellerratte"), 3, s.player.pos, 0, true)
	# Elite gestampft: genug für die Sendung
	Viewers.on_event(s, {"type": "kill", "monster": m, "technique": {"part": "tritt", "move": "stampfen"}})
	var h := Highlights.state(s)
	t.eq(h.scenes.size(), 1, "Szene vorgemerkt")
	t.ok(String(h.scenes[0].text).contains(s.player.name), "Szene nennt den Crawler")
	var before: int = s.viewers.follower
	_air(s)
	t.ok(h.current.featured, "in den Highlights")
	t.eq(int(h.featured), 1, "Auftritt gezählt")
	t.gt(s.viewers.follower, before, "Follower dazu")
	t.has(s.achievements, "highlight_1")
	t.eq(h.scenes.size(), 0, "neuer Tag, neue Szenen")


func test_viele_kills_kommen_ins_programm(t) -> void:
	var s := _make()
	var h := Highlights.state(s)
	h.kills = 30
	_air(s)
	t.ok(h.current.featured, "Schlachtfest reicht für die Sendung")


func test_im_safe_room_laeuft_die_sendung(t) -> void:
	var s := _make()
	_into_safe(s)
	_air(s)
	t.eq(s.pendingDialogs.size(), 1, "Sendung als Dialog")
	t.ok(String(s.pendingDialogs[0].title).begins_with("Abgrund am Abend"), "Titel")
	t.eq(int(Highlights.state(s).watched), 1, "angesehen")


func test_bildschirm_und_tipp(t) -> void:
	var s := _make()
	_air(s)
	t.eq(s.pendingDialogs.size(), 0, "draußen kein Dialog")
	t.ok(not Game.watch_screen(s).ok, "nur im Safe Room")
	var cur: Dictionary = Highlights.state(s).current
	_into_safe(s)
	t.ok(Game.watch_screen(s).ok, "am Bildschirm ansehen")
	t.eq(s.pendingDialogs.size(), 1, "Sendung als Dialog")
	if cur.get("tipRoom") != null:
		var room = J.find(s.map.rooms, func(r): return r.id == cur.tipRoom)
		t.ok(s.map.explored[MapGen.idx(s.map, room.x, room.y)], "Tipp der Redaktion auf der Karte")
	var safe = Game.current_room(s)
	t.ok(J.some(safe.furniture, func(f): return f.kind == "bildschirm"), "Bildschirm im Safe Room")


func test_einladung_nach_auftritt(t) -> void:
	var s := _make()
	s.viewers.follower = 2000
	var invited := false
	for i in 20:
		s.erase("invitation")
		Highlights.note(s, 40, "boss", {"gegner": "den Boss"})
		Highlights.state(s).aired = floori((Highlights.clock_minutes(s) - 1260) / 1440.0) - 1
		Highlights.tick(s)
		if Invitations.pending(s) != null:
			invited = true
			break
	t.ok(invited, "eingeladen")
	var inv = Invitations.pending(s)
	t.ok(["fragerunde", "talkshow"].has(inv.format), "passendes Format (%s)" % inv.format)
	t.ok(not Game.accept_invitation(s).ok, "nur im Safe Room")
	_into_safe(s)
	t.ok(Game.accept_invitation(s).ok, "angenommen")
	t.eq(Invitations.pending(s), null, "Einladung eingelöst")
	t.eq(s.pendingDialogs[-1].kind, "talkshow", "Sendung beginnt")


func test_einladung_verfaellt(t) -> void:
	var s := _make()
	s.invitation = {"format": "fragerunde", "until": s.turn + 5}
	s.viewers.hype = 50
	s.turn += 10
	Invitations.tick(s)
	t.eq(Invitations.pending(s), null, "verfallen")
	t.lt(s.viewers.hype, 50, "Produktion beleidigt")


func test_absagen(t) -> void:
	var s := _make()
	s.invitation = {"format": "talkshow", "until": s.turn + 100}
	t.ok(Game.decline_invitation(s).ok, "abgesagt")
	t.has(s.achievements, "show_absage")


func test_formate_bis_zum_ende(t) -> void:
	for fmt in ["fragerunde", "talkshow", "diskussion"]:
		var s := _make(6110)
		s.viewers.follower = 5000
		var d := TalkShow.start_format(s, fmt)
		t.eq(d.kind, "talkshow", "%s: Dialog" % fmt)
		t.eq(s.talkShow.format, fmt, "%s: Format gemerkt" % fmt)
		t.eq(s.talkShow.questions.size(), 3, "%s: drei Fragen" % fmt)
		for q in s.talkShow.questions:
			t.ok(not String(q.text).contains("{"), "%s: Platzhalter ersetzt" % fmt)
			for a in q.answers:
				t.ok(not String(a.label).contains("{") and not String(a.reaction).contains("{"), "%s: Antworten ersetzt" % fmt)
		var res := {}
		for i in 3:
			res = Game.answer_talk_show(s, 0)
			t.ok(res.ok, "%s: Antwort %d" % [fmt, i + 1])
		t.ok(res.get("finished", false), "%s: Sendung vorbei" % fmt)
		t.has(s.achievements, "primetime")
	var s2 := _make(6111)
	TalkShow.start_format(s2, "fragerunde")
	for i in 3:
		Game.answer_talk_show(s2, 0)
	t.has(s2.achievements, "show_fragerunde")


func test_show_zwischen_den_etagen_nur_fuer_bekannte(t) -> void:
	var s := _make()
	s.viewers.follower = 10
	t.eq(TalkShow.start(s), null, "Unbekannte: keine Show")
	s.viewers.follower = 500
	TalkShow.start(s)
	t.eq(s.talkShow.format, "fragerunde", "Aufsteiger: Fragerunde")
	s.viewers.follower = 5000
	TalkShow.start(s)
	t.eq(s.talkShow.format, "talkshow", "Bekannte: Talkshow")


func test_grube_sieg(t) -> void:
	var s := _make()
	var safe := _into_safe(s)
	var map_before: Dictionary = s.map
	var pos: Dictionary = s.player.pos.duplicate()
	var boxes: int = s.player.boxes.size()
	s.player.level = 6
	s.invitation = {"format": "gladiator", "until": s.turn + 100}
	t.ok(Game.accept_invitation(s).ok, "angenommen")
	t.ok(Arena.active(s), "in der Grube")
	t.ok(not is_same(s.map, map_before), "eigene Karte")
	t.eq(s.monsters.size(), 1, "ein Gegner")
	var m: Dictionary = s.monsters[0]
	t.eq(m.rank, "elite", "Elite-Gegner")
	# Gegner direkt neben den Crawler stellen und schwächen
	m.pos = {"x": s.player.pos.x + 1, "y": s.player.pos.y}
	m.hp = 1
	m.dmg = [0, 0]
	m.abilities = []
	for i in 60:
		if not Arena.active(s):
			break
		Game.attack(s, m.uid, {"part": "faust", "move": "normal", "zone": "koerper"})
	t.ok(not Arena.active(s), "Kampf vorbei")
	t.ok(is_same(s.map, map_before), "zurück auf der Etage")
	t.eq(s.player.pos, pos, "am alten Platz")
	t.gt(s.player.boxes.size(), boxes, "Schläger-Box")
	t.has(s.achievements, "show_gladiator")
	t.eq(s.status, "playing", "lebt")
	t.ok(Combat.is_in_safe_room(s, s.player.pos), "wieder im Safe Room %s" % safe.name)


func test_grube_niederlage_ist_nicht_der_tod(t) -> void:
	var s := _make()
	_into_safe(s)
	var map_before: Dictionary = s.map
	s.pendingDialogs.append(Arena.start(s))
	s.player.hp = 1
	Death.handle_lethal(s, "Test")
	t.eq(s.status, "playing", "nicht gestorben")
	Game.wait(s)
	t.ok(not Arena.active(s), "Kampf vorbei")
	t.ok(is_same(s.map, map_before), "zurück auf der Etage")
	t.ge(s.player.hp, 1, "lebt")
	t.has(s.achievements, "show_gladiator_verloren")


func test_grube_haelt_die_etage_an(t) -> void:
	var s := _make()
	_into_safe(s)
	s.player.blase = 99.95
	s.invitation = {"format": "talkshow", "until": s.turn + 100}
	s.pendingDialogs.append(Arena.start(s))
	# Der Gegner liegt noch am Boden (nur für den Test)
	s.monsters[0].downed = 100
	for i in 5:
		Game.wait(s)
	t.ok(Arena.active(s), "Kampf läuft noch")
	t.eq(float(s.player.blase), 99.95, "Blase pausiert in der Grube")
	t.not_null(Invitations.pending(s), "Einladung bleibt")
