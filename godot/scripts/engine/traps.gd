class_name Traps
extends RefCounted
## Fallen.

const TRAP_DEFS := {
	"pfeilplatte": {"name": "Pfeil-Druckplatte", "hide": 0, "fiddly": 0, "minFloor": 1, "weight": 4},
	"stolperdraht": {"name": "Stolperdraht mit Blechdosen", "hide": 5, "fiddly": -10, "minFloor": 1, "weight": 3},
	"fallgrube": {"name": "Fallgrube", "hide": 10, "fiddly": 5, "minFloor": 1, "weight": 3},
	"giftgas": {"name": "Giftgasdüse", "hide": 10, "fiddly": 10, "minFloor": 2, "weight": 3},
	"baerenfalle": {"name": "Bärenfalle", "hide": 5, "fiddly": 10, "minFloor": 2, "weight": 2},
	"stachelfalle": {"name": "Stachelfalle", "hide": 0, "fiddly": -20, "minFloor": 99, "weight": 0},
	"sprengfalle": {"name": "Sprengfalle", "hide": 0, "fiddly": -10, "minFloor": 99, "weight": 0},
	"schlingfalle": {"name": "Schlingfalle", "hide": 0, "fiddly": -20, "minFloor": 99, "weight": 0},
}
const OWN_TRAP_ITEM := {"stachelfalle": "stachelfalle", "sprengfalle": "sprengfalle", "schlingfalle": "schlingfalle"}


static func trap_name(kind: String) -> String:
	return TRAP_DEFS[kind].name


static func _traps(s: Dictionary) -> Array:
	if s.get("traps") == null:
		s.traps = []
	return s.traps


static func trap_at(s: Dictionary, p: Dictionary) -> Variant:
	for t in J.arr(s, "traps"):
		if t.pos.x == p.x and t.pos.y == p.y:
			return t
	return null


static func known_trap_at(s: Dictionary, p: Dictionary) -> Variant:
	var t = trap_at(s, p)
	return t if t != null and not t.hidden else null


static func _remove(s: Dictionary, t: Dictionary) -> void:
	s.traps = J.without(_traps(s), t)


static func place_traps(s: Dictionary, start: Dictionary) -> void:
	s.traps = []
	var m: Dictionary = s.map
	var count: int = 6 + s.floor * 4
	var pool := []
	for k in TRAP_DEFS:
		var d: Dictionary = TRAP_DEFS[k]
		if d.minFloor <= s.floor and d.weight > 0:
			pool.append([k, d.weight])
	var tries := 0
	while s.traps.size() < count:
		if tries >= count * 60:
			break
		tries += 1
		var x := R.int_(s, 1, m.width - 2)
		var y := R.int_(s, 1, m.height - 2)
		var p := J.pos(x, y)
		if MapGen.tile_at(m, x, y) != "floor":
			continue
		if J.cheb(p, start) < 8:
			continue
		var r: int = m.roomAt[MapGen.idx(m, x, y)]
		if r >= 0 and m.rooms[r].kind != "normal":
			continue
		if trap_at(s, p) != null or J.some(s.monsters, func(mo): return mo.pos.x == x and mo.pos.y == y):
			continue
		if J.some(s.items, func(e): return e.pos.x == x and e.pos.y == y):
			continue
		s.traps.append({"uid": "t%d_%d" % [s.floor, s.traps.size()], "pos": p, "kind": R.weighted(s, pool), "hidden": true, "owner": "dungeon"})


static func detect_chance(s: Dictionary, t: Dictionary, dist: int) -> float:
	var int_v: float = Player.effective_stats(s).int
	var base: float = 12 + (int_v - 5) * 4 + Player.skill_level(s, "fallenkunde") * 6 + Player.skill_level(s, "wahrnehmung") * 3 - TRAP_DEFS[t.kind].hide - (dist - 1) * 6 + (20 if Abilities.has_special(s, "fallenmeister") else 0)
	return maxf(3, minf(90, base)) / 100.0


