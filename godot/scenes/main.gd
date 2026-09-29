extends Control
## Einstieg: Titel, Interview, Spiel, Endbildschirm.
## Dialoge und Einblendungen liegen darüber, die Klänge laufen nebenher.

var meta: Dictionary
var view: GameView
var screen_root: Control
var modals: Modals
var sound: SoundBox


func _ready() -> void:
	theme = UiTheme.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	sound = SoundBox.new()
	add_child(sound)
	screen_root = Control.new()
	screen_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(screen_root)
	modals = Modals.new()
	add_child(modals)
	# Entwicklerschalter: direkt eine Partie starten (Seed 1, ohne Interview)
	var args := OS.get_cmdline_args() + OS.get_cmdline_user_args()
	if args.has("--schnellstart"):
		var s := Game.new_game({"name": "Test", "answers": {}, "seed": 1, "meta": Meta.load_meta()})
		s.pendingDialogs.clear()
		meta = Meta.load_meta()
		start_game(s)
		return
	show_title()


func _clear() -> void:
	if view != null and is_instance_valid(view):
		view.queue_free()
	view = null
	# Musik nur im Spiel; die Spielansicht meldet Etage und Kampf selbst
	sound.music(0)
	modals.clear_toasts()
	Kit.clear(screen_root)


func show_title() -> void:
	_clear()
	meta = Meta.load_meta()
	var save = Meta.load_run()
	Screens.title_screen(screen_root, meta, save != null, func(): _new_season(save), func(): start_game(save))


func _new_season(save: Variant) -> void:
	if save != null:
		var ok = await modals.confirm("Neue Staffel?", "Dein laufender Crawl wird als gescheitert gewertet (Hardcore!). Wirklich neu beginnen?", "Ja, neue Staffel").closed
		if not ok:
			return
		save.status = "dead"
		save.deathCause = "hat die Show verlassen"
		meta = Meta.record_run_end(meta, save)
	show_interview()


func show_interview() -> void:
	_clear()
	Screens.interview_screen(screen_root, func(r: Dictionary):
		var s := Game.new_game({"name": r.name, "answers": r.answers, "petName": r.petName, "meta": meta})
		Meta.save_run(s)
		start_game(s))


func start_game(s: Dictionary) -> void:
	_clear()
	view = GameView.new(s, meta)
	screen_root.add_child(view)
	view.ended.connect(func(ended: Dictionary):
		meta = Meta.record_run_end(meta, ended)
		_clear()
		Screens.end_screen(screen_root, ended, meta, show_interview, show_title))
	# Offene Dialoge (z. B. Intro) direkt anzeigen
	view.flush_dialogs.call_deferred()
