extends SceneTree
## Entwicklerwerkzeug: rendert nur die Karte eines neuen Spiels und speichert
## ein Bildschirmfoto.  xvfb-run godot --path godot -s res://tools/shot_map.gd -- ziel.png [seed] [zoom] [etage] [alles]
## etage: Spiel auf dieser Etage beginnen; alles: ganze Karte aufgedeckt.

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://map.png"
	var seed := int(args[1]) if args.size() > 1 else 1
	var s := Game.new_game({"name": "Test", "answers": {}, "seed": seed, "meta": Meta.empty_meta()})
	if args.size() > 3 and int(args[3]) > 1:
		Game._enter_floor(s, int(args[3]), Meta.empty_meta())
	if args.size() > 4:
		for i in s.map.explored.size():
			s.map.explored[i] = true
	var root_ctl := Control.new()
	root_ctl.size = Vector2(1600, 900)
	get_root().add_child(root_ctl)
	var tiles := Tiles.new()
	root_ctl.add_child(tiles)
	var mv := MapView.new()
	mv.s = s
	mv.anim = Animator.new()
	mv.size = Vector2(1600, 900)
	root_ctl.add_child(mv)
	if args.size() > 2:
		mv.zoom(int(args[2]) - mv.zoom_index)
	await tiles.build()
	mv.tiles = tiles
	mv.hover = Vector2i(s.player.pos.x + 2, s.player.pos.y)
	for i in 6:
		mv.redraw()
		if args.size() > 4:
			# Alles sichtbar, ohne Nebel und Dunkelheit (zum Begutachten der Grafik)
			for k in s.map.tiles.size():
				mv.visible_set[k] = true
			mv._static_key = ""
			mv._dark.visible = false
			mv._fog.visible = false
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(out)
	print("gespeichert: ", out)
	quit()
