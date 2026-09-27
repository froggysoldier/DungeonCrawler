class_name MapView
extends Control
## Die Karte (Port von src/ui/render.ts). Böden, Wände und Türen kommen als
## zwischengespeicherte Texturen aus Tiles; Figuren, Gegenstände, Fallen,
## Nebel, Licht und Effekte werden jedes Bild neu gezeichnet.
## Gezeichnet wird in „Design-Einheiten“: eine Kachel ist 32 Einheiten groß.

signal tile_hovered(tile: Variant)
signal tile_clicked(tile: Vector2i, button: int)
signal zoom_requested(delta: int)

const ZOOM_STEPS := [22, 26, 32, 38, 46, 56]
const U := 32.0

var s: Dictionary
var tiles: Tiles
var anim: Animator
var hover: Variant = null
var path: Variant = null
var selected: Variant = null

var zoom_index: int = 3
var tile_px: float = 38.0
## Kamera: linke obere Ecke in Kachelkoordinaten.
var ox := 0.0
var oy := 0.0
var visible_set: Dictionary = {}
var frame_anim: Dictionary = {}
## Zeichenzeit des letzten Bildes in Millisekunden (zur Leistungsmessung).
var last_draw_ms := 0.0

var _light: Control
var _top: Control
var _fog_img: Image
var _fog_tex: ImageTexture


func _init() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var z = Settings.get_value("zoom", 3)
	zoom_index = clampi(int(z), 0, ZOOM_STEPS.size() - 1)
	tile_px = ZOOM_STEPS[zoom_index]
	_static = StaticLayer.new()
	_static.view = self
	_static.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(_static)
	_dyn = Control.new()
	_dyn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dyn.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dyn.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_dyn.draw.connect(_draw_dynamic)
	add_child(_dyn)
	_light = Control.new()
	_light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_light.set_anchors_preset(Control.PRESET_FULL_RECT)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_light.material = mat
	_light.draw.connect(_draw_light)
	add_child(_light)
	_top = Control.new()
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top.set_anchors_preset(Control.PRESET_FULL_RECT)
	_top.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_top.draw.connect(_draw_top)
	add_child(_top)


## Zoom ändern; gibt zurück, ob sich etwas geändert hat.
func zoom(delta: int) -> bool:
	var next := clampi(zoom_index + delta, 0, ZOOM_STEPS.size() - 1)
	if next == zoom_index:
		return false
	zoom_index = next
	tile_px = ZOOM_STEPS[zoom_index]
	Settings.set_value("zoom", zoom_index)
	return true


func zoom_bounds() -> Dictionary:
	return {"min": zoom_index == 0, "max": zoom_index == ZOOM_STEPS.size() - 1}


func tile_from_local(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / tile_px + ox), floori(p.y / tile_px + oy))


func tile_to_local(t: Vector2i) -> Vector2:
	return Vector2((t.x - ox) * tile_px, (t.y - oy) * tile_px)


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		var t := tile_from_local(ev.position)
		if hover == null or hover != t:
			hover = t
			tile_hovered.emit(t)
	elif ev is InputEventMouseButton and ev.pressed:
		match ev.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				zoom_requested.emit(1)
			MOUSE_BUTTON_WHEEL_DOWN:
				zoom_requested.emit(-1)
			MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT:
				tile_clicked.emit(tile_from_local(ev.position), ev.button_index)
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		hover = null
		tile_hovered.emit(null)


# ================================================================ Hilfen

func _sx(x: float) -> float:
	return roundf(x * tile_px - _cam_px.x)


func _sy(y: float) -> float:
	return roundf(y * tile_px - _cam_px.y)


func _at(key: String, p: Dictionary) -> Vector2:
	var v := Vector2(p.x, p.y)
	return anim.draw_pos(key, v, frame_anim.get("now", -1.0)) if anim else v


static func _cond_turns(m: Dictionary, id: String) -> float:
	var c = m.get("conditions")
	if c == null:
		return 0.0
	var e = c.get(id)
	return 0.0 if e == null else J.num(e, "turns")


static func _hex_or(c: Variant, fallback: String) -> Variant:
	return c if c is String and (c as String).length() == 7 else fallback


# ================================================================ Zeichnen

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#05060b"))


## Einmal pro Bild: Kamera und Sicht bestimmen, Ebenen neu zeichnen lassen.
func redraw() -> void:
	if s.is_empty():
		return
	frame_anim = anim.frame(s) if anim else {"cam": Vector2(s.player.pos.x, s.player.pos.y), "projectiles": [], "floaters": [], "time": 0.0, "now": 0.0}
	var cols := size.x / tile_px
	var rows := size.y / tile_px
	var cam: Vector2 = frame_anim.cam
	ox = cam.x + 0.5 - cols / 2.0
	oy = cam.y + 0.5 - rows / 2.0
	_cam_px = Vector2(roundf(ox * tile_px), roundf(oy * tile_px))
	var vkey := "%d|%d|%d|%d" % [s.turn, s.floor, s.player.pos.x, s.player.pos.y]
	if vkey != _vis_key:
		_vis_key = vkey
		visible_set = Game.visible_tiles(s)
	# Statische Ebene nur neu zeichnen, wenn sich etwas geändert hat oder die
	# Kamera den vorgezeichneten Bereich verlässt
	var memory := Game.has_unlock(s, "minimap")
	var inside := ox >= _region.position.x and oy >= _region.position.y and ox + cols <= _region.end.x and oy + rows <= _region.end.y
	var key := "%s|%d|%s|%s" % [vkey, zoom_index, memory, tiles != null and tiles.is_ready]
	if key != _static_key or not inside:
		_static_key = key
		_region = Rect2(floorf(ox) - REGION_MARGIN, floorf(oy) - REGION_MARGIN, ceilf(cols) + REGION_MARGIN * 2, ceilf(rows) + REGION_MARGIN * 2)
		_static.queue_redraw()
	_static.position = -_cam_px
	queue_redraw()
	_dyn.queue_redraw()
	_light.queue_redraw()
	_top.queue_redraw()


const REGION_MARGIN := 8.0
var _cam_px := Vector2.ZERO
var _region := Rect2()
var _static_key := ""
var _vis_key := ""
## Felder mit Bewegung (Treppe, Boss-Tür, Automat), gesammelt beim statischen Zeichnen.
var _animated: Array = []
var _static: Node2D
var _dyn: Control


class StaticLayer:
	extends Node2D
	var view: MapView

	func _draw() -> void:
		var t0 := Time.get_ticks_usec()
		view._draw_static(self)
		view.last_static_ms = (Time.get_ticks_usec() - t0) / 1000.0


var last_static_ms := 0.0


func _known(i: int, memory: bool) -> bool:
	return visible_set.has(i) or (memory and s.map.explored[i])


