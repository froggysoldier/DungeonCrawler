class_name Crawlers
extends RefCounted
## Andere Crawler, Party und Bevölkerung.

const DIRS := Pathfinding.DIRS


static func _c(name: String) -> Variant:
	return Db.t("crawlers", name)


static func crawlers(s: Dictionary) -> Array:
	if s.get("crawlers") == null:
		s.crawlers = []
	return s.crawlers


static func party(s: Dictionary) -> Array:
	return crawlers(s).filter(func(c): return c.alive and c.party)


static func crawler_at(s: Dictionary, p: Dictionary) -> Variant:
	for c in crawlers(s):
		if c.alive and c.pos.x == p.x and c.pos.y == p.y:
			return c
	return null


static func _blocked(s: Dictionary, p: Dictionary, self_c: Variant = null) -> bool:
	if not MapGen.is_walkable(s.map, p.x, p.y):
		return true
	if s.player.pos.x == p.x and s.player.pos.y == p.y:
		return true
	var pet = s.player.pet
	if pet != null and pet.alive and pet.pos.x == p.x and pet.pos.y == p.y:
		return true
	if J.some(s.monsters, func(m): return m.pos.x == p.x and m.pos.y == p.y):
		return true
	return J.some(crawlers(s), func(c): return not is_same(c, self_c) and c.alive and c.pos.x == p.x and c.pos.y == p.y)


# ================================================================ Bevölkerung

static func population(s: Dictionary) -> Dictionary:
	if s.get("population") == null:
		var start: int = _c("START_POPULATION")
		s.population = {"alive": start, "floorStart": start, "lastAnnounce": 0}
	return s.population


static func _update_population(s: Dictionary) -> void:
	var pop := population(s)
	var def := Db.floor_def0(s.floor)
	var losses: Array = _c("FLOOR_LOSS")
	var loss: float = losses[mini(s.floor, losses.size() - 1)]
	var progress := minf(1, (s.turn - s.floorStartTurn) / float(def.duration))
	var target := J.rnd(pop.floorStart * (1 - loss * sqrt(progress)))
	if target < pop.alive:
		pop.alive = target


static func announce_population(s: Dictionary, force: bool = false) -> void:
	var pop := population(s)
	if not force and s.turn - pop.lastAnnounce < int(_c("ANNOUNCE_EVERY")):
		return
	pop.lastAnnounce = s.turn
	var start: int = _c("START_POPULATION")
	var lost: int = start - pop.alive
	var pct := J.rnd((float(lost) / start) * 100)
	Log.add(s, "SYSTEMMELDUNG: Es verbleiben %s Crawler. %sWeitermachen!" % [J.de(pop.alive), ("%d %% haben es nicht geschafft. " % pct) if pct > 0 else ""], "system")


static func population_on_descend(s: Dictionary) -> void:
	var pop := population(s)
	var losses: Array = _c("FLOOR_LOSS")
	var loss: float = losses[mini(s.floor, losses.size() - 1)]
	pop.alive = mini(pop.alive, J.rnd(pop.floorStart * (1 - loss) * (1 - float(_c("COLLAPSE_LOSS")))))
	pop.floorStart = pop.alive


# ================================================================ Erzeugen

static func make_crawler(s: Dictionary, pos: Dictionary, personality: Variant = null) -> Dictionary:
	var def := Db.floor_def0(s.floor)
	var pers_defs: Dictionary = _c("PERSONALITIES")
	var pers: String
	if personality != null:
		pers = personality
	else:
		var entries := []
		for k in pers_defs:
			entries.append([k, pers_defs[k].weight])
		pers = R.weighted(s, entries)
	var level := maxi(1, R.int_(s, def.mobLevel[0], def.mobLevel[1] + 1) - 1)
	var max_hp := 18 + level * 6
	s.uidCounter += 1
	return {
		"uid": "c%d" % s.uidCounter,
		"name": "%s %s" % [R.pick(s, _c("FIRST_NAMES")), R.pick(s, _c("LAST_NAMES"))],
		"background": R.pick(s, _c("BACKGROUNDS")),
		"personality": pers,
		"level": level,
		"xp": 0,
		"hp": maxi(3, J.rnd(max_hp * 0.2)) if pers == "verzweifelt" else max_hp,
		"maxHp": max_hp,
		"dmg": [2 + level, 4 + J.rnd(level * 1.5)],
		"pos": J.pcopy(pos),
		"alive": true,
		"met": false,
		"party": false,
		"trust": 40 if pers == "freundlich" else 10,
		"kills": 0,
	}


