class_name Game
extends RefCounted
## Spielablauf: Neues Spiel, Züge, Aktionen, Etagenwechsel.
## Aktionen geben {ok, message?} zurück.

const SAVE_VERSION := 1
const SELECT_FIRST := "Wähle zuerst deine Rasse und Klasse."
const FREEBIE_JOKES := ["clownsnase", "partyhut", "aluhut", "kaffeetasse", "porzellanpuppe", "rubbellos"]
const CONTRACT_MIN_FLOOR := 9


static func _fail(message: String) -> Dictionary:
	return {"ok": false, "message": message}


static func _ok() -> Dictionary:
	return {"ok": true}


# ================================================================ Start

## opts: {name, answers (Dictionary oder Array), petName?, seed?, meta}
static func new_game(opts: Dictionary) -> Dictionary:
	var seed_v = opts.get("seed")
	var seed: int = seed_v if seed_v != null else randi() % 2147483648
	var meta: Dictionary = opts.meta
	var last_guide = meta.guides[meta.guides.size() - 1] if not meta.guides.is_empty() else null
	var floors: Array = Db.world("FLOORS")
	var name := String(opts.get("name", "")).strip_edges()
	var s := {
		"version": SAVE_VERSION,
		"seed": seed,
		"rng": seed,
		"floor": 1,
		"turn": 0,
		"collapseAt": floors[0].duration,
		"floorStartTurn": 0,
		"map": null,
		"player": {
			"name": name if not name.is_empty() else "Namenlos",
			"background": "Unbekannt",
			"pos": J.pos(0, 0),
			"level": 1,
			"xp": 0,
			"hp": 1,
			"maxHpBase": 10,
			"ausdauer": 1,
			"maxAusdauerBase": 4,
			"stats": Db.t("interview", "BASE_STATS").duplicate(),
			"statPoints": 0,
			"gold": 0,
			"hand": null,
			"inventory": [],
			"boxes": [],
			"equipment": {},
			"skills": [],
			"buffs": [],
			"techniqueUses": {},
			"techniqueKills": {},
			"lastMoveDir": null,
			"pet": null,
			"flags": [],
			"curses": [],
		},
		"monsters": [],
		"items": [],
		# Die Karte merkt sich von Anfang an, wo man schon war
		"unlocks": ["minimap"],
		"achievements": [],
		"counters": {
			"kills": 0, "killsByDef": {}, "steps": 0, "itemsPicked": 0, "boxesOpened": 0, "missStreak": 0,
			"hitTakenStreak": 0, "throws": 0, "bossKills": 0, "damageDealt": 0, "damageTaken": 0,
			"goldEarned": 0, "goldStolen": 0, "poisonDamage": 0, "mealsEaten": 0, "potionsDrunk": 0, "sleeps": 0,
			"crits": 0, "knockdowns": 0, "eliteKills": 0,
			"trapsFound": 0, "trapsTriggered": 0, "trapsDisarmed": 0, "trapKills": 0, "crafted": 0,
		},
		"log": [],
		"status": "playing",
		"lastSpawnTurn": 0,
		"uidCounter": 0,
		"currentRoom": -1,
		"pendingDialogs": [],
		"guideName": last_guide.name if last_guide != null else Db.world("DEFAULT_GUIDE").name,
		"season": meta.season + 1,
		"contractSigned": false,
		"firstEver": meta.achievementsEver.duplicate(),
		"ghostsDefeated": [],
		"viewers": {"follower": 0, "hype": 0, "nextFanBox": 0, "lastSpectacle": 0},
		"pendingSelection": false,
		"toasts": [],
	}

	# --- Interview auswerten
	var p: Dictionary = s.player
	var answers: Dictionary
	if opts.answers is Array:
		answers = {}
		var order: Array = Db.t("interview", "LEGACY_ORDER")
		for i in opts.answers.size():
			answers[order[i]] = opts.answers[i]
	else:
		answers = opts.answers
	p.traits = []
	var hand = null
	for q in Rules.visible_questions(answers):
		if answers.get(q.id) == null:
			continue
		var ai: int = answers[q.id]
		if ai < 0 or ai >= q.answers.size():
			continue
		var a: Dictionary = q.answers[ai]
		if a.get("background"):
			p.background = a.background
		if a.get("stats") != null:
			for k in a.stats:
				p.stats[k] = maxi(1, p.stats[k] + a.stats[k])
		for sk in J.arr(a, "skills"):
			Skills.learn_skill(s, sk, 1, true)
		for f in J.arr(a, "flags"):
			p.flags.append(f)
		for id in J.arr(a, "items"):
			var it := Items.create_item(s, id)
			if not it.get("slot"):
				continue
			var slot: String = "ring1" if it.slot == "ring" else ("fussring1" if it.slot == "fussring" else it.slot)
			p.equipment[slot] = it
		if a.get("pet") != null:
			var pet_name := String(opts.get("petName", "")).strip_edges()
			p.pet = _make_pet(a.pet.species, pet_name if not pet_name.is_empty() else a.pet.defaultName)
		for t in J.arr(a, "traits"):
			if not p.traits.has(t):
				p.traits.append(t)
		if a.get("hand"):
			hand = Items.create_item(s, a.hand, int(J.nn(a, "handMenge", 1)))
		if a.get("gold"):
			p.gold += a.gold
	var combo_notes := []
	var combos: Array = Db.t("interview", "INTERVIEW_COMBOS")
	for i in combos.size():
		if not Rules.combo_when(i, answers):
			continue
		for t in combos[i].traits:
			if not p.traits.has(t):
				p.traits.append(t)
		combo_notes.append(combos[i].text)
	p.hand = hand
	if p.traits.has("tierarzt") and p.pet != null:
		Ai.pet_level_up(s)

	_enter_floor(s, 1, meta)
	_mark_tutorial_guild(s)
	p.hp = Player.max_hp(s)
	p.ausdauer = Player.max_ausdauer(s)

	var show_name: String = Db.world("SHOW_NAME")
	Log.add(s, "Willkommen bei %s, Staffel %d!" % [show_name, s.season], "system")
	var pages := [
		"Crawler %s! Deine Welt wurde soeben… sagen wir: „umgenutzt“. Die gute Nachricht: Du darfst an der beliebtesten Show der Galaxis teilnehmen. Die schlechte: Du hast keine Wahl." % p.name,
		"%s" % floors[0].intro,
	]
	pages.append_array(combo_notes)
	if not p.traits.is_empty():
		var names: Array = p.traits.map(func(t):
			var d = Db.trait_def(t)
			return d.name if d != null else t)
		pages.append("Die Systemstimme hat dich analysiert. Deine Eigenschaften: %s. Details findest du im Crawler-Tab." % ", ".join(names))
	pages.append("Du hast nichts. Kein Inventar, keine Karte, keine Ahnung. Irgendwo auf dieser Etage gibt es eine Gilde der Einweisung – such sie. Bis dahin kannst du genau einen Gegenstand in der Hand halten. Und deine Fäuste. Und Füße. Viel Spaß!")
	s.pendingDialogs.append({"title": "%s – Staffel %d" % [show_name, s.season], "speaker": Db.world("SYSTEM_NAME"), "pages": pages})
	s.pendingDialogs.append({"title": "So spielst du", "speaker": Db.world("SYSTEM_NAME"), "pages": Rules.controls_pages()})
	Events.emit(s, {"type": "start"})
	return s


static func _make_pet(species: String, name: String) -> Dictionary:
	var cat := species == "Katze"
	return {
		"name": name, "species": species, "level": 1, "xp": 0,
		"hp": 12 if cat else 16, "maxHp": 12 if cat else 16,
		"dmg": [1, 3] if cat else [2, 3],
		"pos": J.pos(0, 0), "alive": true,
	}


static func _enter_floor(s: Dictionary, floor: int, meta: Dictionary) -> void:
	# Die Etage gilt schon beim Erzeugen (Stärke der Monster hängt daran)
	s.floor = floor
	var gen := MapGen.generate_floor(s, floor, meta.ghosts)
	s.map = gen.map
	s.monsters = gen.monsters
	s.items = gen.items
	s.player.pos = J.pcopy(gen.start)
	s.player.immobile = 0
	Traps.place_traps(s, gen.start)
	s.currentRoom = -1
	var def := Db.floor_def0(floor)
	s.floorStartTurn = s.turn
	s.collapseAt = s.turn + def.duration
	s.lastSpawnTurn = s.turn
	# Stand zu Beginn der Etage (für Meisterleistungen wie „Ohne Netz“)
	s.floorStart = {"potions": int(s.counters.potionsDrunk), "sleeps": int(s.counters.sleeps), "kills": int(s.counters.kills)}
	# Einlagen gelten nur auf ihrer Etage
	s.erase("showEvent")
	s.erase("nextShowEvent")
	var pet = s.player.pet
	if pet != null:
		var spot = null
		for q in _neighbors(gen.start):
			if MapGen.is_walkable(s.map, q.x, q.y) and not Ai.occupied(s, q):
				spot = q
				break
		pet.pos = spot if spot != null else J.pcopy(gen.start)
	Crawlers.populate(s, gen.start)
	Kanalstadt.add_residents(s)
	TalkShow.snapshot_floor(s)
	after_move(s)


