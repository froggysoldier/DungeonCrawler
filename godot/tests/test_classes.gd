extends RefCounted
## Klassen und Rassen (Port von tests/classes.test.ts).


func test_viele_klassen_und_rassen(t) -> void:
	var classes: Array = Db.t("classes", "CLASSES")
	var races: Array = Db.t("races", "RACES")
	t.ge(classes.size(), 45, "Klassen")
	t.ge(races.size(), 24, "Rassen")
	t.eq(J.uniq(classes.map(func(c): return c.id)).size(), classes.size(), "Klassen-IDs")
	t.eq(J.uniq(classes.map(func(c): return c.name)).size(), classes.size(), "Klassennamen")
	t.eq(J.uniq(races.map(func(r): return r.id)).size(), races.size(), "Rassen-IDs")


func test_verweise_existieren(t) -> void:
	var abilities: Dictionary = Db.t("classes", "ABILITIES")
	var specials: Dictionary = Db.t("specials", "SPECIAL_TEXT")
	var bad := []
	for c in Db.t("classes", "CLASSES"):
		if not abilities.has(c.ability):
			bad.append("%s: Fähigkeit" % c.id)
		if c.skills.is_empty():
			bad.append("%s: keine Skills" % c.id)
		for id in c.skills:
			if Db.skill(id) == null:
				bad.append("%s: %s" % [c.id, id])
		for id in J.arr(c, "spells"):
			if Db.spell(id) == null:
				bad.append("%s: %s" % [c.id, id])
		for g in J.arr(c, "gear"):
			if Db.base_item(g[0]) == null:
				bad.append("%s: %s" % [c.id, g[0]])
		for sp in J.arr(c, "specials"):
			if not specials.has(sp):
				bad.append("%s: %s" % [c.id, sp])
		if c.rarity != "normal" and c.get("requirement") == null:
			bad.append("%s: Bedingung fehlt" % c.id)
	for r in Db.t("races", "RACES"):
		if r.get("talent") != null and Db.skill(r.talent) == null:
			bad.append("%s: %s" % [r.id, r.talent])
		for sp in J.arr(r, "specials"):
			if not specials.has(sp):
				bad.append("%s: %s" % [r.id, sp])
	t.eq(bad, [], "alle Verweise gültig")


func test_klassenliste(t) -> void:
	var s := TH.make(3100)
	var opts := Classes.class_options(s)
	t.eq(opts.filter(func(o): return o.klass.rarity == "normal").size(), Classes.CLASS_LIST_SIZE, "zehn gewöhnliche")
	t.ok(not J.some(opts, func(o): return o.klass.rarity != "normal"), "keine seltenen")
	t.eq(opts.filter(func(o): return o.get("recommended", false)).size(), 3, "drei Empfehlungen")
	if s.get("stats") == null:
		s.stats = {}
	s.stats["knapp.ueberlebt"] = 12
	t.ok(J.some(Classes.class_options(s), func(o): return o.klass.id == "todesveraechter"), "seltene Klasse erscheint")


func test_empfehlung_folgt_interview(t) -> void:
	var s := TH.make(3101)
	var tr: Array = J.arr(s.player, "traits").duplicate()
	tr.append("social_media")
	s.player.traits = tr
	var o = J.find(Classes.class_options(s), func(x): return x.klass.id == "influencer")
	t.ok(o != null and o.get("recommended", false), "Influencer empfohlen")


func test_wahl_vergibt_alles(t) -> void:
	var s := TH.make(3102)
	TH.to_floor3(s)
	s.player.stats.int = 12
	s.player.techniqueUses = {}
	t.not_null(J.find(Classes.class_options(s), func(o): return o.klass.id == "kellermagier"), "Kellermagier angeboten")
	t.ok(Classes.choose(s, "elf", "kellermagier").ok, "Wahl")
	var p: Dictionary = s.player
	t.has(p.classSkills, "arkane_kunde")
	t.has(p.classSkills, "wahrnehmung")
	t.ge(J.find(p.skills, func(k): return k.id == "arkane_kunde").level, 2, "Skillstufe")
	var spells: Array = J.arr(p, "spells").map(func(x): return x.id)
	t.has(spells, "geschoss")
	t.has(spells, "fackel")
	t.ok(J.some(p.inventory, func(i): return i.baseId == "kleiner_manatrank"), "Manatrank")


func test_gesperrte_wahl(t) -> void:
	var s := TH.make(3103)
	TH.to_floor3(s)
	t.eq(J.find(Classes.race_options(s), func(r): return r.race.id == "drachenblut").available, false, "Drachenblut gesperrt")
	t.ok(not Classes.choose(s, "drachenblut", Classes.class_options(s)[0].klass.id).ok, "Rasse abgelehnt")
	t.ok(not Classes.choose(s, "mensch", "wiedergaenger").ok, "Klasse abgelehnt")


func test_rattenfreund(t) -> void:
	var s := TH.make(3104)
	s.player.race = "rattling"
	var rat := Monsters.spawn_monster(s, Db.monster("kellerratte"), 1, s.player.pos, 0)
	t.ok(Extras.pass_protects(s, rat), "geschützt")
	rat.provoked = true
	t.ok(not Extras.pass_protects(s, rat), "nach Angriff nicht mehr")


func test_haendlerblut(t) -> void:
	var s := TH.make(3105)
	var it := Items.create_item(s, "heiltrank")
	var buy := Shop.offer_price(100, it, s)
	var sell := Shop.sell_price(it, s)
	s.player.klass = "marktschreier"
	t.lt(Shop.offer_price(100, it, s), buy, "günstiger kaufen")
	t.gt(Shop.sell_price(it, s), sell, "teurer verkaufen")


func test_zaeh(t) -> void:
	var s := TH.make(3106)
	s.player.klass = "todesveraechter"
	s.player.hp = Player.max_hp(s)
	var full := Player.total_bonuses(s)
	s.player.hp = 1
	var low := Player.total_bonuses(s)
	t.gt(J.num(J.nn(low, "schaden", {}), "alle"), J.num(J.nn(full, "schaden", {}), "alle"), "mehr Schaden")
	t.gt(J.num(low, "ausweichen"), J.num(full, "ausweichen"), "mehr Ausweichen")


func test_klassen_ueber_id(t) -> void:
	for c in Db.t("classes", "CLASSES"):
		t.ok(is_same(Db.klass(c.id), c), c.id)
