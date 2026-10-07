extends RefCounted
## Gebietskarte: Der Boss lässt sie fallen, sie kommt ins Inventar und deckt
## erst beim Lesen das ganze Viertel auf.

var _tree: SceneTree


func setup(_data) -> void:
	_tree = Engine.get_main_loop()


func _hood_cells(s: Dictionary, hood: int) -> Array:
	var out: Array = []
	var m: Dictionary = s.map
	for y in MapGen.MAP_H:
		for x in MapGen.MAP_W:
			if MapGen.is_walkable(m, x, y) and MapGen.hood_of(m, J.pos(x, y)) == hood:
				out.append(MapGen.idx(m, x, y))
	return out


func test_karte_ins_inventar_und_lesen(t) -> void:
	var s := TH.make(6201, {"beruf": 1})
	TH.tutorial(s)
	t.ok(Game.has_unlock(s, "inventar"), "Inventar freigeschaltet")
	var hood := 1 if s.map.hoods.size() > 1 else 0
	var karte := Items.create_area_map(s, hood)
	s.items.append({"pos": J.pcopy(s.player.pos), "item": karte})
	t.ok(Game.pickup(s, karte.uid).ok, "Karte aufgehoben")
	t.ok(not s.map.hoods[hood].mapFound, "Aufheben deckt noch nichts auf")
	t.ok(J.some(s.player.inventory, func(i): return i.uid == karte.uid), "Karte liegt im Inventar")
	t.ok(Game.use_item(s, karte.uid).ok, "Karte gelesen")
	t.ok(s.map.hoods[hood].mapFound, "Viertel gilt als aufgedeckt")
	t.ok(not J.some(s.player.inventory, func(i): return i.uid == karte.uid), "Karte ist verbraucht")
	var cells := _hood_cells(s, hood)
	t.gt(cells.size(), 0, "Viertel hat begehbare Felder")
	t.ok(cells.all(func(i): return s.map.explored[i]), "Ganzes Viertel erkundet")


func test_ohne_rucksack_sofort(t) -> void:
	var s := TH.make(6202, {"beruf": 1})
	s.unlocks.erase("inventar")
	var karte := Items.create_area_map(s, 0)
	s.items.append({"pos": J.pcopy(s.player.pos), "item": karte})
	Game.pickup(s, karte.uid)
	t.ok(s.map.hoods[0].mapFound, "Ohne Inventar wird die Karte gleich eingetragen")


func test_boxen_nacheinander_oeffnen(t) -> void:
	var s := TH.make(6203, {"beruf": 1})
	TH.tutorial(s)
	s.player.boxes = []
	for i in 3:
		s.player.boxes.append(Items.create_box(s, "waffen", "bronze"))
	var uids: Array = s.player.boxes.map(func(b): return b.uid)
	var meta := Meta.empty_meta()
	meta["guide"] = {"step": 99, "fight": true}
	var modals := Modals.new()
	_tree.root.add_child(modals)
	var gv := GameView.new(s, meta)
	_tree.root.add_child(gv)
	modals.close_all()
	s.pendingDialogs.clear()
	await _tree.process_frame
	t.ok(Combat.can_open_boxes(s, s.player.pos), "In der Gilde darf man öffnen")
	GameDialogs.open_boxes(gv, uids.slice(0, 2))
	await _tree.process_frame
	t.eq(s.player.boxes.size(), 2, "Erst eine Box geöffnet")
	var ev := InputEventKey.new()
	ev.keycode = KEY_ENTER
	ev.pressed = true
	modals._job.on_key.call(ev)
	t.eq(s.player.boxes.size(), 1, "„Nächste“ öffnet die zweite")
	modals._job.on_key.call(ev)
	await _tree.process_frame
	t.eq(s.player.boxes.size(), 1, "Die dritte bleibt zu")
	modals.close_all()
	await _tree.process_frame
	gv.free()
	modals.free()
