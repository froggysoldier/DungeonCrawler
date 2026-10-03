extends SceneTree
## Vorschau der Tiny-Swords-Figuren (tools/ts_figures.gd) in Beispielfarben.
##   godot --headless --path godot -s res://tools/shot_ts.gd -- bild.png [name,name,...]

const F := preload("res://tools/ts_figures.gd")
const R := preload("res://tools/ts_render.gd")
const TINTS := ["#8a9a5a", "#b08a6a", "#4ad8b0", "#9a6ad0", "#c8a0a0", "#6aa04a", "#7a6a8a", "#c8503a"]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://ts.png"
	var names: Array = []
	if args.size() > 1:
		names = Array(args[1].split(","))
	else:
		for n in F.CREATURES:
			names.append(n)
		for n in F.BOSSES:
			names.append(n)
	var cell := 200
	var cols := 8
	var rows := ceili(names.size() / float(cols))
	var sheet := Image.create(cols * cell, rows * cell, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("#47776b"))
	for i in names.size():
		var n: String = names[i]
		var frames: int = F.CREATURES.get(n, F.BOSSES.get(n, 1))
		var img := R.render(F.shapes(n, 0))
		_tint(img, Color(TINTS[i % TINTS.size()]))
		# Schatten wie im Spiel
		var ox := (i % cols) * cell + 4
		var oy := (i / cols) * cell + 4
		for y in 10:
			for x in 70:
				var dx := (x - 35) / 35.0
				var dy := (y - 5) / 5.0
				if dx * dx + dy * dy <= 1.0:
					sheet.set_pixel(ox + 13 + x + 0, oy + 2 * 84 + y, Color("#2f4f47"))
		var big := img.duplicate()
		big.resize(192, 192, Image.INTERPOLATE_NEAREST)
		sheet.blend_rect(big, Rect2i(0, 0, 192, 192), Vector2i(ox, oy))
		if frames > 1:
			var img2 := R.render(F.shapes(n, 1))
			_tint(img2, Color(TINTS[i % TINTS.size()]))
			sheet.blend_rect(img2, Rect2i(0, 0, 96, 96), Vector2i(ox + 120, oy))
	sheet.save_png(out)
	print("gespeichert: ", out)
	quit()


func _tint(img: Image, c: Color) -> void:
	var ramp := PixelArt.ramp(c)
	var keys: Array = PixelArt.TINT_KEYS.map(func(k): return Color(k))
	for y in img.get_height():
		for x in img.get_width():
			var p := img.get_pixel(x, y)
			for k in keys.size():
				if p.a > 0.5 and p.is_equal_approx(keys[k]):
					img.set_pixel(x, y, ramp[k])
