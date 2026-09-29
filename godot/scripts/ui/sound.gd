class_name SoundBox
extends Node
## Klänge, im Spiel erzeugt:
## Lootbox, Level-Aufstieg, Achievement, neuer Skill, Kampfbeginn und -ende,
## Versus-Bildschirm und ein weiches Tippgeräusch; dazu Musik: eine Klangkulisse
## je Etage (Brummen als Schleife und zufällige Tropfen, Knarzen, Grollen) und
## eine Kampfschleife. Alles wird einmal im Hintergrund berechnet und dann nur
## noch abgespielt.

const RATE := 32000
const TIER_RANK := {"bronze": 0, "silber": 1, "gold": 2, "platin": 3, "legendaer": 4, "himmlisch": 5}

static var instance: SoundBox

var enabled := true
var typing_on := true
var music_on := true
## Musikzustand: Etage (0 = keine Musik), Kampf, Boss
var _floor := 0
var _combat := false
var _boss := false
var _amb: AudioStreamPlayer
var _mus: AudioStreamPlayer
var _amb_key := ""
var _next_event := 0.0
var _streams: Dictionary = {}
var _players: Array = []
var _next := 0
var _last_click := 0.0
var _task := -1
var _ready_flag := false
var _mutex := Mutex.new()


func _ready() -> void:
	instance = self
	enabled = Settings.get_value("ton", true)
	typing_on = Settings.get_value("tippen", true)
	music_on = Settings.get_value("musik", true)
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_amb = AudioStreamPlayer.new()
	_mus = AudioStreamPlayer.new()
	for p in [_amb, _mus]:
		p.volume_db = -80.0
		add_child(p)
	_jobs = _job_list()
	if OS.has_feature("threads"):
		_task = WorkerThreadPool.add_task(_build_all, true, "Klänge berechnen")
	else:
		# Ohne Threads (z. B. im Browser): ein Klang pro Bild, damit nichts ruckelt
		pass
	set_process(true)


var _jobs: Array = []


func _process(_d: float) -> void:
	if _task < 0 and not _jobs.is_empty():
		var job: Callable = _jobs.pop_front()
		job.call()
		if _jobs.is_empty():
			_ready_flag = true
	_update_music()


func _exit_tree() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
	if instance == self:
		instance = null


func set_enabled(on: bool) -> void:
	enabled = on
	Settings.set_value("ton", on)


func set_typing(on: bool) -> void:
	typing_on = on
	Settings.set_value("tippen", on)


func set_music(on: bool) -> void:
	music_on = on
	Settings.set_value("musik", on)


# ================================================================ Musik

const MUSIC_DB := -5.0
const AMBIENT_DB := -10.0
## Einzelgeräusche je Etage: [Name, Gewicht]
const EVENTS := {
	1: [["tropfen:0", 4], ["tropfen:1", 3], ["knarzen:0", 2], ["kette", 1], ["grollen", 1]],
	2: [["tropfen:1", 3], ["tropfen:2", 3], ["knarzen:1", 2], ["grollen", 2], ["kette", 2]],
	3: [["tropfen:0", 3], ["tropfen:2", 3], ["blubbern", 4], ["grollen", 1], ["knarzen:1", 1]],
}


## Was gerade laufen soll: Etage (0 = still), Kampf, Boss. Mehrfach aufrufbar.
func music(floor_no: int, combat: bool = false, boss: bool = false) -> void:
	_floor = clampi(floor_no, 0, 3)
	_combat = combat
	_boss = boss


func _stream(key: String) -> AudioStream:
	_mutex.lock()
	var st = _streams.get(key)
	_mutex.unlock()
	return st