static func populate(s: Dictionary, start: Dictionary) -> void:
	var keep := party(s)
	for c in keep:
		var spot = null
		for d in DIRS:
			var q := J.pos(start.x + d[0], start.y + d[1])
			if not _blocked(s, q, c):
				spot = q
				break
		c.pos = spot if spot != null else J.pcopy(start)
	s.crawlers = keep.duplicate()
	var want: int = 3 + s.floor
	var rooms: Array = s.map.rooms.filter(func(r): return r.kind == "normal")
	var tries := 0
	while tries < 200 and s.crawlers.size() - keep.size() < want and not rooms.is_empty():
		tries += 1
		var r: Dictionary = R.pick(s, rooms)
		var p := J.pos(R.int_(s, r.x, r.x + r.w - 1), R.int_(s, r.y, r.y + r.h - 1))
		if J.cheb(p, start) < 8 or MapGen.tile_at(s.map, p.x, p.y) != "floor" or _blocked(s, p):
			continue
		s.crawlers.append(make_crawler(s, p))
	# Auf Etage 1 wartet einer ganz in der Nähe
	if s.floor == 1:
		var sorted: Array = J.sort(s.map.rooms.filter(func(r): return r.kind == "normal"), func(a, b): return J.cheb({"x": a.x, "y": a.y}, start) - J.cheb({"x": b.x, "y": b.y}, start))
		if sorted.size() > 1:
			var near: Dictionary = sorted[1]
			var p := J.pos(near.x + floori(near.w / 2.0), near.y + floori(near.h / 2.0))
			if not _blocked(s, p):
				s.crawlers.append(make_crawler(s, p, "freundlich"))


# ================================================================ Gespräche

static func describe(c: Dictionary) -> String:
	var pers := (", %s" % _c("PERSONALITIES")[c.personality].name) if c.met else ""
	return "%s (Level %d, früher %s%s)" % [c.name, c.level, c.background, pers]


static func _adjacent(s: Dictionary, c: Dictionary) -> bool:
	return c.alive and J.cheb(c.pos, s.player.pos) <= 1


static func talkable(s: Dictionary) -> Array:
	return crawlers(s).filter(func(c): return _adjacent(s, c))


static func _by_uid(s: Dictionary, uid: String) -> Variant:
	return J.find(crawlers(s), func(x): return x.uid == uid)


static func talk_to(s: Dictionary, uid: String) -> Dictionary:
	var c = _by_uid(s, uid)
	if c == null or not _adjacent(s, c):
		return {"ok": false, "message": "Da ist niemand zum Reden."}
	var pd: Dictionary = _c("PERSONALITIES")[c.personality]
	var first: bool = not c.met
	c.met = true
	var line: String = R.pick(s, Db.world("RESIDENT_LINES")) if c.get("resident") else R.pick(s, pd.greetings)
	Log.add(s, "%s: „%s“" % [c.name, line], "dialog")
	if first:
		Events.emit(s, {"type": "crawlerMet", "name": c.name, "personality": c.personality})
	if c.personality == "feindselig" and not Combat.is_in_safe_room(s, s.player.pos):
		_turn_hostile(s, c)
		return {"ok": true}
	if first and not c.party and c.personality != "feindselig" and s.unlocks.has("inventar") and Quests.quest_of(s, c.uid) == null and R.chance(s, 0.6):
		var q = Quests.offer_quest(s, {"kind": "crawler", "ref": c.uid, "name": c.name})
		if q != null:
			Log.add(s, "%s hat ein Anliegen: %s" % [c.name, q.text], "dialog")
	return {"ok": true}


static func join_chance(s: Dictionary, c: Dictionary) -> float:
	var pd: Dictionary = _c("PERSONALITIES")[c.personality]
	if pd.join <= 0:
		return 0.0
	var cha: float = Player.effective_stats(s).cha
	var lvl: int = (s.player.level - c.level) * 5
	var followers := 0
	if s.unlocks.has("zuschauer"):
		followers = mini(15, floori(J.log10(maxf(1, s.viewers.follower)) * 4))
	var hurt := -40 if c.personality == "verzweifelt" and c.hp < c.maxHp * 0.5 else 0
	return maxf(0, minf(95, pd.join + (cha - 5) * 4 + lvl + followers + (c.trust - 20) / 2.0 + hurt)) / 100.0