## Böden, Schatten, Dekoration, Türen und Wände in Weltkoordinaten (Kachel · Größe).
func _draw_static(ci: CanvasItem) -> void:
	_animated.clear()
	if s.is_empty():
		return
	var vis := visible_set
	var memory := Game.has_unlock(s, "minimap")
	var m: Dictionary = s.map
	var mw: int = m.width
	var mh: int = m.height
	var tl: Array = m.tiles
	var explored: Array = m.explored
	var room_at: Array = m.roomAt
	var T := tile_px
	var k := T / U
	var c := Pen.new(ci)
	var x0 := maxi(0, int(_region.position.x))
	var y0 := maxi(0, int(_region.position.y))
	var x1 := mini(mw, int(_region.end.x) + 1)
	var y1 := mini(mh, int(_region.end.y) + 1)
	var materials := {}

	# --- Böden, Umgebungsverdeckung, Treppen, Türen
	for y in range(y0, y1):
		for x in range(x0, x1):
			var i := y * mw + x
			if not (vis.has(i) or (memory and explored[i])):
				continue
			var tile: String = tl[i]
			if tile == "wall":
				continue
			var px := x * T
			var py := y * T
			var ri: int = room_at[i]
			var room = m.rooms[ri] if ri >= 0 else null
			var r := Rect2(px, py, T, T)
			if tiles:
				var mat = materials.get(ri)
				if mat == null:
					mat = Tiles.room_material(room)
					materials[ri] = mat
				_tex_on(ci, tiles.floor_tex(mat, floori(Tiles.hash(x, y) * 4)), r)
			# Weiche Schatten an angrenzenden Wänden
			var n: bool = y == 0 or tl[i - mw] == "wall"
			var so: bool = y == mh - 1 or tl[i + mw] == "wall"
			var we: bool = x == 0 or tl[i - 1] == "wall"
			var ea: bool = x == mw - 1 or tl[i + 1] == "wall"
			if tiles:
				if n: _tex_on(ci, tiles.ao_tex("n"), r)
				if so: _tex_on(ci, tiles.ao_tex("s"), r)
				if we: _tex_on(ci, tiles.ao_tex("w"), r)
				if ea: _tex_on(ci, tiles.ao_tex("e"), r)
				if not n and not we and _wall(x - 1, y - 1): _tex_on(ci, tiles.ao_tex("nw"), r)
				if not n and not ea and _wall(x + 1, y - 1): _tex_on(ci, tiles.ao_tex("ne"), r)
				if not so and not we and _wall(x - 1, y + 1): _tex_on(ci, tiles.ao_tex("sw"), r)
				if not so and not ea and _wall(x + 1, y + 1): _tex_on(ci, tiles.ao_tex("se"), r)
			var rkind = room.kind if room != null else null
			if tile == "floor" and rkind != "safe" and rkind != "guild":
				_draw_decal(c, px, py, k, x, y, s.floor)
			# Einrichtung an den Wänden normaler Räume (nur Dekoration)
			if rkind == "normal" and tile == "floor" and (n or we or ea) and Tiles.hash(x, y, 5) < 0.09:
				_draw_prop(c, px, py, k, floori(Tiles.hash(x, y, 6) * 5))
			if tile == "stairs":
				if vis.has(i):
					_animated.append(["stairs", x, y])
				else:
					_draw_stairs(c, px, py, k, false, 0.0)
			if room != null:
				for f in J.arr(room, "furniture"):
					if f.pos.x == x and f.pos.y == y:
						if f.kind == "automat" or f.kind == "haendler" or f.kind == "wirt":
							_animated.append(["furniture", x, y, f.kind])
						else:
							_draw_furniture(c, f.kind, px, py, k, 0.0)
						break
			if tile == "door" or tile == "dooropen":
				var horizontal := not MapGen.is_walkable(m, x - 1, y) and MapGen.tile_at(m, x - 1, y) != "door"
				var lair := false
				for d in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
					var nx: int = x + d[0]
					var ny: int = y + d[1]
					var nri: int = room_at[ny * mw + nx] if MapGen.in_bounds(m, nx, ny) else -1
					if nri >= 0 and (m.rooms[nri].kind == "boss" or m.rooms[nri].kind == "arena"):
						lair = true
				if lair and vis.has(i):
					_animated.append(["lairdoor", x, y, tile == "dooropen", horizontal])
				elif tiles:
					_tex_on(ci, tiles.door_tex(tile == "dooropen", horizontal, lair), r)

	# --- Wände mit Vorderseite, Kanten zum Raum hin betont
	var th := Tiles.wall_theme(s.floor)
	var lip := Pen.rgba(th.lip, 0.55)
	var lw := maxf(1.0, 1.2 * k)
	for y in range(y0, y1):
		for x in range(x0, x1):
			var i := y * mw + x
			if tl[i] != "wall" or not (vis.has(i) or (memory and explored[i])):
				continue
			var edge := false
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var nx := x + dx
					var ny := y + dy
					if nx >= 0 and ny >= 0 and nx < mw and ny < mh and tl[ny * mw + nx] != "wall":
						edge = true
			if not edge:
				continue
			var below := not _wall(x, y + 1)
			var px := x * T
			var py := y * T
			if tiles:
				_tex_on(ci, tiles.wall_tex(s.floor, floori(Tiles.hash(x, y, 3) * 4), below), Rect2(px, py, T, T))
			# Helle Kante der Mauerkrone, wo sie an Boden grenzt
			if not _wall(x, y - 1):
				ci.draw_rect(Rect2(px, py, T, lw), lip)
			if not _wall(x - 1, y):
				ci.draw_rect(Rect2(px, py, lw, T * 0.38 if below else T), lip)
			if not _wall(x + 1, y):
				ci.draw_rect(Rect2(px + T - lw, py, lw, T * 0.38 if below else T), lip)


func _wall(x: int, y: int) -> bool:
	var m: Dictionary = s.map
	return x < 0 or y < 0 or x >= m.width or y >= m.height or m.tiles[y * m.width + x] == "wall"


func _tex_on(ci: CanvasItem, tex: Texture2D, r: Rect2) -> void:
	if tex:
		ci.draw_texture_rect(tex, r, false)


## Alles, was sich bewegt: Glühen, Nebel, Pfad, Fallen, Gegenstände, Figuren, Licht.
func _draw_dynamic() -> void:
	if s.is_empty():
		return
	var t0 := Time.get_ticks_usec()
	_draw_dynamic_body()
	last_draw_ms = (Time.get_ticks_usec() - t0) / 1000.0 + last_static_ms
	last_static_ms = 0.0


