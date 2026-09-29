extends RefCounted
## Die erzeugten Klänge sind hörbar, aber nicht übersteuert.


func _peak(b) -> float:
	var p := 0.0
	for v in b.data:
		p = maxf(p, absf(v))
	return p


func test_sounds_in_range(t) -> void:
	var sb := SoundBox.new()
	var cases := {
		"Box Bronze": sb._box(0), "Box Himmlisch": sb._box(5), "Achievement Gold": sb._achievement(2),
		"Taste": sb._click(false), "Leertaste": sb._click(true),
	}
	for name in cases:
		var b = cases[name]
		b.reverb()
		var gain := 0.8 if name.begins_with("Taste") or name.begins_with("Leer") else 0.35
		var peak: float = _peak(b) * gain
		t.ok(peak > 0.005, "%s ist hörbar (Spitze %.3f)" % [name, peak])
		t.ok(peak < 1.0, "%s übersteuert nicht (Spitze %.3f)" % [name, peak])
	var st: AudioStreamWAV = cases["Taste"].to_stream(0.8)
	t.eq(st.mix_rate, SoundBox.RATE, "Abtastrate")
	t.ok(st.data.size() > 1000, "Tastenklick hat Daten")
	sb.free()


func test_musik(t) -> void:
	var sb := SoundBox.new()
	for job in sb._job_list():
		job.call()
	for f in [1, 2, 3]:
		var st: AudioStreamWAV = sb._streams.get("brummen:%d" % f)
		t.not_null(st, "Brummen für Etage %d" % f)
		if st != null:
			t.eq(st.loop_mode, AudioStreamWAV.LOOP_FORWARD, "Etage %d läuft in Schleife" % f)
			t.eq(st.loop_end, st.data.size() / 2, "Schleife über das ganze Stück")
			t.lt(absf(float(st.data.decode_s16(st.data.size() - 2) - st.data.decode_s16(0))) / 32767.0, 0.03, "Etage %d: keine hörbare Naht" % f)
		for e in SoundBox.EVENTS[f]:
			t.ok(sb._streams.has(e[0]), "Geräusch %s vorhanden" % e[0])
	var mus: AudioStreamWAV = sb._streams.get("kampfmusik")
	t.not_null(mus, "Kampfmusik")
	if mus != null:
		t.eq(mus.loop_mode, AudioStreamWAV.LOOP_FORWARD, "Kampfmusik läuft in Schleife")
		t.lt(absf(float(mus.data.size() / 2) / mus.mix_rate - SoundBox.MUSIC_LOOP), 0.01, "genau vier Takte")
		var peak := 0
		for i in mus.data.size() / 2:
			peak = maxi(peak, absi(mus.data.decode_s16(i * 2)))
		t.lt(peak, 32000, "Kampfmusik übersteuert nicht")
		t.gt(peak, 3000, "Kampfmusik ist hörbar")
	# Zustand: ohne Etage still, mit Etage und Kampf die Kampfschleife
	sb.music(2, true, true)
	t.eq([sb._floor, sb._combat, sb._boss], [2, true, true], "Musikzustand übernommen")
	sb.music(0)
	t.eq(sb._floor, 0, "still")
	t.eq(sb._pick_event(9), "", "keine Geräusche ohne Etage")
	t.ok(sb._pick_event(3) != "", "Geräusche in der Kanalstadt")
	sb.free()
