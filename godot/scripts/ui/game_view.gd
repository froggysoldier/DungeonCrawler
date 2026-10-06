class_name GameView
extends Control
## Die Spielansicht: Kopfzeile, Karte mit
## Übersichtskarte und Tooltips, Seitenleiste mit Reitern, Aktionsleiste
## (im Kampf die Kampfsequenz) und das getippte Log.

signal ended(s: Dictionary)

const STEP_MS := Animator.STEP_MS

const PART_KEYS := {"faust": "1", "tritt": "2", "knie": "3", "ellbogen": "4", "kopf": "5", "waffe": "6", "wurf": "7"}
const MOVE_KEYS := {"normal": "Q", "sprung": "W", "stampfen": "E", "anlauf": "R"}
const ZONE_KEYS := {"kopf": "Y", "koerper": "X", "arme": "C", "beine": "V"}
const DIR_KEYS := {
	KEY_UP: Vector2i(0, -1), KEY_DOWN: Vector2i(0, 1), KEY_LEFT: Vector2i(-1, 0), KEY_RIGHT: Vector2i(1, 0),
	KEY_KP_8: Vector2i(0, -1), KEY_KP_2: Vector2i(0, 1), KEY_KP_4: Vector2i(-1, 0), KEY_KP_6: Vector2i(1, 0),
	KEY_KP_7: Vector2i(-1, -1), KEY_KP_9: Vector2i(1, -1), KEY_KP_1: Vector2i(-1, 1), KEY_KP_3: Vector2i(1, 1),
}

var s: Dictionary
var meta: Dictionary

var tab := "crawler"
## Ist ein Reiter ausgeklappt?
var tab_open := false
var here_folded := false
var folds := {}
var log_filter := "alles"
var show_all_boxes := false
var minimap_big := false
var achv_view := "erfolge"
var achv_open := {}
var part := "faust"
var pending_spell: Variant = null
var missile_mana := 4
var move := "normal"
var zone := "koerper"
var target_uid: Variant = null
var hover: Variant = null
var fight: Variant = null
var inspected: Variant = null
var traveling := false
var is_ended := false
var selecting := false
## Gedrückte Richtungstasten (Taste -> Richtung); zwei zugleich gehen schräg.
var held: Dictionary = {}
## Klick-Weg: noch anzulaufende Punkte (frei, in Feldern).
var _route: Array = []
var _route_fight := false
var _route_round := -1
## Nach einem vergeblichen Schritt (Schlamm, festgehalten) kurz warten.
var _wait_until := 0.0
var _follow_cache := {"key": "", "pts": []}
## Wegvorschau: Feld, über dem die Maus gerade ist, und seit wann.
var _preview_key := ""
var _preview_at := 0.0
const PREVIEW_DELAY_MS := 70.0
## Linke Maustaste gedrückt auf der Karte: nach kurzer Zeit folgt die Figur
## der Maus, bis ein Kampf beginnt oder die Taste losgelassen wird.
var _press_at := -1.0
var _mouse_follow := false
const FOLLOW_AFTER_MS := 220.0
## Nach dem Laufen nachzuholen: speichern, alles neu aufbauen.
var _save_due := false
var _refresh_due := false
var last_step := 0.0
var _path_cache := {"key": "", "path": null}
var _minimap_key := ""
var _last_log_id := -1
var _typer := Typing.Queue.new()

var anim := Animator.new()
var tiles: Tiles
var map: MapView
var minimap: Minimap

var _top: HBoxContainer
var _mapwrap: Control
var _room_label: Label
var _room_wrap: PanelContainer
var _mini_wrap: PanelContainer
var _zoom_out: Button
var _zoom_in: Button
var _tip: PanelContainer
var _tip_text: RichTextLabel
var _combat_frame: Control
var _here: VBoxContainer
var _vitals: VBoxContainer
var _here_scroll: ScrollContainer
var _tabs: HBoxContainer
var _tab_content: VBoxContainer
var _tab_scroll: ScrollContainer
## Ausgeklappter Reiter über der Karte.
var _drawer: PanelContainer
var _drawer_title: Label
var _side: PanelContainer
var _actionbar: PanelContainer
var _log_scroll: ScrollContainer
var _log: VBoxContainer
var _log_bar: HBoxContainer
var _log_prev := {}
var _banner: Control
## Für das Tutorial: Knöpfe der Reiter, Einsturz-Anzeige, Menüknopf,
## wie oft das Rechtsklick-Menü offen war.
var tab_buttons := {}
var collapse_pill: Control
var menu_button: Control
var context_count := 0
var guide: Guide


func _init(state: Dictionary, meta_state: Dictionary) -> void:
	s = state
	meta = meta_state
	theme = UiTheme.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# Klänge vom Spielstart nicht nachträglich abspielen
	Fx.drain_sfx(s)
	Fx.drain_fx(s)


func _ready() -> void:
	_build()
	_typer.on_step = _scroll_log
	refresh()
	guide = Guide.new(self)
	add_child(guide)


static func modals() -> Modals:
	return Modals.instance


static func sound() -> SoundBox:
	return SoundBox.instance


func modal_open() -> bool:
	return Modals.instance != null and Modals.instance.is_open()


# ---------------------------------------------------------------- Aufbau

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = UiTheme.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)
	# Kopfzeile: links Sendung, Etage, Uhr und Hinweise, rechts die Reiter
	var top_panel := PanelContainer.new()
	top_panel.theme_type_variation = "TopBar"
	top_panel.custom_minimum_size = Vector2(0, 52)
	root.add_child(top_panel)
	var top_row := Kit.hbox(top_panel, 10)
	# Zu viele Einträge werden rechts abgeschnitten, statt die Ansicht zu verbreitern
	var top_clip := ScrollContainer.new()
	top_clip.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	top_clip.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	top_clip.mouse_filter = Control.MOUSE_FILTER_PASS
	top_clip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(top_clip)
	_top = HBoxContainer.new()
	_top.add_theme_constant_override("separation", 8)
	_top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_clip.add_child(_top)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 4)
	_tabs.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top_row.add_child(_tabs)
	_line(root)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 0)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 0)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(left)
	# Karte
	_mapwrap = Control.new()
	_mapwrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_mapwrap.clip_contents = true
	left.add_child(_mapwrap)
	tiles = Tiles.new()
	add_child(tiles)
	map = MapView.new()
	map.s = s
	map.anim = anim
	map.set_anchors_preset(Control.PRESET_FULL_RECT)
	_mapwrap.add_child(map)
	map.tile_hovered.connect(_on_hover)
	map.tile_clicked.connect(_on_map_click)
	map.zoom_requested.connect(zoom_map)
	tiles.build()
	tiles.ready_changed.connect(func(): map.tiles = tiles)
	# Innerer Schatten und roter Kampfrahmen
	_combat_frame = FrameGlow.new()
	_combat_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	_combat_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mapwrap.add_child(_combat_frame)
	var rl := PanelContainer.new()
	_room_wrap = rl
	rl.theme_type_variation = "RoomLabel"
	rl.position = Vector2(12, 12)
	rl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mapwrap.add_child(rl)
	_room_label = Kit.label(rl, "", 13, Color("#d8d4ca"), 600)
	# Übersichtskarte
	_mini_wrap = PanelContainer.new()
	_mini_wrap.theme_type_variation = "MiniWrap"
	_mini_wrap.visible = false
	_mini_wrap.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_mini_wrap.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			toggle_minimap())
	_mapwrap.add_child(_mini_wrap)
	minimap = Minimap.new()
	minimap.s = s
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mini_wrap.add_child(minimap)
	var hint := Kit.label(_mini_wrap, "Karte · K", 10, "muted")
	hint.size_flags_horizontal = Control.SIZE_SHRINK_END
	hint.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	# Zoom
	var zc := VBoxContainer.new()
	zc.add_theme_constant_override("separation", 6)
	_mapwrap.add_child(zc)
	_zoom_out = Kit.button(null, "−", func(): zoom_map(-1), "RoundButton", false, "Herauszoomen (Taste -)")
	_zoom_in = Kit.button(null, "+", func(): zoom_map(1), "RoundButton", false, "Hineinzoomen (Taste +)")
	for zb in [_zoom_out, _zoom_in]:
		zb.custom_minimum_size = Vector2(34, 34)
	zc.add_child(_zoom_out)
	zc.add_child(_zoom_in)
	# Ausgeklappter Reiter: Tafel oben rechts über der Karte
	_drawer = PanelContainer.new()
	_drawer.theme_type_variation = "Drawer"
	_drawer.visible = false
	_mapwrap.add_child(_drawer)
	var dv := Kit.vbox(_drawer, 6)
	var dh := Kit.hbox(dv, 6)
	_drawer_title = Kit.label(dh, "", 18, UiTheme.ACCENT, 700)
	_drawer_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Kit.button(dh, "Schließen", func(): close_tab(), "SmallButton", false, "Reiter zuklappen (Esc oder dieselbe Taste)")
	_tab_scroll = ScrollContainer.new()
	_tab_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tab_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dv.add_child(_tab_scroll)
	var tm := Kit.margin(_tab_scroll, 2, 2, 10, 2)
	_tab_content = Kit.vbox(tm, 5)
	_mapwrap.resized.connect(func():
		zc.position = _mapwrap.size - Vector2(12 + 34, 12 + 74)
		_layout_minimap()
		_layout_drawer())
	# Tooltip
	_tip = PanelContainer.new()
	_tip.theme_type_variation = "Tip"
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip.visible = false
	_tip.z_index = 1
	_mapwrap.add_child(_tip)
	_tip_text = Kit.text(_tip, "", 13, null, 4)
	_tip_text.custom_minimum_size = Vector2(300, 0)
	# Unten: Aktionsleiste (im Kampf die Kampfsequenz)
	var bottom := PanelContainer.new()
	bottom.theme_type_variation = "Bottom"
	left.add_child(bottom)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 0)
	bottom.add_child(bv)
	_line(bv)
	_actionbar = PanelContainer.new()
	_actionbar.theme_type_variation = "ActionBar"
	bv.add_child(_actionbar)
	# Rechts: Werte, "Hier" und der Chat (Log)
	var vline := ColorRect.new()
	vline.color = UiTheme.LINE
	vline.custom_minimum_size = Vector2(1, 0)
	body.add_child(vline)
	_side = PanelContainer.new()
	_side.theme_type_variation = "Side"
	_side.custom_minimum_size = Vector2(400, 0)
	body.add_child(_side)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 0)
	_side.add_child(sv)
	var vm := Kit.margin(sv, 14, 10, 14, 10)
	_vitals = Kit.vbox(vm, 5)
	_line(sv)
	_here_scroll = ScrollContainer.new()
	_here_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sv.add_child(_here_scroll)
	var hm := Kit.margin(_here_scroll, 14, 2, 14, 0)
	_here = Kit.vbox(hm, 4)
	_here.minimum_size_changed.connect(_fit_here)
	_line(sv)
	_log_bar = Kit.hbox(Kit.margin(sv, 14, 6, 14, 2), 4)
	_log_scroll = ScrollContainer.new()
	_log_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sv.add_child(_log_scroll)
	var lm := Kit.margin(_log_scroll, 14, 6, 14, 10)
	_log = Kit.vbox(lm, 4)
	_log_scroll.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_typer.finish_all())


