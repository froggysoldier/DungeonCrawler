class_name Extras
extends RefCounted
## Pässe, Haustiere aus Eiern, Zähmen, besondere Gegenstände
## (Port von src/engine/extras.ts).

const TATTOOS := {
	"tattoo_kobold": {"facet": "z:kobold", "text": "Ein Kobold grinst jetzt von deinem Unterarm. Kobolde halten dich für einen der ihren."},
	"tattoo_ratte": {"facet": "z:ratte", "text": "Sieben verknotete Schwänze zieren jetzt deine Hand. Ratten weichen dir aus."},
}
const TALISMAN_FACETS := {"talisman_flug": "z:fliegend", "talisman_untot": "z:untot", "talisman_insekt": "z:insekt"}


static func active_passes(s: Dictionary) -> Array:
	var out: Array = J.arr(s.player, "passes").duplicate()
	for k in s.player.equipment:
		var it = s.player.equipment[k]
		if it != null and it.get("passFacet"):
			out.append(it.passFacet)
	return out


static func pass_protects(s: Dictionary, m: Dictionary) -> bool:
	if m.get("provoked") or m.rank == "nachbarschaftsboss" or m.rank == "boroughboss":
		return false
	var passes := active_passes(s)
	if Abilities.has_special(s, "rattenfreund"):
		passes.append("z:ratte")
	if passes.is_empty():
		return false
	var facets := Observer.target_facets(s, m)
	return J.some(passes, func(p): return facets.has(p))


static func make_pet_of(species: String, name: String) -> Dictionary:
	var all: Dictionary = Db.t("pets", "PET_SPECIES")
	var sp: Dictionary = all.get(species, all.Katze)
	return {"name": name, "species": sp.id, "level": 1, "xp": 0, "hp": sp.hp, "maxHp": sp.hp, "dmg": sp.dmg.duplicate(), "pos": J.pos(0, 0), "alive": true}


static func _free_neighbor(s: Dictionary, p: Dictionary) -> Dictionary:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var q := J.pos(p.x + dx, p.y + dy)
			if (dx or dy) and MapGen.is_walkable(s.map, q.x, q.y) and not J.some(s.monsters, func(m): return m.pos.x == q.x and m.pos.y == q.y):
				return q
	return J.pcopy(p)


static func egg_tick(s: Dictionary) -> void:
	var p: Dictionary = s.player
	for it in p.inventory:
		prepare_egg(s, it)
	for it in p.inventory.duplicate():
		if not it.get("hatchAt") or s.turn < it.hatchAt:
			continue
		if p.pet != null:
			if it.hatchAt == s.turn or s.turn - it.hatchAt == 1:
				Log.add(s, "%s wackelt – aber du hast schon ein Haustier. Es wartet." % Identify.item_name(s, it), "info")
			continue
		var species: String = J.nn(it, "petSpecies", "Kellerraptor")
		var sp: Dictionary = Db.t("pets", "PET_SPECIES")[species]
		p.inventory = p.inventory.filter(func(x): return x.uid != it.uid)
		p.pet = make_pet_of(species, sp.name)
		p.pet.pos = _free_neighbor(s, p.pos)
		Log.add(s, "Das Ei knackt! Ein %s schlüpft, sieht dich und entscheidet: Du bist jetzt die Familie. %s" % [sp.name, sp.flavor], "system")
		Log.toast(s, "Ein Ei ist geschlüpft", sp.name, "loot")
		Events.emit(s, {"type": "petGained", "species": species, "how": "ei"})


static func prepare_egg(s: Dictionary, it: Dictionary) -> void:
	var eggs: Dictionary = Db.t("pets", "EGG_SPECIES")
	if eggs.get(it.baseId) and not it.get("hatchAt"):
		it.hatchAt = s.turn + int(Db.t("pets", "HATCH_TURNS"))
		it.petSpecies = eggs[it.baseId]


static func try_tame(s: Dictionary) -> Dictionary:
	var p: Dictionary = s.player
	if p.pet != null:
		return {"handled": false}
	var tameable: Dictionary = Db.t("pets", "TAMEABLE")
	var cand = J.find(s.monsters, func(m): return J.cheb(m.pos, p.pos) <= 1 and tameable.get(m.defId) and m.rank == "normal" and m.hp <= m.maxHp * 0.4)
	if cand == null:
		return {"handled": false}
	var chance := minf(0.95, 0.35 + (Player.effective_stats(s).cha - 5) * 0.04 + Player.skill_level(s, "tierkunde") * 0.03)
	if R.next(s) < chance:
		var species: String = tameable[cand.defId]
		s.monsters = J.without(s.monsters, cand)
		p.pet = make_pet_of(species, Db.t("pets", "PET_SPECIES")[species].name)
		p.pet.pos = J.pcopy(cand.pos)
		Log.add(s, "%s schnuppert am Leckerli, frisst es – und folgt dir ab jetzt. Du hast ein neues Haustier!" % Identify.name_of(s, cand), "system")
		Events.emit(s, {"type": "petGained", "species": species, "how": "zaehmen"})
	else:
		cand.aware = true
		Log.add(s, "%s frisst das Leckerli und beißt dir zum Dank in die Hand. Zähmen fehlgeschlagen." % Identify.name_of(s, cand), "kampf")
	return {"handled": true}


