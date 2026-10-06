extends RefCounted
## Die Oberfläche einmal eine ganze Partie lang benutzen: dieselben Aktionen
## wie in der aufgezeichneten Partie (Replay), aber über die Spielansicht
## (mit Seitenleiste, Aktionsleiste, Tooltips und Dialogen). Die Oberfläche
## darf den Spielverlauf nicht verändern: Zufall, Zug, HP und Position müssen
## am Ende mit der Aufzeichnung übereinstimmen.

var _tree: SceneTree


func setup(_data) -> void:
	_tree = Engine.get_main_loop()


func test_ui_plays_replay(t) -> void:
	var replays: Array = J.load_json("res://tests/fixtures/replays.json")
	# Schnell: nur die kurze Partie. UI_SMOKE_ALL=1 spielt alle (bis Etage 3).
	var list := replays if OS.get_environment("UI_SMOKE_ALL") != "" else replays.filter(func(x): return x.seed == 8)
	for r in list:
		await _play(t, r)


func _play(t, r: Dictionary) -> void:
	var opts: Dictionary = r.opts.duplicate()
	opts.meta = Meta.empty_meta()
	var s := Game.new_game(opts)
	var modals := Modals.new()
	_tree.root.add_child(modals)
	var gv := GameView.new(s, Meta.empty_meta())
	_tree.root.add_child(gv)
	gv.wait_for_enemies = false
	gv.flush_dialogs()
	var tabs := GameView.TABS.map(func(x): return x[0])
	for i in r.actions.size():
		var a: Dictionary = r.actions[i]
		modals.close_all()
		var name: String = a.a
		var args: Array = a.args
		gv.act(func(): return Parity.run_action(s, name, args))
		# Zwischen den Aktionen ein Bild laufen lassen, wie im echten Spiel
		if i % 10 == 0:
			await _tree.process_frame
		if i % 7 == 0:
			gv.tab = tabs[(i / 7) % tabs.size()]
			gv.achv_view = "statistik" if (i / 35) % 2 == 1 else "erfolge"
			gv.refresh_side()
		if i % 11 == 0:
			for dy in range(-3, 4):
				for dx in range(-3, 4):
					GameDialogs.tooltip_for(gv, Vector2i(s.player.pos.x + dx, s.player.pos.y + dy), true)
	modals.close_all()
	var dg := Parity.digest(s)
	var want: Array = r.digests[r.digests.size() - 1]
	for k in [0, 1, 2, 3, 4, 5, 7]:
		t.eq(dg[k], want[k], "Seed %d: Kurzzustand nach der Partie (Feld %d)" % [r.seed, k])
	gv.free()
	modals.free()
