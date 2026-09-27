class_name Screens
extends RefCounted
## Titel, Interview und Endbildschirm (Port von src/ui/screens.ts).


## Bildschirm mit zentrierter Karte; gibt den Inhalt der Karte zurück.
static func card_screen(root: Control, width: float = 760.0) -> VBoxContainer:
	Kit.clear(root)
	var bg := Backdrop.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var m := Kit.margin(scroll, 16, 48, 16, 48)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.use_top_left = false
	m.add_child(center)
	var panel := PanelContainer.new()
	panel.theme_type_variation = "Card"
	panel.custom_minimum_size = Vector2(minf(width, root.get_viewport_rect().size.x - 32), 0)
	center.add_child(panel)
	var v := Kit.vbox(panel, 10)
	panel.modulate.a = 0.0
	panel.create_tween().tween_property(panel, "modulate:a", 1.0, 0.35)
	return v


## Hintergrund mit zwei weichen Farbflecken (wie im CSS des Body).
class Backdrop:
	extends Control

	func _draw() -> void:
		var w := size.x
		var h := size.y
		draw_rect(Rect2(0, 0, w, h), UiTheme.BG)
		var pen := Pen.new(self)
		var g := pen.radial_gradient(w / 2, -0.1 * h, 0, w / 2, -0.1 * h, 900)
		g.add(0, "rgba(244,194,79,0.06)")
		g.add(0.6, "rgba(244,194,79,0)")
		g.add(1, "rgba(244,194,79,0)")
		pen.fill_style = g
		pen.fill_rect(0, 0, w, h)
		var g2 := pen.radial_gradient(w, h * 1.1, 0, w, h * 1.1, 700)
		g2.add(0, "rgba(255,111,174,0.04)")
		g2.add(0.6, "rgba(255,111,174,0)")
		g2.add(1, "rgba(255,111,174,0)")
		pen.fill_style = g2
		pen.fill_rect(0, 0, w, h)


static func logo(parent: Node, text: String, size: int = 56) -> Label:
	var l := Kit.label(parent, text, size, UiTheme.ACCENT, 800)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_shadow_color", Color(1, 111 / 255.0, 174 / 255.0, 0.55))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 3)
	return l


## Zitat der Systemstimme; wird getippt, die Antworten erscheinen danach.
static func quote(parent: Node, bb: String, then_show: Array) -> Typing:
	var p := PanelContainer.new()
	p.theme_type_variation = "Quote"
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(p)
	var bar := ColorRect.new()
	bar.color = UiTheme.ACCENT
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.draw.connect(func(): p.draw_rect(Rect2(0, 0, 3, p.size.y), UiTheme.ACCENT))
	var rt := Kit.text(p, "", 16, UiTheme.ACCENT, 6)
	rt.add_theme_font_override("normal_font", UiFonts.get_font(400, true))
	for c in then_show:
		c.visible = false
	var t := Typing.type_text(rt, "[i]%s[/i]" % bb, 20)
	p.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed:
			t.finish())
	var reveal := func():
		for c in then_show:
			if is_instance_valid(c):
				c.visible = true
		for c in then_show:
			if is_instance_valid(c) and c is LineEdit:
				c.grab_focus()
	if t.finished:
		reveal.call()
	else:
		t.done.connect(reveal)
	return t


