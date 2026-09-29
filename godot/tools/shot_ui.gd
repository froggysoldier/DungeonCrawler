extends SceneTree
## Entwicklerwerkzeug: startet das Spiel, spielt kurz und speichert Bildschirmfotos.
##   xvfb-run godot --path godot -s res://tools/shot_ui.gd -- ordner modus [seed]
## Modi: title, interview, game, dialog, walk, tabs, combat, ausruestung, truhe, select, versus,
## talkshow, safe, floor3, fx (Angriff mit Ausfallschritt, Aufblitzen, Zerfall),
## fackeln (Raum mit Wandfackeln)

var out := ""
var main: Control


func shot(name: String) -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var p := "%s/%s.png" % [out, name]
	get_root().get_texture().get_image().save_png(p)
	print("Bild: ", p)


func wait(sec: float) -> void:
	await create_timer(sec).timeout


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0]
	var mode := args[1] if args.size() > 1 else "title"
	var seed := int(args[2]) if args.size() > 2 else 1
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	await wait(0.6)
	match mode:
		"title":
			await shot("title")
		"interview":
			main.show_interview()
			await wait(3.0)
			await shot("interview")
		"select", "versus", "talkshow", "safe", "floor3":
			# Aufgezeichnete Partie nachspielen, bis das Ereignis eintritt
			var replays: Array = J.load_json("res://tests/fixtures/replays.json")
			var r: Dictionary = replays.filter(func(x): return x.seed == (seed if seed != 1 or mode != "floor3" else 5))[0]
			var opts: Dictionary = r.opts.duplicate()
			opts.meta = Meta.empty_meta()
			var s := Game.new_game(opts)
			for a in r.actions:
				Parity.run_action(s, a.a, a.args)
				var hit := false
				match mode:
					"select": hit = s.get("pendingSelection", false)
					"versus": hit = s.get("pendingVersus") != null
					"talkshow": hit = J.some(s.pendingDialogs, func(d): return d.get("kind") == "talkshow")
					"safe":
						var room = Game.current_room(s)
						hit = room != null and room.kind == "safe" and not s.player.boxes.is_empty()
					"floor3": hit = s.floor == 3 and J.some(s.monsters, func(m): return Fov.chebyshev(m.pos, s.player.pos) <= 4)
				if hit:
					break
				if mode != "talkshow":
					s.pendingDialogs.clear()
			if mode != "talkshow":
				s.pendingDialogs.clear()
			else:
				s.pendingDialogs = s.pendingDialogs.filter(func(d): return d.get("kind") == "talkshow")
			main.start_game(s)
			await wait(2.5)
			if OS.get_environment("PERF") != "":
				var gv: GameView = main.view
				# Alles aufdecken und ganz herauszoomen: schlimmster Fall
				for i in s.map.explored.size():
					s.map.explored[i] = true
				gv.zoom_map(-10)
				var total := 0.0
				for i in 60:
					await process_frame
					total += gv.map.last_draw_ms
				print("Karte zeichnen: %.2f ms pro Bild (Mittel über 60 Bilder)" % (total / 60))
			await shot(mode)
			if mode == "versus":
				# Danach die Boss-Kammer ohne Dialog, näher herangezoomt
				Modals.instance.close_all()
				main.view.zoom_map(10)
				await wait(0.8)
				await shot("versus_karte")
		_:
			var s := Game.new_game({"name": "Mira", "answers": {}, "seed": seed, "meta": Meta.empty_meta()})
			if mode != "dialog":
				s.pendingDialogs.clear()
			main.start_game(s)
			await wait(1.2)
			if mode == "dialog":
				await wait(2.0)
				await shot("dialog")
			var gv: GameView = main.view
			if mode == "fackeln":
				# In den ersten normalen Raum mit Fackel stellen
				for r in s.map.rooms:
					if r.kind != "normal":
						continue
					var found := false
					for x in range(r.x, r.x + r.w):
						if gv.map._torch_at(x, r.y - 1):
							found = true
					if found:
						TH.teleport(s, {"x": r.x + r.w / 2, "y": r.y + r.h / 2})
						s.monsters = s.monsters.filter(func(mo): return Fov.chebyshev(mo.pos, s.player.pos) > 8)
						break
				gv.refresh_side()
				await wait(1.0)
				await shot("fackeln")
				quit()
				return
			if mode == "fx":
				# Ein Gegner direkt daneben, der beim ersten Schlag fällt
				gv.zoom_map(10)
				s.monsters = []
				var spot = TH.free_neighbor(s, s.player.pos)
				# Mit BOSS=id steht stattdessen dieser Boss daneben (und hält den Schlag aus)
				var boss_id := OS.get_environment("BOSS")
				var m: Dictionary
				if boss_id != "":
					var def = J.find(Db.t("monsters", "HOOD_BOSSES"), func(b): return b.id == boss_id)
					m = Monsters.spawn_boss(s, def, spot, 0, -1, s.floor)
				else:
					m = Monsters.spawn_monster(s, TH.monster_def("kellerratte"), 1, spot, 0)
					m.hp = 1
				m.ausweichen = -200
				m.aware = true
				s.monsters.append(m)
				await wait(0.4)
				gv.act(func(): return Game.attack(s, m.uid, {"part": "faust", "move": "normal"}))
				for i in 6:
					await shot("fx_%d" % i)
					await wait(0.05)
				quit()
				return
			if mode == "truhe":
				# Eine Box der Stufe TIER (Standard gold) öffnen, Bilder während der Szene
				var tier := OS.get_environment("TIER") if OS.get_environment("TIER") != "" else "gold"
				var items: Array = []
				for r in ["selten", "episch"]:
					items.append(Items.generate_equipment(s, r))
				GameDialogs.reveal_items(gv, "Goldene Abenteurer-Box", items, tier)
				var last := 0.0
				for at in [0.3, 0.55, 0.95, 1.4]:
					await wait(at - last)
					last = at
					await shot("truhe_%d" % int(at * 100))
				quit()
				return
			if mode == "ausruestung":
				# Freigeschaltet, mit angelegter Ausrüstung, Rucksack und Haustier (RACE=id wählt die Rasse)
				s.unlocks.append_array(["inventar", "stats", "minimap", "skills"])
				if OS.get_environment("RACE") != "":
					s.player.race = OS.get_environment("RACE")
				var rar: Array = Db.t("items", "RARITY_ORDER")
				for slot in ["kopf", "brust", "haende", "beine", "fuesse", "waffe", "hals", "ring"]:
					var it := Items.generate_equipment(s, rar[(slot.length() + 1) % 5], [slot])
					s.player.equipment[slot if slot != "ring" else "ring1"] = it
				for i in 3:
					s.player.inventory.append(Items.generate_equipment(s, rar[i + 1]))
				s.player.inventory.append(Items.create_item(s, "stein", 3))
				s.player.pet = Extras.make_pet_of("Katze", "Minka")
				s.player.pet.pos = TH.free_neighbor(s, s.player.pos)
				var here := Items.generate_equipment(s, "episch", ["waffe"])
				s.items.append({"pos": J.pcopy(s.player.pos), "item": here})
				s.monsters = []
				gv.zoom_map(10)
				gv.refresh_here()
				for t in ["inventar", "crawler"]:
					gv.tab = t
					gv.refresh_side()
					await wait(0.4)
					await shot("ausruestung_" + t)
					if t == "inventar":
						gv._tab_scroll.scroll_vertical = 100000
						await wait(0.3)
						await shot("ausruestung_rucksack")
				gv.hover = J.pcopy(s.player.pos)
				gv._update_tooltip()
				await wait(0.3)
				await shot("ausruestung_tooltip")
				quit()
				return
			if mode == "walk" or mode == "tabs" or mode == "combat":
				# Ein paar Schritte in Richtung eines Gegners oder zufällig
				for i in 40:
					if gv.in_combat():
						break
					var dirs := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
					gv.step_dir(dirs[(i / 5) % 4])
					await wait(0.05)
				await wait(1.0)
			if mode == "tabs":
				for t in ["crawler", "inventar", "handwerk", "skills", "erfolge"]:
					gv.tab = t
					gv.refresh_side()
					await wait(0.3)
					await shot("tab_" + t)
			else:
				await shot(mode)
	quit()
