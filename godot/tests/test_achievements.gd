extends RefCounted
## Achievements und Statistik.


func _make(seed: int = 5150) -> Dictionary:
	return TH.make(seed, {"beruf": 1})


func test_umfang_eindeutig(t) -> void:
	var all: Array = Db.t("achievements", "ACHIEVEMENTS")
	t.gt(all.size(), 400, "Anzahl")
	t.eq(J.uniq(all.map(func(a): return a.id)).size(), all.size(), "IDs eindeutig")
	var names: Array = all.map(func(a): return a.name)
	var dupes := []
	for i in names.size():
		if names.find(names[i]) != i:
			dupes.append(names[i])
	t.eq(dupes, [], "Namen eindeutig")


func test_kategorie_beschreibung_kommentar(t) -> void:
	var cats: Array = Db.t("achievements", "ACHIEVEMENT_CATEGORIES").map(func(c): return c.id)
	var all: Array = Db.t("achievements", "ACHIEVEMENTS")
	var bad := []
	for a in all:
		if not cats.has(a.category) or String(a.description).length() <= 5 or String(a.comment).length() <= 5:
			bad.append(a.id)
	t.eq(bad, [], "vollständig")
	for c in cats:
		t.ok(J.some(all, func(a): return a.category == c), "Kategorie %s gefüllt" % c)


func test_keine_emojis(t) -> void:
	var re := RegEx.create_from_string("[\\x{1F300}-\\x{1FAFF}\\x{2600}-\\x{27BF}\\x{1F000}-\\x{1F2FF}]")
	var bad := []
	for a in Db.t("achievements", "ACHIEVEMENTS"):
		if re.search("%s %s %s" % [a.name, a.description, a.comment]) != null:
			bad.append(a.id)
	t.eq(bad, [], "keine Emojis")


func test_kills_werden_gezaehlt(t) -> void:
	var s := _make()
	var m := TH.foe(s, "kellerratte", 1)
	m.asleep = true
	Combat.kill_monster(s, m, {"part": "tritt", "move": "normal", "zone": "kopf"}, false, ["t:tritt"])
	for k in ["kills", "kills.art.kellerratte", "bestiarium.arten", "kills.teil.tritt", "kills.zone.kopf", "kills.schlafend"]:
		t.eq(Stats.stat(s, k), 1.0, k)
	t.has(s.achievements, "fam_schlafend_1")


func test_bestiarium_nur_erkannte_arten(t) -> void:
	var s := _make()
	var big := TH.foe(s, "kellerratte", 1)
	big.level = s.player.level + 12
	Combat.kill_monster(s, big, {"part": "faust", "move": "normal"})
	t.eq(Stats.stat(s, "kills.unbekannt"), 1.0, "unbekannt gezählt")
	t.lacks(s.achievements, "art_kellerratte_1")
	t.has(s.achievements, "mo_unbekannt")
	var small := TH.foe(s, "kellerratte", 1)
	Combat.kill_monster(s, small, {"part": "faust", "move": "normal"})
	t.has(s.achievements, "art_kellerratte_1")


func test_ohne_box_nur_ruhm(t) -> void:
	var s := _make()
	TH.ready(s)
	var boxes: int = s.player.boxes.size()
	if s.get("stats") == null:
		s.stats = {}
	s.stats["tueren.geoeffnet"] = 1
	Events.emit(s, {"type": "moved"})
	t.has(s.achievements, "fam_tueren_1")
	t.eq(s.player.boxes.size(), boxes, "keine Box")
	s.stats["tueren.geoeffnet"] = 10
	Events.emit(s, {"type": "moved"})
	t.has(s.achievements, "fam_tueren_10")
	t.eq(s.player.boxes.size(), boxes, "Bronze: keine Box")
	s.stats["tueren.geoeffnet"] = 30
	Events.emit(s, {"type": "moved"})
	t.has(s.achievements, "fam_tueren_30")
	t.eq(s.player.boxes.size(), boxes + 1, "ab Silber eine Box")


func test_konter_kills(t) -> void:
	var s := _make()
	var m := TH.foe(s, "kellerratte", 1)
	m.hp = 1
	Combat.counter_strike(s, m)
	t.ok(not J.has_same(s.monsters, m), "besiegt")
	t.eq(Stats.stat(s, "kills.konter"), 1.0, "Konter-Kill")
	t.eq(Stats.stat(s, "_konter"), 0.0, "Hilfswert zurückgesetzt")


