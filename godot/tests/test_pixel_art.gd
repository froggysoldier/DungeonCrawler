extends RefCounted
## Pixel-Bögen: Zu allem, was das Spiel zeichnet, gibt es ein Bild, und das
## Tönen ersetzt die Magenta-Schlüssel vollständig.


func _missing(names: Array) -> Array:
	return names.filter(func(n): return not PixelArt.has(n))


func test_index_passt_zu_den_boegen(t) -> void:
	var bad: Array = []
	for n in PixelArt.names():
		var e := PixelArt.entry(n)
		var tex := PixelArt.sheet(e.sheet)
		if tex == null or not Rect2i(Vector2i.ZERO, tex.get_size()).encloses(e.rect):
			bad.append(n)
	t.eq(bad, [], "Alle Bilder liegen innerhalb ihres Bogens")
	t.gt(PixelArt.names().size(), 100, "Bilder vorhanden")


func test_jedes_monster_hat_eine_figur(t) -> void:
	var names: Array = []
	for list in [Db.t("monsters", "MONSTERS"), Db.t("monsters", "HOOD_BOSSES")]:
		for m in list:
			names.append(Sprites.sprite_name(m.id))
	names.append(Sprites.sprite_name("", true))
	for m in Db.t("monsters", "HOOD_BOSSES"):
		t.ok(Sprites.sprite_name(m.id).begins_with("boss/"), "%s hat eine eigene Figur" % m.id)
	for n in ["held", "haustier", "mensch"]:
		names.append("kreatur/" + n)
	t.eq(_missing(names), [], "Figuren")


func test_fallen_reittiere_einrichtung(t) -> void:
	var names: Array = []
	for k in Traps.TRAP_DEFS:
		names.append("falle/" + ("baerenfalle" if k == "schlingfalle" else k))
	for id in Db.t("mounts", "MOUNTS"):
		names.append("reittier/" + id)
	for k in ["automat", "bett", "toilette", "theke"] + MapView.PROPS:
		names.append("moebel/" + k)
	for k in Sprites.ITEM_SPRITES.values() + ["edelstein", "stein", "bombe"]:
		names.append("ding/" + k)
	t.eq(_missing(names), [], "Fallen, Reittiere, Möbel, Gegenstände")


func test_haustiere_und_zweite_bilder(t) -> void:
	var names: Array = []
	for species in Db.t("pets", "PET_SPECIES"):
		var look := Sprites.pet_sprite(species)
		t.ok(look[0] != "kreatur/haustier", "%s hat ein eigenes Bild" % species)
		names.append(look[0])
	t.eq(_missing(names), [], "Haustier-Bilder")
	var pairs := 0
	for n in PixelArt.names("kreatur/"):
		if String(n).ends_with("_2"):
			pairs += 1
			var base := String(n).trim_suffix("_2")
			t.ok(PixelArt.has(base), "%s hat ein erstes Bild" % n)
			t.eq(PixelArt.size_of(n), PixelArt.size_of(base), "%s gleich groß" % n)
	t.ge(pairs, 9, "zweite Bilder")
	t.eq(_missing(["moebel/fackel", "moebel/fackel_2"]), [], "Fackel")


func test_kacheln_vollstaendig(t) -> void:
	var names: Array = ["treppe"]
	for mat in Tiles.MATERIALS:
		for v in 4:
			names.append("boden/%s%d" % [mat, v])
	for fl in [1, 2, 3]:
		for v in 4:
			names.append("wand/%d_oben%d" % [fl, v])
			names.append("wand/%d_front%d" % [fl, v])
	for open in [false, true]:
		for hor in [false, true]:
			for boss in [false, true]:
				names.append(MapView.door_name(open, hor, boss))
	t.eq(_missing(names), [], "Böden, Wände, Türen")


func test_toenen_ersetzt_alle_schluessel(t) -> void:
	var keys: Array = PixelArt.TINT_KEYS.map(func(c): return Color(c))
	var tex := PixelArt.texture("kreatur/ratte", "#b08a6a")
	var img := tex.get_image()
	var left := 0
	for y in img.get_height():
		for x in img.get_width():
			var p := img.get_pixel(x, y)
			for k in keys:
				if p.a > 0.5 and p.is_equal_approx(k):
					left += 1
	t.eq(left, 0, "keine Magenta-Pixel übrig")
	var r := PixelArt.ramp(Color("#b08a6a"))
	t.eq(r.size(), 5, "fünf Stufen")
	t.lt(r[0].v, r[2].v, "Schatten dunkler als Grundfarbe")
	t.gt(r[4].v, r[2].v, "Glanz heller als Grundfarbe")
	t.ok(PixelArt.texture("kreatur/ratte", "#b08a6a") == tex, "Zwischenspeicher")


func test_gegenstaende_und_plaetze_haben_bilder(t) -> void:
	var names: Array = []
	for slot in GameTabs.EQUIP_ORDER:
		var n := Sprites.slot_sprite(slot)
		t.ok(n.begins_with("ding/slot_"), "%s hat ein eigenes Symbol" % slot)
		names.append(n)
	t.eq(Sprites.slot_sprite("ring2"), "ding/slot_ring", "zweiter Ring")
	t.eq(Sprites.slot_sprite("fussring1"), "ding/slot_fussring", "Fußring")
	var kinds := {}
	for base in Db.t("items", "BASE_ITEMS"):
		var it: Dictionary = base.duplicate()
		it.rarity = "selten"
		var look := Sprites.item_sprite(it)
		names.append(look[0])
		kinds[it.kind] = true
		if it.get("slot") != null:
			t.eq(look[0], "ding/slot_" + it.slot, "%s zeigt seinen Platz" % it.id)
			t.eq(look[1], GameTabs.rarity_color("selten"), "%s in Seltenheitsfarbe" % it.id)
	t.ok(kinds.has("ausruestung") and kinds.has("wurf") and kinds.has("verbrauch"), "Arten abgedeckt")
	names.append(Sprites.item_sprite({"kind": "box", "rarity": "gewoehnlich", "box": {"tier": "bronze"}})[0])
	t.eq(_missing(names), [], "Bilder für Gegenstände")


