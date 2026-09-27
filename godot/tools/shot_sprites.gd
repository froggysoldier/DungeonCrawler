extends SceneTree
## Entwicklerwerkzeug: alle Kreaturen, Gegenstände und Fallen als Bogen.
##   xvfb-run godot --path godot -s res://tools/shot_sprites.gd -- ziel.png

const KINDS := ["ratte", "kakerlake", "kobold", "schleim", "hase", "geist", "alien", "sack", "wurm", "zombie", "gnom", "spinne", "fledermaus", "kroete", "irrlicht", "tentakel", "maschine", "drohne", "hund", "troll", "skelett", "mensch", "elementar", "kroko", "fisch", "hexe", "pilz", "motte", "vogel", "crawler", "haustier"]
const COLORS := ["#8a7a6a", "#6a4a2a", "#5fa04a", "#6ad04a", "#c8a878", "#b8c8ff", "#9aa0b0", "#3a3a3a", "#8a6a4a", "#7a8a5a"]


class Sheet:
	extends Control

	func _draw() -> void:
		var c := Pen.new(self)
		draw_rect(Rect2(Vector2.ZERO, size), Color("#1a1d25"))
		for i in KINDS.size():
			var x := 60.0 + (i % 10) * 110
			var y := 60.0 + (i / 10) * 120
			Sprites.draw_sprite(c, KINDS[i], COLORS[i % COLORS.size()], x, y, 90, {"time": 0.0, "crown": i == 0, "unknown": i == 1})
		Sprites.draw_hero(c, 60 + 1 * 110, 60 + 3 * 120, 90)


func _initialize() -> void:
	var out := OS.get_cmdline_user_args()[0]
	var sh := Sheet.new()
	sh.size = Vector2(1600, 900)
	sh.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	get_root().add_child(sh)
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(out)
	quit()
