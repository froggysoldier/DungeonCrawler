class_name Typing
extends Node
## Schreibmaschinen-Effekt: Text erscheint
## Zeichen für Zeichen mit weichem Tastenklicken und blinkender Schreibmarke.
## finish() zeigt sofort den ganzen Text.

signal done

const CARET := "[bgcolor=#f4c24fd0] [/bgcolor]"
const CLICK := {"dialog": [46.0, 1.0], "log": [72.0, 0.55]}

var label: RichTextLabel
var full := ""
var tokens: PackedStringArray = []
var ms := 18.0
var sound := "dialog"
var finished := false
var _i := 0
var _shown := ""
var _acc := 0.0

static var _re: RegEx


static func tokenize(bb: String) -> PackedStringArray:
	if _re == null:
		_re = RegEx.new()
		_re.compile("\\[[^\\]]+\\]|[\\s\\S]")
	var out := PackedStringArray()
	for m in _re.search_all(bb):
		out.append(m.get_string())
	return out


## Tippt BBCode in ein RichTextLabel.
static func type_text(l: RichTextLabel, bb: String, ms_per_char: float = 18.0, snd: String = "dialog") -> Typing:
	var t := Typing.new()
	t.label = l
	t.full = bb
	t.ms = ms_per_char
	t.sound = snd
	l.add_child(t)
	if ms_per_char <= 0:
		t.finish()
		return t
	t.tokens = tokenize(bb)
	l.text = ""
	t._tick()
	return t


func is_done() -> bool:
	return finished


func _process(delta: float) -> void:
	if finished:
		return
	_acc += delta * 1000.0
	while _acc >= ms and not finished:
		_acc -= ms
		_tick()


func _tick() -> void:
	# Pro Schritt mehrere Zeichen, damit lange Texte nicht ewig dauern
	for n in 2:
		if _i < tokens.size():
			var tok := tokens[_i]
			_i += 1
			_shown += tok
			_click(tok)
	if _i >= tokens.size():
		finish()
		return
	label.text = _shown + CARET


func _click(tok: String) -> void:
	if sound == "stumm" or tok.begins_with("[") and tok.length() > 1 and tok != "[lb]":
		return
	var cfg: Array = CLICK.get(sound, CLICK.dialog)
	if SoundBox.instance:
		SoundBox.instance.type_click(tok == " ", cfg[1], cfg[0])


func finish() -> void:
	if finished:
		return
	finished = true
	set_process(false)
	if is_instance_valid(label):
		label.text = full
	done.emit()


## Warteschlange für mehrere Zeilen (das Log): Zeile für Zeile tippen.
class Queue:
	extends RefCounted
	var _queue: Array = []
	var _current: Typing
	var ms := 9.0
	var on_step: Callable

	func push(l: RichTextLabel, bb: String) -> void:
		_queue.append([l, bb])
		# Bei vielen wartenden Zeilen die älteren sofort zeigen
		while _queue.size() > 6:
			var old: Array = _queue.pop_front()
			if is_instance_valid(old[0]):
				old[0].visible = true
				old[0].text = old[1]
		if _current == null:
			_next()

	func finish_all() -> void:
		if _current and is_instance_valid(_current):
			_current.finish()
		for q in _queue:
			if is_instance_valid(q[0]):
				q[0].visible = true
				q[0].text = q[1]
		_queue.clear()

	func _next() -> void:
		while not _queue.is_empty():
			var item: Array = _queue.pop_front()
			if not is_instance_valid(item[0]):
				continue
			item[0].visible = true
			_current = Typing.type_text(item[0], item[1], ms, "log")
			if _current.finished:
				_current = null
				continue
			_current.done.connect(func():
				_current = null
				if on_step.is_valid():
					on_step.call()
				_next())
			return
		_current = null