## Lautstärke weich zum Ziel führen (pro Bild), Schleifen wechseln, Geräusche streuen.
func _update_music() -> void:
	var on := enabled and music_on and _floor > 0
	var amb_key := "brummen:%d" % _floor
	if on and amb_key != _amb_key:
		var st := _stream(amb_key)
		if st != null:
			_amb_key = amb_key
			_amb.stream = st
			_amb.volume_db = -60.0
			_amb.play()
	if on and _mus.stream == null:
		var st := _stream("kampfmusik")
		if st != null:
			_mus.stream = st
	var want_amb := AMBIENT_DB if on and not _combat else (AMBIENT_DB - 10.0 if on else -80.0)
	var want_mus := MUSIC_DB if on and _combat else -80.0
	_fade(_amb, want_amb, 18.0)
	_fade(_mus, want_mus, 30.0 if _combat else 12.0)
	if _mus.stream != null:
		var pitch := 1.12 if _boss else 1.0
		_mus.pitch_scale = pitch
		if want_mus > -79.0 and not _mus.playing:
			_mus.play()
		elif _mus.volume_db <= -79.0 and _mus.playing:
			_mus.stop()
	# Einzelgeräusche nur abseits vom Kampf
	var now := Time.get_ticks_msec() / 1000.0
	if on and not _combat and now >= _next_event:
		if _next_event > 0.0:
			var pick := _pick_event(_floor)
			if pick != "":
				_play(pick, 0.45 + randf() * 0.4, 0.85 + randf() * 0.3)
		_next_event = now + (2.5 if _floor == 3 else 3.5) + randf() * 5.0


func _fade(p: AudioStreamPlayer, target: float, speed_db: float) -> void:
	var dt := get_process_delta_time()
	if p.volume_db < target:
		p.volume_db = minf(target, p.volume_db + speed_db * dt * (4.0 if p.volume_db < -40.0 else 1.0))
	elif p.volume_db > target:
		p.volume_db = maxf(target, p.volume_db - speed_db * dt * 2.0)


func _pick_event(f: int) -> String:
	var list: Array = EVENTS.get(f, [])
	var total := 0
	for e in list:
		total += int(e[1])
	if total == 0:
		return ""
	var r := randi() % total
	for e in list:
		r -= int(e[1])
		if r < 0:
			return e[0]
	return ""


# ================================================================ Abspielen

func _play(key: String, volume: float = 1.0, pitch: float = 1.0) -> void:
	if not enabled:
		return
	_mutex.lock()
	var st = _streams.get(key)
	_mutex.unlock()
	if st == null:
		return
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = st
	p.volume_db = linear_to_db(maxf(0.0001, volume))
	p.pitch_scale = pitch
	p.play()


## Wichtigster Klang aus einer Liste von Engine-Klängen (sfx).
func play_sfx(list: Array) -> void:
	if not enabled or list.is_empty():
		return
	var order := ["levelup", "box", "achievement", "skill"]
	var best: Dictionary = list[0]
	for x in list:
		if order.find(x.kind) < order.find(best.kind):
			best = x
	match best.kind:
		"box": _play("box:" + String(best.get("tier", "bronze")))
		"levelup": _play("levelup")
		"achievement": _play("achv:" + String(best.get("tier", "bronze")))
		"skill": _play("skill")


## Eine Box springt auf (Klang der Box-Stufe).
func play_box(tier: String) -> void:
	_play("box:" + tier)


func play_combat_start() -> void:
	_play("kampf")


func play_combat_end() -> void:
	_play("kampfende")


func play_versus() -> void:
	_play("versus")


## Weicher Tastenanschlag. loud: 1 für Dialoge, 0.55 für das Log.
func type_click(space: bool = false, loud: float = 1.0, gap: float = 46.0) -> void:
	if not enabled or not typing_on:
		return
	var now := Time.get_ticks_msec()
	if now - _last_click < gap * (0.85 + randf() * 0.3):
		return
	_last_click = now
	var v := loud * (0.8 + randf() * 0.35)
	var key := ("leer:%d" % (randi() % 4)) if space else ("taste:%d" % (randi() % 10))
	_play(key, v, 0.9 + randf() * 0.2)


# ================================================================ Erzeugen