func test_boss_makellos(t) -> void:
	var s := _make()
	var boss := TH.foe(s, "kellerratte", 1)
	boss.rank = "nachbarschaftsboss"
	s.player.hp = Player.max_hp(s)
	Combat.kill_monster(s, boss, {"part": "faust", "move": "sprung"})
	t.has(s.achievements, "mo_boss_makellos")
	t.has(s.achievements, "mo_boss_sprung")


func test_rettung_durch_haustier(t) -> void:
	var s := _make()
	var m := TH.foe(s, "kellerratte", 1)
	s.player.hp = 1
	Combat.kill_monster(s, m, null, true)
	t.has(s.achievements, "mo_rettung_haustier")


func test_anatomiestunde(t) -> void:
	var s := _make()
	var m := TH.foe(s, "kellerratte", 1)
	m.zonesHit = ["kopf", "arme", "beine"]
	Combat.kill_monster(s, m, {"part": "faust", "move": "normal"})
	t.has(s.achievements, "mo_anatomie")


func test_doppelaufstieg(t) -> void:
	var s := _make()
	TH.ready(s)
	var turn: int = s.turn
	Events.emit(s, {"type": "levelUp", "level": 2})
	t.lacks(s.achievements, "mo_doppelaufstieg")
	t.eq(s.turn, turn, "kein Zug vergangen")
	Events.emit(s, {"type": "levelUp", "level": 3})
	t.has(s.achievements, "mo_doppelaufstieg")


func test_fruehe_etage(t) -> void:
	var s := _make()
	TH.ready(s)
	s.player.level = 3
	Events.emit(s, {"type": "descend", "floor": 2})
	t.has(s.achievements, "mo_etage2_frueh")


func test_boxen_erst_ab_silber(t) -> void:
	var bad := []
	for a in Db.t("achievements", "ACHIEVEMENTS"):
		if a.tier == "bronze" and a.get("box") != null:
			bad.append(a.id)
	t.eq(bad, [], "Bronze-Achievements ohne Box")


func test_boxstufe_je_etage(t) -> void:
	var s := _make()
	s.floor = 1
	t.eq(Items.create_box(s, "abenteurer", "gold").box.tier, "silber", "Etage 1: höchstens Silber")
	t.eq(Items.create_box(s, "abenteurer", "platin", true).box.tier, "gold", "Meisterleistung auf Etage 1: Gold")
	t.eq(Items.create_box(s, "abenteurer", "bronze").box.tier, "bronze", "darunter unverändert")
	s.floor = 2
	t.eq(Items.create_box(s, "abenteurer", "platin").box.tier, "gold", "Etage 2: höchstens Gold")
	t.eq(Items.create_box(s, "abenteurer", "platin", true).box.tier, "platin", "Meisterleistung ab Etage 2: Platin")


func _boss_beside(s: Dictionary, rank: String) -> Dictionary:
	var bd = J.find(Db.t("monsters", "HOOD_BOSSES"), func(b): return b.rank == rank)
	var m := Monsters.spawn_boss(s, bd, TH.free_neighbor(s, s.player.pos), 0, -1, 1)
	s.monsters.append(m)
	return m


func test_meister_einzelkaempfer_und_faustrecht(t) -> void:
	var s := _make()
	TH.ready(s)
	s.player.pet = null
	var m := _boss_beside(s, "boroughboss")
	m.hitBy = ["faust"]
	var boxes: int = s.player.boxes.size()
	Combat.kill_monster(s, m, {"part": "faust", "move": "normal"})
	t.has(s.achievements, "meister_einzelkaempfer", "allein")
	t.has(s.achievements, "meister_faustrecht", "nur Fäuste")
	var gold: Array = s.player.boxes.slice(boxes).filter(func(b): return b.box.tier == "gold" and b.box.special)
	t.ge(gold.size(), 2, "Gold-Boxen auf Etage 1, nur durch Meisterleistung")


func test_meister_unberuehrbar(t) -> void:
	var s := _make()
	TH.ready(s)
	var hit := _boss_beside(s, "nachbarschaftsboss")
	hit.hitPlayer = true
	Combat.kill_monster(s, hit, {"part": "faust", "move": "normal"})
	t.lacks(s.achievements, "meister_unberuehrbar", "getroffen: nein")
	var clean := _boss_beside(s, "nachbarschaftsboss")
	Combat.kill_monster(s, clean, {"part": "faust", "move": "normal"})
	t.has(s.achievements, "meister_unberuehrbar", "nie getroffen: ja")


func test_meister_gewaltfrei(t) -> void:
	var s := _make()
	TH.ready(s)
	s.counters.kills = 0
	Events.emit(s, {"type": "descend", "floor": 2})
	t.has(s.achievements, "meister_gewaltfrei", "ohne Kill auf Etage 2")