static func _line(parent: Node) -> void:
	var l := ColorRect.new()
	l.color = UiTheme.LINE
	l.custom_minimum_size = Vector2(0, 1)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)


func _fit_here() -> void:
	var h := _here.get_combined_minimum_size().y
	var sv_h := size.y - 52 - _vitals.get_combined_minimum_size().y - 20
	# Der Chat behält immer mindestens gut die Hälfte
	_here_scroll.custom_minimum_size.y = minf(h + 2, sv_h * 0.4) if h > 1 else 0.0


## Tafel des ausgeklappten Reiters: oben rechts, so hoch wie nötig.
func _layout_drawer() -> void:
	if _drawer == null:
		return
	var w := _mapwrap.size
	var dw := minf(560, w.x - 24)
	# So hoch wie der Inhalt, höchstens bis zum unteren Rand der Karte
	var want := _tab_content.get_combined_minimum_size().y + 110
	_drawer.size = Vector2(dw, clampf(want, 160, maxf(160, w.y - 24)))
	_drawer.position = Vector2(w.x - dw - 12, 12)


func _layout_minimap() -> void:
	var w := _mapwrap.size
	var sz := Vector2(minf(520, w.x * 0.7), minf(360, w.y * 0.7)) if minimap_big else Vector2(190, 130)
	_mini_wrap.size = sz
	# Übersichtskarte oben links, der Raumname rechts daneben
	_mini_wrap.position = Vector2(12, 12)
	_room_wrap.position = Vector2(12 + sz.x + 10, 12) if _mini_wrap.visible else Vector2(12, 12)
	minimap.queue_redraw()


## Innerer Schatten der Karte in Stufen, im Kampf mit pulsierendem roten Pixelrahmen.
class FrameGlow:
	extends Control
	var combat := false

	func _process(_d: float) -> void:
		if combat:
			queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var col := Color(0, 0, 0)
		var a := 0.5
		var bands := 5
		var pulse := 0.0
		if combat:
			pulse = 0.5 - 0.5 * cos(Time.get_ticks_msec() / 2400.0 * TAU)
			col = Color(200 / 255.0, 30 / 255.0, 20 / 255.0)
			a = 0.3 + 0.12 * roundf(pulse * 2) / 2
			bands = 6 + int(roundf(pulse * 2))
		# Bänder von 8 px, nach innen durchsichtiger
		for i in bands:
			var ba := a * (1.0 - float(i) / bands)
			var d := i * 8.0
			var c := Color(col, ba)
			draw_rect(Rect2(d, d, w - 2 * d, 8), c)
			draw_rect(Rect2(d, h - d - 8, w - 2 * d, 8), c)
			draw_rect(Rect2(d, d + 8, 8, h - 2 * d - 16), c)
			draw_rect(Rect2(w - d - 8, d + 8, 8, h - 2 * d - 16), c)
		if combat:
			var bright := roundf(pulse * 2) / 2
			var edge := Color(0.9 + 0.1 * bright, 0.27 + 0.1 * bright, 0.2, 0.9)
			draw_rect(Rect2(0, 0, w, 4), edge)
			draw_rect(Rect2(0, h - 4, w, 4), edge)
			draw_rect(Rect2(0, 4, 4, h - 8), edge)
			draw_rect(Rect2(w - 4, 4, 4, h - 8), edge)


## Karte vergrößern oder verkleinern.
func zoom_map(delta: int) -> void:
	if not map.zoom(delta):
		return
	var bounds := map.zoom_bounds()
	_zoom_out.disabled = bounds.min
	_zoom_in.disabled = bounds.max


# ---------------------------------------------------------------- Bild für Bild

func _process(delta: float) -> void:
	var now := Animator.now_ms()
	_follow_mouse(now)
	_move_free(minf(delta, 0.05), now)
	if not walking():
		if _refresh_due:
			_refresh_due = false
			refresh()
		_persist()
	_draw_frame()


func _draw_frame() -> void:
	var path: Variant = null
	var attack := false
	if hover != null and not traveling and held.is_empty() and not _mouse_follow and s.status == "playing":
		var key := "%d,%d|%d,%d|%d|%s" % [hover.x, hover.y, s.player.pos.x, s.player.pos.y, s.turn, part]
		# Erst rechnen, wenn die Maus kurz ruht: Weite Wege kosten Zeit, und
		# beim Wischen über die Karte soll nichts ruckeln
		if _path_cache.key != key:
			if _preview_key != key:
				_preview_key = key
				_preview_at = Animator.now_ms()
			if Animator.now_ms() - _preview_at >= PREVIEW_DELAY_MS:
				_path_cache = _plan_preview(key)
		path = _path_cache.path
		attack = _path_cache.get("attack", false)
	map.hover = hover
	map.hover_label = _path_cache.get("hover_label", "") if hover != null and _path_cache.key != "" else ""
	map.path = path
	map.path_pts = _path_cache.get("pts", []) if path != null else []
	# Im Kampf: Weg bis zur Reichweite der Runde, Länge in Metern
	map.path_ok = -1.0
	map.path_label = ""
	if path != null and not map.path_pts.is_empty():
		var steps: int = (path as Array).size()
		map.path_label = ("Angriff · %s · %s" % [FreeMove.meters(steps), _path_cache.get("chance", "")]) if attack else FreeMove.meters(steps)
		if in_combat():
			var left := int(s.round.move)
			map.path_ok = FreeMove.length(map.path_pts) * minf(1.0, float(left) / steps)
	map.redraw()
	var room = Game.current_room(s)
	_room_label.text = room.name if room != null else "Gang"
	_draw_minimap()


## Trefferchance gegen einen Gegner, so weit man sie kennt.
func _hit_text(mon: Dictionary) -> String:
	if pending_spell != null:
		return "Zauber"
	if not Identify.describe_monster(s, mon).showHitChance:
		return "Treffer unklar"
	return "%d %%" % clampi(Combat.hit_chance(s, mon, technique()), 0, 100)