static func _neighbors(p: Dictionary) -> Array:
	var out := []
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx or dy:
				out.append(J.pos(p.x + dx, p.y + dy))
	return out


# ================================================================ Abfragen

static func has_unlock(s: Dictionary, u: String) -> bool:
	return s.unlocks.has(u)


## Ab welcher Etage ein System dazukommt (world.json UNLOCK_FLOORS):
## Zuschauer ab Etage 2, Klassen, Rassen, Handel und Aufträge ab Etage 3.
static func unlock_floor(u: String) -> int:
	return int(J.nn(Db.world("UNLOCK_FLOORS"), u, 1))


## Schaltet Handel und Aufträge frei, sobald die Etage erreicht ist.
## Gibt die neu freigeschalteten Systeme zurück.
static func unlock_floor_systems(s: Dictionary, floor: int) -> Array:
	var neu := []
	for u in ["handel", "auftraege"]:
		if floor >= unlock_floor(u) and not has_unlock(s, u):
			s.unlocks.append(u)
			neu.append(u)
	return neu


static func visible_tiles(s: Dictionary) -> Dictionary:
	return Fov.compute(s.map, s.player.pos, Player.lichtradius(s))


static func items_at(s: Dictionary, p: Dictionary) -> Array:
	return s.items.filter(func(e): return e.pos.x == p.x and e.pos.y == p.y)


static func current_room(s: Dictionary) -> Variant:
	return MapGen.room_of(s.map, s.player.pos)


static func time_left(s: Dictionary) -> int:
	return maxi(0, s.collapseAt - s.turn)


## Weg über bekannte Kacheln zu einem Ziel (für Klick-Bewegung).
static func plan_path(s: Dictionary, target: Dictionary) -> Variant:
	var m: Dictionary = s.map
	if not MapGen.in_bounds(m, target.x, target.y):
		return null
	var known := func(x: int, y: int) -> bool: return m.explored[MapGen.idx(m, x, y)]
	if not known.call(target.x, target.y):
		return null
	var is_target := func(x: int, y: int) -> bool: return x == target.x and y == target.y
	var ok := func(x: int, y: int) -> bool:
		return known.call(x, y) and Ai.monster_at(s, J.pos(x, y)) == null and (is_target.call(x, y) or (MapGen.furniture_at(m, J.pos(x, y)) == null and Dungeon.lock_at(s, J.pos(x, y)) == null))
	var path = Pathfinding.find_path(m, s.player.pos, target, func(x, y): return ok.call(x, y) and (is_target.call(x, y) or not Traps.avoid_tile(s, x, y)), 6000, true)
	if path == null:
		path = Pathfinding.find_path(m, s.player.pos, target, ok, 6000, true)
	return path


# ================================================================ Züge

static func move_step(s: Dictionary, to: Dictionary) -> Dictionary:
	if s.status != "playing":
		return _fail("Das Spiel ist vorbei.")
	if s.pendingSelection:
		return _fail(SELECT_FIRST)
	var p: Dictionary = s.player
	if J.cheb(p.pos, to) != 1:
		return _fail("Nur ein Feld pro Zug.")
	if not Rounds.can_move(s):
		return _fail("Keine Bewegung mehr in dieser Runde. Greif an oder beende die Runde (Leertaste).")
	var furn = MapGen.furniture_at(s.map, to)
	if furn != null:
		return use_furniture(s, furn)
	var lair = locked_lair(s)
	if lair != null:
		var tr = MapGen.room_of(s.map, to)
		if tr == null or tr.id != lair.id:
			return _fail("Die Tür ist verriegelt. Hier kommst du erst wieder heraus, wenn der Boss besiegt ist.")
	var to_tile := MapGen.tile_at(s.map, to.x, to.y)
	if to_tile == "door":
		return open_door(s, to)
	if Dungeon.is_crate(to_tile):
		return smash(s, to)
	if Tiefgarage.is_wreck(to_tile):
		return search_wreck(s, to)
	if not Pathfinding.can_step(s.map, p.pos, to):
		return _fail("Durch einen Türrahmen geht es nur gerade hindurch." if Pathfinding.is_door(s.map, to.x, to.y) or Pathfinding.is_door(s.map, p.pos.x, p.pos.y) else "Da ist eine Wand.")
	if Ai.monster_at(s, to) != null:
		return _fail("Da steht ein Gegner.")
	# Friedliche Crawler lassen dich vorbei (ihr tauscht die Plätze), damit
	# niemand dauerhaft einen engen Gang versperrt
	var other = Crawlers.crawler_at(s, to)
	if other != null and not other.party and other.personality == "feindselig":
		return _fail("Da steht %s." % other.name)
	if p.get("immobile") and not Traps.struggle(s):
		end_turn(s)
		return _ok()
	if Dungeon.stuck_in_mud(s):
		end_turn(s)
		return _ok()
	var pet = p.pet
	if pet != null and pet.alive and pet.pos.x == to.x and pet.pos.y == to.y:
		pet.pos = J.pcopy(p.pos)
	if other != null:
		other.pos = J.pcopy(p.pos)
		if not other.party:
			Log.add(s, "Du drängst dich an %s vorbei." % other.name, "info")
	p.lastMoveDir = J.pos(to.x - p.pos.x, to.y - p.pos.y)
	p.pos = J.pcopy(to)
	# In der Tür einer Boss-Kammer bleibt man nicht stehen: ein Schritt hinein,
	# und die Tür fällt hinter einem zu (siehe _on_enter_room)
	var inside = _lair_step_inside(s, to, p.lastMoveDir)
	if inside != null:
		p.pos = inside
	s.counters.steps += 1
	Events.emit(s, {"type": "moved"})
	after_move(s)
	Traps.on_player_step(s)
	Dungeon.on_player_step(s)
	if Mounts.mount_step(s):
		end_turn(s, true, "move")
	return _ok()


## Feld hinter der offenen Tür einer Boss-Kammer mit lebendem Boss (oder null).
static func _lair_step_inside(s: Dictionary, at: Dictionary, dir: Dictionary) -> Variant:
	if MapGen.tile_at(s.map, at.x, at.y) != "dooropen" or not is_lair_door(s, at):
		return null
	var cands: Array = [J.pos(at.x + dir.x, at.y + dir.y)]
	for d in MapGen.DIRS4:
		cands.append(J.pos(at.x + d[0], at.y + d[1]))
	for q in cands:
		var r = MapGen.room_of(s.map, q)
		if r == null or (r.kind != "boss" and r.kind != "arena"):
			continue
		if not J.some(s.monsters, func(m): return m.get("homeRoom") == r.id and (m.rank == "nachbarschaftsboss" or m.rank == "boroughboss")):
			return null
		if MapGen.is_walkable(s.map, q.x, q.y) and Ai.monster_at(s, q) == null and MapGen.furniture_at(s.map, q) == null:
			return q
	return null


## Die Boss-Kammer, in der der Crawler gerade eingeschlossen ist.
static func locked_lair(s: Dictionary) -> Variant:
	var room = current_room(s)
	if room == null or (room.kind != "boss" and room.kind != "arena"):
		return null
	var boss := J.some(s.monsters, func(m): return m.get("homeRoom") == room.id and (m.rank == "nachbarschaftsboss" or m.rank == "boroughboss"))
	return room if boss else null


static func is_lair_door(s: Dictionary, at: Dictionary) -> bool:
	for d in MapGen.DIRS4:
		var r = MapGen.room_of(s.map, J.pos(at.x + d[0], at.y + d[1]))
		if r != null and (r.kind == "boss" or r.kind == "arena"):
			return true
	return false


static func open_door(s: Dictionary, at: Dictionary) -> Dictionary:
	if s.status != "playing":
		return _fail("Das Spiel ist vorbei.")
	var p: Dictionary = s.player
	if MapGen.tile_at(s.map, at.x, at.y) != "door":
		return _fail("Hier ist keine geschlossene Tür.")
	if absi(at.x - p.pos.x) + absi(at.y - p.pos.y) != 1:
		return _fail("Türen öffnet man von vorne, nicht schräg.")
	if Dungeon.lock_at(s, at) != null:
		var res := Dungeon.try_door(s, at)
		if not res.ok:
			return _fail(res.message)
	s.map.tiles[MapGen.idx(s.map, at.x, at.y)] = "dooropen"
	var behind = null
	for d in MapGen.DIRS4:
		var r = MapGen.room_of(s.map, J.pos(at.x + d[0], at.y + d[1]))
		if r != null and r.kind != "normal":
			behind = r
			break
	var label := "die Tür"
	if behind != null and behind.kind == "safe":
		label = "die Tür zum Safe Room"
	elif behind != null and behind.kind == "guild":
		label = "die schwere Tür der Gilde"
	Log.add(s, "Du drückst die Klinke und öffnest %s." % label, "info")
	Events.emit(s, {"type": "doorOpened", "pos": J.pcopy(at)})
	after_move(s)
	end_turn(s)
	return _ok()


