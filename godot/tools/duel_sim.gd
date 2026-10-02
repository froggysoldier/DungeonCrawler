extends SceneTree
## Entwicklerwerkzeug: Duelle Crawler gegen jedes Monster einer Etage.
## Der Crawler hat die Stufe, die ein gründlicher Spieler dort etwa erreicht,
## und kämpft mit Faust und Tritt; Tränke benutzt er nicht.
##   godot --headless --path godot -s res://tools/duel_sim.gd [-- etage stufe duelle]
##   Umgebung: KIT=1 Ausrüstung und Tränke, MLVL=n Monsterstufe, BOSSONLY=1, NOSPECIAL=1, LOG=1

const LEVEL_BY_FLOOR := {1: 3, 2: 6, 3: 9}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var floors := [int(args[0])] if args.size() > 0 else [1, 2, 3]
	var runs := int(args[2]) if args.size() > 2 else 30
	for fl in floors:
		var lvl := int(args[1]) if args.size() > 1 else int(LEVEL_BY_FLOOR[fl])
		print("\nEtage %d, Crawler Stufe %d" % [fl, lvl])
		print("%-26s %4s %6s %8s %6s" % ["Monster", "Lvl", "Sieg%", "HP-Verl", "Züge"])
		var defs: Array = Db.t("monsters", "MONSTERS").filter(func(m): return m.floors.has(fl) and m.weight > 0)
		if OS.get_environment("BOSSONLY") != "":
			defs = []
		for bd in Db.t("monsters", "HOOD_BOSSES"):
			if bd.floors[0] == fl:
				defs.append(bd)
		for def in defs:
			var boss: bool = def.has("rank") and (def.rank == "nachbarschaftsboss" or def.rank == "boroughboss")
			var mlvl: int = def.level if boss else Monsters.clamp_level(def, Db.floor_def(fl).mobLevel[1])
			# MLVL=n: Monster auf Stufe n (soweit die Art das erlaubt)
			if not boss and OS.get_environment("MLVL") != "":
				mlvl = Monsters.clamp_level(def, int(OS.get_environment("MLVL")))
			var wins := 0
			var lost := 0.0
			var turns := 0
			for r in runs:
				var res := _duel(fl, lvl, def, mlvl, boss, 9000 + r * 31)
				wins += 1 if res.win else 0
				lost += res.lost
				turns += res.turns
			print("%-26s %4d %5d%% %7d%% %6d%s" % [String(def.name).left(26), mlvl, J.rnd(100.0 * wins / runs), J.rnd(100.0 * lost / runs), J.rnd(float(turns) / runs), "  BOSS" if boss else ""])
	quit()


func _duel(fl: int, lvl: int, def: Dictionary, mlvl: int, boss: bool, seed: int) -> Dictionary:
	var s := TH.make(seed, {"beruf": 1})
	var r := TH.ready(s, 7)
	while s.floor < fl:
		s.floor += 1
	s.traps = []
	while s.player.level < lvl:
		Player.gain_xp(s, 50)
	if OS.get_environment("KIT") != "":
		var rar := "ungewoehnlich" if fl == 1 else "selten"
		for slot in ["waffe", "brust", "beine", "fuesse", "kopf", "haende"]:
			var it := Items.generate_equipment(s, rar, [slot])
			s.player.inventory.append(it)
			Game.equip(s, it.uid)
		s.player.inventory.append(Items.create_item(s, "heiltrank" if fl == 1 else "grosser_heiltrank", 2))
	s.player.hp = Player.max_hp(s)
	s.player.ausdauer = Player.max_ausdauer(s)
	s.player.pos = {"x": r.x + 1, "y": r.y + 1}
	var m: Dictionary
	if boss:
		m = Monsters.spawn_boss(s, def, {"x": r.x + 2, "y": r.y + 1}, 0, r.id, fl)
	else:
		m = Monsters.spawn_monster(s, def, mlvl, {"x": r.x + 2, "y": r.y + 1}, 0)
	m.aware = true
	s.monsters = [m]
	var hp0: int = s.player.hp
	var n := 0
	while n < 300 and s.status == "playing" and J.has_same(s.monsters, m):
		n += 1
		if OS.get_environment("NOSPECIAL") != "":
			m.specialCd = 999
		# Angekündigten Boss-Angriffen ausweichen, wenn möglich
		if BossFight.on_tile(m, s.player.pos):
			var moved := false
			for d in [[-1, 0], [0, 1], [0, -1], [-1, 1], [-1, -1]]:
				var q := {"x": s.player.pos.x + d[0], "y": s.player.pos.y + d[1]}
				if Pathfinding.can_step(s.map, s.player.pos, q) and not Ai.occupied(s, q) and not BossFight.on_tile(m, q):
					moved = Game.move_step(s, q).ok
					if moved:
						break
			if moved:
				continue
		if s.player.hp < Player.max_hp(s) * 0.35:
			var pot = J.find(s.player.inventory, func(i): return String(i.baseId).contains("heiltrank"))
			if pot != null and Game.use_item(s, pot.uid).ok:
				continue
		if J.cheb(m.pos, s.player.pos) > 1:
			var path = Pathfinding.find_path(s.map, s.player.pos, m.pos, func(x, y): return true, 400, false)
			if path != null and not path.is_empty() and Game.move_step(s, path[0]).ok:
				continue
			Game.wait(s)
			continue
		var done := false
		for t in [{"part": "tritt", "move": "stampfen"}, {"part": "waffe", "move": "normal", "zone": "koerper"}, {"part": "tritt", "move": "normal", "zone": "koerper"}, {"part": "faust", "move": "normal", "zone": "koerper"}]:
			if Combat.technique_blocker(s, m, t) == null and Game.attack(s, m.uid, t).ok:
				done = true
				break
		if not done:
			Game.wait(s)
	var win: bool = not J.has_same(s.monsters, m) and s.status == "playing"
	if OS.get_environment("LOG") != "" and seed == 9000:
		for l in s.log.slice(-45):
			print("   ", l.text)
	return {"win": win, "lost": clampf(float(hp0 - maxi(0, s.player.hp)) / hp0, 0, 1), "turns": n}