class Buf:
	var data: PackedFloat32Array
	var rate := SoundBox.RATE

	func _init(seconds: float, r: int = SoundBox.RATE) -> void:
		rate = r
		data = PackedFloat32Array()
		data.resize(int(seconds * rate))

	## Ton mit Hüllkurve: 12 ms Anstieg, dann exponentielles Ausklingen.
	func tone(freq: float, start: float, dur: float, type: String, vol: float, glide_to: float = 0.0) -> void:
		var s0 := int(start * rate)
		var n := int(dur * rate)
		var phase := 0.0
		var attack := 0.012
		for i in n:
			var idx := s0 + i
			if idx >= data.size():
				break
			var t := float(i) / rate
			var f := freq
			if glide_to > 0.0:
				f = freq * pow(glide_to / freq, t / dur)
			phase += f / rate
			phase -= floorf(phase)
			var w := 0.0
			match type:
				"sine": w = sin(phase * TAU)
				"square": w = 1.0 if phase < 0.5 else -1.0
				"sawtooth": w = 2.0 * phase - 1.0
				"triangle": w = 1.0 - 4.0 * absf(phase - 0.5)
			var env: float
			if t < attack:
				env = 0.0001 * pow(vol / 0.0001, t / attack)
			else:
				env = vol * pow(0.0001 / vol, (t - attack) / maxf(0.001, dur - attack))
			data[idx] += w * env

	## Glocke: Grundton plus unharmonische Obertöne.
	func bell(freq: float, start: float, vol: float = 0.3, dur: float = 1.4) -> void:
		tone(freq, start, dur, "sine", vol)
		tone(freq * 2.01, start, dur * 0.7, "sine", vol * 0.45)
		tone(freq * 3.02, start, dur * 0.4, "sine", vol * 0.2)
		tone(freq * 4.2, start, dur * 0.25, "triangle", vol * 0.08)

	## Gefiltertes Rauschen mit wanderndem Bandpass.
	func noise(start: float, dur: float, vol: float, from: float, to: float, q: float = 6.0) -> void:
		var s0 := int(start * rate)
		var n := int(dur * rate)
		var x1 := 0.0
		var x2 := 0.0
		var y1 := 0.0
		var y2 := 0.0
		var b0 := 0.0
		var b2 := 0.0
		var a1 := 0.0
		var a2 := 0.0
		var a0 := 1.0
		for i in n:
			var idx := s0 + i
			if idx >= data.size():
				break
			var t := float(i) / rate
			if i % 32 == 0:
				var fc := from * pow(to / from, t / dur)
				var w0 := TAU * fc / rate
				var alpha := sin(w0) / (2.0 * q)
				b0 = alpha
				b2 = -alpha
				a0 = 1.0 + alpha
				a1 = -2.0 * cos(w0)
				a2 = 1.0 - alpha
			var x := (randf() * 2.0 - 1.0) * (1.0 - float(i) / n)
			var y := (b0 * x + b2 * x2 - a1 * y1 - a2 * y2) / a0
			x2 = x1
			x1 = x
			y2 = y1
			y1 = y
			data[idx] += y * vol * pow(0.0001 / vol, t / dur)

	## Kurzer Hall über eine Rückkopplung.
	func reverb() -> void:
		var d := int(0.11 * rate)
		var wet := PackedFloat32Array()
		wet.resize(data.size())
		for i in data.size():
			if i >= d:
				wet[i] = data[i - d] + 0.25 * wet[i - d]
		for i in data.size():
			data[i] += wet[i]

	## Gehaltener Ton ohne Ausklingen, mit weichem Ein- und Ausblenden und
	## langsamem Schweben der Lautstärke (für Brummen und Flächen).
	func hum(freq: float, start: float, dur: float, type: String, vol: float, lfo: float = 0.0, depth: float = 0.0) -> void:
		var s0 := int(start * rate)
		var n := int(dur * rate)
		var fade := int(0.3 * rate)
		var phase := 0.0
		var step := freq / rate
		for i in n:
			var idx := s0 + i
			if idx >= data.size():
				break
			phase += step
			phase -= floorf(phase)
			var w := 0.0
			match type:
				"sine": w = sin(phase * TAU)
				"triangle": w = 1.0 - 4.0 * absf(phase - 0.5)
				"square": w = 1.0 if phase < 0.5 else -1.0
				"sawtooth": w = 2.0 * phase - 1.0
			var env := vol
			if lfo > 0.0:
				env *= 1.0 - depth * (0.5 + 0.5 * sin(TAU * lfo * i / rate))
			if i < fade:
				env *= float(i) / fade
			elif i > n - fade:
				env *= float(n - i) / fade
			data[idx] += w * env

	## Gleichmäßiges, gefiltertes Rauschen (Wind, Wasser), Lautstärke schwebt.
	func wash(start: float, dur: float, vol: float, fc: float, q: float, lfo: float = 0.1, depth: float = 0.5) -> void:
		var s0 := int(start * rate)
		var n := int(dur * rate)
		var w0 := TAU * fc / rate
		var alpha := sin(w0) / (2.0 * q)
		var a0 := 1.0 + alpha
		var a1 := -2.0 * cos(w0)
		var a2 := 1.0 - alpha
		var x1 := 0.0
		var x2 := 0.0
		var y1 := 0.0
		var y2 := 0.0
		var fade := int(0.3 * rate)
		for i in n:
			var idx := s0 + i
			if idx >= data.size():
				break
			var x := randf() * 2.0 - 1.0
			var y := (alpha * x - alpha * x2 - a1 * y1 - a2 * y2) / a0
			x2 = x1
			x1 = x
			y2 = y1
			y1 = y
			var env := vol * (1.0 - depth * (0.5 + 0.5 * sin(TAU * lfo * i / rate + 1.3 * sin(TAU * lfo * 0.37 * i / rate))))
			if i < fade:
				env *= float(i) / fade
			elif i > n - fade:
				env *= float(n - i) / fade
			data[idx] += y * env

	## Nahtlose Schleife: Der Puffer ist `loop` Sekunden plus Überhang lang; der
	## Überhang (Hall, ausklingende Töne) wird in den Anfang geblendet.
	func loopify(loop: float) -> void:
		var n := int(loop * rate)
		var extra := data.size() - n
		if extra <= 0:
			return
		for i in extra:
			var k := float(i) / extra
			data[i] = data[i] * k + data[n + i] * (1.0 - k)
		data.resize(n)

	func to_stream(gain: float) -> AudioStreamWAV:
		var bytes := PackedByteArray()
		bytes.resize(data.size() * 2)
		for i in data.size():
			var v := clampi(int(data[i] * gain * 32767.0), -32768, 32767)
			bytes.encode_s16(i * 2, v)
		var st := AudioStreamWAV.new()
		st.format = AudioStreamWAV.FORMAT_16_BITS
		st.mix_rate = rate
		st.stereo = false
		st.data = bytes
		return st


