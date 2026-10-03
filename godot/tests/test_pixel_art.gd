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
	for open in [false, true]:
		for hor in [false, true]:
			for boss in [false, true]:
				names.append(MapView.door_name(open, hor, boss))
	t.eq(_missing(names), [], "Böden, Türen")
	for fl in [1, 2, 3]:
		var sheet := MapView.wall_sheet(fl)
		t.not_null(sheet, "Klippen-Block Etage %d" % fl)
		t.eq(sheet.get_size(), Vector2(256, 384), "4 x 6 Felder zu 64 Pixeln")


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


func test_feine_figuren(t) -> void:
	# Kreaturen und Bosse im Tiny-Swords-Stil: doppelt so fein, 48 Kunstpixel groß
	for n in ["kreatur/ratte", "kreatur/kobold", "kreatur/mensch", "boss/rattenkaiser"]:
		t.eq(PixelArt.res(n), 2, "%s fein gezeichnet" % n)
		t.eq(PixelArt.size_of(n), Vector2i(48, 48), "%s in Kunstpixeln" % n)
		t.eq(PixelArt.texture(n).get_size(), Vector2(96, 96), "%s als Bild" % n)
	t.eq(PixelArt.res("ding/trank"), 1, "Gegenstände im groben Raster")
	# Teamfarbe der Pack-Figuren ist tönbar
	var a := PixelArt.texture("kreatur/kobold", "#c03030").get_image()
	var b := PixelArt.texture("kreatur/kobold", "#3030c0").get_image()
	t.ok(a.get_data() != b.get_data(), "Kapuze in der Farbe der Monsterart")
	t.eq(Sprites.sprite_name("kobold_bombe"), "kreatur/kobold_tnt", "Bombenkobold mit Dynamit")


func test_bilder_in_der_oberflaeche(t) -> void:
	# Im Fließtext: [img] findet die getönte, vergrößerte Textur
	var bb := Kit.img("ding/slot_waffe", "#5aa0ff", 2)
	t.matches(bb, "^\\[img=64x64\\]res://pixel_bb/.+\\[/img\\]$", "BBCode mit Größe")
	var path := bb.get_slice("]", 1).get_slice("[", 0)
	var tex: Texture2D = load(path)
	t.not_null(tex, "Textur über den Pfad ladbar")
	if tex != null:
		t.eq(tex.get_size(), Vector2(64, 64), "vorab vergrößert")
		t.gt(tex.get_image().get_used_rect().size.x, 0, "nicht leer")
	t.eq(Kit.img("ding/gibt_es_nicht"), "", "unbekanntes Bild")
	# Als Control: Größe ist das vergrößerte Bild oder das vorgegebene Feld
	var ic := Kit.icon(null, "kreatur/ratte", "#b08a6a", 3)
	t.eq(ic.custom_minimum_size, Vector2(PixelArt.size_of("kreatur/ratte") * 3), "Figur dreifach")
	t.ok(Kit.img("ding/trank", null, 0.5).begins_with("[img=16x16]"), "im Text auch verkleinert")
	ic.free()
	var slot := Kit.icon(null, "ding/slot_ring", null, 2, Vector2(40, 36), true)
	t.eq(slot.custom_minimum_size, Vector2(40, 36), "festes Feld")
	t.lt(slot.items[0].mod.a, 1.0, "leerer Platz abgeblendet")
	slot.free()


func _gear(slot: String, rarity: String) -> Dictionary:
	return {"kind": "ausruestung", "slot": slot, "rarity": rarity}


## Zeilen, in denen sich zwei gleich große Bilder unterscheiden.
func _diff_rows(a: Image, b: Image) -> Array:
	var rows: Array = []
	for y in a.get_height():
		for x in a.get_width():
			if a.get_pixel(x, y) != b.get_pixel(x, y):
				rows.append(y)
				break
	return rows