static func hall_of_fame(parent: Node, meta: Dictionary) -> void:
	var hof: Array = meta.hallOfFame
	if hof.is_empty():
		Kit.text(parent, "Noch keine Staffeln gespielt.", 14, "muted")
		return
	var g := Kit.grid(parent, 9, 12, 6)
	for h in ["#", "Crawler", "Vorher", "Level", "Etage", "Kills", "Erfolge", "Ausgang", "Ende"]:
		var l := Kit.label(g, h.to_upper(), 11, "muted", 600)
		l.add_theme_font_override("font", UiFonts.get_font(600, false, 1))
	var rows := hof.duplicate()
	rows.reverse()
	for h in rows.slice(0, 12):
		var outcome := "Überlebt" if h.outcome == "ueberlebt" else ("Vertrag" if h.outcome == "vertrag" else "Tot")
		for cell in [J.s(h.season), h.name, h.background, "Lv %s" % J.s(h.level), "E%s" % J.s(h.floor), J.s(h.kills), J.s(h.achievements), outcome]:
			Kit.label(g, str(cell), 13)
		var cause := Kit.label(g, str(h.cause), 13, "muted")
		cause.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cause.custom_minimum_size = Vector2(120, 0)
		cause.size_flags_horizontal = Control.SIZE_EXPAND_FILL


# ================================================================ Titel

static func title_screen(root: Control, meta: Dictionary, has_save: bool, on_new: Callable, on_continue: Callable) -> void:
	var v := card_screen(root)
	logo(v, Db.world("SHOW_NAME"))
	Kit.text(v, "Ein textbasierter Dungeon-Crawl. 18 Etagen. Eine Galaxis schaut zu. Du hast einen Bademantel. Vielleicht.", 15, "muted", 6)
	Kit.spacer(v, 4)
	var row := Kit.hbox(v, 8)
	if has_save:
		Kit.button(row, "Staffel fortsetzen", on_continue, "PrimaryButton")
	Kit.button(row, "Neue Staffel starten", on_new, "Button" if has_save else "PrimaryButton")
	if has_save:
		Kit.text(v, "Achtung: Eine neue Staffel beendet den laufenden Crawl endgültig.", 12, "muted")
	Kit.section(v, "Karriere")
	var guides: Array = meta.guides
	var guide = guides.back() if not guides.is_empty() else null
	var line := "Staffeln gespielt: [b]%s[/b] · Achievements jemals: [b]%d[/b] · Geister im Dungeon: [b]%d[/b]" % [J.s(meta.season), meta.achievementsEver.size(), meta.ghosts.size()]
	if guide != null:
		line += " · Aktueller Guide: [b]%s[/b]" % Kit.esc(guide.name)
	Kit.text(v, line, 14, "muted")
	Kit.section(v, "Hall of Fame")
	hall_of_fame(v, meta)
	Kit.section(v, "So funktioniert’s")
	for li in [
		"Klick auf die Karte, um dich zu bewegen. Klick auf Gegner, um mit der gewählten Technik anzugreifen.",
		"Rundenbasiert: Jede Aktion kostet einen Zug (3 Minuten Spielzeit). Die Etage stürzt nach 5 Tagen ein.",
		"Wie du kämpfst, bestimmt deine Skills. Tritt viel – werde gut im Treten.",
		"Hardcore: Tod ist endgültig. Dein Geist bleibt aber im Dungeon zurück…",
	]:
		Kit.text(v, "·  " + Kit.esc(li), 12, "muted", 5)


# ================================================================ Interview

