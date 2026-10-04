class_name Animator
extends RefCounted
## Weiche Bewegung und Effekte: Figuren gleiten
## von Feld zu Feld, die Kamera folgt sanft, Geschosse fliegen sichtbar,
## Schadenszahlen steigen auf. Angreifer machen einen Ausfallschritt, Getroffene
## blitzen auf, Besiegte zerfallen in Pixel, schwere Treffer lassen das Bild
## beben. Die Spiellogik bleibt rundenbasiert.

const STEP_MS := 125.0
const LUNGE_MS := 200.0
const FLASH_MS := 110.0
const BURST_MS := 650.0
const SHAKE_MS := 180.0
const SPARKLE_MS := 1200.0
## Angriffsbilder der Pack-Figuren: so lange je Bild.
const ATTACK_FRAME_MS := 70.0
## Treffer- und Todesbilder: so lange je Bild.
const HURT_FRAME_MS := 80.0
const DEATH_FRAME_MS := 90.0
## Tod der Spielfigur: umkippen, Staub, der Geist steigt auf.
const PLAYER_DEATH_MS := 1800.0

var _tweens: Dictionary = {}
var _lunges: Dictionary = {}
## Laufende Angriffe (Schlag, Wurf, Zauber): Figur -> Beginn und Richtung.
var _attacks: Dictionary = {}
## Getroffene Figuren: Figur -> Beginn der Trefferbilder.
var _hurts: Dictionary = {}
## Beginn des Todes der Spielfigur (-1: lebt).
var _player_death := -1.0
var _flashes: Dictionary = {}
var _bursts: Array = []
var _shake: Dictionary = {}
var _sparkles: Array = []
## Effekte aus dem Tiny-Swords-Pack (Staub, Explosion, Feuer).
var _fx: Array = []
var _shots: Array = []
var _floaters: Array = []
var _cam: Variant = null


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
	# Wer steht wo (nach der Aktion, sonst davor)?
	var at_key := {}
	for key in before:
		at_key["%d,%d" % [before[key].x, before[key].y]] = key
	for key in current:
		at_key["%d,%d" % [current[key].x, current[key].y]] = key
	var delay := 0.0
	var per_tile := {}
	# Ankunft von Geschossen je Feld: Treffer und Zahlen erst, wenn es ankommt
	var arrival := {}
	for f in fx:
		match f.kind:
			"shot":
				var a := Vector2(f.from.x, f.from.y)
				var b := Vector2(f.to.x, f.to.y)
				var dur := maxf(120.0, a.distance_to(b) * 45)
				var shooter = at_key.get("%d,%d" % [f.from.x, f.from.y])
				if shooter != null and a != b:
					_attacks[shooter] = {"start": now + delay, "dir": (b - a).normalized()}
				_shots.append({"from": a, "to": b, "start": now + delay, "dur": dur, "style": f.style})
				if f.style in ["bombe", "feuer", "magie"]:
					var kind: String = {"bombe": "explosion", "feuer": "feuer", "magie": "zauber"}[f.style]
					_fx.append({"at": b, "kind": kind, "start": now + delay + dur, "dur": 640.0 if kind != "zauber" else 360.0})
				arrival["%d,%d" % [f.to.x, f.to.y]] = now + delay + dur
				delay += 60
			"strike":
				var key = at_key.get("%d,%d" % [f.from.x, f.from.y])
				var d := Vector2(f.to.x - f.from.x, f.to.y - f.from.y)
				if key != null and d != Vector2.ZERO:
					_lunges[key] = {"dir": d.normalized(), "start": now + delay, "dur": LUNGE_MS}
					_attacks[key] = {"start": now + delay, "dir": d.normalized()}
					arrival["%d,%d" % [f.to.x, f.to.y]] = now + delay + LUNGE_MS * 0.5
			"hit":
				var tile := "%d,%d" % [f.at.x, f.at.y]
				var t0: float = maxf(now + delay, arrival.get(tile, 0.0))
				var key = at_key.get(tile)
				if key != null:
					_flashes[key] = {"start": t0, "dur": FLASH_MS}
					_hurts[key] = t0
				if f.get("strong", false):
					_shake = {"start": t0, "dur": SHAKE_MS, "amp": 2 if key == "p" else 1}
			"levelup":
				_sparkles.append({"start": now + delay, "dur": SPARKLE_MS})
			"death":
				var tile := "%d,%d" % [f.at.x, f.at.y]
				var t0: float = maxf(now + delay, arrival.get(tile, 0.0)) + 60
				# Figuren mit Todesbildern fallen um, die anderen zerfallen in Staub
				var deaths := PixelArt.seq_count(Sprites.sprite_name(String(f.defId), f.get("rank", "normal") == "geist"), "tod")
				var dur := maxf(BURST_MS, deaths * DEATH_FRAME_MS)
				_bursts.append({"at": Vector2(f.at.x, f.at.y), "defId": f.defId, "color": f.get("color"), "rank": f.get("rank", "normal"), "start": t0, "dur": dur})
				if deaths == 0:
					_fx.append({"at": Vector2(f.at.x, f.at.y), "kind": "staub", "start": t0, "dur": BURST_MS})
			_:
				var tile := "%d,%d" % [f.at.x, f.at.y]
				var n: int = per_tile.get(tile, 0)
				per_tile[tile] = n + 1
				var t0: float = maxf(now + delay, arrival.get(tile, 0.0))
				_floaters.append({"at": Vector2(f.at.x, f.at.y), "text": f.text, "color": f.color, "start": t0 + n * 260, "dur": 900.0})


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
	# Gleichmäßig: beim Dauerlaufen gehen die Schritte ohne Abbremsen ineinander über
	return (t.from as Vector2).lerp(t.to, k)