func test_ausruestung_an_der_figur(t) -> void:
	for body in ["normal", "klein", "gross", "breit"]:
		for slot in Sprites.GEAR_BEHIND + Sprites.GEAR_BODY + Sprites.GEAR_TOP:
			t.ok(PixelArt.has("ausruestung/%s/%s" % [body, slot]), "%s: %s" % [body, slot])
	for slot in Sprites.GEAR_BEHIND + Sprites.GEAR_BODY + Sprites.GEAR_TOP:
		t.has(GameTabs.EQUIP_ORDER, slot, "%s ist ein Ausrüstungsplatz" % slot)
	var plain := Sprites.hero_name({})
	t.ok(PixelArt.has(plain) and PixelArt.has(plain + "_2"), "schlichte Figur mit Laufbild")
	t.eq(PixelArt.size_of(plain), Vector2i(PixelArt.TILE, PixelArt.TILE), "so groß wie eine Kachel")
	t.eq(Sprites.hero_name({"equipment": {"ring1": _gear("ring", "episch")}}), plain, "Ringe sieht man nicht")
	var base := PixelArt.image(plain)
	# Der Helm verändert nur den Kopf, die Stiefel nur die Füße
	var helm := PixelArt.image(Sprites.hero_name({"equipment": {"kopf": _gear("kopf", "selten")}}))
	var rows := _diff_rows(base, helm)
	t.ok(not rows.is_empty() and rows.max() < 16, "Helm nur am Kopf")
	var boots := PixelArt.image(Sprites.hero_name({"equipment": {"fuesse": _gear("fuesse", "selten")}}))
	rows = _diff_rows(base, boots)
	t.ok(not rows.is_empty() and rows.min() >= 24, "Stiefel nur an den Füßen")
	# Die Waffe ragt über die Hand hinaus und hat oben einen Umriss
	var eq := {"kopf": _gear("kopf", "selten"), "waffe": _gear("waffe", "episch"), "fuesse": _gear("fuesse", "gewoehnlich")}
	var n := Sprites.hero_name({"equipment": eq})
	t.ok(n != plain and PixelArt.has(n + "_2"), "zusammengesetzt, mit Laufbild")
	t.eq(Sprites.hero_name({"equipment": eq}), n, "gleiche Ausrüstung, gleicher Name")
	var armed := PixelArt.image(Sprites.hero_name({"equipment": {"waffe": _gear("waffe", "episch")}}))
	var tip := Vector2i(-1, 99)
	for y in armed.get_height():
		for x in range(armed.get_width() / 2, armed.get_width()):
			if armed.get_pixel(x, y) != base.get_pixel(x, y) and armed.get_pixel(x, y) != Sprites.OUTLINE and y < tip.y:
				tip = Vector2i(x, y)
	t.ok(tip.x >= 0, "Waffe sichtbar")
	if tip.x >= 0:
		t.eq(armed.get_pixel(tip.x, tip.y - 1), Sprites.OUTLINE, "Umriss um die Waffenspitze")
	var eq2 := eq.duplicate(true)
	eq2.kopf.rarity = "episch"
	t.ok(Sprites.hero_name({"equipment": eq2}) != n, "andere Seltenheit, andere Figur")
	t.not_null(PixelArt.texture(n), "tönbar wie jedes Bild")
	t.not_null(PixelArt.silhouette(n), "Aufblitzen möglich")
	# Laufbild: nur die Füße bewegen sich
	rows = _diff_rows(base, PixelArt.image(plain + "_2"))
	t.ok(not rows.is_empty() and rows.min() >= Sprites.WALK_ROW - 1, "Laufbild: nur die Füße gehen auseinander")
	# Der Zwergenbart liegt über der Weste
	var dwarf := PixelArt.image(Sprites.hero_name({"race": "zwerg"}))
	var vest := PixelArt.image(Sprites.hero_name({"race": "zwerg", "equipment": {"brust": _gear("brust", "episch")}}))
	var beard_same := true
	for y in range(18, 24):
		if vest.get_pixel(15, y) != dwarf.get_pixel(15, y):
			beard_same = false
	t.ok(beard_same, "Bart über der Weste")
	t.ok(not _diff_rows(dwarf, vest).is_empty(), "Weste neben dem Bart")


func test_truhe_beim_oeffnen(t) -> void:
	t.eq(PixelArt.size_of("ding/truhe_offen"), PixelArt.size_of("ding/truhe"), "offene Truhe gleich groß")
	var shut := PixelArt.image("ding/truhe")
	var open := PixelArt.image("ding/truhe_offen")
	var same := true
	for y in range(16, 24):
		for x in PixelArt.TILE:
			var a := shut.get_pixel(x, y)
			var b := open.get_pixel(x, y)
			# Durchsichtige Pixel zählen gleich, egal welche Farbe der Import darin ablegt
			if (a.a > 0.5 or b.a > 0.5) and a != b:
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


func test_rassen_an_der_figur(t) -> void:
	var names := {}
	for r in Db.t("races", "RACES"):
		t.ok(Sprites.RACE_LOOKS.has(r.id), "%s hat Aussehen" % r.id)
		t.ok(PixelArt.has("held/" + r.id) and PixelArt.has("held/%s_kopf" % r.id), "%s hat eine Figur" % r.id)
		var n := Sprites.hero_name({"race": r.id})
		t.ok(PixelArt.has(n + "_2"), "%s mit Laufbild" % r.id)
		names[n] = true
	t.eq(names.size(), Db.t("races", "RACES").size(), "jede Rasse sieht anders aus")
	for id in Sprites.RACE_LOOKS:
		t.has(["normal", "klein", "gross", "breit"], Sprites.RACE_LOOKS[id].body, "%s: Körperbau" % id)
	var box := func(id: String) -> Rect2i:
		return PixelArt.image(Sprites.hero_name({"race": id})).get_used_rect()
	t.lt(box.call("halbling").size.y, box.call("mensch").size.y, "Halblinge sind kleiner")
	t.gt(box.call("troll").size.y, box.call("mensch").size.y, "Trolle sind größer")
	t.gt(box.call("zwerg").size.x, box.call("mensch").size.x, "Zwerge sind breiter")
	t.lt(box.call("zwerg").size.y, box.call("mensch").size.y, "und kleiner")
	t.ge(box.call("echsenmensch").end.x, PixelArt.TILE - 2, "Echsenschwanz ragt hinaus")
	t.le(box.call("kellerfee").position.x, 0, "Feenflügel ragen hinaus")
	var elf := PixelArt.image(Sprites.hero_name({"race": "elf"}))
	var skin := Color(Sprites.RACE_LOOKS.elf.skin).to_html(false)
	var found := false
	for y in elf.get_height():
		for x in elf.get_width():
			if elf.get_pixel(x, y).to_html(false) == skin:
				found = true
	t.ok(found, "Haut in der Farbe der Rasse")
	t.eq(Sprites.hero_name({"race": "gibt_es_nicht"}), Sprites.hero_name({}), "Unbekannte Rasse: Mensch")
