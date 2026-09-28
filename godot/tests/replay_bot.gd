class_name ReplayBot
extends RefCounted
## Aufzeichnungs-Bot für die Replay-Tests: spielt Partien und hält jede
## Aktion samt Kurzzustand fest. `test_replay` spielt dieselben Aktionen nach
## und vergleicht Zug für Zug. Neu aufnehmen mit `tools/record_fixtures.gd`,
## wenn sich Inhalte oder Regeln absichtlich ändern.

const ANSWERS := [
	{"beruf": 1},
	{"beruf": 5, "sport": 1, "hobbysport": 1, "kampfsport": 3, "haustier": 0, "ort": 0, "hand": 1, "kleidung": 3, "schuhe": 2, "angst": 1, "laster": 2, "glueck": 0, "alter": 2, "charakter": 1},
	{"beruf": 7, "it": 1, "sozial": 2, "haustier": 1, "ort": 1, "hand": 3, "kleidung": 0, "hose": 1, "schuhe": 4, "extra": 2, "angst": 3, "laster": 4, "konflikt": 4, "augen": 0},
]

const PARTS := ["faust", "tritt", "knie", "ellbogen", "kopf", "waffe"]
const MOVES := ["normal", "normal", "sprung", "stampfen", "anlauf"]
const ZONES := [null, "kopf", "koerper", "arme", "beine"]
const DIRS := [[1, 0], [-1, 0], [0, 1], [0, -1]]

var s: Dictionary
var actions: Array = []
var digests: Array = []
var checkpoints: Dictionary = {}
var every: int
var _rng: Rng


## Die Partien für `test_replay` (Seed, Antworten, Aktionen, Abstand der Zwischenstände).
static func replays() -> Array:
	return [
		ReplayBot.make(1, ANSWERS[1], 3500, 700),
		ReplayBot.make(5, ANSWERS[2], 3500, 700),
		ReplayBot.make(8, ANSWERS[2], 400, 100),
	]


static func make(seed: int, answers: Dictionary, steps: int, every_n: int) -> Dictionary:
	var bot := ReplayBot.new()
	return bot._play(seed, answers, steps, every_n)


static func _center(r: Dictionary) -> Dictionary:
	return {"x": r.x + floori(r.w / 2.0), "y": r.y + floori(r.h / 2.0)}


func _rnd() -> float:
	return _rng.next()


func _pick_index(n: int) -> int:
	return floori(_rnd() * n)


func _act(a: String, args: Array = []) -> bool:
	var res := Parity.run_action(s, a, args)
	actions.append({"a": a, "args": args})
	digests.append(Parity.digest(s))
	if actions.size() % every == 0:
		checkpoints[str(actions.size())] = Parity.snapshot(s)
	return res.ok


func _occupied(x: int, y: int) -> bool:
	return J.some(s.monsters, func(m): return m.pos.x == x and m.pos.y == y)


func _go_to(target: Dictionary) -> bool:
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
		if MapGen.furniture_at(s.map, {"x": x, "y": y}) != null:
			return false
		return not _occupied(x, y)
	var path = Pathfinding.find_path(s.map, s.player.pos, target, passable, 8000, true)
	if path == null or path.is_empty():
		return false
	return _act("moveStep", [path[0]])


func _wander() -> void:
	var p: Dictionary = s.player.pos
	var w: int = s.map.width
	var dirs: Array = []
	for d in DIRS:
		var q := {"x": p.x + d[0], "y": p.y + d[1]}
		if s.map.tiles[q.y * w + q.x] == "floor" and MapGen.furniture_at(s.map, q) == null and not _occupied(q.x, q.y):
			dirs.append(q)
	if not dirs.is_empty() and _rnd() < 0.7:
		_act("moveStep", [dirs[_pick_index(dirs.size())]])
	else:
		_act("wait")