## Gegenstände mit Sonderwirkung. null = kein Sonderfall.
static func use_special(s: Dictionary, it: Dictionary) -> Variant:
	var p: Dictionary = s.player
	var tattoo = TATTOOS.get(it.baseId)
	if tattoo != null:
		if p.get("passes") == null:
			p.passes = []
		if p.passes.has(tattoo.facet):
			return {"ok": false, "message": "Dieses Tattoo hast du schon."}
		p.passes.append(tattoo.facet)
		Log.add(s, tattoo.text, "system")
		return {"ok": true}
	if it.baseId == "superkeks":
		if p.pet == null:
			Log.add(s, "Du isst den Superkeks. Er summt in deinem Magen. Nichts passiert, außer dass die Zuschauer schreien.", "info")
			return {"ok": true}
		var pet: Dictionary = p.pet
		pet.caster = true
		pet.alive = true
		for i in 3:
			pet.level += 1
			pet.maxHp += 6
			pet.dmg = [pet.dmg[0] + 1, pet.dmg[1] + 2]
		pet.hp = pet.maxHp
		PetEvo.check_evolve(s)
		Log.add(s, "%s frisst den Superkeks. Die Augen leuchten auf. %s schaut dich an – und SPRICHT: „Na endlich. Ich dachte schon, du fragst nie.“ %s kann jetzt zaubern." % [pet.name, pet.name, pet.name], "system")
		Log.toast(s, "%s ist erwacht" % pet.name, "Das Haustier spricht und wirkt Magische Geschosse.", "skill")
		return {"ok": true}
	if it.baseId == "rubbellos":
		_scratch(s)
		return {"ok": true}
	if Db.t("pets", "EGG_SPECIES").get(it.baseId):
		prepare_egg(s, it)
		return {"ok": false, "message": "Das Ei ist noch nicht so weit. Noch etwa %d Züge." % maxi(0, int(J.num(it, "hatchAt")) - s.turn)}
	return null


static func _scratch(s: Dictionary) -> void:
	var roll := R.next(s)
	var outcome: String
	if roll < 0.5:
		outcome = "niete"
		Log.add(s, "Du rubbelst … „LEIDER NICHT GEWONNEN. Versuch es noch einmal!“ Die Systemstimme kichert.", "info")
	elif roll < 0.75:
		var amount := R.int_(s, 10, 40)
		Inventory.give_item(s, Items.create_gold(s, amount))
		outcome = "gold"
		Log.add(s, "Du rubbelst … drei Münzen! Gewinn: %d Gold." % amount, "loot")
	elif roll < 0.87:
		var item := Items.generate_equipment(s, "selten" if R.chance(s, 0.3) else "ungewoehnlich")
		Inventory.give_item(s, item)
		outcome = "gegenstand"
		Log.add(s, "Du rubbelst … drei Schwerter! Gewinn: %s." % Identify.item_name(s, item), "loot")
	elif roll < 0.95:
		s.player.boxes.append(Items.create_box(s, "abenteurer", "silber" if R.chance(s, 0.3) else "bronze"))
		outcome = "box"
		Log.add(s, "Du rubbelst … drei Kisten! Gewinn: eine Lootbox.", "loot")
	elif roll < 0.99:
		var tome := Magic.random_tome(s, "selten")
		Inventory.give_item(s, tome)
		outcome = "buch"
		Log.add(s, "Du rubbelst … drei Bücher! Gewinn: %s." % Identify.item_name(s, tome), "loot")
	else:
		Inventory.give_item(s, Items.create_gold(s, 500))
		outcome = "jackpot"
		Log.add(s, "JACKPOT! Drei goldene Kronen! 500 Gold! Die Zuschauer drehen durch.", "loot")
		Log.toast(s, "Jackpot!", "500 Gold aus einem Rubbellos", "loot")
	Events.emit(s, {"type": "lottery", "outcome": outcome})


static func pet_cast(s: Dictionary, pet: Dictionary) -> Variant:
	if not pet.get("caster") or not R.chance(s, 0.35):
		return null
	var cands: Array = s.monsters.filter(func(m): return J.cheb(m.pos, pet.pos) <= 5 and m.aware and Fov.has_line_of_sight(s.map, pet.pos, m.pos))
	J.sort(cands, func(a, b): return J.cheb(a.pos, pet.pos) - J.cheb(b.pos, pet.pos))
	return cands[0] if not cands.is_empty() else null
