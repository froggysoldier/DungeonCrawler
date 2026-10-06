class_name Guide
extends Control
## Interaktives Tutorial: Ein Pfeil zeigt auf ein Teil der Oberfläche, das
## Teil blinkt, ein Kasten sagt, was es ist und was man jetzt tun soll. Erst
## wenn man es ausprobiert hat, geht es weiter. Jeder Bereich kommt einzeln
## dran: Laufen, Karte, Kopfzeile, Werte, Chat, jeder Reiter, Aktionsleiste,
## Menü. Beim ersten Kampf folgt die Kampfleiste Teil für Teil.
## Der Fortschritt steht in meta.guide ({"step": n, "fight": bool, "fight_i": n}).

var gv: GameView
var _main: Array = []
var _fight: Array = []
var _box: PanelContainer
var _count: Label
var _text: RichTextLabel
var _next: Button
## Aktueller Schritt und was beim Beginn galt (Startfeld, Zug, Runde …).
var _cur: Variant = null
var _base := {}
var _clicked := false
var _follow_ms := 0.0
var _fight_i := 0
var _target := Rect2()


func _init(view: GameView) -> void:
	gv = view
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 10
	_main = _main_steps()
	_fight = _fight_steps()


func _ready() -> void:
	_box = PanelContainer.new()
	_box.theme_type_variation = "Tip"
	_box.mouse_filter = Control.MOUSE_FILTER_STOP
	_box.custom_minimum_size = Vector2(340, 0)
	_box.visible = false
	add_child(_box)
	var v := Kit.vbox(_box, 6)
	_count = Kit.label(v, "", 12, "muted")
	_count.add_theme_font_override("font", UiFonts.pixel(700, 1))
	_text = Kit.text(v, "", 16, null, 4)
	_text.custom_minimum_size = Vector2(320, 0)
	var row := Kit.hbox(v, 8)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp)
	Kit.button(row, "Tutorial beenden", finish, "SmallButton", false, "Alle weiteren Hinweise auslassen (im Menü wiederholbar)")
	_next = Kit.button(row, "Weiter", func(): _advance(), "SmallPrimary")


# ---------------------------------------------------------------- Zustand

func _state() -> Dictionary:
	var g = gv.meta.get("guide")
	if not (g is Dictionary):
		g = {"step": 0, "fight": false}
		gv.meta["guide"] = g
	return g


func _save() -> void:
	Meta.save_meta(gv.meta)


## Tutorial abbrechen: alle Schritte gelten als erledigt.
func finish() -> void:
	var g := _state()
	g.step = _main.size()
	g.fight = true
	_cur = null
	_box.visible = false
	_save()
	queue_redraw()


func restart() -> void:
	gv.meta["guide"] = {"step": 0, "fight": false, "fight_i": 0}
	_fight_i = 0
	_cur = null
	_save()


func active() -> bool:
	var g := _state()
	return int(g.step) < _main.size() or not g.fight


## Der Schritt, der gerade dran ist (oder null).
func _pick() -> Variant:
	var g := _state()
	_fight_i = int(g.get("fight_i", 0))
	if gv.in_combat() and not g.fight:
		return _fight[clampi(_fight_i, 0, _fight.size() - 1)]
	if not gv.in_combat():
		# Kampf vorbei: Stand der letzte Schritt an, gilt der Kampfteil als
		# gelernt; sonst geht es beim nächsten Kampf an derselben Stelle weiter
		if not g.fight and _fight_i >= _fight.size() - 1:
			g.fight = true
			_save()
		if int(g.step) < _main.size():
			return _main[int(g.step)]
	return null


## Nummer eines Schrittes (für Tests und Sprünge).
func index_of(id: String) -> int:
	for n in _main.size():
		if _main[n].get("id") == id:
			return n
	return -1


func _advance() -> void:
	var g := _state()
	if _cur == null:
		return
	if _fight.has(_cur):
		_fight_i += 1
		g.fight_i = _fight_i
		if _fight_i >= _fight.size():
			g.fight = true
	else:
		g.step = int(g.step) + 1
	_cur = null
	_save()


# ---------------------------------------------------------------- Ablauf