func _draw_dynamic_body() -> void:
	var w := size.x
	var h := size.y
	var vis := visible_set
	var memory := Game.has_unlock(s, "minimap")
	var m: Dictionary = s.map
	var explored: Array = m.explored
	var time: float = frame_anim.time
	var T := tile_px
	var k := T / U
	var c := Pen.new(_dyn)
	var x0 := maxi(0, floori(ox) - 1)
	var y0 := maxi(0, floori(oy) - 1)
	var x1 := mini(int(m.width), ceili(ox + ceili(w / T)) + 1)
	var y1 := mini(int(m.height), ceili(oy + ceili(h / T)) + 1)

	# --- Treppe, Boss-Türen und Automaten mit Glühen
	for a in _animated:
		var px := _sx(a[1])
		var py := _sy(a[2])
		match a[0]:
			"stairs":
				_draw_stairs(c, px, py, k, true, time)
			"furniture":
				_draw_furniture(c, a[3], px, py, k, time)
			"lairdoor":
				var pulse := 0.25 + 0.15 * sin(time / 400.0)
				var g := c.radial_gradient(px + T / 2, py + T / 2, 1, px + T / 2, py + T / 2, T)
				g.add(0, Color(1, 60 / 255.0, 40 / 255.0, pulse))
				g.add(1, Color(1, 60 / 255.0, 40 / 255.0, 0))
				c.fill_style = g
				c.fill_rect(px - T / 2, py - T / 2, T * 2, T * 2)
				if tiles:
					_tex_on(_dyn, tiles.door_tex(a[3], a[4], true), Rect2(px, py, T, T))

	# --- Nebel: Erinnerung abgedunkelt, Unbekanntes schwarz, weiche Kanten
	_draw_fog(vis, memory, x0, y0, x1, y1)

	# --- Pfadvorschau
	if path is Array and not (path as Array).is_empty():
		var pl: Array = path
		for n in pl.size():
			var p = pl[n]
			var cx := _sx(p.x) + T / 2
			var cy := _sy(p.y) + T / 2
			if n == pl.size() - 1:
				c.stroke_style = "rgba(255,214,90,0.85)"
				c.line_width = 1.5 * k
				c.begin_path()
				c.arc(cx, cy, 7 * k, 0, TAU)
				c.stroke()
			c.fill_style = Color(1, 214 / 255.0, 90 / 255.0, maxf(0.18, 0.7 - n * 0.025))
			c.begin_path()
			c.arc(cx, cy, 2.4 * k, 0, TAU)
			c.fill()

	# --- Bekannte Fallen
	for tr in J.arr(s, "traps"):
		if tr.get("hidden", false):
			continue
		var i := MapGen.idx(m, tr.pos.x, tr.pos.y)
		if not (vis.has(i) or (memory and explored[i])):
			continue
		c.alpha = 1.0 if vis.has(i) else 0.45
		_draw_trap(c, tr.kind, _sx(tr.pos.x), _sy(tr.pos.y), k, tr.get("owner") == "crawler")
		c.alpha = 1.0

	# --- Gegenstände
	for e in s.items:
		var i := MapGen.idx(m, e.pos.x, e.pos.y)
		if not (vis.has(i) or (memory and explored[i])):
			continue
		c.alpha = 1.0 if vis.has(i) else 0.4
		_draw_item(c, e.item, _sx(e.pos.x) + T / 2, _sy(e.pos.y) + T / 2, k, vis.has(i), time)
		c.alpha = 1.0

	c.text_align = "center"
	c.text_baseline = "middle"

	# --- Andere Crawler (nur sichtbare)
	for cr in J.arr(s, "crawlers"):
		if not cr.alive or not vis.has(MapGen.idx(m, cr.pos.x, cr.pos.y)):
			continue
		var p := _at(cr.uid, cr.pos)
		var cx := _sx(p.x) + T / 2
		var cy := _sy(p.y) + T / 2
		var party: bool = cr.get("party", false)
		var col := "#7fe0a0" if party else "#7cc4ff"
		var r := 9.5 * k
		_ground_ring(c, cx, cy + r * 0.72, r, k, Pen.rgba(col, 0.6))
		Sprites.draw_sprite(c, "crawler", "#4f9a6a" if party else "#4a7fb0", cx, cy - 1.5 * k, r * 2.7, {"time": time})
		if cr.hp < cr.maxHp:
			_hp_bar(c, cx, cy - r - 5 * k, r * 2, k, float(cr.hp) / cr.maxHp, "#6ee07a")

	# --- Monster (nur sichtbare)
	var ppos := _at("p", s.player.pos)
	for mo in s.monsters:
		if not vis.has(MapGen.idx(m, mo.pos.x, mo.pos.y)):
			continue
		var p := _at(mo.uid, mo.pos)
		var cx := _sx(p.x) + T / 2
		var cy := _sy(p.y) + T / 2
		var boss: bool = mo.rank != "normal" and mo.rank != "elite"
		var elite: bool = mo.rank == "elite"
		var info := Identify.describe_monster(s, mo)
		var unknown: bool = info.insight >= 3
		var sz: String = mo.get("size", "")
		var base := 14.5 if boss else (10.5 if sz == "winzig" else (12.0 if sz == "klein" else (14.0 if sz == "gross" or sz == "riesig" else 13.0)))
		var r := base * k
		var asleep: bool = mo.get("asleep", false)
		var ring_col: Variant
		if mo.get("aware", false) and not asleep:
			ring_col = Color(1, 76 / 255.0, 60 / 255.0, 0.45 + 0.35 * (0.5 + 0.5 * sin(time / 170.0)))
		else:
			ring_col = Pen.rgba(_hex_or(info.challenge.color, "#a39a8c"), 0.55)
		_ground_ring(c, cx, cy + r * 0.72, r * 1.05, k, ring_col, "#ffcc33" if boss else ("#ff5a4a" if elite else null))
		var bob := 0.0 if asleep else sin(time / 260.0 + mo.pos.x * 1.7) * 0.8 * k
		c.alpha = 0.85 if asleep else 1.0
		Sprites.draw_sprite(c, Sprites.sprite_for(mo.defId, mo.rank == "geist"), mo.color, cx, cy - 2 * k + bob, r * 3.1, {"time": time, "flip": p.x > ppos.x, "crown": boss, "unknown": unknown})
		c.alpha = 1.0
		# Brennende Gegner flackern
		if _cond_turns(mo, "brennen") > 0:
			var flicker := 0.45 + 0.35 * sin(time / 70.0 + mo.pos.x)
			c.stroke_style = Color(1, 140 / 255.0, 40 / 255.0, flicker)
			c.line_width = 2 * k
			c.begin_path()
			c.arc(cx, cy, r + 1.8 * k, 0, TAU)
			c.stroke()
		if mo.hp < mo.maxHp and info.showHealthBar:
			_hp_bar(c, cx, cy - r - 6 * k, maxf(r * 2, 18 * k), k, float(mo.hp) / mo.maxHp, "#ff5a4a")
		# Stufenmarke unten links: Farbe zeigt die Herausforderung
		_level_pill(c, cx - r * 0.72, cy + r * 0.78, k, J.s(mo.level) if info.insight <= 1 else "?", info.challenge.color)
		# Zustände als kleine farbige Punkte oben rechts
		var conds := Conditions.condition_list(mo)
		for n in conds.size():
			var dx := cx + r * 0.95 - n * 7.5 * k
			var dy := cy - r * 1.02
			c.fill_style = "rgba(0,0,0,0.8)"
			c.begin_path()
			c.arc(dx, dy, 3.8 * k, 0, TAU)
			c.fill()
			c.fill_style = conds[n].color
			c.begin_path()
			c.arc(dx, dy, 2.6 * k, 0, TAU)
			c.fill()
		if asleep:
			c.font(10 * k, 700)
			c.fill_style = "#a9c8ff"
			var zb := sin(time / 400.0) * 2 * k
			c.fill_text("z", cx + r + 2 * k, cy - r + zb)
			c.font(8 * k, 700)
			c.fill_text("z", cx + r + 7 * k, cy - r - 5 * k + zb)
		else:
			var label: Variant = null
			if J.num(mo, "downed") > 0:
				label = ["am Boden", "#7cc4ff"]
			elif _cond_turns(mo, "furcht") > 0:
				label = ["verängstigt", "#c3a3ff"]
			elif _cond_turns(mo, "blind") > 0:
				label = ["geblendet", "#e2e2e2"]
			elif mo.get("fleeing", false):
				label = ["flieht", "#ffd24a"]
			if label != null:
				_tag(c, cx, cy + r + 7 * k, k, label[0], label[1])

	# --- Haustier
	var pet = s.player.get("pet")
	if pet != null and pet.alive:
		var p := _at("pet", pet.pos)
		var cx := _sx(p.x) + T / 2
		var cy := _sy(p.y) + T / 2
		_ground_ring(c, cx, cy + 6 * k, 8.5 * k, k, "rgba(255,179,230,0.6)")
		Sprites.draw_sprite(c, "haustier", "#e0a0c8", cx, cy - 1 * k, 19 * k, {"time": time})
		if pet.hp < pet.maxHp:
			_hp_bar(c, cx, cy - 13 * k, 16 * k, k, float(pet.hp) / pet.maxHp, "#ff8ad8")

	# --- Spieler
	var pxp := _sx(ppos.x) + T / 2
	var pyp := _sy(ppos.y) + T / 2
	_draw_player(c, pxp, pyp, k, time)

	# --- Licht: weicher Lichtkegel um den Crawler
	var radius := Player.lichtradius(s) * T
	var flick := 1 + sin(time / 90.0) * 0.012 + sin(time / 37.0) * 0.008
	var dark := c.radial_gradient(pxp, pyp, radius * 0.4 * flick, pxp, pyp, radius * 1.05 * flick)
	dark.add(0, "rgba(0,0,0,0)")
	dark.add(0.7, "rgba(2,3,8,0.14)")
	dark.add(1, "rgba(2,3,8,0.4)")
	c.fill_style = dark
	c.fill_rect(0, 0, w, h)
	_light_center = Vector2(pxp, pyp)
	_light_radius = radius


