class_name Identify
extends RefCounted
## Was der Crawler über Monster und Gegenstände weiß (Port von src/engine/identify.ts).
## Namen und Werte von Monstern und Gegenständen immer hierüber anzeigen.

const INSIGHT_NAMES := {
	0: "Vollständig identifiziert",
	1: "Gut eingeschätzt",
	2: "Grob eingeschätzt",
	3: "Kaum einzuschätzen",
	4: "Nicht einzuschätzen",
}
const SIZE_WORDS := {"winzig": "winziges", "klein": "kleines", "mittel": "mittelgroßes", "gross": "großes", "riesig": "riesiges"}
const SIZE_DAT := {"winzig": "winzigen", "klein": "kleinen", "mittel": "mittelgroßen", "gross": "großen", "riesig": "riesigen"}
const RARITY_LEVEL := {"gewoehnlich": 1, "ungewoehnlich": 1, "selten": 3, "episch": 6, "legendaer": 10, "himmlisch": 15}


static func intelligence_bonus(s: Dictionary) -> int:
	var perception := 1 if Player.skill_level(s, "wahrnehmung") >= 8 else 0
	var system := 2 if Abilities.has_special(s, "systemkenntnis") else 0
	return maxi(0, floori((Player.effective_stats(s).int - 5) / 3.0)) + perception + system


static func experience_bonus(s: Dictionary, def_id: String) -> int:
	return mini(2, floori(J.num(s.counters.killsByDef, def_id) / 3.0))


static func _insight_from_gap(gap: int) -> int:
	if gap <= 0:
		return 0
	if gap <= 2:
		return 1
	if gap <= 4:
		return 2
	if gap <= 7:
		return 3
	return 4


static func monster_insight(s: Dictionary, m: Dictionary) -> int:
	var gap: int = m.level - s.player.level - intelligence_bonus(s) - experience_bonus(s, m.defId)
	return _insight_from_gap(gap)


static func _is_boss(m: Dictionary) -> bool:
	return m.rank == "nachbarschaftsboss" or m.rank == "boroughboss"


## Der Name, den der Crawler für dieses Monster kennt.
static func name_of(s: Dictionary, m: Dictionary) -> String:
	var insight := monster_insight(s, m)
	if insight <= 2:
		return m.name
	if insight == 4:
		return "etwas sehr Gefährliches"
	return "ein unbekannter Boss" if _is_boss(m) else "ein unbekanntes %s Wesen" % SIZE_WORDS[m.size]


## Name im Dativ, z. B. nach „von“.
static func name_of_dat(s: Dictionary, m: Dictionary) -> String:
	var insight := monster_insight(s, m)
	if insight <= 2:
		return m.name
	if insight == 4:
		return "etwas sehr Gefährlichem"
	return "einem unbekannten Boss" if _is_boss(m) else "einem unbekannten %s Wesen" % SIZE_DAT[m.size]


## Name am Satzanfang (großgeschrieben).
static func name_of_cap(s: Dictionary, m: Dictionary) -> String:
	return J.cap(name_of(s, m))


static func condition_word(hp: float, max_v: float) -> String:
	var r := hp / max_v
	if r >= 1:
		return "unverletzt"
	if r > 0.75:
		return "leicht verletzt"
	if r > 0.45:
		return "verletzt"
	if r > 0.2:
		return "schwer verletzt"
	return "fast tot"


static func _threat_word(s: Dictionary, m: Dictionary) -> String:
	var avg: float = (m.dmg[0] + m.dmg[1]) / 2.0
	var r := avg / Player.max_hp(s)
	if r < 0.08:
		return "gering"
	if r < 0.15:
		return "mittel"
	if r < 0.25:
		return "hoch"
	return "sehr hoch"


