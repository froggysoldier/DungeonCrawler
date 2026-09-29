extends SceneTree
## Entwicklerwerkzeug: alle Monster in ihrer echten Farbe (so, wie sie im
## Spiel getönt werden), dazu Spielfigur, Reittiere, Gegenstände und Fallen.
##   xvfb-run godot --path godot -s res://tools/shot_sprites.gd -- ziel.png [vergrößerung]


class Sheet:
	extends Control
	var scale_px := 2

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("#1a1d25"))
		var font := UiFonts.get_font(500)
		var cell := PixelArt.TILE * scale_px + 28
		var cols := int(size.x / cell)
		var entries: Array = []
		for m in Db.t("monsters", "MONSTERS"):
			entries.append([m.id, Sprites.sprite_name(m.id), m.color])
		for m in Db.t("monsters", "HOOD_BOSSES"):
			entries.append([m.id, Sprites.sprite_name(m.id), m.color])
		entries.append(["held", "kreatur/held", null])
		entries.append(["haustier", "kreatur/haustier", "#e0a0c8"])
		for n in PixelArt.names("reittier/"):
			entries.append([n.get_file(), n, null])
		for n in PixelArt.names("ding/"):
			entries.append([n.get_file(), n, "#5aa0ff"])
		for n in PixelArt.names("falle/"):
			entries.append([n.get_file(), n, "#ff5a4a"])
		for i in entries.size():
			var e: Array = entries[i]
			var at := Vector2(14 + (i % cols) * cell, 10 + (i / cols) * (cell + 8))
			PixelArt.draw(self, e[1], at, scale_px, e[2])
			draw_string(font, at + Vector2(0, PixelArt.TILE * scale_px + 14), String(e[0]).left(14), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#a7a9b4"))


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0]
	var sh := Sheet.new()
	if args.size() > 1:
		sh.scale_px = int(args[1])
	sh.size = Vector2(1600, 900)
	sh.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	get_root().add_child(sh)
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(out)
	quit()