## Verschlossene Tür: Schloss knacken (kostet einen Zug).
static func pick_lock(s: Dictionary, at: Dictionary) -> Dictionary:
	if s.status != "playing":
		return _fail("Das Spiel ist vorbei.")
	var res := Dungeon.pick_lock(s, at)
	if not res.ok:
		return _fail(res.message)
	end_turn(s)
	return _ok()


## Kiste oder Fass zerschlagen (kostet einen Zug).
static func smash(s: Dictionary, at: Dictionary) -> Dictionary:
	if s.status != "playing":
		return _fail("Das Spiel ist vorbei.")
	if J.cheb(at, s.player.pos) != 1:
		return _fail("Dafür musst du direkt daneben stehen.")
	var res := Dungeon.smash(s, at)
	if not res.ok:
		return _fail(res.message)
	after_move(s)
	end_turn(s)
	return _ok()


## Autowrack durchsuchen (kostet einen Zug).
static func search_wreck(s: Dictionary, at: Dictionary) -> Dictionary:
	if s.status != "playing":
		return _fail("Das Spiel ist vorbei.")
	if J.cheb(at, s.player.pos) != 1:
		return _fail("Dafür musst du direkt daneben stehen.")
	var res := Tiefgarage.search(s, at)
	if not res.ok:
		return _fail(res.message)
	after_move(s)
	end_turn(s)
	return _ok()


## Verschlossene Türen neben dem Crawler.
static func adjacent_locked_doors(s: Dictionary) -> Array:
	var p: Dictionary = s.player.pos
	var out := []
	for d in MapGen.DIRS4:
		var q := J.pos(p.x + d[0], p.y + d[1])
		if MapGen.tile_at(s.map, q.x, q.y) == "door" and Dungeon.lock_at(s, q) != null:
			out.append(q)
	return out


static func close_door(s: Dictionary, at: Dictionary) -> Dictionary:
	if s.status != "playing":
		return _fail("Das Spiel ist vorbei.")
	if MapGen.tile_at(s.map, at.x, at.y) != "dooropen":
		return _fail("Hier ist keine offene Tür.")
	if J.cheb(at, s.player.pos) != 1:
		return _fail("Dafür musst du direkt daneben stehen.")
	if Ai.occupied(s, at) or not items_at(s, at).is_empty():
		return _fail("Etwas steht in der Tür.")
	s.map.tiles[MapGen.idx(s.map, at.x, at.y)] = "door"
	Log.add(s, "Du ziehst die Tür hinter dir zu. Klick.", "info")
	Events.emit(s, {"type": "doorClosed", "pos": J.pcopy(at)})
	after_move(s)
	end_turn(s)
	return _ok()


static func adjacent_open_doors(s: Dictionary) -> Array:
	var p: Dictionary = s.player.pos
	var out := []
	for d in MapGen.DIRS4:
		var q := J.pos(p.x + d[0], p.y + d[1])
		if MapGen.tile_at(s.map, q.x, q.y) == "dooropen":
			out.append(q)
	return out


static func attack(s: Dictionary, target_uid: String, t: Dictionary) -> Dictionary:
	if s.status != "playing":
		return _fail("Das Spiel ist vorbei.")
	if s.pendingSelection:
		return _fail(SELECT_FIRST)
	Rounds.before_action(s)
	if s.status != "playing":
		return _fail("Das Spiel ist vorbei.")
	var m = J.find(s.monsters, func(x): return x.uid == target_uid)
	if m == null:
		return _fail("Kein Ziel.")
	var res := Combat.player_attack(s, m, t)
	if not res.ok:
		return _fail(res.get("reason", "Geht nicht."))
	end_turn(s)
	return _ok()


static func defend(s: Dictionary) -> Dictionary:
	if s.status != "playing":
		return _fail("Das Spiel ist vorbei.")
	if s.pendingSelection:
		return _fail(SELECT_FIRST)
	Rounds.before_action(s)
	if s.status != "playing":
		return _fail("Das Spiel ist vorbei.")
	var p: Dictionary = s.player
	p.buffs = p.buffs.filter(func(b): return b.name != "Deckung")
	var guard := Player.skill_level(s, "abwehr")
	p.buffs.append({"name": "Deckung", "turns": 1, "bonuses": {"ausweichen": 20 + 2 * guard, "ruestung": 2 + floori(guard / 3.0)}})
	p.ausdauer = mini(Player.max_ausdauer(s), p.ausdauer + 2)
	Log.add(s, "Du gehst in Deckung und hebst die Arme.", "kampf")
	end_turn(s)
	return _ok()


static func wait(s: Dictionary) -> Dictionary:
	if s.status != "playing":
		return _fail("Das Spiel ist vorbei.")
	if s.pendingSelection:
		return _fail(SELECT_FIRST)
	if Conditions.clear_player(s, "brennen"):
		Log.add(s, "Du wirfst dich zu Boden und wälzt dich, bis die Flammen erstickt sind.", "info")
		end_turn(s, false, "end")
		return _ok()
	s.player.ausdauer = mini(Player.max_ausdauer(s), s.player.ausdauer + 1)
	# Wer wartet, sieht sich um: Geheimtüren in der Nähe fallen eher auf
	Dungeon.detect(s, visible_tiles(s))
	# Im Kampf: Runde beenden
	end_turn(s, false, "end")
	return _ok()


## Ende eines Zuges. kind (siehe Rounds.spend): "move" (Schritt), "action"
## oder "end". Im Kampf geht die Zeit erst weiter, wenn die Runde endet.
static func end_turn(s: Dictionary, keep_move_dir: bool = false, kind: String = "action") -> void:
	if not keep_move_dir:
		s.player.lastMoveDir = null
	if s.status != "playing":
		return
	if not Rounds.spend(s, kind):
		return
	var fighting := Rounds.active(s)
	var before := time_left(s)
	s.turn += 1
	# Monster in der Nähe handeln; weit entfernte schlafen. In der Kampfrunde
	# laufen wache Gegner erst bis zu ihrer Reichweite heran.
	for m in s.monsters.duplicate():
		if s.status != "playing":
			break
		if J.cheb(m.pos, s.player.pos) > 24 and not m.aware:
			continue
		var from = m.pos
		if fighting:
			Ai.close_in(s, m, Rounds.monster_speed(m) - 1)
		Ai.monster_turn(s, m)
		if not is_same(m.pos, from):
			Traps.on_monster_step(s, m)
	if fighting:
		Ai.pet_close_in(s, Rounds.ALLY_SPEED - 1)
		Crawlers.close_in(s, Rounds.ALLY_SPEED - 1)
	Ai.pet_turn(s)
	Crawlers.turn(s)
	# In der Grube wartet die Etage: keine Aufträge, die scheitern könnten
	if not Arena.active(s):
		Quests.tick(s)
	if s.status != "playing":
		return
	_tick_time(s, 1, before)
	Arena.check(s)
	Rounds.after_turn(s)


## Zeit vergeht: Buffs, Regeneration, Nachspawns, Einsturz.
static func _tick_time(s: Dictionary, turns: int, before: int) -> void:
	var p: Dictionary = s.player
	for b in p.buffs:
		if not b.get("dot"):
			continue
		var ticks := mini(turns, b.turns)
		var poisoned: bool = b.name == "Vergiftet"
		var resist := minf(0.9, Player.skill_level(s, "giftfestigkeit") * 0.06) if poisoned else 0.0
		var dmg := maxi(0 if poisoned and resist >= 0.9 else 1, J.rnd(b.dot * ticks * (1 - resist)))
		if poisoned and turns == 1:
			Skills.train_skill(s, "poison", 0.5)
		p.hp -= dmg
		if poisoned:
			s.counters.poisonDamage += dmg
		else:
			Stats.track(s, "schaden.%s" % String(b.name).to_lower(), dmg)
		if turns == 1:
			Log.add(s, "%s: −%d HP." % [b.name, dmg], "gefahr")
			Fx.float_text(s, p.pos, "-%d" % dmg, Fx.COLORS.gegenSpieler)
			Fx.hit(s, p.pos)
		if p.hp <= 0:
			Death.handle_lethal(s, Conditions.death_by_buff(b.name))
			if s.status != "playing":
				return
	for b in p.buffs:
		b.turns -= turns
	var expired: Array = p.buffs.filter(func(b): return b.turns <= 0)
	if not expired.is_empty():
		p.buffs = p.buffs.filter(func(b): return b.turns > 0)
		for b in expired:
			if b.name != "Deckung":
				Log.add(s, "Der Effekt „%s“ lässt nach." % b.name, "info")
	var bon := Player.total_bonuses(s)
	var regen_ticks := floori(s.turn / 8.0) - floori((s.turn - turns) / 8.0)
	if regen_ticks > 0:
		p.hp = mini(Player.max_hp(s, bon), p.hp + regen_ticks * (1 + int(J.num(bon, "hpRegen"))))
	var calm := not J.some(s.monsters, func(m): return m.aware and J.cheb(m.pos, p.pos) <= 10)
	if turns == 1 and calm and s.turn % 3 == 0:
		p.hp = mini(Player.max_hp(s, bon), p.hp + 1)
	p.ausdauer = mini(Player.max_ausdauer(s, bon), p.ausdauer + turns * (1 + floori(Player.skill_level(s, "kondition") / 5.0)))
	Player.clamp_vitals(s)

	Viewers.tick(s, turns)
	var in_arena := Arena.active(s)
	if not in_arena:
		ShowEvents.tick(s, turns)
		Highlights.tick(s)
	Magic.tick(s, turns)
	Extras.egg_tick(s)
	if p.get("potionCooldown"):
		p.potionCooldown = maxi(0, p.potionCooldown - turns)
	if p.get("immobile"):
		p.immobile = maxi(0, p.immobile - turns)
		if not p.immobile:
			Log.add(s, "Du bist wieder frei.", "info")
	if not in_arena:
		Bladder.tick(s, turns)
	if s.status != "playing":
		return
	if p.get("abilityCooldown"):
		p.abilityCooldown = maxi(0, p.abilityCooldown - turns)

	while s.turn - s.lastSpawnTurn >= 30:
		s.lastSpawnTurn += 30
		_respawn(s)

	var left := time_left(s)
	for w in Db.world("COLLAPSE_WARNINGS"):
		var threshold: int = w[0]
		if before > threshold and left <= threshold:
			Log.add(s, "SYSTEMMELDUNG: %s" % w[1], "gefahr")
			Log.toast(s, "Einsturz-Warnung", w[1], "warnung")
	if left <= 20 and Combat.is_in_safe_room(s, p.pos):
		_kick_from_safe_room(s)
	if left <= 0:
		p.hp = 0
		s.status = "dead"
		s.deathCause = "unter der einstürzenden Etage begraben"
		Log.add(s, "Die Decke kommt herunter. Die ganze Etage stürzt ein – und du mit ihr.", "gefahr")


