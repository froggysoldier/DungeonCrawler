extends RefCounted
## Einlagen der Show: zeitlich begrenzte Ereignisse mit Boni, Kopfgeld,
## neue Verbrauchsgegenstände und der Kopfgeld-Sponsor.


func _ready_state(seed: int) -> Dictionary:
	var s := TH.make(seed, {"beruf": 1})
	TH.ready(s)
	return s


func test_erst_nach_dem_tutorial(t) -> void:
	var s := TH.make(6101, {"beruf": 1})
	for i in 400:
		s.turn += 1
		ShowEvents.tick(s, 1)
	t.eq(ShowEvents.active(s), null, "vor dem Tutorial keine Einlage")


func test_kommt_und_geht(t) -> void:
	var s := _ready_state(6102)
	var seen := {}
	var ended := 0
	for i in 3000:
		s.turn += 1
		var was = ShowEvents.active(s)
		ShowEvents.tick(s, 1)
		var now = ShowEvents.active(s)
		if now != null:
			seen[now.id] = true
		if was != null and now == null:
			ended += 1
	t.ge(seen.size(), 3, "verschiedene Einlagen (%s)" % ", ".join(seen.keys()))
	t.ge(ended, 3, "Einlagen enden auch wieder")
	t.ge(int(J.num(s.stats, "einlagen")), 3, "gezählt")


func test_doppelte_erfahrung(t) -> void:
	var s := _ready_state(6103)
	s.player.xp = 0
	var plain := Player.gain_xp(s, 10)
	t.ok(ShowEvents.start(s, "doppelxp"), "gestartet")
	var double := Player.gain_xp(s, 10)
	t.eq(double, plain * 2, "doppelt so viel")
	t.ok(ShowEvents.label(s) != "", "Anzeige")


func test_licht_aus(t) -> void:
	var s := _ready_state(6104)
	var before := Player.lichtradius(s)
	ShowEvents.start(s, "licht_aus")
	t.eq(Player.lichtradius(s), before - 2, "Sichtweite kleiner")


func test_goldrausch_und_schnaeppchen(t) -> void:
	var s := _ready_state(6105)
	t.eq(ShowEvents.gold_factor(s), 1.0, "normal")
	ShowEvents.start(s, "goldrausch")
	t.eq(ShowEvents.gold_factor(s), 3.0, "dreifach")
	s.erase("showEvent")
	var it := Items.create_item(s, "heiltrank")
	var full := Shop.offer_price(100, it, s)
	ShowEvents.start(s, "schnaeppchen")
	t.lt(Shop.offer_price(100, it, s), full, "billiger")


func test_kopfgeld(t) -> void:
	var s := _ready_state(6106)
	var m := TH.beside(s, "kellerratte", 3)
	t.ok(ShowEvents.start(s, "kopfgeld"), "Kopfgeld ausgesetzt")
	t.eq(s.showEvent.bountyUid, m.uid, "einziges Ziel markiert")
	var gold: int = s.player.gold
	var reward := int(m.bounty)
	Combat.kill_monster(s, m, {"part": "faust", "move": "normal"})
	t.ge(s.player.gold, gold + reward, "Belohnung gezahlt")
	t.eq(ShowEvents.active(s), null, "Einlage vorbei")
	t.eq(int(J.num(s.stats, "kopfgelder")), 1, "gezählt")


func test_kopfgeld_verfaellt(t) -> void:
	var s := _ready_state(6107)
	var m := TH.beside(s, "kellerratte", 2)
	ShowEvents.start(s, "kopfgeld")
	s.showEvent.left = 1
	ShowEvents.tick(s, 1)
	t.eq(ShowEvents.active(s), null, "abgelaufen")
	t.ok(not m.get("bounty"), "Markierung weg")


func test_einlage_endet_beim_abstieg(t) -> void:
	var s := _ready_state(6108)
	ShowEvents.start(s, "erste_hilfe")
	TH.teleport(s, TH.stairs(s))
	Game.descend(s, {"ghosts": []})
	t.eq(ShowEvents.active(s), null, "neue Etage, neues Programm")


func test_neue_gegenstaende(t) -> void:
	var s := _ready_state(6109)
	for id in ["kuehlpack", "augentropfen", "baldrian", "glueckskeks", "fokuspille", "spruehlack", "thermoskanne"]:
		t.ok(Items.base_exists(id), id)
	Conditions.inflict_player(s, "brennen", 3, 1, "Test")
	t.ok(Conditions.player_has(s, "brennen"), "brennt")
	var it := Items.create_item(s, "kuehlpack")
	s.player.inventory.append(it)
	t.ok(Game.use_item(s, it.uid).ok, "benutzt")
	t.ok(not Conditions.player_has(s, "brennen"), "gelöscht")
	var keks := Items.create_item(s, "glueckskeks")
	s.player.inventory.append(keks)
	Game.use_item(s, keks.uid)
	t.ok(J.some(s.player.buffs, func(b): return b.name == "Glückspilz"), "Glückspilz")


func test_kopfgeld_sponsor(t) -> void:
	t.not_null(Db.sponsor("kopfjaeger"), "Sponsor da")
	t.eq(Sponsors.signals_of({"type": "bountyClaimed"}), ["bounty"], "Signal Kopfgeld")
	t.eq(Sponsors.signals_of({"type": "showEvent", "id": "doppelxp"}), ["showEvent"], "Signal Einlage")