func _process(delta: float) -> void:
	if gv.s.status != "playing" or gv.modal_open() or not active():
		_hide()
		return
	var st = _pick()
	if st == null:
		_hide()
		return
	if not is_same(st, _cur):
		_cur = st
		_clicked = false
		_follow_ms = 0.0
		_base = {"pos": Vector2i(gv.s.player.pos.x, gv.s.player.pos.y), "turn": gv.s.turn, "ctx": gv.context_count, "round": int(gv.s.round.n) if gv.in_combat() else -1,
			"keys": gv.key_presses, "zoom": gv.map.zoom_index, "mini": gv.minimap_big, "part": gv.part, "zone": gv.zone}
	if gv._mouse_follow:
		_follow_ms += delta * 1000.0
	var target = st.target.call()
	var rect := Rect2()
	if target is Control:
		var c: Control = target
		if not is_instance_valid(c) or not c.is_visible_in_tree() or c.size.y < 4:
			target = null
		else:
			rect = c.get_global_rect()
	elif target is Rect2:
		rect = target
	if target == null and st.get("optional", false):
		_advance()
		return
	var done: Callable = st.get("done", Callable())
	if (done.is_valid() and done.call()) or (st.get("click", false) and _clicked):
		_advance()
		return
	_target = rect
	_count.text = ("KAMPF %d/%d" % [_fight_i + 1, _fight.size()]) if _fight.has(st) else ("TUTORIAL %d/%d" % [int(_state().step) + 1, _main.size()])
	if _text.text != st.text:
		_text.text = st.text
	_next.visible = st.get("info", false)
	_next.text = st.get("button", "Weiter")
	_box.visible = true
	_place(rect)
	queue_redraw()


func _hide() -> void:
	if _box and _box.visible:
		_box.visible = false
		queue_redraw()


func _input(ev: InputEvent) -> void:
	if _cur == null or not _box.visible:
		return
	if ev is InputEventMouseButton and ev.pressed and _target.has_area() and _target.grow(4).has_point(ev.global_position):
		_clicked = true


## Kasten neben das Ziel: darunter, darüber, links oder rechts – wo Platz ist.
func _place(r: Rect2) -> void:
	_box.reset_size()
	var bs := _box.size
	var vs := get_viewport_rect().size
	var gap := 56.0
	var pos: Vector2
	if not r.has_area():
		pos = (vs - bs) / 2
	else:
		var tries := [
			Vector2(r.get_center().x - bs.x / 2, r.end.y + gap),
			Vector2(r.get_center().x - bs.x / 2, r.position.y - bs.y - gap),
			Vector2(r.position.x - bs.x - gap, r.get_center().y - bs.y / 2),
			Vector2(r.end.x + gap, r.get_center().y - bs.y / 2),
		]
		pos = tries[0]
		for t in tries:
			var q := Rect2(t, bs)
			if q.position.x >= 8 and q.position.y >= 8 and q.end.x <= vs.x - 8 and q.end.y <= vs.y - 8 and not q.intersects(r.grow(8)):
				pos = t
				break
	pos.x = clampf(pos.x, 8, maxf(8, vs.x - bs.x - 8))
	pos.y = clampf(pos.y, 8, maxf(8, vs.y - bs.y - 8))
	_box.position = pos.round()


# ---------------------------------------------------------------- Zeichnen

func _draw() -> void:
	if not _box.visible or not _target.has_area():
		return
	var t := Time.get_ticks_msec() / 1000.0
	var blink := 0.5 + 0.5 * sin(t * TAU * 1.4)
	var gold := UiTheme.ACCENT
	var r := _target.grow(4)
	# Blinkender Rahmen um das Ziel
	draw_rect(r, Color(gold, 0.10 + 0.22 * blink))
	draw_rect(r, Color(0, 0, 0, 0.7), false, 6.0)
	draw_rect(r, Color(gold, 0.55 + 0.45 * blink), false, 3.0)
	# Pfeil vom Kasten zum Ziel, wippt leicht
	var box := Rect2(_box.position, _box.size)
	var from := _edge_point(box, r.get_center())
	var to := _edge_point(r, box.get_center())
	var d := to - from
	if d.length() < 24:
		return
	var dir := d.normalized()
	to -= dir * (6 + 6 * blink)
	from += dir * 4
	var side := Vector2(-dir.y, dir.x)
	var head := [to, to - dir * 22 + side * 13, to - dir * 22 - side * 13]
	draw_line(from, to - dir * 18, Color(0, 0, 0, 0.75), 10.0)
	draw_colored_polygon(PackedVector2Array([to + dir * 3, head[1] - dir * 3 + side * 3, head[2] - dir * 3 - side * 3]), Color(0, 0, 0, 0.75))
	draw_line(from, to - dir * 18, gold, 5.0)
	draw_colored_polygon(PackedVector2Array(head), gold)