var _light_center := Vector2.ZERO
var _light_radius := 0.0


func _tex(tex: Texture2D, r: Rect2) -> void:
	if tex:
		draw_texture_rect(tex, r, false)


## Warmer Schein (additiv gemischt wie „lighter“ im Browser).
func _draw_light() -> void:
	if s.is_empty() or _light_radius <= 0.0:
		return
	var c := Pen.new(_light)
	var radius := _light_radius
	var p := _light_center
	var warm := c.radial_gradient(p.x, p.y, 0, p.x, p.y, radius * 0.75)
	warm.add(0, "rgba(110,70,22,0.17)")
	warm.add(1, "rgba(110,70,22,0)")
	c.fill_style = warm
	c.fill_rect(p.x - radius, p.y - radius, radius * 2, radius * 2)


## Geschosse, Zahlen, Hover, Auswahl, Vignette.
func _draw_top() -> void:
	if s.is_empty():
		return
	var c := Pen.new(_top)
	var T := tile_px
	var k := T / U
	var w := size.x
	var h := size.y
	for pr in frame_anim.get("projectiles", []):
		_draw_projectile(c, pr, k)
	c.font(14 * k, 800)
	c.text_align = "center"
	c.text_baseline = "middle"
	for f in frame_anim.get("floaters", []):
		c.alpha = f.alpha
		c.stroke_style = "rgba(0,0,0,0.85)"
		c.line_width = 3.2 * k
		c.stroke_text(f.text, _sx(f.x) + T / 2, _sy(f.y))
		c.fill_style = f.color
		c.fill_text(f.text, _sx(f.x) + T / 2, _sy(f.y))
	c.alpha = 1.0
	if hover != null:
		var hx := _sx(hover.x)
		var hy := _sy(hover.y)
		c.fill_style = "rgba(255, 214, 90, 0.07)"
		c.stroke_style = "rgba(255, 214, 90, 0.9)"
		c.line_width = 1.5
		c.begin_path()
		c.round_rect(hx + 1, hy + 1, T - 2, T - 2, 4 * k)
		c.fill()
		c.stroke()
	if selected != null:
		var qx := _sx(selected.x)
		var qy := _sy(selected.y)
		var L := T * 0.3
		c.stroke_style = "rgba(140, 200, 255, 0.95)"
		c.line_width = 2
		c.begin_path()
		for q in [[qx, qy, 1, 1], [qx + T, qy, -1, 1], [qx, qy + T, 1, -1], [qx + T, qy + T, -1, -1]]:
			c.move_to(q[0] + q[2] * L, q[1] + q[3] * 1)
			c.line_to(q[0] + q[2] * 1, q[1] + q[3] * 1)
			c.line_to(q[0] + q[2] * 1, q[1] + q[3] * L)
		c.stroke()
	# Vignette: Ränder weich abdunkeln
	var vg := c.radial_gradient(w / 2, h / 2, minf(w, h) * 0.35, w / 2, h / 2, maxf(w, h) * 0.75)
	vg.add(0, "rgba(0,0,0,0)")
	vg.add(1, "rgba(0,0,0,0.5)")
	c.fill_style = vg
	c.fill_rect(0, 0, w, h)


func _draw_fog(vis: Dictionary, memory: bool, x0: int, y0: int, x1: int, y1: int) -> void:
	var m: Dictionary = s.map
	var fw := x1 - x0 + 2
	var fh := y1 - y0 + 2
	if fw <= 0 or fh <= 0:
		return
	var data := PackedByteArray()
	data.resize(fw * fh * 4)
	var mw: int = m.width
	var mh: int = m.height
	var explored: Array = m.explored
	var o := 0
	for fy in fh:
		var y := y0 - 1 + fy
		for fx in fw:
			var x := x0 - 1 + fx
			var a := 255
			if x >= 0 and y >= 0 and x < mw and y < mh:
				var i := y * mw + x
				if vis.has(i):
					a = 0
				elif memory and explored[i]:
					a = 150
			data[o] = 5
			data[o + 1] = 6
			data[o + 2] = 12
			data[o + 3] = a
			o += 4
	var img := Image.create_from_data(fw, fh, false, Image.FORMAT_RGBA8, data)
	if _fog_tex == null or _fog_img == null or _fog_img.get_size() != img.get_size():
		_fog_tex = ImageTexture.create_from_image(img)
	else:
		_fog_tex.update(img)
	_fog_img = img
	_dyn.draw_texture_rect(_fog_tex, Rect2(_sx(x0 - 1), _sy(y0 - 1), fw * tile_px, fh * tile_px), false)


# ================================================================ Figuren

