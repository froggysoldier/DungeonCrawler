class_name Modals
extends Control
## Dialoge und Einblendungen. Immer nur ein Dialog
## ist offen; weitere warten in einer Schlange. Jeder Aufruf liefert einen
## Job, auf dessen Signal `closed(result)` man warten kann.

static var instance: Modals


class Job:
	extends RefCounted
	signal closed(result: Variant)
	var on_key: Callable


var _queue: Array = []
var _open := false
var _job: Job
var _back: ColorRect
var _center: CenterContainer
var _toasts: VBoxContainer


func _init() -> void:
	instance = self
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_back = ColorRect.new()
	_back.color = Color(4 / 255.0, 5 / 255.0, 9 / 255.0, 0.66)
	_back.set_anchors_preset(Control.PRESET_FULL_RECT)
	_back.mouse_filter = Control.MOUSE_FILTER_STOP
	_back.visible = false
	add_child(_back)
	_center = CenterContainer.new()
	_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_center)
	_toasts = VBoxContainer.new()
	_toasts.add_theme_constant_override("separation", 6)
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.anchor_left = 1.0
	_toasts.anchor_right = 1.0
	_toasts.offset_left = -350 - 330
	_toasts.offset_right = -350
	_toasts.offset_top = 56
	add_child(_toasts)


func _exit_tree() -> void:
	if instance == self:
		instance = null


func is_open() -> bool:
	return _open


## Freier Dialog. build(inhalt: VBoxContainer, close: Callable(result)).
func custom(build: Callable, width: float = 620.0, variant: String = "Modal") -> Job:
	var job := Job.new()
	var run := func(): _show(job, build, width, variant)
	if _open:
		_queue.append(run)
	else:
		run.call()
	return job


func _show(job: Job, build: Callable, width: float, variant: String) -> void:
	_open = true
	_job = job
	_back.visible = true
	_back.modulate.a = 0.0
	create_tween().tween_property(_back, "modulate:a", 1.0, 0.2)
	var panel := PanelContainer.new()
	panel.theme_type_variation = variant
	var vw := get_viewport_rect().size
	panel.custom_minimum_size = Vector2(minf(width, vw.x - 32), 0)
	_center.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	panel.modulate.a = 0.0
	panel.position.y += 10
	var tw := create_tween().set_parallel()
	tw.tween_property(panel, "modulate:a", 1.0, 0.22)
	var close := func(result: Variant = null) -> void: _close(job, panel, result)
	build.call(content, close)
	# Höhe an den Inhalt anpassen, höchstens 90 % des Fensters
	var fit := func() -> void:
		if not is_instance_valid(scroll):
			return
		var h := content.get_combined_minimum_size().y
		scroll.custom_minimum_size.y = minf(h, get_viewport_rect().size.y * 0.9 - 48)
	content.minimum_size_changed.connect(fit)
	fit.call_deferred()


func _close(job: Job, panel: Control, result: Variant) -> void:
	if _job != job:
		return
	panel.queue_free()
	_open = false
	_job = null
	_back.visible = false
	job.closed.emit(result)
	if not _queue.is_empty():
		var next: Callable = _queue.pop_front()
		next.call()


func _input(ev: InputEvent) -> void:
	if not _open or _job == null:
		return
	if ev is InputEventKey and ev.pressed and not ev.echo:
		if _job.on_key.is_valid():
			_job.on_key.call(ev)
		# Bei offenem Dialog erreicht das Spiel keine Tasten
		if not (get_viewport().gui_get_focus_owner() is LineEdit):
			get_viewport().set_input_as_handled()


# ================================================================ Bausteine

static func title(parent: Node, t: String) -> Label:
	var l := Kit.label(parent, t, 30, UiTheme.ACCENT)
	l.add_theme_font_override("font", UiFonts.pixel(700))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func speaker(parent: Node, t: String) -> void:
	var h := HBoxContainer.new()
	parent.add_child(h)
	var p := PanelContainer.new()
	p.theme_type_variation = "Speaker"
	h.add_child(p)
	var l := Kit.label(p, t.to_upper(), 16, UiTheme.ACCENT_2)
	l.add_theme_font_override("font", UiFonts.pixel(700, 1))
	Kit.spacer(parent, 4)


static func page(parent: Node, bb: String = "") -> RichTextLabel:
	var rt := Kit.text(parent, bb, 16, null, 8)
	rt.custom_minimum_size = Vector2(0, 80)
	return rt


