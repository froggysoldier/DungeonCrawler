extends RefCounted
## Sponsoren.


func _stomp_kill(s: Dictionary) -> void:
	var m := Monsters.spawn_monster(s, Db.monster("kellerratte"), 1, {"x": 1, "y": 1}, 0)
	Events.emit(s, {"type": "kill", "monster": m, "technique": {"part": "tritt", "move": "stampfen"}, "facets": ["t:tritt", "m:stampfen", "z:ratte"]})


func test_ohne_publikum_niemand(t) -> void:
	var s := TH.make(5100, {"beruf": 1})
	for i in 30:
		_stomp_kill(s)
	t.ok(J.every(Sponsors.states(s), func(x): return x.status == "none"), "kein Interesse")


func test_sponsor_ablauf(t) -> void:
	var s := TH.make(5100, {"beruf": 1})
	s.unlocks.append("zuschauer")
	s.viewers.follower = 500
	s.viewers.hype = 50
	for i in 30:
		_stomp_kill(s)
	var vornex = J.find(Sponsors.states(s), func(x): return x.id == "vornex")
	t.eq(vornex.status, "offer", "Angebot")
	t.ok(Game.accept_sponsor_offer(s, "vornex").ok, "angenommen")
	var boxes: int = s.player.boxes.size()
	for i in 4:
		_stomp_kill(s)
	t.eq(vornex.completed, 1, "Wunsch erfüllt")
	t.gt(s.player.boxes.size(), boxes, "Box")
	t.has(s.achievements, "sponsor_wunsch")
	for i in 10:
		Events.emit(s, {"type": "trapTriggered", "kind": "pfeilplatte", "onPlayer": true})
	t.eq(vornex.status, "dropped", "Gunst verspielt")


func test_neue_sponsoren_reagieren(t) -> void:
	var s := TH.make(3301, {"beruf": 1})
	s.unlocks.append("zuschauer")
	s.viewers.follower = 500
	for i in 40:
		Events.emit(s, {"type": "crateSmashed"})
		Events.emit(s, {"type": "spellCast", "spell": "geschoss", "kills": 0})
		Events.emit(s, {"type": "dodged", "source": "x", "facets": []})
	var st := func(id: String) -> Dictionary: return J.find(Sponsors.states(s), func(x): return x.id == id)
	t.ok(st.call("tiefgrabe").interest > 0 or st.call("tiefgrabe").status != "none", "Tiefgrabe mag Kisten")
	t.ok(st.call("arkanum").interest > 0 or st.call("arkanum").status != "none", "Arkanum mag Zauber")
	t.ok(st.call("ballsaal_zirr").interest > 0 or st.call("ballsaal_zirr").status != "none", "Zirr mag Ausweichen")
	t.has(Sponsors.signals_of({"type": "questDone", "kind": "retten"}), "quest|retten")
	t.has(Sponsors.signals_of({"type": "bossDodged"}), "boss|dodge")
	# Jeder Wunsch nennt nur Signale, die das Spiel auch sendet
	var known := {}
	for e in [{"type": "spellCast", "spell": "x"}, {"type": "dodged"}, {"type": "bossDodged"}, {"type": "crateSmashed"}, {"type": "secretFound"}, {"type": "lockPicked"}, {"type": "treasureFound"}, {"type": "nestCleared"}, {"type": "prayed"}, {"type": "questDone", "kind": "retten"}, {"type": "questDone", "kind": "liefern"}, {"type": "questDone", "kind": "finden"}, {"type": "questFailed"}, {"type": "chainDone"}]:
		for sig in Sponsors.signals_of(e):
			known[sig] = true
	for id in ["arkanum", "tiefgrabe", "ballsaal_zirr", "siebter_mond", "sternfracht"]:
		var def: Dictionary = Db.sponsor(id)
		for w in def.wishes:
			for sig in w.signals:
				t.ok(known.has(sig) or String(sig).begins_with("kill|"), "%s: %s" % [id, sig])