static func interview_screen(root: Control, on_done: Callable) -> void:
	var st := {"answers": {}, "order": [], "name": "", "pet_name": "", "stage": "name"}
	var fns := {}
	var next_question := func() -> Variant:
		for q in Rules.visible_questions(st.answers):
			if not st.answers.has(q.id):
				return q
		return null
	fns.draw = func() -> void:
		if st.stage == "name":
			var v := card_screen(root)
			var input := LineEdit.new()
			input.max_length = 24
			input.placeholder_text = "Dein Name"
			input.text = st.name
			var row := HBoxContainer.new()
			var go := func(_t = null):
				st.name = input.text.strip_edges() if input.text.strip_edges() != "" else "Namenlos"
				st.stage = "question"
				fns.draw.call()
			quote(v, "„Hallo! Hier spricht die Systemstimme. Bevor du in den Dungeon darfst, müssen wir ein paar Formalitäten klären. Es sind einige Fragen. Antworte ehrlich – es wirkt sich aus. Wie heißt du?“", [input, row])
			v.add_child(input)
			v.add_child(row)
			Kit.button(row, "Weiter", go, "PrimaryButton")
			input.text_submitted.connect(go)
			return
		var q = next_question.call() if st.stage == "question" else null
		if q != null:
			var done: int = st.order.size()
			var total: int = Rules.visible_questions(st.answers).size()
			var v := card_screen(root)
			Kit.text(v, "Frage %d von %d · Crawler %s" % [done + 1, total, Kit.esc(st.name)], 12, "muted")
			var pl := Kit.bar(v, float(done) / total, "", "#e9aa2c", "#ffd873", 5)
			pl.custom_minimum_size.y = 5
			var answers := VBoxContainer.new()
			answers.add_theme_constant_override("separation", 8)
			var many: bool = q.answers.size() > 7
			var grid := GridContainer.new()
			grid.columns = 2 if many else 1
			grid.add_theme_constant_override("h_separation", 8)
			grid.add_theme_constant_override("v_separation", 8)
			grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			answers.add_child(grid)
			var back_row := HBoxContainer.new()
			quote(v, "„%s“" % Kit.esc(q.question), [answers, back_row])
			v.add_child(answers)
			for i in q.answers.size():
				var a: Dictionary = q.answers[i]
				var idx: int = i
				var qid: String = q.id
				var cp := Kit.rbutton(grid, Kit.esc(a.label), func():
					st.answers[qid] = idx
					st.order.append(qid)
					if a.get("pet") != null:
						fns.ask_pet.call(a.pet.species, a.pet.defaultName, a.reaction)
					else:
						fns.reaction.call(a.reaction), "AnswerButton", false, "", 15)
				cp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if not st.order.is_empty():
				v.add_child(back_row)
				Kit.button(back_row, "Zurück", func():
					var last = st.order.pop_back()
					if last != null:
						st.answers.erase(last)
					# Antworten auf Folgefragen, die jetzt nicht mehr gestellt würden, verwerfen
					var vis := Rules.visible_questions(st.answers).map(func(x): return x.id)
					for id in st.answers.keys():
						if not vis.has(id):
							st.answers.erase(id)
					fns.draw.call())
			return
		# Zusammenfassung
		st.stage = "summary"
		var v := card_screen(root)
		var rest := VBoxContainer.new()
		rest.add_theme_constant_override("separation", 10)
		quote(v, "„Wunderbar, %s. Die Formalitäten sind erledigt. Deine Werte wurden berechnet. Deine Überlebenschance wurde auch berechnet. Die sagen wir dir lieber nicht.“" % Kit.esc(st.name), [rest])
		v.add_child(rest)
		var trait_ids: Array = []
		var visible := Rules.visible_questions(st.answers)
		for x in visible:
			if st.answers.has(x.id):
				for t in J.arr(x.answers[st.answers[x.id]], "traits"):
					if not trait_ids.has(t):
						trait_ids.append(t)
		var combos: Array = Db.t("interview", "INTERVIEW_COMBOS")
		for i in combos.size():
			if Rules.combo_when(i, st.answers):
				for t in combos[i].traits:
					if not trait_ids.has(t):
						trait_ids.append(t)
		Kit.section(rest, "Deine Eigenschaften")
		var kinds: Dictionary = Db.t("traits", "TRAIT_KIND_NAMES")
		var found := false
		for id in trait_ids:
			var t = Db.trait_def(id)
			if t == null:
				continue
			found = true
			Kit.text(rest, "·  [b]%s[/b] %s\n    %s" % [Kit.esc(t.name), Kit.muted("(%s)" % kinds[t.kind]), Kit.small(Kit.esc(t.description))], 14)
		if not found:
			Kit.text(rest, "Keine besonderen Eigenschaften.", 14, "muted")
		Kit.section(rest, "Deine Antworten")
		for x in visible:
			if st.answers.has(x.id):
				Kit.text(rest, "·  %s\n    %s" % [Kit.muted(Kit.esc(x.question)), Kit.esc(x.answers[st.answers[x.id]].label)], 13)
		var row := Kit.hbox(rest, 8)
		Kit.button(row, "Nochmal von vorn", func():
			st.answers.clear()
			st.order.clear()
			st.stage = "name"
			fns.draw.call())
		Kit.button(row, "In den Dungeon!", func(): on_done.call({"name": st.name, "answers": st.answers.duplicate(), "petName": st.pet_name if st.pet_name != "" else null}), "PrimaryButton")
	fns.reaction = func(text: String) -> void:
		var v := card_screen(root)
		var row := HBoxContainer.new()
		quote(v, "„%s“" % Kit.esc(text), [row])
		v.add_child(row)
		Kit.button(row, "Weiter", func(): fns.draw.call(), "PrimaryButton")
	fns.ask_pet = func(species: String, def: String, reaction: String) -> void:
		var v := card_screen(root)
		var input := LineEdit.new()
		input.max_length = 20
		input.placeholder_text = def
		var row := HBoxContainer.new()
		quote(v, "„%s Wie heißt %s?“" % [Kit.esc(reaction), "die Katze" if species == "Katze" else "der Hund"], [input, row])
		v.add_child(input)
		v.add_child(row)
		var go := func(_t = null):
			st.pet_name = input.text.strip_edges() if input.text.strip_edges() != "" else def
			fns.draw.call()
		Kit.button(row, "Weiter", go, "PrimaryButton")
		input.text_submitted.connect(go)
	fns.draw.call()


