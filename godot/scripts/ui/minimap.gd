class_name Minimap
extends Control
## Kleine Übersichtskarte aller bekannten Felder: Räume nach Art eingefärbt,
## Treppe und Crawler hervorgehoben.

## Farben aus der Tiny-Swords-Palette (Sand, Fels, Wasser).
const ROOM_COLORS := {"safe": "#dcaa46", "guild": "#4697ac", "boss": "#b65555", "arena": "#b48355", "start": "#8c9a9d"}

var s: Dictionary


func _draw() -> void:
	if s.is_empty():
		return
	var m: Dictionary = s.map
	var w := size.x
	var h := size.y
	if w <= 0 or h <= 0:
		return
	var mw: int = m.width
	var mh: int = m.height
	var explored: Array = m.explored
	var tl: Array = m.tiles
	# Nur den bekannten Bereich zeigen (mit etwas Rand), damit er groß genug ist
	var bx0 := mw
	var by0 := mh
	var bx1 := 0
	var by1 := 0
	for y in mh:
		for x in mw:
			if not explored[y * mw + x]:
				continue
			bx0 = mini(bx0, x)
			by0 = mini(by0, y)
			bx1 = maxi(bx1, x)
			by1 = maxi(by1, y)
	if bx1 < bx0:
		return
	var pad := 3
	bx0 = maxi(0, bx0 - pad)
	by0 = maxi(0, by0 - pad)
	bx1 = mini(mw - 1, bx1 + pad)
	by1 = mini(mh - 1, by1 + pad)
	var bw := bx1 - bx0 + 1
	var bh := by1 - by0 + 1
	# Ganze Pixel je Feld, damit die Karte scharf bleibt
	var cell := maxf(1.0, floorf(minf(minf(w / bw, h / bh), 8.0)))
	var ox := floorf((w - cell * bw) / 2) - bx0 * cell
	var oy := floorf((h - cell * bh) / 2) - by0 * cell
	var cs := cell
	for y in range(by0, by1 + 1):
		for x in range(bx0, bx1 + 1):
			var i := y * mw + x
			if not explored[i]:
				continue
			var tile: String = tl[i]
			var col: Color
			if tile == "wall":
				# Nur Wände an bekanntem Boden zeigen
				var edge := false
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						var nx := x + dx
						var ny := y + dy
						if nx >= 0 and ny >= 0 and nx < mw and ny < mh and tl[ny * mw + nx] != "wall" and explored[ny * mw + nx]:
							edge = true
				if not edge:
					continue
				col = Color("#4c6b70")
			elif tile == "stairs":
				col = Color("#f1d867")
			elif tile == "door" or tile == "dooropen":
				col = Color("#b48355")
			elif tile == Dungeon.WATER:
				col = Color("#47aba9")
			elif tile == Dungeon.MUD:
				col = Color("#866353")
			elif tile == Kanalstadt.CANAL:
				col = Color("#3e8698")
			elif tile == Kanalstadt.BRIDGE:
				col = Color("#c8a876")
			elif tile == Tiefgarage.OIL:
				col = Color("#2a2f45")
			elif Tiefgarage.is_wreck(tile):
				col = Color("#8d4848")
			else:
				var ri: int = m.roomAt[i]
				if ri >= 0:
					col = Color(ROOM_COLORS.get(m.rooms[ri].kind, "#c9b48e"))
				else:
					col = Color("#9a8a72")
			draw_rect(Rect2(ox + x * cell, oy + y * cell, cs, cs), col)
	var si := tl.find("stairs")
	if si >= 0 and explored[si]:
		var sx := ox + (si % mw) * cell + cell / 2
		var sy := oy + (si / mw) * cell + cell / 2
		var r := maxf(3, floorf(cell * 1.6))
		draw_rect(Rect2(floorf(sx - r), floorf(sy - r), r * 2, r * 2), Color("#f1d867"), false, 2.0)
	# Gilde der Einweisung umrahmt, bis das Inventar freigeschaltet ist
	if not Game.has_unlock(s, "inventar"):
		for r in m.rooms:
			if r.get("marked", false):
				draw_rect(Rect2(ox + (r.x - 1) * cell, oy + (r.y - 1) * cell, (r.w + 2) * cell, (r.h + 2) * cell), Color("#7cd4ea"), false, 2.0)
	var px: float = ox + s.player.pos.x * cell + cell / 2
	var py: float = oy + s.player.pos.y * cell + cell / 2
	var g := maxf(4, floorf(cell * 2.4))
	draw_rect(Rect2(floorf(px - g), floorf(py - g), g * 2, g * 2), Color(1, 214 / 255.0, 90 / 255.0, 0.3))
	var d := maxf(2, floorf(cell * 1.1))
	draw_rect(Rect2(floorf(px - d), floorf(py - d), d * 2, d * 2), Color("#fff4cc"))