## Fußzeile mit Linie: links ein Text, rechts Knöpfe. Gibt [links, rechts] zurück.
static func foot(parent: Node) -> Array:
	Kit.spacer(parent, 8)
	var line := ColorRect.new()
	line.color = UiTheme.LINE
	line.custom_minimum_size = Vector2(0, 1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(line)
	Kit.spacer(parent, 8)
	var h := Kit.hbox(parent, 8)
	var left := Kit.text(h, "", 12, "muted")
	left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var right := Kit.hbox(h, 8)
	right.size_flags_horizontal = Control.SIZE_SHRINK_END
	return [left, right]


static func _bb(text: String) -> String:
	# *Betonung* kursiv
	var re := RegEx.new()
	re.compile("\\*(.+?)\\*")
	return re.sub(Kit.esc(text), "[i]$1[/i]", true)


## Mehrseitiger Dialog (Systemstimme, Guide …).
func dialog(t: String, who: Variant, pages: Array) -> Job:
	var build := func(root: VBoxContainer, close: Callable) -> void:
		Modals.title(root, t)
		if who != null and String(who) != "":
			Modals.speaker(root, String(who))
		var page_el := Modals.page(root)
		var f := Modals.foot(root)
		var no: RichTextLabel = f[0]
		var state := {"page": 0, "typing": null}
		var btn := Kit.button(f[1], "Weiter", Callable(), "PrimaryButton")
		var draw := func() -> void:
			state.typing = Typing.type_text(page_el, Modals._bb(pages[state.page]), 22)
			no.text = "%d / %d" % [state.page + 1, pages.size()]
			btn.text = "Los geht’s" if state.page == pages.size() - 1 else "Weiter"
		var advance := func() -> void:
			# Erster Klick: Text sofort vollständig. Zweiter Klick: weiter.
			var ty: Typing = state.typing
			if ty and is_instance_valid(ty) and not ty.is_done():
				ty.finish()
				return
			if state.page < pages.size() - 1:
				state.page += 1
				draw.call()
			else:
				close.call()
		btn.pressed.connect(advance)
		_job.on_key = func(ev: InputEventKey) -> void:
			if ev.keycode == KEY_ENTER or ev.keycode == KEY_KP_ENTER or ev.keycode == KEY_SPACE:
				advance.call()
		draw.call()
	return custom(build)


## Freier Inhalt mit Schließen-Knopf. body(inhalt: VBoxContainer).
func html(t: String, body: Callable, button: String = "Schließen", width: float = 620.0) -> Job:
	var build := func(root: VBoxContainer, close: Callable) -> void:
		Modals.title(root, t)
		Kit.spacer(root, 4)
		body.call(root)
		var f := Modals.foot(root)
		Kit.button(f[1], button, func(): close.call(), "PrimaryButton")
		_job.on_key = func(ev: InputEventKey) -> void:
			if ev.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE]:
				close.call()
	return custom(build, width)


## Ja/Nein-Frage. Ergebnis: true bei Ja.
func confirm(t: String, text: String, yes: String, no: String = "Abbrechen") -> Job:
	var build := func(root: VBoxContainer, close: Callable) -> void:
		Modals.title(root, t)
		Kit.spacer(root, 4)
		Modals.page(root, Kit.esc(text))
		var f := Modals.foot(root)
		f[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
		Kit.button(f[1], no, func(): close.call(false))
		Kit.button(f[1], yes, func(): close.call(true), "PrimaryButton")
		_job.on_key = func(ev: InputEventKey) -> void:
			if ev.keycode in [KEY_ENTER, KEY_KP_ENTER]:
				close.call(true)
			elif ev.keycode == KEY_ESCAPE:
				close.call(false)
	return custom(build)


## Kurze Meldung oben rechts.
func toast(t: String, text: String, kind: String) -> void:
	var p := PanelContainer.new()
	p.theme_type_variation = "Toast"
	var sb: PixelBox = UiTheme.get_theme().get_stylebox("panel", "Toast").duplicate()
	sb.border_color = UiTheme.LINE_2
	var edge := {"achievement": UiTheme.ACHV, "skill": UiTheme.INFO, "warnung": UiTheme.DANGER}
	var accent: Color = edge.get(kind, UiTheme.ACCENT)
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	p.add_child(v)
	Kit.label(v, t, 14, null, 700)
	Kit.text(v, Kit.esc(text), 13, "muted")
	_toasts.add_child(p)
	# Farbiger linker Rand
	p.draw.connect(func(): p.draw_rect(Rect2(0, 6, 4, p.size.y - 12), accent))
	while _toasts.get_child_count() > 5:
		var old := _toasts.get_child(0)
		_toasts.remove_child(old)
		old.queue_free()
	p.modulate.a = 0.0
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.3)
	tw.tween_interval(5.0)
	tw.tween_property(p, "modulate:a", 0.0, 0.5)
	tw.tween_callback(p.queue_free)


## Alle Dialoge schließen, ohne sie zu zeigen (für Tests und beim Bildschirmwechsel).
func close_all() -> void:
	_queue.clear()
	if _job != null:
		var job := _job
		for c in _center.get_children():
			c.queue_free()
		_open = false
		_job = null
		_back.visible = false
		job.closed.emit(null)


func clear_toasts() -> void:
	Kit.clear(_toasts)
