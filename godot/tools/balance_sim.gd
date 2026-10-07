extends SceneTree
## Entwicklerwerkzeug: Ein einfacher Bot spielt 30 Partien bis Etage 3 und
## gibt eine Tabelle aus.
##   godot --headless --path godot -s res://tools/balance_sim.gd [-- anzahl]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var count := int(args[0]) if args.size() > 0 else 30
	var results: Array = []
	print("seed  status        lvl  kills  zug    klasse          follower  ach  bosse  ursache")
	var only := OS.get_environment("SEED")
	var from := int(OS.get_environment("FROM")) if OS.get_environment("FROM") != "" else 1
	for seed in range(from, count + 1):
		if only != "" and int(only) != seed:
			continue
		var s := _run_bot(seed)
		if only != "":
			var room = Game.current_room(s)
			print("Ende: Zug %d, Pos %s, Raum %s, HP %d/%d, Stufe %d, Freischaltungen %s, Blase %s" % [s.turn, s.player.pos, room.name if room != null else "-", s.player.hp, Player.max_hp(s), s.player.level, s.unlocks, J.num(s.player, "blase")])
			for l in s.log.slice(-40):
				print("   %d %s" % [l.turn, l.text])
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
		if OS.get_environment("ARRIVALS") != "":
			print("   Ankunft: %s" % " | ".join(J.arr(s, "_arrivals")))
		if OS.get_environment("BOXES") != "":
			_box_report(s)
		print("%-5d %-13s %-4d %-6d %-6d %-15s %-9d %-4d %-6d %s" % [
			r.seed, r.status, r.level, r.kills, r.turn, r.klasse, r.follower, r.ach, r.bosses, r.cause])
	for f in [2, 3]:
		var n := results.filter(func(r): return r.status == "SIEG" or r.floor >= f).size()
		print("Etage %d erreicht: %d/%d" % [f, n, count])
	print("Etage 3 überlebt: %d/%d" % [results.filter(func(r): return r.status == "SIEG").size(), count])
	quit()


## Neue Boxen nach Etage und Stufe zählen (BOXES=1).
func _tally_boxes(s: Dictionary) -> void:
	if s.get("_boxSeen") == null:
		s._boxSeen = {}
		s._boxTally = {}
	for b in s.player.boxes:
		if s._boxSeen.has(b.uid):
			continue
		s._boxSeen[b.uid] = true
		var k := "E%d %s%s" % [int(s.floor), b.box.tier, " (Meister)" if b.box.get("special") else ""]
		if OS.get_environment("BOXES") == "2":
			k += " " + String(b.box.type)
		s._boxTally[k] = int(s._boxTally.get(k, 0)) + 1


