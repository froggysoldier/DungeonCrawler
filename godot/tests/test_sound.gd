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
