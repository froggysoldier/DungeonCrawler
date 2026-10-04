extends SceneTree
## Vorschau der Ausrüstung über der Spielfigur (GearLook): Formen je Platz,
## ganze Sätze in den Seltenheitsfarben und eine Bildfolge zum Animieren.
##   godot --headless --path godot -s res://tools/shot_gear.gd -- ordner

const RAR := {"gewoehnlich": "#c8c8c8", "selten": "#5aa0ff", "episch": "#c08aff", "legendaer": "#ffb347"}


func _initialize() -> void:
	var out := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://gear"
	DirAccess.make_dir_recursive_absolute(out)
	var t0 := Time.get_ticks_msec()
	# 1) Jede Form einzeln (selten = blau), Platz für Platz
	var rows: Array = []
	for slot in GearLook.SLOTS:
		var row: Array = []
		for v in GearLook.SLOTS[slot].variants:
			var g := {slot: [v, RAR.selten]}
			row.append([slot + ": " + v, GearLook.compose(g)[GearLook.BASE]])
		rows.append(row)
	_sheet(rows, out.path_join("formen.png"))
	# 2) Ganze Sätze in vier Seltenheiten
	var sets := [
		{"kopf": "helm", "brust": "jacke", "schultern": "polster", "guertel": "guertel", "haende": "handschuh", "beine": "hose", "fuesse": "stiefel", "ruecken": "umhang", "waffe": "schlaeger"},
		{"kopf": "hut", "gesicht": "brille", "brust": "weste", "hals": "schal", "fuesse": "stiefel", "ruecken": "rucksack", "waffe": "werkzeug"},
		{"kopf": "krone", "brust": "mantel", "hals": "kette", "arme": "schiene", "haende": "handschuh", "fuesse": "stiefel", "ruecken": "umhang", "waffe": "messer"},
		{"kopf": "muetze", "gesicht": "schutzbrille", "brust": "shirt", "guertel": "guertel", "beine": "hose", "fuesse": "stiefel", "waffe": "pfanne"},
	]
	var srows: Array = []
	for st in sets:
		var row: Array = []
		for r in RAR:
			var g := {}
			for slot in st:
				g[slot] = [st[slot], RAR[r]]
			row.append([r, GearLook.compose(g)[GearLook.BASE]])
		srows.append(row)
	_sheet(srows, out.path_join("saetze.png"))
	# 3) Bildfolge: Satz 1 episch, Ruhe und Laufen
	var g1 := {}
	for slot in sets[0]:
		g1[slot] = [sets[0][slot], RAR.episch]
	var frames := GearLook.compose(g1)
	var i := 0
	for fr in frames:
		var img: Image = frames[fr].duplicate()
		img.resize(256, 256, Image.INTERPOLATE_NEAREST)
		img.save_png(out.path_join("anim_%02d.png" % i))
		i += 1
	print("gespeichert in ", out, " (", Time.get_ticks_msec() - t0, " ms)")
	quit()


func _sheet(rows: Array, path: String) -> void:
	var cell := 200
	var cols := 0
	for r in rows:
		cols = maxi(cols, r.size())
	var img := Image.create(cols * cell, rows.size() * cell, false, Image.FORMAT_RGBA8)
	img.fill(Color("#47776b"))
	for y in rows.size():
		for x in rows[y].size():
			var fig: Image = rows[y][x][1].duplicate()
			var crop := fig.get_region(Rect2i(16, 28, 96, 100))
			crop.resize(192, 200, Image.INTERPOLATE_NEAREST)
			img.blend_rect(crop, Rect2i(0, 0, 192, 200), Vector2i(x * cell + 4, y * cell))
	img.save_png(path)
	# Beschriftung als Textdatei daneben
	var f := FileAccess.open(path.get_basename() + ".txt", FileAccess.WRITE)
	for r in rows:
		f.store_line(" | ".join(r.map(func(e): return e[0])))
	f.close()
