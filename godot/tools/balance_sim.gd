extends SceneTree
## Entwicklerwerkzeug: Ein einfacher Bot spielt 30 Partien bis Etage 3 und
## gibt eine Tabelle aus.
##   godot --headless --path godot -s res://tools/balance_sim.gd [-- anzahl]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var count := int(args[0]) if args.size() > 0 else 30
	var results: Array = []
	print("seed  status        lvl  kills  zug    klasse          follower  ach  bosse  ursache")
	for seed in range(1, count + 1):
		var s := _run_bot(seed)
		var r := {
			"seed": seed,
			"status": "SIEG" if s.status == "victory" else "E%d %s" % [s.floor, s.status],
			"floor": s.floor,
			"level": s.player.level,
			"kills": s.counters.kills,
			"turn": s.turn,
			"klasse": s.player.get("klass") if s.player.get("klass") != null else "-",
			"follower": s.viewers.follower,
			"ach": s.achievements.size(),
			"bosses": s.counters.bossKills,
			"cause": s.get("deathCause") if s.get("deathCause") != null else "",
		}
		results.append(r)
		print("%-5d %-13s %-4d %-6d %-6d %-15s %-9d %-4d %-6d %s" % [
			r.seed, r.status, r.level, r.kills, r.turn, r.klasse, r.follower, r.ach, r.bosses, r.cause])
	for f in [2, 3]:
		var n := results.filter(func(r): return r.status == "SIEG" or r.floor >= f).size()
		print("Etage %d erreicht: %d/%d" % [f, n, count])
	print("Etage 3 überlebt: %d/%d" % [results.filter(func(r): return r.status == "SIEG").size(), count])
	quit()


func _center(r: Dictionary) -> Dictionary:
	return {"x": r.x + floori(r.w / 2.0), "y": r.y + floori(r.h / 2.0)}


func _go_to(s: Dictionary, target: Dictionary) -> bool:
	var lairs := {}
	for m in s.monsters:
		if m.get("homeRoom") != null:
			lairs[int(m.homeRoom)] = true
	var w: int = s.map.width
	var target_room: int = s.map.roomAt[target.y * w + target.x]
	var passable := func(x: int, y: int) -> bool:
		var r: int = s.map.roomAt[y * w + x]
		if r >= 0 and lairs.has(r) and r != target_room:
			return false
		# Möbel und verschlossene Türen umgehen (hineinlaufen kostet keinen Zug)
		if not (x == target.x and y == target.y) and (MapGen.furniture_at(s.map, J.pos(x, y)) != null or Dungeon.lock_at(s, J.pos(x, y)) != null):
			return false
		return not J.some(s.monsters, func(m): return m.pos.x == x and m.pos.y == y)
	var path = Pathfinding.find_path(s.map, s.player.pos, target, passable, 8000, true)
	if path == null or path.is_empty():
		return false
	return Game.move_step(s, path[0]).ok


func _fight(s: Dictionary) -> bool:
	var near: Array = s.monsters.filter(func(m): return J.cheb(m.pos, s.player.pos) <= 1)
	if near.is_empty():
		return false
	J.sort(near, func(a, b): return a.hp - b.hp)
	var adj: Dictionary = near[0]
	for t in [{"part": "tritt", "move": "stampfen"}, {"part": "tritt", "move": "normal"}, {"part": "faust", "move": "normal"}]:
		# Scheitert der Angriff (etwa ohne Ausdauer), lieber warten als stehen bleiben
		if Combat.technique_blocker(s, adj, t) == null and Game.attack(s, adj.uid, t).ok:
			return true
	Game.wait(s)
	return true


func _nearest_room(s: Dictionary, kind: String) -> Variant:
	var rooms: Array = s.map.rooms.filter(func(r): return r.kind == kind)
	J.sort(rooms, func(a, b): return J.cheb(_center(a), s.player.pos) - J.cheb(_center(b), s.player.pos))
	return rooms[0] if not rooms.is_empty() else null