## Wegvorschau zum Feld unter der Maus. Über einem Gegner: der Weg bis
## neben ihn (hinlaufen und zuschlagen), sofern es ein Nahkampfangriff ist.
func _plan_preview(key: String) -> Dictionary:
	var out := {"key": key, "path": null, "pts": []}
	var m: Dictionary = s.map
	if not MapGen.in_bounds(m, hover.x, hover.y):
		return out
	var i := MapGen.idx(m, hover.x, hover.y)
	if not m.explored[i]:
		return out
	var tp := _pos(hover)
	var mon = Ai.monster_at(s, tp)
	var grid: Variant = null
	if mon != null:
		if not _vis_now().has(i):
			return out
		out.chance = _hit_text(mon)
		var blocker = Combat.technique_blocker(s, mon, technique())
		if part == "wurf" or Fov.chebyshev(tp, s.player.pos) <= 1:
			# Kein Weg nötig: Chance (oder was fehlt) steht über dem Gegner
			out.hover_label = ("Angriff · %s" % out.chance) if blocker == null else String(blocker).trim_suffix(".")
			return out
		grid = Game.plan_path(s, tp)
		if grid is Array and not grid.is_empty():
			grid = (grid as Array).slice(0, (grid as Array).size() - 1)
		out.attack = true
	elif MapGen.is_walkable(m, hover.x, hover.y) or MapGen.tile_at(m, hover.x, hover.y) == "door":
		grid = Game.plan_path(s, tp)
	if grid is Array and not grid.is_empty():
		out.path = grid
		out.pts = FreeMove.smooth(s, _pos_now(), grid)
	return out


static func _pos(v: Variant) -> Dictionary:
	return {"x": int(v.x), "y": int(v.y)}


func visible_set() -> Dictionary:
	return map.visible_set


func _draw_minimap() -> void:
	var on := Game.has_unlock(s, "minimap")
	_mini_wrap.visible = on
	if not on:
		return
	var key := "%d|%d|%d,%d|%s" % [s.floor, s.turn, s.player.pos.x, s.player.pos.y, minimap_big]
	if key == _minimap_key:
		return
	_minimap_key = key
	_layout_minimap()


func toggle_minimap() -> void:
	minimap_big = not minimap_big
	if minimap_big:
		raise_window(_mini_wrap)
	_minimap_key = ""
	_draw_minimap()


# ---------------------------------------------------------------- Kampfmodus

## Kampf läuft, sobald ein wacher Gegner, der dich bemerkt hat, in Sicht ist.
## Läuft eine Kampfrunde (siehe Rounds)?
func in_combat() -> bool:
	return Rounds.active(s)


## Sichtbare Felder zum aktuellen Stand (nach einer Aktion sofort neu).
func _vis_now() -> Dictionary:
	var key := "%d|%d|%d|%d" % [s.turn, s.player.pos.x, s.player.pos.y, s.floor]
	if key != _vis_key:
		_vis_key = key
		_vis_cache = Game.visible_tiles(s)
	return _vis_cache


var _vis_key := ""
var _vis_cache: Dictionary = {}


func _update_combat_mode() -> void:
	var now: bool = s.status == "playing" and in_combat()
	if sound():
		var boss := now and J.some(combat_targets(), func(m): return m.rank != "normal" and m.rank != "elite")
		sound().music(s.floor if s.status == "playing" else 0, now, boss)
	_combat_frame.combat = now
	_combat_frame.queue_redraw()
	if now and fight == null:
		fight = {"kills": Stats.stat(s, "kills"), "xp": Stats.stat(s, "xp.gesamt"), "turn": s.turn, "hp": s.player.hp}
		_stop_moving()
		held.clear()
		var foes := combat_targets().filter(func(m): return m.get("aware", false))
		var names := J.uniq(foes.map(func(m): return Identify.describe_monster(s, m).name))
		var who := ("%s und weitere" % ", ".join(names.slice(0, 2))) if names.size() > 2 else " und ".join(names)
		Log.add(s, "%s %s dich entdeckt." % [who, "haben" if foes.size() > 1 else "hat"], "gefahr")
		# Beim Betreten einer Boss-Kammer übernimmt der Versus-Bildschirm den Auftritt
		if s.get("pendingVersus") == null:
			banner("Kampf", who, "start")
			if sound():
				sound().play_combat_start()
	elif not now and fight != null:
		var f: Dictionary = fight
		fight = null
		if s.status != "playing":
			return
		var kills := int(Stats.stat(s, "kills") - f.kills)
		var xp := int(Stats.stat(s, "xp.gesamt") - f.xp)
		var turns: int = s.turn - f.turn
		var lost := maxi(0, f.hp - s.player.hp)
		var bits := ["%d %s" % [turns, "Zug" if turns == 1 else "Züge"]]
		if kills:
			bits.append("%d besiegt" % kills)
		if xp:
			bits.append("+%d Erfahrung" % xp)
		if lost:
			bits.append("%d Lebenspunkte verloren" % lost)
		Log.add(s, "Kampf vorbei: %s." % ", ".join(bits), "kampf")
		banner("Sieg" if kills else "Kampf vorbei", " · ".join(bits), "end")
		if sound():
			sound().play_combat_end()


## Banner quer über die Karte bei Kampfbeginn und -ende.
func banner(title: String, sub: String, kind: String) -> void:
	if _banner and is_instance_valid(_banner):
		_banner.queue_free()
	var b := Banner.new()
	b.title = title
	b.sub = sub
	b.kind = kind
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mapwrap.add_child(b)
	b.set_anchors_preset(Control.PRESET_FULL_RECT)
	_banner = b


class Banner:
	extends Control
	var title := ""
	var sub := ""
	var kind := "start"
	var _t0 := Time.get_ticks_msec()

	func _process(_d: float) -> void:
		queue_redraw()
		var life := 1700 if kind == "start" else 2200
		if Time.get_ticks_msec() - _t0 > life:
			queue_free()

	func _draw() -> void:
		var t := (Time.get_ticks_msec() - _t0) / 1000.0
		var fade_at := 1.2 if kind == "start" else 1.7
		var a := clampf(t / 0.35, 0.0, 1.0)
		var dy := 0.0
		if t > fade_at:
			var k := clampf((t - fade_at) / 0.5, 0.0, 1.0)
			a *= 1.0 - k
			dy = -8 * floorf(k * 3)
		# Höhe wächst in 4-px-Stufen
		var full := 96.0
		var h := clampf(floorf((0.2 + t / 0.35 * 0.8) * full / 8) * 8, 16, full)
		var w := size.x
		var y := floorf(size.y * 0.34 / 4) * 4 + dy + (full - h) / 2
		var col := Color(120 / 255.0, 12 / 255.0, 8 / 255.0, 0.85) if kind == "start" else Color(20 / 255.0, 40 / 255.0, 28 / 255.0, 0.88)
		var edge := Color("#ff5a3c") if kind == "start" else Color("#6ee07a")
		# Band mit gestuften Enden
		var steps := 8
		var sw := floorf(w * 0.2 / steps / 4) * 4
		for i in steps:
			var ca := Color(col, col.a * a * (i + 1) / (steps + 1))
			draw_rect(Rect2(i * sw, y, sw, h), ca)
			draw_rect(Rect2(w - (i + 1) * sw, y, sw, h), ca)
		draw_rect(Rect2(steps * sw, y, w - 2 * steps * sw, h), Color(col, col.a * a))
		draw_rect(Rect2(steps * sw, y, w - 2 * steps * sw, 4), Color(edge, 0.8 * a))
		draw_rect(Rect2(steps * sw, y + h - 4, w - 2 * steps * sw, 4), Color(edge, 0.8 * a))
		if h < full:
			return
		var f := UiFonts.pixel(700, 4)
		var fs := UiFonts.px(36)
		var up := title.to_upper()
		var tw := f.get_string_size(up, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var x := roundf((w - tw) / 2)
		draw_string(f, Vector2(x + 4, y + 56), up, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.6 * a))
		draw_string(f, Vector2(x, y + 52), up, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, a))
		if sub != "":
			var f2 := UiFonts.get_font(500)
			var sw2 := f2.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, UiFonts.px(14)).x
			draw_string(f2, Vector2(roundf((w - sw2) / 2), y + 80), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, UiFonts.px(14), Color(1, 1, 1, 0.85 * a))


# ---------------------------------------------------------------- Aktionen