## BOXES=1: Woher kamen die Achievements und Boxen dieser Partie?
func _box_report(s: Dictionary) -> void:
	_tally_boxes(s)
	var tk: Array = s._boxTally.keys()
	tk.sort()
	print("   Boxen je Etage: " + ", ".join(tk.map(func(k): return "%s=%d" % [k, s._boxTally[k]])))
	var by := {}
	var fam_stage := {}
	for fam in Db.t("achievement_families", "familyTable"):
		for i in fam.stages.size():
			fam_stage["fam_%s_%s" % [fam.id, J.s(fam.stages[i])]] = i + 1
	for a in Db.t("achievements", "ACHIEVEMENTS"):
		if not s.achievements.has(a.id):
			continue
		var src := "einzeln"
		if fam_stage.has(a.id):
			src = "familie_stufe%d" % fam_stage[a.id]
		elif String(a.id).begins_with("art_"):
			src = "bestiarium"
		elif String(a.id).begins_with("mo_"):
			src = "moment"
		var k := "%s/%s" % [src, a.tier if a.get("box") != null else "ohne_box"]
		by[k] = int(by.get(k, 0)) + 1
	var keys := by.keys()
	keys.sort()
	print("   Boxen-Herkunft: " + ", ".join(keys.map(func(k): return "%s=%d" % [k, by[k]])))
	var bon := Player.total_bonuses(s)
	print("   Werte: HP %d, Rüstung %s, Ausweichen %d %%, Ausrüstung %s" % [Player.max_hp(s, bon), J.s(J.num(bon, "ruestung")), J.rnd(Player.ausweichen(s, bon)), s.player.equipment.values().filter(func(x): return x != null).map(func(x): return x.rarity)])
	print("   Wartezüge nach Stelle: %s" % J.nn(s, "_waits", {}))
	var cs := {}
	for k in s.counters:
		if typeof(s.counters[k]) in [TYPE_INT, TYPE_FLOAT] and s.counters[k] != 0:
			cs[k] = s.counters[k]
	print("   Zähler: %s" % cs)
	var freq := {}
	for l in s.log:
		var key := " ".join(String(l.text).split(" ").slice(0, 4))
		freq[key] = int(freq.get(key, 0)) + 1
	var top := freq.keys()
	top.sort_custom(func(a, b): return freq[a] > freq[b])
	print("   Häufigste Meldungen (%d Einträge): %s" % [s.log.size(), ", ".join(top.slice(0, 12).map(func(k): return "%s ×%d" % [k, freq[k]]))])
	print("   Zähler: Schritte %d, Schlafen %d, Boxen geöffnet %d, Kills %d" % [s.counters.steps, s.counters.sleeps, s.counters.boxesOpened, s.counters.kills])
	print("   Gold %d, Boxen ungeöffnet %d, Tränke im Rucksack %d" % [s.player.gold, s.player.boxes.size(), s.player.inventory.filter(func(i): return i.kind == "verbrauch").reduce(func(a, i): return a + int(J.nn(i, "menge", 1)), 0)])


## Warten mit Zählung (Fehlersuche: wo verliert der Bot seine Zeit?)
func _wait(s: Dictionary, tag: String) -> Dictionary:
	if s.get("_waits") == null:
		s._waits = {}
	s._waits[tag] = int(s._waits.get(tag, 0)) + 1
	return Game.wait(s)


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
	if path == null:
		# Versperrt ein Monster den einzigen Weg, wird es eben angegriffen
		var through := func(x: int, y: int) -> bool:
			var r: int = s.map.roomAt[y * w + x]
			if r >= 0 and lairs.has(r) and r != target_room:
				return false
			return (x == target.x and y == target.y) or (MapGen.furniture_at(s.map, J.pos(x, y)) == null and Dungeon.lock_at(s, J.pos(x, y)) == null)
		path = Pathfinding.find_path(s.map, s.player.pos, target, through, 8000, true)
	if path == null or path.is_empty():
		if OS.get_environment("SEED") != "" and s.turn % 200 == 1:
			var any = Pathfinding.find_path(s.map, s.player.pos, target, func(x, y): return true, 8000, true)
			var nb := []
			for d in [[1, 0], [-1, 0], [0, 1], [0, -1], [1, 1], [-1, -1], [1, -1], [-1, 1]]:
				var q := J.pos(s.player.pos.x + d[0], s.player.pos.y + d[1])
				nb.append("%s:%s%s" % [d, MapGen.tile_at(s.map, q.x, q.y), "M" if MapGen.furniture_at(s.map, q) != null else ""])
			print("    kein Weg zu %s (ohne Regeln: %s), Nachbarn %s" % [target, any != null, nb])
		return false
	var blocker = Ai.monster_at(s, path[0])
	if blocker != null:
		for t in [{"part": "waffe", "move": "normal"}, {"part": "tritt", "move": "normal"}, {"part": "faust", "move": "normal"}]:
			if Combat.technique_blocker(s, blocker, t) == null and Game.attack(s, blocker.uid, t).ok:
				return true
		return false
	var res := Game.move_step(s, path[0])
	if OS.get_environment("SEED") != "" and not res.ok and s.turn % 200 == 0:
		print("    Schritt nach %s scheitert: %s (Feld %s)" % [path[0], res.get("message"), MapGen.tile_at(s.map, path[0].x, path[0].y)])
	return res.ok