# ================================================================ Ende

static func end_screen(root: Control, s: Dictionary, meta: Dictionary, on_new: Callable, on_title: Callable) -> void:
	var victory: bool = s.status == "victory"
	var contract: bool = not victory and s.get("contractSigned", false)
	var quips: Array = Db.world("DEATH_QUIPS")
	var quip: String = quips[int(s.turn) % quips.size()]
	var p: Dictionary = s.player
	var headline := "Etage %d überlebt!" % s.floor if victory else ("In den Dienst übernommen" if contract else "Staffel beendet")
	var text: String
	if victory:
		text = "Du hast es bis ans Ende dessen geschafft, was bisher gebaut ist. Die Systemstimme ist beeindruckt und leicht verärgert. Weitere Etagen folgen."
	elif contract:
		text = "%s ist nicht tot – sondern jetzt Personal. In der nächsten Staffel wartet %s als Guide in der Gilde der Einweisung." % [p.name, p.name]
	else:
		text = "%s Ursache: %s. Der Geist von %s wandert jetzt durch Etage %d – mit der alten Ausrüstung. Vielleicht triffst du ihn in der nächsten Staffel." % [quip, J.nn(s, "deathCause", "unbekannt"), p.name, s.floor]
	var b: Dictionary = s.counters
	var v := card_screen(root)
	logo(v, headline, 36)
	var rest := VBoxContainer.new()
	rest.add_theme_constant_override("separation", 10)
	quote(v, Kit.esc(text), [])
	v.add_child(rest)
	Kit.section(rest, "Bilanz von %s (%s)" % [p.name, p.background])
	Kit.text(rest, "Level %d · Etage %d · %s Kills (%s Bosse) · %s Schaden ausgeteilt · %s eingesteckt · %s %s · %d Achievements · %s Boxen geöffnet" % [p.level, s.floor, J.s(b.kills), J.s(b.bossKills), J.s(b.damageDealt), J.s(b.damageTaken), J.s(b.steps), "Schritt" if b.steps == 1 else "Schritte", s.achievements.size(), J.s(b.boxesOpened)], 14, "muted")
	Kit.section(rest, "Hall of Fame")
	hall_of_fame(rest, meta)
	Kit.spacer(rest, 4)
	var row := Kit.hbox(rest, 8)
	Kit.button(row, "Neue Staffel", on_new, "PrimaryButton")
	Kit.button(row, "Zum Titel", on_title)
