extends RefCounted
## Haustier-Entwicklung (Port von tests/petevo.test.ts).


func _make() -> Dictionary:
	return TH.make(7100, {"beruf": 1, "haustier": 1})


func test_entwicklungswege(t) -> void:
	var s := _make()
	var pet: Dictionary = s.player.pet
	t.eq(pet.species, "Hund", "Hund")
	t.ok(not Game.evolve_pet_to(s, "wachhund").ok, "noch nicht")
	while pet.level < 4:
		Ai.pet_level_up(s)
	t.eq(pet.get("evolveReady"), true, "bereit")
	var hp: int = pet.maxHp
	t.ok(not Game.evolve_pet_to(s, "reisser").ok, "falscher Weg")
	t.ok(Game.evolve_pet_to(s, "spuernase").ok, "Spürnase")
	t.gt(pet.maxHp, hp, "mehr HP")
	t.has(pet.abilities, "spaeher")
	t.ge(J.num(Player.total_bonuses(s), "lichtradius"), 1.0, "Sichtweite")
	t.has(s.achievements, "evolution")
	while pet.level < 8:
		Ai.pet_level_up(s)
	t.ok(Game.evolve_pet_to(s, "rettungshund").ok, "Endform")
	t.has(pet.abilities, "spaeher")
	t.has(pet.abilities, "lecken")
	t.has(s.achievements, "endform")


func test_halsbaender(t) -> void:
	var s := _make()
	var pet: Dictionary = s.player.pet
	s.unlocks.append("inventar")
	var collar := Items.create_item(s, "halsband_stachel")
	s.player.inventory.append(collar)
	var hp: int = pet.maxHp
	t.ok(Game.pet_gear_on(s, collar.uid).ok, "anlegen")
	t.eq(pet.maxHp, hp + 8, "mehr HP")
	t.ok(Game.pet_gear_off(s).ok, "abnehmen")
	t.eq(pet.maxHp, hp, "zurück")
	t.ok(J.some(s.player.inventory, func(i): return i.baseId == "halsband_stachel"), "wieder im Rucksack")


func test_doppelbiss(t) -> void:
	var s := _make()
	var pet: Dictionary = s.player.pet
	pet.abilities = ["doppelbiss"]
	pet.dmg = [5, 5]
	var spot = null
	for d in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
		var q := {"x": pet.pos.x + d[0], "y": pet.pos.y + d[1]}
		if MapGen.is_walkable(s.map, q.x, q.y) and not (q.x == s.player.pos.x and q.y == s.player.pos.y):
			spot = q
			break
	var m := Monsters.spawn_monster(s, Db.monster("ghul"), 3, spot, 0)
	m.hp = 500
	m.maxHp = 500
	m.ruestung = 0
	s.monsters = [m]
	var before: int = s.log.size()
	for i in 6:
		Ai.pet_turn(s)
	var bites: int = s.log.slice(before).filter(func(l): return String(l.text).contains("beißt")).size()
	t.gt(bites, 6, "zweimal pro Zug")
