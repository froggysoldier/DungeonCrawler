extends RefCounted
## Beobachter, Eigenschaften und Interview (Port von tests/observer.test.ts).


func _make(answers: Dictionary = {"beruf": 1}) -> Dictionary:
	return Game.new_game({"name": "Test", "answers": answers, "seed": 1200, "meta": Meta.empty_meta()})


func _mob(s: Dictionary, id: String, level: int = 2) -> Dictionary:
	var m := Monsters.spawn_monster(s, Db.monster(id), level, {"x": s.player.pos.x + 1, "y": s.player.pos.y}, 0)
	m.aware = true
	return m


## Simuliert einen Kill mit vollem Kontext, wie ihn der Kampf erzeugt.
func _kill(s: Dictionary, m: Dictionary, tech: Dictionary) -> void:
	var facets := Observer.attack_facets(s, m, tech)
	Events.emit(s, {"type": "attack", "technique": tech, "hit": true, "crit": false, "damage": 5, "target": m, "facets": facets})
	s.counters.kills += 1
	s.counters.killsByDef[m.defId] = int(J.num(s.counters.killsByDef, m.defId)) + 1
	Events.emit(s, {"type": "kill", "monster": m, "technique": tech, "facets": facets})
	s.turn += 10


func _has_all(t, list: Array, want: Array, msg: String) -> void:
	for w in want:
		t.has(list, w, msg)


func test_facetten(t) -> void:
	var s := _make()
	var bat := _mob(s, "fledermaus")
	bat.aware = false
	_has_all(t, Observer.target_facets(s, bat), ["z:tier", "z:winzig", "z:fliegend", "z:schnell", "z:ahnungslos"], "Ziel")
	s.player.equipment.erase("fuesse")
	s.player.hp = 1
	_has_all(t, Observer.self_facets(s), ["i:barfuss", "i:fasttot"], "Zustand")
	_has_all(t, Observer.attack_facets(s, bat, {"part": "tritt", "move": "sprung"}), ["t:tritt", "m:sprung"], "Technik")


func test_ungewoehnliche_kombination(t) -> void:
	var s := _make()
	s.player.equipment.erase("fuesse")
	var before: int = s.player.boxes.size()
	_kill(s, _mob(s, "ghul", 3), {"part": "kopf", "move": "normal"})
	var dyn := J.arr(s, "dynAchievements")
	t.gt(dyn.size(), 0, "erkannt")
	t.gt(s.player.boxes.size(), before, "Box")
	t.matches(dyn[0].name, " I$")
	t.matches(dyn[0].description, "Getötet: 1")


func test_gewoehnliche_erst_bei_wiederholung(t) -> void:
	var s := _make()
	if s.player.equipment.get("fuesse") == null:
		s.player.equipment.fuesse = {"uid": "x", "baseId": "turnschuhe", "name": "Turnschuhe", "kind": "ausruestung", "rarity": "gewoehnlich", "slot": "fuesse", "flavor": "", "wert": 1}
	s.player.equipment.brust = {"uid": "y", "baseId": "hoodie", "name": "Hoodie", "kind": "ausruestung", "rarity": "gewoehnlich", "slot": "brust", "flavor": "", "wert": 1}
	s.player.hand = {"uid": "w", "baseId": "rohr", "name": "Rohr", "kind": "ausruestung", "rarity": "gewoehnlich", "slot": "waffe", "waffenSchaden": 3, "flavor": "", "wert": 1}
	_kill(s, _mob(s, "kellerratte", 1), {"part": "faust", "move": "normal"})
	t.eq(J.arr(s, "dynAchievements").size(), 0, "nicht sofort")
	for i in 20:
		_kill(s, _mob(s, "kellerratte", 1), {"part": "faust", "move": "normal"})
	t.gt(J.arr(s, "dynAchievements").size(), 0, "bei Wiederholung")


func test_stufen_aufsteigen(t) -> void:
	var s := _make()
	s.player.equipment.erase("fuesse")
	for i in 16:
		_kill(s, _mob(s, "ghul", 3), {"part": "kopf", "move": "normal"})
	t.ok(J.some(J.arr(s, "dynAchievements"), func(a): return String(a.name).ends_with(" II")), "Stufe II")


func test_dynamischer_skill(t) -> void:
	var s := _make()
	var bat := _mob(s, "fledermaus")
	var tech := {"part": "tritt", "move": "normal"}
	var before := Combat.hit_chance(s, bat, tech)
	for i in 12:
		Events.emit(s, {"type": "attack", "technique": tech, "hit": true, "crit": false, "damage": 3, "target": bat, "facets": Observer.attack_facets(s, bat, tech)})
	var dyn := J.arr(s.player, "dynSkills")
	t.not_null(J.find(dyn, func(k): return k.name == "Tritte gegen Flieger"), "Skill")
	t.gt(Combat.hit_chance(s, bat, tech), before, "Bonus")
	t.eq(dyn.filter(func(k): return k.get("part") == "faust").size(), 0, "nur für Tritte")


func test_ausweich_skill(t) -> void:
	var s := _make()
	for i in 10:
		Events.emit(s, {"type": "dodged", "source": "x", "facets": ["z:fernkampf"]})
	t.ok(J.some(J.arr(s.player, "dynSkills"), func(k): return k.kind == "ausweichen" and k.facet == "z:fernkampf"), "Ausweich-Skill")


func test_angst_ueberwinden(t) -> void:
	var calm := _make({"beruf": 1, "angst": 5})
	var scared := _make({"beruf": 1, "angst": 0})
	var tech := {"part": "faust", "move": "normal"}
	var a := _mob(calm, "kellerspinne")
	var b := _mob(scared, "kellerspinne")
	t.lt(Combat.hit_chance(scared, b, tech), Combat.hit_chance(calm, a, tech), "Angst senkt Treffer")
	t.has(scared.player.traits, "angst_krabbeltiere")
	for i in 10:
		_kill(scared, _mob(scared, "kellerspinne"), tech)
	t.has(scared.player.traits, "krabbeltier_schreck")
	t.lacks(scared.player.traits, "angst_krabbeltiere")


func test_folgefragen(t) -> void:
	var ids := func(a: Dictionary) -> Array: return Rules.visible_questions(a).map(func(q): return q.id)
	t.has(ids.call({"beruf": 0}), "handwerk")
	t.lacks(ids.call({"beruf": 0}), "sport")
	t.has(ids.call({"beruf": 5}), "sport")
	t.has(ids.call({"hobbysport": 1}), "kampfsport")
	t.lacks(ids.call({"ort": 5}), "hand")
	t.ge(Db.t("interview", "INTERVIEW").size(), 20, "Anzahl Fragen")


func test_antworten_bestimmen_start(t) -> void:
	var s := _make({"beruf": 5, "sport": 1, "hobbysport": 1, "kampfsport": 3, "ort": 5})
	t.eq(s.player.hand.baseId, "klobuerste", "Handgegenstand")
	t.has(s.player.traits, "profischlaeger")
	t.eq(s.player.background, "Profiboxer*in", "Beruf")
