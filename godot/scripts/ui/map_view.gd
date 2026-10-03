class_name MapView
extends Control
## Die Karte in Pixel-Grafik. Eine Kachel ist 32 Kunstpixel groß und wird
## ganzzahlig vergrößert (Zoom 1× bis 3×), die Kamera rastet auf Kunstpixel
## ein. Ebenen von unten nach oben:
##   statisch   Böden, Schatten, Flecken, Einrichtung, Türen, Wände (nur bei Änderungen neu)
##   belebt     Treppe, Automaten, Boss-Türen, Fallen, Gegenstände
##   Nebel      bekannte und unbekannte Felder, gerastert mit Dithering (Shader)
##   Figuren    Pfad, Crawler, Monster, Haustier, Spielfigur
##   Dunkelheit Lichtkegel und Vignette, gerastert (Shader), dazu warmes Licht
##   oben       Geschosse, Zahlen, Maus, Auswahl

signal tile_hovered(tile: Variant)
signal tile_clicked(tile: Vector2i, button: int)
signal zoom_requested(delta: int)

const TILE := PixelArt.TILE
const ZOOM_STEPS := [32, 64, 96]

var s: Dictionary
var tiles: Tiles
var anim: Animator
var hover: Variant = null
var path: Variant = null
var selected: Variant = null

var zoom_index: int = 1
var tile_px: float = 64.0
## Bildschirmpixel pro Kunstpixel.
var px: int = 2
## Kamera: linke obere Ecke in Kachelkoordinaten.
var ox := 0.0
var oy := 0.0
var visible_set: Dictionary = {}
var frame_anim: Dictionary = {}
## Zeichenzeit des letzten Bildes in Millisekunden (zur Leistungsmessung).
var last_draw_ms := 0.0
var last_static_ms := 0.0

const REGION_MARGIN := 8.0
var _cam_px := Vector2.ZERO
var _region := Rect2()
var _static_key := ""
var _vis_key := ""
## Felder mit Bewegung (Treppe, Boss-Tür, Automat), gesammelt beim statischen Zeichnen.
var _animated: Array = []
var _static: Node2D
var _live: Control
var _fog: Control
var _dyn: Control
var _dark: ColorRect
var _warm: ColorRect
var _top: Control
var _fog_img: Image
var _fog_tex: ImageTexture
var _fog_rect := Rect2()
var _light_center := Vector2.ZERO
var _light_radius := 0.0

const FOG_SHADER := """
shader_type canvas_item;
uniform float cell = 3.0;
uniform vec2 grid = vec2(0.0);
uniform vec2 rect_pos = vec2(0.0);
uniform vec2 rect_size = vec2(1.0);
varying vec2 local_pos;
float bayer2(vec2 a) { a = floor(a); return fract(a.x / 2.0 + a.y * a.y * 0.75); }
float bayer4(vec2 a) { return bayer2(0.5 * a) * 0.25 + bayer2(a); }
void vertex() { local_pos = VERTEX; }
void fragment() {
	vec2 c = floor((local_pos + grid) / cell);
	vec2 center = c * cell + cell * 0.5 - grid;
	float a = texture(TEXTURE, (center - rect_pos) / rect_size).a;
	float q = clamp(floor(a * 8.0 + bayer4(c)) / 8.0, 0.0, 1.0);
	COLOR = vec4(0.02, 0.024, 0.047, q);
}
"""

const DARK_SHADER := """
shader_type canvas_item;
uniform float cell = 3.0;
uniform vec2 grid = vec2(0.0);
uniform vec2 light_pos = vec2(0.0);
uniform float radius = 100.0;
uniform vec2 view_size = vec2(100.0);
// Fackeln: xy Bildschirmposition, z Radius
uniform vec3 torches[8];
uniform int torch_count = 0;
varying vec2 local_pos;
float bayer2(vec2 a) { a = floor(a); return fract(a.x / 2.0 + a.y * a.y * 0.75); }
float bayer4(vec2 a) { return bayer2(0.5 * a) * 0.25 + bayer2(a); }
void vertex() { local_pos = VERTEX; }
void fragment() {
	vec2 c = floor((local_pos + grid) / cell);
	vec2 center = c * cell + cell * 0.5 - grid;
	float d = distance(center, light_pos) / max(radius, 1.0);
	float a = mix(0.0, 0.16, clamp((d - 0.4) / 0.3, 0.0, 1.0));
	a = mix(a, 0.45, clamp((d - 0.7) / 0.35, 0.0, 1.0));
	for (int i = 0; i < 8; i++) {
		if (i >= torch_count) {
			break;
		}
		float dt = distance(center, torches[i].xy) / max(torches[i].z, 1.0);
		a = min(a, mix(0.0, 0.45, clamp((dt - 0.35) / 0.65, 0.0, 1.0)));
	}
	float r0 = min(view_size.x, view_size.y) * 0.35;
	float r1 = max(view_size.x, view_size.y) * 0.75;
	float v = clamp((length(center - view_size * 0.5) - r0) / (r1 - r0), 0.0, 1.0) * 0.5;
	a = 1.0 - (1.0 - a) * (1.0 - v);
	float q = clamp(floor(a * 8.0 + bayer4(c)) / 8.0, 0.0, 1.0);
	COLOR = vec4(0.008, 0.012, 0.03, q);
}
"""

const WARM_SHADER := """
shader_type canvas_item;
render_mode blend_add;
uniform float cell = 3.0;
uniform vec2 grid = vec2(0.0);
uniform vec2 light_pos = vec2(0.0);
uniform float radius = 100.0;
uniform vec3 torches[8];
uniform int torch_count = 0;
varying vec2 local_pos;
float bayer2(vec2 a) { a = floor(a); return fract(a.x / 2.0 + a.y * a.y * 0.75); }
float bayer4(vec2 a) { return bayer2(0.5 * a) * 0.25 + bayer2(a); }
void vertex() { local_pos = VERTEX; }
void fragment() {
	vec2 c = floor((local_pos + grid) / cell);
	vec2 center = c * cell + cell * 0.5 - grid;
	float d = distance(center, light_pos) / max(radius * 0.75, 1.0);
	float a = clamp(1.0 - d, 0.0, 1.0);
	float q = clamp(floor(a * 4.0 + bayer4(c)) / 4.0, 0.0, 1.0) * 0.18;
	vec3 col = vec3(0.43, 0.27, 0.09) * q;
	for (int i = 0; i < 8; i++) {
		if (i >= torch_count) {
			break;
		}
		float dt = distance(center, torches[i].xy) / max(torches[i].z, 1.0);
		float ta = clamp(1.0 - dt, 0.0, 1.0);
		col += vec3(0.55, 0.3, 0.08) * clamp(floor(ta * 4.0 + bayer4(c)) / 4.0, 0.0, 1.0) * 0.2;
	}
	COLOR = vec4(col, 1.0);
}
"""

static var _shaders := {}


static func _shader(code: String) -> Shader:
	if not _shaders.has(code):
		var sh := Shader.new()
		sh.code = code
		_shaders[code] = sh
	return _shaders[code]


func _layer(fn: Callable) -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	c.draw.connect(fn)
	add_child(c)
	return c


func _shaded_rect(code: String) -> ColorRect:
	var r := ColorRect.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	var mat := ShaderMaterial.new()
	mat.shader = _shader(code)
	r.material = mat
	add_child(r)
	return r