func test_bilder_in_der_oberflaeche(t) -> void:
	# Im Fließtext: [img] findet die getönte, vergrößerte Textur
	var bb := Kit.img("ding/slot_waffe", "#5aa0ff", 2)
	t.matches(bb, "^\\[img=32x32\\]res://pixel_bb/.+\\[/img\\]$", "BBCode mit Größe")
	var path := bb.get_slice("]", 1).get_slice("[", 0)
	var tex: Texture2D = load(path)
	t.not_null(tex, "Textur über den Pfad ladbar")
	if tex != null:
		t.eq(tex.get_size(), Vector2(32, 32), "vorab vergrößert")
		t.gt(tex.get_image().get_used_rect().size.x, 0, "nicht leer")
	t.eq(Kit.img("ding/gibt_es_nicht"), "", "unbekanntes Bild")
	# Als Control: Größe ist das vergrößerte Bild oder das vorgegebene Feld
	var ic := Kit.icon(null, "kreatur/ratte", "#b08a6a", 3)
	t.eq(ic.custom_minimum_size, Vector2(48, 48), "Figur dreifach")
	ic.free()
	var slot := Kit.icon(null, "ding/slot_ring", null, 2, Vector2(40, 36), true)
	t.eq(slot.custom_minimum_size, Vector2(40, 36), "festes Feld")
	t.lt(slot.items[0].mod.a, 1.0, "leerer Platz abgeblendet")
	slot.free()


func _gear(slot: String, rarity: String) -> Dictionary:
	return {"kind": "ausruestung", "slot": slot, "rarity": rarity}


func test_ausruestung_an_der_figur(t) -> void:
	for slot in Sprites.GEAR_BEHIND + Sprites.GEAR_FRONT:
		t.ok(PixelArt.has("ausruestung/" + slot), "%s hat einen Aufsatz" % slot)
		t.has(GameTabs.EQUIP_ORDER, slot, "%s ist ein Ausrüstungsplatz" % slot)
	t.eq(Sprites.hero_name({"equipment": {}}), "kreatur/held", "ohne Ausrüstung die schlichte Figur")
	t.eq(Sprites.hero_name({"equipment": {"ring1": _gear("ring", "episch")}}), "kreatur/held", "Ringe sieht man nicht")
	var eq := {"kopf": _gear("kopf", "selten"), "waffe": _gear("waffe", "episch"), "fuesse": _gear("fuesse", "gewoehnlich")}
	var n := Sprites.hero_name({"equipment": eq})
	t.ok(n != "kreatur/held" and PixelArt.has(n) and PixelArt.has(n + "_2"), "zusammengesetzt, mit Laufbild")
	t.eq(PixelArt.size_of(n), PixelArt.size_of("kreatur/held"), "gleich groß wie die Figur")
	t.eq(Sprites.hero_name({"equipment": eq}), n, "gleiche Ausrüstung, gleicher Name")
	var img := PixelArt.image(n)
	var base := PixelArt.image("kreatur/held")
	t.ok(img.get_pixel(7, 1) != base.get_pixel(7, 1), "Helm über den Haaren")
	t.eq(img.get_pixel(7, 4), base.get_pixel(7, 4), "Gesicht bleibt frei")
	t.eq(img.get_pixel(13, 1), Sprites.OUTLINE, "Umriss um die Waffenspitze")
	t.ok(PixelArt.image(n + "_2").get_pixel(3, 13) != img.get_pixel(3, 13), "Stiefel im Laufbild versetzt")
	var eq2 := eq.duplicate(true)
	eq2.kopf.rarity = "episch"
	t.ok(Sprites.hero_name({"equipment": eq2}) != n, "andere Seltenheit, andere Figur")
	t.not_null(PixelArt.texture(n), "tönbar wie jedes Bild")
	t.not_null(PixelArt.silhouette(n), "Aufblitzen möglich")


func test_truhe_beim_oeffnen(t) -> void:
	t.eq(PixelArt.size_of("ding/truhe_offen"), PixelArt.size_of("ding/truhe"), "offene Truhe gleich groß")
	var shut := PixelArt.image("ding/truhe")
	var open := PixelArt.image("ding/truhe_offen")
	var same := true
	for y in range(8, 12):
		for x in 16:
			if shut.get_pixel(x, y) != open.get_pixel(x, y):
				same = false
	t.ok(same, "Unterteil deckungsgleich, damit die Truhe beim Aufspringen nicht springt")
	for tier in Db.world("BOX_TIERS"):
		t.ok(Db.world("BOX_TIER_COLORS").has(tier), "%s hat eine Farbe" % tier)
		t.ok(SoundBox.TIER_RANK.has(tier), "%s hat einen Klang" % tier)
	var root := VBoxContainer.new()
	t.eq(GameDialogs._chest(root, null), 0.0, "ohne Box keine Truhe")
	t.eq(root.get_child_count(), 0, "nichts eingefügt")
	var delay := GameDialogs._chest(root, "gold")
	t.gt(delay, GameDialogs.Chest.OPEN_AT, "Gegenstände erst nach dem Aufspringen")
	var c = root.get_child(0)
	t.ok(c is GameDialogs.Chest, "Truhe eingefügt")
	t.eq(c.color, Color(Db.world("BOX_TIER_COLORS")["gold"]), "Farbe der Box-Stufe")
	root.free()
