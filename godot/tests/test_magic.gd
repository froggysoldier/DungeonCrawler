extends RefCounted
## Magie, Tränke, Toiletten-Regel.


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


func test_toilette_nur_an_einer_toilette(t) -> void:
	var s := _make()
	s.player.blase = 70
	t.ok(not Game.toilet(s).ok, "ohne Toilette nicht")
	var safe = TH.room(s, "safe")
	var f = J.find(safe.furniture, func(x): return x.kind == "toilette")
	s.monsters = []
	s.player.pos = MapGen.free_beside(s.map, f.pos)
	t.ok(Game.toilet(s).ok, "neben der Toilette im Safe Room")
	t.lt(s.player.blase, 1, "erleichtert")


func test_blase_fuellt_sich(t) -> void:
	var s := _make()
	s.monsters = []
	var before := J.num(s.player, "blase")
	for i in 60:
		Game.wait(s)
	t.gt(s.player.blase, before + 8, "gefüllt")


## Neue Zauber: jeder lässt sich wirken und tut, was er soll.
func _caster(id: String) -> Array:
	var s := TH.make(1510, {"beruf": 1})
	var m := TH.foe(s, "ghul", 2)
	m.hp = 500
	m.maxHp = 500
	m.ruestung = 4
	Magic.learn_spell(s, id, true)
	s.player.stats.int = 12
	s.player.mp = 40
	return [s, m]


func test_neue_zauber(t) -> void:
	for id in ["frostnadel", "blitzkette", "saeurespritzer", "blenden"]:
		var sm := _caster(id)
		var s: Dictionary = sm[0]
		var m: Dictionary = sm[1]
		t.ok(Game.cast(s, id, {"targetUid": m.uid}).ok, "%s gewirkt" % id)
	var fr := _caster("frostnadel")
	Game.cast(fr[0], "frostnadel", {"targetUid": fr[1].uid})
	t.lt(fr[1].hp, 500, "Frostnadel trifft")
	t.gt(int(J.num(fr[1], "slowed")), 0, "verlangsamt")
	var sa := _caster("saeurespritzer")
	Game.cast(sa[0], "saeurespritzer", {"targetUid": sa[1].uid})
	t.eq(sa[1].ruestung, 2, "Rüstung zersetzt")
	var bk := _caster("blitzkette")
	var s2: Dictionary = bk[0]
	var second := Monsters.spawn_monster(s2, Db.monster("ghul"), 2, {"x": bk[1].pos.x + 1, "y": bk[1].pos.y}, 0)
	if MapGen.is_walkable(s2.map, second.pos.x, second.pos.y):
		second.hp = 500
		s2.monsters.append(second)
		Game.cast(s2, "blitzkette", {"targetUid": bk[1].uid})
		t.lt(second.hp, 500, "Blitz springt über")


func test_selbstzauber(t) -> void:
	var sm := _caster("donnerschlag")
	var s: Dictionary = sm[0]
	var m: Dictionary = sm[1]
	m.pos = TH.free_neighbor(s, s.player.pos)
	t.ok(Game.cast(s, "donnerschlag").ok, "Donnerschlag")
	t.lt(m.hp, 500, "Schaden ringsum")
	for id in ["regeneration", "steinhaut", "schreck"]:
		var s3: Dictionary = _caster(id)[0]
		var armor: float = J.num(Player.total_bonuses(s3), "ruestung")
		t.ok(Game.cast(s3, id).ok, "%s gewirkt" % id)
		if id == "steinhaut":
			t.gt(J.num(Player.total_bonuses(s3), "ruestung"), armor, "mehr Rüstung")
		if id == "regeneration":
			t.gt(J.num(Player.total_bonuses(s3), "hpRegen"), 0, "Regeneration")
	for sp in Db.t("spells", "SPELLS"):
		t.ok(Magic.TOME_VALUE.has(sp.rarity), "%s: Seltenheit" % sp.id)
