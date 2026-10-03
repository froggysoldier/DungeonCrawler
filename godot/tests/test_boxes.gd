extends RefCounted
## Boxinhalte passen zum Boxtyp, ab Gold liegt ein magischer Gegenstand bei,
## normale Monster lassen selten Ausrüstung fallen.


func _magic(it: Dictionary) -> bool:
	return Db.unique_item(String(it.baseId)) != null or it.get("spell") != null


func test_boxinhalt_passt_zum_typ(t) -> void:
	var s := TH.make(5101, {"beruf": 1})
	s.floor = 2
	for type in ["waffen", "schuh", "kleidung", "schmuck", "brawler", "wurf", "ueberlebens"]:
		var slots: Array = Items.box_theme(type).slots
		for i in 30:
			for it in Items.roll_box_contents(s, type, "silber"):
				if it.kind == "ausruestung" and not _magic(it):
					t.has(slots, it.slot, "%s-Box: passendes Teil (%s)" % [type, it.slot])


func test_wurf_und_ueberlebensboxen_bringen_verbrauchsgut(t) -> void:
	var s := TH.make(5102, {"beruf": 1})
	s.floor = 2
	var wurf := 0
	var heil := 0
	for i in 40:
		for it in Items.roll_box_contents(s, "wurf", "bronze"):
			if it.kind == "wurf" and not ["stein", "ziegel"].has(it.baseId):
				wurf += 1
		for it in Items.roll_box_contents(s, "ueberlebens", "bronze"):
			if it.kind == "verbrauch":
				heil += 1
	t.gt(wurf, 15, "Wurf-Box: Wurfsterne, Bomben und Co.")
	t.gt(heil, 20, "Überlebens-Box: Heil- und Gegenmittel")


func test_ab_gold_ein_magischer_gegenstand(t) -> void:
	var s := TH.make(5103, {"beruf": 1})
	s.floor = 2
	var order: Array = Db.t("items", "RARITY_ORDER")
	for type in Db.world("BOX_TYPE_NAMES").keys():
		for i in 10:
			var items := Items.roll_box_contents(s, type, "gold")
			var magic := items.filter(_magic)
			t.ok(not magic.is_empty() or (type == "haustier" and J.some(items, func(it): return it.baseId == "ei_drache")), "%s-Box Gold: magischer Gegenstand" % type)
			for m in magic:
				t.le(order.find(m.rarity), order.find(Items.cap_rarity(s, "himmlisch", type == "boss")), "%s: innerhalb der Etagengrenze" % type)
				var allowed = Items.box_theme(type).magic
				if Db.unique_item(String(m.baseId)) != null and allowed is Array:
					t.has(allowed, m.baseId, "%s: Unikat passt zum Typ" % type)
	# Bronze und Silber nur in seltenen Ausnahmen
	var n := 0
	for i in 100:
		n += Items.roll_box_contents(s, "waffen", "bronze").filter(_magic).size()
	t.eq(n, 0, "Bronze: nichts Magisches")


func test_meister_goldbox_auf_etage_1(t) -> void:
	var s := TH.make(5104, {"beruf": 1})
	s.floor = 1
	var box := Items.create_box(s, "boss", "gold", true)
	t.eq(box.box.tier, "gold", "Meisterleistung: Gold auf Etage 1")
	for i in 10:
		var magic := Items.roll_box_contents(s, "boss", "gold", 1, true).filter(_magic)
		t.ok(not magic.is_empty(), "magischer Gegenstand dabei")


func test_mobs_lassen_selten_ausruestung_fallen(t) -> void:
	var s := TH.make(5105, {"beruf": 1})
	s.floor = 1
	var gear := 0
	var n := 4000
	var order: Array = Db.t("items", "RARITY_ORDER")
	for i in n:
		for it in Items.roll_mob_drop(s, 2, false):
			if it.kind == "ausruestung" and it.get("rarity") != null:
				t.le(order.find(it.rarity), order.find("selten"), "Etage 1: höchstens selten")
				gear += 1
	var rate := float(gear) / n
	# 5 % Ausrüstungsfund plus gelegentlich ein getragenes Teil unter dem Kleinkram
	t.ok(rate > 0.04 and rate < 0.13, "etwa 5 %% Ausrüstung (%.3f)" % rate)


func test_gold_tiefer_haeufiger_platin_nur_meister(t) -> void:
	var s := TH.make(5106, {"beruf": 1})
	var gold := {}
	for fl in [1, 2, 3]:
		s.floor = fl
		gold[fl] = 0
		for i in 400:
			var b := Items.create_box(s, "abenteurer", "silber")
			if b.box.tier == "gold":
				gold[fl] += 1
		for tier in ["platin", "legendaer", "himmlisch"]:
			t.ok(Items.create_box(s, "boss", tier).box.tier != "platin", "Etage %d: Platin nicht ohne Meisterleistung" % fl)
		t.eq(Items.create_box(s, "boss", "platin", true).box.tier, "gold" if fl == 1 else "platin", "Etage %d: Meisterleistung" % fl)
	t.eq(gold[1], 0, "Etage 1: Silber bleibt Silber")
	t.gt(gold[2], 20, "Etage 2: manchmal Gold")
	t.gt(gold[3], gold[2] + 30, "Etage 3: öfter Gold")
