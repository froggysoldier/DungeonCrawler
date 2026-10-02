class_name PetEvo
extends RefCounted
## Haustier-Entwicklung und Halsband.


static func _forms() -> Dictionary:
	return Db.t("pets", "PET_FORMS")


static func evolve_stage(pet: Dictionary) -> int:
	if not pet.get("form"):
		return 0
	var f = _forms().get(pet.form)
	return 1 if f != null and f.get("next") else 2


static func evolve_options(pet: Dictionary) -> Array:
	var stage := evolve_stage(pet)
	if stage == 0:
		var paths: Dictionary = Db.t("pets", "PET_PATHS")
		return paths.get(pet.species, paths.Katze).map(func(id): return _forms()[id])
	if stage == 1:
		return [_forms()[_forms()[pet.form].next]]
	return []


static func check_evolve(s: Dictionary) -> void:
	var pet = s.player.pet
	if pet == null or pet.get("evolveReady"):
		return
	var stage := evolve_stage(pet)
	if stage >= 2 or pet.level < Db.t("pets", "EVOLVE_LEVELS")[stage]:
		return
	pet.evolveReady = true
	Log.add(s, "%s glüht und zittert. Eine ENTWICKLUNG ist möglich! (Crawler-Tab)" % pet.name, "system")
	Log.toast(s, "%s kann sich entwickeln" % pet.name, "Wähle im Crawler-Tab.", "skill")


static func evolve(s: Dictionary, form_id: String) -> Dictionary:
	var pet = s.player.pet
	if pet == null:
		return {"ok": false, "message": "Du hast kein Haustier."}
	if not pet.get("evolveReady"):
		return {"ok": false, "message": "%s ist noch nicht so weit." % pet.name}
	var form = J.find(evolve_options(pet), func(f): return f.id == form_id)
	if form == null:
		return {"ok": false, "message": "Diese Entwicklung passt nicht."}
	pet.form = form.id
	pet.evolveReady = false
	pet.maxHp += form.hp
	pet.hp = pet.maxHp
	pet.dmg = [pet.dmg[0] + form.dmg[0], pet.dmg[1] + form.dmg[1]]
	pet.abilities = J.uniq(J.arr(pet, "abilities") + [form.ability])
	var stage := evolve_stage(pet)
	var ab: Dictionary = Db.t("pets", "PET_ABILITIES")[form.ability]
	Log.add(s, "%s entwickelt sich zu: %s! %s Neue Fähigkeit: %s." % [pet.name, form.name, form.flavor, ab.name], "system")
	Log.toast(s, "%s: %s" % [pet.name, form.name], ab.text, "skill")
	Events.emit(s, {"type": "petEvolved", "form": form.id, "stage": stage})
	check_evolve(s)
	return {"ok": true}


static func form_name(pet: Dictionary) -> String:
	var sp = Db.t("pets", "PET_SPECIES").get(pet.species)
	var species: String = sp.name if sp != null else pet.species
	if pet.get("form"):
		var f = _forms().get(pet.form)
		return "%s (%s)" % [f.name if f != null else species, species]
	return species


static func equip_gear(s: Dictionary, uid: String) -> Dictionary:
	var p: Dictionary = s.player
	var pet = p.pet
	if pet == null:
		return {"ok": false, "message": "Du hast kein Haustier."}
	var it = J.find(p.inventory, func(i): return i.uid == uid)
	if it == null or it.get("petBonus") == null:
		return {"ok": false, "message": "Das ist kein Halsband."}
	var gear: Dictionary = it
	if int(J.nn(it, "menge", 1)) > 1:
		it.menge = int(J.nn(it, "menge", 1)) - 1
		s.uidCounter += 1
		gear = it.duplicate()
		gear.uid = "i%d" % s.uidCounter
		gear.menge = 1
	else:
		p.inventory = J.without(p.inventory, it)
	if pet.get("gear") != null:
		remove_gear(s)
	pet.gear = gear
	pet.maxHp += int(J.num(gear.petBonus, "hp"))
	pet.hp += int(J.num(gear.petBonus, "hp"))
	Log.add(s, "%s trägt jetzt: %s. Es sieht sehr zufrieden aus." % [pet.name, Identify.item_name(s, gear)], "info")
	return {"ok": true}