func _init() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var z = Settings.get_value("zoom_pixel", 1)
	zoom_index = clampi(int(z), 0, ZOOM_STEPS.size() - 1)
	_apply_zoom()
	_static = StaticLayer.new()
	_static.view = self
	_static.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_static)
	_live = _layer(_draw_live)
	_fog = _layer(_draw_fog)
	_fog.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var fm := ShaderMaterial.new()
	fm.shader = _shader(FOG_SHADER)
	_fog.material = fm
	_dyn = _layer(_draw_dynamic)
	_dark = _shaded_rect(DARK_SHADER)
	_warm = _shaded_rect(WARM_SHADER)
	_top = _layer(_draw_top)


func _apply_zoom() -> void:
	tile_px = ZOOM_STEPS[zoom_index]
	px = int(tile_px) / TILE


## Zoom ändern; gibt zurück, ob sich etwas geändert hat.
func zoom(delta: int) -> bool:
	var next := clampi(zoom_index + delta, 0, ZOOM_STEPS.size() - 1)
	if next == zoom_index:
		return false
	zoom_index = next
	_apply_zoom()
	Settings.set_value("zoom_pixel", zoom_index)
	return true


func zoom_bounds() -> Dictionary:
	return {"min": zoom_index == 0, "max": zoom_index == ZOOM_STEPS.size() - 1}


func tile_from_local(p: Vector2) -> Vector2i:
	return Vector2i(floori((p.x + _cam_px.x) / tile_px), floori((p.y + _cam_px.y) / tile_px))


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

## Bildschirm-x einer Kachelkoordinate (auch Zwischenwerte), auf Kunstpixel gerastert.
func _sx(x: float) -> float:
	return roundf(x * TILE) * px - _cam_px.x


func _sy(y: float) -> float:
	return roundf(y * TILE) * px - _cam_px.y


func _at(key: String, p: Dictionary) -> Vector2:
	var v := Vector2(p.x, p.y)
	if anim == null:
		return v
	var now: float = frame_anim.get("now", -1.0)
	return anim.draw_pos(key, v, now) + anim.lunge(key, now)


## Kreaturen mit zweitem Bild: flatternd oder schwebend (immer) und laufend (nur in Bewegung).
const FLAPPING := ["kreatur/fledermaus", "kreatur/motte", "kreatur/vogel", "kreatur/drohne"]
const WALKERS := ["kreatur/held", "kreatur/mensch"]


## Welches Bild gerade dran ist: erstes oder zweites (Name mit „_2“).
func _frame(name: String, key: String, moving: bool, idle: bool = true) -> String:
	var alt := name + "_2"
	if not idle or not PixelArt.has(alt):
		return name
	var time: float = frame_anim.get("time", 0.0)
	if name.get_slice("@", 0) in WALKERS:
		return alt if moving and fmod(time / 130.0, 2.0) >= 1.0 else name
	# Jede Figur mit eigenem Takt, damit nicht alle gleichzeitig schlagen
	var phase := float(absi(key.hash()) % 97) * 11.0
	var period := 170.0 if name in FLAPPING else 420.0
	return alt if fmod((time + phase) / period, 2.0) >= 1.0 else name


## Eine Figur zeichnen: zweites Bild, weißes Aufblitzen bei Treffern.
func _figure(ci: CanvasItem, key: String, name: String, x: float, y: float, tint: Variant, flip: bool, mod: Color = Color.WHITE, moving: bool = false, idle: bool = true) -> void:
	var n := _frame(name, key, moving, idle)
	if anim and anim.flashing(key, frame_anim.get("now", -1.0)):
		PixelArt.draw_texture(ci, PixelArt.silhouette(n), Vector2(x, y), px, flip, Color(1, 1, 1, mod.a), PixelArt.res(n))
		return
	_spr(ci, n, x, y, tint, flip, mod)


static func _cond_turns(m: Dictionary, id: String) -> float:
	var c = m.get("conditions")
	if c == null:
		return 0.0
	var e = c.get(id)
	return 0.0 if e == null else J.num(e, "turns")


static func _hex_or(c: Variant, fallback: String) -> Variant:
	return c if c is String and (c as String).length() == 7 else fallback


static func _col(c: Variant, a: float = 1.0) -> Color:
	var col: Color = c if c is Color else Color(String(_hex_or(c, "#ffffff")))
	return Color(col, col.a * a)


## Rechteck in Kunstpixeln relativ zu (x, y) in Bildschirmpixeln.
func _rect(ci: CanvasItem, x: float, y: float, ax: int, ay: int, aw: int, ah: int, c: Color) -> void:
	ci.draw_rect(Rect2(x + ax * px, y + ay * px, aw * px, ah * px), c)


func _spr(ci: CanvasItem, name: String, x: float, y: float, tint: Variant = null, flip: bool = false, mod: Color = Color.WHITE) -> void:
	PixelArt.draw(ci, name, Vector2(x, y), px, tint, flip, mod)


## Leuchten mittig bei (cx, cy); groß = zwei Kacheln, sonst eine.
func _glow(ci: CanvasItem, cx: float, cy: float, color: Variant, alpha: float, big: bool = true) -> void:
	var n := "aufsatz/leuchten" if big else "aufsatz/leuchten_klein"
	var half := (TILE if big else TILE / 2) * px
	_spr(ci, n, cx - half, cy - half, null, false, _col(color, alpha))


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
	_cam_px = Vector2(roundf(ox * tile_px / px) * px, roundf(oy * tile_px / px) * px)
	# Beben bei schweren Treffern, in ganzen Kunstpixeln
	_cam_px += (frame_anim.get("shake", Vector2.ZERO) as Vector2) * 2 * px
	var vkey := "%d|%d|%d|%d" % [s.turn, s.floor, s.player.pos.x, s.player.pos.y]
	if vkey != _vis_key:
		_vis_key = vkey
		visible_set = Game.visible_tiles(s)
	# Statische Ebene nur neu zeichnen, wenn sich etwas geändert hat oder die
	# Kamera den vorgezeichneten Bereich verlässt
	var memory := Game.has_unlock(s, "minimap")
	var inside := ox >= _region.position.x and oy >= _region.position.y and ox + cols <= _region.end.x and oy + rows <= _region.end.y
	var key := "%s|%d|%s" % [vkey, zoom_index, memory]
	if key != _static_key or not inside:
		_static_key = key
		_region = Rect2(floorf(ox) - REGION_MARGIN, floorf(oy) - REGION_MARGIN, ceilf(cols) + REGION_MARGIN * 2, ceilf(rows) + REGION_MARGIN * 2)
		_static.queue_redraw()
	_static.position = -_cam_px
	_update_light_shaders()
	queue_redraw()
	_live.queue_redraw()
	_fog.queue_redraw()
	_dyn.queue_redraw()
	_top.queue_redraw()


class StaticLayer:
	extends Node2D
	var view: MapView

	func _draw() -> void:
		var t0 := Time.get_ticks_usec()
		view._draw_static(self)
		view.last_static_ms = (Time.get_ticks_usec() - t0) / 1000.0


func _wall(x: int, y: int) -> bool:
	var m: Dictionary = s.map
	return x < 0 or y < 0 or x >= m.width or y >= m.height or m.tiles[y * m.width + x] == "wall"


