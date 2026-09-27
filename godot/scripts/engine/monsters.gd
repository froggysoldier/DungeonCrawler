class_name Monsters
extends RefCounted
## Monster erzeugen (Port von src/engine/monsters.ts).


static func _mid(s: Dictionary) -> String:
	s.uidCounter += 1
	return "m%d" % s.uidCounter


static func spawn_monster(s: Dictionary, def: Dictionary, level: int, pos: Dictionary, hood: int, elite: bool = false) -> Dictionary:
	var lv := level + (1 if elite else 0)
	var extra: int = lv - def.levels[0]
	var hp_mul := 1.8 if elite else 1.0
	var dmg_mul := 1.3 if elite else 1.0
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
		"xp": J.rnd((def.xp + extra * 4) * (2.5 if elite else 1.0)),
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
	var max_hp := J.rnd(def.hp * scale)
	return Items.compact({
		"uid": _mid(s),
		"defId": def.id,
		"name": def.name,
		"glyph": def.glyph,
		"color": def.color,
		"level": def.level + level_bonus,
		"hp": max_hp,
		"maxHp": max_hp,
		"dmg": [J.rnd(def.dmg[0] * scale), J.rnd(def.dmg[1] * scale)],
		"treffer": def.treffer,
		"ruestung": def.ruestung,
		"ausweichen": def.ausweichen,
		"size": def.size,
		"behavior": "ranged" if def.get("range") else "boss",
		"range": def.get("range"),
		"xp": J.rnd(def.xp * scale),
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
static func spawn_ghost(s: Dictionary, ghost: Dictionary, pos: Dictionary, hood: int) -> Dictionary:
	var lv := maxi(2, int(ghost.level) + 1)
	var max_hp := 20 + lv * 9
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
		"dmg": [2 + lv, 4 + lv * 2],
		"treffer": 75,
		"ruestung": 1 + floori(lv / 3.0),
		"ausweichen": 15,
		"size": "mittel",
		"behavior": "melee",
		"xp": 40 + lv * 20,
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
	return R.weighted(s, list.map(func(m): return [m, m.weight]))


static func clamp_level(def: Dictionary, level: int) -> int:
	return maxi(def.levels[0], mini(def.levels[1] + 2, level))


static func spawn_for_floor(s: Dictionary, floor: int, level: int, pos: Dictionary, hood: int, elite: bool) -> Dictionary:
	var def := pick_monster_def(s, floor, level)
	return spawn_monster(s, def, clamp_level(def, level), pos, hood, elite)


static func def_by_id(id: String) -> Variant:
	return Db.monster(id)