static func invite(s: Dictionary, uid: String) -> Dictionary:
	var c = _by_uid(s, uid)
	if c == null or not _adjacent(s, c):
		return {"ok": false, "message": "Da ist niemand."}
	if c.party:
		return {"ok": false, "message": "%s ist schon in deiner Party." % c.name}
	if c.get("resident"):
		return {"ok": false, "message": "%s: „Nett gemeint. Aber jemand muss hier unten die Stellung halten.“" % c.name}
	if party(s).size() >= int(_c("PARTY_MAX")):
		return {"ok": false, "message": "Deine Party ist voll (vier Crawler inklusive dir)."}
	if c.get("refusedUntil") and s.turn < c.refusedUntil:
		return {"ok": false, "message": "%s hat gerade erst abgelehnt. Gib ihr oder ihm etwas Zeit." % c.name}
	c.met = true
	var pd: Dictionary = _c("PERSONALITIES")[c.personality]
	if c.personality == "feindselig":
		_turn_hostile(s, c)
		return {"ok": true}
	if R.chance(s, join_chance(s, c)):
		c.party = true
		c.trust = maxi(c.trust, 50)
		Log.add(s, "%s: „%s“" % [c.name, R.pick(s, pd.joinYes)], "dialog")
		Log.add(s, "%s ist jetzt in deiner Party." % c.name, "system")
		if c.get("healed"):
			Stats.track(s, "party.gerettet")
		Events.emit(s, {"type": "partyJoined", "name": c.name, "size": party(s).size() + 1})
	else:
		c.refusedUntil = s.turn + 40
		Log.add(s, "%s: „%s“" % [c.name, R.pick(s, pd.joinNo if not pd.joinNo.is_empty() else ["Nein."])], "dialog")
	return {"ok": true}


static func dismiss(s: Dictionary, uid: String) -> Dictionary:
	var c = J.find(party(s), func(x): return x.uid == uid)
	if c == null:
		return {"ok": false, "message": "Nicht in deiner Party."}
	c.party = false
	c.refusedUntil = s.turn + 200
	Log.add(s, "%s nickt stumm und geht eigene Wege." % c.name, "dialog")
	Events.emit(s, {"type": "partyLeft", "name": c.name})
	return {"ok": true}


static func ask_tip(s: Dictionary, uid: String) -> Dictionary:
	var c = _by_uid(s, uid)
	if c == null or not _adjacent(s, c):
		return {"ok": false, "message": "Da ist niemand."}
	if c.personality == "feindselig":
		return talk_to(s, uid)
	if c.get("tipGiven"):
		return {"ok": false, "message": "%s hat dir schon alles erzählt, was sie oder er weiß." % c.name}
	c.tipGiven = true
	c.met = true
	var m: Dictionary = s.map
	var reveal := func(p: Dictionary, r: int) -> void:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var x: int = p.x + dx
				var y: int = p.y + dy
				if x >= 0 and y >= 0 and x < m.width and y < m.height:
					m.explored[MapGen.idx(m, x, y)] = true
	var kind := R.int_(s, 0, 2)
	if kind == 0:
		var i: int = m.tiles.find("stairs")
		if i >= 0:
			reveal.call(J.pos(i % int(m.width), floori(i / float(m.width))), 2)
	elif kind == 1:
		var safes: Array = J.sort(m.rooms.filter(func(r): return r.kind == "safe"), func(a, b): return J.cheb({"x": a.x, "y": a.y}, s.player.pos) - J.cheb({"x": b.x, "y": b.y}, s.player.pos))
		if not safes.is_empty():
			var safe: Dictionary = safes[0]
			reveal.call(J.pos(safe.x + floori(safe.w / 2.0), safe.y + floori(safe.h / 2.0)), maxi(safe.w, safe.h))
	else:
		for t in J.arr(s, "traps"):
			if t.owner == "dungeon" and J.cheb(t.pos, s.player.pos) <= 15:
				t.hidden = false
	Log.add(s, "%s: „%s“" % [c.name, _c("TIP_LINES")[kind]], "dialog")
	c.trust = mini(100, c.trust + 5)
	Stats.track(s, "tipps")
	return {"ok": true}