## Nachschub kommt nur in den Revieren, und zwar immer dieselbe Art.
static func _respawn(s: Dictionary) -> void:
	var vis := visible_tiles(s)
	for hood in s.map.hoods:
		# Ohne Boss kommt im Viertel nur halb so oft etwas nach
		if not hood.bossAlive and int(s.lastSpawnTurn / 30) % 2 == 1:
			continue
		var rooms: Array = s.map.rooms.filter(func(r): return r.hood == hood.id and r.get("revier") != null)
		if rooms.is_empty():
			continue
		var room: Dictionary = R.pick(s, rooms)
		var inside: int = s.monsters.filter(func(m): return m.rank == "normal" and MapGen.room_of(s.map, m.pos) != null and MapGen.room_of(s.map, m.pos).id == room.id).size()
		if inside >= 6:
			continue
		var p := J.pos(R.int_(s, room.x, room.x + room.w - 1), R.int_(s, room.y, room.y + room.h - 1))
		if vis.has(MapGen.idx(s.map, p.x, p.y)) or Ai.occupied(s, p) or MapGen.tile_at(s.map, p.x, p.y) != "floor":
			continue
		var def = Db.monster(room.revier.def)
		var level := Monsters.clamp_level(def, Monsters.respawn_level(s))
		# Elite-Nachzügler erst, wenn der Crawler ein paar Stufen hat
		s.monsters.append(Monsters.spawn_monster(s, def, level, p, hood.id, R.chance(s, 0.05) and int(s.player.level) >= 3))


static func _kick_from_safe_room(s: Dictionary) -> void:
	var start: Dictionary = s.player.pos
	var seen := {MapGen.idx(s.map, start.x, start.y): true}
	var queue := [start]
	while not queue.is_empty():
		var cur: Dictionary = queue.pop_front()
		if not Combat.is_in_safe_room(s, cur) and not Ai.occupied(s, cur):
			s.player.pos = cur
			Log.add(s, "Der Safe Room schließt! Ein unsichtbarer Türsteher wirft dich hinaus. „Letzte Runde war vor einer Stunde.“", "gefahr")
			after_move(s)
			return
		for n in _neighbors(cur):
			var i := MapGen.idx(s.map, n.x, n.y)
			if not MapGen.in_bounds(s.map, n.x, n.y) or seen.has(i):
				continue
			if MapGen.tile_at(s.map, n.x, n.y) == "door":
				s.map.tiles[i] = "dooropen"
			if not MapGen.is_walkable(s.map, n.x, n.y):
				continue
			seen[i] = true
			queue.append(n)


## Sichtfeld, Karte, Räume und Hinweise nach jeder Bewegung aktualisieren.
static func after_move(s: Dictionary) -> void:
	var vis := visible_tiles(s)
	var stairs_new := false
	for i in vis:
		if not s.map.explored[i]:
			s.map.explored[i] = true
			if s.map.tiles[i] == "stairs":
				stairs_new = true
	if stairs_new:
		Log.add(s, "Du entdeckst ein Treppenhaus nach unten!", "system")
		Events.emit(s, {"type": "stairsFound"})
	Traps.detect(s, vis)
	Dungeon.detect(s, vis)
	var room = current_room(s)
	var room_id: int = room.id if room != null else -1
	if room_id != s.currentRoom:
		s.currentRoom = room_id
		if room != null:
			_on_enter_room(s, room)
	# Gold hebt man beim Drüberlaufen von selbst auf
	for e in items_at(s, s.player.pos):
		if e.item.kind == "gold":
			pickup(s, e.item.uid)
	var here := items_at(s, s.player.pos)
	if not here.is_empty():
		Log.add(s, "Hier liegt: %s." % ", ".join(here.map(func(e): return Identify.item_name(s, e.item))), "loot")
	if MapGen.tile_at(s.map, s.player.pos.x, s.player.pos.y) == "stairs":
		Log.add(s, "Du stehst an einem Treppenhaus. Hier kannst du auf die nächste Etage hinabsteigen.", "system")


static func _on_enter_room(s: Dictionary, room: Dictionary) -> void:
	var first: bool = not room.get("visited")
	room.visited = true
	if first:
		Log.add(s, "» %s « %s" % [room.name, room.description], "info")
	else:
		Log.add(s, "Du betrittst: %s." % room.name, "info")
	if room.kind == "guild" and not has_unlock(s, "inventar"):
		_run_tutorial(s)
	if room.kind == "safe":
		Mounts.dismount_for_safe_room(s)
		if has_unlock(s, "handel"):
			Shop.ensure_shop(s, room)
		if not room.get("questOffered") and has_unlock(s, "auftraege") and Quests.quest_of(s, str(room.id)) == null:
			room.questOffered = true
			var keeper: String = String(Shop.ensure_shop(s, room).keeper).split(",")[0]
			var q = Quests.offer_quest(s, {"kind": "laden", "ref": str(room.id), "name": keeper})
			if q != null:
				Log.add(s, "%s hat einen Auftrag für dich: %s" % [keeper, q.text], "dialog")
	if room.kind == "safe" and first:
		if room.get("safeVariant") == "restaurant":
			var hosts: Array = Db.world("RESTAURANT_HOSTS")
			var host: Dictionary = hosts[room.id % hosts.size()]
			Log.add(s, "%s (%s): %s" % [host.name, host.race, host.greeting], "dialog")
		else:
			Log.add(s, "Der Automat piept freundlich. „EIN GRATIS-GEGENSTAND PRO CRAWLER!“", "dialog")
		Log.add(s, "Hier drin kann dir niemand etwas tun. Hier kannst du Lootboxen öffnen und schlafen.", "system")
	if (room.kind == "boss" or room.kind == "arena") and locked_lair(s) != null:
		for y in range(room.y - 1, room.y + room.h + 1):
			for x in range(room.x - 1, room.x + room.w + 1):
				if MapGen.tile_at(s.map, x, y) == "dooropen" and is_lair_door(s, J.pos(x, y)):
					s.map.tiles[MapGen.idx(s.map, x, y)] = "door"
		Log.add(s, "Hinter dir fällt die schwere Tür ins Schloss. Ein Riegel schnappt zu. Jetzt gibt es nur noch einen Weg hinaus.", "gefahr")
		var boss = J.find(s.monsters, func(m): return m.get("homeRoom") == room.id)
		if boss != null and not room.get("versusShown"):
			room.versusShown = true
			s.pendingVersus = boss.uid
	Dungeon.on_enter_room(s, room, first)
	if room.get("antechamberOf") != null and first:
		Log.add(s, "Hinter der rot beschlagenen Tür rumort etwas Großes. Das hier ist der Vorraum einer Boss-Kammer.", "gefahr")
	if (room.kind == "boss" or room.kind == "arena") and first:
		var boss = J.find(s.monsters, func(m): return m.get("homeRoom") == room.id)
		var def = Db.hood_boss(boss.defId) if boss != null else null
		if def != null:
			Log.add(s, def.intro, "gefahr")
			var info := Identify.describe_monster(s, boss)
			if info.insight <= 2:
				Log.add(s, "BOSS: %s (%s). %s" % [def.name, info.level, def.flavor], "gefahr")
			else:
				Log.add(s, "BOSS: %s. %s. Du kannst nicht einschätzen, womit du es zu tun hast." % [info.name, info.level], "gefahr")
	Events.emit(s, {"type": "enterRoom", "room": room, "first": first})