## Hängt an dieser Wand eine Fackel? Nur an Vorderseiten über Boden in
## gewöhnlichen Räumen, Boss-Kammern, Arenen und Gilden, nicht zu dicht.
func _torch_at(x: int, y: int) -> bool:
	var m: Dictionary = s.map
	if (x + y) % 2 != 0 or Tiles.hash(x, y, 11) > 0.2 or not MapGen.in_bounds(m, x, y + 1):
		return false
	var below: int = (y + 1) * int(m.width) + x
	if m.tiles[below] != "floor":
		return false
	var ri: int = m.roomAt[below]
	return ri >= 0 and m.rooms[ri].kind in ["normal", "boss", "arena", "guild"]


static func door_name(open: bool, horizontal: bool, boss: bool) -> String:
	return "tuer/%s_%s_%s" % ["boss" if boss else "holz", "quer" if horizontal else "laengs", "offen" if open else "zu"]


## Nur Dekoration; echte Kisten und Fässer sind eigene Kacheln (zerschlagbar).
const PROPS := ["regal", "geruempel", "eimer"]


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
	var x0 := maxi(0, int(_region.position.x))
	var y0 := maxi(0, int(_region.position.y))
	var x1 := mini(mw, int(_region.end.x) + 1)
	var y1 := mini(mh, int(_region.end.y) + 1)
	var materials := {}
	var shade := Color(0, 0, 0, 0.38)
	var shade2 := Color(0, 0, 0, 0.18)

	# --- Böden, Schatten an Wänden, Flecken, Einrichtung, Türen
	for y in range(y0, y1):
		for x in range(x0, x1):
			var i := y * mw + x
			if not (vis.has(i) or (memory and explored[i])):
				continue
			var tile: String = tl[i]
			if tile == "wall":
				continue
			var sx := x * T
			var sy := y * T
			var ri: int = room_at[i]
			var room = m.rooms[ri] if ri >= 0 else null
			var mat = materials.get(ri)
			if mat == null:
				mat = Tiles.room_material(room)
				materials[ri] = mat
			if tile == Dungeon.WATER or tile == Kanalstadt.CANAL:
				# Wasser aus dem Tiny-Swords-Pack; die Gischt bewegt sich nur, wo man hinsieht
				_water(ci, x, y, sx, sy, -1 if vis.has(i) else 0)
				if vis.has(i):
					_animated.append(["water", x, y])
			elif tile == Dungeon.MUD or tile == Tiefgarage.OIL:
				_spr(ci, "boden/%s%d" % [tile, floori(Tiles.hash(x, y) * 4)], sx, sy)
			elif tile == Kanalstadt.BRIDGE:
				# Kanal links oder rechts: Brücke führt nach oben und unten
				var across: bool = MapGen.tile_at(m, x - 1, y) == Kanalstadt.CANAL or MapGen.tile_at(m, x + 1, y) == Kanalstadt.CANAL
				_spr(ci, "boden/%s%d" % ["bruecke" if across else "bruecke_quer", floori(Tiles.hash(x, y) * 4)], sx, sy)
			else:
				_spr(ci, "boden/%s%d" % [mat, floori(Tiles.hash(x, y) * 4)], sx, sy)
			# Harte Schatten unter und neben Wänden
			var n: bool = y == 0 or tl[i - mw] == "wall"
			var we: bool = x == 0 or tl[i - 1] == "wall"
			var ea: bool = x == mw - 1 or tl[i + 1] == "wall"
			if n:
				_rect(ci, sx, sy, 0, 0, TILE, 4, shade)
				_rect(ci, sx, sy, 0, 4, TILE, 2, shade2)
			if we:
				_rect(ci, sx, sy, 0, 0 if not n else 4, 2, TILE - (0 if not n else 4), shade2)
			if ea:
				_rect(ci, sx, sy, TILE - 2, 0 if not n else 4, 2, TILE - (0 if not n else 4), shade2)
			var rkind = room.kind if room != null else null
			# Parkdeck: weiße Stellplatzlinien an den Längsseiten
			if room != null and room.get("parkdeck") and (y == room.y or y == room.y + room.h - 1) and (x - room.x) % 2 == 0 and tile != "wall":
				_rect(ci, sx, sy, 0, 2, 2, TILE - 4, Color(0.85, 0.85, 0.8, 0.55))
			if tile == "floor" and rkind != "safe" and rkind != "guild":
				_draw_decal(ci, sx, sy, x, y, s.floor)
			# Einrichtung an den Wänden normaler Räume (nur Dekoration)
			if rkind == "normal" and tile == "floor" and (n or we or ea) and Tiles.hash(x, y, 5) < 0.09:
				_spr(ci, "moebel/" + PROPS[floori(Tiles.hash(x, y, 6) * PROPS.size())], sx, sy)
			if Dungeon.is_crate(tile) or Tiefgarage.is_wreck(tile):
				_spr(ci, "moebel/" + tile, sx, sy)
			if tile == "stairs":
				if vis.has(i):
					_animated.append(["stairs", x, y])
				else:
					_spr(ci, "treppe", sx, sy)
			if room != null:
				for f in J.arr(room, "furniture"):
					if f.pos.x == x and f.pos.y == y:
						if f.kind in ["automat", "haendler", "wirt", "schrein", "bildschirm"]:
							_animated.append(["furniture", x, y, f.kind])
						else:
							_spr(ci, "moebel/" + f.kind, sx, sy)
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
				else:
					_spr(ci, door_name(tile == "dooropen", horizontal, lair), sx, sy)
				if tile == "door" and Dungeon.lock_at(s, J.pos(x, y)) != null:
					_spr(ci, "aufsatz/schloss", sx, sy)

	# --- Wände im Tiny-Swords-Stil: Fels von oben, zum Raum hin die Felswand
	var sheet := wall_sheet(s.floor)
	for y in range(y0, y1):
		for x in range(x0, x1):
			var i := y * mw + x
			if tl[i] != "wall" or not (vis.has(i) or (memory and explored[i])) or not _edge_wall(x, y):
				continue
			var sx := x * T
			var sy := y * T
			# Unter den Ausbuchtungen des Randes liegt der Boden des Nachbarn
			for d in [[0, 1], [0, -1], [-1, 0], [1, 0]]:
				var nx: int = x + d[0]
				var ny: int = y + d[1]
				if MapGen.in_bounds(m, nx, ny) and tl[ny * mw + nx] != "wall":
					var nri: int = room_at[ny * mw + nx]
					var nmat = materials.get(nri)
					if nmat == null:
						nmat = Tiles.room_material(m.rooms[nri] if nri >= 0 else null)
						materials[nri] = nmat
					_spr(ci, "boden/%s%d" % [nmat, floori(Tiles.hash(nx, ny) * 4)], sx, sy)
					break
			var cell := wall_cell(x, y)
			ci.draw_texture_rect_region(sheet, Rect2(sx, sy, T, T), Rect2(cell.x * 64, cell.y * 64, 64, 64))
			if cell.y == 4 and _torch_at(x, y):
				if vis.has(i) or vis.has(i + mw):
					_animated.append(["torch", x, y])
				else:
					_spr(ci, "moebel/fackel", sx, sy)


const FOAM_FRAMES := 16
static var _terrain := {}


static func _ts(name: String) -> Texture2D:
	if not _terrain.has(name):
		_terrain[name] = load("res://assets/tinyswords/terrain/%s.png" % name)
	return _terrain[name]


static func _is_water(t: String) -> bool:
	return t == Dungeon.WATER or t == Kanalstadt.CANAL


