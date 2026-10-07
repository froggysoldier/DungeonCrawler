extends SceneTree
## Entwicklerwerkzeug: Wie gut kommt ein Crawler, so wie er auf einer Etage
## ankommt, mit deren normalen Monstern zurecht? Liest Schnappschüsse aus
## tools/balance_sim.gd (SNAPDIR=… LEAVE=0.5|0.7|0.95) und lässt jeden davon
## gegen jede Monsterart der Etage antreten – ohne Tränke, mit vollen HP, so
## dass nur Werte, Ausrüstung und Schaden zählen.
##   godot --headless --path godot -s res://tools/calib_sim.gd -- <snapdir> [duelle]
##   SCALE2=hp,dmg und SCALE3=hp,dmg probieren andere Stärkefaktoren aus,
##   BOSSSCALE2/3=hp,dmg die der Bosse; BOSSES=1 lässt auch gegen Bosse antreten
##   ONLY=E2 beschränkt auf eine Etage
## Ausgabe je Etage und Abgangszeitpunkt: Siegquote und verlorene HP pro Kampf,
## am Etagenanfang (untere Stufe + 1) und in der Mitte des Stufenbereichs.


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var dir: String = args[0]
	var runs := int(args[1]) if args.size() > 1 else 4
	# SCALE2=hp,dmg / SCALE3=hp,dmg: Stärkefaktor der Etage probeweise ersetzen
	for fl in [1, 2, 3]:
		var env := OS.get_environment("SCALE%d" % fl)
		if env != "":
			var parts := env.split(",")
			Db.floor_def0(fl).mobScale = {"hp": float(parts[0]), "dmg": float(parts[1]), "xp": 1.0}
		var benv := OS.get_environment("BOSSSCALE%d" % fl)
		if benv != "":
			var bp := benv.split(",")
			Db.floor_def0(fl).bossScale = {"hp": float(bp[0]), "dmg": float(bp[1]), "xp": 1.0}
	var snaps := {}
	for f in DirAccess.get_files_at(dir):
		if not f.begins_with("snap_") or not f.ends_with(".json"):
			continue
		var d: Dictionary = J.load_json("%s/%s" % [dir, f])
		var key := "E%d @ %s" % [int(d.floor), String(d.leave)]
		if not snaps.has(key):
			snaps[key] = []
		snaps[key].append(d)
	var keys := snaps.keys()
	keys.sort()
	print("Etage @ Abgang     n  Stufe   Anfang: Sieg  HP-Verl   Mitte: Sieg  HP-Verl")
	for key in keys:
		if OS.get_environment("ONLY") != "" and not String(key).begins_with(OS.get_environment("ONLY")):
			continue
		var list: Array = snaps[key]
		var fl := int(list[0].floor)
		var lv: Array = Db.floor_def0(fl).mobLevel
		var res_lo := _gauntlet(list, fl, int(lv[0]) + 1, runs)
		var res_mid := _gauntlet(list, fl, roundi((int(lv[0]) + int(lv[1])) / 2.0), runs)
		var lvl := 0.0
		for d in list:
			lvl += float(d.player.level)
		print("%-16s %3d  %5.1f   %10d %%  %6d %%   %10d %%  %6d %%" % [key, list.size(), lvl / list.size(), J.rnd(res_lo.win * 100), J.rnd(res_lo.lost * 100), J.rnd(res_mid.win * 100), J.rnd(res_mid.lost * 100)])
		if OS.get_environment("BOSSES") != "":
			for bd in Db.t("monsters", "HOOD_BOSSES"):
				if not bd.floors.has(fl) or (bd.rank == "boroughboss" and int(bd.floors[0]) != fl):
					continue
				var wins := 0.0
				var lost := 0.0
				for snap in list:
					for r in runs:
						var res := _duel(snap, fl, bd, 0, 7100 + r * 17, true)
						wins += 1.0 if res.win else 0.0
						lost += res.lost
				var n := float(list.size() * runs)
				print("     %s %-28s Sieg %3d %%  HP-Verl %3d %%" % ["BEZIRK" if bd.rank == "boroughboss" else "Boss  ", String(bd.name).left(28), J.rnd(wins / n * 100), J.rnd(lost / n * 100)])
	quit()