static func note(semi: float) -> float:
	return 523.25 * pow(2.0, semi / 12.0)


func _store(key: String, b: Buf, gain: float = 0.35, reverb: bool = true, loop: float = 0.0) -> void:
	if reverb:
		b.reverb()
	if loop > 0.0:
		b.loopify(loop)
	var st := b.to_stream(gain)
	if loop > 0.0:
		st.loop_mode = AudioStreamWAV.LOOP_FORWARD
		st.loop_begin = 0
		st.loop_end = b.data.size()
	_mutex.lock()
	_streams[key] = st
	_mutex.unlock()


func _build_all() -> void:
	for job in _jobs:
		job.call()
	_jobs = []
	_ready_flag = true


## Alle Klänge als einzelne Aufgaben; das Tippen zuerst, das hört man am häufigsten.
func _job_list() -> Array:
	var jobs: Array = []
	for i in 10:
		jobs.append(func(): _store("taste:%d" % i, _click(false), 0.8, false))
	for i in 4:
		jobs.append(func(): _store("leer:%d" % i, _click(true), 0.8, false))
	for tier in TIER_RANK:
		jobs.append(func(): _store("box:" + tier, _box(TIER_RANK[tier])))
		jobs.append(func(): _store("achv:" + tier, _achievement(TIER_RANK[tier])))
	jobs.append(func():
		var b := Buf.new(2.0)
		var seq := [0, 4, 7, 12]
		for i in seq.size():
			b.tone(note(seq[i]), i * 0.11, 0.22, "square", 0.09)
			b.tone(note(seq[i] + 12), i * 0.11, 0.18, "triangle", 0.06)
		for sm in [0, 4, 7, 12, 16]:
			b.tone(note(sm), 0.46, 1.1, "sawtooth", 0.035)
		b.bell(note(24), 0.46, 0.2, 1.3)
		_store("levelup", b))
	jobs.append(func():
		var b := Buf.new(1.3)
		b.bell(note(12), 0, 0.18, 0.9)
		b.tone(note(19), 0.08, 0.5, "sine", 0.08)
		_store("skill", b))
	jobs.append(func():
		var b := Buf.new(0.9)
		b.tone(90, 0, 0.35, "sine", 0.45, 45)
		b.noise(0, 0.18, 0.3, 2400, 600)
		b.tone(note(-5), 0.04, 0.16, "sawtooth", 0.07, note(-12))
		b.tone(note(-6), 0.18, 0.22, "sawtooth", 0.07, note(-14))
		_store("kampf", b))
	jobs.append(func():
		var b := Buf.new(1.3)
		b.tone(note(-5), 0, 0.2, "triangle", 0.1)
		b.tone(note(0), 0.12, 0.45, "triangle", 0.1)
		b.bell(note(12), 0.12, 0.08, 0.8)
		_store("kampfende", b))
	jobs.append(func():
		var b := Buf.new(2.2)
		for i in 3:
			b.tone(70, i * 0.16, 0.3, "sine", 0.5, 40)
		b.noise(0.48, 0.6, 0.35, 3000, 300)
		for sm in [-24, -17, -12]:
			b.tone(note(sm), 0.5, 1.2, "sawtooth", 0.05)
		_store("versus", b))
	# Musik zuletzt: Geräusche, Brummen je Etage, Kampfschleife in Stimmen zerlegt
	for v in 3:
		jobs.append(func(): _store("tropfen:%d" % v, _drip(v), 0.9))
	for v in 2:
		jobs.append(func(): _store("knarzen:%d" % v, _creak(v), 1.0))
	jobs.append(func(): _store("grollen", _rumble(), 0.9))
	jobs.append(func(): _store("kette", _chain(), 1.2))
	jobs.append(func(): _store("blubbern", _bubbles(), 0.9))
	for f in [1, 2, 3]:
		jobs.append(func(): _drone_bufs[f] = Buf.new(DRONE_LOOP + 1.0, DRONE_RATE))
		for voice in DRONES[f]:
			jobs.append(func(): _drone_voice(_drone_bufs[f], voice))
		jobs.append(func(): _store("brummen:%d" % f, _drone_bufs[f], 0.6, false, DRONE_LOOP))
	jobs.append(func(): _music_buf = Buf.new(MUSIC_LOOP + 0.5, MUSIC_RATE))
	for part in ["bass", "arp", "melodie", "schlagzeug"]:
		for bar in 4:
			jobs.append(func(): _music_part(_music_buf, part, bar))
	jobs.append(func(): _store("kampfmusik", _music_buf, 0.55, false, MUSIC_LOOP))
	return jobs


