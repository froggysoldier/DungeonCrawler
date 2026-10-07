class_name Monsters
extends RefCounted
## Monster erzeugen.


static func _mid(s: Dictionary) -> String:
	s.uidCounter += 1
	return "m%d" % s.uidCounter


static func spawn_monster(s: Dictionary, def: Dictionary, level: int, pos: Dictionary, hood: int, elite: bool = false) -> Dictionary:
	var lv := level + (1 if elite else 0)
	var extra: int = lv - def.levels[0]
	# Jede Etage hat einen eigenen Stärkefaktor für normale Monster (world.json
	# FLOORS[].mobScale): tiefer unten mehr HP, mehr Schaden, mehr Erfahrung
	var sc: Dictionary = J.nn(Db.floor_def0(int(s.floor)), "mobScale", {})
	# Elite-Aufschlag: auf Etage 1 voll, tiefer unten kleiner (der Etagenfaktor
	# macht ohnehin schon alles stärker)
	var scaled: bool = sc.has("hp")
	var hp_mul: float = ((1.4 if scaled else 1.8) if elite else 1.0) * float(sc.get("hp", 1.0))
	var dmg_mul: float = ((1.15 if scaled else 1.3) if elite else 1.0) * float(sc.get("dmg", 1.0))
	var xp_mul: float = float(sc.get("xp", 1.0))
	var max_hp := J.rnd((def.hp + def.hpPerLevel * extra) * hp_mul)
	return Items.compact({
		"uid": _mid(s),
		"defId": def.id,
		"name": ("%s [Elite]" % def.name) if elite else def.name,
		"glyph": def.glyph,
		"color": "#ff5050" if elite else def.color,
		"level": lv,
		"hp": max_hp,
		"maxHp": max_hp,
		"dmg": [
			J.rnd((def.dmg[0] + def.dmgPerLevel * extra * 0.5) * dmg_mul),
			J.rnd((def.dmg[1] + def.dmgPerLevel * extra) * dmg_mul),
		],
		"treffer": def.treffer + lv,
		"ruestung": def.ruestung + (1 if elite else 0),
		"ausweichen": def.ausweichen,
		"size": def.size,
		"behavior": def.behavior,
		"range": def.get("range"),
		"xp": J.rnd((def.xp + extra * 4) * (2.5 if elite else 1.0) * xp_mul),
		"pos": J.pcopy(pos),
		"hood": hood,
		"rank": "elite" if elite else "normal",
		"downed": 0,
		"aware": false,
		"flavor": def.flavor,
		"abilities": def.abilities.duplicate() if def.get("abilities") != null else null,
	})


static func spawn_boss(s: Dictionary, def: Dictionary, pos: Dictionary, hood: int, room: int, floor: int) -> Dictionary:
	# Bosse, die tiefer als auf ihrer ersten Etage auftauchen, werden stärker.
	var level_bonus: int = maxi(0, floor - int(def.floors.min())) * 2
	var scale := 1 + level_bonus * 0.25
	# Etagenfaktor für Bosse (world.json FLOORS[].bossScale, für den
	# Bezirksboss boroughScale: erst gegen Ende der Etage zu schaffen)
	var fd := Db.floor_def0(floor)
	var bs: Dictionary = J.nn(fd, "boroughScale" if def.rank == "boroughboss" and fd.has("boroughScale") else "bossScale", {})
	var max_hp := J.rnd(def.hp * scale * float(bs.get("hp", 1.0)))
	var dmul: float = scale * float(bs.get("dmg", 1.0))
	return Items.compact({
		"uid": _mid(s),
		"defId": def.id,
		"name": def.name,
		"glyph": def.glyph,
		"color": def.color,
		"level": def.level + level_bonus,
		"hp": max_hp,
		"maxHp": max_hp,
		"dmg": [J.rnd(def.dmg[0] * dmul), J.rnd(def.dmg[1] * dmul)],
		"treffer": def.treffer,
		"ruestung": def.ruestung,
		"ausweichen": def.ausweichen,
		"size": def.size,
		"behavior": "ranged" if def.get("range") else "boss",
		"range": def.get("range"),
		"xp": J.rnd(def.xp * scale * float(bs.get("xp", 1.0))),
		"pos": J.pcopy(pos),
		"hood": hood,
		"rank": def.rank,
		"downed": 0,
		"aware": false,
		"homeRoom": room,
		"loot": def.get("loot"),
		"flavor": def.flavor,
		"abilities": def.abilities.duplicate() if def.get("abilities") != null else null,
	})