static func detect(s: Dictionary, vis: Dictionary) -> void:
	var p: Dictionary = s.player.pos
	for t in _traps(s):
		if not t.hidden:
			continue
		var d := J.cheb(t.pos, p)
		if d > 2 or d == 0 or not vis.has(MapGen.idx(s.map, t.pos.x, t.pos.y)):
			continue
		if not R.chance(s, detect_chance(s, t, d)):
			continue
		t.hidden = false
		s.counters.trapsFound += 1
		Log.add(s, "Du bemerkst eine %s im Boden. Das war knapp." % trap_name(t.kind), "gefahr")
		Events.emit(s, {"type": "trapDetected", "kind": t.kind})


static func _hurt_player(s: Dictionary, dmg: int, cause: String) -> bool:
	s.player.hp -= dmg
	s.counters.damageTaken += dmg
	if s.player.hp <= 0:
		Death.handle_lethal(s, cause)
		return s.status != "playing"
	return false


static func on_player_step(s: Dictionary) -> void:
	var t = trap_at(s, s.player.pos)
	if t == null or t.owner == "crawler":
		return
	if not t.hidden:
		var ges: float = Player.effective_stats(s).ges
		var safe := minf(0.95, 0.6 + (ges - 5) * 0.04 + Player.skill_level(s, "fallenkunde") * 0.04)
		if R.chance(s, safe):
			Log.add(s, "Du steigst vorsichtig über die %s." % trap_name(t.kind), "info")
			return
		Log.add(s, "Du steigst über die %s – und rutschst ab." % trap_name(t.kind), "gefahr")
	spring_on_player(s, t)


static func spring_on_player(s: Dictionary, t: Dictionary) -> void:
	var p: Dictionary = s.player
	var f: int = s.floor
	t.hidden = false
	_remove(s, t)
	s.counters.trapsTriggered += 1
	Events.emit(s, {"type": "trapTriggered", "kind": t.kind, "onPlayer": true})
	match t.kind:
		"pfeilplatte":
			var dmg := R.int_(s, 3, 6) + f * 2
			Log.add(s, "KLICK. Aus der Wand schießen Pfeile. %d Schaden." % dmg, "gefahr")
			_hurt_player(s, dmg, "von einer Pfeilfalle durchlöchert")
		"fallgrube":
			var dmg := R.int_(s, 2, 5) + f
			Log.add(s, "Der Boden gibt nach! Du fällst in eine Grube. %d Schaden, und herausklettern dauert." % dmg, "gefahr")
			p.immobile = maxi(int(J.num(p, "immobile")), 2)
			_hurt_player(s, dmg, "in einer Fallgrube gestorben")
		"giftgas":
			Log.add(s, "Zischen. Grünes Gas steigt aus einer Düse im Boden.", "gefahr")
			Abilities.poison(s, "Giftgasfalle", 1 + floori(f / 2.0))
		"stolperdraht":
			Log.add(s, "Du bleibst an einem Draht hängen. Dutzende Blechdosen scheppern durch den Gang. Alles in der Nähe weiß jetzt, wo du bist.", "gefahr")
			Ai.make_noise(s, p.pos, 12)
			_hurt_player(s, 1, "über einen Stolperdraht gefallen")
		"baerenfalle":
			var dmg := R.int_(s, 4, 8) + f
			Log.add(s, "KLACK! Eine Bärenfalle schnappt um dein Bein zu. %d Schaden. Du steckst fest." % dmg, "gefahr")
			p.immobile = maxi(int(J.num(p, "immobile")), 3)
			_hurt_player(s, dmg, "in einer Bärenfalle verblutet")


## Festgehalten: Bewegungsversuch. Gibt true zurück, wenn man frei ist.
static func struggle(s: Dictionary) -> bool:
	var p: Dictionary = s.player
	if not p.get("immobile"):
		return true
	var str_v: float = Player.effective_stats(s).str
	Skills.train_skill(s, "struggle", 1)
	if R.chance(s, minf(0.9, 0.1 + (str_v - 5) * 0.05 + Player.skill_level(s, "entfesseln") * 0.08)):
		p.immobile = 0
		Stats.track(s, "befreit")
		if J.some(s.monsters, func(m): return m.aware and J.cheb(m.pos, p.pos) <= 2):
			Stats.track(s, "befreit.kampf")
		Log.add(s, "Mit aller Kraft reißt du dich los.", "info")
		return true
	Log.add(s, "Du zerrst und ziehst, kommst aber nicht frei.", "info")
	return false