## Leuchtender Ring am Boden unter einer Figur.
func _ground_ring(c: Pen, cx: float, cy: float, r: float, k: float, color: Variant, outer: Variant = null) -> void:
	c.fill_style = "rgba(0,0,0,0.45)"
	c.begin_path()
	c.ellipse(cx, cy, r, r * 0.42, 0, 0, TAU)
	c.fill()
	c.stroke_style = color
	c.line_width = 1.8 * k
	c.stroke()
	if outer != null:
		c.stroke_style = outer
		c.line_width = 1.2 * k
		c.begin_path()
		c.ellipse(cx, cy, r + 3 * k, (r + 3 * k) * 0.42, 0, 0, TAU)
		c.stroke()


func _hp_bar(c: Pen, cx: float, y: float, width: float, k: float, frac: float, color: String) -> void:
	var f := clampf(frac, 0, 1)
	var hgt := 4 * k
	var x := cx - width / 2
	c.fill_style = "rgba(0,0,0,0.8)"
	c.begin_path()
	c.round_rect(x - 1, y - 1, width + 2, hgt + 2, hgt)
	c.fill()
	if f <= 0:
		return
	var g := c.linear_gradient(0, y, 0, y + hgt)
	g.add(0, Pen.shade(_hex_or(color, "#ff5a4a"), 1.25))
	g.add(1, color)
	c.fill_style = g
	c.begin_path()
	c.round_rect(x, y, maxf(hgt, width * f), hgt, hgt / 2)
	c.fill()


func _level_pill(c: Pen, cx: float, cy: float, k: float, text: String, color: Variant) -> void:
	c.font(8.5 * k, 800)
	var w := maxf(11 * k, c.measure_text(text) * 1.0 + 6 * k)
	var h := 10 * k
	c.fill_style = "rgba(0,0,0,0.85)"
	c.begin_path()
	c.round_rect(cx - w / 2 - 1, cy - h / 2 - 1, w + 2, h + 2, h)
	c.fill()
	c.fill_style = color
	c.begin_path()
	c.round_rect(cx - w / 2, cy - h / 2, w, h, h / 2)
	c.fill()
	c.fill_style = "#12100c"
	c.fill_text(text, cx, cy + 0.5 * k)


## Kleines Schild unter einer Figur, z. B. „am Boden“.
func _tag(c: Pen, cx: float, cy: float, k: float, text: String, color: String) -> void:
	c.font(9 * k, 700)
	var w := c.measure_text(text) + 8 * k
	var h := 12 * k
	c.fill_style = "rgba(8,9,14,0.82)"
	c.begin_path()
	c.round_rect(cx - w / 2, cy - h / 2, w, h, 4 * k)
	c.fill()
	c.stroke_style = Pen.rgba(_hex_or(color, "#ffffff"), 0.5)
	c.line_width = 1
	c.stroke()
	c.fill_style = color
	c.fill_text(text, cx, cy + 0.5 * k)


func _draw_player(c: Pen, px: float, py: float, k: float, time: float) -> void:
	var p: Dictionary = s.player
	var r := 10 * k
	# Leuchten
	var glow := c.radial_gradient(px, py, 2, px, py, 34 * k)
	glow.add(0, "rgba(255, 214, 110, 0.42)")
	glow.add(1, "rgba(255, 214, 110, 0)")
	c.fill_style = glow
	c.fill_rect(px - 34 * k, py - 34 * k, 68 * k, 68 * k)
	var mount = p.get("mount")
	if p.get("riding", false) and mount != null and not mount.get("down", false):
		var mg := c.linear_gradient(0, py - 6 * k, 0, py + 14 * k)
		mg.add(0, "#8a6038")
		mg.add(1, "#4a3018")
		c.fill_style = mg
		c.begin_path()
		c.ellipse(px, py + 4 * k, 15 * k, 9.5 * k, 0, 0, TAU)
		c.fill()
		c.stroke_style = "#d19a5b"
		c.line_width = 1.6 * k
		c.stroke()
	# Bodenring in Gold, darauf die Figur
	_ground_ring(c, px, py + r * 0.75, r * 1.05, k, "rgba(255,214,90,0.9)")
	var dir = p.get("lastMoveDir")
	var flip: bool = dir != null and dir.x < 0
	Sprites.draw_hero(c, px, py - 2 * k + sin(time / 300.0) * 0.6 * k, r * 3.1, flip)
	var has_buff := func(n: String) -> bool:
		for b in p.buffs:
			if b.name == n:
				return true
		return false
	if has_buff.call("Vergiftet"):
		c.stroke_style = "rgba(155,224,74,0.8)"
		c.line_width = 1.6 * k
		c.begin_path()
		c.ellipse(px, py + r * 0.75, r * 1.3, r * 0.55, 0, 0, TAU)
		c.stroke()
	# Zustände des Crawlers als Außenring
	var ail: Array = []
	for pair in [["Blutung", "#e0434a"], ["Brennen", "#ff8a2a"], ["Furcht", "#b38cff"], ["Geblendet", "#d9d9d9"]]:
		if has_buff.call(pair[0]):
			ail.append(pair)
	for n in ail.size():
		c.stroke_style = Pen.rgba(ail[n][1], 0.55 + 0.3 * sin(time / 150.0 + n))
		c.line_width = 1.6 * k
		c.begin_path()
		var rr := r * 1.3 + (2 + n * 2.5) * k
		c.ellipse(px, py + r * 0.75, rr, rr * 0.42, 0, 0, TAU)
		c.stroke()


# ================================================================ Gegenstände

func _draw_item(c: Pen, it: Dictionary, cx: float, cy: float, k: float, is_visible: bool, time: float) -> void:
	var col: String
	if it.kind == "box" and it.get("box") != null:
		col = Db.world("BOX_TIER_COLORS")[it.box.tier]
	else:
		col = Db.t("items", "RARITY_COLORS")[it.rarity]
	if is_visible and (it.rarity != "gewoehnlich" or it.kind == "box"):
		var pulse := 0.75 + 0.25 * sin(time / 420.0 + cx)
		var g := c.radial_gradient(cx, cy, 1, cx, cy, 14 * k)
		g.add(0, Pen.rgba(col, 0.45 * pulse))
		g.add(1, Pen.rgba(col, 0))
		c.fill_style = g
		c.fill_rect(cx - 14 * k, cy - 14 * k, 28 * k, 28 * k)
	c.fill_style = "rgba(0,0,0,0.45)"
	c.begin_path()
	c.ellipse(cx, cy + 6.5 * k, 7 * k, 2.4 * k, 0, 0, TAU)
	c.fill()
	c.save()
	c.translate(cx, cy)
	c.scale(k, k)
	match it.kind:
		"gold": _coins(c)
		"karte": _scroll(c)
		"box": _chest(c, col)
		"wurf": _rock(c, "#3a3a3a" if it.get("explosion") else "#8d857a", it.get("explosion") != null and it.get("explosion"))
		"verbrauch": _flask(c, col)
		"buch": _book(c, col)
		"schrott": _nut(c)
		_: _gem(c, col)
	c.restore()


