extends RefCounted
## Kampfansicht: Beim Kampfbeginn zoomt die Kamera heraus, bis alle sichtbaren
## Gegner im Bild sind, danach zurück; der Mauszeiger zeigt, was ein Klick tut.

var _tree: SceneTree


func setup(_data) -> void:
	_tree = Engine.get_main_loop()


func _view() -> Array:
	var s := TH.make(9100, {"beruf": 1})
	var meta := Meta.empty_meta()
	meta["guide"] = {"step": 99, "fight": true}
	var modals := Modals.new()
	_tree.root.add_child(modals)
	var gv := GameView.new(s, meta)
	_tree.root.add_child(gv)
	modals.close_all()
	await _tree.process_frame
	await _tree.process_frame
	return [gv, modals]


func _free(pair: Array) -> void:
	pair[1].close_all()
	await _tree.process_frame
	pair[0].free()
	pair[1].free()


func test_zoom_beim_kampf(t) -> void:
	var pair: Array = await _view()
	var gv: GameView = pair[0]
	var s := gv.s
	var r := TH.ready(s, 9)
	TH.teleport(s, {"x": r.x + 1, "y": r.y + 1})
	s.monsters = []
	gv.zoom_map(10, true)
	var close := gv.map.zoom_index
	gv.refresh()
	await _tree.process_frame
	var ghul := Monsters.spawn_monster(s, Db.monster("ghul"), 1, {"x": r.x + 6, "y": r.y + 1}, 0)
	ghul.aware = true
	s.monsters = [ghul]
	Game.after_move(s)
	Rounds.after_turn(s)
	t.ok(Rounds.active(s), "Kampf")
	gv.refresh()
	await _tree.process_frame
	var cols := gv.map.size.x / gv.map.tile_px
	t.lt(gv.map.zoom_index, close, "herausgezoomt")
	t.ok(absf(ghul.pos.x - s.player.pos.x) <= cols / 2.0, "Gegner im Bild")
	# Zeiger: Schwert über dem Gegner, Hand über einem Gegenstand
	gv._on_hover(Vector2i(ghul.pos.x, ghul.pos.y))
	t.eq(gv.map.mouse_default_cursor_shape, Control.CURSOR_CROSS, "Schwert über dem Gegner")
	var spot := {"x": r.x + 2, "y": r.y + 2}
	s.items.append({"pos": spot, "item": Items.create_item(s, "stein")})
	gv._on_hover(Vector2i(spot.x, spot.y))
	t.eq(gv.map.mouse_default_cursor_shape, Control.CURSOR_POINTING_HAND, "Hand über einem Gegenstand")
	gv._on_hover(Vector2i(r.x + 3, r.y + 3))
	t.eq(gv.map.mouse_default_cursor_shape, Control.CURSOR_ARROW, "sonst der Pfeil")
	# Kampf vorbei: wieder so nah wie vorher
	s.monsters = []
	gv.act(func(): return Game.wait(s))
	pair[1].close_all()
	await _tree.process_frame
	t.ok(not Rounds.active(s), "Kampf vorbei")
	t.eq(gv.map.zoom_index, close, "wieder hineingezoomt")
	await _free(pair)
