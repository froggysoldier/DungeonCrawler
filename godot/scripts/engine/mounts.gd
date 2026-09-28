class_name Mounts
extends RefCounted
## Reittiere und Fahrzeuge.


static func mount_def(s: Dictionary) -> Variant:
	var m = s.player.get("mount")
	return Db.t("mounts", "MOUNTS").get(m.id) if m != null else null


static func is_riding(s: Dictionary) -> bool:
	var m = s.player.get("mount")
	return s.player.get("riding") and m != null and not m.get("down")


static func is_mount_item(it: Dictionary) -> bool:
	return Db.t("mounts", "MOUNT_ITEMS").has(it.baseId)


static func gain_mount(s: Dictionary, it: Dictionary) -> Dictionary:
	var id = Db.t("mounts", "MOUNT_ITEMS").get(it.baseId)
	var def = Db.t("mounts", "MOUNTS").get(id) if id != null else null
	if def == null:
		return {"ok": false, "message": "Das ist kein Reittier."}
	var p: Dictionary = s.player
	if p.get("mount") != null:
		Log.add(s, "%s verabschiedet sich. Man kann nur ein Reittier gleichzeitig haben." % p.mount.name, "info")
	p.mount = Items.compact({"id": id, "name": def.name, "hp": def.hp, "maxHp": def.hp, "fuel": def.get("fuel")})
	p.riding = false
	p.mountSteps = 0
	Log.add(s, "%s gehört jetzt dir! %s (Aufsitzen im Crawler-Tab oder mit M.)" % [def.name, def.flavor], "system")
	Log.toast(s, "Neues Reittier", def.name, "loot")
	Events.emit(s, {"type": "mountGained", "id": id})
	return {"ok": true}


static func toggle_ride(s: Dictionary) -> Dictionary:
	var p: Dictionary = s.player
	var m = p.get("mount")
	if m == null:
		return {"ok": false, "message": "Du hast kein Reittier."}
	if p.get("riding"):
		p.riding = false
		Log.add(s, "Du steigst von %s ab. Das System verwahrt es für dich." % m.name, "info")
		return {"ok": true}
	if m.get("down"):
		return {"ok": false, "message": "%s muss sich erst erholen. Schlaf in einem Safe Room." % m.name}
	var r = MapGen.room_of(s.map, p.pos)
	if r != null and r.kind == "safe":
		return {"ok": false, "message": "Im Safe Room wird nicht geritten. Der Türsteher war da sehr deutlich."}
	if m.get("fuel") != null and m.fuel <= 0:
		return {"ok": false, "message": "Der Tank ist leer. Du brauchst einen Benzinkanister."}
	p.riding = true
	p.mountSteps = 0
	Log.add(s, "Du steigst auf %s. Los geht’s!" % m.name, "info")
	return {"ok": true}


static func refuel(s: Dictionary) -> Dictionary:
	var p: Dictionary = s.player
	var m = p.get("mount")
	var def = mount_def(s)
	if m == null or def == null or def.kind != "fahrzeug":
		return {"ok": false, "message": "Du hast kein Fahrzeug."}
	var can = J.find(p.inventory, func(i): return i.baseId == "benzinkanister")
	if can == null:
		return {"ok": false, "message": "Du hast keinen Benzinkanister."}
	if int(J.nn(can, "menge", 1)) > 1:
		can.menge = int(J.nn(can, "menge", 1)) - 1
	else:
		p.inventory = J.without(p.inventory, can)
	m.fuel = mini(int(J.nn(def, "fuel", 0)), int(J.nn(m, "fuel", 0)) + 90)
	Log.add(s, "Du tankst %s. Tank: %d von %s." % [m.name, m.fuel, J.s(def.get("fuel"))], "info")
	return {"ok": true}


## Nach einem Schritt: verbraucht Benzin; gibt zurück, ob der Zug endet.
static func mount_step(s: Dictionary) -> bool:
	if not is_riding(s):
		return true
	var p: Dictionary = s.player
	var m: Dictionary = p.mount
	var def: Dictionary = mount_def(s)
	Skills.train_skill(s, "ride", 0.3)
	if m.get("fuel") != null:
		var saving := minf(0.75, Player.skill_level(s, "reiten") * 0.05) + (0.5 if Abilities.has_special(s, "schrauber") else 0.0)
		if not R.chance(s, minf(0.9, saving)):
			m.fuel -= 1
		if m.fuel <= 0:
			m.fuel = 0
			p.riding = false
			Log.add(s, "%s stottert und bleibt stehen. Tank leer. Du steigst ab." % m.name, "gefahr")
			return true
		if m.fuel == 20:
			Log.add(s, "%s: Der Tank ist fast leer." % m.name, "gefahr")
	p.mountSteps = int(J.num(p, "mountSteps")) + 1
	return p.mountSteps % maxi(1, def.speed) == 0


static func dismount_for_safe_room(s: Dictionary) -> void:
	if not is_riding(s):
		return
	s.player.riding = false
	Log.add(s, "Du steigst von %s ab. Reittiere müssen draußen bleiben – das System verwahrt es." % s.player.mount.name, "info")


static func mount_absorbs(s: Dictionary, dmg: int, source: String) -> bool:
	if not is_riding(s) or not R.chance(s, 0.35):
		return false
	var p: Dictionary = s.player
	var m: Dictionary = p.mount
	var def: Dictionary = mount_def(s)
	var armor := (0.3 if Abilities.has_special(s, "schrauber") else 0.0) + (0.25 if Abilities.has_special(s, "sattelfest") else 0.0)
	dmg = maxi(1, J.rnd(dmg * (1 - minf(0.6, Player.skill_level(s, "reiten") * 0.04)) * (1 - armor)))
	m.hp -= dmg
	Log.add(s, "%s trifft %s für %d Schaden." % [source, m.name, dmg], "kampf")
	if m.hp > 0:
		return true
	p.riding = false
	if def.kind == "fahrzeug":
		p.erase("mount")
		Inventory.add_to_inventory(s, Items.create_item(s, "schraubenmutter", 4))
		Log.add(s, "%s fällt auseinander. Totalschaden. Du rettest ein paar Schraubenmuttern." % m.name, "gefahr")
	else:
		m.hp = 0
		m.down = true
		Log.add(s, "%s bricht zusammen und wird vom System weggebeamt. Nach dem Schlafen ist es wieder da." % m.name, "gefahr")
	Events.emit(s, {"type": "mountLost", "id": def.id})
	return true


static func rest_mount(s: Dictionary) -> void:
	var m = s.player.get("mount")
	if m == null:
		return
	m.down = false
	m.hp = m.maxHp


static func fuel_max(s: Dictionary) -> int:
	var d = mount_def(s)
	return int(J.nn(d, "fuel", 0)) if d != null else 0


static func ram_bonus(s: Dictionary) -> float:
	if not is_riding(s):
		return 0.0
	var d = mount_def(s)
	return J.num(d, "ram") if d != null else 0.0
