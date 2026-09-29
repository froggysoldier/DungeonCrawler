class_name Kit
extends RefCounted
## Bausteine für die Oberfläche (Abschnitt, Karte, Zeile, Knopf, Balken)
## als Godot-Controls.
## Text mit Farben und Hervorhebungen läuft über BBCode in RichTextLabel.


## Text für BBCode sicher machen.
static func esc(v: Variant) -> String:
	return str(v).replace("[", "[lb]")


static func col(text: String, color: Variant) -> String:
	var c: String = UiTheme.HEX.get(color, color) if color is String else (color as Color).to_html(false)
	if not c.begins_with("#"):
		c = "#" + c
	return "[color=%s]%s[/color]" % [c, text]


static func muted(text: String) -> String:
	return col(text, "muted")


static func small(text: String) -> String:
	return "[font_size=12]%s[/font_size]" % text


static func b(text: String) -> String:
	return "[b]%s[/b]" % text


static func i(text: String) -> String:
	return "[i]%s[/i]" % text


static func clear(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()


static func _add(parent: Node, c: Node) -> Node:
	if parent != null:
		parent.add_child(c)
	return c


static func vbox(parent: Node, sep: int = 6) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return _add(parent, v)


static func hbox(parent: Node, sep: int = 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return _add(parent, h)


static func flow(parent: Node, sep: int = 4) -> HFlowContainer:
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", sep)
	f.add_theme_constant_override("v_separation", sep)
	f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return _add(parent, f)


static func grid(parent: Node, cols: int, hsep: int = 10, vsep: int = 5) -> GridContainer:
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", hsep)
	g.add_theme_constant_override("v_separation", vsep)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return _add(parent, g)


static func margin(parent: Node, l: int, t: int, r: int, bm: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", l)
	m.add_theme_constant_override("margin_top", t)
	m.add_theme_constant_override("margin_right", r)
	m.add_theme_constant_override("margin_bottom", bm)
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return _add(parent, m)


static func spacer(parent: Node, h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return _add(parent, c)


## Text mit BBCode, bricht um, passt die Höhe an.
static func text(parent: Node, bb: String, size: int = 14, color: Variant = null, line_sep: int = 3) -> RichTextLabel:
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.scroll_active = false
	rt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rt.add_theme_constant_override("line_separation", line_sep)
	if size != 14:
		for k in ["normal_font_size", "bold_font_size", "italics_font_size", "bold_italics_font_size"]:
			rt.add_theme_font_size_override(k, size)
	if color != null:
		rt.add_theme_color_override("default_color", UiTheme.css(UiTheme.HEX.get(color, color)) if color is String else color)
	rt.text = bb
	return _add(parent, rt)


## Einzeilige Beschriftung.
static func label(parent: Node, t: String, size: int = 14, color: Variant = null, weight: int = 400) -> Label:
	var l := Label.new()
	l.text = t
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if size != 14:
		l.add_theme_font_size_override("font_size", size)
	if weight != 400:
		l.add_theme_font_override("font", UiFonts.get_font(weight))
	if color != null:
		l.add_theme_color_override("font_color", UiTheme.css(UiTheme.HEX.get(color, color)) if color is String else color)
	return _add(parent, l)


## Abschnittsüberschrift in Goldschrift mit feiner Linie.
static func section(parent: Node, title: String, extra_bb: String = "") -> HBoxContainer:
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 0)
	_add(parent, wrap)
	spacer(wrap, 10)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	wrap.add_child(h)
	var l := Label.new()
	l.text = title.to_upper()
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_font_override("font", UiFonts.pixel(700, 1))
	l.add_theme_color_override("font_color", UiTheme.ACCENT)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(l)
	if extra_bb != "":
		var rt := text(h, extra_bb, 12)
		rt.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		rt.autowrap_mode = TextServer.AUTOWRAP_OFF
	var line := Rule.new()
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.custom_minimum_size = Vector2(10, 2)
	h.add_child(line)
	spacer(wrap, 4)
	return h


## Gepunktete Pixellinie, die nach rechts in Stufen ausläuft.
class Rule:
	extends Control

	func _draw() -> void:
		var n := int(size.x / 6)
		for i in n:
			var a := 1.0 - floorf(float(i) / n * 4) / 4
			draw_rect(Rect2(i * 6, 0, 4, 2), Color(UiTheme.LINE_2, a))


## Normaler Knopf.
static func button(parent: Node, t: String, cb: Callable, variant: String = "Button", disabled: bool = false, tip: String = "") -> Button:
	var btn := Button.new()
	btn.text = t
	btn.theme_type_variation = variant
	btn.disabled = disabled
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_ARROW if disabled else Control.CURSOR_POINTING_HAND
	if tip != "":
		btn.tooltip_text = tip
	if cb.is_valid():
		btn.pressed.connect(cb)
	return _add(parent, btn)


## Knopf mit Tastenkappe rechts (z. B. „Faust [1]“) und optionalem Zusatztext.
static func kbutton(parent: Node, t: String, key: String, cb: Callable, variant: String = "Button", disabled: bool = false, tip: String = "", extra_bb: String = "", size: int = 13) -> ClickPanel:
	var cp := ClickPanel.new(variant)
	cp.disabled = disabled
	if tip != "":
		cp.tooltip_text = tip
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cp.add_child(h)
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", UiTheme.pixel_size(size))
	l.add_theme_font_override("font", UiFonts.pixel(500))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	cp.track_label(l)
	if key != "":
		h.add_child(keycap(key))
	if extra_bb != "":
		var rt := text(h, extra_bb, 11)
		rt.autowrap_mode = TextServer.AUTOWRAP_OFF
		rt.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		rt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if cb.is_valid():
		cp.pressed.connect(cb)
	_add(parent, cp)
	return cp


## Knopf mit frei gestaltetem Inhalt (BBCode, mehrzeilig).
static func rbutton(parent: Node, bb: String, cb: Callable, variant: String = "Button", disabled: bool = false, tip: String = "", size: int = 13) -> ClickPanel:
	var cp := ClickPanel.new(variant)
	cp.disabled = disabled
	if tip != "":
		cp.tooltip_text = tip
	var rt := text(cp, bb, size)
	cp.track_label(rt)
	if cb.is_valid():
		cp.pressed.connect(cb)
	_add(parent, cp)
	return cp


## Kleine Tastenkappe.
static func keycap(key: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := UiTheme.box(Color("#0e1015"), Color("#3a3f4d"), 4, 1, Vector4(4, 0, 4, 0))
	sb.border_width_bottom = 4
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var l := Label.new()
	l.text = key
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_font_override("font", UiFonts.pixel(700))
	l.add_theme_color_override("font_color", Color("#b9bdc8"))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(9, 0)
	p.add_child(l)
	return p


## Karte (Gegenstand, Achievement, Detail). Gibt den Inhalt zurück.
static func card(parent: Node, variant: String = "Item", sep: int = 3) -> VBoxContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = variant
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_add(parent, p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	p.add_child(v)
	return v


## Pixel-Bild als Control, ganzzahlig vergrößert und mittig in einem Feld der
## Größe box (sonst genau so groß wie das Bild). dim blendet es ab (leerer Platz).
static func icon(parent: Node, name: String, tint: Variant = null, scale: int = 2, box: Vector2 = Vector2.ZERO, dim: bool = false) -> Stage:
	var st := Stage.new()
	var sz := Vector2(PixelArt.size_of(name) * scale)
	st.custom_minimum_size = box if box != Vector2.ZERO else sz
	st.mouse_filter = Control.MOUSE_FILTER_IGNORE
	st.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	st.items = [{"name": name, "tint": tint, "scale": scale, "center": true, "mod": Color(1, 1, 1, 0.3) if dim else Color.WHITE}]
	return _add(parent, st)


## Pixel-Bild im BBCode-Text (Tooltips). Das Bild wird vorab pixelgenau
## vergrößert (Text braucht die weiche Filterung) und bekommt einen Pfad im
## Ressourcen-Zwischenspeicher, über den [img] es findet.
static var _bb_images := {}


static func img(name: String, tint: Variant = null, scale: float = 1.0) -> String:
	var key := "roh" if tint == null else ((tint as Color).to_html() if tint is Color else String(tint).trim_prefix("#"))
	var path := "res://pixel_bb/%s.tex" % ("%s|%s|%s" % [name, key, scale]).md5_text()
	if not _bb_images.has(path):
		var src := PixelArt.texture(name, tint)
		if src == null:
			return ""
		var im := src.get_image()
		im.resize(maxi(1, roundi(im.get_width() * scale)), maxi(1, roundi(im.get_height() * scale)), Image.INTERPOLATE_NEAREST)
		var tex := ImageTexture.create_from_image(im)
		tex.take_over_path(path)
		_bb_images[path] = tex
	var sz := Vector2(PixelArt.size_of(name)) * scale
	return "[img=%dx%d]%s[/img]" % [roundi(sz.x), roundi(sz.y), path]


## Kleine Bühne für Pixel-Figuren: jedes Element {name, tint, scale} steht
## entweder mittig (center) oder mit den Füßen bei foot, auf Wunsch mit Schatten.
class Stage:
	extends Control
	var items: Array = []

	func _init() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func _draw() -> void:
		for e in items:
			var sc: int = e.get("scale", 2)
			var mod: Color = e.get("mod", Color.WHITE)
			if e.get("center", false):
				var sz := Vector2(PixelArt.size_of(e.name) * sc)
				PixelArt.draw(self, e.name, ((size - sz) / 2.0).floor(), sc, e.get("tint"), false, mod)
				continue
			var foot: Vector2 = e.foot
			if e.get("shadow", true):
				PixelArt.draw_foot(self, "aufsatz/schatten", foot + Vector2(0, 6 * sc), sc)
			PixelArt.draw_foot(self, e.name, foot, sc, e.get("tint"), e.get("flip", false), mod)


## Balken mit Verlauf und Beschriftung (HP, Ausdauer, XP …).
class Bar:
	extends Control
	var frac := 0.0
	var label := ""
	var c0 := Color.RED
	var c1 := Color.RED
	var pulse := false

	func _process(_d: float) -> void:
		if pulse:
			queue_redraw()

	func _draw() -> void:
		# Pixel-Balken: dunkler Rahmen, Füllung mit heller Oberkante und dunkler Unterkante
		var u := 2.0
		var w := floorf(size.x / u) * u
		var h := floorf(size.y / u) * u
		draw_rect(Rect2(u, 0, w - 2 * u, h), Color("#07080b"))
		draw_rect(Rect2(0, u, w, h - 2 * u), Color("#07080b"))
		draw_rect(Rect2(u, u, w - 2 * u, h - 2 * u), Color("#161922"))
		var fw := floorf((w - 2 * u) * clampf(frac, 0.0, 1.0) / u) * u
		if fw > 0:
			var a := 1.0
			if pulse:
				a = 0.75 + 0.25 * cos(Time.get_ticks_msec() / 1000.0 * TAU)
			# Farbe in vier Stufen von c0 nach c1
			var steps := 4
			for i in steps:
				var x0 := floorf(fw * i / steps / u) * u
				var x1 := floorf(fw * (i + 1) / steps / u) * u
				if x1 > x0:
					draw_rect(Rect2(u + x0, u, x1 - x0, h - 2 * u), Color(c0.lerp(c1, float(i) / (steps - 1)), a))
			draw_rect(Rect2(u, u, fw, u), Color(1, 1, 1, 0.22 * a))
			if h >= 6 * u:
				draw_rect(Rect2(u, h - 2 * u, fw, u), Color(0, 0, 0, 0.22 * a))
		if label == "":
			return
		var f := UiFonts.pixel(700)
		var fs := 16
		var y := roundf((h + f.get_ascent(fs) - f.get_descent(fs)) / 2.0)
		draw_string(f, Vector2(10, y + 2), label, HORIZONTAL_ALIGNMENT_LEFT, w - 12, fs, Color(0, 0, 0, 0.9))
		draw_string(f, Vector2(8, y), label, HORIZONTAL_ALIGNMENT_LEFT, w - 12, fs, UiTheme.TEXT)


static func bar(parent: Node, frac: float, t: String, c0: String, c1: String, height: float = 20, pulse: bool = false) -> Bar:
	var b := Bar.new()
	b.frac = frac
	b.label = t
	b.c0 = Color(c0)
	b.c1 = Color(c1)
	b.pulse = pulse
	b.custom_minimum_size = Vector2(0, height)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	return _add(parent, b)


## Dünner Fortschrittsbalken in Gold.
static func progress(parent: Node, frac: float, tip: String = "") -> Bar:
	var b := bar(parent, frac, "", "#e9aa2c", "#ffd873", 6)
	if tip != "":
		b.tooltip_text = tip
	return b


## Gesperrter Bereich (gestrichelter Kasten).
static func locked(parent: Node, bb: String) -> RichTextLabel:
	var v := card(parent, "Locked")
	var rt := text(v, "[center]%s[/center]" % bb, 14, "muted")
	return rt
