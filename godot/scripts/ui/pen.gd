class_name Pen
extends RefCounted
## Nachbildung der Canvas-2D-Schnittstelle des Browsers auf einem CanvasItem.
## Damit lassen sich prozedurale Zeichnungen (Karte, Kreaturen, Gegenstände)
## wie auf einem Canvas beschreiben: Pfade mit Kurven,
## Füllen und Konturen, Transformationen, Deckkraft und Farbverläufe.
##
## Nur innerhalb von _draw() des CanvasItems benutzen.


## Farbverlauf wie CanvasGradient (linear oder radial).
class Grad:
	var radial := false
	var x0 := 0.0
	var y0 := 0.0
	var r0 := 0.0
	var x1 := 0.0
	var y1 := 0.0
	var r1 := 0.0
	var stops: Array = []

	func add(offset: float, color: Variant) -> void:
		stops.append([clampf(offset, 0.0, 1.0), Pen.css(color)])


var ci: CanvasItem
var xf := Transform2D.IDENTITY
var alpha := 1.0
var fill_style: Variant = Color.BLACK
var stroke_style: Variant = Color.BLACK
var line_width := 1.0
var line_cap := "butt"
var line_join := "miter"
var dash: Array = []
var font_size := 10.0
var font_weight := 400
var italic := false
var text_align := "left"
var text_baseline := "alphabetic"
## Weiche Kanten an gefüllten Flächen.
var aa := true

var _stack: Array = []
var _subs: Array = []
var _pts := PackedVector2Array()
var _closed := false

static var _colors: Dictionary = {}
static var _grad_tex: Dictionary = {}


func _init(item: CanvasItem) -> void:
	ci = item


# ---------------------------------------------------------------- Farben

## CSS-Farbe ('#rgb', '#rrggbb', 'rgb(...)', 'rgba(...)') oder Color.
static func css(v: Variant) -> Color:
	if v is Color:
		return v
	var key: String = v
	var c = _colors.get(key)
	if c != null:
		return c
	var out := Color.BLACK
	var t := key.strip_edges()
	if t.begins_with("#"):
		var h := t.substr(1)
		if h.length() == 3:
			h = h[0] + h[0] + h[1] + h[1] + h[2] + h[2]
		out = Color.html("#" + h)
	elif t.begins_with("rgb"):
		var inner := t.substr(t.find("(") + 1, t.rfind(")") - t.find("(") - 1)
		var parts := inner.split(",")
		var r := float(parts[0]) / 255.0
		var g := float(parts[1]) / 255.0
		var b := float(parts[2]) / 255.0
		var a := float(parts[3]) if parts.size() > 3 else 1.0
		out = Color(r, g, b, a)
	elif t == "transparent":
		out = Color(0, 0, 0, 0)
	elif t == "white":
		out = Color.WHITE
	if _colors.size() > 4000:
		_colors.clear()
	_colors[key] = out
	return out


## rgba mit Deckkraft aus einer Hex-Farbe.
static func rgba(hex: Variant, a: float) -> Color:
	var c := css(hex)
	return Color(c.r, c.g, c.b, a)


## Farbe aufhellen oder abdunkeln (Faktor, gerundet auf 0–255).
static func shade(hex: Variant, f: float) -> Color:
	var c := css(hex)
	return Color(
		clampi(J.rnd(c.r8 * f), 0, 255) / 255.0,
		clampi(J.rnd(c.g8 * f), 0, 255) / 255.0,
		clampi(J.rnd(c.b8 * f), 0, 255) / 255.0)


# ---------------------------------------------------------------- Zustand

func save() -> void:
	_stack.append([xf, alpha, fill_style, stroke_style, line_width, line_cap, line_join, dash, font_size, font_weight, italic, text_align, text_baseline])


func restore() -> void:
	if _stack.is_empty():
		return
	var st: Array = _stack.pop_back()
	xf = st[0]
	alpha = st[1]
	fill_style = st[2]
	stroke_style = st[3]
	line_width = st[4]
	line_cap = st[5]
	line_join = st[6]
	dash = st[7]
	font_size = st[8]
	font_weight = st[9]
	italic = st[10]
	text_align = st[11]
	text_baseline = st[12]


func translate(x: float, y: float) -> void:
	xf = xf * Transform2D(0.0, Vector2(x, y))


func scale(sx: float, sy: float) -> void:
	xf = xf * Transform2D(Vector2(sx, 0), Vector2(0, sy), Vector2.ZERO)


func rotate(a: float) -> void:
	xf = xf * Transform2D(a, Vector2.ZERO)


func set_transform(t: Transform2D) -> void:
	xf = t