## Maustaste gehalten: nach kurzer Zeit folgt die Figur der Maus (siehe _move_free).
func _follow_mouse(now: float) -> void:
	if _press_at < 0:
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or s.status != "playing" or modal_open() or in_combat():
		_press_at = -1.0
		_mouse_follow = false
		return
	if not _mouse_follow and now - _press_at >= FOLLOW_AFTER_MS:
		_mouse_follow = true
		_stop_moving()


# ---------------------------------------------------------------- Freies Laufen

## Wo die Figur gerade steht (frei, in Feldern).
func _pos_now() -> Vector2:
	if anim.free != null:
		return anim.free
	return anim.draw_pos("p", Vector2(s.player.pos.x, s.player.pos.y))


func _stop_moving() -> void:
	traveling = false
	_route.clear()
	anim.free_moving = false


## Jedes Bild: Die Figur läuft stufenlos – mit den Pfeiltasten (zwei zugleich
## schräg), der Maus nach (Taste gehalten) oder einen Klick-Weg entlang.
## Betritt sie ein neues Feld, macht das Spiel im Hintergrund einen Schritt.
func _move_free(dt: float, now: float) -> void:
	if s.status != "playing" or modal_open() or now < _wait_until:
		anim.free_moving = false
		return
	var pos := _pos_now()
	var dir := Vector2.ZERO
	var goal: Variant = null
	if not held.is_empty():
		for k in held:
			dir += Vector2(held[k])
	elif _mouse_follow:
		goal = _follow_goal(pos)
	elif traveling:
		while not _route.is_empty() and pos.distance_to(_route[0]) < 0.04:
			_route.pop_front()
		if _route.is_empty():
			_stop_moving()
			return
		goal = _route[0]
	var step := FreeMove.SPEED * dt
	if goal != null:
		var d: Vector2 = goal - pos
		if d.length() < 0.02:
			anim.free_moving = false
			return
		dir = d
		step = minf(step, d.length())
	if dir == Vector2.ZERO:
		anim.free_moving = false
		return
	var nxt := pos + dir.normalized() * minf(step, 0.45)
	var moved := _try_move(pos, nxt, now)
	if not moved and (not held.is_empty() or _mouse_follow):
		# An Wänden entlanggleiten
		for alt in [Vector2(nxt.x, pos.y), Vector2(pos.x, nxt.y)]:
			if alt.distance_to(pos) > 0.001 and _try_move(pos, alt, now):
				moved = true
				break
	anim.free_moving = moved
	if not moved and traveling and now >= _wait_until:
		_stop_moving()


## Ziel beim Folgen der Maus: geradeaus, wenn frei, sonst um die Ecke.
func _follow_goal(pos: Vector2) -> Variant:
	var mp := map.pos_from_local(map.get_local_mouse_position())
	if pos.distance_to(mp) < 0.15:
		return null
	if FreeMove.clear_line(s, pos, mp):
		return mp
	var t := FreeMove.tile_of(mp)
	var key := "%d,%d|%d,%d" % [t.x, t.y, s.player.pos.x, s.player.pos.y]
	# Höchstens alle 150 ms einen neuen Weg suchen (die Maus wandert ständig)
	if _follow_cache.key != key and Animator.now_ms() - float(_follow_cache.get("at", 0.0)) >= 150.0:
		var grid = Game.plan_path(s, J.pos(t.x, t.y)) if MapGen.in_bounds(s.map, t.x, t.y) else null
		_follow_cache = {"key": key, "at": Animator.now_ms(), "pts": FreeMove.smooth(s, pos, grid) if grid is Array and not grid.is_empty() else []}
	var pts: Array = _follow_cache.pts
	return pts[1] if pts.size() > 1 else mp


## Ein Stück laufen. Bleibt die Figur auf ihrem Feld, ändert sich nur die
## freie Position; auf einem neuen Feld macht das Spiel einen Schritt.
func _try_move(pos: Vector2, nxt: Vector2, now: float) -> bool:
	var cur := Vector2i(int(s.player.pos.x), int(s.player.pos.y))
	var t := FreeMove.tile_of(nxt)
	if t == cur:
		anim.free = nxt
		return true
	if absi(t.x - cur.x) > 1 or absi(t.y - cur.y) > 1 or not MapGen.in_bounds(s.map, t.x, t.y):
		return false
	var tp := J.pos(t.x, t.y)
	var tile := MapGen.tile_at(s.map, t.x, t.y)
	if tile == "door":
		# Tür öffnen, dann weiter
		if (t.x == cur.x or t.y == cur.y) and not (in_combat() and not Rounds.can_move(s)):
			anim.free = pos
			act(func(): return Game.move_step(s, tp))
			_wait_until = now + STEP_MS
			return MapGen.tile_at(s.map, t.x, t.y) != "door"
		return false
	if Ai.monster_at(s, tp) != null or MapGen.furniture_at(s.map, tp) != null or Dungeon.is_crate(tile) or Tiefgarage.is_wreck(tile):
		return false
	if not Pathfinding.can_step(s.map, s.player.pos, tp):
		return false
	if in_combat() and not Rounds.can_move(s):
		return false
	var fight := in_combat()
	var hp: int = s.player.hp
	var traps := _known_traps()
	var turn: int = s.turn
	anim.free = nxt
	act(func(): return Game.move_step(s, tp))
	if s.player.pos.x != t.x or s.player.pos.y != t.y:
		# Nicht weitergekommen. Im Schlamm oder festgehalten verging dabei ein
		# Zug: außerhalb des Kampfes weiter versuchen, sonst anhalten
		_wait_until = now + STEP_MS
		if s.turn > turn and not in_combat() and s.player.hp >= hp and s.status == "playing":
			return true
		_route.clear()
		return false
	if (not fight and in_combat()) or s.player.hp < hp or _known_traps() > traps:
		_stop_moving()
		_mouse_follow = false
		_press_at = -1.0
	elif traveling and _route_fight and (not in_combat() or int(s.round.n) != _route_round):
		_stop_moving()
	return true


func _known_traps() -> int:
	return J.arr(s, "traps").filter(func(x): return not x.get("hidden", false)).size()


## Läuft die Figur gerade (Taste gehalten oder Klick-Weg)?
func walking() -> bool:
	return not held.is_empty() or traveling or _mouse_follow


## Spielstand und Meta speichern, wenn sich etwas geändert hat.
func _persist() -> void:
	if not _save_due:
		return
	_save_due = false
	Meta.sync_meta(meta, s)
	Meta.save_meta(meta)
	if s.status == "playing":
		Meta.save_run(s)


## Schritt beim Laufen: Karte, Kampfmodus, Werte, Umgebung und Log.
func _refresh_light() -> void:
	_refresh_due = true
	_vis_key = ""
	_draw_frame()
	_update_combat_mode()
	refresh_vitals()
	refresh_here()
	refresh_log()


## Führt eine Engine-Aktion aus und kümmert sich um alles danach.
func act(fn: Callable) -> bool:
	if s.status != "playing" or modal_open():
		return false
	var before := anim.snapshot(s)
	var floor: int = s.floor
	var map_before: Dictionary = s.map
	if inspected != null:
		inspected = null
		_tip.visible = false
	var res: Dictionary = fn.call()
	# Neue Etage oder Ausflug in die Grube: nichts zwischen zwei Karten animieren
	if s.floor != floor or not is_same(s.map, map_before):
		anim.reset()
	else:
		anim.after(s, before, Fx.drain_fx(s))
	var sfx := Fx.drain_sfx(s)
	if sound():
		sound().play_sfx(sfx)
	if not res.get("ok", false) and res.get("message") != null:
		Log.add(s, res.message, "info")
	after_action()
	return res.get("ok", false)


func after_action() -> void:
	# Einblendungen nur noch für Warnungen – alles andere steht im Log
	for t in Game.drain_toasts(s):
		if t.kind == "warnung" and modals():
			modals().toast(t.title, t.text, t.kind)
	# Beim Laufen außerhalb des Kampfes nur das Nötigste: Karte, Werte, Log.
	# Gespeichert und alles neu aufgebaut wird, sobald die Figur steht.
	_save_due = true
	if walking() and s.status == "playing" and not in_combat():
		_refresh_light()
	else:
		_persist()
		refresh()
	flush_dialogs()
	if s.status != "playing" and not is_ended:
		is_ended = true
		traveling = false
		var title := "Geschafft!" if s.status == "victory" else "Tot."
		if s.status == "victory":
			await get_tree().create_timer(0.3).timeout
		else:
			# Erst sieht man die Figur umkippen und ihren Geist aufsteigen
			anim.player_death(Vector2(s.player.pos.x, s.player.pos.y))
			await get_tree().create_timer(Animator.PLAYER_DEATH_MS / 1000.0 + 0.2).timeout
		var text := "Du hast alle bisher gebauten Etagen überlebt." if s.status == "victory" else "Todesursache: %s." % J.nn(s, "deathCause", "unbekannt")
		await modals().html(title, func(root): Modals.page(root, Kit.esc(text)), "Weiter").closed
		ended.emit(s)


