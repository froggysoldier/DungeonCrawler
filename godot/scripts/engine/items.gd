class_name Items
extends RefCounted
## Gegenstände erzeugen.

const START_ONLY := ["bademantel", "schlafanzug", "anzug", "arbeitsjacke", "sportshirt", "hausschuhe", "eigener_ehering", "uniformjacke", "kasack", "kochjacke", "schlafanzughose"]
const RARITY_VALUE := {"gewoehnlich": 1, "ungewoehnlich": 2, "selten": 4, "episch": 8, "legendaer": 20, "himmlisch": 60}
const BOX_SLOTS := {
	"waffen": ["waffe", "haende"],
	"schuh": ["fuesse", "fussring"],
	"kleidung": ["kopf", "gesicht", "brust", "schultern", "arme", "beine", "unterwaesche", "guertel", "ruecken"],
	"schmuck": ["ring", "hals", "fussring"],
	"brawler": ["haende", "arme", "fuesse", "kopf"],
	"wurf": ["arme", "haende", "schultern"],
}
const MATERIAL_EXTRA := ["stein", "ziegel", "flasche", "dose", "schraubenmutter"]

static var _boss_loot := {}


static func _is_boss_loot(id: String) -> bool:
	if _boss_loot.is_empty():
		for b in Db.t("monsters", "HOOD_BOSSES"):
			for l in b.loot:
				_boss_loot[l] = true
	return _boss_loot.has(id)


static func uid(s: Dictionary) -> String:
	s.uidCounter += 1
	return "i%d" % s.uidCounter


## Entfernt fehlende Werte (wie JSON.stringify undefined weglässt).
static func compact(d: Dictionary) -> Dictionary:
	for k in d.keys():
		if d[k] == null:
			d.erase(k)
	return d


static func is_stackable(kind: String) -> bool:
	return kind == "wurf" or kind == "verbrauch" or kind == "schrott"


static func create_item(s: Dictionary, base_id: String, menge: int = 1) -> Dictionary:
	var base = Db.base_item(base_id)
	if base == null:
		push_error("Unbekanntes Item: %s" % base_id)
		return {}
	var unique = Db.unique_item(base_id)
	var wz = base.get("wurfZustand")
	return compact({
		"uid": uid(s),
		"baseId": base_id,
		"name": base.name,
		"kind": base.kind,
		"rarity": unique.rarity if unique != null else "gewoehnlich",
		"slot": base.get("slot"),
		"bonuses": base.bonuses.duplicate(true) if base.get("bonuses") != null else null,
		"waffenSchaden": base.get("waffenSchaden"),
		"wurfSchaden": base.get("wurfSchaden"),
		"effekt": base.get("effekt"),
		"menge": menge if is_stackable(base.kind) else null,
		"flavor": base.flavor,
		"special": unique.get("special") if unique != null else null,
		"passFacet": base.get("passFacet"),
		"explosion": base.get("explosion"),
		"blutung": base.get("blutung"),
		"wurfZustand": wz.duplicate() if wz != null else null,
		"trapKind": base.get("trapKind"),
		"petBonus": base.get("petBonus"),
		"wert": base.wert,
	})


static func create_box(s: Dictionary, type: String, tier: String) -> Dictionary:
	return {
		"uid": uid(s),
		"baseId": "box_%s_%s" % [type, tier],
		"name": "%s %s" % [Db.world("BOX_TIER_NAMES")[tier], Db.world("BOX_TYPE_NAMES")[type]],
		"kind": "box",
		"rarity": _tier_to_rarity(tier),
		"box": {"type": type, "tier": tier},
		"flavor": "Kann nur in einem Safe Room geöffnet werden.",
		"wert": 0,
	}


static func create_area_map(s: Dictionary, hood: int) -> Dictionary:
	return {
		"uid": uid(s),
		"baseId": "gebietskarte",
		"name": "Gebietskarte: %s" % Db.world("HOOD_NAMES")[hood],
		"kind": "karte",
		"rarity": "selten",
		"hood": hood,
		"flavor": "Zeigt den kompletten Grundriss dieses Viertels. Beim Aufheben wird die Karte sofort eingetragen.",
		"wert": 0,
	}


static func create_gold(s: Dictionary, amount: int) -> Dictionary:
	return {
		"uid": uid(s), "baseId": "gold", "name": "%d Gold" % amount, "kind": "gold", "rarity": "gewoehnlich",
		"menge": amount, "flavor": "Die Währung des Dungeons. Riecht nach Münzen und Blut.", "wert": amount,
	}


