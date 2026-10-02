class_name Abilities
extends RefCounted
## Monster-Fähigkeiten und Sondereigenschaften.

const ABILITY_NAMES := {
	"gift": "giftig",
	"explodiert": "explodiert beim Tod",
	"diebisch": "klaut Gold",
	"rufer": "ruft Verstärkung",
	"regeneriert": "regeneriert",
	"schnell": "schnell",
	"fliegend": "fliegt",
	"gepanzert": "gepanzert (halber Faustschaden)",
	"blutig": "reißt blutende Wunden",
	"brennend": "setzt in Brand",
	"blendend": "blendet",
	"furchterregend": "jagt Angst ein",
}

const NEIGHBORS := [[1, 0], [-1, 0], [0, 1], [0, -1], [1, 1], [1, -1], [-1, 1], [-1, -1]]


static func has(m: Dictionary, a: String) -> bool:
	return J.arr(m, "abilities").has(a)


static func has_special(s: Dictionary, special: String) -> bool:
	var p: Dictionary = s.player
	if p.get("race"):
		var r = Db.race(p.race)
		if r != null and J.arr(r, "specials").has(special):
			return true
	if p.get("klass"):
		var k = Db.klass(p.klass)
		if k != null and J.arr(k, "specials").has(special):
			return true
	if Traits.trait_special(s, special):
		return true
	for slot in p.equipment:
		var i = p.equipment[slot]
		if i != null and i.get("special") == special:
			return true
	return false


## Vergiftet den Crawler (stapelt nicht, frischt aber auf).
static func poison(s: Dictionary, source: String, strength: int) -> void:
	if has_special(s, "giftimmun"):
		Log.add(s, "%s will dich vergiften – deine Ausrüstung neutralisiert das Gift." % source, "info")
		return
	var p: Dictionary = s.player
	var existing = J.find(p.buffs, func(b): return b.name == "Vergiftet")
	if existing != null:
		existing.turns = maxi(existing.turns, 6)
		existing.dot = maxi(int(J.nn(existing, "dot", 1)), strength)
	else:
		p.buffs.append({"name": "Vergiftet", "turns": 6, "bonuses": {}, "dot": strength, "debuff": true})
	Log.add(s, "Du bist vergiftet! (%d Schaden pro Zug)" % strength, "gefahr")
	Events.emit(s, {"type": "poisoned", "source": source})


static func cure(s: Dictionary) -> bool:
	var before: int = s.player.buffs.size()
	s.player.buffs = s.player.buffs.filter(func(b): return b.name != "Vergiftet")
	if s.player.buffs.size() == before:
		return false
	Log.add(s, "Das Gift ist neutralisiert.", "info")
	Events.emit(s, {"type": "cured"})
	return true


## Wird aufgerufen, wenn ein Monster den Crawler getroffen hat.
static func on_monster_hit(s: Dictionary, m: Dictionary) -> void:
	if has(m, "gift") and R.chance(s, 0.4):
		poison(s, Identify.name_of_cap(s, m), 1 + floori(m.level / 4.0))
	if has(m, "diebisch") and s.player.gold > 0 and not m.get("stolenGold") and R.chance(s, 0.5):
		var amount: int = mini(s.player.gold, 5 + m.level * 3)
		s.player.gold -= amount
		m.stolenGold = amount
		m.fleeing = true
		s.counters.goldStolen += amount
		Log.add(s, "%s klaut dir %d Gold und rennt davon!" % [Identify.name_of_cap(s, m), amount], "gefahr")
		Events.emit(s, {"type": "robbed", "amount": amount, "source": m.name})


## Fähigkeiten, die zu Beginn eines Monsterzugs greifen.
static func start_of_turn(s: Dictionary, m: Dictionary) -> void:
	if has(m, "regeneriert") and m.hp < m.maxHp:
		# Bosse haben viel mehr Lebenspunkte: dort heilt nur ein kleinerer Anteil
		var rate := 0.015 if m.rank == "nachbarschaftsboss" or m.rank == "boroughboss" else 0.04
		m.hp = mini(m.maxHp, m.hp + maxi(1, J.rnd(m.maxHp * rate)))
	if has(m, "rufer") and m.aware and J.num(m, "summoned") < 2 and R.chance(s, 0.12):
		_summon(s, m)


static func _summon(s: Dictionary, m: Dictionary) -> void:
	var free := []
	for d in NEIGHBORS:
		var p := J.pos(m.pos.x + d[0], m.pos.y + d[1])
		if MapGen.is_walkable(s.map, p.x, p.y) and not _is_taken(s, p) and (m.get("homeRoom") == null or s.map.roomAt[p.y * s.map.width + p.x] == m.homeRoom):
			free.append(p)
	if free.is_empty():
		return
	var pos: Dictionary = R.pick(s, free)
	# Diener von Bossen sind deutlich schwächer als ihr Herr
	var level := maxi(1, m.level - (5 if m.rank == "nachbarschaftsboss" or m.rank == "boroughboss" else 3))
	var def_id: String = m.defId
	var is_rat := def_id.contains("ratte") or def_id == "rattenschamane" or def_id == "rattenkaiser" or def_id == "rattenmensch"
	var rat_def = Monsters.def_by_id("knochenratte" if s.floor >= 2 else "kellerratte")
	var minion: Dictionary
	if is_rat and rat_def != null:
		minion = Monsters.spawn_monster(s, rat_def, maxi(rat_def.levels[0], level), pos, m.hood)
	else:
		minion = Monsters.spawn_for_floor(s, s.floor, level, pos, m.hood, false)
	minion.aware = true
	# Diener eines Bosses bleiben mit ihm in der Kammer
	if m.get("homeRoom") != null:
		minion.homeRoom = m.homeRoom
	s.monsters.append(minion)
	m.summoned = int(J.num(m, "summoned")) + 1
	Log.add(s, "%s ruft Verstärkung: %s taucht auf!" % [Identify.name_of_cap(s, m), Identify.name_of(s, minion, "nom")], "gefahr")


static func _is_taken(s: Dictionary, p: Dictionary) -> bool:
	if s.player.pos.x == p.x and s.player.pos.y == p.y:
		return true
	var pet = s.player.pet
	if pet != null and pet.alive and pet.pos.x == p.x and pet.pos.y == p.y:
		return true
	return J.some(s.monsters, func(o): return o.pos.x == p.x and o.pos.y == p.y)