func _gem(c: Pen, col: String) -> void:
	c.fill_style = Pen.shade(_hex_or(col, "#c8c8c8"), 0.6)
	c.begin_path()
	c.move_to(0, -7)
	c.line_to(6.5, -1.5)
	c.line_to(0, 6.5)
	c.line_to(-6.5, -1.5)
	c.close_path()
	c.fill()
	c.fill_style = col
	c.begin_path()
	c.move_to(0, -7)
	c.line_to(6.5, -1.5)
	c.line_to(0, 1)
	c.line_to(-6.5, -1.5)
	c.close_path()
	c.fill()
	c.fill_style = "rgba(255,255,255,0.6)"
	c.begin_path()
	c.move_to(0, -7)
	c.line_to(2.5, -2.5)
	c.line_to(-2.5, -2.5)
	c.close_path()
	c.fill()
	c.stroke_style = "rgba(0,0,0,0.6)"
	c.line_width = 0.8
	c.begin_path()
	c.move_to(0, -7)
	c.line_to(6.5, -1.5)
	c.line_to(0, 6.5)
	c.line_to(-6.5, -1.5)
	c.close_path()
	c.stroke()


func _coins(c: Pen) -> void:
	for d in [[-3.5, 2.5], [3.5, 2.5], [0, -1]]:
		c.fill_style = "#8a6a10"
		c.begin_path()
		c.ellipse(d[0], d[1] + 1.4, 4.6, 2.5, 0, 0, TAU)
		c.fill()
		c.fill_style = "#ffd24a"
		c.begin_path()
		c.ellipse(d[0], d[1], 4.6, 2.5, 0, 0, TAU)
		c.fill()
		c.fill_style = "rgba(255,255,255,0.55)"
		c.fill_rect(d[0] - 2, d[1] - 1.2, 2.5, 0.9)


func _scroll(c: Pen) -> void:
	c.fill_style = "#eadcb0"
	c.fill_rect(-6.5, -4.5, 13, 9)
	c.fill_style = "#b89a5a"
	c.begin_path()
	c.round_rect(-8, -5.5, 2.6, 11, 1.2)
	c.round_rect(5.4, -5.5, 2.6, 11, 1.2)
	c.fill()
	c.stroke_style = "#6a8fb8"
	c.line_width = 0.9
	c.begin_path()
	c.move_to(-4, -1.5)
	c.line_to(0, 1)
	c.line_to(4, -1)
	c.stroke()


func _chest(c: Pen, col: String) -> void:
	c.fill_style = "#5b3a1e"
	c.begin_path()
	c.round_rect(-7.5, -3, 15, 9, 1.5)
	c.fill()
	c.fill_style = "#7a4f28"
	c.begin_path()
	c.round_rect(-7.5, -7, 15, 5, [3, 3, 0, 0])
	c.fill()
	c.fill_style = col
	c.fill_rect(-7.5, -2.6, 15, 1.4)
	c.fill_rect(-1.3, -4, 2.6, 5)
	c.fill_rect(-7.5, -7, 1.4, 13)
	c.fill_rect(6.1, -7, 1.4, 13)


func _rock(c: Pen, col: String, fuse: bool) -> void:
	c.fill_style = col
	c.begin_path()
	c.move_to(-5.5, 2)
	c.line_to(-4, -3.5)
	c.line_to(1, -5)
	c.line_to(5.5, -1.5)
	c.line_to(4.5, 4)
	c.line_to(-2, 5)
	c.close_path()
	c.fill()
	c.fill_style = "rgba(255,255,255,0.22)"
	c.begin_path()
	c.move_to(-4, -3.5)
	c.line_to(1, -5)
	c.line_to(0, -1)
	c.close_path()
	c.fill()
	if fuse:
		c.stroke_style = "#c8a060"
		c.line_width = 1
		c.begin_path()
		c.move_to(2, -4.5)
		c.quadratic_curve_to(5, -9, 7, -7)
		c.stroke()
		c.fill_style = "#ffb040"
		c.begin_path()
		c.arc(7, -7, 1.3, 0, TAU)
		c.fill()


func _flask(c: Pen, col: String) -> void:
	c.fill_style = "rgba(210,230,255,0.35)"
	c.begin_path()
	c.arc(0, 2, 5.5, 0, TAU)
	c.fill()
	c.fill_rect(-1.8, -6, 3.6, 5)
	c.fill_style = "#d8604a" if col == "#c8c8c8" else col
	c.begin_path()
	c.arc(0, 2.3, 4.3, 0, PI)
	c.fill()
	c.fill_style = "#8a6a44"
	c.fill_rect(-2.2, -7.5, 4.4, 2)
	c.fill_style = "rgba(255,255,255,0.55)"
	c.begin_path()
	c.arc(-2, 0, 1.2, 0, TAU)
	c.fill()


func _book(c: Pen, col: String) -> void:
	c.fill_style = Pen.shade(_hex_or(col, "#c8c8c8"), 0.55)
	c.begin_path()
	c.round_rect(-6, -5.5, 12, 11, 1.2)
	c.fill()
	c.fill_style = "#efe6cc"
	c.fill_rect(-4.5, -4, 9.5, 8)
	c.fill_style = col
	c.fill_rect(-6, -5.5, 2.2, 11)
	c.fill_style = "rgba(0,0,0,0.25)"
	c.fill_rect(-2.5, -2, 6, 0.8)
	c.fill_rect(-2.5, 0.5, 6, 0.8)


func _nut(c: Pen) -> void:
	c.fill_style = "#8f949b"
	c.begin_path()
	for n in 6:
		var a := n / 6.0 * TAU
		c.line_to(cos(a) * 5.5, sin(a) * 5.5)
	c.close_path()
	c.fill()
	c.fill_style = "#2a2d31"
	c.begin_path()
	c.arc(0, 0, 2.2, 0, TAU)
	c.fill()
	c.fill_style = "rgba(255,255,255,0.25)"
	c.fill_rect(-3, -4.5, 5, 1)


# ================================================================ Einrichtung, Treppe, Fallen, Geschosse