## Wasserfläche mit Gischt an jedem Ufer (auch an Wänden). frame < 0: nur
## das Wasser (die Gischt zeichnet die lebende Ebene); foam_only: nur Gischt.
func _water(ci: CanvasItem, x: int, y: int, sx: float, sy: float, frame: int, foam_only: bool = false) -> void:
	var T := tile_px
	var m: Dictionary = s.map
	if not foam_only:
		var canal := MapGen.tile_at(m, x, y) == Kanalstadt.CANAL
		ci.draw_texture_rect(_ts("water"), Rect2(sx, sy, T, T), false, Color(0.66, 0.84, 0.7) if canal else Color(0.8, 0.9, 0.88))
	if frame < 0:
		return
	var foam := _ts("foam")
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if (dx == 0 and dy == 0) or not MapGen.in_bounds(m, x + dx, y + dy) or _is_water(MapGen.tile_at(m, x + dx, y + dy)):
				continue
			# Der Teil des Gischtrings um das Ufer-Feld, der auf dieses Feld fällt
			ci.draw_texture_rect_region(foam, Rect2(sx, sy, T, T), Rect2(frame * 192 + (1 - dx) * 64, (1 - dy) * 64, 64, 64))


static var _wall_sheets := {}


## Klippen-Block aus dem Tiny-Swords-Tileset, umgefärbt je Etage (siehe
## tools/import_tinyswords.gd).
static func wall_sheet(floor_no: int) -> Texture2D:
	var fl := clampi(floor_no, 1, 3)
	if not _wall_sheets.has(fl):
		_wall_sheets[fl] = load("res://assets/tinyswords/terrain/wall_%d.png" % fl)
	return _wall_sheets[fl]


## Wand mit Boden daneben (nur die werden gezeichnet; tiefer Fels bleibt dunkel).
func _edge_wall(x: int, y: int) -> bool:
	if _wall(x, y) == false or not MapGen.in_bounds(s.map, x, y):
		return false
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if not _wall(x + dx, y + dy):
				return true
	return false


## Felswand: Wand mit Boden direkt darunter.
func _face(x: int, y: int) -> bool:
	return _edge_wall(x, y) and not _wall(x, y + 1)


func _rock_top(x: int, y: int) -> bool:
	return _edge_wall(x, y) and _wall(x, y + 1)


## Feld im Klippen-Block: Spalte 0 links, 1 Mitte, 2 rechts, 3 einzeln;
## Reihe 0 oben, 1 Mitte, 2 unten, 3 einzeln, 4 Felswand.
func wall_cell(x: int, y: int) -> Vector2i:
	if _face(x, y):
		return Vector2i(_col_of(_face(x - 1, y), _face(x + 1, y)), 4)
	var top_edge := not _rock_top(x, y - 1)
	var bottom_edge := not _rock_top(x, y + 1)
	var row := 3 if top_edge and bottom_edge else (0 if top_edge else (2 if bottom_edge else 1))
	return Vector2i(_col_of(_rock_top(x - 1, y), _rock_top(x + 1, y)), row)


static func _col_of(left: bool, right: bool) -> int:
	if left and right:
		return 1
	if right:
		return 0
	if left:
		return 2
	return 3


## Einzelne Flecken, Risse und Pfützen – selten, an zufälliger Stelle.
func _draw_decal(ci: CanvasItem, sx: float, sy: float, x: int, y: int, floor_no: int) -> void:
	var roll := Tiles.hash(x, y, 41)
	if roll > 0.11:
		return
	var v := floori(Tiles.hash(x, y, 50) * 3)
	if roll < 0.04:
		# Pfütze, auf Etage 3 grünlich
		_spr(ci, "fleck/pfuetze%d" % v, sx, sy, null, false, Color(0.75, 1.15, 0.7) if floor_no >= 3 else Color.WHITE)
	elif roll < 0.075:
		_spr(ci, "fleck/riss%d" % v, sx, sy)
	else:
		_spr(ci, "fleck/fleck%d" % v, sx, sy)


## Treppe, Automaten, Boss-Türen (mit Leuchten), Fallen und Gegenstände – unter dem Nebel.
func _draw_live() -> void:
	if s.is_empty():
		return
	var ci := _live
	var time: float = frame_anim.time
	var T := tile_px
	var m: Dictionary = s.map
	var vis := visible_set
	var memory := Game.has_unlock(s, "minimap")
	var explored: Array = m.explored
	for a in _animated:
		var sx := _sx(a[1])
		var sy := _sy(a[2])
		match a[0]:
			"stairs":
				_glow(ci, sx + T / 2, sy + T / 2, "#ffbe50", 0.55 + 0.2 * sin(time / 500.0))
				_spr(ci, "treppe", sx, sy)
			"furniture":
				_draw_furniture(ci, a[3], sx, sy, time)
			"lairdoor":
				_glow(ci, sx + T / 2, sy + T / 2, "#ff3c28", 0.45 + 0.3 * sin(time / 400.0))
				_spr(ci, door_name(a[3], a[4], true), sx, sy)
			"water":
				_water(ci, a[1], a[2], sx, sy, int(time / 110.0) % FOAM_FRAMES, true)
			"torch":
				var ph: float = Tiles.hash(a[1], a[2], 12) * 1000.0
				_glow(ci, sx + T / 2, sy + 10 * px, "#ff9a3c", 0.38 + 0.12 * sin((time + ph) / 90.0) + 0.06 * sin((time + ph) / 37.0))
				_spr(ci, "moebel/fackel_2" if fmod((time + ph) / 160.0, 2.0) >= 1.0 else "moebel/fackel", sx, sy)

	# --- Bekannte Fallen
	for tr in J.arr(s, "traps"):
		if tr.get("hidden", false):
			continue
		var i := MapGen.idx(m, tr.pos.x, tr.pos.y)
		if not (vis.has(i) or (memory and explored[i])):
			continue
		var own: bool = tr.get("owner") == "crawler"
		var kind: String = tr.kind
		if kind == "schlingfalle":
			kind = "baerenfalle"
		_spr(ci, "falle/" + kind, _sx(tr.pos.x), _sy(tr.pos.y), "#6ee07a" if own else "#ff5a4a")

	# --- Angekündigte Spezialangriffe der Bosse: rot pulsierende Felder
	var danger := BossFight.danger_tiles(s)
	if not danger.is_empty():
		var pulse := 0.28 + 0.14 * sin(time / 110.0)
		for q in danger:
			if not vis.has(MapGen.idx(m, q.x, q.y)):
				continue
			var qx := _sx(q.x)
			var qy := _sy(q.y)
			_rect(ci, qx, qy, 0, 0, TILE, TILE, Color(1.0, 0.2, 0.1, pulse))
			_rect(ci, qx, qy, 0, 0, TILE, 2, Color(1.0, 0.8, 0.3, pulse + 0.45))
			_rect(ci, qx, qy, 0, TILE - 2, TILE, 2, Color(1.0, 0.8, 0.3, pulse + 0.45))
			_rect(ci, qx, qy, 0, 0, 2, TILE, Color(1.0, 0.8, 0.3, pulse + 0.45))
			_rect(ci, qx, qy, TILE - 2, 0, 2, TILE, Color(1.0, 0.8, 0.3, pulse + 0.45))

	# --- Gegenstände
	for e in s.items:
		var i := MapGen.idx(m, e.pos.x, e.pos.y)
		if not (vis.has(i) or (memory and explored[i])):
			continue
		_draw_item(ci, e.item, _sx(e.pos.x), _sy(e.pos.y), vis.has(i), time)