func flush_dialogs() -> void:
	while not s.pendingDialogs.is_empty():
		var d: Dictionary = s.pendingDialogs.pop_front()
		var job: Modals.Job
		if d.get("kind") == "talkshow":
			job = GameDialogs.run_talk_show(self, d.title, d.pages)
		else:
			job = modals().dialog(d.title, d.get("speaker"), d.pages)
		job.closed.connect(func(_r):
			refresh()
			maybe_select())
	_save_due = true
	if not walking():
		_persist()
	var reveal = s.get("pendingReveal")
	if reveal != null:
		s.erase("pendingReveal")
		GameDialogs.reveal_items(self, reveal.title, reveal.items)
	GameDialogs.maybe_versus(self)
	maybe_select()


## Öffnet die Rassen-/Klassenwahl, sobald keine anderen Dialoge mehr offen sind.
func maybe_select() -> void:
	if not s.get("pendingSelection", false) or selecting or modal_open():
		return
	selecting = true
	var job := Selection.show_selection(self)
	job.closed.connect(func(_r):
		selecting = false
		after_action())


func technique() -> Dictionary:
	return {"part": part, "move": move, "zone": zone}


func attack_monster(uid: String) -> void:
	act(func(): return Game.attack(s, uid, technique()))


func step_dir(dir: Vector2i) -> void:
	var to := {"x": s.player.pos.x + dir.x, "y": s.player.pos.y + dir.y}
	var mon = Ai.monster_at(s, to)
	if mon != null:
		attack_monster(mon.uid)
	else:
		act(func(): return Game.move_step(s, to))


## Angreifen, wenn es geht; sonst einen Schritt auf den Gegner zu.
func attack_or_approach(uid: String) -> void:
	var mon = J.find(s.monsters, func(m): return m.uid == uid)
	if mon == null:
		return
	var blocker = Combat.technique_blocker(s, mon, technique())
	if blocker == null:
		attack_monster(uid)
		return
	if Fov.chebyshev(s.player.pos, mon.pos) > 1 and part != "wurf":
		# Hinlaufen und zuschlagen, wenn die Bewegung reicht
		var t := technique()
		go_then(mon.pos, true, func(): return Game.attack(s, uid, t))
		return
	say(blocker)


## Hinlaufen (auf das Feld oder daneben) und dann fn als Aktion ausführen.
func go_then(tp: Dictionary, adjacent: bool, fn: Callable) -> void:
	var close := func() -> bool:
		var d := Fov.chebyshev(s.player.pos, tp)
		return d <= 1 if adjacent else d == 0
	if not close.call():
		var path = Game.plan_path(s, tp)
		if not (path is Array) or path.is_empty():
			say("Dorthin kennst du keinen Weg.")
			return
		if adjacent and path.size() > 0 and path[-1].x == tp.x and path[-1].y == tp.y:
			path = path.slice(0, path.size() - 1)
		var fight := in_combat()
		await travel(path)
		# Ohne Kampf hält man an, sobald einer beginnt; im Kampf zählt nur, ob es reicht
		if not close.call() or s.status != "playing" or (not fight and in_combat()):
			return
	act(fn)


func step_toward(target: Dictionary) -> void:
	var path = Game.plan_path(s, target)
	var next = path[0] if path is Array and not path.is_empty() else null
	if next != null and Ai.monster_at(s, next) == null:
		act(func(): return Game.move_step(s, next))
	else:
		say("Kein Weg dorthin.")


func say(text: String) -> void:
	Log.add(s, text, "info")
	refresh_log()


func visible_monsters() -> Array:
	var vis := _vis_now()
	return s.monsters.filter(func(m): return vis.has(MapGen.idx(s.map, m.pos.x, m.pos.y)))


## Klick-Weg: Die Figur läuft frei auf geraden Linien bis ans Ziel (siehe
## _move_free). Anhalten nur bei Gefahr: Kampf beginnt, Schaden, neue Falle,
## Weg versperrt. Im Kampf am Stück, solange die Bewegung der Runde reicht.
func travel(path: Array, exact: Variant = null) -> void:
	if traveling or path.is_empty():
		return
	_route = FreeMove.smooth(s, _pos_now(), path)
	_route.pop_front()
	# Genau dorthin, wo geklickt wurde (innerhalb des Zielfelds)
	if exact != null and not _route.is_empty() and FreeMove.tile_of(exact) == FreeMove.tile_of(_route[-1]):
		_route[-1] = exact
	traveling = true
	_route_fight = in_combat()
	_route_round = int(s.round.n) if _route_fight else -1
	while traveling and is_inside_tree() and s.status == "playing":
		await get_tree().process_frame
	traveling = false


# ---------------------------------------------------------------- Eingabe

func _on_hover(t: Variant) -> void:
	hover = t
	if t == null:
		_tip.visible = false
		return
	if inspected != null and (inspected.x != t.x or inspected.y != t.y):
		inspected = null
	if inspected == null:
		_update_tooltip()


func _on_map_click(t: Vector2i, button: int) -> void:
	if modal_open():
		return
	if button == MOUSE_BUTTON_RIGHT:
		_stop_moving()
		ContextMenu.open(self, t, get_viewport().get_mouse_position())
		return
	# Ein neuer Klick ändert das Ziel
	_stop_moving()
	# Gedrückt halten: die Figur folgt der Maus (siehe _follow_mouse)
	_press_at = Animator.now_ms()
	var tp := _pos(t)
	var vis := _vis_now()
	var i := MapGen.idx(s.map, t.x, t.y) if MapGen.in_bounds(s.map, t.x, t.y) else -1
	var seen := i >= 0 and vis.has(i)
	var mon = Ai.monster_at(s, tp)
	# Zauber mit Ziel: der nächste Klick bestimmt das Ziel
	if pending_spell != null:
		var sp: String = pending_spell
		pending_spell = null
		var target = mon if mon != null and seen else null
		act(func(): return Game.cast(s, sp, {"targetUid": target.uid if target != null else null, "pos": tp, "mana": missile_mana}))
		return
	if mon != null and seen:
		attack_or_approach(mon.uid)
		return
	var npc = Crawlers.crawler_at(s, tp)
	if npc != null and seen and not npc.get("party", false):
		if Fov.chebyshev(npc.pos, s.player.pos) <= 1:
			act(func(): return Game.talk_crawler(s, npc.uid))
			return
		step_toward(npc.pos)
		return
	var on_player: bool = t.x == s.player.pos.x and t.y == s.player.pos.y
	var was_inspected: bool = inspected != null and inspected.x == t.x and inspected.y == t.y
	if not on_player and not was_inspected and worth_inspecting(t):
		inspected = t
		_show_card(t)
		return
	inspected = null
	if on_player:
		if not Game.items_at(s, tp).is_empty():
			act(func(): return Game.pickup(s))
		elif Game.on_stairs(s):
			ask_descend()
		else:
			act(func(): return Game.wait(s))
		return
	var closed_door := MapGen.in_bounds(s.map, t.x, t.y) and (MapGen.tile_at(s.map, t.x, t.y) == "door" or Dungeon.is_crate(MapGen.tile_at(s.map, t.x, t.y)) or MapGen.tile_at(s.map, t.x, t.y) == Tiefgarage.WRECK)
	if Fov.chebyshev(tp, s.player.pos) == 1 and closed_door:
		act(func(): return Game.move_step(s, tp))
		return
	var path = Game.plan_path(s, tp)
	if not (path is Array) or path.is_empty():
		say("Dorthin kennst du keinen Weg.")
	else:
		# Im Kampf so weit, wie die Bewegung der Runde reicht
		travel(path, map.pos_from_local(map.get_local_mouse_position()))


## Felder, die man per Klick erst ansieht, statt sofort loszulaufen.
func worth_inspecting(t: Vector2i) -> bool:
	var m: Dictionary = s.map
	if t.x < 0 or t.y < 0 or t.x >= m.width or t.y >= m.height:
		return false
	var i := MapGen.idx(m, t.x, t.y)
	if not m.explored[i] or not _vis_now().has(i):
		return false
	var tp := _pos(t)
	var fu = MapGen.furniture_at(m, tp)
	if fu != null:
		return Fov.chebyshev(tp, s.player.pos) > 1
	if not Game.items_at(s, tp).is_empty() or Traps.known_trap_at(s, tp) != null or m.tiles[i] == "stairs":
		return true
	return (m.tiles[i] == "door" or m.tiles[i] == "dooropen") and Game.is_lair_door(s, tp) and Fov.chebyshev(tp, s.player.pos) > 1


