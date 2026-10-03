extends SceneTree
## Vorschau der Spielfigur je Rasse (HeroLook), oben ohne, unten mit Ausrüstung.
##   godot --headless --path godot -s res://tools/shot_heroes.gd -- bild.png

func _initialize() -> void:
	var out := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://heroes.png"
	var races: Array = Sprites.RACE_LOOKS.keys()
	var gear := {}
	var colors := ["#5aa0ff", "#c08aff", "#ffb347", "#8fd16a"]
	var i := 0
	for slot in Sprites.GEAR_BEHIND + Sprites.GEAR_BODY + Sprites.GEAR_TOP:
		if slot != "gesicht":
			gear[slot] = colors[i % colors.size()]
		i += 1
	var cell := 110
	var sheet := Image.create(12 * cell, 4 * cell, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("#47776b"))
	for r in races.size():
		var look: Dictionary = Sprites.RACE_LOOKS[races[r]]
		for row in 2:
			var img := TsRender.render(HeroLook.shapes(races[r], look.body, look.skin, gear if row == 1 else {}, 0))
			var x := (r % 12) * cell + 7
			var y := ((r / 12) * 2 + row) * cell + 7
			sheet.blend_rect(img, Rect2i(0, 0, 96, 96), Vector2i(x, y))
	sheet.save_png(out)
	print("gespeichert: ", out)
	quit()
