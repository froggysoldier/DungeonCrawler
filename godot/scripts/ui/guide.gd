class_name Guide
extends Control
## Interaktives Tutorial: Ein Pfeil zeigt auf ein Teil der Oberfläche, das
## Teil blinkt, ein Kasten sagt, was es ist und was man jetzt tun soll. Erst
## wenn man es ausprobiert hat, geht es weiter. Beim ersten Kampf gibt es drei
## eigene Schritte (Bewegung und Aktion, angreifen, Runde beenden).
## Der Fortschritt steht in meta.guide ({"step": n, "fight": bool}).

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
	gv.meta["guide"] = {"step": 0, "fight": false}
	_cur = null
	_save()


func active() -> bool:
	var g := _state()
	return int(g.step) < _main.size() or not g.fight


## Der Schritt, der gerade dran ist (oder null).
func _pick() -> Variant:
	var g := _state()
	if gv.in_combat() and not g.fight:
		return _fight[clampi(_fight_i, 0, _fight.size() - 1)]
	if not gv.in_combat():
		# Kampf vorbei: Stand der letzte Schritt an, gilt er als gelernt,
		# sonst beginnt der Kampfteil beim nächsten Kampf von vorn
		if not g.fight and _fight_i >= _fight.size() - 1:
			g.fight = true
			_save()
		elif _fight_i > 0:
			_fight_i = 0
		if int(g.step) < _main.size():
			return _main[int(g.step)]
	return null


func _advance() -> void:
	var g := _state()
	if _cur == null:
		return
	if _fight.has(_cur):
		_fight_i += 1
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
		_base = {"pos": Vector2i(gv.s.player.pos.x, gv.s.player.pos.y), "turn": gv.s.turn, "ctx": gv.context_count, "round": int(gv.s.round.n) if gv.in_combat() else -1}
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


func _main_steps() -> Array:
	return [
		{"text": "Das bist du. [b]Klicke irgendwo auf die Karte[/b], und du läufst frei dorthin.",
			"target": _player_rect, "done": func(): return _moved(2)},
		{"text": "Jetzt [b]halte die linke Maustaste gedrückt[/b] und bewege die Maus. Deine Figur folgt ihr, bis ein Kampf beginnt.",
			"target": _player_rect, "done": func(): return _follow_ms > 600.0},
		{"text": "[b]Rechtsklick[/b] auf die Karte öffnet ein Menü mit allem, was dort geht: aufheben, anziehen, angreifen, öffnen, untersuchen. [b]Probier es aus.[/b]",
			"target": _player_rect, "done": func(): return gv.context_count > int(_base.ctx)},
		{"text": "Deine [b]Lebenspunkte[/b] und deine [b]Ausdauer[/b]. Sinken die Lebenspunkte auf null, ist die Staffel für dich vorbei. [b]Klicke darauf.[/b]",
			"target": func(): return gv._vitals, "click": true},
		{"text": "Der [b]Chat[/b]: Hier steht alles, was passiert. Die Knöpfe filtern ihn, „Überspringen“ zeigt neue Zeilen sofort ganz. [b]Klicke auf einen der Knöpfe.[/b]",
			"target": func(): return gv._log_bar, "click": true},
		{"text": "[b]Hier[/b] steht, was genau an deiner Stelle liegt oder steht, mit Knöpfen zum Aufheben und Benutzen. [b]Klicke darauf.[/b]",
			"target": func(): return gv._here_scroll, "click": true, "optional": true},
		{"text": "Das ist dein [b]Inventar[/b]: alles, was du bei dir trägst. [b]Öffne es mit einem Klick[/b] (oder Taste I).",
			"target": func(): return gv.tab_buttons.get("inventar"), "done": func(): return gv.tab_open and gv.tab == "inventar"},
		{"text": "Ein Klick auf einen Eintrag zeigt Einzelheiten und Knöpfe. [b]Klicke neben das Fenster[/b], um es wieder zu schließen.",
			"target": func(): return gv._drawer, "done": func(): return not gv.tab_open},
		{"text": "Unter [b]Ausrüstung[/b] siehst du, was du am Körper trägst. [b]Öffne sie[/b] (Taste A).",
			"target": func(): return gv.tab_buttons.get("ausruestung"), "done": func(): return gv.tab_open and gv.tab == "ausruestung"},
		{"text": "Unter [b]Ziele[/b] stehen Aufträge, Sponsoren und was die Show von dir will. [b]Öffne sie[/b] (Taste Z).",
			"target": func(): return gv.tab_buttons.get("ziele"), "done": func(): return gv.tab_open and gv.tab == "ziele"},
		{"text": "Unter [b]Crawler[/b] stehen deine Werte, später auch Klasse und Rasse. [b]Öffne ihn[/b] (Taste P).",
			"target": func(): return gv.tab_buttons.get("crawler"), "done": func(): return gv.tab_open and gv.tab == "crawler"},
		{"text": "Läuft diese Zeit ab, [b]stürzt die Etage ein[/b]. Bis dahin musst du die Treppe nach unten gefunden haben. [b]Klicke darauf.[/b]",
			"target": func(): return gv.collapse_pill, "click": true},
		{"text": "Unten sind deine [b]Aktionen[/b]. Im Kampf wählst du hier, womit und wie du zuschlägst. [b]Klicke auf „Warten“[/b] (Leertaste), dann vergeht ein Zug.",
			"target": func(): return Guide.find_text(gv._actionbar, "Warten") if Guide.find_text(gv._actionbar, "Warten") != null else gv._actionbar,
			"done": func(): return gv.s.turn > int(_base.turn)},
		{"text": "Im [b]Menü[/b] findest du Ton, Musik und alle Tasten (H). [b]Öffne es.[/b]",
			"target": func(): return gv.menu_button, "click": true},
		{"text": "Geschafft. Dein erstes Ziel ist die [b]Gilde der Einweisung[/b], sie ist auf der Karte markiert. Beim ersten Kampf zeige ich dir noch, wie Runden gehen.",
			"target": func(): return gv._mini_wrap if gv._mini_wrap.visible else null, "info": true, "button": "Los geht's"},
	]


func _fight_steps() -> Array:
	return [
		{"text": "[b]Kampf![/b] Jetzt geht es in Runden. Hier unten siehst du, wie viele Meter du in dieser Runde noch laufen kannst und ob deine Aktion bereit ist. Brauchst du mehr Weg, macht „Spurt“ (S) aus der Aktion Bewegung.",
			"target": func(): return gv._actionbar, "info": true},
		{"text": "[b]Klicke auf einen Gegner[/b], um ihn anzugreifen. Ist er zu weit weg, läufst du erst hin. Die Linie zum Mauszeiger ist grün, solange deine Bewegung reicht.",
			"target": _foe_rect, "done": func(): return gv.in_combat() and gv.s.round.get("acted", false)},
		{"text": "Aktion verbraucht. Mit der übrigen Bewegung kannst du noch zurückweichen. [b]Beende die Runde[/b] (Leertaste), dann sind die Gegner dran.",
			"target": func(): return Guide.find_text(gv._actionbar, "Runde beenden") if Guide.find_text(gv._actionbar, "Runde beenden") != null else gv._actionbar,
			"done": func(): return not gv.in_combat() or int(gv.s.round.n) > int(_base.round)},
	]


func _foe_rect() -> Variant:
	var list := gv.combat_targets()
	if list.is_empty():
		return null
	var m: Dictionary = list[0]
	return gv.map.screen_rect(gv.anim.draw_pos(m.uid, Vector2(m.pos.x, m.pos.y)))
