class_name Crafting
extends RefCounted
## Handwerk.

const MAX_WEAPON_UPGRADES := 3


static func has_workbench(s: Dictionary) -> bool:
	if J.some(s.player.inventory, func(i): return i.baseId == "klappwerkbank"):
		return true
	var room = MapGen.room_of(s.map, s.player.pos)
	if room == null:
		return false
	var n := String(room.name).to_lower()
	return n.contains("werkstatt") or n.contains("schmiede") or room.kind == "safe"


static func _count_of(s: Dictionary, ids: Array) -> int:
	var n := 0
	for it in s.player.inventory:
		if ids.has(it.baseId):
			n += int(J.nn(it, "menge", 1))
	return n


static func _consume(s: Dictionary, ids: Array, n: int) -> void:
	var p: Dictionary = s.player
	for it in p.inventory.duplicate():
		if n <= 0:
			break
		if not ids.has(it.baseId):
			continue
		var have: int = J.nn(it, "menge", 1)
		var take := mini(have, n)
		n -= take
		if have - take > 0:
			it.menge = have - take
		else:
			p.inventory = J.without(p.inventory, it)


static func recipe_status(s: Dictionary, r: Dictionary) -> Dictionary:
	var missing := []
	for ing in r.ingredients:
		var have := _count_of(s, ing.ids)
		if have < ing.n:
			missing.append("%dx %s" % [ing.n - have, ing.label])
	if r.get("workbench") and not has_workbench(s):
		missing.append("eine Werkbank")
	if r.get("upgradeWeapon"):
		var w = s.player.equipment.get("waffe")
		if w == null:
			missing.append("eine ausgerüstete Waffe")
		elif J.num(w, "upgrades") >= MAX_WEAPON_UPGRADES:
			missing.append("eine Waffe, die noch nicht voller Nägel steckt")
	var up = r.get("upgradeArmor")
	if up != null:
		var it = s.player.equipment.get(up.slot)
		if it == null:
			missing.append("ein angelegtes Teil am Platz %s" % Db.t("items", "SLOT_NAMES").get(up.slot, up.slot))
		elif J.num(it, "armorUpgrades") >= up.max:
			missing.append("ein Teil, das noch nicht fertig verstärkt ist")
	return {"recipe": r, "missing": missing}


static func all_recipes(s: Dictionary) -> Array:
	return Db.t("crafting", "RECIPES").map(func(r): return recipe_status(s, r))


static func craft(s: Dictionary, recipe_id: String) -> Dictionary:
	var r = Db.recipe(recipe_id)
	if r == null:
		return {"ok": false, "message": "Dieses Rezept kennst du nicht."}
	var st := recipe_status(s, r)
	if not st.missing.is_empty():
		return {"ok": false, "message": "Dir fehlt: %s." % ", ".join(st.missing)}
	for ing in r.ingredients:
		_consume(s, ing.ids, ing.n)
	s.counters.crafted += 1
	if r.get("upgradeWeapon"):
		var w: Dictionary = s.player.equipment.waffe
		w.upgrades = int(J.num(w, "upgrades")) + 1
		w.waffenSchaden = int(J.nn(w, "waffenSchaden", 2)) + 2
		if w.upgrades == 1:
			w.name = "%s (benagelt)" % w.name
		Log.add(s, "Du hämmerst Nägel in %s und wickelst Panzertape drumherum. Waffenschaden jetzt %s." % [Identify.item_name(s, w), J.s(w.waffenSchaden)], "loot")
		Events.emit(s, {"type": "crafted", "recipe": r.id})
		return {"ok": true, "item": w}
	var up = r.get("upgradeArmor")
	if up != null:
		var it: Dictionary = s.player.equipment[up.slot]
		it.armorUpgrades = int(J.num(it, "armorUpgrades")) + 1
		it.bonuses = Bonuses.add(J.nn(it, "bonuses", {}).duplicate(true), up.bonuses)
		if it.armorUpgrades == 1:
			it.name = "%s (%s)" % [it.name, up.suffix]
		Log.add(s, up.text % Identify.item_name(s, it), "loot")
		Events.emit(s, {"type": "crafted", "recipe": r.id})
		return {"ok": true, "item": it}
	var res: Dictionary = r.result
	var n: int = res.n
	if r.get("explosive") and Player.skill_level(s, "handwerk") >= 3 and R.chance(s, 0.1 + Player.skill_level(s, "handwerk") * 0.02):
		n += 1
	var item := Items.create_item(s, res.id, n)
	Inventory.add_to_inventory(s, item)
	var extra := " Es reicht sogar für ein Stück mehr." if n > res.n else ""
	Log.add(s, "Hergestellt: %s%s.%s" % [("%dx " % n) if n > 1 else "", Identify.item_name(s, item), extra], "loot")
	Events.emit(s, {"type": "crafted", "recipe": r.id})
	return {"ok": true, "item": item}