# ---------------------------------------------------------------- Musik erzeugen

const DRONE_LOOP := 8.0
## Tiefe Klänge brauchen keine hohe Abtastrate; das spart Rechenzeit im Browser.
const DRONE_RATE := 11025
const MUSIC_RATE := 22050
## Vier Takte bei 128 Schlägen pro Minute
const BAR := 1.875
const MUSIC_LOOP := BAR * 4
var _music_buf: Buf


func _drip(v: int) -> Buf:
	var b := Buf.new(1.2)
	var f: float = [1500.0, 1150.0, 1900.0][v]
	b.tone(f, 0.0, 0.07, "sine", 0.22, f * 0.5)
	b.tone(f * 1.3, 0.09, 0.05, "sine", 0.08, f * 0.7)
	return b


## Holz knarzt: rauer Sägezahn in kurzen Stößen, dazu Reiben.
func _creak(v: int) -> Buf:
	var b := Buf.new(1.2)
	var f := 95.0 if v == 0 else 140.0
	for i in 9:
		b.tone(f * (1.0 + 0.04 * sin(i * 1.7)), i * 0.055, 0.07, "sawtooth", 0.05, f * 0.9)
	b.noise(0.0, 0.5, 0.05, 500, 900, 3.0)
	return b


func _rumble() -> Buf:
	var b := Buf.new(2.6)
	b.noise(0.0, 2.2, 0.5, 90, 45, 1.5)
	b.tone(42, 0.1, 1.8, "sine", 0.18, 36)
	return b


