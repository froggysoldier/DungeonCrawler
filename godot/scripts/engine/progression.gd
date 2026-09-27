class_name Progression
extends RefCounted
## Erfahrung und Stufen (Port von src/engine/progression.ts).

const XP_BASE := 60
const XP_EXPONENT := 1.75

const CHALLENGES := {
	"trivial": {"name": "harmlos", "color": "#8f8a82", "hint": "kaum Erfahrung"},
	"leicht": {"name": "leicht", "color": "#6ee07a", "hint": "wenig Erfahrung"},
	"passend": {"name": "ebenbürtig", "color": "#f0e2a8", "hint": "normale Erfahrung"},
	"fordernd": {"name": "fordernd", "color": "#ffb04a", "hint": "viel Erfahrung"},
	"gefaehrlich": {"name": "gefährlich", "color": "#ff5a4a", "hint": "sehr viel Erfahrung"},
	"toedlich": {"name": "tödlich", "color": "#d070ff", "hint": "enorm viel Erfahrung"},
}

const DIFF_TABLE := {-5: 0.1, -4: 0.2, -3: 0.35, -2: 0.55, -1: 0.8, 0: 1.0, 1: 1.15, 2: 1.3, 3: 1.5, 4: 1.7, 5: 1.85}


static func xp_to_next(level: int) -> int:
	return J.rnd(XP_BASE * pow(level, XP_EXPONENT))


static func total_xp_for(level: int) -> int:
	var sum := 0
	for l in range(1, level):
		sum += xp_to_next(l)
	return sum


static func challenge_of(diff: int) -> String:
	if diff <= -5:
		return "trivial"
	if diff <= -2:
		return "leicht"
	if diff <= 1:
		return "passend"
	if diff <= 3:
		return "fordernd"
	if diff <= 5:
		return "gefaehrlich"
	return "toedlich"


static func level_diff_factor(diff: int) -> float:
	if diff <= -6:
		return 0.05
	if diff >= 6:
		return 2.0
	return DIFF_TABLE[diff]


static func kill_xp(s: Dictionary, m: Dictionary) -> Dictionary:
	var diff := int(m.level) - int(s.player.level)
	return {"xp": maxi(1, J.rnd(m.xp * level_diff_factor(diff))), "diff": diff, "challenge": challenge_of(diff)}


static func level_gap_hit(attacker_level: int, defender_level: int) -> float:
	var d := defender_level - attacker_level
	if d > 2:
		return -mini(20, (d - 2) * 3)
	if d < -2:
		return mini(10, (-d - 2) * 2)
	return 0