static func remove_gear(s: Dictionary) -> Dictionary:
	var pet = s.player.pet
	if pet == null or pet.get("gear") == null:
		return {"ok": false, "message": "Das Haustier trägt nichts."}
	var gear: Dictionary = pet.gear
	pet.erase("gear")
	pet.maxHp -= int(J.num(gear.get("petBonus"), "hp"))
	pet.hp = maxi(1, mini(pet.hp, pet.maxHp))
	Inventory.add_to_inventory(s, gear)
	return {"ok": true}


static func pet_bite_bonus(s: Dictionary) -> int:
	var pet = s.player.pet
	if pet == null:
		return 0
	var bonus := 0
	if pet.get("gear") != null:
		bonus = int(J.num(pet.gear.get("petBonus"), "dmg"))
	if J.arr(pet, "abilities").has("giftbiss"):
		bonus += 2 + floori(pet.level / 3.0)
	return bonus


## Sonderfähigkeiten vor dem normalen Zug. true = Zug verbraucht.
static func pet_ability_turn(s: Dictionary, pet: Dictionary, kill_fn: Callable) -> bool:
	var ab := J.arr(pet, "abilities")
	if ab.is_empty():
		return false
	var p: Dictionary = s.player
	var adjacent: Array = s.monsters.filter(func(m): return J.cheb(m.pos, pet.pos) <= 1)
	if ab.has("lecken") and p.hp < Player.max_hp(s) and J.cheb(pet.pos, p.pos) <= 2 and s.turn - int(J.nn(pet, "lastHeal", -99)) >= 12:
		pet.lastHeal = s.turn
		var heal := 2 + floori(pet.level / 2.0)
		p.hp = mini(Player.max_hp(s), p.hp + heal)
		Log.add(s, "%s kümmert sich um deine Wunden. +%d HP." % [pet.name, heal], "info")
		return true
	if ab.has("feuerodem") and R.chance(s, 0.25):
		var targets: Array = s.monsters.filter(func(m): return J.cheb(m.pos, pet.pos) <= 2 and m.aware)
		if not targets.is_empty():
			var dmg: int = pet.level + 3
			Log.add(s, "%s speit Feuer!" % pet.name, "kampf")
			for m in targets:
				m.hp -= maxi(1, dmg - floori(m.ruestung / 2.0))
				Log.add(s, "Die Flammen treffen %s." % Identify.name_of(s, m), "kampf")
				if m.hp <= 0:
					kill_fn.call(m)
			return true
	var foe = J.find(adjacent, func(m): return m.rank == "normal" or m.rank == "elite")
	if foe != null and ab.has("fauchen") and foe.rank == "normal" and not foe.get("fleeing") and R.chance(s, 0.2):
		foe.fleeing = true
		Log.add(s, "%s faucht %s an. Der Gegner ergreift die Flucht." % [pet.name, Identify.name_of(s, foe)], "kampf")
		return true
	if foe != null and (ab.has("bellen") or ab.has("netz")) and foe.downed <= 0 and foe.size != "riesig" and not J.arr(foe, "abilities").has("fliegend") and R.chance(s, 0.2):
		foe.downed = 2
		if ab.has("netz"):
			Log.add(s, "%s spinnt %s in ein Netz. Der Gegner liegt am Boden." % [pet.name, Identify.name_of(s, foe)], "kampf")
		else:
			Log.add(s, "%s springt %s an und reißt ihn um!" % [pet.name, Identify.name_of(s, foe)], "kampf")
		return true
	return false