static func _tier_to_rarity(tier: String) -> String:
	return Db.t("items", "RARITY_ORDER")[Db.world("BOX_TIERS").find(tier)]


## Ausrüstungsteil mit zufälliger Verzauberung.
static func generate_equipment(s: Dictionary, rarity: String, slots: Variant = null) -> Dictionary:
	var base_items: Array = Db.t("items", "BASE_ITEMS")
	var pool := base_items.filter(func(b):
		return b.kind == "ausruestung" and not _is_boss_loot(b.id) and not START_ONLY.has(b.id) and (slots == null or (b.get("slot") != null and slots.has(b.slot))))
	if pool.is_empty():
		pool = base_items.filter(func(b): return b.kind == "ausruestung")
	var base: Dictionary = R.pick(s, pool)
	var item := create_item(s, base.id)
	item.rarity = rarity
	var cfg: Dictionary = Db.t("items", "RARITY_AFFIXES")[rarity]
	var count := R.int_(s, cfg.count[0], cfg.count[1])
	var affix_pool: Array = Db.t("items", "AFFIXES").filter(func(a): return a.get("slots") == null or (base.get("slot") != null and a.slots.has(base.slot)))
	var chosen: Array = R.shuffle(s, affix_pool.duplicate()).slice(0, count)
	var bonuses: Dictionary = item.get("bonuses") if item.get("bonuses") != null else {}
	for a in chosen:
		Bonuses.add(bonuses, Rules.affix_bonuses(a.id, R.int_(s, cfg.power[0], cfg.power[1])))
	item.bonuses = bonuses
	if item.get("waffenSchaden"):
		item.waffenSchaden += Db.t("items", "RARITY_ORDER").find(rarity) * 2
	if not chosen.is_empty():
		item.name = "%s %s" % [base.name, chosen[0].prefix]
		if chosen.size() > 1:
			item.name += " (+%d)" % (chosen.size() - 1)
		item.flavor = "%s %s" % [base.flavor, R.pick(s, Db.t("items", "ITEM_QUIPS"))]
	item.wert = J.rnd((base.wert + 2) * RARITY_VALUE[rarity])
	return item


static func _roll_unique(s: Dictionary, max_rarity: String) -> Variant:
	var order: Array = Db.t("items", "RARITY_ORDER")
	var max_idx := order.find(max_rarity)
	var pool: Array = Db.t("items", "UNIQUE_ITEMS").filter(func(u): return order.find(u.rarity) <= max_idx)
	if pool.is_empty():
		return null
	return create_item(s, R.pick(s, pool).id)


## Öffnet eine Box und erzeugt ihren Inhalt.
static func roll_box_contents(s: Dictionary, type: String, tier: String) -> Array:
	var cfg: Dictionary = Db.world("BOX_CONTENTS")[tier]
	var out := []
	var count := R.int_(s, cfg.items[0], cfg.items[1])
	var max_rarity: String = cfg.rarities[cfg.rarities.size() - 1][0]
	for i in count:
		if R.chance(s, cfg.uniqueChance):
			var u = _roll_unique(s, max_rarity)
			if u != null:
				out.append(u)
				continue
		var rarity: String = R.weighted(s, cfg.rarities)
		out.append(_roll_themed_item(s, type, rarity))
	out.append(create_gold(s, R.int_(s, cfg.gold[0], cfg.gold[1])))
	var tier_idx: int = Db.world("BOX_TIERS").find(tier)
	var half := floori(tier_idx / 2.0)
	if type == "ueberlebens" or type == "abenteurer":
		out.append(create_item(s, "heiltrank" if tier_idx >= 1 else "kleiner_heiltrank", 1 + half))
	if type == "wurf":
		out.append(create_item(s, "ziegel" if tier_idx >= 2 else "stein", 5 + tier_idx * 3))
	if type == "ueberlebens":
		out.append(create_item(s, "gegengift", 1 + half))
	if type == "ueberlebens" or type == "wurf":
		if R.chance(s, 0.5):
			out.append(create_item(s, "fallenteile", 1 + half))
		if R.chance(s, 0.4):
			out.append(create_item(s, "schwarzpulver", 1 + half))
	if type == "wurf" and tier_idx >= 1:
		out.append(create_item(s, "brandflasche" if R.chance(s, 0.5) else "nagelbombe", tier_idx))
	if tier_idx >= 2 and R.chance(s, 0.1):
		out.append(create_item(s, "klappwerkbank"))
	# Reittiere: selten, in guten Boxen häufiger
	if (type == "abenteurer" or type == "fan" or type == "boss" or type == "haustier") and tier_idx >= 1 and R.chance(s, 0.05 + tier_idx * 0.04):
		var pool := ["zuendschluessel_traktor", "pfeife_eber", "pfeife_schnecke"] if tier_idx >= 3 else ["zuendschluessel_wagen", "pfeife_pony", "zuendschluessel_bobbycar"]
		out.append(create_item(s, R.pick(s, pool)))
	# Zauberbücher: selten in einfachen Boxen, häufiger in guten
	if (type == "abenteurer" or type == "fan" or type == "boss") and R.chance(s, 0.12 + tier_idx * 0.1):
		out.append(Magic.random_tome(s, Db.t("items", "RARITY_ORDER")[mini(4, tier_idx + 1)]))
	if tier_idx >= 1 and R.chance(s, 0.3):
		out.append(create_item(s, "kleiner_manatrank", 1 + half))
	if type == "brawler":
		out.append(create_item(s, "energydrink", 1 + half))
	return out