static func disarm_chance(s: Dictionary, t: Dictionary) -> float:
	var ges: float = Player.effective_stats(s).ges
	var base: float = 40 + (ges - 5) * 3 + Player.skill_level(s, "fallenkunde") * 8 - TRAP_DEFS[t.kind].fiddly
	return maxf(10, minf(95, base)) / 100.0


static func disarm(s: Dictionary, uid: String) -> Dictionary:
	var t = J.find(_traps(s), func(x): return x.uid == uid)
	if t == null or t.hidden:
		return {"ok": false, "message": "Hier ist keine bekannte Falle."}
	if J.cheb(t.pos, s.player.pos) > 1:
		return {"ok": false, "message": "Dafür musst du direkt daneben stehen."}
	if t.owner == "crawler":
		_remove(s, t)
		var id = OWN_TRAP_ITEM.get(t.kind)
		if id != null:
			Inventory.add_to_inventory(s, Items.create_item(s, id))
		Log.add(s, "Du baust deine %s wieder ab und steckst sie ein." % trap_name(t.kind), "info")
		return {"ok": true}
	if R.chance(s, disarm_chance(s, t)):
		_remove(s, t)
		Inventory.add_to_inventory(s, Items.create_item(s, "fallenteile"))
		s.counters.trapsDisarmed += 1
		Log.add(s, "Vorsichtig löst du die %s. Geschafft! Du nimmst die Fallenteile mit." % trap_name(t.kind), "loot")
		Events.emit(s, {"type": "trapDisarmed", "kind": t.kind, "success": true})
		return {"ok": true}
	Events.emit(s, {"type": "trapDisarmed", "kind": t.kind, "success": false})
	if R.chance(s, 0.5):
		Log.add(s, "Deine Finger rutschen ab. Die %s löst aus!" % trap_name(t.kind), "gefahr")
		spring_on_player(s, t)
	else:
		Log.add(s, "Etwas klickt bedrohlich. Du ziehst die Hand zurück. Die %s ist noch scharf." % trap_name(t.kind), "info")
	return {"ok": true}


static func place_own_trap(s: Dictionary, item: Dictionary) -> Dictionary:
	var p: Dictionary = s.player
	if not item.get("trapKind"):
		return {"ok": false, "message": "Das ist keine Falle."}
	if Combat.is_in_safe_room(s, p.pos):
		return {"ok": false, "message": "Im Safe Room sind Fallen verboten."}
	if MapGen.tile_at(s.map, p.pos.x, p.pos.y) == "stairs":
		return {"ok": false, "message": "Nicht auf der Treppe."}
	if trap_at(s, p.pos) != null:
		return {"ok": false, "message": "Hier ist schon eine Falle."}
	_traps(s).append({"uid": "c%d_%d" % [s.turn, _traps(s).size()], "pos": J.pcopy(p.pos), "kind": item.trapKind, "hidden": false, "owner": "crawler"})
	Log.add(s, "Du stellst eine %s auf. Jetzt nur noch jemanden hierher locken." % trap_name(item.trapKind), "info")
	Events.emit(s, {"type": "trapPlaced", "kind": item.trapKind})
	return {"ok": true}


static func _trap_facets(s: Dictionary, m: Dictionary, part: String) -> Array:
	return ["t:%s" % part] + Observer.target_facets(s, m) + Observer.self_facets(s)


static func _master(s: Dictionary) -> float:
	return 1.5 if Abilities.has_special(s, "fallenmeister") else 1.0


