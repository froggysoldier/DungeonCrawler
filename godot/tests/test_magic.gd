extends RefCounted
## Magie, Tränke, Toiletten-Regel (Port von tests/magic.test.ts).


func _make() -> Dictionary:
	var s := TH.make(1500, {"beruf": 1})
	TH.tutorial(s)
	return s


func test_tutorial_schenkt_heilzauber(t) -> void:
	var s := _make()
	t.has(J.arr(s.player, "spells").map(func(k): return k.id), "heilen")
	t.eq(s.player.mp, Magic.max_mp(s), "Mana voll")


func test_heilen(t) -> void:
	var s := _make()
	s.player.hp = 3
	var mp: int = s.player.mp
	t.ok(Game.cast(s, "heilen").ok, "zaubern")
	t.gt(s.player.hp, 3, "geheilt")
	t.eq(s.player.mp, mp - 2, "Mana")
	t.ok(not Game.cast(s, "heilen").ok, "Abklingzeit")


func test_zauberbuecher(t) -> void:
	var s := _make()
	var book := Magic.create_tome(s, "geschoss")
	s.player.inventory.append(book)
	t.ok(Game.use_item(s, book.uid).ok, "lesen")
	t.ok(J.some(s.player.spells, func(k): return k.id == "geschoss"), "gelernt")
	t.ok(not J.some(s.player.inventory, func(i): return i.uid == book.uid), "verbraucht")


func test_geschoss_mehr_mana_mehr_schaden(t) -> void:
	var s := _make()
	Magic.learn_spell(s, "geschoss", true)
	s.player.stats.int = 20
	s.player.mp = 20
	var a := TH.beside(s, "moorleiche")
	a.maxHp = 500
	a.hp = 500
	Game.cast(s, "geschoss", {"targetUid": a.uid, "mana": 3})
	var low: int = 500 - a.hp
	s.player.spellCooldowns = {}
	a.hp = 500
	Game.cast(s, "geschoss", {"targetUid": a.uid, "mana": 6})
	var high: int = 500 - a.hp
	t.gt(high, low, "mehr Schaden")
	t.ok(not Game.cast(s, "geschoss", {"mana": 3}).ok, "ohne Ziel")


func test_irrlichtruestung(t) -> void:
	var s := _make()
	Magic.learn_spell(s, "irrlichtruestung", true)
	s.player.mp = 10
	Game.cast(s, "irrlichtruestung")
	var m := TH.beside(s, "kobold")
	m.treffer = 999
	m.dmg = [3, 3]
	var hp: int = s.player.hp
	Ai.monster_turn(s, m)
	t.eq(s.player.hp, hp, "Schaden abgefangen")


func test_heiltraenke(t) -> void:
	var s := _make()
	s.player.hp = 1
	var a := Items.create_item(s, "heiltrank", 2)
	s.player.inventory.append(a)
	t.ok(Game.use_item(s, a.uid).ok, "trinken")
	t.ge(s.player.hp, 1 + 10, "Hälfte geheilt")
	t.ok(not Game.use_item(s, a.uid).ok, "Abklingzeit")


func test_unfall_ruft_wutelementar(t) -> void:
	var s := _make()
	s.monsters = []
	Bladder.add(s, 100)
	t.ok(J.some(s.monsters, func(m): return m.defId == "wutelementar"), "Wutelementar")
	t.eq(s.player.blase, 0, "Blase leer")


func test_toilette_nur_im_safe_room(t) -> void:
	var s := _make()
	s.player.blase = 70
	t.ok(not Game.toilet(s).ok, "draußen nicht")
	var safe = TH.room(s, "safe")
	s.player.pos = {"x": safe.x + 1, "y": safe.y + 1}
	Game.move_step(s, {"x": safe.x + 2, "y": safe.y + 1})
	t.ok(Game.toilet(s).ok, "im Safe Room")
	t.lt(s.player.blase, 1, "erleichtert")


func test_blase_fuellt_sich(t) -> void:
	var s := _make()
	s.monsters = []
	var before := J.num(s.player, "blase")
	for i in 60:
		Game.wait(s)
	t.gt(s.player.blase, before + 8, "gefüllt")