static func _run_tutorial(s: Dictionary) -> void:
	var guide: Dictionary = Db.world("DEFAULT_GUIDE")
	var former: bool = s.guideName != guide.name
	s.pendingDialogs.append({"title": "Gilde der Einweisung", "speaker": s.guideName, "pages": Rules.tutorial_pages(s.guideName, guide.description, former)})
	for u in ["inventar", "stats", "minimap", "skills"]:
		if not s.unlocks.has(u):
			s.unlocks.append(u)
	var p: Dictionary = s.player
	if p.hand != null:
		# Eine Waffe in der Hand wird angelegt, nicht weggepackt
		if p.hand.get("slot") == "waffe" and p.equipment.get("waffe") == null:
			p.equipment.waffe = p.hand
			Log.add(s, "Du legst %s als Waffe an." % Identify.item_name(s, p.hand), "info")
		else:
			Inventory.add_to_inventory(s, p.hand)
		p.hand = null
	Inventory.add_to_inventory(s, Items.create_item(s, "kleiner_heiltrank", 2))
	Magic.learn_spell(s, "heilen", true)
	p.mp = Magic.max_mp(s)
	p.blase = J.nn(p, "blase", 10)
	Log.add(s, "%s schiebt dir zwei kleine Heiltränke über den Tresen. „Geht aufs Haus.“" % s.guideName, "loot")
	if former:
		p.stats.str += 1
		p.stats.ges += 1
		p.stats.kon += 1
		Log.add(s, "%s bringt dir ein paar Tricks aus der eigenen Staffel bei: +1 Stärke, +1 Geschick, +1 Konstitution." % s.guideName, "system")
	Log.add(s, "FREIGESCHALTET: Inventar, Werte, Skills, automatische Kartierung, Mana und der Zauber „Heilen“.", "system")
	Log.toast(s, "Tutorial abgeschlossen", "Inventar, Werte, Skills und Karte freigeschaltet!", "level")
	Events.emit(s, {"type": "tutorialDone"})


# ================================================================ Gegenstände

## Die Gilde der Einweisung (die nächste Gilde zum Start) ist von Anfang an
## auf der Karte: Raum samt Wänden aufgedeckt und markiert.
static func _mark_tutorial_guild(s: Dictionary) -> void:
	var m: Dictionary = s.map
	var best = null
	for r in m.rooms:
		if r.kind == "guild" and (best == null or J.cheb(MapGen.center(r), s.player.pos) < J.cheb(MapGen.center(best), s.player.pos)):
			best = r
	if best == null:
		return
	best.marked = true
	for y in range(best.y - 1, best.y + best.h + 1):
		for x in range(best.x - 1, best.x + best.w + 1):
			if MapGen.in_bounds(m, x, y):
				m.explored[MapGen.idx(m, x, y)] = true


static func pickup(s: Dictionary, uid: Variant = null) -> Dictionary:
	var p: Dictionary = s.player
	var here := items_at(s, p.pos).filter(func(e): return uid == null or e.item.uid == uid)
	if here.is_empty():
		return _fail("Hier liegt nichts.")
	for entry in here:
		var it: Dictionary = entry.item
		if it.kind == "karte":
			s.items = J.without(s.items, entry)
			_reveal_hood(s, int(J.nn(it, "hood", 0)))
			continue
		if not has_unlock(s, "inventar") and it.kind != "gold":
			# Ohne Inventar nur eine Hand frei: die Waffe nicht für Kleinkram hergeben
			if p.hand != null and p.hand.get("slot") == "waffe" and it.get("slot") != "waffe":
				return _fail("Du hältst schon %s. Ohne Rucksack hast du keine Hand frei – finde erst die Gilde." % Identify.item_name(s, p.hand))
			if p.hand != null:
				s.items.append({"pos": J.pcopy(p.pos), "item": p.hand})
				Log.add(s, "Du legst %s ab." % p.hand.name, "info")
			p.hand = it
			s.items = J.without(s.items, entry)
			Log.add(s, "Du nimmst %s in die Hand." % Identify.item_name(s, it), "loot")
			s.counters.itemsPicked += 1
			Events.emit(s, {"type": "pickup", "item": it})
			break
		s.items = J.without(s.items, entry)
		Inventory.give_item(s, it)
		s.counters.itemsPicked += 1
		var menge := int(J.nn(it, "menge", 0))
		Log.add(s, "Aufgehoben: %s%s." % [Identify.item_name(s, it), (" ×%d" % menge) if menge > 1 and it.kind != "gold" else ""], "loot")
		Events.emit(s, {"type": "pickup", "item": it})
	return _ok()


static func _reveal_hood(s: Dictionary, hood: int) -> void:
	var m: Dictionary = s.map
	for y in MapGen.MAP_H:
		for x in MapGen.MAP_W:
			if MapGen.hood_of(m, J.pos(x, y)) != hood:
				continue
			var near := J.some(_neighbors(J.pos(x, y)), func(n): return MapGen.is_walkable(m, n.x, n.y)) or MapGen.is_walkable(m, x, y)
			if near:
				m.explored[MapGen.idx(m, x, y)] = true
	m.hoods[hood].mapFound = true
	Log.add(s, "Die Gebietskarte zeigt dir den kompletten Grundriss: %s." % m.hoods[hood].name, "system")
	Events.emit(s, {"type": "mapPicked", "hood": hood})


static func _find_owned(s: Dictionary, uid: String) -> Variant:
	var hand = s.player.hand
	if hand != null and hand.uid == uid:
		return {"item": hand, "from": "hand"}
	var it = J.find(s.player.inventory, func(i): return i.uid == uid)
	return {"item": it, "from": "inv"} if it != null else null


static func _remove_one(s: Dictionary, uid: String) -> void:
	var p: Dictionary = s.player
	var owned = _find_owned(s, uid)
	if owned == null:
		return
	var it: Dictionary = owned.item
	if int(J.nn(it, "menge", 1)) > 1:
		it.menge = int(J.nn(it, "menge", 1)) - 1
		return
	if owned.from == "hand":
		p.hand = null
	else:
		p.inventory = p.inventory.filter(func(i): return i.uid != uid)


static func _apply_effect(s: Dictionary, e: Dictionary, is_food: bool) -> void:
	var p: Dictionary = s.player
	if e.get("heal") or e.get("healPct"):
		var boost := (1 + 0.15 * Player.skill_level(s, "kochen")) if is_food else (1 + 0.08 * Player.skill_level(s, "erste_hilfe"))
		if is_food and Abilities.has_special(s, "aasfresser"):
			boost *= 2
		if not is_food and Abilities.has_special(s, "trankkunde"):
			boost *= 1.5
		if not is_food:
			Skills.train_skill(s, "heal", 1)
		var amount := J.rnd((J.num(e, "heal") + (J.num(e, "healPct") / 100.0) * Player.max_hp(s)) * boost)
		p.hp = mini(Player.max_hp(s), p.hp + amount)
		Fx.float_text(s, p.pos, "+%d" % amount, Fx.COLORS.heilung)
		Log.add(s, "+%d HP." % amount, "info")
	if e.get("mana") or e.get("manaPct"):
		var amount := J.rnd(J.num(e, "mana") + (J.num(e, "manaPct") / 100.0) * Magic.max_mp(s))
		p.mp = mini(Magic.max_mp(s), int(J.num(p, "mp")) + amount)
		Log.add(s, "+%d Mana." % amount, "info")
	if e.get("blase"):
		Bladder.add(s, e.blase)
	if e.get("ausdauer"):
		p.ausdauer = mini(Player.max_ausdauer(s), p.ausdauer + e.ausdauer)
	if e.get("cure"):
		Abilities.cure(s)
	if (e.get("bandage") or J.num(e, "healPct") >= 50) and Conditions.clear_player(s, "blutung"):
		Log.add(s, "Die Blutung hört auf.", "info")
	for id in J.arr(e, "clear"):
		if Conditions.clear_player(s, id):
			Log.add(s, "Das hilft: %s ist vorbei." % Conditions.CONDITIONS[id].name, "info")
	if e.get("buff") != null:
		p.buffs = p.buffs.filter(func(b): return b.name != e.buff.name)
		p.buffs.append(e.buff.duplicate(true))
		Log.add(s, "Effekt: %s (%s Züge)." % [e.buff.name, J.s(e.buff.turns)], "info")


