extends RefCounted
## Rückblick und Talkshow (Port von tests/talkshow.test.ts).


func test_rueckblick_und_talkshow(t) -> void:
	var s := TH.make(4100, {"beruf": 1, "haustier": 0})
	TH.tutorial(s)
	s.counters.kills += 12
	s.pendingDialogs = []
	TH.teleport(s, TH.stairs(s))
	Game.descend(s, {"ghosts": []})
	t.eq(s.pendingDialogs[0].title, "Rückblick: Etage 1", "Rückblick 1")
	t.ok(" ".join(s.pendingDialogs[0].pages).contains("12 Gegner besiegt"), "Kills im Rückblick")
	t.ok(not J.some(s.pendingDialogs, func(d): return d.get("kind") == "talkshow"), "noch keine Talkshow")
	s.pendingDialogs = []
	TH.teleport(s, TH.stairs(s))
	Game.descend(s, {"ghosts": []})
	t.eq(s.pendingDialogs[0].title, "Rückblick: Etage 2", "Rückblick 2")
	t.not_null(J.find(s.pendingDialogs, func(d): return d.get("kind") == "talkshow"), "Talkshow")
	t.eq(s.talkShow.questions.size(), 3, "drei Fragen")
	t.has(s.talkShow.questions.map(func(q): return q.id), "haustier")
	var res := Game.answer_talk_show(s, 0)
	t.ok(res.ok, "Antwort 1")
	res = Game.answer_talk_show(s, 1)
	res = Game.answer_talk_show(s, 0)
	t.eq(res.get("finished"), true, "fertig")
	t.has(s.achievements, "primetime")
	t.ok(not Game.answer_talk_show(s, 0).ok, "vorbei")