## Einrichtung der Safe Rooms: Automat, Händler, Wirt, Bett, Toilette.
func _draw_furniture(c: Pen, kind: String, px: float, py: float, k: float, time: float) -> void:
	var cx := px + tile_px / 2
	var cy := py + tile_px / 2
	if kind == "haendler" or kind == "wirt":
		# Theke, dahinter die Figur
		Sprites.draw_sprite(c, "mensch", "#8a4a3a" if kind == "wirt" else "#3a6a8a", cx, cy - 6 * k, 24 * k, {"time": time})
		c.save()
		c.translate(px, py)
		c.scale(k, k)
		Tiles.bevel(c, 2, 18, 28, 12, 2, "#6e4a2a", 0.22, 0.4)
		c.fill_style = "#e7c46a" if kind == "wirt" else "#9fd0ff"
		c.fill_rect(6, 22, 20, 1.5)
		c.restore()
		return
	c.save()
	c.translate(px, py)
	c.scale(k, k)
	c.fill_style = "rgba(0,0,0,0.4)"
	c.begin_path()
	c.ellipse(16, 28, 12, 3.5, 0, 0, TAU)
	c.fill()
	match kind:
		"automat":
			var glow := 0.5 + 0.3 * sin(time / 350.0)
			var g := c.radial_gradient(16, 14, 2, 16, 14, 22)
			g.add(0, Color(120 / 255.0, 220 / 255.0, 1, glow * 0.5))
			g.add(1, Color(120 / 255.0, 220 / 255.0, 1, 0))
			c.fill_style = g
			c.fill_rect(-8, -8, 48, 48)
			Tiles.bevel(c, 6, 1, 20, 28, 2.5, "#2e5f8a", 0.25, 0.4)
			c.fill_style = Color(170 / 255.0, 235 / 255.0, 1, 0.55 + glow * 0.3)
			c.fill_rect(9, 4, 14, 12)
			c.fill_style = "#ffe14a"
			c.fill_rect(10, 6, 3, 3)
			c.fill_style = "#ff7a6a"
			c.fill_rect(15, 6, 3, 3)
			c.fill_style = "#9fffb0"
			c.fill_rect(10, 11, 3, 3)
			c.fill_style = "#111"
			c.fill_rect(9, 20, 14, 4)
		"bett":
			Tiles.bevel(c, 4, 3, 24, 26, 3, "#5a3a22", 0.2, 0.4)
			Tiles.bevel(c, 6, 9, 20, 18, 2, "#3f6ea8", 0.25, 0.3)
			Tiles.bevel(c, 7, 4, 18, 6, 2.5, "#efe8d8", 0.3, 0.2)
		"toilette":
			Tiles.bevel(c, 10, 2, 12, 8, 2, "#e8ecef", 0.3, 0.25)
			c.fill_style = "#e8ecef"
			c.stroke_style = "#9aa2a8"
			c.line_width = 1
			c.begin_path()
			c.ellipse(16, 19, 8, 9, 0, 0, TAU)
			c.fill()
			c.stroke()
			c.fill_style = "#9fd0e8"
			c.begin_path()
			c.ellipse(16, 20, 4.5, 5.5, 0, 0, TAU)
			c.fill()
	c.restore()


## Einzelne Flecken, Risse und Pfützen – selten, an zufälliger Stelle.
func _draw_decal(c: Pen, px: float, py: float, k: float, x: int, y: int, floor: int) -> void:
	var roll := Tiles.hash(x, y, 41)
	if roll > 0.11:
		return
	var r := func(n: int) -> float: return Tiles.hash(x, y, 50 + n)
	c.save()
	c.translate(px, py)
	c.scale(k, k)
	if roll < 0.04:
		# Pfütze (auf Etage 3 grünlich)
		c.fill_style = "rgba(70,110,60,0.28)" if floor >= 3 else "rgba(30,40,55,0.35)"
		c.begin_path()
		c.ellipse(8 + r.call(1) * 16, 8 + r.call(2) * 16, 5 + r.call(3) * 5, 3 + r.call(4) * 2, r.call(5) * 3, 0, TAU)
		c.fill()
		c.fill_style = "rgba(200,220,255,0.10)"
		c.begin_path()
		c.ellipse(8 + r.call(1) * 16 - 1.5, 8 + r.call(2) * 16 - 1, 2, 0.8, r.call(5) * 3, 0, TAU)
		c.fill()
	elif roll < 0.075:
		# Riss
		c.stroke_style = "rgba(0,0,0,0.45)"
		c.line_width = 0.8
		c.begin_path()
		var cx: float = r.call(6) * 10 + 4
		var cy: float = r.call(7) * 10 + 4
		c.move_to(cx, cy)
		for n in 4:
			cx += 3 + r.call(8 + n) * 5
			cy += (r.call(12 + n) - 0.3) * 7
			c.line_to(cx, cy)
		c.stroke()
	else:
		# Fleck
		c.fill_style = "rgba(12,8,4,0.26)"
		c.begin_path()
		c.ellipse(8 + r.call(1) * 16, 8 + r.call(2) * 16, 4 + r.call(3) * 4, 2.5 + r.call(4) * 2, r.call(5) * 3, 0, TAU)
		c.fill()
	c.restore()


## Kisten, Fässer, Regale, Gerümpel.
func _draw_prop(c: Pen, px: float, py: float, k: float, kind: int) -> void:
	c.save()
	c.translate(px, py)
	c.scale(k, k)
	c.fill_style = "rgba(0,0,0,0.35)"
	c.begin_path()
	c.ellipse(16, 26, 11, 3, 0, 0, TAU)
	c.fill()
	match kind:
		0:
			# Holzkiste
			Tiles.bevel(c, 7, 8, 18, 17, 1.5, "#6e4c2b", 0.18, 0.35)
			c.stroke_style = "#3a2614"
			c.line_width = 1
			c.stroke_rect(7.5, 8.5, 17, 16)
			c.begin_path()
			c.move_to(8, 9)
			c.line_to(24, 24)
			c.stroke()
		1:
			# Fass
			var g := c.linear_gradient(7, 0, 25, 0)
			g.add(0, "#3e2812")
			g.add(0.45, "#7a5230")
			g.add(1, "#3e2812")
			c.fill_style = g
			c.begin_path()
			c.ellipse(16, 16, 9, 10, 0, 0, TAU)
			c.fill()
			c.stroke_style = "#8f949b"
			c.line_width = 1.2
			c.begin_path()
			c.ellipse(16, 11, 8.5, 2.5, 0, 0, TAU)
			c.ellipse(16, 21, 8.5, 2.5, 0, 0, TAU)
			c.stroke()
		2:
			# Regal
			Tiles.bevel(c, 4, 5, 24, 8, 1, "#4c3521", 0.15, 0.4)
			c.fill_style = "#b09468"
			c.fill_rect(7, 6.5, 4, 5)
			c.fill_style = "#6a8aa0"
			c.fill_rect(13, 6.5, 5, 5)
			c.fill_style = "#8a5a5a"
			c.fill_rect(20, 7.5, 4, 4)
		3:
			# Gerümpel
			Tiles.bevel(c, 8, 16, 8, 7, 1, "#5a534a")
			Tiles.bevel(c, 15, 12, 7, 11, 1, "#7a6a50")
			Tiles.bevel(c, 11, 9, 6, 6, 1, "#3e3e3e")
		_:
			# Eimer
			Tiles.bevel(c, 10, 12, 12, 11, 2, "#708090", 0.2, 0.35)
			c.fill_style = "#2a3238"
			c.fill_rect(10, 12, 12, 2.5)
			c.stroke_style = "#9aa6b0"
			c.line_width = 1
			c.begin_path()
			c.arc(16, 13, 6, PI, 0)
			c.stroke()
	c.restore()