## Der Geist eines früheren, gestorbenen Crawlers.
## Stark wie ein Elite-Gegner der Etage, nicht wie der Crawler auf seinem
## Höhepunkt: höchstens Stufe 2 + 2 × Etage, dazu der Etagenfaktor.
static func spawn_ghost(s: Dictionary, ghost: Dictionary, pos: Dictionary, hood: int) -> Dictionary:
	var floor := int(s.floor)
	var lv := clampi(int(ghost.level), 1, 2 + floor * 2)
	var sc: Dictionary = J.nn(Db.floor_def0(floor), "mobScale", {})
	var max_hp := J.rnd((14 + lv * 6) * float(sc.get("hp", 1.0)))
	var dmul := float(sc.get("dmg", 1.0))
	var gdef: Dictionary = Db.t("monsters", "GHOST_DEF")
	return {
		"uid": _mid(s),
		"defId": "geist",
		"name": "Geist von %s" % ghost.name,
		"glyph": gdef.glyph,
		"color": gdef.color,
		"level": lv,
		"hp": max_hp,
		"maxHp": max_hp,
		"dmg": [J.rnd((1 + lv / 2.0) * dmul), J.rnd((3 + lv) * dmul)],
		"treffer": 70,
		"ruestung": floori(lv / 3.0),
		"ausweichen": 15,
		"size": "mittel",
		"behavior": "melee",
		"abilities": ["fliegend", "geisterhaft"],
		"xp": J.rnd((30 + lv * 12) * float(sc.get("xp", 1.0))),
		"pos": J.pcopy(pos),
		"hood": hood,
		"rank": "geist",
		"downed": 0,
		"aware": false,
		"ghostOf": ghost.name,
		"ghostItems": ghost.items,
		"flavor": "Das ist %s aus Staffel %s. Oder was davon übrig ist. Gestorben auf dieser Etage, mit Level %s. Trägt noch die alte Ausrüstung." % [ghost.name, J.s(ghost.season), J.s(ghost.level)],
	}


## Monstertyp, der auf dieser Etage und in diesem Level vorkommt.
static func pick_monster_def(s: Dictionary, floor: int, level: int) -> Dictionary:
	var monsters: Array = Db.t("monsters", "MONSTERS")
	var on_floor := monsters.filter(func(m): return m.floors.has(floor))
	var pool := on_floor.filter(func(m): return level >= m.levels[0] and level <= m.levels[1] + 2)
	var list: Array = pool if not pool.is_empty() else (on_floor if not on_floor.is_empty() else monsters)
	# Arten von weiter oben kommen tiefer unten nur noch halb so oft vor,
	# damit jede Etage ihre eigenen Bewohner zeigt
	return R.weighted(s, list.map(func(m): return [m, m.weight * (0.5 if m.floors[0] < floor else 1.0)]))


## Zufällige Stufe für Nachzügler (Nachspawns, Mimics, Auftragsgegner): im
## Bereich der Etage, aber höchstens zwei Stufen über dem Crawler.
static func roll_level(s: Dictionary) -> int:
	var lv: Array = Db.floor_def0(s.floor).mobLevel
	var hi: int = clampi(int(s.player.level) + 2, int(lv[0]), int(lv[1]))
	return R.int_(s, int(lv[0]), hi)


## Stufe für Nachspawns: je näher der Einsturz, desto stärker. Zu Beginn der
## Etage untere Hälfte des Bereichs, gegen Ende bis zur Obergrenze – aber nie
## mehr als eine Stufe über dem Crawler. Wer die Zeit nutzt, findet so bis
## zuletzt Gegner, an denen er wächst.
static func respawn_level(s: Dictionary) -> int:
	var lv: Array = Db.floor_def0(s.floor).mobLevel
	var lo0: int = int(lv[0])
	var span: int = int(lv[1]) - lo0
	var dur := float(Db.floor_def0(s.floor).duration)
	var elapsed := clampf(1.0 - float(Game.time_left(s)) / dur, 0.0, 1.0)
	var hi: int = mini(lo0 + J.rnd(span * (0.4 + 0.6 * elapsed)), int(s.player.level) + 1)
	var lo: int = mini(lo0 + floori(span * elapsed * 0.5), hi)
	return R.int_(s, maxi(lo0, lo), maxi(lo0, hi))


static func clamp_level(def: Dictionary, level: int) -> int:
	return maxi(def.levels[0], mini(def.levels[1] + 2, level))


static func spawn_for_floor(s: Dictionary, floor: int, level: int, pos: Dictionary, hood: int, elite: bool) -> Dictionary:
	var def := pick_monster_def(s, floor, level)
	return spawn_monster(s, def, clamp_level(def, level), pos, hood, elite)


static func def_by_id(id: String) -> Variant:
	return Db.monster(id)