static func give_healing(s: Dictionary, uid: String, item: Dictionary) -> Dictionary:
	var c = _by_uid(s, uid)
	if c == null or not _adjacent(s, c):
		return {"ok": false, "message": "Da ist niemand."}
	var e = item.get("effekt")
	if e == null or (not e.get("heal") and not e.get("healPct")):
		return {"ok": false, "message": "Das heilt nicht."}
	var amount := J.rnd(J.num(e, "heal") + (J.num(e, "healPct") / 100.0) * c.maxHp)
	c.hp = mini(c.maxHp, c.hp + maxi(8, amount))
	c.trust = mini(100, c.trust + (60 if c.personality == "verzweifelt" else 25))
	c.erase("refusedUntil")
	c.met = true
	if c.personality == "verzweifelt":
		c.personality = "freundlich"
	c.healed = true
	Stats.track(s, "crawler.geheilt")
	Log.add(s, "Du gibst %s %s. „Danke. Wirklich. Das vergesse ich dir nicht.“" % [c.name, Identify.item_name(s, item)], "dialog")
	return {"ok": true}


# ================================================================ Feindselige Crawler

static func _turn_hostile(s: Dictionary, c: Dictionary) -> void:
	var def = Monsters.def_by_id("abtruenniger_crawler")
	if def == null:
		return
	c.alive = false
	var m := Monsters.spawn_monster(s, def, maxi(def.levels[0], c.level + 1), c.pos, -1)
	m.name = c.name
	m.aware = true
	m.provoked = true
	m.maxHp = maxi(m.maxHp, c.maxHp)
	m.hp = m.maxHp
	s.monsters.append(m)
	s.crawlers = J.without(crawlers(s), c)
	Log.add(s, "%s zieht eine Klinge. „Nichts Persönliches. Ich will nur dein Zeug.“" % c.name, "gefahr")
	Events.emit(s, {"type": "crawlerTurned", "name": c.name})


# ================================================================ Züge

static func _seen(s: Dictionary, c: Dictionary) -> bool:
	return Sight.player_sees(s, c.pos)


static func _hit_monster(s: Dictionary, c: Dictionary, m: Dictionary) -> void:
	if R.chance(s, 0.3):
		if _seen(s, c):
			Log.add(s, "%s schlägt nach %s und verfehlt." % [c.name, Identify.name_of(s, m)], "kampf")
		return
	var dmg := maxi(1, R.int_(s, c.dmg[0], c.dmg[1]) - m.ruestung)
	m.hp -= dmg
	m.aware = true
	if _seen(s, c):
		Log.add(s, "%s trifft %s für %d Schaden." % [c.name, Identify.name_of(s, m), dmg], "kampf")
	if m.hp <= 0:
		c.kills += 1
		c.xp += m.xp
		c.trust = mini(100, c.trust + 2)
		while c.xp >= c.level * 50:
			c.xp -= c.level * 50
			c.level += 1
			c.maxHp += 6
			c.hp = c.maxHp
			c.dmg = [c.dmg[0] + 1, c.dmg[1] + 2]
			if _seen(s, c):
				Log.add(s, "%s steigt auf Level %d auf." % [c.name, c.level], "system")
		Combat.kill_monster(s, m, null, c.name, null, c.get("party", false))


static func hurt_crawler(s: Dictionary, c: Dictionary, dmg: int, by: String) -> void:
	c.hp -= dmg
	if _seen(s, c):
		Log.add(s, "%s trifft %s für %d Schaden." % [by, c.name, dmg], "gefahr" if c.party else "kampf")
	if c.hp <= 0:
		_crawler_dies(s, c)


static func _crawler_dies(s: Dictionary, c: Dictionary) -> void:
	c.alive = false
	c.hp = 0
	var was_party: bool = c.party
	c.party = false
	population(s).alive -= 1
	s.crawlers = J.without(crawlers(s), c)
	if _seen(s, c):
		Log.add(s, J.replace1(R.pick(s, _c("DEATH_LINES")), "{name}", c.name), "gefahr")
	if was_party:
		if s.get("fallen") == null:
			s.fallen = []
		s.fallen.append(c.name)
		if _seen(s, c):
			Log.toast(s, "Party-Mitglied gefallen", c.name, "warnung")
	Events.emit(s, {"type": "crawlerDied", "name": c.name, "party": was_party})