func _fight(s: Dictionary) -> bool:
	var near: Array = s.monsters.filter(func(m): return J.cheb(m.pos, s.player.pos) <= 1)
	if near.is_empty():
		return false
	J.sort(near, func(a, b): return a.hp - b.hp)
	var adj: Dictionary = near[0]
	if Magic.knows_spell(s, "geschoss") and adj.hp > 6 and int(J.num(s.player, "mp")) >= 4 and Game.cast(s, "geschoss", {"targetUid": adj.uid, "mana": mini(6, int(s.player.mp))}).ok:
		return true
	if use_technique(s, adj):
		return true
	for t in [{"part": "tritt", "move": "stampfen"}, {"part": "waffe", "move": "normal"}, {"part": "tritt", "move": "normal"}, {"part": "faust", "move": "normal"}]:
		# Scheitert der Angriff (etwa ohne Ausdauer), lieber warten als stehen bleiben
		if Combat.technique_blocker(s, adj, t) == null and Game.attack(s, adj.uid, t).ok:
			return true
	_wait(s, "L135")
	return true


## Gelernte Angriffstechnik einsetzen, wenn eine bereit ist (die erste in
## Datenreihenfolge, die gegen dieses Ziel geht).
static func use_technique(s: Dictionary, target: Dictionary) -> bool:
	var cur := {"part": "waffe" if Player.current_weapon(s) != null else "tritt", "zone": "koerper"}
	for d in Techniques.learned(s, "angriff"):
		if d.get("free") or Techniques.blocker(s, d, target) != null:
			continue
		if J.cheb(target.pos, s.player.pos) > 1 and not d.get("leap"):
			continue
		if Combat.technique_blocker(s, target, Techniques.attack_t(d, cur)) != null and not d.get("leap"):
			continue
		if Game.use_technique(s, d.id, target.uid, cur).ok:
			return true
	return false


func _nearest_room(s: Dictionary, kind: String) -> Variant:
	var rooms: Array = s.map.rooms.filter(func(r): return r.kind == kind)
	J.sort(rooms, func(a, b): return J.cheb(_center(a), s.player.pos) - J.cheb(_center(b), s.player.pos))
	return rooms[0] if not rooms.is_empty() else null


const RARITY_RANK := {"gewoehnlich": 0, "ungewoehnlich": 1, "selten": 2, "episch": 3, "legendaer": 4, "himmlisch": 5}


## Ist it besser als das, was im Platz steckt? (Seltenheit, dann Wert)
## Was gerade auf dem Platz liegt; bei Ringen und Fußringen der schwächere
## der beiden Plätze (ein leerer Platz zählt als nichts).
func _current_in(p: Dictionary, slot: String) -> Variant:
	if slot != "ring" and slot != "fussring":
		return p.equipment.get(slot)
	var a = p.equipment.get(slot + "1")
	var b = p.equipment.get(slot + "2")
	if a == null or b == null:
		return null
	return b if Game.item_rank(b) < Game.item_rank(a) else a


func _better(it: Dictionary, cur: Variant) -> bool:
	if cur == null:
		return true
	var a: int = RARITY_RANK.get(it.get("rarity", "gewoehnlich"), 0)
	var b: int = RARITY_RANK.get(cur.get("rarity", "gewoehnlich"), 0)
	return a > b or (a == b and float(J.nn(it, "wert", 0)) > float(J.nn(cur, "wert", 0)))


func _calm(s: Dictionary) -> bool:
	return not J.some(s.monsters, func(m): return m.aware and J.cheb(m.pos, s.player.pos) <= 6)


func _find_item(s: Dictionary, pred: Callable) -> Variant:
	return J.find(s.player.inventory, pred)


## Pflege außerhalb des Kampfes: Werte verteilen, bessere Ausrüstung anlegen,
## Zauberbücher lesen. true = es wurde etwas getan, das keinen Zug kostet.
func _maintain(s: Dictionary) -> void:
	var p: Dictionary = s.player
	while int(J.num(p, "statPoints")) > 0 and Game.has_unlock(s, "stats"):
		var key := "kon" if p.stats.kon <= p.stats.str else "str"
		if not Game.allocate_stat(s, key).ok:
			break
	for it in p.inventory.duplicate():
		if it.kind == "ausruestung" and it.get("slot") != null and _better(it, _current_in(p, it.slot)):
			Game.equip(s, it.uid)
		elif it.kind == "buch" and it.get("spell") != null and not Magic.knows_spell(s, it.spell):
			Game.use_item(s, it.uid)


