extends RefCounted
## Stufenverlauf.

const THOROUGH := {"mobs": 1.0, "respawns": 0.8, "hoodBosses": 3, "borough": true}
const CASUAL := {"mobs": 0.6, "respawns": 0.3, "hoodBosses": 1, "borough": false}


## Spielt drei Etagen „auf dem Papier“: Kills in sinnvoller Reihenfolge, dann Abstieg.
func _run(seed: int, style: Dictionary) -> Array:
	var s := Game.new_game({"name": "Sim", "answers": {"beruf": 1}, "seed": seed, "meta": Meta.empty_meta()})
	var levels := []
	for floor in range(1, 4):
		var mobs: Array = s.monsters.filter(func(m): return m.rank == "normal" or m.rank == "elite")
		J.sort(mobs, func(a, b): return a.level - b.level)
		var take := J.rnd(mobs.size() * style.mobs)
		for m in mobs.slice(0, take):
			Combat.kill_monster(s, m, null)
		var def := Db.floor_def(floor)
		var extra := J.rnd(mobs.size() * style.respawns)
		for i in extra:
			var m := Monsters.spawn_for_floor(s, floor, R.int_(s, def.mobLevel[0], def.mobLevel[1]), {"x": 1, "y": 1}, 0, false)
			s.monsters.append(m)
			Combat.kill_monster(s, m, null)
		var bosses: Array = s.monsters.filter(func(m): return m.rank == "nachbarschaftsboss").slice(0, style.hoodBosses)
		for b in bosses:
			Combat.kill_monster(s, b, null)
		if style.borough:
			var b = J.find(s.monsters, func(m): return m.rank == "boroughboss")
			if b != null:
				Combat.kill_monster(s, b, null)
		levels.append(s.player.level)
		if floor < 3:
			TH.teleport(s, TH.stairs(s))
			Game.descend(s, {"ghosts": []})
			if s.pendingSelection:
				Classes.choose(s, "elf", Classes.class_options(s)[0].klass.id)
	return levels


func _avg(all: Array, i: int) -> float:
	var sum := 0.0
	for l in all:
		sum += l[i]
	return sum / all.size()


func test_erfahrung_nach_stufenabstand(t) -> void:
	t.lt(Progression.level_diff_factor(-6), Progression.level_diff_factor(-2), "niedriger weniger")
	t.eq(Progression.level_diff_factor(0), 1.0, "gleich")
	t.gt(Progression.level_diff_factor(3), 1.0, "höher mehr")
	var s := Game.new_game({"name": "A", "answers": {"beruf": 1}, "seed": 5, "meta": Meta.empty_meta()})
	var m = J.find(s.monsters, func(x): return x.rank == "normal")
	s.player.level = m.level + 6
	t.eq(Progression.kill_xp(s, m).challenge, "trivial", "trivial")
	s.player.level = maxi(1, m.level - 4)
	t.gt(Progression.kill_xp(s, m).xp, m.xp, "Bonus")
	t.gt(Progression.xp_to_next(5), Progression.xp_to_next(4) * 1.3, "Kurve")


func test_gruendliche_crawler(t) -> void:
	var all := [11, 22, 33, 44, 55].map(func(seed): return _run(seed, THOROUGH))
	t.ge(_avg(all, 0), 4.0, "Etage 1 ab")
	t.le(_avg(all, 0), 6.0, "Etage 1 bis")
	t.ge(_avg(all, 1), 6.5, "Etage 2 ab")
	t.le(_avg(all, 1), 9.0, "Etage 2 bis")
	t.ge(_avg(all, 2), 9.5, "Etage 3 ab")
	t.le(_avg(all, 2), 13.0, "Etage 3 bis")


func test_vorsichtige_crawler(t) -> void:
	var all := [11, 22, 33, 44, 55].map(func(seed): return _run(seed, CASUAL))
	t.ge(_avg(all, 0), 2.5, "Etage 1 ab")
	t.le(_avg(all, 0), 4.5, "Etage 1 bis")
	t.ge(_avg(all, 2), 7.0, "Etage 3 ab")
	t.le(_avg(all, 2), 11.0, "Etage 3 bis")