static func use_item(s: Dictionary, uid: String) -> Dictionary:
	Rounds.before_action(s)
	if s.status != "playing":
		return _fail("Das Spiel ist vorbei.")
	var owned = _find_owned(s, uid)
	if owned == null:
		return _fail("Nicht gefunden.")
	var it: Dictionary = owned.item
	if it.kind == "buch":
		if not has_unlock(s, "inventar"):
			return _fail("Ohne Tutorial verstehst du die Schrift in diesem Buch nicht. Finde die Gilde.")
		var res := Magic.read_tome(s, it)
		if not res.ok:
			return _fail(res.get("message", "Geht nicht."))
		_remove_one(s, uid)
		end_turn(s)
		return _ok()
	if it.kind != "verbrauch":
		return _fail("Das kann man nicht benutzen.")
	if Mounts.is_mount_item(it):
		var res := Mounts.gain_mount(s, it)
		if not res.ok:
			return _fail(res.get("message", "Geht nicht."))
		_remove_one(s, uid)
		end_turn(s)
		return _ok()
	var special = Extras.use_special(s, it)
	if special != null:
		if not special.ok:
			return _fail(special.get("message", "Geht nicht."))
		_remove_one(s, uid)
		end_turn(s)
		return _ok()
	if it.baseId == "leckerli" and Extras.try_tame(s).handled:
		_remove_one(s, uid)
		end_turn(s)
		return _ok()
	var is_potion := String(it.baseId).contains("trank")
	if is_potion and J.num(s.player, "potionCooldown") > 0:
		return _fail("Dein Körper verträgt gerade keinen weiteren Trank. Noch %s Züge." % J.s(s.player.potionCooldown))
	if is_potion:
		s.player.potionCooldown = 10 if Abilities.has_special(s, "trankkunde") else 20
	if it.baseId == "leckerli":
		var pet = s.player.pet
		if pet != null:
			Ai.pet_level_up(s)
			pet.alive = true
			Log.add(s, "%s verschlingt das Leckerli und glüht kurz auf." % pet.name, "system")
		else:
			Log.add(s, "Du isst das Haustier-Leckerli. Es schmeckt nach Fisch und Reue. Die Zuschauer sind verstört.", "info")
	else:
		Log.add(s, "Du benutzt: %s." % Identify.item_name(s, it), "info")
		var potion: bool = String(it.baseId).contains("trank") or it.baseId == "gegengift"
		var hp_before: int = s.player.hp
		if potion:
			s.counters.potionsDrunk += 1
		var food: bool = Db.t("items", "FOOD_IDS").has(it.baseId)
		_apply_effect(s, it.get("effekt") if it.get("effekt") != null else {}, food)
		if food:
			Events.emit(s, {"type": "eat", "item": it})
		if potion:
			Events.emit(s, {"type": "potion", "item": it, "hpBefore": hp_before})
	_remove_one(s, uid)
	end_turn(s)
	return _ok()


static func _slot_for(s: Dictionary, it: Dictionary) -> Variant:
	var eq: Dictionary = s.player.equipment
	if not it.get("slot"):
		return null
	if it.slot == "ring" or it.slot == "fussring":
		# Erst ein freier Platz, sonst wird der schwächere der beiden ersetzt
		var a: String = it.slot + "1"
		var b: String = it.slot + "2"
		if eq.get(a) == null:
			return a
		if eq.get(b) == null:
			return b
		return b if item_rank(eq[b]) < item_rank(eq[a]) else a
	return it.slot


## Grobe Güte eines Gegenstands: Seltenheit zuerst, dann Wert.
static func item_rank(it: Dictionary) -> float:
	return Db.t("items", "RARITY_ORDER").find(it.get("rarity", "gewoehnlich")) * 1000.0 + float(J.nn(it, "wert", 0))


static func equip(s: Dictionary, uid: String) -> Dictionary:
	if not has_unlock(s, "inventar"):
		return _fail("Ohne Inventar kannst du nichts umziehen. Finde die Gilde.")
	var p: Dictionary = s.player
	var it = J.find(p.inventory, func(i): return i.uid == uid)
	if it == null or it.kind != "ausruestung":
		return _fail("Das kann man nicht anlegen.")
	var slot = _slot_for(s, it)
	if slot == null:
		return _fail("Kein passender Platz.")
	var old = p.equipment.get(slot)
	p.inventory = p.inventory.filter(func(i): return i.uid != uid)
	if old != null:
		p.inventory.append(old)
	p.equipment[slot] = it
	Log.add(s, "Angelegt: %s." % Identify.item_name(s, it), "info")
	Events.emit(s, {"type": "equip", "item": it})
	Player.clamp_vitals(s)
	end_turn(s)
	return _ok()


## Ausrüstung, die am Boden liegt, direkt anziehen. Was vorher an dem Platz
## war, bleibt dafür liegen. Geht auch ohne Inventar (nur Waffen nicht: die
## nimmt man ohne Rucksack in die Hand).
static func wear_from_ground(s: Dictionary, uid: String) -> Dictionary:
	var p: Dictionary = s.player
	var entry = J.find(items_at(s, p.pos), func(e): return e.item.uid == uid)
	if entry == null:
		return _fail("Das liegt nicht hier.")
	var it: Dictionary = entry.item
	if it.kind != "ausruestung":
		return _fail("Das kann man nicht anziehen.")
	if it.get("slot") == "waffe" and not has_unlock(s, "inventar"):
		return _fail("Ohne Inventar nimmst du Waffen in die Hand: aufheben.")
	var slot = _slot_for(s, it)
	if slot == null:
		return _fail("Kein passender Platz.")
	s.items = J.without(s.items, entry)
	var old = p.equipment.get(slot)
	if old != null:
		s.items.append({"pos": J.pcopy(p.pos), "item": old})
		Log.add(s, "Du legst %s ab." % Identify.item_name(s, old), "info")
	p.equipment[slot] = it
	s.counters.itemsPicked += 1
	Log.add(s, "Angezogen: %s." % Identify.item_name(s, it), "loot")
	Events.emit(s, {"type": "pickup", "item": it})
	Events.emit(s, {"type": "equip", "item": it})
	Player.clamp_vitals(s)
	end_turn(s)
	return _ok()


static func unequip(s: Dictionary, slot: String) -> Dictionary:
	if not has_unlock(s, "inventar"):
		return _fail("Ohne Inventar wohin damit? Finde die Gilde.")
	var p: Dictionary = s.player
	var it = p.equipment.get(slot)
	if it == null:
		return _fail("Da ist nichts.")
	p.equipment.erase(slot)
	p.inventory.append(it)
	Player.clamp_vitals(s)
	Log.add(s, "Abgelegt: %s." % Identify.item_name(s, it), "info")
	return _ok()


static func drop_item(s: Dictionary, uid: String) -> Dictionary:
	var owned = _find_owned(s, uid)
	if owned == null:
		return _fail("Nicht gefunden.")
	var p: Dictionary = s.player
	if owned.from == "hand":
		p.hand = null
	else:
		p.inventory = p.inventory.filter(func(i): return i.uid != uid)
	s.items.append({"pos": J.pcopy(p.pos), "item": owned.item})
	Log.add(s, "Du lässt %s fallen." % Identify.item_name(s, owned.item), "info")
	return _ok()


# ================================================================ Safe Room

static func open_box(s: Dictionary, uid: String) -> Dictionary:
	var p: Dictionary = s.player
	if not Combat.can_open_boxes(s, p.pos):
		return _fail("Lootboxen kannst du nur in einem Safe Room oder einer Gilde öffnen.")
	if not has_unlock(s, "inventar"):
		return _fail("Du brauchst erst ein Inventar. Schließ das Tutorial in der Gilde ab.")
	var box = J.find(p.boxes, func(b): return b.uid == uid)
	if box == null or box.get("box") == null:
		return _fail("Box nicht gefunden.")
	p.boxes = p.boxes.filter(func(b): return b.uid != uid)
	var contents := Items.roll_box_contents(s, box.box.type, box.box.tier, int(J.nn(box.box, "floor", s.floor)), bool(J.nn(box.box, "special", false)))
	for it in contents:
		Inventory.give_item(s, it)
	s.counters.boxesOpened += 1
	var names := contents.map(func(c):
		var menge := int(J.nn(c, "menge", 0))
		return Identify.item_name(s, c) + ((" ×%d" % menge) if menge > 1 and c.kind != "gold" else ""))
	Log.add(s, "Du öffnest: %s. Inhalt: %s." % [box.name, ", ".join(names)], "loot")
	Events.emit(s, {"type": "boxOpened", "item": box, "contents": contents})
	return {"ok": true, "contents": contents}


static func take_freebie(s: Dictionary) -> Dictionary:
	var room = current_room(s)
	if room == null or room.kind != "safe":
		return _fail("Hier gibt es keinen Gratis-Automaten.")
	if room.get("freebieTaken"):
		return _fail("„ERROR: Du hattest deinen Gratis-Gegenstand schon, Crawler.“")
	room.freebieTaken = true
	var roll := R.next(s)
	var item: Dictionary
	var note := ""
	if roll < 0.45:
		item = Items.generate_equipment(s, R.weighted(s, [["ungewoehnlich", 60], ["selten", 35], ["episch", 5]]))
	elif roll < 0.68:
		item = Items.create_item(s, R.pick(s, ["heiltrank", "kleiner_heiltrank", "kleiner_manatrank", "gegengift", "verband"]), 2)
	elif roll < 0.84:
		item = Items.create_item(s, R.pick(s, ["brandflasche", "rattengift", "staubbeutel", "nagelbombe"]), 2)
	else:
		item = Items.create_item(s, R.pick(s, FREEBIE_JOKES.filter(func(x): return Items.base_exists(x))))
		note = " Die Systemstimme kichert."
	Inventory.give_item(s, item)
	var menge := int(J.nn(item, "menge", 0))
	Log.add(s, "Der Automat rattert und spuckt aus: %s%s.%s" % [Identify.item_name(s, item), (" ×%d" % menge) if menge > 1 else "", note], "loot")
	return {"ok": true, "item": item}