## Feste Info-Karte am untersuchten Feld.
func _show_card(t: Vector2i) -> void:
	var bb = GameDialogs.tooltip_for(self, t, true)
	if bb == null:
		return
	_tip_text.text = bb + "\n[font_size=%d][color=#8cc8ff]NOCHMAL KLICKEN, UM HINZUGEHEN · RECHTSKLICK: AKTIONEN[/color][/font_size]" % UiFonts.px(11)
	_tip.visible = true
	_tip.reset_size()
	var tl := map.tile_px
	var px := (t.x - map.ox + 1) * tl + 8
	var py := (t.y - map.oy) * tl
	var w := _mapwrap.size
	var x := px - tl - 300 if px + 290 > w.x else px
	await get_tree().process_frame
	var th := _tip.size.y
	var y := w.y - th - 8 if py + th > w.y else py
	_tip.position = Vector2(maxf(4, x), maxf(4, y))


func _update_tooltip() -> void:
	var bb = GameDialogs.tooltip_for(self, hover) if hover != null else null
	if bb == null:
		_tip.visible = false
		return
	_tip_text.text = bb
	_tip.visible = true
	_tip.reset_size()
	var mp := _mapwrap.get_local_mouse_position()
	var w := _mapwrap.size
	var x := mp.x + 16
	var y := mp.y + 16
	if x + 290 > w.x:
		x = mp.x - 290
	var th := _tip.get_combined_minimum_size().y
	if y + th > w.y:
		y = mp.y - th - 8
	_tip.position = Vector2(maxf(4, x), maxf(4, y))


func examine(t: Vector2i) -> void:
	var tp := _pos(t)
	if not MapGen.in_bounds(s.map, t.x, t.y):
		return
	var mon = Ai.monster_at(s, tp) if _vis_now().has(MapGen.idx(s.map, t.x, t.y)) else null
	if mon != null:
		var info := Identify.describe_monster(s, mon)
		var conds := ", ".join(Conditions.condition_list(mon).map(func(c): return c.state))
		var parts := ["%s (%s, %s)" % [info.name, info.level, Identify.INSIGHT_NAMES[info.insight]], info.health, conds, info.combat, info.abilities, info.flavor]
		say(". ".join(parts.filter(func(x): return x != null and String(x) != "")))
		return
	var items := Game.items_at(s, tp)
	if not items.is_empty():
		say(" | ".join(items.map(func(e):
			var d := Identify.describe_item(s, e.item)
			return "%s: %s" % [d.name, J.nn(d, "flavor", J.nn(d, "note", ""))])))
		return
	var ri: int = s.map.roomAt[MapGen.idx(s.map, t.x, t.y)]
	if ri >= 0 and s.map.rooms[ri].get("visited", false):
		say("%s: %s" % [s.map.rooms[ri].name, s.map.rooms[ri].description])


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and not ev.pressed:
		held.erase(ev.keycode)
		return
	if not (ev is InputEventKey) or not ev.pressed:
		return
	if modal_open() or s.status != "playing":
		return
	var k: int = ev.keycode
	var ch := String.chr(ev.unicode).to_lower() if ev.unicode > 0 else ""
	var dir = DIR_KEYS.get(k)
	if dir != null:
		get_viewport().set_input_as_handled()
		if ev.echo:
			return
		_stop_moving()
		# Steht in dieser Richtung ein Gegner, wird angegriffen statt gelaufen
		var to := {"x": s.player.pos.x + dir.x, "y": s.player.pos.y + dir.y}
		var mon = Ai.monster_at(s, to)
		if mon != null and held.is_empty():
			attack_monster(mon.uid)
			return
		held[k] = dir
		return
	if ev.echo:
		return
	for p in PART_KEYS:
		if ch == PART_KEYS[p] and k != KEY_KP_1 and k != KEY_KP_2 and k != KEY_KP_3 and k != KEY_KP_4 and k != KEY_KP_5 and k != KEY_KP_6 and k != KEY_KP_7:
			part = p
			if p == "wurf":
				move = "normal"
			refresh_actions()
			get_viewport().set_input_as_handled()
			return
	for mv in MOVE_KEYS:
		if ch == MOVE_KEYS[mv].to_lower():
			move = mv
			if mv == "stampfen":
				part = "tritt"
			refresh_actions()
			get_viewport().set_input_as_handled()
			return
	for z in ZONE_KEYS:
		if ch == ZONE_KEYS[z].to_lower():
			zone = z
			refresh_actions()
			get_viewport().set_input_as_handled()
			return
	get_viewport().set_input_as_handled()
	if k == KEY_TAB and not in_combat():
		var ids := TABS.map(func(t): return t[0])
		show_tab(ids[(ids.find(tab) + (ids.size() - 1 if ev.shift_pressed else 1)) % ids.size()])
		return
	for t in TABS:
		if ch == String(t[2]).to_lower():
			show_tab(t[0])
			return
	if k == KEY_TAB and in_combat():
		var list := combat_targets()
		var idx := -1
		for n in list.size():
			if list[n].uid == target_uid:
				idx = n
		target_uid = list[(idx + 1) % maxi(1, list.size())].uid if not list.is_empty() else null
		refresh_actions()
		return
	var enter: bool = k == KEY_ENTER or k == KEY_KP_ENTER
	if enter and in_combat() and target_uid != null and not Game.on_stairs(s):
		strike(target_uid)
		return
	if k == KEY_SPACE or k == KEY_KP_5:
		act(func(): return Game.wait(s))
	elif ch == "f" and Classes.current_ability(s) != null:
		act(func(): return Classes.use_ability(s, technique()))
	elif ch == "m" and s.player.get("mount") != null:
		act(func(): return Game.ride_toggle(s))
	elif ch == "g":
		act(func(): return Game.pickup(s))
	elif enter and Game.on_stairs(s):
		ask_descend()
	elif ch == "k":
		toggle_minimap()
	elif ch == "h" or ch == "?":
		GameDialogs.show_help(self)
	elif ch == "+" or ch == "=" or k == KEY_KP_ADD:
		zoom_map(1)
	elif ch == "-" or k == KEY_KP_SUBTRACT:
		zoom_map(-1)
	elif ch == "n":
		here_folded = not here_folded
		refresh_here()
	elif k == KEY_ESCAPE:
		if pending_spell != null:
			pending_spell = null
			say("Zauber abgebrochen.")
			refresh_actions()
		elif traveling:
			_stop_moving()
		elif tab_open:
			close_tab()
		else:
			open_menu()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		held.clear()
		_persist()
	elif what == NOTIFICATION_EXIT_TREE or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_persist()


func ask_descend() -> void:
	var next: int = s.floor + 1
	var def = null
	for f in Db.world("FLOORS"):
		if f.floor == next:
			def = f
	var boxes: int = s.player.boxes.size()
	var text := "Auf Etage %d%s hinabsteigen? Es gibt kein Zurück.%s" % [next, (" („%s“)" % def.name) if def != null else "", (" Du hast noch %d ungeöffnete Box(en) – die bleiben dir erhalten." % boxes) if boxes else ""]
	# Wer früh geht, kommt unten schwächer an: Hinweis ab mehr als 30 % Restzeit
	var dur := float(Db.floor_def0(s.floor).duration)
	var rest := float(Game.time_left(s))
	if def != null and rest > dur * 0.3:
		text += "\n\nNoch %s bis zum Einsturz. Unten ist alles deutlich stärker – wer hier die Zeit nutzt, steigt weiter auf und kommt besser vorbereitet an." % ViewHelpers.format_time(int(rest))
	var ok = await modals().confirm("Treppenhaus", text, "Hinabsteigen").closed
	if ok:
		act(func(): return Game.descend(s, meta))


# ---------------------------------------------------------------- Darstellung

func refresh() -> void:
	_vis_key = ""
	_draw_frame()
	_update_combat_mode()
	refresh_top()
	refresh_vitals()
	refresh_here()
	refresh_side()
	refresh_actions()
	refresh_log()