func _fight() -> bool:
	var p: Dictionary = s.player
	# Werfen auf Entfernung
	var far: Array = s.monsters.filter(func(m): return m.aware and J.cheb(m.pos, p.pos) >= 2 and J.cheb(m.pos, p.pos) <= 5)
	if not far.is_empty() and not Player.throwables(s).is_empty() and _rnd() < 0.15:
		var tw := {"part": "wurf", "move": "normal"}
		if Combat.technique_blocker(s, far[0], tw) == null:
			return _act("attack", [far[0].uid, tw])
	if not far.is_empty() and Magic.knows_spell(s, "geschoss") and J.num(p, "mp") >= 3 and _rnd() < 0.15:
		if _act("cast", ["geschoss", {"targetUid": far[0].uid, "mana": 3}]):
			return true
	var near: Array = s.monsters.filter(func(m): return J.cheb(m.pos, p.pos) <= 1)
	if near.is_empty():
		return false
	J.sort(near, func(a, b): return a.hp - b.hp)
	var adj: Dictionary = near[0]
	if _rnd() < 0.05:
		return _act("defend")
	# Wie in der Aufnahme: die Schleifengrenze wird bei jedem Durchlauf neu ausgewürfelt
	var i := 0
	while i < (6 if _rnd() < 0.3 else 0):
		var t := {"part": PARTS[_pick_index(PARTS.size())], "move": MOVES[_pick_index(MOVES.size())]}
		var z = ZONES[_pick_index(ZONES.size())]
		if z != null:
			t.zone = z
		if Combat.technique_blocker(s, adj, t) == null:
			return _act("attack", [adj.uid, t])
		i += 1
	for t in [{"part": "tritt", "move": "stampfen"}, {"part": "tritt", "move": "normal"}, {"part": "faust", "move": "normal"}]:
		if Combat.technique_blocker(s, adj, t) == null:
			return _act("attack", [adj.uid, t])
	return _act("wait")


func _nearest_rooms(filter: Callable) -> Array:
	var p: Dictionary = s.player.pos
	var rooms: Array = s.map.rooms.filter(filter)
	J.sort(rooms, func(a, b): return J.cheb(_center(a), p) - J.cheb(_center(b), p))
	return rooms


