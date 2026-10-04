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
		var n := Sprites.sprite_name(m.id)
		t.ok(n.begins_with("boss/") or m.id in Sprites.PACK_BOSSES, "%s hat eine eigene Figur oder eine aus dem Pack" % m.id)
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
	for n in ["kreatur/ratte", "boss/rattenkaiser"]:
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
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			# Durchsichtige Pixel zählen gleich, egal welche Farbe darin steht
			if (ca.a > 0.5 or cb.a > 0.5) and ca != cb:
				rows.append(y)
				break
	return rows


func test_spielfigur_aus_dem_pack(t) -> void:
	var plain := Sprites.hero_name({})
	t.eq(plain, GearLook.BASE, "ohne Ausrüstung: blauer Arbeiter")
	t.ge(PixelArt.frame_count(plain), 6, "Ruhebilder")
	t.ge(PixelArt.run_count(plain), 4, "Laufbilder")
	t.eq(PixelArt.size_of(plain), Vector2i(64, 64), "Bildfläche")
	var img := PixelArt.image(plain)
	var blue := false
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).to_html(false) == "4697ac":
				blue = true
	t.ok(blue, "Blau wie im Pack")
	t.eq(Sprites.hero_name({"equipment": {"ring1": _gear("ring", "episch")}}), plain, "Ringe sieht man nicht")
	for slot in GearLook.SLOTS:
		t.has(GameTabs.EQUIP_ORDER, slot, "%s ist ein Ausrüstungsplatz" % slot)


func test_ausruestung_auf_der_figur(t) -> void:
	var plain := PixelArt.image(GearLook.BASE)
	var helm := Sprites.hero_name({"equipment": {"kopf": _gear("kopf", "selten")}})
	t.ok(helm != GearLook.BASE, "mit Helm eigene Figur")
	t.eq(PixelArt.frame_count(helm), PixelArt.frame_count(GearLook.BASE), "alle Ruhebilder")
	t.eq(PixelArt.run_count(helm), PixelArt.run_count(GearLook.BASE), "alle Laufbilder")
	t.eq(PixelArt.res(helm), 2, "fein")
	var rows := _diff_rows(plain, PixelArt.image(helm))
	t.ok(not rows.is_empty() and rows.max() < 90, "Helm nur am Kopf")
	var boots := PixelArt.image(Sprites.hero_name({"equipment": {"fuesse": _gear("fuesse", "selten")}}))
	rows = _diff_rows(plain, boots)
	t.ok(not rows.is_empty() and rows.min() >= 112, "Stiefel nur an den Füßen")
	# Form nach Gegenstand, Farbe nach Seltenheit
	t.eq(GearLook.variant("kopf", "cowboyhut"), "hut", "Cowboyhut ist ein Hut")
	t.eq(GearLook.variant("waffe", "bratpfanne"), "pfanne", "Pfanne")
	t.eq(GearLook.variant("waffe", "gibt_es_nicht"), "schlaeger", "Standardform")
	var a := Sprites.hero_name({"equipment": {"kopf": _gear("kopf", "selten")}})
	var b := Sprites.hero_name({"equipment": {"kopf": _gear("kopf", "episch")}})
	t.ok(a != b, "andere Seltenheit, andere Figur")
	t.eq(Sprites.hero_name({"equipment": {"kopf": _gear("kopf", "selten")}}), a, "gleiche Ausrüstung, gleicher Name")
	# Die Ausrüstung wandert mit: im Laufbild sitzt der Helm anders als im Ruhebild
	var run := PixelArt.image(a + "_lauf2")
	t.ok(run.get_data() != PixelArt.image(GearLook.BASE + "_lauf2").get_data(), "Helm auch im Laufbild")
	for slot in GearLook.SLOTS:
		for v in GearLook.SLOTS[slot].variants:
			var sh = GearLook.shapes(slot, v)
			t.ok(sh is Array and not sh.is_empty(), "%s/%s hat Formen" % [slot, v])


func test_monster_aus_dem_pack(t) -> void:
	for id in ["kobold", "kobold_bombe", "fischmensch", "ghul", "abtruenniger_crawler", "der_hausmeister", "muellsack_mimic", "kellermeister", "wolpertinger"]:
		var n := Sprites.sprite_name(id)
		t.ok(PixelArt.has(n), "%s: %s" % [id, n])
		t.eq(PixelArt.res(n), 2, "%s fein" % id)
	for id in ["schleim", "fledermaus", "kellermeister", "schleusenwaerter", "troll_lehrling", "brueckentroll", "schwarzmarkt_oger", "ghulhund", "nachtmahr"]:
		t.ok(Sprites.sprite_name(id).begins_with("kreatur/rpg_"), "%s aus dem Tiny RPG Pack" % id)
		t.ok(PixelArt.has(Sprites.sprite_name(id)), "%s hat Bilder" % id)
	t.ge(PixelArt.frame_count("kreatur/rpg_ork"), 4, "Ork mit Ruhe-Animation")
	t.ge(PixelArt.run_count("kreatur/rpg_ork"), 4, "und Laufbildern")
	var s1 := PixelArt.texture("kreatur/rpg_schleim", "#4ad8b0").get_image()
	var s2 := PixelArt.texture("kreatur/rpg_schleim", "#2a2a30").get_image()
	t.ok(s1.get_data() != s2.get_data(), "Schleim in der Farbe der Art")
	t.ge(PixelArt.frame_count("kreatur/kobold"), 6, "Goblin mit Ruhe-Animation")
	t.ge(PixelArt.run_count("kreatur/kobold"), 6, "und Laufbildern")
	var a := PixelArt.texture("kreatur/krieger", "#c03030").get_image()
	var b := PixelArt.texture("kreatur/krieger", "#3030c0").get_image()
	t.ok(a.get_data() != b.get_data(), "Teamfarbe in der Farbe der Monsterart")
	# Abgewandelte Haut: Fischmensch blau statt grün
	t.ok(PixelArt.image("kreatur/fischmensch").get_data() != PixelArt.image("kreatur/kobold").get_data(), "eigene Hautfarbe")


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


func test_rassen_beschrieben(t) -> void:
	for r in Db.t("races", "RACES"):
		t.ok(Sprites.RACE_LOOKS.has(r.id), "%s hat Aussehen" % r.id)
	for id in Sprites.RACE_LOOKS:
		t.has(["normal", "klein", "gross", "breit"], Sprites.RACE_LOOKS[id].body, "%s: Körperbau" % id)