## Punkt auf dem Rand von r in Richtung toward.
static func _edge_point(r: Rect2, toward: Vector2) -> Vector2:
	var c := r.get_center()
	var d := toward - c
	if d == Vector2.ZERO:
		return c
	var sx := (r.size.x / 2) / maxf(absf(d.x), 0.001)
	var sy := (r.size.y / 2) / maxf(absf(d.y), 0.001)
	return c + d * minf(minf(sx, sy), 1.0)


# ---------------------------------------------------------------- Schritte

func _player_rect() -> Rect2:
	return gv.map.screen_rect(gv._pos_now())


## Knopf mit diesem Text unterhalb von root (für „Warten“, „Runde beenden“).
static func find_text(root: Node, text: String) -> Control:
	if root == null:
		return null
	for c in root.get_children():
		if c is Button and String(c.text).begins_with(text):
			return c
		if c is ClickPanel:
			for l in c.find_children("*", "Label", true, false):
				if String(l.text).begins_with(text):
					return c
		var f := find_text(c, text)
		if f != null:
			return f
	return null


func _moved(n: int) -> bool:
	var b: Vector2i = _base.pos
	return maxi(absi(gv.s.player.pos.x - b.x), absi(gv.s.player.pos.y - b.y)) >= n


func _tab(id: String, key: String, text: String) -> Dictionary:
	return {"id": id, "text": "%s [b]Öffne ihn[/b] (Taste %s)." % [text, key],
		"target": func(): return gv.tab_buttons.get(id), "done": func(): return gv.tab_open and gv.tab == id}


func _part(id: String) -> Variant:
	var c = gv.bar_parts.get(id)
	return c if c != null and is_instance_valid(c) else null