## Einrichtung der Safe Rooms mit Bewegung: Automat, Händler, Wirt, Bildschirm.
func _draw_furniture(ci: CanvasItem, kind: String, sx: float, sy: float, time: float) -> void:
	var T := tile_px
	match kind:
		"automat":
			_glow(ci, sx + T / 2, sy + T / 2, "#78dcff", 0.35 + 0.2 * sin(time / 350.0))
			_spr(ci, "moebel/automat", sx, sy)
		"schrein":
			_glow(ci, sx + T / 2, sy + 10 * px, "#ffb45a", 0.3 + 0.1 * sin(time / 130.0) + 0.05 * sin(time / 47.0))
			_spr(ci, "moebel/schrein", sx, sy)
		"haendler", "wirt":
			# Figur hinter der Theke
			var bob := 2 * px if fmod(time / 700.0, 2.0) < 1.0 else 0
			_spr(ci, "kreatur/mensch", sx, sy - 10 * px + bob, "#8a4a3a" if kind == "wirt" else "#3a6a8a")
			_spr(ci, "moebel/theke", sx, sy)
			_rect(ci, sx, sy, 8, 20, 16, 2, Color("#e7c46a") if kind == "wirt" else Color("#9fd0ff"))
		"bildschirm":
			_draw_screen(ci, sx, sy, time)
		_:
			_spr(ci, "moebel/" + kind, sx, sy)


## Fernseher auf zwei Beinen: tagsüber Testbild, während der Highlights
## flimmerndes Programm mit rotem Punkt.
func _draw_screen(ci: CanvasItem, sx: float, sy: float, time: float) -> void:
	var live := Highlights.on_air(s)
	if live:
		_glow(ci, sx + tile_px / 2, sy + 14 * px, "#7fb4ff", 0.35 + 0.15 * sin(time / 90.0))
	var dark := Color("#14161c")
	_rect(ci, sx, sy, 9, 24, 2, 6, dark)
	_rect(ci, sx, sy, 21, 24, 2, 6, dark)
	_rect(ci, sx, sy, 3, 5, 26, 20, dark)
	_rect(ci, sx, sy, 4, 6, 24, 18, Color("#3a3f50"))
	if live:
		var phase := int(time / 260.0)
		var cols := [Color("#2b4a8a"), Color("#3a7a6a"), Color("#8a4a3a"), Color("#6a3a8a")]
		_rect(ci, sx, sy, 5, 7, 22, 16, cols[phase % cols.size()])
		_rect(ci, sx, sy, 7 + (phase * 5) % 14, 12, 6, 8, Color("#e9e5dc"))
		_rect(ci, sx, sy, 5, 19, 22, 4, Color(0, 0, 0, 0.45))
		if fmod(time / 500.0, 2.0) < 1.3:
			_rect(ci, sx, sy, 23, 8, 2, 2, Color("#ff4040"))
	else:
		var bars := ["#b8b8b8", "#b8b800", "#00b8b8", "#00b800", "#b800b8", "#b80000"]
		for i in bars.size():
			_rect(ci, sx, sy, 5 + i * 4 - (1 if i == 5 else 0), 7, 4 if i < 5 else 3, 16, Color(bars[i]).darkened(0.35))
		_rect(ci, sx, sy, 5, 19, 22, 4, Color("#20202a"))


func _draw_item(ci: CanvasItem, it: Dictionary, sx: float, sy: float, is_visible: bool, time: float) -> void:
	var col := Sprites.item_color(it)
	var T := tile_px
	if is_visible and (it.rarity != "gewoehnlich" or it.kind == "box"):
		_glow(ci, sx + T / 2, sy + T / 2, col, 0.5 + 0.25 * sin(time / 420.0 + sx), false)
	_spr(ci, "aufsatz/schatten_klein", sx + 6 * px, sy + 22 * px)
	var look := Sprites.item_sprite(it)
	_spr(ci, look[0], sx, sy, look[1])


func _draw_fog() -> void:
	if s.is_empty():
		return
	var m: Dictionary = s.map
	var vis := visible_set
	var memory := Game.has_unlock(s, "minimap")
	var x0 := maxi(0, floori(ox) - 1)
	var y0 := maxi(0, floori(oy) - 1)
	var x1 := mini(int(m.width), ceili(ox + ceili(size.x / tile_px)) + 1)
	var y1 := mini(int(m.height), ceili(oy + ceili(size.y / tile_px)) + 1)
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
					# 160/255 ≈ 5/8: genau eine Stufe des Shaders, damit bekannte Felder nicht flimmern
					a = 160
			data[o + 3] = a
			o += 4
	var img := Image.create_from_data(fw, fh, false, Image.FORMAT_RGBA8, data)
	if _fog_tex == null or _fog_img == null or _fog_img.get_size() != img.get_size():
		_fog_tex = ImageTexture.create_from_image(img)
	else:
		_fog_tex.update(img)
	_fog_img = img
	# Texel liegen in Kachelmitten: um eine halbe Kachel versetzt zeichnen
	_fog_rect = Rect2(_sx(x0 - 1), _sy(y0 - 1), fw * tile_px, fh * tile_px)
	var mat: ShaderMaterial = _fog.material
	mat.set_shader_parameter("cell", float(px))
	mat.set_shader_parameter("grid", _cam_px)
	mat.set_shader_parameter("rect_pos", _fog_rect.position)
	mat.set_shader_parameter("rect_size", _fog_rect.size)
	_fog.draw_texture_rect(_fog_tex, _fog_rect, false)


func _update_light_shaders() -> void:
	var ppos := _at("p", s.player.pos)
	var T := tile_px
	var time: float = frame_anim.time
	var flick := 1 + sin(time / 90.0) * 0.012 + sin(time / 37.0) * 0.008
	_light_center = Vector2(_sx(ppos.x) + T / 2, _sy(ppos.y) + T / 2)
	_light_radius = Player.lichtradius(s) * T * flick
	# Sichtbare Fackeln, die nächsten acht zum Spieler
	var torches: Array = []
	for a in _animated:
		if a[0] == "torch":
			var ph: float = Tiles.hash(a[1], a[2], 12) * 1000.0
			var r := T * 2.6 * (1 + 0.04 * sin((time + ph) / 90.0))
			torches.append(Vector3(_sx(a[1]) + T / 2, _sy(a[2]) + T * 0.4, r))
	torches.sort_custom(func(u, w): return u.distance_squared_to(Vector3(_light_center.x, _light_center.y, u.z)) < w.distance_squared_to(Vector3(_light_center.x, _light_center.y, w.z)))
	var packed := PackedVector3Array()
	for i in 8:
		packed.append(torches[i] if i < torches.size() else Vector3.ZERO)
	for r in [_dark, _warm]:
		var mat: ShaderMaterial = r.material
		mat.set_shader_parameter("cell", float(px))
		mat.set_shader_parameter("grid", _cam_px)
		mat.set_shader_parameter("light_pos", _light_center)
		mat.set_shader_parameter("radius", _light_radius * (1.05 if r == _dark else 1.0))
		mat.set_shader_parameter("torches", packed)
		mat.set_shader_parameter("torch_count", mini(8, torches.size()))
	(_dark.material as ShaderMaterial).set_shader_parameter("view_size", size)