func refresh_top() -> void:
	Kit.clear(_top)
	var p: Dictionary = s.player
	var def = Db.floor_def(s.floor)
	var left := Game.time_left(s)
	var show := Kit.label(_top, Db.world("SHOW_NAME"), 18, UiTheme.ACCENT)
	show.add_theme_font_override("font", UiFonts.pixel(700))
	show.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	show.tooltip_text = "Staffel %d" % s.season
	show.mouse_filter = Control.MOUSE_FILTER_PASS
	_pill_bb("Etage [b]%d[/b] · %s" % [s.floor, Kit.esc(def.name if def else "")])
	_pill(Highlights.clock_text(s), "text", "Pill", 400, "Uhrzeit im Dungeon. Ab Etage 2 laufen jeden Abend um 21 Uhr die Highlights auf den Bildschirmen der Safe Rooms.")
	if Arena.active(s):
		_pill("Die Grube", "danger", "PillWarn", 700, "Gladiatorenkampf: Wer liegen bleibt, verliert – sterben kannst du hier nicht.")
	elif Game.has_unlock(s, "zuschauer") and Highlights.on_air(s):
		_pill("Jetzt live: Abgrund am Abend", "accent", "PillTimer", 700, "Am Bildschirm in einem Safe Room anschauen (bis Mitternacht)")
	var inv = Invitations.pending(s)
	if inv != null:
		_pill("Einladung: " + Invitations.format_name(inv.format), "achv", "PillTimer", 700, "Im Safe Room am Bildschirm annehmen oder absagen. Gilt noch %s." % ViewHelpers.format_time(maxi(0, int(inv.until) - int(s.turn))))
	collapse_pill = _pill("Einsturz in %s" % ViewHelpers.format_time(left), "text" if left > 120 else "danger", "PillWarn" if left <= 120 else "PillTimer", 700, "Zeit bis zum Einsturz der Etage")
	var rush := Progression.rush_bonus(s)
	if rush >= 0.1:
		_pill("Endspurt +%d %% XP" % J.rnd(rush * 100), "accent", "PillTimer", 700, "Je näher der Einsturz, desto mehr Erfahrung pro Kill")
	var ev = ShowEvents.active_def(s)
	if ev != null:
		_pill("Einlage: " + ShowEvents.label(s), "achv", "PillTimer", 700, ev.text)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_top.add_child(sp)
	if Game.has_unlock(s, "zuschauer"):
		_pill("Zuschauer %s" % J.de(Viewers.live_viewers(s)), "achv", "Pill", 400, "Follower %s · Hype %d%s" % [J.de(s.viewers.follower), J.rnd(s.viewers.hype), (" · Crawler übrig %s" % J.de(Crawlers.population(s).alive)) if Game.has_unlock(s, "inventar") else ""])
	_pill("Gold %s" % J.s(p.gold), Color("#ffd700"))
	if not p.boxes.is_empty():
		_pill("Lootboxen %d" % p.boxes.size(), "accent", "PillTimer", 700, "Öffnen kannst du sie in einem Safe Room oder einer Gilde")
	var btn := Kit.button(_top, "Menü", open_menu, "PillButton", false, "Hilfe, Ton und Musik (Esc)")
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	menu_button = btn


## Menü mit Hilfe und Klangeinstellungen.
func open_menu() -> void:
	if not modals() or modal_open():
		return
	modals().html("Menü", func(root: VBoxContainer):
		Kit.text(root, "%s · Staffel %d · %s, Level %d" % [Kit.esc(Db.world("SHOW_NAME")), s.season, Kit.esc(s.player.name), s.player.level], 13, "muted")
		Kit.spacer(root, 6)
		var g := Kit.grid(root, 2, 12, 8)
		var rows := [
			["Ton", func(): return sound() and sound().enabled, _toggle_sound, "Klänge für Lootboxen, Level-Aufstieg und Achievements"],
			["Musik", func(): return sound() and sound().music_on, _toggle_music, "Klangkulisse der Etage und Kampfmusik"],
			["Tippgeräusch", func(): return sound() and sound().typing_on, _toggle_typing, "Weiches Tastenklicken, wenn Texte getippt werden"],
		]
		for r in rows:
			Kit.label(g, r[0], 14, null, 600).tooltip_text = r[3]
			var get_on: Callable = r[1]
			var toggle: Callable = r[2]
			var b: Button
			b = Kit.button(g, "an" if get_on.call() else "aus", func():
				toggle.call()
				b.text = "an" if get_on.call() else "aus", "SmallButton")
			b.custom_minimum_size = Vector2(60, 0)
		Kit.spacer(root, 8)
		var hb := Kit.hbox(root, 8)
		Kit.button(hb, "Steuerung anzeigen (H)", func():
			modals().close_all()
			GameDialogs.show_help.call_deferred(self), "Button")
		Kit.button(hb, "Tutorial wiederholen", func():
			modals().close_all()
			guide.restart(), "Button"), "Weiter", 420)


func _pill(text: String, color: Variant, variant: String = "Pill", weight: int = 400, tip: String = "") -> Control:
	var pc := PanelContainer.new()
	pc.theme_type_variation = variant
	pc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if tip != "":
		pc.tooltip_text = tip
	_top.add_child(pc)
	var l := Kit.label(pc, text, 16, color)
	l.add_theme_font_override("font", UiFonts.pixel(maxi(400, mini(700, weight))))
	return pc


func _pill_bb(bb: String) -> void:
	var pc := PanelContainer.new()
	pc.theme_type_variation = "Pill"
	pc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_top.add_child(pc)
	var rt := Kit.text(pc, bb, 16)
	rt.add_theme_font_override("normal_font", UiFonts.pixel(400))
	rt.add_theme_font_override("bold_font", UiFonts.pixel(700))
	for k in ["normal_font_size", "bold_font_size"]:
		rt.add_theme_font_size_override(k, UiFonts.px(16))
	rt.autowrap_mode = TextServer.AUTOWRAP_OFF
	rt.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN


func _toggle_sound() -> void:
	if not sound():
		return
	sound().set_enabled(not sound().enabled)
	if sound().enabled:
		sound().play_sfx([{"kind": "skill"}])
	refresh_top()


func _toggle_music() -> void:
	if not sound():
		return
	sound().set_music(not sound().music_on)
	refresh_top()


func _toggle_typing() -> void:
	if not sound():
		return
	sound().set_typing(not sound().typing_on)
	if sound().typing_on:
		sound().type_click(false, 1.0, 0.0)
	refresh_top()


func refresh_here() -> void:
	Kit.clear(_here)
	var tmp := VBoxContainer.new()
	GameHere.build(self, tmp)
	if tmp.get_child_count() == 0:
		tmp.free()
		_fit_here.call_deferred()
		return
	# Kopf mit Ein- und Ausklappen; eingeklappt bleibt nur eine Zeile
	var head := Kit.hbox(_here, 6)
	var title := Kit.label(head, "HIER", 14, UiTheme.ACCENT)
	title.add_theme_font_override("font", UiFonts.pixel(700, 1))
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	Kit.button(head, "ausklappen" if here_folded else "einklappen", func():
		here_folded = not here_folded
		refresh_here(), "SmallButton", false, "Bereich „Hier“ ein- oder ausklappen (N)")
	if here_folded:
		tmp.free()
		Kit.spacer(_here, 4)
		_line(_here)
	else:
		for c in tmp.get_children():
			tmp.remove_child(c)
			_here.add_child(c)
		tmp.free()
	_fit_here.call_deferred()


func refresh_vitals() -> void:
	Kit.clear(_vitals)
	GameVitals.build(self, _vitals)


## Einen Reiter ausklappen; derselbe noch einmal klappt ihn wieder zu.
func show_tab(id: String) -> void:
	if tab_open and tab == id:
		close_tab()
		return
	open_tab(id)


## Einen Reiter ausklappen (bleibt offen, wenn er es schon ist).
func open_tab(id: String) -> void:
	if not tab_open:
		raise_window(_drawer)
	tab = id
	tab_open = true
	_tab_scroll.scroll_vertical = 0
	refresh_side()


## Zuletzt geöffnetes Fenster über die anderen legen.
func raise_window(c: Control) -> void:
	if is_instance_valid(c) and c.get_parent() == _mapwrap:
		_mapwrap.move_child(c, _mapwrap.get_child_count() - 1)
		# Der Tooltip bleibt obenauf
		_mapwrap.move_child(_tip, _mapwrap.get_child_count() - 1)


