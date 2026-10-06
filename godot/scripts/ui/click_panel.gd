class_name ClickPanel
extends PanelContainer
## Ein Knopf mit beliebigem Inhalt (mehrzeilig, Tastenkappe, farbige Teile).
## Sieht aus wie ein Button der gewählten Theme-Variante und meldet Klicks.

signal pressed

var variant := "Button"
var disabled := false:
	set(v):
		disabled = v
		_apply()
## Fester Hintergrund statt der Button-Stile (z. B. Zielkarten im Kampf).
var fixed_panel: StyleBox
var _hover := false
var _down := false
var _labels: Array = []


func _init(v: String = "Button") -> void:
	variant = v
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_mode = Control.FOCUS_NONE


func _ready() -> void:
	mouse_entered.connect(func():
		_hover = true
		_apply())
	mouse_exited.connect(func():
		_hover = false
		_down = false
		_apply())
	_apply()


## Beschriftung, deren Farbe dem Zustand folgt.
func track_label(l: Control) -> void:
	_labels.append(l)
	_apply()


func _gui_input(ev: InputEvent) -> void:
	if disabled:
		return
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			_down = true
			_apply()
		elif _down:
			_down = false
			_apply()
			if _hover:
				pressed.emit()
		accept_event()


var _applied := ""


func _apply() -> void:
	var th := UiTheme.get_theme()
	var state := "disabled" if disabled else ("pressed" if _down else ("hover" if _hover else "normal"))
	# Nur bei einem Wechsel neu setzen: jede Überschreibung kostet Zeit
	var stamp := "%s|%s|%d|%s" % [state, variant, _labels.size(), fixed_panel != null]
	if stamp == _applied:
		return
	_applied = stamp
	add_theme_stylebox_override("panel", fixed_panel if fixed_panel != null else th.get_stylebox(state, variant))
	var key := "font_disabled_color" if disabled else ("font_hover_color" if _hover else "font_color")
	var col := th.get_color(key, variant)
	mouse_default_cursor_shape = Control.CURSOR_ARROW if disabled else Control.CURSOR_POINTING_HAND
	for l in _labels:
		if not is_instance_valid(l):
			continue
		if l is Label:
			l.add_theme_color_override("font_color", col)
		elif l is RichTextLabel:
			l.add_theme_color_override("default_color", col)