# ================================================================ Figuren

## Oberste belegte Zeile eines Bildes (für Krone, Balken, Zeichen darüber).
static var _tops := {}


static func sprite_top(name: String) -> int:
	if not _tops.has(name):
		var img := PixelArt.image(name)
		_tops[name] = img.get_used_rect().position.y / PixelArt.res(name) if img else 0
	return _tops[name]


## Schatten und Ring am Boden unter einer Figur.
func _ground(ci: CanvasItem, sx: float, sy: float, ring: Variant, outer: Variant = null) -> void:
	_spr(ci, "aufsatz/schatten", sx + 2 * px, sy + 22 * px)
	if ring != null:
		_spr(ci, "aufsatz/ring", sx, sy + 20 * px, null, false, _col(ring))
	if outer != null:
		_spr(ci, "aufsatz/ring_gross", sx - 4 * px, sy + 18 * px, null, false, _col(outer))


## Lebensbalken über einer Figur: 26 Kunstpixel breit, mit dunklem Rand.
func _hp_bar(ci: CanvasItem, sx: float, sy: float, top: int, frac: float, color: String) -> void:
	var f := clampf(frac, 0, 1)
	var y := maxi(-6, top - 7)
	_rect(ci, sx, sy, 2, y, 28, 6, Color(0.02, 0.02, 0.05, 0.9))
	var w := int(ceilf(26 * f))
	if w > 0:
		var c := _col(color)
		_rect(ci, sx, sy, 3, y + 1, w, 4, c)
		_rect(ci, sx, sy, 3, y + 1, w, 1, c.lightened(0.35))
		_rect(ci, sx, sy, 3, y + 4, w, 1, c.darkened(0.25))


## Winzige Ziffern (3 × 5) für Stufen.
const DIGITS := {
	"0": ["###", "#.#", "#.#", "#.#", "###"], "1": [".#.", "##.", ".#.", ".#.", "###"],
	"2": ["###", "..#", "###", "#..", "###"], "3": ["###", "..#", ".##", "..#", "###"],
	"4": ["#.#", "#.#", "###", "..#", "..#"], "5": ["###", "#..", "###", "..#", "###"],
	"6": ["###", "#..", "###", "#.#", "###"], "7": ["###", "..#", ".#.", ".#.", ".#."],
	"8": ["###", "#.#", "###", "#.#", "###"], "9": ["###", "#.#", "###", "..#", "###"],
	"?": ["##.", "..#", ".#.", "...", ".#."],
}


## Ziffern mit zwei Kunstpixeln je Punkt (auf der Karte gut lesbar).
func _digits(ci: CanvasItem, x: float, y: float, text: String, c: Color) -> void:
	var d := 2 * px
	for n in text.length():
		var g: Array = DIGITS.get(text[n], DIGITS["?"])
		for gy in 5:
			for gx in 3:
				if g[gy][gx] == "#":
					ci.draw_rect(Rect2(x + (n * 4 + gx) * d, y + gy * d, d, d), c)


## Stufenmarke unten links: dunkles Kästchen, Ziffern in der Farbe der Herausforderung.
func _level_pill(ci: CanvasItem, sx: float, sy: float, text: String, color: Variant) -> void:
	var w := text.length() * 8 + 2
	_rect(ci, sx, sy, -2, 20, w + 4, 14, Color(0.02, 0.02, 0.05, 0.92))
	_digits(ci, sx + 2 * px, sy + 22 * px, text, _col(_hex_or(color, "#a39a8c")))


## Kleines Schild unter einer Figur, z. B. „am Boden“.
func _tag(ci: CanvasItem, cx: float, y: float, text: String, color: String) -> void:
	var f := UiFonts.pixel(500)
	var fs := 20 if px < 2 else 30
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 12
	var h := fs + 4
	var r := Rect2(roundf(cx - w / 2), roundf(y), roundf(w), h)
	ci.draw_rect(r, Color(0.03, 0.035, 0.055, 0.88))
	ci.draw_rect(r, _col(_hex_or(color, "#ffffff"), 0.6), false, 2)
	ci.draw_string(f, Vector2(r.position.x + 6, r.position.y + fs * 0.82), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, _col(color))


func _draw_dynamic() -> void:
	if s.is_empty():
		return
	var t0 := Time.get_ticks_usec()
	_draw_dynamic_body()
	last_draw_ms = (Time.get_ticks_usec() - t0) / 1000.0 + last_static_ms
	last_static_ms = 0.0


