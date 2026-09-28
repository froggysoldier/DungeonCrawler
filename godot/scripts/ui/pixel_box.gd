class_name PixelBox
extends StyleBox
## Rahmen im Pixel-Stil: abgestufte Ecken, harter Schlagschatten, heller
## Innenrand oben und dunkler unten. Ein Kunstpixel ist `unit` Bildschirmpixel.
## Die Eigenschaften heißen wie bei StyleBoxFlat, damit sich die Stile gleich
## schreiben lassen.
## Alle Felder sind exportiert, sonst übernimmt duplicate() sie nicht.

## Einrückung je Zeile einer Ecke, nach Stufe (0 = eckig, 3 = fast rund).
const CORNERS := {0: [], 1: [1], 2: [2, 1], 3: [3, 1, 1]}

@export var unit := 2
@export var bg_color := Color(0, 0, 0, 0)
@export var border_color := Color(0, 0, 0, 0)
@export var border_width_left := 0
@export var border_width_top := 0
@export var border_width_right := 0
@export var border_width_bottom := 0
## Eckenstufe 0 bis 3.
@export var corner := 1
## Stärke des hellen und dunklen Innenrands (0 = aus).
@export var bevel := 0.0
@export var shadow_color := Color(0, 0, 0, 0)
@export var shadow_size := 0
@export var shadow_offset := Vector2.ZERO


func set_border_width_all(w: int) -> void:
	border_width_left = w
	border_width_top = w
	border_width_right = w
	border_width_bottom = w


## Stufe aus einem Rundungsradius wie bei StyleBoxFlat.
func set_corner_radius_all(radius: int) -> void:
	corner = 0 if radius <= 0 else (1 if radius <= 8 else (2 if radius <= 16 else 3))


func _insets() -> Array:
	return CORNERS.get(clampi(corner, 0, 3), [])


## Fläche mit abgestuften Ecken als Rechtecke.
func _shape(ci: RID, r: Rect2i, c: Color) -> void:
	if c.a <= 0.0 or r.size.x <= 0 or r.size.y <= 0:
		return
	var ins := _insets()
	var u := unit
	var n := mini(ins.size(), r.size.y / (2 * u))
	for i in n:
		var dx: int = mini(ins[i] * u, r.size.x / 2)
		RenderingServer.canvas_item_add_rect(ci, Rect2(r.position.x + dx, r.position.y + i * u, r.size.x - 2 * dx, u), c)
		RenderingServer.canvas_item_add_rect(ci, Rect2(r.position.x + dx, r.end.y - (i + 1) * u, r.size.x - 2 * dx, u), c)
	RenderingServer.canvas_item_add_rect(ci, Rect2(r.position.x, r.position.y + n * u, r.size.x, r.size.y - 2 * n * u), c)


## Waagerechte Ausdehnung der Form in der Zeile y (Bildschirmpixel), leer = (0, 0).
func _span(r: Rect2i, y: int) -> Vector2i:
	if r.size.x <= 0 or y < r.position.y or y >= r.end.y:
		return Vector2i.ZERO
	var ins := _insets()
	var n := mini(ins.size(), r.size.y / (2 * unit))
	var row_top := (y - r.position.y) / unit
	var row_bot := (r.end.y - 1 - y) / unit
	var dx := 0
	if row_top < n:
		dx = ins[row_top] * unit
	elif row_bot < n:
		dx = ins[row_bot] * unit
	dx = mini(dx, r.size.x / 2)
	return Vector2i(r.position.x + dx, r.end.x - dx)


## Stücke des Rings in Zeile y: Außenform ohne Innenform.
func _pieces(outer: Rect2i, inner: Rect2i, y: int) -> Array:
	var o := _span(outer, y)
	if o == Vector2i.ZERO:
		return []
	var i := _span(inner, y)
	if i == Vector2i.ZERO:
		return [o]
	var out: Array = []
	if i.x > o.x:
		out.append(Vector2i(o.x, i.x))
	if o.y > i.y:
		out.append(Vector2i(i.y, o.y))
	return out


static func _flush(ci: RID, pieces: Array, y0: int, y1: int, c: Color) -> void:
	for p in pieces:
		RenderingServer.canvas_item_add_rect(ci, Rect2(p.x, y0, p.y - p.x, y1 - y0), c)


## Rahmen als Ring (Außenform ohne Innenform), damit durchscheinende Flächen
## sauber bleiben. Zeilenweise nur oben und unten, dazwischen zwei Leisten.
func _ring(ci: RID, outer: Rect2i, inner: Rect2i, c: Color) -> void:
	if inner.size.x <= 0 or inner.size.y <= 0:
		_shape(ci, outer, c)
		return
	var n := mini(_insets().size(), outer.size.y / (2 * unit))
	var ni := mini(_insets().size(), inner.size.y / (2 * unit))
	var top_end := mini(outer.end.y, maxi(outer.position.y + n * unit, inner.position.y + ni * unit))
	var bot_start := maxi(top_end, mini(outer.end.y - n * unit, inner.end.y - ni * unit))
	for z in [[outer.position.y, top_end], [bot_start, outer.end.y]]:
		if z[1] <= z[0]:
			continue
		var run_y: int = z[0]
		var run := _pieces(outer, inner, run_y)
		for y in range(z[0] + 1, z[1]):
			var p := _pieces(outer, inner, y)
			if p != run:
				_flush(ci, run, run_y, y, c)
				run_y = y
				run = p
		_flush(ci, run, run_y, z[1], c)
	if bot_start > top_end:
		_flush(ci, _pieces(outer, inner, top_end), top_end, bot_start, c)


func _draw(ci: RID, rect: Rect2) -> void:
	var r := Rect2i(Vector2i(roundi(rect.position.x), roundi(rect.position.y)), Vector2i(roundi(rect.size.x), roundi(rect.size.y)))
	if r.size.x <= 0 or r.size.y <= 0:
		return
	# Harter Schatten: um ganze Kunstpixel versetzt
	if shadow_color.a > 0.0 and shadow_size > 0:
		var off := maxi(unit, roundi(maxf(shadow_offset.y, shadow_size / 4.0) / unit) * unit)
		_shape(ci, Rect2i(r.position + Vector2i(0, off), r.size), Color(shadow_color, minf(0.85, shadow_color.a * 1.2)))
	var inner := r
	var has_border := border_color.a > 0.0 and (border_width_left + border_width_top + border_width_right + border_width_bottom) > 0
	if has_border:
		inner = Rect2i(r.position + Vector2i(border_width_left, border_width_top), r.size - Vector2i(border_width_left + border_width_right, border_width_top + border_width_bottom))
	_shape(ci, inner, bg_color)
	if has_border:
		_ring(ci, r, inner, border_color)
	if bevel > 0.0 and bg_color.a > 0.0 and inner.size.y >= 3 * unit:
		var ins := _insets()
		var dx: int = (ins[0] * unit) if not ins.is_empty() else 0
		RenderingServer.canvas_item_add_rect(ci, Rect2(inner.position.x + dx, inner.position.y, inner.size.x - 2 * dx, unit), Color(bg_color.lightened(bevel), bg_color.a))
		RenderingServer.canvas_item_add_rect(ci, Rect2(inner.position.x + dx, inner.end.y - unit, inner.size.x - 2 * dx, unit), Color(bg_color.darkened(bevel * 1.6), bg_color.a))


func duplicate_box() -> PixelBox:
	return duplicate()
