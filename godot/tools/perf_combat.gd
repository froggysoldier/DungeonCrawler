extends SceneTree
## Entwicklerwerkzeug: misst einen Kampf mit vielen Gegnern (Spiellogik einer
## Runde, Schritte, Neuaufbau der Oberfläche, Bildzeit).
##   xvfb-run godot --path godot -s res://tools/perf_combat.gd   (N=Anzahl Gegner)
var main: Control

func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	await create_timer(0.5).timeout
	var s := Game.new_game({"name": "P", "answers": {}, "seed": 3, "meta": Meta.empty_meta()})
	s.pendingDialogs.clear()
	TH.tutorial(s)
	s.pendingDialogs.clear()
	var r := TH.ready(s, 9)
	TH.teleport(s, {"x": r.x + 1, "y": r.y + 1})
	s.monsters = []
	var n := 0
	for dy in range(0, r.h):
		for dx in range(3, r.w):
			if n >= int(OS.get_environment("N") if OS.get_environment("N") != "" else "14"):
				break
			var p := {"x": r.x + dx, "y": r.y + dy}
			if MapGen.is_walkable(s.map, p.x, p.y) and (dx + dy) % 2 == 0:
				var m := Monsters.spawn_monster(s, Db.monster("kellerratte"), 1, p, 0)
				m.aware = true
				s.monsters.append(m)
				n += 1
	Game.after_move(s)
	Rounds.after_turn(s)
	main.start_game(s)
	await create_timer(1.0).timeout
	Modals.instance.close_all()
	var gv: GameView = main.view
	gv.meta["guide"] = {"step": 99, "fight": true}
	print("Gegner: %d, Kampf: %s" % [s.monsters.size(), gv.in_combat()])
	var t0 := Time.get_ticks_usec()
	gv.refresh()
	print("refresh: %.1f ms" % ((Time.get_ticks_usec() - t0) / 1000.0))
	for fn in ["refresh_top", "refresh_vitals", "refresh_here", "refresh_side", "refresh_log", "_draw_frame", "_update_combat_mode"]:
		var a0 := Time.get_ticks_usec()
		for k in 5:
			gv.call(fn)
		print("  %s: %.2f ms" % [fn, (Time.get_ticks_usec() - a0) / 5000.0])
	var a1 := Time.get_ticks_usec()
	Meta.save_run(s)
	print("  save_run: %.2f ms" % ((Time.get_ticks_usec() - a1) / 1000.0))
	a1 = Time.get_ticks_usec()
	Meta.sync_meta(gv.meta, s)
	Meta.save_meta(gv.meta)
	print("  sync+save_meta: %.2f ms" % ((Time.get_ticks_usec() - a1) / 1000.0))
	a1 = Time.get_ticks_usec()
	var snap := gv.anim.snapshot(s)
	gv.anim.after(s, snap, [])
	print("  anim: %.2f ms" % ((Time.get_ticks_usec() - a1) / 1000.0))
	gv._bar_state = ""
	gv.bar_static_key = ""
	t0 = Time.get_ticks_usec()
	gv.refresh_actions()
	print("refresh_actions (neu gebaut): %.1f ms" % ((Time.get_ticks_usec() - t0) / 1000.0))
	gv._bar_state = ""
	t0 = Time.get_ticks_usec()
	gv.refresh_actions()
	print("refresh_actions (nur nachgezogen): %.1f ms" % ((Time.get_ticks_usec() - t0) / 1000.0))
	var to: Dictionary = TH.free_neighbor(s, s.player.pos)
	t0 = Time.get_ticks_usec()
	gv.act(func(): return Game.move_step(s, to))
	print("Schritt im Kampf: %.1f ms" % ((Time.get_ticks_usec() - t0) / 1000.0))
	gv.traveling = true
	var back: Dictionary = TH.free_neighbor(s, s.player.pos)
	t0 = Time.get_ticks_usec()
	gv.act(func(): return Game.move_step(s, back))
	print("Schritt beim Laufen im Kampf: %.1f ms" % ((Time.get_ticks_usec() - t0) / 1000.0))
	gv.traveling = false
	t0 = Time.get_ticks_usec()
	gv.act(func(): return Game.wait(s))
	print("Runde beenden: %.1f ms" % ((Time.get_ticks_usec() - t0) / 1000.0))
	Modals.instance.close_all()
	var total := 0.0
	var worst := 0.0
	var frames := 0
	var tf := Time.get_ticks_usec()
	for i in 60:
		var a := Time.get_ticks_usec()
		await process_frame
		var d := (Time.get_ticks_usec() - a) / 1000.0
		total += d
		worst = maxf(worst, d)
		frames += 1
	print("Bild: Mittel %.1f ms, schlimmstes %.1f ms, Karte %.1f ms" % [total / frames, worst, gv.map.last_draw_ms])
	var cpu := 0.0
	for i in 30:
		var a := Time.get_ticks_usec()
		gv._process(0.016)
		cpu = maxf(cpu, (Time.get_ticks_usec() - a) / 1000.0)
	print("CPU je Bild (Spielansicht ohne Zeichnen), schlimmstes: %.1f ms" % cpu)
	t0 = Time.get_ticks_usec()
	Game.wait(s)
	print("nur Spiellogik Runde: %.1f ms" % ((Time.get_ticks_usec() - t0) / 1000.0))
	quit()
