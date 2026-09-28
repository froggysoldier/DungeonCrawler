class_name Sight
extends RefCounted
## Sieht der Crawler diese Stelle gerade?


static func player_sees(s: Dictionary, p: Dictionary) -> bool:
	var dx: int = p.x - s.player.pos.x
	var dy: int = p.y - s.player.pos.y
	var r := Player.lichtradius(s)
	if dx * dx + dy * dy > r * r:
		return false
	return Fov.has_line_of_sight(s.map, s.player.pos, p)