## Klick neben das ausgeklappte Fenster (oder die große Karte) schließt es.
## Auf der Karte löst der Klick dann nichts weiter aus.
func _input(ev: InputEvent) -> void:
	if not (ev is InputEventMouseButton) or not ev.pressed or modal_open():
		return
	if ev.button_index != MOUSE_BUTTON_LEFT and ev.button_index != MOUSE_BUTTON_RIGHT:
		return
	var at: Vector2 = ev.global_position
	var closed := false
	if tab_open and not _drawer.get_global_rect().has_point(at) and not _tabs.get_global_rect().has_point(at):
		close_tab()
		closed = true
	if minimap_big and not _mini_wrap.get_global_rect().has_point(at):
		toggle_minimap()
		closed = true
	if closed and map.get_global_rect().has_point(at) and not _actionbar.get_global_rect().has_point(at):
		get_viewport().set_input_as_handled()


func close_tab() -> void:
	tab_open = false
	refresh_side()


const TABS := [
	["crawler", "Crawler", "P"], ["ziele", "Ziele", "Z"], ["inventar", "Inventar", "I"], ["ausruestung", "Ausrüstung", "A"],
	["handwerk", "Handwerk", "B"], ["skills", "Skills", "L"], ["erfolge", "Erfolge", "O"],
]


## Reiter, der Aufmerksamkeit braucht (freie Punkte, Angebote, Abgaben).
func tab_badge(id: String) -> bool:
	match id:
		"crawler":
			return Game.has_unlock(s, "stats") and J.num(s.player, "statPoints") > 0
		"ziele":
			var ev = ShowEvents.active(s)
			if ev != null and ev.get("bountyUid") != null:
				return true
			return J.some(Sponsors.states(s), func(st): return st.status == "offer") or J.some(Quests.active_quests(s), func(q): return Quests.can_turn_in(s, q))
	return false


func refresh_side() -> void:
	Kit.clear(_tabs)
	for t in TABS:
		var id: String = t[0]
		var active: bool = tab_open and tab == id
		var b := Kit.button(_tabs, t[1], func(): show_tab(id), "TabActive" if active else "TabButton", false, "%s ausklappen (Taste %s)" % [t[1], t[2]])
		tab_buttons[id] = b
		b.custom_minimum_size.x = 76
		var badge := tab_badge(id)
		b.draw.connect(func():
			if active:
				# Goldene Unterkante
				b.draw_rect(Rect2(1, b.size.y - 2, b.size.x - 2, 2), UiTheme.ACCENT)
			if badge:
				b.draw_rect(Rect2(b.size.x - 10, 5, 5, 5), UiTheme.ACCENT if not active else Color("#ff8a4a")))
	_drawer.visible = tab_open
	Kit.clear(_tab_content)
	if not tab_open:
		return
	for t in TABS:
		if t[0] == tab:
			_drawer_title.text = String(t[1]).to_upper()
	match tab:
		"crawler": GameTabs.crawler_tab(self, _tab_content)
		"ziele": GameTabs.goals_tab(self, _tab_content)
		"inventar": GameTabs.inventory_tab(self, _tab_content)
		"ausruestung": GameTabs.gear_tab(self, _tab_content)
		"handwerk": GameTabs.craft_tab(self, _tab_content)
		"skills": GameTabs.skills_tab(self, _tab_content)
		"erfolge": GameTabs.achievements_tab(self, _tab_content)
	_layout_drawer.call_deferred()


func refresh_actions() -> void:
	var fighting := in_combat()
	_actionbar.theme_type_variation = "CombatBar" if fighting else "ActionBar"
	Kit.clear(_actionbar)
	if fighting:
		GameCombat.render_combat(self, _actionbar)
	else:
		GameCombat.render_actions(self, _actionbar)


## Gegner, die gerade zu sehen sind – nach Entfernung sortiert.
func combat_targets() -> Array:
	var list := visible_monsters()
	return J.sort(list, func(a, b): return Fov.chebyshev(a.pos, s.player.pos) - Fov.chebyshev(b.pos, s.player.pos))


## Angriff (oder Zauber) auf ein Ziel aus der Kampfsequenz.
func strike(uid: String) -> void:
	target_uid = uid
	if pending_spell != null:
		var sp: String = pending_spell
		pending_spell = null
		var m = J.find(s.monsters, func(x): return x.uid == uid)
		act(func(): return Game.cast(s, sp, {"targetUid": uid, "pos": m.pos if m != null else null, "mana": missile_mana}))
		return
	attack_monster(uid)


## Wenige Farben im Chat: normaler Text, Gold für Funde und Erfolge, Rot für
## Gefahr. Gespräche stehen kursiv, Hinweise etwas gedämpft.
const LOG_TEXT := "#e2ddd2"
const LOG_COLORS := {
	"kampf": LOG_TEXT, "info": "#bdb6aa", "system": "#f4c24f", "gefahr": "#ff6a5a", "loot": "#f4c24f",
	"achievement": "#f4c24f", "dialog": LOG_TEXT,
}


const LOG_FILTERS := [
	["alles", "Alles", []],
	["kampf", "Kampf", ["kampf", "gefahr"]],
	["funde", "Funde", ["loot", "achievement", "system"]],
	["story", "Gespräche", ["dialog", "info"]],
]


func _log_kinds() -> Array:
	for f in LOG_FILTERS:
		if f[0] == log_filter:
			return f[2]
	return []


func set_log_filter(id: String) -> void:
	log_filter = id
	refresh_log(true)


func _log_line(l: Dictionary, n: int) -> String:
	var color: String = LOG_COLORS.get(l.kind, "#e9e5dc")
	var body := Kit.esc(l.text)
	if l.kind == "dialog":
		body = "[i]%s[/i]" % body
	if n > 1:
		body += " [color=#8f8a80](%d×)[/color]" % n
	return "[font_size=%d][color=#6f6a62]%s[/color][/font_size]  [color=%s]%s[/color]" % [UiFonts.px(11), ViewHelpers.clock_at(s, int(l.turn)), color, body]


## Neue Log-Zeilen werden angehängt und Zeichen für Zeichen getippt.
## Gleiche Zeilen direkt hintereinander werden zusammengefasst; der Filter
## oben blendet ganze Arten aus.
func refresh_log(rebuild: bool = false) -> void:
	Kit.clear(_log_bar)
	var lt := Kit.label(_log_bar, "CHAT", 13, "muted")
	lt.add_theme_font_override("font", UiFonts.pixel(700, 1))
	lt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for f in LOG_FILTERS:
		var id: String = f[0]
		Kit.button(_log_bar, f[1], func(): set_log_filter(id), "SmallSel" if log_filter == id else "SmallButton")
	Kit.button(_log_bar, "Überspringen", func(): _typer.finish_all(), "SmallButton", false, "Alle Zeilen sofort ganz zeigen")
	var entries: Array = s.log
	var first := _last_log_id < 0 or rebuild
	if rebuild:
		_typer.finish_all()
		Kit.clear(_log)
		_log_prev = {}
	var kinds := _log_kinds()
	var fresh: Array = []
	if first:
		fresh = entries.filter(func(l): return kinds.is_empty() or kinds.has(l.kind))
		fresh = fresh.slice(maxi(0, fresh.size() - 120))
	else:
		fresh = entries.filter(func(l): return int(J.nn(l, "id", 0)) > _last_log_id and (kinds.is_empty() or kinds.has(l.kind)))
	for l in fresh:
		var key: String = "%s|%s" % [l.kind, l.text]
		if _log_prev.get("key") == key and is_instance_valid(_log_prev.get("rt")):
			_log_prev.n += 1
			_typer.finish_all()
			_log_prev.rt.text = _log_line(l, _log_prev.n)
			_log_prev.rt.visible = true
			continue
		var bb := _log_line(l, 1)
		var rt := Kit.text(_log, "", 16, null, 3)
		if first:
			rt.text = bb
		else:
			rt.visible = false
			_typer.push(rt, bb)
		_log_prev = {"key": key, "rt": rt, "n": 1}
	var last = entries.back() if not entries.is_empty() else null
	if last != null and last.get("id") != null:
		_last_log_id = int(last.id)
	elif first:
		_last_log_id = 0
	while _log.get_child_count() > 150:
		var old := _log.get_child(0)
		_log.remove_child(old)
		old.queue_free()
	_scroll_log()


func _scroll_log() -> void:
	# Erst im nächsten Bild steht die neue Höhe fest. Die Verbindung löst sich
	# mit der Spielansicht, falls diese vorher verschwindet.
	if not get_tree().process_frame.is_connected(_scroll_log_now):
		get_tree().process_frame.connect(_scroll_log_now, CONNECT_ONE_SHOT)


func _scroll_log_now() -> void:
	if is_instance_valid(_log_scroll):
		_log_scroll.scroll_vertical = int(_log_scroll.get_v_scroll_bar().max_value)