func _play(seed: int, answers: Dictionary, steps: int, every_n: int) -> Dictionary:
	every = every_n
	_rng = Rng.new(seed * 7919 + 13)
	var opts := {"name": "Bot", "answers": answers, "seed": seed}
	var o2 := opts.duplicate()
	o2.meta = Meta.empty_meta()
	s = Game.new_game(o2)
	var start := Parity.snapshot(s)
	var phase := "guild"
	var floor_no := 1
	var guard := 0
	while s.status == "playing" and actions.size() < steps:
		if guard >= steps * 4:
			break
		guard += 1
		var p: Dictionary = s.player
		if s.floor != floor_no:
			floor_no = s.floor
			phase = "clear"
		var show = s.get("talkShow")
		if show != null and not show.get("done"):
			_act("answerTalkShow", [_pick_index(3)])
			continue
		if s.pendingSelection:
			var opts2 := Classes.class_options(s)
			_act("chooseRaceAndClass", ["mensch", opts2[_pick_index(mini(3, opts2.size()))].klass.id])
			continue
		if J.num(p, "statPoints") > 0 and s.unlocks.has("stats"):
			_act("allocateStat", [["str", "ges", "kon", "int", "cha"][_pick_index(5)]])
			continue
		if p.get("klass") != null and not p.get("abilityCooldown") and J.some(s.monsters, func(m): return J.cheb(m.pos, p.pos) <= 2) and _rnd() < 0.3:
			if _act("useAbility", [{"part": "tritt", "move": "normal"}]):
				continue
		var nc = J.find(J.arr(s, "crawlers"), func(c): return c.alive and not c.get("party") and J.cheb(c.pos, p.pos) <= 1)
		if nc != null and not nc.get("met") and _rnd() < 0.5:
			_act("talkCrawler" if _rnd() < 0.5 else "inviteCrawler", [nc.uid])
			continue
		if p.hp < Player.max_hp(s) * 0.25:
			_act("testHeal")
			continue
		# Blase: rechtzeitig zur Toilette (hineinlaufen benutzt sie)
		if J.num(p, "blase") >= 60:
			var is_wc := func(f): return f.kind == "toilette"
			var safes := _nearest_rooms(func(r): return r.kind == "safe" and J.some(J.arr(r, "furniture"), is_wc))
			var wc = J.find(J.arr(safes[0], "furniture"), is_wc) if not safes.is_empty() else null
			if wc != null:
				if J.cheb(wc.pos, p.pos) == 1 and absi(wc.pos.x - p.pos.x) + absi(wc.pos.y - p.pos.y) == 1:
					_act("moveStep", [wc.pos])
					continue
				var spots: Array = []
				for d in DIRS:
					var q := {"x": wc.pos.x + d[0], "y": wc.pos.y + d[1]}
					if s.map.tiles[q.y * s.map.width + q.x] == "floor" and MapGen.furniture_at(s.map, q) == null:
						spots.append(q)
				if not spots.is_empty() and _go_to(spots[0]):
					continue
		var danger := J.some(s.monsters, func(m): return m.aware and J.cheb(m.pos, p.pos) <= 3 and m.level >= p.level + 3)
		var mhp := Player.max_hp(s)
		if p.hp < mhp * 0.5 or (danger and p.hp < mhp * 0.8):
			var pot = J.find(p.inventory, func(it):
				var e = it.get("effekt")
				if it.kind != "verbrauch" or e == null or not (e.get("heal") or e.get("healPct")):
					return false
				return not (String(it.baseId).contains("trank") and J.num(p, "potionCooldown") > 0))
			if pot != null:
				_act("useItem", [pot.uid])
				continue
			if Magic.knows_spell(s, "heilen") and J.num(p, "mp") >= 3 and _act("cast", ["heilen", {}]):
				continue
			var safes := _nearest_rooms(func(r): return r.kind == "safe")
			var safe = safes[0] if not safes.is_empty() else null
			if safe != null and not Combat.is_in_safe_room(s, p.pos):
				if not danger and _fight():
					continue
				if not _go_to(_center(safe)):
					_wander()
				continue
			if safe != null:
				if not p.boxes.is_empty() and s.unlocks.has("inventar"):
					_act("openBox", [p.boxes[0].uid])
					continue
				var gear = J.find(p.inventory, func(it): return it.kind == "ausruestung")
				if gear != null and _rnd() < 0.7:
					_act("equip", [gear.uid])
					continue
				if J.num(p, "blase") > 20:
					_act("toilet")
					continue
				if not _act("sleep"):
					_act("wait")
				continue
		if _fight():
			continue
		var last = actions.back() if not actions.is_empty() else null
		if J.some(s.items, func(e): return e.pos.x == p.pos.x and e.pos.y == p.pos.y) and (last == null or last.a != "pickup"):
			_act("pickup")
			continue
		if s.unlocks.has("inventar") and _rnd() < 0.05:
			var idx := _pick_index(p.inventory.size())
			var it = p.inventory[idx] if idx < p.inventory.size() else null
			if it != null and it.kind == "ausruestung":
				_act("equip", [it.uid])
				continue
			if it != null and (it.kind == "verbrauch" or it.kind == "buch"):
				_act("useItem", [it.uid])
				continue
		if s.unlocks.has("inventar") and _rnd() < 0.02:
			_act("craftItem", [["verband", "brandflasche", "nagelbombe", "stachelfalle"][_pick_index(4)]])
			continue
		if phase == "guild":
			if s.unlocks.has("inventar"):
				phase = "clear"
				continue
			var g := _nearest_rooms(func(r): return r.kind == "guild")
			if not _go_to(_center(g[0])):
				_wander()
			continue
		if phase == "clear":
			var targets: Array = s.monsters.filter(func(m):
				var rank_ok: bool = (m.rank == "normal" or m.rank == "elite") if p.level < 5 else m.rank != "boroughboss"
				return rank_ok and m.level <= p.level + 1)
			J.sort(targets, func(a, b): return J.cheb(a.pos, p.pos) - J.cheb(b.pos, p.pos))
			if targets.is_empty() or s.turn - s.floorStartTurn > 900:
				phase = "stairs"
				continue
			if not _go_to(targets[0].pos):
				_wander()
			continue
		var stairs: Array = []
		var w: int = s.map.width
		for i in s.map.tiles.size():
			if s.map.tiles[i] == "stairs":
				stairs.append({"x": i % w, "y": floori(i / float(w))})
		J.sort(stairs, func(a, b): return J.cheb(a, p.pos) - J.cheb(b, p.pos))
		if J.some(stairs, func(q): return q.x == p.pos.x and q.y == p.pos.y):
			_act("descend", [{"ghosts": []}])
			continue
		if not _go_to(stairs[0]):
			_wander()
	checkpoints[str(actions.size())] = Parity.snapshot(s)
	return {"seed": seed, "opts": opts, "start": start, "actions": actions, "digests": digests, "checkpoints": checkpoints}