## Eine Treppe nach unten, von oben gesehen.
func _draw_stairs(c: Pen, px: float, py: float, k: float, seen: bool, time: float) -> void:
	var T := tile_px
	if seen:
		var pulse := 0.28 + 0.08 * sin(time / 500.0)
		var glow := c.radial_gradient(px + T / 2, py + T / 2, 2, px + T / 2, py + T / 2, T * 1.2)
		glow.add(0, Color(1, 190 / 255.0, 80 / 255.0, pulse))
		glow.add(1, Color(1, 190 / 255.0, 80 / 255.0, 0))
		c.fill_style = glow
		c.fill_rect(px - T, py - T, T * 3, T * 3)
	c.save()
	c.translate(px, py)
	c.scale(k, k)
	Tiles.bevel(c, 1, 1, 30, 30, 2, "#6e5a42", 0.2, 0.35)
	c.fill_style = "#1d150d"
	c.fill_rect(4, 4, 24, 25)
	var steps := 5
	var step_h := 25.0 / steps
	for i in steps:
		var t := float(i) / (steps - 1)
		var inset := i * 1.3
		var x := 4 + inset
		var w := 24 - inset * 2
		var y := 4 + i * step_h
		var light := J.rnd(222 - t * 110)
		c.fill_style = Color(light / 255.0, J.rnd(light * 0.84) / 255.0, J.rnd(light * 0.62) / 255.0)
		c.fill_rect(x, y, w, step_h - 1.3)
		c.fill_style = Color(1, 245 / 255.0, 220 / 255.0, 0.75 - t * 0.5)
		c.fill_rect(x, y, w, 0.9)
		c.fill_style = "#120c06"
		c.fill_rect(x, y + step_h - 1.3, w, 1.3)
	c.stroke_style = "#d9ae52"
	c.line_width = 1.4
	c.begin_path()
	c.move_to(3, 4)
	c.line_to(3 + steps * 1.3, 29)
	c.move_to(29, 4)
	c.line_to(29 - steps * 1.3, 29)
	c.stroke()
	c.restore()


func _draw_trap(c: Pen, kind: String, px: float, py: float, k: float, own: bool) -> void:
	var col := "#6ee07a" if own else "#ff5a4a"
	c.save()
	c.translate(px, py)
	c.scale(k, k)
	var cx := 16.0
	var cy := 16.0
	# Markierung: getönter Kreis, damit Fallen auf jedem Boden auffallen
	c.fill_style = Pen.rgba(col, 0.12)
	c.stroke_style = Pen.rgba(col, 0.45)
	c.dash = [2.5, 2]
	c.line_width = 1
	c.begin_path()
	c.arc(cx, cy, 12.5, 0, TAU)
	c.fill()
	c.stroke()
	c.dash = []
	c.stroke_style = col
	c.fill_style = col
	c.line_width = 1.8
	match kind:
		"pfeilplatte":
			c.stroke_rect(9.5, 9.5, 13, 13)
			for d in [[-3, -3], [3, -3], [-3, 3], [3, 3]]:
				c.begin_path()
				c.arc(cx + d[0], cy + d[1], 1.3, 0, TAU)
				c.fill()
		"fallgrube":
			c.fill_style = "rgba(0,0,0,0.8)"
			c.begin_path()
			c.ellipse(cx, cy, 9, 7, 0, 0, TAU)
			c.fill()
			c.stroke()
		"giftgas":
			c.fill_style = "rgba(140,220,90,0.4)"
			c.begin_path()
			c.arc(cx - 4, cy - 3, 5, 0, TAU)
			c.arc(cx + 4, cy - 1, 4, 0, TAU)
			c.arc(cx, cy + 4, 4, 0, TAU)
			c.fill()
			c.begin_path()
			c.arc(cx, cy, 3, 0, TAU)
			c.stroke()
		"stolperdraht":
			c.begin_path()
			c.move_to(4, cy + 3)
			c.line_to(28, cy - 3)
			c.stroke()
			c.fill_rect(3, cy + 1, 3, 5)
			c.fill_rect(26, cy - 5, 3, 5)
		"baerenfalle", "schlingfalle":
			c.begin_path()
			c.arc(cx, cy, 8, 0, TAU)
			c.stroke()
			for a in 10:
				var ang := a / 10.0 * TAU
				c.begin_path()
				c.move_to(cx + cos(ang) * 8, cy + sin(ang) * 8)
				c.line_to(cx + cos(ang) * 4.5, cy + sin(ang) * 4.5)
				c.stroke()
		"stachelfalle":
			for d in [[-6, 5], [0, 5], [6, 5], [-3, -2], [3, -2]]:
				c.begin_path()
				c.move_to(cx + d[0] - 2.5, cy + d[1])
				c.line_to(cx + d[0], cy + d[1] - 6)
				c.line_to(cx + d[0] + 2.5, cy + d[1])
				c.close_path()
				c.fill()
		"sprengfalle":
			c.begin_path()
			c.round_rect(cx - 6, cy - 3, 12, 8, 1.5)
			c.fill()
			c.begin_path()
			c.move_to(cx + 5, cy - 3)
			c.quadratic_curve_to(cx + 10, cy - 9, cx + 5, cy - 10)
			c.stroke()
	c.restore()


const PROJECTILE_COLORS := {"stein": "#c8c0b0", "pfeil": "#e0d0a0", "magie": "#c080ff", "feuer": "#ff8a2a", "schleim": "#8ce04a", "bombe": "#555555", "blitz": "#9fdcff"}


func _draw_projectile(c: Pen, pr: Dictionary, k: float) -> void:
	var T := tile_px
	var cx := _sx(pr.x) + T / 2
	var cy := _sy(pr.y) + T / 2
	var style: String = pr.style
	var color: String = PROJECTILE_COLORS.get(style, "#c8c0b0")
	# Schweif
	var trail: Array = pr.trail
	for n in trail.size():
		var tp: Vector2 = trail[n]
		c.alpha = (n + 1.0) / trail.size() * 0.4
		c.fill_style = color
		c.begin_path()
		c.arc(_sx(tp.x) + T / 2, _sy(tp.y) + T / 2, (4.5 if style == "magie" or style == "feuer" else 2.5) * k, 0, TAU)
		c.fill()
	c.alpha = 1.0
	if style == "pfeil":
		c.save()
		c.translate(cx, cy)
		c.rotate(pr.angle)
		c.scale(k, k)
		c.stroke_style = color
		c.line_width = 2
		c.begin_path()
		c.move_to(-10, 0)
		c.line_to(8, 0)
		c.stroke()
		c.fill_style = "#e8e8e8"
		c.begin_path()
		c.move_to(11, 0)
		c.line_to(6, -3.5)
		c.line_to(6, 3.5)
		c.fill()
		c.fill_style = "#c05040"
		c.fill_rect(-11, -2.5, 3, 5)
		c.restore()
		return
	if style == "magie" or style == "feuer" or style == "blitz":
		var g := c.radial_gradient(cx, cy, 1, cx, cy, 13 * k)
		g.add(0, "#ffffff")
		g.add(0.3, color)
		g.add(1, "rgba(0,0,0,0)")
		c.fill_style = g
		c.begin_path()
		c.arc(cx, cy, 13 * k, 0, TAU)
		c.fill()
		return
	c.save()
	c.translate(cx, cy)
	c.rotate(pr.angle * 3)
	c.scale(k, k)
	c.fill_style = color
	c.begin_path()
	c.round_rect(-4, -4, 8, 8, 2)
	c.fill()
	c.fill_style = "rgba(255,255,255,0.25)"
	c.fill_rect(-3, -3, 4, 2)
	if style == "bombe":
		c.fill_style = "#ffb040"
		c.fill_rect(3, -7, 2, 4)
	c.restore()