static func on_monster_step(s: Dictionary, m: Dictionary) -> void:
	var t = trap_at(s, m.pos)
	if t == null or t.owner != "crawler" or not J.has_same(s.monsters, m):
		return
	_remove(s, t)
	var skill := Player.skill_level(s, "fallenkunde")
	var facets := _trap_facets(s, m, "falle")
	var seen := Sight.player_sees(s, m.pos)
	var who := Identify.name_of_cap(s, m)
	Events.emit(s, {"type": "trapTriggered", "kind": t.kind, "onPlayer": false})
	match t.kind:
		"stachelfalle":
			var dmg := maxi(1, J.rnd((R.int_(s, 6, 10) + s.floor * 2 + skill * 2) * _master(s)) - floori(m.ruestung / 2.0))
			m.hp -= dmg
			Log.add(s, ("%s tritt in deine Stachelfalle. %d Schaden." % [who, dmg]) if seen else "Irgendwo schnappt deine Stachelfalle zu. Ein Schrei hallt durch die Gänge.", "kampf")
			if m.hp <= 0:
				Combat.kill_monster(s, m, null, false, facets)
		"schlingfalle":
			m.downed = maxi(m.downed, 4)
			m.hp -= 2
			Log.add(s, ("%s verfängt sich in deiner Schlingfalle und stürzt zu Boden." % who) if seen else "In der Ferne zieht sich deine Schlingfalle zu.", "kampf")
			if m.hp <= 0:
				Combat.kill_monster(s, m, null, false, facets)
		"sprengfalle":
			Log.add(s, ("%s löst deine Sprengfalle aus. BUMM!" % who) if seen else "Irgendwo geht deine Sprengfalle hoch. BUMM!", "kampf")
			blast(s, m.pos, J.rnd((R.int_(s, 10, 15) + s.floor * 2 + skill * 2) * _master(s)), "falle", "von der eigenen Sprengfalle zerlegt")


## Explosion im Umkreis von einem Feld.
static func blast(s: Dictionary, at: Dictionary, dmg: int, part: String, self_cause: String, cond: Variant = null) -> void:
	Ai.make_noise(s, at, 10)
	for o in s.monsters.duplicate():
		if J.cheb(o.pos, at) > 1:
			continue
		var hit := maxi(1, dmg - floori(o.ruestung / 2.0))
		var facets := _trap_facets(s, o, part)
		o.hp -= hit
		o.aware = true
		o.provoked = true
		if Sight.player_sees(s, o.pos):
			Log.add(s, "Die Explosion trifft %s für %d Schaden." % [Identify.name_of(s, o), hit], "kampf")
		if o.hp <= 0:
			Combat.kill_monster(s, o, null, false, facets)
		elif cond != null:
			Conditions.inflict(s, o, cond.id, cond.turns, cond.power + floori(s.player.level / 4.0))
	var pet = s.player.pet
	if pet != null and pet.alive and J.cheb(pet.pos, at) <= 1:
		pet.hp -= ceili(dmg / 2.0)
		if pet.hp <= 0:
			pet.hp = 0
			pet.alive = false
			Log.add(s, "%s wird von der Explosion umgeworfen und verschwindet bewusstlos in einem Transportlicht." % pet.name, "gefahr")
	if s.status == "playing" and J.cheb(s.player.pos, at) <= 1:
		var raw := maxi(1, J.rnd(dmg * 0.6 * (1 - minf(0.75, Player.skill_level(s, "sprengmeister") * 0.05))))
		var taken := ceili(raw / 2.0) if Abilities.has_special(s, "explosionsschutz") else raw
		Log.add(s, "Du stehst zu nah dran. Die Druckwelle erwischt dich für %d Schaden." % taken, "gefahr")
		if not _hurt_player(s, taken, self_cause):
			Events.emit(s, {"type": "explosion", "damage": taken, "source": "eigener Sprengsatz"})
			if cond != null and s.status == "playing":
				Conditions.inflict_player(s, cond.id, maxi(1, cond.turns - 1), cond.power, "Die Druckwelle")


static func avoid_tile(s: Dictionary, x: int, y: int) -> bool:
	var t = trap_at(s, J.pos(x, y))
	return t != null and not t.hidden and t.owner == "dungeon"