## Mittel über alle Schnappschüsse und Monsterarten (nach Häufigkeit gewichtet).
func _gauntlet(list: Array, fl: int, mlevel: int, runs: int) -> Dictionary:
	var defs: Array = Db.t("monsters", "MONSTERS").filter(func(m): return m.floors.has(fl) and m.weight > 0)
	var win := 0.0
	var lost := 0.0
	var wsum := 0.0
	for snap in list:
		for def in defs:
			var w: float = float(def.weight) * (0.5 if int(def.floors[0]) < fl else 1.0)
			for r in runs:
				var res := _duel(snap, fl, def, Monsters.clamp_level(def, mlevel), 7000 + r * 13)
				win += w * (1.0 if res.win else 0.0)
				lost += w * res.lost
				wsum += w
	return {"win": win / wsum, "lost": lost / wsum}


func _duel(snap: Dictionary, fl: int, def: Dictionary, mlvl: int, seed: int, boss: bool = false) -> Dictionary:
	var s := TH.make(seed, {"beruf": 1})
	var r := TH.ready(s, 7)
	s.floor = fl
	s.traps = []
	s.player = snap.player.duplicate(true)
	s.unlocks = snap.unlocks.duplicate()
	s.player.pet = null
	s.player.erase("mount")
	s.player.riding = false
	s.player.buffs = []
	# Ohne Tränke: nur Werte, Ausrüstung und Schaden zählen (bei Bossen zwei)
	s.player.inventory = s.player.inventory.filter(func(i): return i.kind != "verbrauch")
	s.player.hp = Player.max_hp(s)
	s.player.ausdauer = Player.max_ausdauer(s)
	s.player.pos = {"x": r.x + 1, "y": r.y + 1}
	var m: Dictionary
	if boss:
		# Bosse mit zwei Heiltränken (wie man sie sich aufhebt), Spezialangriffen ausweichen
		s.player.inventory.append(Items.create_item(s, "heiltrank", 2))
		m = Monsters.spawn_boss(s, def, {"x": r.x + 2, "y": r.y + 1}, 0, r.id, fl)
	else:
		m = Monsters.spawn_monster(s, def, mlvl, {"x": r.x + 2, "y": r.y + 1}, 0)
	m.aware = true
	s.monsters = [m]
	var hp0: int = s.player.hp
	var n := 0
	while n < 300 and s.status == "playing" and J.has_same(s.monsters, m):
		n += 1
		if boss and BossFight.on_tile(m, s.player.pos):
			var moved := false
			for d in [[-1, 0], [0, 1], [0, -1], [-1, 1], [-1, -1]]:
				var q := {"x": s.player.pos.x + d[0], "y": s.player.pos.y + d[1]}
				if Pathfinding.can_step(s.map, s.player.pos, q) and not Ai.occupied(s, q) and not BossFight.on_tile(m, q):
					moved = Game.move_step(s, q).ok
					if moved:
						break
			if moved:
				continue
		if boss and s.player.hp < Player.max_hp(s) * 0.35:
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
		for t in [{"part": "waffe", "move": "normal", "zone": "koerper"}, {"part": "tritt", "move": "normal", "zone": "koerper"}, {"part": "faust", "move": "normal", "zone": "koerper"}]:
			if Combat.technique_blocker(s, m, t) == null and Game.attack(s, m.uid, t).ok:
				done = true
				break
		if not done:
			Game.wait(s)
	var win: bool = not J.has_same(s.monsters, m) and s.status == "playing"
	if OS.get_environment("LOG") == def.id and seed == 7000:
		print("--- %s Lv %d gegen Crawler Lv %d (HP %d)" % [def.id, mlvl, s.player.level, hp0])
		for l in s.log.slice(-14):
			print("   ", l.text)
	return {"win": win, "lost": clampf(float(hp0 - maxi(0, s.player.hp)) / hp0, 0, 1)}