## Zustände behandeln und heilen. true = ein Zug wurde verbraucht.
func _survive(s: Dictionary) -> bool:
	var p: Dictionary = s.player
	var max_hp := Player.max_hp(s)
	# Gegenmittel aus dem Rucksack (Kühlpack, Augentropfen, Baldrian)
	for id in Conditions.IDS:
		if Conditions.player_has(s, id):
			var cure = _find_item(s, func(i): return i.kind == "verbrauch" and i.get("effekt") != null and J.arr(i.effekt, "clear").has(id))
			if cure != null and Game.use_item(s, cure.uid).ok:
				return true
	# Brennen: am Boden wälzen (Warten löscht), wenn niemand daneben steht
	if Conditions.player_has(s, "brennen") and not J.some(s.monsters, func(m): return J.cheb(m.pos, p.pos) <= 1):
		return _wait(s, "L192").ok
	if Conditions.player_has(s, "blutung"):
		var band = _find_item(s, func(i): return i.kind == "verbrauch" and i.get("effekt") != null and i.effekt.get("bandage"))
		if band != null and Game.use_item(s, band.uid).ok:
			return true
		if band == null and Game.craft_item(s, "verband").ok:
			return true
	if Conditions.player_has(s, "gift"):
		var anti = _find_item(s, func(i): return i.baseId == "gegengift")
		if anti != null and Game.use_item(s, anti.uid).ok:
			return true
		if Magic.knows_spell(s, "entgiften") and Game.cast(s, "entgiften").ok:
			return true
	if p.hp < max_hp * 0.6 and Magic.knows_spell(s, "heilen") and Game.cast(s, "heilen").ok:
		return true
	if p.hp < max_hp * 0.45:
		var pot = _find_item(s, func(i):
			var e = i.get("effekt")
			return i.kind == "verbrauch" and e != null and (e.get("heal") or e.get("healPct")))
		if pot != null and Game.use_item(s, pot.uid).ok:
			return true
	return false


## Zum nächsten Safe Room und schlafen, wenn es sich lohnt. true = Zug verbraucht.
func _rest(s: Dictionary, threshold: float) -> bool:
	var p: Dictionary = s.player
	# Auch zum Safe Room, wenn sich Boxen stapeln (wie ein Mensch es täte)
	var hurt: bool = p.hp < Player.max_hp(s) * threshold
	var boxes: bool = p.boxes.size() >= 15 and Game.has_unlock(s, "inventar")
	if (not hurt and not boxes) or Game.time_left(s) < 400:
		return false
	var safe = _nearest_room(s, "safe")
	if safe == null:
		return false
	if not Combat.is_in_safe_room(s, p.pos):
		if J.cheb(_center(safe), p.pos) > (40 if hurt else 20) and p.hp >= Player.max_hp(s) * 0.45:
			return false
		return _go_to(s, _center(safe)) or _wait(s, "L230").ok
	for b in p.boxes.duplicate():
		Game.open_box(s, b.uid)
	var room = Game.current_room(s)
	if room != null and not room.get("freebieTaken", false):
		Game.take_freebie(s)
	_maintain(s)
	if not hurt:
		return false
	return Game.sleep(s).ok or _wait(s, "L239").ok


## Zur Toilette im nächsten Safe Room. true = Zug verbraucht.
func _toilet(s: Dictionary) -> bool:
	var safe = _nearest_room(s, "safe")
	if safe == null or Game.time_left(s) < 60:
		return false
	if Combat.is_in_safe_room(s, s.player.pos):
		if Game.toilet(s).ok:
			return true
		# Neben die Toilette stellen (Möbel des Raums)
		var room = Game.current_room(s)
		var wc = J.find(J.arr(room, "furniture"), func(f): return f.kind == "toilette") if room != null else null
		if wc != null:
			var spot = TH.free_neighbor(s, wc.pos)
			if spot != null and _go_to(s, spot):
				return true
		return false
	if J.some(s.monsters, func(m): return J.cheb(m.pos, s.player.pos) <= 1):
		return false
	return _go_to(s, _center(safe))


