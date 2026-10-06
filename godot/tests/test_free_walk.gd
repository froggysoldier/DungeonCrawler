extends RefCounted
## Freies Laufen in der Spielansicht: lange Klick-Wege durch Türen,
## gehaltene Pfeiltasten (auch schräg) und Gleiten an Wänden.

var _tree: SceneTree


func setup(_data) -> void:
	_tree = Engine.get_main_loop()


func _view(seed: int) -> Array:
	var s := TH.make(seed)
	s.monsters = []
	s.crawlers = []
	for i in s.map.explored.size():
		s.map.explored[i] = true
	var meta := Meta.empty_meta()
	meta["guide"] = {"step": 99, "fight": true}
	var modals := Modals.new()
	_tree.root.add_child(modals)
	var gv := GameView.new(s, meta)
	_tree.root.add_child(gv)
	modals.close_all()
	await _tree.process_frame
	return [gv, modals]


func _free(pair: Array) -> void:
	pair[0]._stop_moving()
	pair[0].held.clear()
	pair[1].close_all()
	await _tree.process_frame
	pair[0].free()
	pair[1].free()


## Bis zu sec Sekunden laufen lassen; Dialoge werden weggeklickt.
func _run(pair: Array, sec: float, until: Callable) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < sec * 1000.0:
		await _tree.process_frame
		pair[1].close_all()
		if until.call():
			return


func test_langer_weg_durch_tueren(t) -> void:
	var pair: Array = await _view(25)
	var gv: GameView = pair[0]
	var s := gv.s
	var guild = TH.room(s, "guild")
	var goal := MapGen.center(guild)
	var path = Game.plan_path(s, goal)
	t.not_null(path, "Weg zur Gilde")
	var doors: int = (path as Array).filter(func(p): return Pathfinding.is_door(s.map, p.x, p.y)).size()
	t.ge(doors, 1, "der Weg führt durch eine Tür")
	# Ohne Fallen und Gegner: Der Weg soll nur an Gelände (Türen, Schlamm) geprüft werden
	s.traps = []
	gv.travel(path)
	await _run(pair, 20.0, func():
		s.monsters.clear()
		return not gv.traveling)
	t.eq(Vector2i(s.player.pos.x, s.player.pos.y), Vector2i(goal.x, goal.y), "angekommen (%d Felder)" % path.size())
	t.ok(not gv.traveling, "Weg beendet")
	var p: Vector2 = gv._pos_now()
	t.ok(p.distance_to(Vector2(goal.x, goal.y)) < 0.1, "steht am Ziel")
	await _free(pair)


func test_pfeiltasten_und_waende(t) -> void:
	var pair: Array = await _view(25)
	var gv: GameView = pair[0]
	var s := gv.s
	var r := TH.ready(s, 6)
	TH.teleport(s, {"x": r.x + 1, "y": r.y + 1})
	gv.anim.reset()
	var start := Vector2i(s.player.pos.x, s.player.pos.y)
	# Nach rechts bis an die Wand
	gv.held[KEY_RIGHT] = Vector2i(1, 0)
	await _run(pair, 3.0, func(): return not MapGen.is_walkable(s.map, s.player.pos.x + 1, s.player.pos.y))
	await _run(pair, 0.3, func(): return false)
	gv.held.clear()
	t.gt(s.player.pos.x, start.x + 2, "nach rechts gelaufen")
	t.ok(not MapGen.is_walkable(s.map, s.player.pos.x + 1, s.player.pos.y) or MapGen.tile_at(s.map, s.player.pos.x + 1, s.player.pos.y) == "dooropen", "an der Wand angehalten")
	t.eq(s.player.pos.y, start.y, "geradeaus")
	# Schräg nach rechts unten: an der Wand entlang gleiten, also weiter nach unten
	var y0: int = s.player.pos.y
	gv.held[KEY_RIGHT] = Vector2i(1, 0)
	gv.held[KEY_DOWN] = Vector2i(0, 1)
	await _run(pair, 0.8, func(): return false)
	gv.held.clear()
	t.gt(s.player.pos.y, y0, "an der Wand entlang weiter")
	await _free(pair)