func _draw_dynamic_body() -> void:
	var ci := _dyn
	var vis := visible_set
	var m: Dictionary = s.map
	var time: float = frame_anim.time
	var T := tile_px

	# --- Pfadvorschau
	if path is Array and not (path as Array).is_empty():
		var pl: Array = path
		for n in pl.size():
			var p = pl[n]
			var sx := _sx(p.x)
			var sy := _sy(p.y)
			var c := Color(1, 214 / 255.0, 90 / 255.0, maxf(0.3, 0.85 - n * 0.03))
			if n == pl.size() - 1:
				for q in [[10, 10, 12, 2], [10, 20, 12, 2], [10, 10, 2, 12], [20, 10, 2, 12]]:
					_rect(ci, sx, sy, q[0], q[1], q[2], q[3], c)
			else:
				_rect(ci, sx, sy, 14, 14, 4, 4, c)

	# --- Andere Crawler (nur sichtbare)
	for cr in J.arr(s, "crawlers"):
		if not cr.alive or not vis.has(MapGen.idx(m, cr.pos.x, cr.pos.y)):
			continue
		var p := _at(cr.uid, cr.pos)
		var sx := _sx(p.x)
		var sy := _sy(p.y)
		var party: bool = cr.get("party", false)
		_ground(ci, sx, sy, _col("#7fe0a0" if party else "#7cc4ff", 0.7))
		_figure(ci, cr.uid, "kreatur/mensch", sx, sy - 2 * px, "#4f9a6a" if party else "#4a7fb0", p.x > _at("p", s.player.pos).x, Color.WHITE, anim != null and anim.moving(cr.uid))
		if cr.hp < cr.maxHp:
			_hp_bar(ci, sx, sy, sprite_top("kreatur/mensch") - 2, float(cr.hp) / cr.maxHp, "#6ee07a")

	# --- Monster (nur sichtbare)
	var ppos := _at("p", s.player.pos)
	for mo in s.monsters:
		if not vis.has(MapGen.idx(m, mo.pos.x, mo.pos.y)):
			continue
		var p := _at(mo.uid, mo.pos)
		var sx := _sx(p.x)
		var sy := _sy(p.y)
		var boss: bool = mo.rank != "normal" and mo.rank != "elite"
		var elite: bool = mo.rank == "elite"
		var info := Identify.describe_monster(s, mo)
		var unknown: bool = info.insight >= 3
		var asleep: bool = mo.get("asleep", false)
		var ring: Color
		if mo.get("aware", false) and not asleep:
			ring = Color(1, 76 / 255.0, 60 / 255.0, 0.95 if fmod(time / 340.0, 2.0) < 1.0 else 0.55)
		else:
			ring = _col(_hex_or(info.challenge.color, "#a39a8c"), 0.75)
		_ground(ci, sx, sy, ring, Color("#ffcc33") if boss else (Color("#ff5a4a") if elite else null))
		var name := Sprites.sprite_name(mo.defId, mo.rank == "geist")
		# Größere Figuren (eigene Boss-Bilder) stehen mittig auf der Kachel und ragen nach oben
		var sz := PixelArt.size_of(name)
		var gx := (sz.x - TILE) / 2
		var gy := sz.y - TILE
		# Wache Monster wippen um einen Kunstpixel
		var bob: float = 0.0 if asleep or fmod(time / 260.0 + mo.pos.x * 1.7, 2.0) < 1.0 else -px
		var mod := Color(1, 1, 1, 0.75 if mo.rank == "geist" else 1.0)
		if asleep:
			mod = Color(0.8, 0.8, 0.9, mod.a)
		_figure(ci, mo.uid, name, sx - gx * px, sy - (gy + 2) * px + bob, mo.color, p.x > ppos.x, mod, false, not asleep)
		var top := sprite_top(name) - 2 - gy
		var crown_h := PixelArt.size_of("aufsatz/krone").y
		if boss and not name.begins_with("boss/"):
			_spr(ci, "aufsatz/krone", sx + (TILE - PixelArt.size_of("aufsatz/krone").x) / 2 * px, sy + (top - crown_h) * px + bob)
		if unknown:
			_spr(ci, "aufsatz/frage", sx + 20 * px, sy + (top - 6) * px)
		# Brennende Gegner flackern
		if _cond_turns(mo, "brennen") > 0:
			var fl := 0.5 + 0.4 * sin(time / 70.0 + mo.pos.x)
			_spr(ci, "aufsatz/ring_gross", sx - 4 * px, sy + 18 * px, null, false, Color(1, 0.55, 0.15, fl))
		if mo.hp < mo.maxHp and info.showHealthBar:
			_hp_bar(ci, sx, sy, top - (crown_h + 1 if boss and not name.begins_with("boss/") else 0), float(mo.hp) / mo.maxHp, "#ff5a4a")
		_level_pill(ci, sx, sy, J.s(mo.level) if info.insight <= 1 else "?", info.challenge.color)
		# Zustände als kleine farbige Quadrate oben rechts
		var conds := Conditions.condition_list(mo)
		for n in conds.size():
			var cx := 24 - n * 8
			_rect(ci, sx, sy, cx, top, 8, 8, Color(0.02, 0.02, 0.05, 0.9))
			_rect(ci, sx, sy, cx + 2, top + 2, 4, 4, _col(conds[n].color))
		if asleep:
			var zb := 2 * px if fmod(time / 500.0, 2.0) < 1.0 else 0
			_spr(ci, "aufsatz/schlaf", sx + 22 * px, sy + (top - 12) * px - zb)
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
				_tag(ci, sx + T / 2, sy + T + px, label[0], label[1])
		if mo.get("bounty") and (asleep or not (J.num(mo, "downed") > 0 or _cond_turns(mo, "furcht") > 0 or _cond_turns(mo, "blind") > 0 or mo.get("fleeing", false))):
			_tag(ci, sx + T / 2, sy + T + px, "Kopfgeld", "#ffd700")

	# --- Besiegte zerfallen in Pixel
	for b in frame_anim.get("bursts", []):
		if vis.has(MapGen.idx(m, int(b.at.x), int(b.at.y))):
			_draw_burst(ci, b)

	# --- Haustier
	var pet = s.player.get("pet")
	if pet != null and pet.alive:
		var p := _at("pet", pet.pos)
		var sx := _sx(p.x)
		var sy := _sy(p.y)
		_ground(ci, sx, sy, _col("#ffb3e6", 0.7))
		var look := Sprites.pet_sprite(String(pet.get("species", "")))
		_figure(ci, "pet", look[0], sx, sy - 2 * px, look[1], p.x > ppos.x, Color.WHITE, anim != null and anim.moving("pet"))
		if pet.hp < pet.maxHp:
			_hp_bar(ci, sx, sy, sprite_top(look[0]) - 2, float(pet.hp) / pet.maxHp, "#ff8ad8")

	# --- Spieler
	_draw_player(ci, _sx(ppos.x), _sy(ppos.y), time)
	for e in frame_anim.get("fx", []):
		_draw_fx(ci, e)
	for k in frame_anim.get("sparkles", []):
		_draw_sparkles(ci, _sx(ppos.x), _sy(ppos.y), k)


## Ein besiegtes Monster: erst weiß, dann fliegen seine Pixel auseinander und fallen.
func _draw_burst(ci: CanvasItem, b: Dictionary) -> void:
	var name := Sprites.sprite_name(String(b.defId), b.rank == "geist")
	var sz := PixelArt.size_of(name)
	var sx := _sx(b.at.x) - (sz.x - TILE) / 2 * px
	var sy := _sy(b.at.y) - (sz.y - TILE + 2) * px
	var k: float = b.k
	var r := PixelArt.res(name)
	if k < 0.1:
		PixelArt.draw_texture(ci, PixelArt.silhouette(name), Vector2(sx, sy), px, false, Color.WHITE, r)
		return
	var t := (k - 0.1) / 0.9
	var alpha := 1.0 - t * t
	var pix := PixelArt.pixels(name, b.color)
	for i in pix.size():
		var qi: Vector2i = pix[i][0]
		var c: Color = pix[i][1]
		var h := Tiles.hash(qi.x, qi.y, 77)
		# Feine Figuren: Bildpixel in Kunstpixeln (halbe Größe)
		var q := Vector2(qi) / r
		var dx := (q.x - sz.x / 2.0 + 0.5) * (0.5 + h) * t * 1.4
		var dy := (q.y - sz.y * 0.56) * (0.3 + h * 0.5) * t + 20.0 * t * t
		var ps := float(px) / r
		ci.draw_rect(Rect2(sx + roundf((q.x + dx) * r) * ps, sy + roundf((q.y + dy) * r) * ps, ps, ps), Color(c, c.a * alpha))


## Bildfolgen aus dem Tiny-Swords-Pack: Bildgröße und Anzahl je Effekt.
const FX := {
	"staub": {"tex": "dust_01", "size": 64, "frames": 8, "scale": 1.0},
	"explosion": {"tex": "explosion_01", "size": 192, "frames": 8, "scale": 1.0},
	"feuer": {"tex": "fire_01", "size": 64, "frames": 8, "scale": 1.0},
}
static var _fx_tex := {}


func _draw_fx(ci: CanvasItem, e: Dictionary) -> void:
	var d: Dictionary = FX.get(e.kind, {})
	if d.is_empty():
		return
	if not _fx_tex.has(d.tex):
		_fx_tex[d.tex] = load("res://assets/tinyswords/fx/%s.png" % d.tex)
	var tex: Texture2D = _fx_tex[d.tex]
	var n: int = mini(int(e.k * d.frames), d.frames - 1)
	# Im Pack ist eine Kachel 64 Pixel groß
	var sz: float = d.size * tile_px / 64.0 * d.scale
	var cx := _sx(e.at.x) + tile_px / 2.0
	var cy := _sy(e.at.y) + tile_px / 2.0
	ci.draw_texture_rect_region(tex, Rect2(cx - sz / 2, cy - sz / 2, sz, sz), Rect2(n * d.size, 0, d.size, d.size))


