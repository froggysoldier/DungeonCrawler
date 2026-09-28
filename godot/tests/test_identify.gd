extends RefCounted
## Identifikation (Port von tests/identify.test.ts).


func _make() -> Dictionary:
	return TH.make(900, [0, 0, 3, 0, 0])


func test_einschaetzung_nach_abstand(t) -> void:
	var s := _make()
	s.player.stats.int = 5
	var def: Dictionary = Db.monster("kanalkroko")
	var at := func(lv: int) -> Dictionary:
		var m := Monsters.spawn_monster(s, def, 7, s.player.pos, 0)
		m.level = lv
		return m
	s.player.level = 5
	t.eq(Identify.monster_insight(s, at.call(5)), 0, "gleich")
	t.eq(Identify.monster_insight(s, at.call(7)), 1, "+2")
	t.eq(Identify.monster_insight(s, at.call(9)), 2, "+4")
	t.eq(Identify.monster_insight(s, at.call(11)), 3, "+6")
	t.eq(Identify.monster_insight(s, at.call(14)), 4, "+9")
	var full := Identify.describe_monster(s, at.call(5))
	t.eq(full.name, "Kanal-Krokodil", "Name")
	t.matches(full.combat, "Schaden")
	t.matches(full.abilities, "gepanzert")
	var rough := Identify.describe_monster(s, at.call(9))
	t.eq(rough.name, "Kanal-Krokodil", "Name grob")
	t.is_null(rough.combat, "keine Kampfwerte")
	t.matches(rough.health, "Zustand")
	t.eq(Identify.name_of(s, at.call(11)), "ein unbekanntes großes Wesen", "unbekannt")
	t.eq(Identify.name_of(s, at.call(14)), "etwas sehr Gefährliches", "sehr gefährlich")
	t.is_null(Identify.describe_monster(s, at.call(14)).flavor, "keine Beschreibung")


func test_intelligenz_und_erfahrung(t) -> void:
	var s := _make()
	s.player.level = 5
	s.player.stats.int = 5
	var m := Monsters.spawn_monster(s, Db.monster("kanalkroko"), 7, s.player.pos, 0)
	m.level = 9
	t.eq(Identify.monster_insight(s, m), 2, "Grundwert")
	s.player.stats.int = 11
	t.eq(Identify.monster_insight(s, m), 1, "Intelligenz")
	s.counters.killsByDef["kanalkroko"] = 6
	t.eq(Identify.monster_insight(s, m), 0, "Erfahrung")


func test_seltenheit_unlesbar(t) -> void:
	var s := _make()
	s.player.level = 1
	s.player.stats.int = 5
	var epic := Items.generate_equipment(s, "episch", ["fuesse"])
	var d := Identify.describe_item(s, epic)
	t.eq(d.insight, 2, "Einsicht")
	t.eq(d.bonuses, ["Unbekannte magische Eigenschaften"], "Boni unbekannt")
	t.matches(Identify.item_name(s, epic), "Unbekannter epischer Gegenstand")
	s.player.level = 4
	t.ok(J.every(Identify.describe_item(s, epic).bonuses, func(b): return String(b).begins_with("?")), "Boni geschätzt")
	s.player.level = 6
	t.eq(Identify.describe_item(s, epic).name, epic.name, "erkannt")