## Ausfallschritt einer Figur in Kacheln (0 außerhalb eines Angriffs).
func lunge(key: String, now: float = -1.0) -> Vector2:
	var l = _lunges.get(key)
	if l == null:
		return Vector2.ZERO
	if now < 0:
		now = now_ms()
	var k: float = (now - l.start) / l.dur
	if k >= 1:
		_lunges.erase(key)
		return Vector2.ZERO
	if k < 0:
		return Vector2.ZERO
	return (l.dir as Vector2) * 0.3 * sin(k * PI)


## Welches Angriffsbild (0 …) eine Figur mit frames Angriffsbildern gerade
## zeigt, -1 außerhalb eines Angriffs.
func attack_frame(key: String, frames: int, now: float = -1.0) -> int:
	var a = _attacks.get(key)
	if a == null or frames <= 0:
		return -1
	if now < 0:
		now = now_ms()
	var i := floori((now - a.start) / ATTACK_FRAME_MS)
	if i >= frames:
		_attacks.erase(key)
		return -1
	return i if i >= 0 else -1


## Welches Trefferbild (0 …) eine getroffene Figur gerade zeigt, -1 sonst.
func hurt_frame(key: String, frames: int, now: float = -1.0) -> int:
	if not _hurts.has(key) or frames <= 0:
		return -1
	if now < 0:
		now = now_ms()
	var i := floori((now - float(_hurts[key])) / HURT_FRAME_MS)
	if i >= frames:
		_hurts.erase(key)
		return -1
	return i if i >= 0 else -1


## Die Spielfigur stirbt an Feld at: Umkippen beginnt, beim Aufprall staubt es.
func player_death(at: Vector2, now: float = -1.0) -> void:
	if now < 0:
		now = now_ms()
	_player_death = now
	_fx.append({"at": at, "kind": "staub", "start": now + 420.0, "dur": BURST_MS})
	_shake = {"start": now + 420.0, "dur": SHAKE_MS, "amp": 1}


## Fortschritt des Todes der Spielfigur (0 bis 1, danach bleibt sie liegen),
## -1 solange sie lebt.
func dying(now: float = -1.0) -> float:
	if _player_death < 0:
		return -1.0
	if now < 0:
		now = now_ms()
	return clampf((now - _player_death) / PLAYER_DEATH_MS, 0.0, 1.0)


## Richtung des laufenden Angriffs (null ohne Angriff).
func attack_dir(key: String) -> Variant:
	var a = _attacks.get(key)
	return null if a == null else a.dir


## Blitzt die Figur gerade auf (getroffen)?
func flashing(key: String, now: float = -1.0) -> bool:
	var f = _flashes.get(key)
	if f == null:
		return false
	if now < 0:
		now = now_ms()
	if now >= f.start + f.dur:
		_flashes.erase(key)
		return false
	return now >= f.start


## Zerfallende Monster: at, defId, color, rank und Fortschritt k (0 bis 1).
func bursts(now: float = -1.0) -> Array:
	if now < 0:
		now = now_ms()
	_bursts = _bursts.filter(func(b): return now < b.start + b.dur)
	var out: Array = []
	for b in _bursts:
		if now >= b.start:
			var e: Dictionary = b.duplicate()
			e.k = (now - b.start) / b.dur
			out.append(e)
	return out


## Laufende Effekte: at, kind und Fortschritt k (0 bis 1).
func fx(now: float = -1.0) -> Array:
	if now < 0:
		now = now_ms()
	_fx = _fx.filter(func(e): return now < e.start + e.dur)
	var out: Array = []
	for e in _fx:
		if now >= e.start:
			var c: Dictionary = e.duplicate()
			c.k = (now - e.start) / e.dur
			out.append(c)
	return out


## Funken beim Stufenaufstieg: Fortschritte k (0 bis 1) der laufenden Funkenregen.
func sparkles(now: float = -1.0) -> Array:
	if now < 0:
		now = now_ms()
	_sparkles = _sparkles.filter(func(sp): return now < sp.start + sp.dur)
	var out: Array = []
	for sp in _sparkles:
		if now >= sp.start:
			out.append((now - sp.start) / sp.dur)
	return out


## Beben des Bildes in Kunstpixeln.
func shake(now: float = -1.0) -> Vector2:
	if _shake.is_empty():
		return Vector2.ZERO
	if now < 0:
		now = now_ms()
	var k: float = (now - _shake.start) / _shake.dur
	if k >= 1:
		_shake = {}
		return Vector2.ZERO
	if k < 0:
		return Vector2.ZERO
	var amp: float = _shake.amp * (1 - k)
	return Vector2(roundf(sin(now / 18.0) * amp), roundf(cos(now / 23.0) * amp * 0.6))


## Gleitet diese Figur gerade von Feld zu Feld?
func moving(key: String) -> bool:
	return _tweens.has(key)


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
	if not _tweens.is_empty() or not _lunges.is_empty():
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
	_lunges.clear()
	_attacks.clear()
	_hurts.clear()
	_player_death = -1.0
	_flashes.clear()
	_bursts.clear()
	_sparkles.clear()
	_fx.clear()
	_shake = {}
	_cam = null


## Bild für den aktuellen Zeitpunkt: Kamera, Geschosse, Zahlen.
func frame(s: Dictionary, now: float = -1.0) -> Dictionary:
	if now < 0:
		now = now_ms()
	var player := draw_pos("p", Vector2(s.player.pos.x, s.player.pos.y), now)
	# Die Kamera klebt am Crawler (der Schritt selbst ist schon weich animiert)
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
	return {"cam": _cam, "projectiles": projectiles, "floaters": floaters, "bursts": bursts(now), "sparkles": sparkles(now), "fx": fx(now), "shake": shake(now), "time": now, "now": now}