## Stufenaufstieg: goldene Funken steigen in Säulen um die Spielfigur auf.
func _draw_sparkles(ci: CanvasItem, sx: float, sy: float, k: float) -> void:
	var gold := [Color("#fee761"), Color("#feae34"), Color("#ffffff")]
	var alpha := 1.0 if k < 0.7 else 1.0 - (k - 0.7) / 0.3
	if k < 0.15:
		_spr(ci, "aufsatz/ring_gross", sx - 4 * px, sy + 18 * px, null, false, Color(1, 0.9, 0.4, 1.0 - k / 0.15))
	var d := 2 * px
	for i in 18:
		var h := Tiles.hash(i, 3, 91)
		var x := -6 + int(h * 44)
		var start := Tiles.hash(i, 5, 92) * 0.4
		var t := clampf((k - start) / 0.6, 0.0, 1.0)
		if t <= 0.0 or t >= 1.0:
			continue
		var y := 28 - int(t * (36 + h * 16))
		var c: Color = gold[i % 3]
		ci.draw_rect(Rect2(sx + x * px, sy + y * px, d, d), Color(c, alpha))
		if i % 3 == 0:
			ci.draw_rect(Rect2(sx + x * px, sy + y * px + d, d, d), Color(c, alpha * 0.4))


func _draw_player(ci: CanvasItem, sx: float, sy: float, time: float) -> void:
	var p: Dictionary = s.player
	var T := tile_px
	_glow(ci, sx + T / 2, sy + T / 2, "#ffd66e", 0.5)
	var dir = p.get("lastMoveDir")
	var flip: bool = dir != null and dir.x < 0
	var mount = p.get("mount")
	var riding: bool = p.get("riding", false) and mount != null and not mount.get("down", false)
	var mount_name := ""
	var vehicle := false
	if riding:
		mount_name = "reittier/" + String(mount.get("id", mount.get("defId", "kellerpony")))
		if not PixelArt.has(mount_name):
			mount_name = "reittier/kellerpony"
		vehicle = mount_name in ["reittier/einkaufswagen", "reittier/rasentraktor", "reittier/bobbycar"]
	_ground(ci, sx, sy, Color(1, 214 / 255.0, 90 / 255.0, 0.95))
	var bob: float = 0.0 if fmod(time / 600.0, 2.0) < 1.0 else -px
	if riding and not vehicle:
		_spr(ci, mount_name, sx, sy, null, flip)
	var lift := (10 if riding and not vehicle else (6 if riding else 2)) * px
	var walking: bool = anim != null and anim.player_moving(frame_anim.get("now", -1.0)) > 0
	# Mittig auf der Kachel, Füße wie bei den anderen Figuren
	var hero := Sprites.hero_name(p)
	var hsz := PixelArt.size_of(hero)
	var hx := (hsz.x - TILE) / 2
	var hy := hsz.y - TILE
	_figure(ci, "p", hero, sx - hx * px, sy - hy * px - lift + (0.0 if walking else bob), null, flip, Color.WHITE, walking)
	if riding and vehicle:
		_spr(ci, mount_name, sx, sy, null, flip)
	# Zustände des Crawlers als farbige Ringe
	var has_buff := func(n: String) -> bool:
		for b in p.buffs:
			if b.name == n:
				return true
		return false
	var rings: Array = []
	for pair in [["Vergiftet", "#9be04a"], ["Blutung", "#e0434a"], ["Brennen", "#ff8a2a"], ["Furcht", "#b38cff"], ["Geblendet", "#d9d9d9"]]:
		if has_buff.call(pair[0]):
			rings.append(pair[1])
	for n in rings.size():
		var a := 0.6 + 0.35 * sin(time / 150.0 + n)
		_spr(ci, "aufsatz/ring_gross", sx - 4 * px, sy + (18 - n * 4) * px, null, false, _col(rings[n], a))


# ================================================================ Oben

const PROJECTILE_COLORS := {"stein": "#c8c0b0", "pfeil": "#e0d0a0", "magie": "#c080ff", "feuer": "#ff8a2a", "schleim": "#8ce04a", "bombe": "#555555", "blitz": "#9fdcff"}


## Geschosse, Zahlen, Maus, Auswahl.
func _draw_top() -> void:
	if s.is_empty():
		return
	var ci := _top
	var T := tile_px
	for pr in frame_anim.get("projectiles", []):
		_draw_projectile(ci, pr)
	var font := UiFonts.pixel(700)
	var fs := 20 if px < 2 else 30
	for f in frame_anim.get("floaters", []):
		var text: String = f.text
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var pos := Vector2(roundf(_sx(f.x) + T / 2 - w / 2), roundf(_sy(f.y) + fs * 0.35))
		var c := _col(f.color, f.alpha)
		ci.draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(0, 0, 0, 0.9 * f.alpha))
		ci.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)
	if hover != null:
		var hx := _sx(hover.x)
		var hy := _sy(hover.y)
		var c := Color(1, 214 / 255.0, 90 / 255.0, 0.9)
		ci.draw_rect(Rect2(hx, hy, T, T), Color(1, 214 / 255.0, 90 / 255.0, 0.08))
		# Ecken als Pixelwinkel
		for q in [[0, 0, 8, 2], [0, 0, 2, 8], [24, 0, 8, 2], [30, 0, 2, 8], [0, 30, 8, 2], [0, 24, 2, 8], [24, 30, 8, 2], [30, 24, 2, 8]]:
			_rect(ci, hx, hy, q[0], q[1], q[2], q[3], c)
	if selected != null:
		var qx := _sx(selected.x)
		var qy := _sy(selected.y)
		var c := Color(140 / 255.0, 200 / 255.0, 1, 0.95)
		for q in [[-2, -2, 10, 2], [-2, -2, 2, 10], [24, -2, 10, 2], [32, -2, 2, 10], [-2, 32, 10, 2], [-2, 24, 2, 10], [24, 32, 10, 2], [32, 24, 2, 10]]:
			_rect(ci, qx, qy, q[0], q[1], q[2], q[3], c)


func _draw_projectile(ci: CanvasItem, pr: Dictionary) -> void:
	var T := tile_px
	var style: String = pr.style
	var color := _col(PROJECTILE_COLORS.get(style, "#c8c0b0"))
	var cx := _sx(pr.x) + T / 2
	var cy := _sy(pr.y) + T / 2
	# Schweif als einzelne Pixel
	var trail: Array = pr.trail
	for n in trail.size():
		var tp: Vector2 = trail[n]
		var a := (n + 1.0) / trail.size() * 0.5
		ci.draw_rect(Rect2(_sx(tp.x) + T / 2 - 2 * px, _sy(tp.y) + T / 2 - 2 * px, px * 4, px * 4), Color(color, a))
	if style == "pfeil":
		# Pfeil als Pixellinie in Flugrichtung, zwei Pixel stark
		var d := Vector2(cos(pr.angle), sin(pr.angle))
		for i in range(-10, 11):
			var q := Vector2(roundf(d.x * i), roundf(d.y * i))
			var c := Color("#e8e8e8") if i >= 7 else (Color("#c05040") if i <= -7 else color)
			ci.draw_rect(Rect2(cx + q.x * px, cy + q.y * px, px * 2, px * 2), c)
		return
	var name := "geschoss/" + style
	if not PixelArt.has(name):
		name = "geschoss/stein"
	var sz := PixelArt.size_of(name)
	if style in ["magie", "feuer", "blitz"]:
		_glow(ci, cx, cy, color, 0.6, false)
	_spr(ci, name, cx - sz.x * px / 2.0, cy - sz.y * px / 2.0)