static func _roll_themed_item(s: Dictionary, type: String, rarity: String) -> Dictionary:
	var order: Array = Db.t("items", "RARITY_ORDER")
	if type == "haustier":
		var r := order.find(rarity)
		if r >= 4 and R.chance(s, 0.4):
			return create_item(s, "superkeks")
		if r >= 2 and R.chance(s, 0.3):
			return create_item(s, "ei_drache" if R.chance(s, 0.3) else "ei_raptor")
		if R.chance(s, 0.35):
			var id: String
			if r >= 3:
				id = "halsband_stachel"
			elif r >= 2:
				id = R.pick(s, ["halsband_nieten", "halsband_glocke"])
			else:
				id = "halsband_leder"
			return create_item(s, id)
		return create_item(s, "leckerli", r + 1) if R.chance(s, 0.6) else generate_equipment(s, rarity, ["hals"])
	if type == "ueberlebens" and R.chance(s, 0.4):
		return create_item(s, "heiltrank", 1 + order.find(rarity))
	return generate_equipment(s, rarity, BOX_SLOTS.get(type))


## Zufälliger Bodenfund (Steine, Flaschen, Kleinkram).
static func roll_ground_item(s: Dictionary) -> Dictionary:
	var pool := []
	for b in Db.t("items", "BASE_ITEMS"):
		if b.get("ground"):
			pool.append([b.id, b.ground])
	var id: String = R.weighted(s, pool)
	var base: Dictionary = Db.base_item(id)
	if base.kind == "ausruestung" and R.chance(s, 0.15):
		return generate_equipment(s, "ungewoehnlich", [base.slot] if base.get("slot") != null else null)
	return create_item(s, id)


## Material zum Basteln und Wurfkram (normale Räume).
static func roll_material(s: Dictionary) -> Dictionary:
	var pool := []
	for b in Db.t("items", "BASE_ITEMS"):
		if b.get("ground") and (b.kind == "schrott" or MATERIAL_EXTRA.has(b.id)):
			pool.append([b.id, b.ground])
	return create_item(s, R.weighted(s, pool))


## Mob-Drops: meist nichts, manchmal Gold oder Kleinkram.
static func roll_mob_drop(s: Dictionary, level: int, elite: bool) -> Array:
	var out := []
	if R.chance(s, 1.0 if elite else 0.35):
		out.append(create_gold(s, R.int_(s, 1, 3 + level * 2) * (3 if elite else 1)))
	if R.chance(s, 0.6 if elite else 0.12):
		if elite:
			out.append(generate_equipment(s, "selten" if R.chance(s, 0.3) else "ungewoehnlich"))
		else:
			out.append(roll_ground_item(s))
	if R.chance(s, 0.05):
		out.append(create_item(s, "kleiner_heiltrank"))
	if R.chance(s, 0.03):
		out.append(create_item(s, "gegengift"))
	if R.chance(s, 0.08):
		out.append(create_item(s, R.pick(s, ["lappen", "naegel", "klebeband", "lappen", "naegel", "schwarzpulver"])))
	return out


static func base_exists(id: String) -> bool:
	return Db.base_item(id) != null