## In ein Möbelstück hineinlaufen heißt: benutzen oder ansprechen.
static func use_furniture(s: Dictionary, f: Dictionary) -> Dictionary:
	var room = current_room(s)
	match f.kind:
		"automat":
			var res := take_freebie(s)
			if not res.ok or res.get("item") == null:
				return res
			s.pendingReveal = {"title": "Gratis-Automat", "items": [res.item]}
			end_turn(s)
			return _ok()
		"bett":
			return sleep(s)
		"toilette":
			return toilet(s)
		"wirt":
			var hosts: Array = Db.world("RESTAURANT_HOSTS")
			var host: Dictionary = hosts[(room.id if room != null else 0) % hosts.size()]
			Log.add(s, "%s: „Was darf’s sein? Essen gibt’s an der Theke, schlafen kannst du oben.“" % host.name, "dialog")
			return _ok()
		"bildschirm":
			return watch_screen(s)
		"haendler":
			if room != null:
				var shop := Shop.ensure_shop(s, room)
				Log.add(s, "%s: „Schau dich um. Anfassen kostet nichts. Kaufen schon.“" % String(shop.keeper).split(",")[0], "dialog")
			return _ok()
		"schrein", "schrein_leer":
			var res := Dungeon.pray(s, f)
			if not res.ok:
				return _fail(res.message)
			end_turn(s)
			return _ok()
		"nest":
			Log.add(s, "Das Nest stinkt nach nassem Fell. Solange hier noch jemand wohnt, lässt sich darin nichts finden.", "info")
			return _ok()
		"nest_leer":
			Log.add(s, "Ein leeres, kaltes Nest. Hier ist nichts mehr.", "info")
			return _ok()
	return _ok()


static func buy_meal(s: Dictionary, menu_id: String) -> Dictionary:
	var room = current_room(s)
	if room == null or room.kind != "safe" or room.get("safeVariant") != "restaurant":
		return _fail("Hier gibt es kein Restaurant.")
	var meal = J.find(Db.world("RESTAURANT_MENU"), func(m): return m.id == menu_id)
	if meal == null:
		return _fail("Das steht nicht auf der Karte.")
	if s.player.gold < meal.price:
		return _fail("Nicht genug Gold. „Anschreiben gibt’s nicht, Schätzchen.“")
	s.player.gold -= meal.price
	Log.add(s, "Du bestellst %s. %s" % [meal.name, meal.flavor], "dialog")
	s.counters.mealsEaten += 1
	_apply_effect(s, meal.effekt, true)
	var pseudo := {"uid": "meal%d" % s.turn, "baseId": meal.id, "name": meal.name, "kind": "verbrauch", "rarity": "gewoehnlich", "flavor": meal.flavor, "wert": meal.price}
	Events.emit(s, {"type": "eat", "item": pseudo})
	end_turn(s)
	return _ok()


static func sleep(s: Dictionary) -> Dictionary:
	if not Combat.is_in_safe_room(s, s.player.pos):
		return _fail("Schlafen kannst du nur in einem Safe Room.")
	var duration := mini(160, time_left(s) - 21)
	if duration < 10:
		return _fail("Keine Zeit mehr zum Schlafen – die Etage stürzt bald ein!")
	var p: Dictionary = s.player
	var before := time_left(s)
	s.turn += duration
	var heal_pct := 0.6 + 0.1 * Player.skill_level(s, "erste_hilfe")
	p.hp = mini(Player.max_hp(s), p.hp + J.rnd(Player.max_hp(s) * heal_pct))
	p.ausdauer = Player.max_ausdauer(s)
	if not J.arr(p, "spells").is_empty():
		p.mp = Magic.max_mp(s)
	if has_unlock(s, "inventar"):
		p.blase = 25
	if p.pet != null:
		if not p.pet.alive:
			Log.add(s, "%s taucht in einem Lichtblitz wieder auf und rollt sich neben dir zusammen." % p.pet.name, "info")
		p.pet.alive = true
		p.pet.hp = p.pet.maxHp
		var spot = null
		for q in _neighbors(p.pos):
			if MapGen.is_walkable(s.map, q.x, q.y) and not Ai.occupied(s, q):
				spot = q
				break
		p.pet.pos = J.pcopy(spot if spot != null else p.pos)
	Mounts.rest_mount(s)
	for m in s.monsters:
		if m.get("homeRoom") == null:
			m.aware = false
	Log.add(s, "Du schläfst %d Stunden. Du fühlst dich erholt (%d %% Heilung)." % [J.rnd((duration * 3) / 60.0), J.rnd(heal_pct * 100)], "info")
	s.counters.sleeps += 1
	Abilities.cure(s)
	Events.emit(s, {"type": "sleep"})
	_tick_time(s, duration, before)
	return _ok()


# ================================================================ Magie, Toilette, Fallen, Handwerk

static func cast(s: Dictionary, spell_id: String, opts: Dictionary = {}) -> Dictionary:
	if s.status != "playing":
		return _fail("Das Spiel ist vorbei.")
	if s.pendingSelection:
		return _fail(SELECT_FIRST)
	Rounds.before_action(s)
	if s.status != "playing":
		return _fail("Das Spiel ist vorbei.")
	var res := Magic.cast_spell(s, spell_id, opts)
	if not res.ok:
		return _fail(res.get("message", "Das geht nicht."))
	if spell_id == "pfuetzensprung":
		after_move(s)
	end_turn(s)
	return _ok()


static func toilet(s: Dictionary) -> Dictionary:
	var room = current_room(s)
	var near: bool = room != null and J.some(J.arr(room, "furniture"), func(f): return f.kind == "toilette" and J.cheb(f.pos, s.player.pos) <= 1)
	var legacy_safe: bool = room != null and room.kind == "safe" and J.arr(room, "furniture").is_empty()
	if not near and not legacy_safe:
		return _fail("Hier gibt es keine Toilette. Stell dich neben eine – in Safe Rooms und in manchen Räumen gibt es welche. Und die Regel gilt.")
	var res := Bladder.use_toilet(s)
	if not res.ok:
		return _fail(res.get("message", "Geht nicht."))
	end_turn(s)
	return _ok()


static func disarm_trap(s: Dictionary, trap_uid: String) -> Dictionary:
	if s.status != "playing":
		return _fail("Das Spiel ist vorbei.")
	var res := Traps.disarm(s, trap_uid)
	if not res.ok:
		return _fail(res.get("message", "Geht nicht."))
	end_turn(s)
	return _ok()


static func place_trap(s: Dictionary, uid: String) -> Dictionary:
	if s.status != "playing":
		return _fail("Das Spiel ist vorbei.")
	var owned = _find_owned(s, uid)
	if owned == null:
		return _fail("Nicht gefunden.")
	var res := Traps.place_own_trap(s, owned.item)
	if not res.ok:
		return _fail(res.get("message", "Geht nicht."))
	_remove_one(s, uid)
	end_turn(s)
	return _ok()


static func craft_item(s: Dictionary, recipe_id: String) -> Dictionary:
	if s.status != "playing":
		return _fail("Das Spiel ist vorbei.")
	if not has_unlock(s, "inventar"):
		return _fail("Ohne Inventar kannst du nichts basteln. Finde die Gilde.")
	var res := Crafting.craft(s, recipe_id)
	if not res.ok:
		return _fail(res.get("message", "Geht nicht."))
	end_turn(s)
	return _ok()


static func choose_throwable(s: Dictionary, base_id: Variant) -> Dictionary:
	if base_id == null:
		s.player.erase("wurfWahl")
	else:
		s.player.wurfWahl = base_id
	return _ok()


# ================================================================ Andere Crawler

static func _crawler_action(s: Dictionary, fn: Callable, takes_turn: bool = true) -> Dictionary:
	if s.status != "playing":
		return _fail("Das Spiel ist vorbei.")
	if s.pendingSelection:
		return _fail(SELECT_FIRST)
	var res: Dictionary = fn.call()
	if not res.ok:
		return _fail(res.get("message", "Geht nicht."))
	if takes_turn:
		end_turn(s)
	return _ok()


static func talk_crawler(s: Dictionary, uid: String) -> Dictionary:
	return _crawler_action(s, func(): return Crawlers.talk_to(s, uid))


static func invite_crawler(s: Dictionary, uid: String) -> Dictionary:
	return _crawler_action(s, func(): return Crawlers.invite(s, uid))


static func ask_crawler_tip(s: Dictionary, uid: String) -> Dictionary:
	return _crawler_action(s, func(): return Crawlers.ask_tip(s, uid))


static func dismiss_crawler(s: Dictionary, uid: String) -> Dictionary:
	return _crawler_action(s, func(): return Crawlers.dismiss(s, uid), false)