func _chain() -> Buf:
	var b := Buf.new(1.0)
	for i in 6:
		var t := i * 0.07 + randf() * 0.03
		for p in [2100.0, 3350.0, 4700.0]:
			b.tone(p * (0.95 + randf() * 0.1), t, 0.06, "sine", 0.025)
	return b


func _bubbles() -> Buf:
	var b := Buf.new(1.0)
	for i in 4:
		var f := 260.0 + randf() * 200.0
		b.tone(f, i * 0.09 + randf() * 0.04, 0.06, "sine", 0.12, f * 2.2)
	return b


## Brummen je Etage: tiefe, schwebende Töne und Rauschen (Luftzug, Wasser).
## Ton: ["hum", Frequenz, Form, Lautstärke, Schweben, Tiefe];
## Rauschen: ["wash", Lautstärke, Mittenfrequenz, Güte, Schweben, Tiefe].
const DRONES := {
	1: [["hum", 55.0, "sine", 0.16, 0.11, 0.35], ["hum", 55.4, "sine", 0.1, 0.0, 0.0], ["hum", 110.0, "triangle", 0.03, 0.07, 0.6], ["wash", 0.05, 320.0, 0.8, 0.09, 0.6]],
	2: [["hum", 49.0, "sine", 0.17, 0.09, 0.4], ["hum", 49.5, "sine", 0.1, 0.0, 0.0], ["hum", 73.5, "triangle", 0.035, 0.05, 0.7], ["wash", 0.06, 220.0, 0.9, 0.07, 0.7]],
	3: [["hum", 52.0, "sine", 0.14, 0.1, 0.3], ["hum", 78.0, "triangle", 0.03, 0.06, 0.5], ["wash", 0.07, 900.0, 0.5, 0.13, 0.5], ["wash", 0.025, 2600.0, 1.2, 0.3, 0.8]],
}
var _drone_bufs := {}


func _drone_voice(b: Buf, v: Array) -> void:
	var d := DRONE_LOOP + 1.0
	if v[0] == "hum":
		b.hum(v[1], 0, d, v[2], v[3], v[4], v[5])
	else:
		b.wash(0, d, v[1], v[2], v[3], v[4], v[5])


## Kampfschleife in a-Moll (Am, F, G, E), eine Stimme und ein Takt pro Aufruf.
const MELODY := [[[-3, 2], [0, 1], [4, 1]], [[5, 2], [4, 1], [0, 1]], [[2, 2], [-1, 1], [-5, 1]], [[-4, 2], [-1, 1], [4, 1]]]


func _music_part(b: Buf, part: String, bar: int) -> void:
	var roots := [-15, -19, -17, -20]
	var chords := [[0, 3, 7], [0, 4, 7], [0, 4, 7], [0, 4, 7]]
	var e := BAR / 8.0
	var t0 := bar * BAR
	match part:
		"bass":
			var pat := [0, 0, 12, 0, 0, 12, 7, 12]
			for i in 8:
				b.tone(note(roots[bar] - 12 + pat[i]), t0 + i * e, e * 0.9, "triangle", 0.2)
		"arp":
			var seq := [0, 1, 2, 3, 2, 1, 0, 1, 2, 3, 2, 1, 0, 2, 1, 3]
			var ch: Array = chords[bar]
			var tones := [ch[0], ch[1], ch[2], 12]
			for i in 16:
				b.tone(note(roots[bar] + 12 + tones[seq[i]]), t0 + i * e / 2.0, e * 0.45, "square", 0.026)
		"melodie":
			var t := t0
			for m in MELODY[bar]:
				var dur: float = m[1] * BAR / 4.0
				b.tone(note(m[0]), t, dur * 0.95, "square", 0.06)
				b.tone(note(m[0] - 12), t, dur * 0.9, "triangle", 0.035)
				t += dur
		"schlagzeug":
			for beat in 4:
				var tb := t0 + beat * BAR / 4.0
				if beat % 2 == 0:
					b.tone(150, tb, 0.14, "sine", 0.5, 45)
				else:
					b.noise(tb, 0.12, 0.3, 1800, 1400, 1.0)
					b.tone(190, tb, 0.06, "triangle", 0.12, 150)
				for h in 2:
					b.noise(tb + h * BAR / 8.0, 0.03, 0.08, 8000, 7000, 1.5)
			b.tone(150, t0 + BAR * 7.0 / 8.0, 0.1, "sine", 0.35, 45)


