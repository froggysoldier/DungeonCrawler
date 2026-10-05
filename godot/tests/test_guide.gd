extends RefCounted
## Interaktives Tutorial: zeigt auf Teile der Oberfläche und geht erst weiter,
## wenn man sie ausprobiert hat; eigener Kampfteil; abbrechbar.

var _tree: SceneTree


func setup(_data) -> void:
	_tree = Engine.get_main_loop()


func _view(t) -> Array:
	var s := TH.make(25)
	s.monsters = []
	var modals := Modals.new()
	_tree.root.add_child(modals)
	var gv := GameView.new(s, Meta.empty_meta())
	_tree.root.add_child(gv)
	modals.close_all()
	await _tree.process_frame
	return [gv, modals]


func _frames(n: int) -> void:
	for i in n:
		await _tree.process_frame


func _free(pair: Array) -> void:
	pair[1].close_all()
	await _tree.process_frame
	pair[0].free()
	pair[1].free()


func test_schritte_zum_ausprobieren(t) -> void:
	var pair: Array = await _view(t)
	var gv: GameView = pair[0]
	var g: Guide = gv.guide
	await _frames(2)
	t.ok(g._box.visible, "Hinweis sichtbar")
	t.ok(g._target.has_area(), "zeigt auf die Figur")
	t.eq(int(gv.meta.guide.step), 0, "erster Schritt: laufen")
	# Zwei Felder weiter stehen
	var s := gv.s
	var p: Dictionary = s.player.pos
	var far = null
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			if far == null and maxi(absi(dx), absi(dy)) >= 2 and MapGen.is_walkable(s.map, p.x + dx, p.y + dy):
				far = J.pos(p.x + dx, p.y + dy)
	t.not_null(far, "freies Feld")
	TH.teleport(s, far)
	await _frames(2)
	t.ge(int(gv.meta.guide.step), 1, "nach dem Laufen weiter")
	# Inventar-Schritt: der Reiterknopf blinkt, Öffnen schaltet weiter
	gv.meta.guide.step = 6
	await _frames(2)
	t.ok(g._target.has_area(), "zeigt auf den Reiter")
	t.eq(g._target.position, gv.tab_buttons.inventar.get_global_rect().position, "genau der Inventar-Knopf")
	gv.open_tab("inventar")
	await _frames(2)
	t.eq(int(gv.meta.guide.step), 7, "Inventar geöffnet")
	gv.close_tab()
	await _frames(2)
	t.eq(int(gv.meta.guide.step), 8, "Fenster geschlossen")
	# Klick-Schritt: Klick auf das Ziel zählt
	gv.meta.guide.step = 3
	await _frames(2)
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.global_position = g._target.get_center()
	g._input(ev)
	await _frames(2)
	t.eq(int(gv.meta.guide.step), 4, "Klick auf die Lebenspunkte")
	g.finish()
	await _frames(2)
	t.ok(not g._box.visible, "beendet: nichts mehr zu sehen")
	t.ok(not g.active(), "beendet")
	await _free(pair)


func test_kampfteil(t) -> void:
	var pair: Array = await _view(t)
	var gv: GameView = pair[0]
	var g: Guide = gv.guide
	var s := gv.s
	gv.meta.guide = {"step": 99, "fight": false}
	var r := TH.ready(s, 9)
	TH.teleport(s, {"x": r.x, "y": r.y + 1})
	var ghul := Monsters.spawn_monster(s, Db.monster("ghul"), 1, {"x": r.x + 3, "y": r.y + 1}, 0)
	ghul.aware = true
	s.monsters = [ghul]
	Rounds.after_turn(s)
	gv.refresh()
	await _frames(2)
	t.ok(g._box.visible, "Kampfhinweis sichtbar")
	t.ok(g._count.text.begins_with("KAMPF"), "Kampfteil")
	g._advance()
	await _frames(2)
	t.ok(g._target.has_area(), "zeigt auf den Gegner")
	s.round.acted = true
	await _frames(2)
	t.eq(g._fight_i, 2, "nach dem Angriff: Runde beenden")
	gv.act(func(): return Game.wait(s))
	pair[1].close_all()
	await _frames(2)
	t.ok(gv.meta.guide.fight, "Kampfteil gelernt")
	await _free(pair)