static func _step_toward(s: Dictionary, c: Dictionary, goal: Dictionary, max_len: int = 200) -> void:
	var path = Pathfinding.find_path(s.map, c.pos, goal, func(x, y): return not _blocked(s, J.pos(x, y), c) or (x == goal.x and y == goal.y), max_len)
	var next = path[0] if path != null and not path.is_empty() else null
	if next != null and not _blocked(s, next, c):
		c.pos = next


## Alle NPC-Crawler handeln einmal.
static func turn(s: Dictionary) -> void:
	if s.status != "playing":
		return
	_update_population(s)
	announce_population(s)
	for c in crawlers(s).duplicate():
		if not c.alive or s.status != "playing":
			continue
		if s.turn % 10 == 0:
			c.hp = mini(c.maxHp, c.hp + 1)
		var foes: Array = s.monsters.filter(func(m): return J.cheb(m.pos, c.pos) <= 1 and not Combat.is_in_safe_room(s, m.pos) and (m.get("homeRoom") == null or (m.aware and c.party)))
		J.sort(foes, func(a, b): return a.hp - b.hp)
		if not foes.is_empty():
			var foe: Dictionary = foes[0]
			_hit_monster(s, c, foe)
			if J.has_same(s.monsters, foe) and foe.downed <= 0 and (J.cheb(foe.pos, s.player.pos) > 1 or R.chance(s, 0.3)) and R.chance(s, 0.55):
				hurt_crawler(s, c, maxi(1, R.int_(s, foe.dmg[0], foe.dmg[1]) - floori(c.level / 3.0)), Identify.name_of_cap(s, foe))
			continue
		var d := J.cheb(c.pos, s.player.pos)
		if c.party:
			var threat = J.find(s.monsters, func(m): return m.aware and J.cheb(m.pos, s.player.pos) <= 3 and J.cheb(m.pos, c.pos) <= 6)
			if threat != null:
				_step_toward(s, c, threat.pos, 120)
			elif d > 2:
				_step_toward(s, c, s.player.pos, 400)
			if J.cheb(c.pos, s.player.pos) > 12:
				for q in DIRS:
					var spot := J.pos(s.player.pos.x + q[0], s.player.pos.y + q[1])
					if Pathfinding.can_step(s.map, s.player.pos, spot) and not _blocked(s, spot, c):
						c.pos = spot
						break
			if _seen(s, c) and R.chance(s, 0.004):
				Log.add(s, J.replace1(R.pick(s, _c("PARTY_BARKS")), "{name}", c.name), "dialog")
			continue
		if d > 20 and not c.get("resident") and R.chance(s, 0.0006 * s.floor):
			_crawler_dies(s, c)
			continue
		if c.personality == "verzweifelt" or d <= 1:
			continue
		if R.chance(s, 0.25):
			var q: Array = R.pick(s, DIRS)
			var p := J.pos(c.pos.x + q[0], c.pos.y + q[1])
			var home_ok: bool = c.get("home") == null or (MapGen.room_of(s.map, p) != null and MapGen.room_of(s.map, p).id == c.home)
			if Pathfinding.can_step(s.map, c.pos, p) and not _blocked(s, p, c) and not Combat.is_in_safe_room(s, p) and home_ok:
				c.pos = p


## Monster greifen gelegentlich Crawler an, die neben ihnen stehen.
static func monster_hits_crawler(s: Dictionary, m: Dictionary) -> bool:
	if J.cheb(m.pos, s.player.pos) <= 1 and R.chance(s, 0.75):
		return false
	var c = J.find(crawlers(s), func(x): return x.alive and J.cheb(x.pos, m.pos) <= 1)
	if c == null or Combat.is_in_safe_room(s, c.pos):
		return false
	if not R.chance(s, 0.5 if c.party else 0.35):
		return false
	hurt_crawler(s, c, maxi(1, R.int_(s, m.dmg[0], m.dmg[1]) - floori(c.level / 3.0)), Identify.name_of_cap(s, m))
	return true