func _run_bot(seed: int, max_floor: int = 3) -> Dictionary:
	var s := Game.new_game({"name": "Bot", "answers": [seed % 9, seed % 4, 3, seed % 5, seed % 4], "seed": seed, "meta": Meta.empty_meta()})
	s.pendingDialogs = []
	var phase := "guild"
	var guard := 0
	var floor_no := 1
	while s.status == "playing" and guard < 18000:
		guard += 1
		var p: Dictionary = s.player
		if s.floor > max_floor:
			break
		if s.floor != floor_no:
			floor_no = s.floor
			phase = "clear"
			s.pendingDialogs = []
		if s.pendingSelection:
			Classes.choose(s, "mensch", Classes.class_options(s)[0].klass.id)
			continue
		if p.get("klass") != null and not p.get("abilityCooldown") and J.some(s.monsters, func(m): return J.cheb(m.pos, p.pos) <= 1):
			if Classes.use_ability(s, {"part": "tritt", "move": "normal"}).ok:
				continue
		# Heilen
		if p.hp < Player.max_hp(s) * 0.45:
			var pot = J.find(p.inventory, func(i):
				var e = i.get("effekt")
				return i.kind == "verbrauch" and e != null and (e.get("heal") or e.get("healPct")))
			if pot != null and Game.use_item(s, pot.uid).ok:
				continue
			var safe = _nearest_room(s, "safe")
			if safe != null and not Combat.is_in_safe_room(s, p.pos):
				if _fight(s):
					continue
				if not _go_to(s, _center(safe)):
					Game.wait(s)
				continue
			if safe != null:
				for b in p.boxes.duplicate():
					Game.open_box(s, b.uid)
				for it in p.inventory.duplicate():
					if it.kind == "ausruestung":
						Game.equip(s, it.uid)
				if not Game.sleep(s).ok:
					Game.wait(s)
				continue
		if _fight(s):
			continue
		if J.some(s.items, func(e): return e.pos.x == p.pos.x and e.pos.y == p.pos.y and e.item.kind != "wurf"):
			Game.pickup(s)
			# Neue Ausrüstung sofort anlegen, wenn der Platz frei ist
			for it in p.inventory.duplicate():
				if it.kind == "ausruestung" and p.equipment.get(it.get("slot", "")) == null:
					Game.equip(s, it.uid)
		if phase == "guild":
			if s.unlocks.has("inventar"):
				phase = "clear"
				continue
			var g = _nearest_room(s, "guild")
			if not _go_to(s, _center(g)):
				Game.wait(s)
			continue
		if phase == "clear":
			# Normale Mobs in der Nähe jagen, bis Level 4, dann Bosse
			var targets: Array = s.monsters.filter(func(m):
				var rank_ok: bool = (m.rank == "normal" or m.rank == "elite") if p.level < 5 else m.rank == "nachbarschaftsboss"
				return rank_ok and m.level <= p.level + (1 if m.rank != "nachbarschaftsboss" else 4))
			J.sort(targets, func(a, b): return J.cheb(a.pos, p.pos) - J.cheb(b.pos, p.pos))
			if targets.is_empty() or s.turn - s.floorStartTurn > 1700:
				phase = "stairs"
				continue
			if not _go_to(s, targets[0].pos):
				Game.wait(s)
			continue
		# Treppe: die nächste bevorzugen
		var stairs: Array = []
		var w: int = s.map.width
		for i in s.map.tiles.size():
			if s.map.tiles[i] == "stairs":
				stairs.append({"x": i % w, "y": floori(i / float(w))})
		J.sort(stairs, func(a, b): return J.cheb(a, p.pos) - J.cheb(b, p.pos))
		if J.some(stairs, func(q): return q.x == p.pos.x and q.y == p.pos.y):
			Game.descend(s, {"ghosts": []})
			continue
		if stairs.is_empty() or not _go_to(s, stairs[0]):
			Game.wait(s)
	return s