func _main_steps() -> Array:
	return [
		{"id": "laufen", "text": "Das bist du. [b]Klicke irgendwo auf den Boden[/b], und du läufst frei genau dorthin.",
			"target": _player_rect, "done": func(): return _moved(2)},
		{"id": "folgen", "text": "Jetzt [b]halte die linke Maustaste auf dem Boden gedrückt[/b] und bewege die Maus. Deine Figur folgt ihr, bis ein Kampf beginnt.",
			"target": _player_rect, "done": func(): return _follow_ms > 600.0},
		{"id": "tasten", "text": "Laufen geht auch mit den [b]Pfeiltasten[/b], zwei zugleich laufen schräg. [b]Drück eine Pfeiltaste.[/b]",
			"target": _player_rect, "done": func(): return gv.key_presses > int(_base.keys)},
		{"id": "rechtsklick", "text": "[b]Rechtsklick[/b] auf den Boden, einen Gegenstand oder eine Tür öffnet ein Menü mit allem, was dort geht: aufheben, anziehen, öffnen, untersuchen, hingehen. [b]Probier es aus.[/b]",
			"target": _player_rect, "done": func(): return gv.context_count > int(_base.ctx)},
		{"id": "karte", "text": "Oben links ist deine [b]Karte[/b]: alles, was du schon gesehen hast. [b]Klicke darauf[/b] (oder K), dann wird sie groß; noch ein Klick macht sie wieder klein.",
			"target": func(): return gv._mini_wrap, "done": func(): return gv.minimap_big != bool(_base.mini), "optional": true},
		{"id": "ort", "text": "Daneben steht, [b]wo du gerade bist[/b]: der Raum oder „Gang“. Betrittst du einen Raum, steht im Chat, was es dort gibt. [b]Klicke darauf.[/b]",
			"target": func(): return gv._room_wrap, "click": true},
		{"id": "zoom", "text": "Mit [b]Plus und Minus[/b] (oder dem Mausrad) zoomst du heran und heraus. [b]Probier es.[/b]",
			"target": func(): return gv.zoom_box, "done": func(): return gv.map.zoom_index != int(_base.zoom)},
		{"id": "etage", "text": "Oben steht die [b]Etage[/b], auf der du bist, und ihr Name. Jede Etage hat eigene Monster und eigene Regeln. [b]Klicke darauf.[/b]",
			"target": func(): return gv.top_refs.get("etage"), "click": true},
		{"id": "uhr", "text": "Die [b]Uhrzeit[/b] im Dungeon. Jeder Zug sind drei Minuten, nachts sind andere Dinge unterwegs. [b]Klicke darauf.[/b]",
			"target": func(): return gv.top_refs.get("uhr"), "click": true},
		{"id": "einsturz", "text": "Läuft diese Zeit ab, [b]stürzt die Etage ein[/b]. Bis dahin musst du die Treppe nach unten gefunden haben. [b]Klicke darauf.[/b]",
			"target": func(): return gv.collapse_pill, "click": true},
		{"id": "gold", "text": "Dein [b]Gold[/b]. Du sammelst es beim Drüberlaufen ein und gibst es bei Händlern aus. [b]Klicke darauf.[/b]",
			"target": func(): return gv.top_refs.get("gold"), "click": true},
		{"id": "boxen", "text": "Deine [b]Lootboxen[/b]: Belohnungen für Erfolge. Öffnen kannst du sie im Safe Room oder in einer Gilde. [b]Klicke darauf.[/b]",
			"target": func(): return gv.top_refs.get("boxen"), "click": true, "optional": true},
		{"id": "werte", "text": "Deine Werte: [b]Rot[/b] sind die Lebenspunkte, fallen sie auf null, ist die Staffel für dich vorbei. [b]Grün[/b] ist die Ausdauer, jeder Angriff kostet etwas. Später kommen [b]Mana[/b] für Zauber und die [b]Blase[/b] dazu. [b]Klicke darauf.[/b]",
			"target": func(): return gv._vitals, "click": true},
		{"id": "hier", "text": "[b]Hier[/b] steht, was genau an deiner Stelle liegt oder steht, mit Knöpfen zum Aufheben, Anziehen und Benutzen. [b]Klicke darauf.[/b]",
			"target": func(): return gv._here_scroll, "click": true, "optional": true},
		{"id": "chat", "text": "Der [b]Chat[/b] zeigt alles, was passiert. Mit [b]Alles, Kampf, Funde, Gespräche[/b] filterst du ihn, „Überspringen“ zeigt neue Zeilen sofort ganz. [b]Klicke auf einen der Knöpfe.[/b]",
			"target": func(): return gv._log_bar, "click": true},
		_tab("crawler", "P", "Reiter [b]Crawler[/b]: deine Werte, Kampfwerte und Effekte, später Klasse und Rasse."),
		_tab("ziele", "Z", "Reiter [b]Ziele[/b]: Aufträge, Sponsoren und laufende Einlagen der Show."),
		_tab("inventar", "I", "Reiter [b]Inventar[/b]: alles, was du bei dir trägst. Ein Klick auf einen Eintrag zeigt Werte und Knöpfe. Bis zur Gilde hast du nur eine Hand frei."),
		_tab("ausruestung", "A", "Reiter [b]Ausrüstung[/b]: was du am Körper trägst, und welche Plätze noch frei sind."),
		_tab("handwerk", "B", "Reiter [b]Handwerk[/b]: aus Fundstücken etwas bauen, mit Rezepten."),
		_tab("skills", "L", "Reiter [b]Skills[/b]: was du durch Tun lernst. Wer viel tritt, wird besser im Treten."),
		_tab("erfolge", "O", "Reiter [b]Erfolge[/b]: Achievements und deine Statistik."),
		{"id": "zu", "text": "Ein Reiter klappt zu mit derselben Taste, mit Esc oder mit einem [b]Klick daneben[/b]. [b]Klicke neben das Fenster.[/b]",
			"target": func(): return gv._drawer, "done": func(): return not gv.tab_open},
		{"id": "aktionen", "text": "Unten die [b]Aktionsleiste[/b]: links dein gewählter Angriff (Körperteil mit 1 bis 7, Ausführung mit Q bis R), daneben Warten (Leertaste) und Aufheben (G). [b]Klicke auf „Warten“[/b], dann vergeht ein Zug.",
			"target": func(): return Guide.find_text(gv._actionbar, "Warten") if Guide.find_text(gv._actionbar, "Warten") != null else gv._actionbar,
			"done": func(): return gv.s.turn > int(_base.turn)},
		{"id": "menue", "text": "Im [b]Menü[/b] (Esc) findest du Ton, Musik, alle Tasten und dieses Tutorial noch einmal. [b]Öffne es.[/b]",
			"target": func(): return gv.menu_button, "click": true},
		{"id": "ende", "text": "Fertig. Dein erstes Ziel ist die [b]Gilde der Einweisung[/b]: Auf dem Boden steht ihr Name, auf der Karte oben links ist sie markiert. Beim ersten Kampf erkläre ich dir die Kampfleiste.",
			"target": _guild_rect, "info": true, "button": "Los geht's"},
	]


