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
			names.append("kreatur/" + Sprites.sprite_for(m.id))
	names.append("kreatur/" + Sprites.sprite_for("", true))
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
	for k in MapView.ITEM_SPRITES.values() + ["edelstein", "stein", "bombe"]:
		names.append("ding/" + k)
	t.eq(_missing(names), [], "Fallen, Reittiere, Möbel, Gegenstände")


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