func _run_bot(seed: int, max_floor: int = 3) -> Dictionary:
	var s := Game.new_game({"name": "Bot", "answers": [seed % 9, seed % 4, 3, seed % 5, seed % 4], "seed": seed, "meta": Meta.empty_meta()})
	s.pendingDialogs = []
	var phase := "guild"
	var guard := 0
	var floor_no := 1
	while s.status == "playing" and guard < 18000:
		guard += 1
		var p: Dictionary = s.player
		if OS.get_environment("BOXES") != "":
			_tally_boxes(s)
		if OS.get_environment("SEED") != "" and s.turn % 200 == 0 and s.turn != int(J.num(s, "_dbgTurn")):
			s._dbgTurn = s.turn
			var rr = Game.current_room(s)
			var near: Array = s.monsters.filter(func(m): return m.aware and J.cheb(m.pos, p.pos) <= 7)
			print("  [Zug %d] Phase %s, Pos %s, Raum %s, HP %d/%d, Blase %d, wach in der Nähe %d %s" % [s.turn, phase, p.pos, rr.name if rr != null else "-", p.hp, Player.max_hp(s), int(J.num(p, "blase")), near.size(), near.map(func(m): return "%s@%s(%s)" % [m.defId, m.pos, m.behavior])])
		if s.floor > max_floor:
			break
		# SNAPAT=0.3,0.6,0.9 (mit SNAPDIR): Crawler mitten in der Etage
		# speichern, sobald dieser Anteil der Etagenzeit vorbei ist. So misst
		# tools/calib_sim.gd, wie früh die Bosse einer Etage schaffbar sind.
		if OS.get_environment("SNAPAT") != "" and OS.get_environment("SNAPDIR") != "" and s.unlocks.has("inventar"):
			var used_now := 1.0 - float(Game.time_left(s)) / float(Db.floor_def0(s.floor).duration)
			for at in OS.get_environment("SNAPAT").split(","):
				var key := "_snap_%d_%s" % [s.floor, at]
				if used_now >= float(at) and not s.has(key):
					s[key] = true
					var sf := FileAccess.open("%s/snap_at%s_%d_E%d.json" % [OS.get_environment("SNAPDIR"), at, s.seed, s.floor], FileAccess.WRITE)
					sf.store_string(JSON.stringify({"player": s.player, "unlocks": s.unlocks, "floor": s.floor, "leave": "at" + at, "seed": s.seed}))
					sf.close()
		if s.floor != floor_no:
			floor_no = s.floor
			phase = "clear"
			s.pendingDialogs = []
			# Ankunft auf der neuen Etage festhalten (Stufe, HP, Rüstung)
			if s.get("_arrivals") == null:
				s._arrivals = []
			var ab := Player.total_bonuses(s)
			s._arrivals.append("E%d: Lv %d, HP %d, Rüstung %s" % [s.floor, p.level, Player.max_hp(s, ab), J.s(J.num(ab, "ruestung"))])
			# SNAPDIR=pfad: Crawler bei Ankunft speichern (für tools/calib_sim.gd)
			if OS.get_environment("SNAPDIR") != "":
				var tag := OS.get_environment("LEAVE") if OS.get_environment("LEAVE") != "" else "auto"
				var f := FileAccess.open("%s/snap_%s_%d_E%d.json" % [OS.get_environment("SNAPDIR"), tag, s.seed, s.floor], FileAccess.WRITE)
				f.store_string(JSON.stringify({"player": s.player, "unlocks": s.unlocks, "floor": s.floor, "leave": tag, "seed": s.seed}))
				f.close()
		if OS.get_environment("STOPAT") != "" and s.floor >= int(OS.get_environment("STOPAT")):
			break
		if s.pendingSelection:
			Classes.choose(s, "mensch", Classes.class_options(s)[0].klass.id)
			continue
		if p.get("klass") != null and not p.get("abilityCooldown") and J.some(s.monsters, func(m): return J.cheb(m.pos, p.pos) <= 1):
			if Classes.use_ability(s, {"part": "tritt", "move": "normal"}).ok:
				continue
		if _survive(s):
			continue
		# Die Blase: rechtzeitig zur Toilette im Safe Room
		if float(J.num(p, "blase")) >= 70 and _toilet(s):
			continue
		# Fast tot: zum Safe Room, auch mitten im Kampf
		if p.hp < Player.max_hp(s) * 0.3 and _rest(s, 0.3):
			continue
		if _fight(s):
			continue
		if _calm(s):
			_maintain(s)
			if _rest(s, 0.65):
				continue
		if J.some(s.items, func(e): return e.pos.x == p.pos.x and e.pos.y == p.pos.y and e.item.kind != "wurf"):
			Game.pickup(s)
			_maintain(s)
		if phase == "guild":
			if s.unlocks.has("inventar"):
				phase = "clear"
				continue
			var g = _nearest_room(s, "guild")
			if not _go_to(s, _center(g)):
				_wait(s, "L303")
			continue
		# Wer uns beschießt oder verfolgt, wird zuerst angegangen (Schützen nicht ignorieren)
		if phase != "guild":
			var attackers: Array = s.monsters.filter(func(m): return m.aware and m.get("homeRoom") == null and J.cheb(m.pos, p.pos) <= 7 and Fov.has_line_of_sight(s.map, p.pos, m.pos))
			if not attackers.is_empty():
				J.sort(attackers, func(a, b): return J.cheb(a.pos, p.pos) - J.cheb(b.pos, p.pos))
				if _go_to(s, attackers[0].pos):
					continue
		if phase == "clear":
			# Gegenstände in der Nähe aufsammeln, wenn es ruhig ist
			if _calm(s):
				var loot = J.find(s.items, func(e): return e.item.kind != "wurf" and J.cheb(e.pos, p.pos) <= 6 and Fov.has_line_of_sight(s.map, p.pos, e.pos) and MapGen.furniture_at(s.map, e.pos) == null)
				if loot != null and _go_to(s, loot.pos):
					continue
			# Normale Mobs in der Nähe jagen, ab Stufe 5 auch Nachbarschaftsbosse
			var targets: Array = s.monsters.filter(func(m):
				# Bosse nur, wenn mindestens gleich stark und kaum verletzt
				if m.rank == "nachbarschaftsboss":
					return p.level >= 5 and m.level <= p.level and p.hp >= Player.max_hp(s) * 0.8
				if m.rank == "elite":
					return m.level <= p.level - 1
				return m.rank == "normal" and m.level <= p.level + 1)
			J.sort(targets, func(a, b): return J.cheb(a.pos, p.pos) - J.cheb(b.pos, p.pos))
			# LEAVE=0.7: erst gehen, wenn 70 % der Etagenzeit vorbei sind
			# (ohne LEAVE: wenn nichts mehr zu tun ist oder die Zeit knapp wird)
			var leave := float(OS.get_environment("LEAVE")) if OS.get_environment("LEAVE") != "" else 0.0
			var used := 1.0 - float(Game.time_left(s)) / float(Db.floor_def0(s.floor).duration)
			var go: bool = (used >= leave or Game.time_left(s) < 150) if leave > 0 else (targets.is_empty() or Game.time_left(s) < 700)
			if go:
				phase = "stairs"
				continue
			if targets.is_empty():
				_wait(s, "keine_ziele")
				continue
			# Das nächste erreichbare Ziel (Monster in verschlossenen Kammern übergehen)
			var moved := false
			if s.get("_unreachable") == null:
				s._unreachable = {}
			var tried := 0
			for tg in targets:
				if s.turn - int(s._unreachable.get(tg.uid, -1000)) < 50:
					continue
				if _go_to(s, tg.pos):
					moved = true
					break
				s._unreachable[tg.uid] = s.turn
				tried += 1
				if tried >= 3:
					break
			if not moved:
				_wait(s, "L345")
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
			_wait(s, "L358")
	return s