static func heal_crawler(s: Dictionary, uid: String, item_uid: String) -> Dictionary:
	var owned = _find_owned(s, item_uid)
	if owned == null:
		return _fail("Nicht gefunden.")
	return _crawler_action(s, func():
		var res := Crawlers.give_healing(s, uid, owned.item)
		if res.ok:
			_remove_one(s, item_uid)
		return res)


# ================================================================ Sponsoren, Haustier, Reittier, Aufträge

static func _wrap(res: Dictionary) -> Dictionary:
	return _ok() if res.ok else _fail(res.get("message", "Geht nicht."))


static func accept_sponsor_offer(s: Dictionary, id: String) -> Dictionary:
	return _wrap(Sponsors.accept(s, id))


static func decline_sponsor_offer(s: Dictionary, id: String) -> Dictionary:
	return _wrap(Sponsors.decline(s, id))


static func evolve_pet_to(s: Dictionary, form_id: String) -> Dictionary:
	return _wrap(PetEvo.evolve(s, form_id))


static func pet_gear_on(s: Dictionary, uid: String) -> Dictionary:
	return _wrap(PetEvo.equip_gear(s, uid))


static func pet_gear_off(s: Dictionary) -> Dictionary:
	return _wrap(PetEvo.remove_gear(s))


static func ride_toggle(s: Dictionary) -> Dictionary:
	if s.status != "playing":
		return _fail("Das Spiel ist vorbei.")
	return _wrap(Mounts.toggle_ride(s))


static func refuel_mount(s: Dictionary) -> Dictionary:
	var res := Mounts.refuel(s)
	if not res.ok:
		return _fail(res.get("message", "Geht nicht."))
	end_turn(s)
	return _ok()


static func accept_quest_offer(s: Dictionary, id: String) -> Dictionary:
	return _wrap(Quests.accept(s, id))


static func decline_quest_offer(s: Dictionary, id: String) -> Dictionary:
	return _wrap(Quests.decline(s, id))


static func turn_in_quest(s: Dictionary, id: String) -> Dictionary:
	return _wrap(Quests.turn_in(s, id))


static func answer_talk_show(s: Dictionary, index: int) -> Dictionary:
	return TalkShow.answer(s, index)


# ================================================================ Laden

# ================================================================ Show

## Der Bildschirm im Safe Room: läuft die Sendung, schaut man sie an.
static func watch_screen(s: Dictionary) -> Dictionary:
	if not Combat.is_in_safe_room(s, s.player.pos):
		return _fail("Bildschirme gibt es nur in Safe Rooms.")
	if not Highlights.on_air(s):
		Log.add(s, Highlights.screen_text(s), "info")
		return _ok()
	s.pendingDialogs.append(Highlights.watch(s))
	return _ok()


static func accept_invitation(s: Dictionary) -> Dictionary:
	return _wrap(Invitations.accept(s))


static func decline_invitation(s: Dictionary) -> Dictionary:
	return _wrap(Invitations.decline(s))


## Raum mit Laden: Safe Room oder Wanderhändler.
static func _safe_room(s: Dictionary) -> Variant:
	var room = current_room(s)
	return room if room != null and (room.kind == "safe" or room.get("feature") == "markt") else null


static func buy_offer(s: Dictionary, index: int) -> Dictionary:
	var room = _safe_room(s)
	if room == null or not has_unlock(s, "handel"):
		return _fail("Hier gibt es keinen Laden.")
	return _wrap(Shop.buy(s, room, index))


static func haggle_offer(s: Dictionary, index: int) -> Dictionary:
	var room = _safe_room(s)
	if room == null or not has_unlock(s, "handel"):
		return _fail("Hier gibt es keinen Laden.")
	return _wrap(Shop.haggle(s, room, index))


static func sell_item(s: Dictionary, uid: String) -> Dictionary:
	if _safe_room(s) == null or not has_unlock(s, "handel"):
		return _fail("Verkaufen kannst du nur bei einem Händler (ab Etage %d)." % unlock_floor("handel"))
	return _wrap(Shop.sell(s, uid))


# ================================================================ Werte

static func allocate_stat(s: Dictionary, key: String) -> Dictionary:
	if not has_unlock(s, "stats"):
		return _fail("Werte sind noch nicht freigeschaltet.")
	if s.player.get("klass") == null:
		return _fail("Punkte frei verteilen kannst du erst nach der Klassen- und Rassenwahl auf Etage 3. Bis dahin verteilen sie sich von selbst.")
	if s.player.statPoints <= 0:
		return _fail("Keine Punkte übrig.")
	s.player.statPoints -= 1
	s.player.stats[key] += 1
	return _ok()


# ================================================================ Etagenwechsel

static func on_stairs(s: Dictionary) -> bool:
	return MapGen.tile_at(s.map, s.player.pos.x, s.player.pos.y) == "stairs"


static func descend(s: Dictionary, meta: Dictionary) -> Dictionary:
	if not on_stairs(s):
		return _fail("Hier ist keine Treppe.")
	Events.emit(s, {"type": "descend", "floor": s.floor + 1})
	if s.floor + 1 > int(Db.world("LAST_PLAYABLE_FLOOR")):
		s.status = "victory"
		Log.add(s, "Du steigst hinab… und landest vor einer Tür mit einem Schild: „Etage %d – Baustelle. Bitte später wiederkommen.“" % (s.floor + 1), "system")
		return _ok()
	var next: int = s.floor + 1
	Crawlers.population_on_descend(s)
	Quests.on_descend(s)
	var recap := TalkShow.floor_recap(s)
	var with_show := has_unlock(s, "zuschauer")
	_enter_floor(s, next, meta)
	s.pendingDialogs.append(recap)
	# Zwischen den Etagen lädt die Show nur ein, wer bekannt genug ist
	var show = TalkShow.start(s) if with_show else null
	if show != null:
		s.pendingDialogs.append(show)
	Crawlers.announce_population(s, true)
	var def := Db.floor_def0(next)
	Log.add(s, "Etage %d: %s." % [next, def.name], "system")
	var pages := [def.intro]
	if next >= unlock_floor("zuschauer") and not has_unlock(s, "zuschauer"):
		s.unlocks.append("zuschauer")
		pages.append("NEU: DAS PUBLIKUM! Ab sofort schaut dir die ganze Galaxis live zu. Spektakuläre Aktionen – Stampfer, Sprungtritte, Bosskills, knappe Rettungen, Achievements – bringen Hype und Follower.")
		pages.append("Mehr Follower bedeuten Fan-Boxen (bei 100, 250, 500, 1000 … Followern) und ab und zu Geschenke aus dem Publikum. Charisma hilft. Langeweile nicht. Die Zuschauer schalten nicht gerne bei jemandem ein, der nur wartet.")
		Log.add(s, "FREIGESCHALTET: Zuschauer, Follower und Fan-Boxen.", "system")
	if next >= unlock_floor("klasse") and not has_unlock(s, "klasse"):
		s.pendingSelection = true
		pages.append("Kaum hast du die Treppe verlassen, zieht dich ein Lichtstrahl zurück in die Gilde der Einweisung. %s wartet schon. „Es ist so weit. Etage 3. Zeit, dich zu entscheiden, was du sein willst.“" % s.guideName)
		pages.append("„Du darfst deine RASSE wählen – oder Mensch bleiben. Einige Rassen hast du dir durch dein Verhalten erst freigeschaltet. Und die Systemstimme hat dir eine persönliche KLASSENLISTE erstellt – basierend darauf, wie du bisher gekämpft hast. Die drei Empfehlungen oben passen am besten zu dir.“")
		pages.append("„Jede Klasse bringt eine besondere Fähigkeit mit. Überleg gut. Das kannst du nicht rückgängig machen.“")
	if not unlock_floor_systems(s, next).is_empty():
		pages.append("NEU: HANDEL UND AUFTRÄGE! Ab dieser Etage haben die Läden in den Safe Rooms geöffnet, und in der Siedlung stehen Marktstände. Händler kaufen deine Beute und lassen mit sich feilschen. Ladenbesitzer und andere Crawler haben jetzt Aufträge für dich – mit Belohnung.")
		Log.add(s, "FREIGESCHALTET: Handel und Aufträge.", "system")
	s.pendingDialogs.append({"title": "Etage %d: %s" % [next, def.name], "speaker": Db.world("SYSTEM_NAME"), "pages": pages})
	return _ok()


static func can_sign_contract(s: Dictionary) -> bool:
	return s.floor >= CONTRACT_MIN_FLOOR and not s.contractSigned


static func sign_contract(s: Dictionary) -> Dictionary:
	if not can_sign_contract(s):
		return _fail("Verträge gibt es erst ab Etage %d." % CONTRACT_MIN_FLOOR)
	s.contractSigned = true
	Log.add(s, "Du unterschreibst den Vertrag. Die Tinte leuchtet kurz rot auf. Das ist bestimmt normal.", "system")
	return _ok()


static func drain_toasts(s: Dictionary) -> Array:
	var t: Array = s.toasts
	s.toasts = []
	return t