func font(size: float, weight: int = 400, is_italic: bool = false) -> void:
	font_size = size
	font_weight = weight
	italic = is_italic


func _scale_len() -> float:
	return sqrt(absf(xf.determinant()))


# ---------------------------------------------------------------- Pfade

func begin_path() -> void:
	_subs.clear()
	_pts = PackedVector2Array()
	_closed = false


func _flush() -> void:
	if _pts.size() > 0:
		_subs.append([_pts, _closed])
	_pts = PackedVector2Array()
	_closed = false


func move_to(x: float, y: float) -> void:
	_flush()
	_pts.append(xf * Vector2(x, y))


func line_to(x: float, y: float) -> void:
	if _pts.is_empty():
		move_to(x, y)
		return
	_pts.append(xf * Vector2(x, y))


func close_path() -> void:
	if _pts.is_empty():
		return
	var first := _pts[0]
	_closed = true
	_flush()
	_pts.append(first)


func _last_local() -> Vector2:
	if _pts.is_empty():
		return Vector2.ZERO
	return xf.affine_inverse() * _pts[_pts.size() - 1]


func _segments(len_local: float) -> int:
	return clampi(ceili(len_local * _scale_len() / 3.0), 4, 48)


func quadratic_curve_to(cpx: float, cpy: float, x: float, y: float) -> void:
	if _pts.is_empty():
		move_to(cpx, cpy)
	var p0 := _last_local()
	var c := Vector2(cpx, cpy)
	var p1 := Vector2(x, y)
	var n := _segments(p0.distance_to(c) + c.distance_to(p1))
	for i in range(1, n + 1):
		var t := float(i) / n
		var u := 1.0 - t
		_pts.append(xf * (p0 * (u * u) + c * (2.0 * u * t) + p1 * (t * t)))


func bezier_curve_to(c1x: float, c1y: float, c2x: float, c2y: float, x: float, y: float) -> void:
	if _pts.is_empty():
		move_to(c1x, c1y)
	var p0 := _last_local()
	var c1 := Vector2(c1x, c1y)
	var c2 := Vector2(c2x, c2y)
	var p1 := Vector2(x, y)
	var n := _segments(p0.distance_to(c1) + c1.distance_to(c2) + c2.distance_to(p1))
	for i in range(1, n + 1):
		var t := float(i) / n
		var u := 1.0 - t
		_pts.append(xf * (p0 * (u * u * u) + c1 * (3.0 * u * u * t) + c2 * (3.0 * u * t * t) + p1 * (t * t * t)))


func arc(x: float, y: float, r: float, a0: float, a1: float, ccw: bool = false) -> void:
	ellipse(x, y, r, r, 0.0, a0, a1, ccw)


func ellipse(x: float, y: float, rx: float, ry: float, rot: float, a0: float, a1: float, ccw: bool = false) -> void:
	var sweep := a1 - a0
	if not ccw:
		if sweep >= TAU:
			sweep = TAU
		else:
			sweep = fposmod(sweep, TAU)
	else:
		if -sweep >= TAU:
			sweep = -TAU
		else:
			sweep = -fposmod(-sweep, TAU)
	var n := clampi(ceili(absf(sweep) / TAU * clampf(maxf(rx, ry) * _scale_len() * 1.3, 10.0, 72.0)), 3, 72)
	var cr := cos(rot)
	var sr := sin(rot)
	# Volle Kreise als eigener Teilpfad: die Verbindungslinie des Browsers hat
	# keine Fläche, würde hier aber die Zerlegung in Dreiecke stören.
	if absf(sweep) >= TAU and _pts.size() > 1:
		_flush()
	for i in range(n + 1):
		var a := a0 + sweep * float(i) / n
		var ex := rx * cos(a)
		var ey := ry * sin(a)
		var p := Vector2(x + ex * cr - ey * sr, y + ex * sr + ey * cr)
		var d := xf * p
		if i == 0 and _pts.size() > 0 and _pts[_pts.size() - 1].distance_squared_to(d) < 1e-6:
			continue
		_pts.append(d)


func rect(x: float, y: float, w: float, h: float) -> void:
	move_to(x, y)
	line_to(x + w, y)
	line_to(x + w, y + h)
	line_to(x, y + h)
	close_path()