# ================================================================ Oberfläche

## Was die Anzeige an einer Stelle der Partie berechnet (für `test_ui_parity`).
static func ui_record(st: Dictionary, step: int) -> Dictionary:
	var items: Array = st.player.inventory.duplicate()
	for slot in st.player.equipment:
		if st.player.equipment[slot] != null:
			items.append(st.player.equipment[slot])
	return {
		"step": step,
		"time": ViewHelpers.format_time(st.turn),
		"goals": ViewHelpers.next_goals(st),
		"materials": st.map.rooms.map(func(r): return Tiles.room_material(r)),
		"bonuses": items.map(func(it): return Bonuses.describe(it.get("bonuses"))),
		"crawlers": J.arr(st, "crawlers").map(func(c): return Crawlers.describe(c)),
		"talkable": Crawlers.talkable(st).map(func(c): return c.uid),
		"traps": ViewHelpers.disarmable_traps(st).map(func(t): return t.uid),
		"sponsors": Sponsors.states(st).map(func(x): return "%s:%s" % [x.id, x.status]),
		"pet": PetEvo.form_name(st.player.pet) if st.player.get("pet") != null else null,
		"skills": st.player.skills.map(func(k): return [Skills.effect_text(Db.skill(k.id), k.level), Skills.effect_text(Db.skill(k.id), k.level + 1)]),
	}


## Prüfpunkte der Anzeige-Helfer entlang einer aufgezeichneten Partie.
static func ui_checks(r: Dictionary, every_n: int) -> Dictionary:
	var opts: Dictionary = r.opts.duplicate()
	opts.meta = Meta.empty_meta()
	var st := Game.new_game(opts)
	var out: Array = [ui_record(st, 0)]
	var acts: Array = r.actions
	for i in acts.size():
		Parity.run_action(st, acts[i].a, acts[i].args)
		if (i + 1) % every_n == 0 or i == acts.size() - 1:
			out.append(ui_record(st, i + 1))
	var hashes: Array = []
	for y in range(-3, 60, 7):
		for x in range(-2, 90, 11):
			for salt in [0, 3, 5, 6, 41, 50, 99]:
				hashes.append(Tiles.hash(x, y, salt))
	var times: Array = [0, 1, 19, 20, 479, 480, 481, 2399, 12345].map(func(t): return ViewHelpers.format_time(t))
	return {"seed": r.seed, "every": every_n, "checks": out, "hashes": hashes, "times": times}


# ================================================================ Karten

## Sichtfeld und Weg auf echten Etagen (für `test_map`).
static func maps() -> Array:
	var out: Array = []
	for seed in [7, 8]:
		var st := Game.new_game({"name": "Test", "answers": {"beruf": 1}, "seed": seed, "meta": Meta.empty_meta()})
		var m: Dictionary = st.map
		var from: Dictionary = st.player.pos
		var fov: Array = Fov.compute(m, from, 7).keys()
		fov.sort()
		var stairs: int = m.tiles.find("stairs")
		var to := {"x": stairs % int(m.width), "y": floori(stairs / float(m.width))}
		var path = Pathfinding.find_path(m, from, to, Callable(), 20000, true)
		out.append({"seed": seed, "width": m.width, "height": m.height, "tiles": m.tiles, "from": from, "fov": fov, "to": to, "path": path})
	return out