static func describe_monster(s: Dictionary, m: Dictionary) -> Dictionary:
	var insight := monster_insight(s, m)
	var boss := _is_boss(m)
	var rank = "Elite" if m.rank == "elite" else ("Geist" if m.rank == "geist" else ("Boss" if boss else null))
	var level: String
	if insight <= 1:
		level = "Level %s" % J.s(m.level)
	elif insight == 2:
		level = "Level %s bis %s" % [J.s(m.level - 1), J.s(m.level + 1)]
	elif insight == 3:
		level = "Level deutlich über deinem"
	else:
		level = "Level weit über deinem"
	var health: String
	if insight <= 1:
		health = "HP %s von %s (%s)" % [J.s(maxf(0, m.hp)), J.s(m.maxHp), condition_word(m.hp, m.maxHp)]
	elif insight <= 3:
		health = "Zustand: %s" % condition_word(m.hp, m.maxHp)
	else:
		health = "Zustand: unbekannt"
	var combat = null
	if insight == 0:
		combat = "Schaden %s bis %s, Rüstung %s, Ausweichen %s %%" % [J.s(m.dmg[0]), J.s(m.dmg[1]), J.s(m.ruestung), J.s(m.ausweichen)]
	elif insight == 1:
		combat = "Gefahr: %s" % _threat_word(s, m)
	var abs_list := J.arr(m, "abilities")
	var count := abs_list.size()
	var abilities = null
	if count == 0:
		abilities = "Keine besonderen Fähigkeiten" if insight <= 1 else null
	elif insight <= 1:
		abilities = "Fähigkeiten: %s" % ", ".join(abs_list.map(func(a): return Abilities.ABILITY_NAMES[a]))
	elif insight == 2:
		abilities = "Hat %s" % ("eine besondere Fähigkeit" if count == 1 else "%d besondere Fähigkeiten" % count)
	var challenge: Dictionary
	if insight <= 2:
		challenge = Progression.CHALLENGES[Progression.challenge_of(m.level - s.player.level)]
	else:
		challenge = {"name": "gefährlich oder schlimmer", "color": Progression.CHALLENGES.gefaehrlich.color, "hint": "unbekannt viel Erfahrung"}
	return {
		"insight": insight,
		"name": m.name if insight <= 2 else name_of_cap(s, m),
		"rank": rank if insight <= 3 else null,
		"level": level,
		"health": health,
		"combat": combat,
		"abilities": abilities,
		"flavor": m.flavor if insight <= 2 else null,
		"showHitChance": insight <= 2,
		"showHealthBar": insight <= 3,
		"challenge": challenge,
	}


# ================================================================ Gegenstände

static func item_insight(s: Dictionary, it: Dictionary) -> int:
	if it.kind == "gold" or it.kind == "box" or it.kind == "karte":
		return 0
	var gap: int = RARITY_LEVEL[it.rarity] - s.player.level - intelligence_bonus(s)
	if gap <= 0:
		return 0
	if gap <= 2:
		return 1
	if gap <= 5:
		return 2
	return 4


## Name eines Gegenstands, wie der Crawler ihn kennt.
static func item_name(s: Dictionary, it: Dictionary) -> String:
	var insight := item_insight(s, it)
	if insight == 0:
		return it.name
	var kind: String = Db.t("items", "SLOT_NAMES")[it.slot] if it.get("slot") else ("Wurfobjekt" if it.kind == "wurf" else "Gegenstand")
	if insight == 1:
		return "%s (nicht identifiziert)" % it.name
	return "Unbekannter %ser Gegenstand (%s)" % [String(Db.t("items", "RARITY_NAMES")[it.rarity]).to_lower(), kind]


static func describe_item(s: Dictionary, it: Dictionary) -> Dictionary:
	var insight := item_insight(s, it)
	var lines := Bonuses.describe(it.get("bonuses"))
	var need: int = RARITY_LEVEL[it.rarity]
	if insight == 0:
		return {"insight": insight, "name": it.name, "bonuses": lines, "flavor": it.flavor, "note": null}
	if insight == 1:
		# Man erkennt, WAS verzaubert ist, aber nicht wie stark.
		var re := RegEx.create_from_string("^[+-]?\\d+(?:[.,]\\d+)?")
		var vague := lines.map(func(l): return re.sub(l, "?"))
		return {"insight": insight, "name": item_name(s, it), "bonuses": vague, "flavor": it.flavor, "note": "Vollständig lesbar ab Level %d." % need}
	return {
		"insight": insight,
		"name": item_name(s, it),
		"bonuses": ["Unbekannte magische Eigenschaften"] if not lines.is_empty() else [],
		"flavor": null,
		"note": "Du verstehst diesen Gegenstand noch nicht. Ab Level %d (oder mit mehr Intelligenz) wird er lesbar." % need,
	}