## roundRect(x, y, w, h, radien): Radius als Zahl oder [oben links, oben rechts, unten rechts, unten links].
func round_rect(x: float, y: float, w: float, h: float, radii: Variant) -> void:
	var r: Array = []
	if radii is Array:
		var a: Array = radii
		match a.size():
			1: r = [a[0], a[0], a[0], a[0]]
			2: r = [a[0], a[1], a[0], a[1]]
			3: r = [a[0], a[1], a[2], a[1]]
			_: r = [a[0], a[1], a[2], a[3]]
	else:
		r = [radii, radii, radii, radii]
	if w < 0:
		x += w
		w = -w
	if h < 0:
		y += h
		h = -h
	# Zu große Radien verkleinern (wie im Browser)
	var f := 1.0
	var sums := [[r[0] + r[1], w], [r[2] + r[3], w], [r[0] + r[3], h], [r[1] + r[2], h]]
	for s in sums:
		if s[0] > 0 and s[1] / s[0] < f:
			f = s[1] / s[0]
	for i in 4:
		r[i] = float(r[i]) * f
	move_to(x + r[0], y)
	line_to(x + w - r[1], y)
	if r[1] > 0:
		ellipse(x + w - r[1], y + r[1], r[1], r[1], 0, -PI / 2, 0)
	line_to(x + w, y + h - r[2])
	if r[2] > 0:
		ellipse(x + w - r[2], y + h - r[2], r[2], r[2], 0, 0, PI / 2)
	line_to(x + r[3], y + h)
	if r[3] > 0:
		ellipse(x + r[3], y + h - r[3], r[3], r[3], 0, PI / 2, PI)
	line_to(x, y + r[0])
	if r[0] > 0:
		ellipse(x + r[0], y + r[0], r[0], r[0], 0, PI, PI * 1.5)
	close_path()


# ---------------------------------------------------------------- Füllen und Konturen

func fill() -> void:
	var subs := _all_subs()
	for sub in subs:
		var pts: PackedVector2Array = sub[0]
		if pts.size() >= 3:
			_fill_poly(pts, fill_style)


func stroke() -> void:
	var w := line_width * _scale_len()
	var col_style = stroke_style
	for sub in _all_subs():
		var pts: PackedVector2Array = sub[0]
		if pts.size() < 2:
			continue
		if sub[1]:
			pts = pts.duplicate()
			pts.append(pts[0])
		_stroke_poly(pts, col_style, w, sub[1])


func _all_subs() -> Array:
	var out := _subs.duplicate()
	if _pts.size() > 0:
		out.append([_pts, _closed])
	return out


func fill_rect(x: float, y: float, w: float, h: float) -> void:
	if fill_style is Grad or xf.x.y != 0.0 or xf.y.x != 0.0:
		var pts := PackedVector2Array([xf * Vector2(x, y), xf * Vector2(x + w, y), xf * Vector2(x + w, y + h), xf * Vector2(x, y + h)])
		_fill_poly(pts, fill_style)
		return
	var c := css(fill_style)
	c.a *= alpha
	if c.a <= 0.0:
		return
	var p0 := xf * Vector2(x, y)
	var p1 := xf * Vector2(x + w, y + h)
	ci.draw_rect(Rect2(p0, p1 - p0).abs(), c)


func stroke_rect(x: float, y: float, w: float, h: float) -> void:
	var keep_subs := _subs
	var keep_pts := _pts
	var keep_closed := _closed
	begin_path()
	rect(x, y, w, h)
	stroke()
	_subs = keep_subs
	_pts = keep_pts
	_closed = keep_closed


func draw_image(tex: Texture2D, x: float, y: float, w: float, h: float) -> void:
	if tex == null:
		return
	var p0 := xf * Vector2(x, y)
	var p1 := xf * Vector2(x + w, y + h)
	ci.draw_texture_rect(tex, Rect2(p0, p1 - p0), false, Color(1, 1, 1, alpha))


func _fill_poly(pts: PackedVector2Array, style: Variant) -> void:
	if pts.size() > 3 and pts[0].distance_squared_to(pts[pts.size() - 1]) < 1e-6:
		pts = pts.slice(0, pts.size() - 1)
	var idx := Geometry2D.triangulate_polygon(pts)
	if idx.is_empty():
		# Selbstüberschneidende Pfade: in konvexe Teile zerlegen, sonst weglassen
		var parts := Geometry2D.decompose_polygon_in_convex(pts)
		for part in parts:
			if part.size() >= 3:
				_fill_poly(part, style)
		return
	if style is Grad:
		_fill_grad(pts, idx, style)
		return
	var c := css(style)
	c.a *= alpha
	if c.a <= 0.0:
		return
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), idx, pts, PackedColorArray([c]))
	# Weiche Kante (2D-MSAA gibt es im Kompatibilitäts-Renderer nicht)
	if c.a >= 0.9 and aa:
		var ring := pts.duplicate()
		ring.append(pts[0])
		ci.draw_polyline(ring, c, 1.0, true)


