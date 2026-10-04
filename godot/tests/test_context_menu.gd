extends RefCounted
## Rechtsklick-Menü auf der Karte: welche Aktionen es anbietet und dass
## "Aufheben" auf einem entfernten Feld erst hinläuft und dann aufhebt.

var _tree: SceneTree


func setup(_data) -> void:
	_tree = Engine.get_main_loop()


func _labels(list: Array) -> Array:
	return list.map(func(a): return String(a[0]))


func test_menue_hebt_auf_und_laeuft_hin(t) -> void:
	var s := TH.make(25)
	TH.tutorial(s)
	s.monsters = []
	var modals := Modals.new()
	_tree.root.add_child(modals)
	var gv := GameView.new(s, Meta.empty_meta())
	_tree.root.add_child(gv)
	modals.close_all()
	var p: Dictionary = s.player.pos
	var here := Vector2i(p.x, p.y)
	var stone := Items.create_item(s, "stein")
	s.items.append({"pos": J.pcopy(p), "item": stone})
	var on_me := _labels(ContextMenu.actions(gv, here))
	t.ok(on_me.any(func(l): return l.begins_with("Aufheben")), "Aufheben auf dem eigenen Feld")
	t.has(on_me, "Einen Zug warten")
	t.has(on_me, "Untersuchen")
	s.items = []
	gv.act(func(): return Game.wait(s))
	modals.close_all()
	# Zwei Felder weiter: hinlaufen und aufheben
	var target = null
	for d in [[2, 0], [-2, 0], [0, 2], [0, -2]]:
		var mid := J.pos(p.x + d[0] / 2, p.y + d[1] / 2)
		if MapGen.is_walkable(s.map, p.x + d[0], p.y + d[1]) and MapGen.is_walkable(s.map, mid.x, mid.y) and s.map.explored[MapGen.idx(s.map, p.x + d[0], p.y + d[1])]:
			target = J.pos(p.x + d[0], p.y + d[1])
			break
	t.not_null(target, "freies Feld in der Nähe")
	if target == null:
		modals.close_all()
		gv.free()
		modals.free()
		return
	var far := Items.create_item(s, "stein")
	s.items.append({"pos": target, "item": far})
	var list := ContextMenu.actions(gv, Vector2i(target.x, target.y))
	var pick = J.find(list, func(a): return String(a[0]).begins_with("Aufheben"))
	t.not_null(pick, "Aufheben auf entferntem Feld")
	t.ok(_labels(list).has("Hierher gehen"), "Hingehen angeboten")
	if pick != null:
		pick[1].call()
		for i in 40:
			await _tree.create_timer(0.05).timeout
			modals.close_all()
			if s.player.inventory.any(func(it): return it.uid == far.uid) or (s.player.hand != null and s.player.hand.uid == far.uid):
				break
		t.eq(s.player.pos.x, target.x, "hingelaufen")
		t.ok(Game.items_at(s, target).is_empty(), "aufgehoben")
	modals.close_all()
	await _tree.process_frame
	gv.free()
	modals.free()
