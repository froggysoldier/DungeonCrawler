class_name SoundBox
extends Node
## Klänge, im Spiel erzeugt:
## Lootbox, Level-Aufstieg, Achievement, neuer Skill, Kampfbeginn und -ende,
## Versus-Bildschirm und ein weiches Tippgeräusch. Die Klänge werden einmal im
## Hintergrund berechnet und dann nur noch abgespielt.

const RATE := 32000
const TIER_RANK := {"bronze": 0, "silber": 1, "gold": 2, "platin": 3, "legendaer": 4, "himmlisch": 5}

static var instance: SoundBox

var enabled := true
var typing_on := true
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
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_jobs = _job_list()
	if OS.has_feature("threads"):
		_task = WorkerThreadPool.add_task(_build_all, true, "Klänge berechnen")
	else:
		# Ohne Threads (z. B. im Browser): ein Klang pro Bild, damit nichts ruckelt
		set_process(true)


var _jobs: Array = []


func _process(_d: float) -> void:
	if _task >= 0 or _jobs.is_empty():
		set_process(false)
		return
	var job: Callable = _jobs.pop_front()
	job.call()
	if _jobs.is_empty():
		_ready_flag = true


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

	func _init(seconds: float) -> void:
		data = PackedFloat32Array()
		data.resize(int(seconds * SoundBox.RATE))

	## Ton mit Hüllkurve: 12 ms Anstieg, dann exponentielles Ausklingen.
	func tone(freq: float, start: float, dur: float, type: String, vol: float, glide_to: float = 0.0) -> void:
		var s0 := int(start * SoundBox.RATE)
		var n := int(dur * SoundBox.RATE)
		var phase := 0.0
		var attack := 0.012
		for i in n:
			var idx := s0 + i
			if idx >= data.size():
				break
			var t := float(i) / SoundBox.RATE
			var f := freq
			if glide_to > 0.0:
				f = freq * pow(glide_to / freq, t / dur)
			phase += f / SoundBox.RATE
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
		var s0 := int(start * SoundBox.RATE)
		var n := int(dur * SoundBox.RATE)
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
			var t := float(i) / SoundBox.RATE
			if i % 32 == 0:
				var fc := from * pow(to / from, t / dur)
				var w0 := TAU * fc / SoundBox.RATE
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
		var d := int(0.11 * SoundBox.RATE)
		var wet := PackedFloat32Array()
		wet.resize(data.size())
		for i in data.size():
			if i >= d:
				wet[i] = data[i - d] + 0.25 * wet[i - d]
		for i in data.size():
			data[i] += wet[i]

	func to_stream(gain: float) -> AudioStreamWAV:
		var bytes := PackedByteArray()
		bytes.resize(data.size() * 2)
		for i in data.size():
			var v := clampi(int(data[i] * gain * 32767.0), -32768, 32767)
			bytes.encode_s16(i * 2, v)
		var st := AudioStreamWAV.new()
		st.format = AudioStreamWAV.FORMAT_16_BITS
		st.mix_rate = SoundBox.RATE
		st.stereo = false
		st.data = bytes
		return st


static func note(semi: float) -> float:
	return 523.25 * pow(2.0, semi / 12.0)


func _store(key: String, b: Buf, gain: float = 0.35, reverb: bool = true) -> void:
	if reverb:
		b.reverb()
	var st := b.to_stream(gain)
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
	return jobs


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