func _fill_grad(pts: PackedVector2Array, idx: PackedInt32Array, g: Grad) -> void:
	if g.stops.is_empty():
		return
	# Gemeinsame Deckkraft herausziehen: pulsierende Verläufe teilen sich eine Textur
	var amax := 0.0
	for st in g.stops:
		amax = maxf(amax, (st[1] as Color).a)
	if amax <= 0.0:
		return
	var tex: Texture2D
	var uvs := PackedVector2Array()
	uvs.resize(pts.size())
	if not g.radial:
		var p0 := xf * Vector2(g.x0, g.y0)
		var p1 := xf * Vector2(g.x1, g.y1)
		var d := p1 - p0
		var dd := d.length_squared()
		for i in pts.size():
			var t := 0.0 if dd == 0.0 else (pts[i] - p0).dot(d) / dd
			uvs[i] = Vector2(t, 0.5)
		tex = _gradient_texture(g.stops, amax, false, 0.0)
	else:
		var c := xf * Vector2(g.x1, g.y1)
		var r1 := g.r1 * _scale_len()
		if r1 <= 0.0:
			return
		for i in pts.size():
			uvs[i] = (pts[i] - c) / (2.0 * r1) + Vector2(0.5, 0.5)
		tex = _gradient_texture(g.stops, amax, true, g.r0 / g.r1 if g.r1 > 0 else 0.0)
	var mod := Color(1, 1, 1, amax * alpha)
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), idx, pts, PackedColorArray([mod]), uvs, PackedInt32Array(), PackedFloat32Array(), tex.get_rid())
	if amax * alpha >= 0.9 and aa and pts.size() > 4:
		var ring := pts.duplicate()
		ring.append(pts[0])
		var cols := PackedColorArray()
		cols.resize(ring.size())
		for i in ring.size():
			var col: Color
			if not g.radial:
				col = sample_stops(g.stops, clampf(uvs[i % pts.size()].x, 0.0, 1.0))
			else:
				var rel: float = (uvs[i % pts.size()] - Vector2(0.5, 0.5)).length() * 2.0
				var inner := g.r0 / g.r1 if g.r1 > 0 else 0.0
				col = sample_stops(g.stops, clampf((rel - inner) / maxf(1e-6, 1.0 - inner), 0.0, 1.0))
			col.a *= alpha
			cols[i] = col
		ci.draw_polyline_colors(ring, cols, 1.0, true)


## Farbe im Verlauf bei t (wie der Browser: vormultipliziert interpoliert).
static func sample_stops(stops: Array, t: float) -> Color:
	if t <= stops[0][0]:
		return stops[0][1]
	var last: Array = stops[stops.size() - 1]
	if t >= last[0]:
		return last[1]
	for i in range(stops.size() - 1):
		var a: Array = stops[i]
		var b: Array = stops[i + 1]
		if t >= a[0] and t <= b[0]:
			var span: float = b[0] - a[0]
			var k: float = 0.0 if span <= 0.0 else (t - a[0]) / span
			var ca: Color = a[1]
			var cb: Color = b[1]
			var al := lerpf(ca.a, cb.a, k)
			if al <= 0.0:
				return Color(0, 0, 0, 0)
			var r := lerpf(ca.r * ca.a, cb.r * cb.a, k) / al
			var gg := lerpf(ca.g * ca.a, cb.g * cb.a, k) / al
			var bb := lerpf(ca.b * ca.a, cb.b * cb.a, k) / al
			return Color(r, gg, bb, al)
	return last[1]


static func _gradient_texture(stops: Array, amax: float, radial: bool, inner: float) -> Texture2D:
	var norm: Array = []
	var key := ("r%.3f|" % inner) if radial else "l|"
	for st in stops:
		var c: Color = st[1]
		var nc := Color(c.r, c.g, c.b, c.a / amax)
		norm.append([st[0], nc])
		key += "%.3f:%s;" % [st[0], nc.to_html()]
	var tex = _grad_tex.get(key)
	if tex != null:
		return tex
	var img: Image
	if not radial:
		img = Image.create(256, 1, false, Image.FORMAT_RGBA8)
		for x in 256:
			img.set_pixel(x, 0, sample_stops(norm, (x + 0.5) / 256.0))
	else:
		const N := 96
		img = Image.create(N, N, false, Image.FORMAT_RGBA8)
		var line := PackedColorArray()
		line.resize(N)
		for y in N:
			for x in N:
				var d := Vector2((x + 0.5) / N - 0.5, (y + 0.5) / N - 0.5).length() * 2.0
				var t := 0.0 if inner >= 1.0 else (d - inner) / (1.0 - inner)
				img.set_pixel(x, y, sample_stops(norm, t))
	tex = ImageTexture.create_from_image(img)
	if _grad_tex.size() > 600:
		_grad_tex.clear()
	_grad_tex[key] = tex
	return tex


