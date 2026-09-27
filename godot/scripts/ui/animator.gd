class_name Animator
extends RefCounted
## Weiche Bewegung und Effekte (Port von src/ui/animator.ts): Figuren gleiten
## von Feld zu Feld, die Kamera folgt sanft, Geschosse fliegen sichtbar,
## Schadenszahlen steigen auf. Die Spiellogik bleibt rundenbasiert.

const STEP_MS := 125.0

var _tweens: Dictionary = {}
var _shots: Array = []
var _floaters: Array = []
var _cam: Variant = null


static func _ease(t: float) -> float:
	return 2 * t * t if t < 0.5 else 1 - pow(-2 * t + 2, 2) / 2


static func now_ms() -> float:
	return Time.get_ticks_usec() / 1000.0


## Positionen aller Figuren vor einer Aktion festhalten.
func snapshot(s: Dictionary) -> Dictionary:
	var out := {}
	out["p"] = Vector2(s.player.pos.x, s.player.pos.y)
	if s.player.get("pet") != null:
		out["pet"] = Vector2(s.player.pet.pos.x, s.player.pet.pos.y)
	for m in s.monsters:
		out[m.uid] = Vector2(m.pos.x, m.pos.y)
	for c in J.arr(s, "crawlers"):
		out[c.uid] = Vector2(c.pos.x, c.pos.y)
	return out


## Nach einer Aktion: Bewegungen weich machen und Effekte starten.
func after(s: Dictionary, before: Dictionary, fx: Array, now: float = -1.0) -> void:
	if now < 0:
		now = now_ms()
	var current := snapshot(s)
	for key in current:
		var to: Vector2 = current[key]
		var from = before.get(key)
		var prev := draw_pos(key, from if from != null else to, now)
		if from == null or from == to:
			continue
		var jump := maxf(absf(to.x - from.x), absf(to.y - from.y))
		if jump > 3:
			_tweens.erase(key)
			continue
		_tweens[key] = {"from": prev, "to": to, "start": now, "dur": STEP_MS * minf(2, jump)}
	var bp = before.get("p")
	if bp != null and maxf(absf(bp.x - s.player.pos.x), absf(bp.y - s.player.pos.y)) > 3:
		_cam = null
	var delay := 0.0
	var per_tile := {}
	for f in fx:
		if f.kind == "shot":
			var a := Vector2(f.from.x, f.from.y)
			var b := Vector2(f.to.x, f.to.y)
			var dur := maxf(120.0, a.distance_to(b) * 45)
			_shots.append({"from": a, "to": b, "start": now + delay, "dur": dur, "style": f.style})
			delay += 60
		else:
			var key := "%d,%d" % [f.at.x, f.at.y]
			var n: int = per_tile.get(key, 0)
			per_tile[key] = n + 1
			_floaters.append({"at": Vector2(f.at.x, f.at.y), "text": f.text, "color": f.color, "start": now + delay + n * 260, "dur": 900.0})


func draw_pos(key: String, fallback: Vector2, now: float = -1.0) -> Vector2:
	var t = _tweens.get(key)
	if t == null:
		return fallback
	if now < 0:
		now = now_ms()
	var k := minf(1.0, (now - t.start) / t.dur)
	if k >= 1:
		_tweens.erase(key)
		return t.to
	return (t.from as Vector2).lerp(t.to, _ease(k))


## Läuft gerade noch eine Bewegung des Spielers?
func player_moving(now: float = -1.0) -> float:
	var t = _tweens.get("p")
	if t == null:
		return 0.0
	if now < 0:
		now = now_ms()
	return maxf(0.0, 1 - (now - t.start) / t.dur)


func busy(now: float = -1.0) -> bool:
	if now < 0:
		now = now_ms()
	if not _tweens.is_empty():
		return true
	for sh in _shots:
		if now < sh.start + sh.dur:
			return true
	for f in _floaters:
		if now < f.start + f.dur:
			return true
	return false


func reset() -> void:
	_tweens.clear()
	_shots.clear()
	_floaters.clear()
	_cam = null


## Bild für den aktuellen Zeitpunkt: Kamera, Geschosse, Zahlen.
func frame(s: Dictionary, now: float = -1.0) -> Dictionary:
	if now < 0:
		now = now_ms()
	var player := draw_pos("p", Vector2(s.player.pos.x, s.player.pos.y), now)
	if _cam == null:
		_cam = player
	_cam = (_cam as Vector2).lerp(player, 0.25)
	if absf(_cam.x - player.x) < 0.01 and absf(_cam.y - player.y) < 0.01:
		_cam = player
	var projectiles: Array = []
	_shots = _shots.filter(func(sh): return now < sh.start + sh.dur)
	for sh in _shots:
		if now < sh.start:
			continue
		var k: float = (now - sh.start) / sh.dur
		var p: Vector2 = (sh.from as Vector2).lerp(sh.to, k)
		# Würfe fliegen im Bogen, Pfeile und Zauber gerade
		var lob: bool = sh.style == "stein" or sh.style == "bombe" or sh.style == "schleim"
		var arc_h := sin(k * PI) * 0.6 if lob else 0.0
		var trail: Array = []
		for j in range(4, 0, -1):
			var kk := maxf(0.0, k - j * 0.06)
			var tp: Vector2 = (sh.from as Vector2).lerp(sh.to, kk)
			trail.append(Vector2(tp.x, tp.y - sin(kk * PI) * (0.6 if arc_h != 0.0 else 0.0)))
		var d: Vector2 = sh.to - sh.from
		var spin: bool = sh.style == "stein" or sh.style == "bombe"
		projectiles.append({"x": p.x, "y": p.y - arc_h, "angle": atan2(d.y, d.x) + (k * 6 if spin else 0.0), "style": sh.style, "trail": trail})
	var floaters: Array = []
	_floaters = _floaters.filter(func(f): return now < f.start + f.dur)
	for f in _floaters:
		if now < f.start:
			continue
		var k: float = (now - f.start) / f.dur
		floaters.append({"x": f.at.x, "y": f.at.y - 0.2 - k * 0.9, "text": f.text, "color": f.color, "alpha": 1.0 if k < 0.7 else 1 - (k - 0.7) / 0.3})
	return {"cam": _cam, "projectiles": projectiles, "floaters": floaters, "time": now, "now": now}