func _fight_steps() -> Array:
	return [
		{"id": "k_runde", "text": "[b]Kampf![/b] Jetzt geht es in Runden. Hier siehst du die [b]Runde[/b], deine übrige [b]Bewegung[/b] (blauer Balken, in Metern) und ob deine [b]Aktion[/b] bereit ist. Pro Runde darfst du laufen und eine Aktion ausführen.",
			"target": func(): return _part("runde"), "info": true},
		{"id": "k_womit", "text": "[b]Womit[/b] schlägst du zu? Faust, Tritt, Knie, Ellbogen, Kopfstoß, Waffe (1 bis 6) oder Werfen (7). [b]Wähle etwas anderes als jetzt.[/b]",
			"target": func(): return _part("womit"), "done": func(): return gv.part != String(_base.part)},
		{"id": "k_wie", "text": "[b]Wie[/b]: Normal, Sprung, Stampfen oder Anlauf (Q bis R). Wuchtigere Ausführungen kosten mehr Ausdauer, die Kosten stehen im Hinweis, wenn du mit der Maus darauf zeigst.",
			"target": func(): return _part("wie"), "info": true},
		{"id": "k_wohin", "text": "[b]Wohin[/b]: Kopf, Körper, Arme oder Beine (Y bis V). Der Kopf ist schwer zu treffen, kann aber benommen machen, Beine lassen Gegner humpeln. [b]Wähle eine Zone.[/b]",
			"target": func(): return _part("wohin"), "done": func(): return gv.zone != String(_base.zone)},
		{"id": "k_sonst", "text": "[b]Sonstiges[/b]: Deckung (schwerer zu treffen), [b]Spurt[/b] (S, die Aktion wird zu doppelter Bewegung), Trank und Warten. Zauber stehen daneben.",
			"target": func(): return _part("sonstiges"), "info": true},
		{"id": "k_ziel", "text": "Rechts steht dein [b]Ziel[/b] mit Trefferchance. Tab wechselt das Ziel, Enter greift es an. Der goldene Ring auf dem Boden zeigt, wen du gewählt hast.",
			"target": func(): return _part("ziel"), "info": true},
		{"id": "k_angriff", "text": "[b]Klicke auf einen Gegner[/b], um ihn anzugreifen. Ist er zu weit weg, läufst du erst hin. Die Linie zum Mauszeiger ist grün, solange deine Bewegung reicht.",
			"target": _foe_rect, "done": func(): return gv.in_combat() and gv.s.round.get("acted", false)},
		{"id": "k_ende", "text": "Aktion verbraucht. Mit der übrigen Bewegung kannst du noch zurückweichen. [b]Beende die Runde[/b] (Leertaste), dann sind die Gegner dran.",
			"target": func(): return _part("ende") if _part("ende") != null else gv._actionbar,
			"done": func(): return not gv.in_combat() or int(gv.s.round.n) > int(_base.round)},
	]


## Die Gilde der Einweisung auf dem Bildschirm, sonst die Karte oben links.
func _guild_rect() -> Variant:
	var room = J.find(gv.s.map.rooms, func(r): return r.get("marked", false))
	if room != null:
		var c := MapGen.center(room)
		var r := gv.map.screen_rect(Vector2(c.x, c.y))
		if gv.map.get_global_rect().encloses(r):
			return r
	return gv._mini_wrap if gv._mini_wrap.visible else null


func _foe_rect() -> Variant:
	var list := gv.combat_targets()
	if list.is_empty():
		return null
	var m: Dictionary = list[0]
	return gv.map.screen_rect(gv.anim.draw_pos(m.uid, Vector2(m.pos.x, m.pos.y)))
