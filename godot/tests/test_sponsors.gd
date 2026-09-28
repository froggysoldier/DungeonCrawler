extends RefCounted
## Sponsoren (Port von tests/sponsors.test.ts).


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