func _stroke_poly(pts: PackedVector2Array, style: Variant, w: float, closed: bool) -> void:
	var c: Color
	if style is Grad:
		c = sample_stops(style.stops, 0.5)
	else:
		c = css(style)
	c.a *= alpha
	if c.a <= 0.0 or w <= 0.0:
		return
	if not dash.is_empty():
		_stroke_dashed(pts, c, w)
		return
	ci.draw_polyline(pts, c, maxf(w, 0.01), true)
	# Runde Ecken und Enden, wo es auffällt
	if w >= 2.2:
		var r := w * 0.5
		var n := pts.size()
		if line_join == "round":
			for i in range(1, n - 1):
				var a := (pts[i] - pts[i - 1]).normalized()
				var b := (pts[i + 1] - pts[i]).normalized()
				if a.dot(b) < 0.9:
					ci.draw_circle(pts[i], r, c, true, -1.0, true)
			if closed and n > 2:
				var a2 := (pts[n - 1] - pts[n - 2]).normalized()
				var b2 := (pts[1] - pts[0]).normalized()
				if a2.dot(b2) < 0.9:
					ci.draw_circle(pts[0], r, c, true, -1.0, true)
		if line_cap == "round" and not closed:
			ci.draw_circle(pts[0], r, c, true, -1.0, true)
			ci.draw_circle(pts[n - 1], r, c, true, -1.0, true)


func _stroke_dashed(pts: PackedVector2Array, c: Color, w: float) -> void:
	var k := _scale_len()
	var pattern: Array = []
	for d in dash:
		pattern.append(float(d) * k)
	if pattern.size() % 2 == 1:
		pattern.append_array(pattern.duplicate())
	var pi := 0
	var left: float = pattern[0]
	var on := true
	for i in range(pts.size() - 1):
		var a := pts[i]
		var b := pts[i + 1]
		var seg := a.distance_to(b)
		var pos := 0.0
		while pos < seg:
			var step := minf(left, seg - pos)
			if on:
				ci.draw_line(a.lerp(b, pos / seg), a.lerp(b, (pos + step) / seg), c, w, true)
			pos += step
			left -= step
			if left <= 0.0001:
				pi = (pi + 1) % pattern.size()
				left = pattern[pi]
				on = not on


# ---------------------------------------------------------------- Verläufe

func linear_gradient(x0: float, y0: float, x1: float, y1: float) -> Grad:
	var g := Grad.new()
	g.x0 = x0
	g.y0 = y0
	g.x1 = x1
	g.y1 = y1
	return g


func radial_gradient(x0: float, y0: float, r0: float, x1: float, y1: float, r1: float) -> Grad:
	var g := Grad.new()
	g.radial = true
	g.x0 = x0
	g.y0 = y0
	g.r0 = r0
	g.x1 = x1
	g.y1 = y1
	g.r1 = r1
	return g


# ---------------------------------------------------------------- Text

func measure_text(text: String) -> float:
	var f := UiFonts.get_font(font_weight, italic)
	return f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(1, roundi(font_size))).x


func _text_pos(text: String, x: float, y: float) -> Array:
	var k := _scale_len()
	var size := maxi(1, roundi(font_size * k))
	var f := UiFonts.get_font(font_weight, italic)
	var p := xf * Vector2(x, y)
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	if text_align == "center":
		p.x -= w / 2.0
	elif text_align == "right" or text_align == "end":
		p.x -= w
	if text_baseline == "middle":
		p.y += (f.get_ascent(size) - f.get_descent(size)) / 2.0
	elif text_baseline == "top":
		p.y += f.get_ascent(size)
	return [f, p, size]


func fill_text(text: String, x: float, y: float) -> void:
	var c := css(fill_style) if not (fill_style is Grad) else sample_stops(fill_style.stops, 0.5)
	c.a *= alpha
	var t := _text_pos(text, x, y)
	ci.draw_string(t[0], t[1], text, HORIZONTAL_ALIGNMENT_LEFT, -1, t[2], c)


func stroke_text(text: String, x: float, y: float) -> void:
	var c := css(stroke_style)
	c.a *= alpha
	var t := _text_pos(text, x, y)
	ci.draw_string_outline(t[0], t[1], text, HORIZONTAL_ALIGNMENT_LEFT, -1, t[2], maxi(1, roundi(line_width * _scale_len())), c)