func _box(r: int) -> Buf:
	var b := Buf.new(3.0)
	# Deckel knarzt auf, dann ein „Plopp“
	b.noise(0, 0.35, 0.25, 300, 1200)
	b.tone(180, 0.3, 0.12, "sine", 0.35, 90)
	# Glitzern: je besser die Box, desto länger und höher
	var scale := [0, 4, 7, 12, 16, 19, 24, 28]
	var n := 3 + r
	for i in n:
		b.tone(note(scale[i % scale.size()] + 12), 0.42 + i * 0.07, 0.35, "triangle", 0.16)
	if r >= 2:
		b.bell(note(24), 0.42 + n * 0.07, 0.18, 1.6)
	if r >= 4:
		for sm in [0, 4, 7, 12]:
			b.tone(note(sm), 0.5 + n * 0.07, 1.4, "sawtooth", 0.04)
	return b


func _achievement(r: int) -> Buf:
	var b := Buf.new(2.0)
	b.bell(note(7), 0, 0.28)
	b.bell(note(12 + (4 if r >= 2 else 0)), 0.16, 0.26)
	if r >= 2:
		b.bell(note(19), 0.32, 0.2)
	for i in 5:
		b.tone(note(24 + i * 2), 0.2 + i * 0.04, 0.2, "sine", 0.05)
	return b


## Ein Tastenanschlag: gedämpftes Klicken und ein leiser, tiefer Körper.
func _click(space: bool) -> Buf:
	var b := Buf.new(0.11)
	var rate := 0.8 + randf() * 0.4
	var band := (850.0 + randf() * 200) if space else (2000.0 + randf() * 1300)
	var peak := 0.12 if space else 0.17
	var decay := 0.05 if space else 0.028
	# Klick: gefiltertes, schnell abklingendes Rauschen
	var n := int(0.045 / rate * RATE)
	var q := 0.9
	var w0 := TAU * band / RATE
	var alpha := sin(w0) / (2.0 * q)
	var a0 := 1.0 + alpha
	var a1 := -2.0 * cos(w0)
	var a2 := 1.0 - alpha
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	for i in mini(n, b.data.size()):
		var t := float(i) / RATE
		var src := (randf() * 2.0 - 1.0) * pow(1.0 - float(i) / n, 5)
		var y := (alpha * src - alpha * x2 - a1 * y1 - a2 * y2) / a0
		x2 = x1
		x1 = src
		y2 = y1
		y1 = y
		var env := 0.0
		if t < 0.0015:
			env = 0.0001 * pow(peak / 0.0001, t / 0.0015)
		elif t < decay:
			env = peak * pow(0.0001 / peak, (t - 0.0015) / (decay - 0.0015))
		b.data[i] += y * env
	# Körper: kurzer, tiefer Anschlag
	var f := (140.0 + randf() * 20) if space else (240.0 + randf() * 70)
	var body_dur := 0.08 if space else 0.04
	var glide := 0.06 if space else 0.03
	var body_peak := 0.09 if space else 0.06
	var phase := 0.0
	for i in int(body_dur * RATE):
		var t := float(i) / RATE
		var fr := f * pow(0.62, minf(1.0, t / glide))
		phase += fr / RATE
		var env := 0.0
		if t < 0.003:
			env = 0.0001 * pow(body_peak / 0.0001, t / 0.003)
		else:
			env = body_peak * pow(0.0001 / body_peak, (t - 0.003) / (body_dur - 0.003))
		b.data[i] += sin(phase * TAU) * env
	# Oben etwas gedämpft
	var lp := 0.0
	var k := 1.0 - exp(-TAU * 4800.0 / RATE)
	for i in b.data.size():
		lp += (b.data[i] - lp) * k
		b.data[i] = lp
	return b
