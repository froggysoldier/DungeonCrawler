class_name HeroLook
extends RefCounted
## Die Spielfigur im Stil von Tiny Swords, aus Formen gebaut (TsRender): ein
## Körperbau je Rasse (normal, klein, gross, breit), darauf die Merkmale der
## Rasse (Ohren, Hörner, Schwanz, Bart …) und die sichtbare Ausrüstung in der
## Farbe ihrer Seltenheit. Bild 96 x 96, zwei Bildpixel je Kunstpixel.

## Ab dieser Bildzeile bewegen sich im Laufbild nur noch die Beine.
const WALK_ROW := 72

## Maße je Körperbau: Kopf (Mitte, Radien), Rumpf (Rechteck), Beine, Arme.
const BUILDS := {
	"normal": {"head": [48, 44, 14, 13], "torso": [36, 55, 24, 22], "leg": [43, 53, 75, 8], "arm": 8},
	"klein": {"head": [48, 56, 13, 12], "torso": [38, 66, 20, 15], "leg": [44, 52, 79, 7], "arm": 7},
	"gross": {"head": [48, 33, 15, 14], "torso": [32, 46, 32, 30], "leg": [41, 55, 74, 10], "arm": 10},
	"breit": {"head": [48, 48, 15, 13], "torso": [32, 59, 32, 20], "leg": [42, 54, 77, 10], "arm": 10},
}


static func shapes(race: String, body: String, skin: String, gear: Dictionary, f: int) -> Array:
	var b: Dictionary = BUILDS.get(body, BUILDS.normal)
	var hd: Array = b.head
	var to: Array = b.torso
	var lg: Array = b.leg
	var hx: float = hd[0]
	var hy: float = hd[1]
	var hr: float = hd[2]
	var tx: float = to[0]
	var ty: float = to[1]
	var tw: float = to[2]
	var th: float = to[3]
	var aw: float = b.arm
	var step := 3 if f == 1 else 0
	var out: Array = []
	var g := func(slot: String) -> Variant:
		return gear.get(slot)
	# Hinter der Figur: Umhang oder Rucksack, Flügel und Schwänze
	if g.call("ruecken") != null:
		out.append(["r", tx - 5, ty - 2, tw + 10, th + 8, 6, g.call("ruecken")])
	out += _behind(race, skin, hx, hy, hr, tx, ty, tw, th)
	# Beine (Hose), Füße
	out.append(["l", lg[0], lg[2], lg[0] - step, 86, lg[3], "N"])
	out.append(["l", lg[1], lg[2], lg[1] + step, 86, lg[3], "N"])
	if g.call("beine") != null:
		out.append(["l", lg[0], lg[2] - 2, lg[0] - step, 84, lg[3] + 1, g.call("beine")])
		out.append(["l", lg[1], lg[2] - 2, lg[1] + step, 84, lg[3] + 1, g.call("beine")])
	if g.call("fuesse") != null:
		out.append(["e", lg[0] - step - 1, 85, lg[3] / 2 + 2, 4, g.call("fuesse")])
		out.append(["e", lg[1] + step + 1, 85, lg[3] / 2 + 2, 4, g.call("fuesse")])
	# Arme (Haut), Rumpf (schlichtes Hemd)
	var sl := Vector2(tx + 2, ty + 5)
	var sr := Vector2(tx + tw - 2, ty + 5)
	var hl := Vector2(tx - 4, ty + th - 2)
	var hand_r := Vector2(tx + tw + 4, ty + th - 2)
	out.append(["l", sl.x, sl.y, hl.x, hl.y, aw, skin])
	out.append(["l", sr.x, sr.y, hand_r.x, hand_r.y, aw, skin])
	out.append(["r", tx, ty, tw, th, 8, "G"])
	if g.call("brust") != null:
		out.append(["r", tx + 2, ty + 2, tw - 4, th - 4, 6, g.call("brust")])
	if g.call("arme") != null:
		out.append(["l", sl.lerp(hl, 0.5).x, sl.lerp(hl, 0.5).y, hl.x, hl.y - 2, aw + 1, g.call("arme")])
		out.append(["l", sr.lerp(hand_r, 0.5).x, sr.lerp(hand_r, 0.5).y, hand_r.x, hand_r.y - 2, aw + 1, g.call("arme")])
	if g.call("schultern") != null:
		out.append(["e", tx + 2, ty + 4, aw * 0.8 + 2, aw * 0.6 + 1, g.call("schultern")])
		out.append(["e", tx + tw - 2, ty + 4, aw * 0.8 + 2, aw * 0.6 + 1, g.call("schultern")])
	if g.call("guertel") != null:
		out.append(["r", tx, ty + th - 7, tw, 5, 2, g.call("guertel")])
		out.append(["r", hx - 3, ty + th - 8, 6, 7, 1, "y"])
	if g.call("hals") != null:
		out.append(["dl", hx - 6, ty + 1, hx, ty + 8, "y"])
		out.append(["dl", hx + 6, ty + 1, hx, ty + 8, "y"])
		out.append(["d", hx, ty + 9, 2.5, g.call("hals")])
	# Hände
	var glove: Variant = g.call("haende")
	out.append(["e", hl.x, hl.y + 2, aw / 2 + 1, aw / 2 + 1, glove if glove != null else skin])
	# Waffe in der rechten Hand, ragt nach oben
	if g.call("waffe") != null:
		out.append(["l", hand_r.x, hand_r.y + 6, hand_r.x + 4, hand_r.y - 2, 4, "D"])
		out.append(["l", hand_r.x + 3, hand_r.y - 2, hand_r.x + 14, hand_r.y - 30, 5, g.call("waffe")])
		out.append(["l", hand_r.x - 3, hand_r.y - 1, hand_r.x + 9, hand_r.y + 3, 3, "y"])
	out.append(["e", hand_r.x, hand_r.y + 2, aw / 2 + 1, aw / 2 + 1, glove if glove != null else skin])
	# Kopf mit den Merkmalen der Rasse
	out += _head(race, skin, hx, hy, hr, tx, ty, tw)
	if g.call("gesicht") != null:
		out.append(["e", hx - 5, hy + 1, 4, 3.5, g.call("gesicht"), "f"])
		out.append(["e", hx + 6, hy + 1, 4, 3.5, g.call("gesicht"), "f"])
		out.append(["dl", hx - 1, hy, hx + 2, hy, "k"])
	if g.call("kopf") != null:
		out.append(["p", _cap(hx, hy - 4, hr), g.call("kopf")])
		out.append(["r", hx - hr - 2, hy - 8, hr * 2 + 4, 5, 2, g.call("kopf")])
	return out


## Helm: obere Hälfte des Kopfes als Vieleck.
static func _cap(hx: float, hy: float, hr: float) -> Array:
	var pts: Array = []
	for i in 13:
		var a := PI * i / 12.0
		pts.append(hx + (hr + 2) * cos(a))
		pts.append(hy - 2 - (hr + 2) * sin(a))
	return pts


static func _eyes(hx: float, hy: float, col: String = "") -> Array:
	if col != "":
		return [["d", hx - 5, hy + 1, 2, col], ["d", hx + 6, hy + 1, 2, col]]
	return [["eye", hx - 6, hy - 1], ["eye", hx + 5, hy - 1]]


## Was hinter dem Körper liegt: Flügel und Schwänze.
static func _behind(race: String, skin: String, hx: float, hy: float, hr: float, tx: float, ty: float, tw: float, th: float) -> Array:
	match race:
		"kellerfee":
			return [
				["e", tx - 14, ty + 2, 16, 10, "c"],
				["e", tx - 8, ty + 14, 11, 7, "c"],
				["e", tx + tw + 14, ty + 2, 16, 10, "c"],
				["e", tx + tw + 8, ty + 14, 11, 7, "c"],
			]
		"wasserspeier":
			return [
				["p", [tx, ty + 4, tx - 18, ty - 8, tx - 12, ty + 6, tx - 16, ty + 14, tx, ty + 14], "N"],
				["p", [tx + tw, ty + 4, tx + tw + 18, ty - 8, tx + tw + 12, ty + 6, tx + tw + 16, ty + 14, tx + tw, ty + 14], "N"],
			]
		"echsenmensch", "salamander", "drachenblut":
			return [
				["l", tx + tw - 4, ty + th - 2, tx + tw + 16, ty + th + 6, 9, skin],
				["l", tx + tw + 16, ty + th + 6, tx + tw + 30, ty + th + 2, 6, skin],
			]
		"katzenmensch":
			return [["l", tx + tw - 4, ty + th - 4, tx + tw + 12, ty + th - 6, 5, skin], ["l", tx + tw + 12, ty + th - 6, tx + tw + 14, ty + th - 20, 5, skin]]
		"rattling":
			return [["l", tx + tw - 4, ty + th - 2, tx + tw + 20, ty + th + 6, 3, "f"]]
		"vampir":
			return [["p", [tx - 6, ty - 2, tx + tw + 6, ty - 2, tx + tw + 10, 86, tx - 10, 86], "r"]]
	return []


## Kopf, Haare, Ohren, Hörner, Bart und Augen je Rasse.
static func _head(race: String, skin: String, hx: float, hy: float, hr: float, tx: float, ty: float, tw: float) -> Array:
	var ears := func(col: String, w: float, h: float, up: float) -> Array:
		return [
			["p", [hx - hr + 3, hy - 2, hx - hr - w, hy - up - h, hx - hr + 4, hy + 5], col],
			["p", [hx + hr - 3, hy - 2, hx + hr + w, hy - up - h, hx + hr - 4, hy + 5], col],
		]
	var horns := func(col: String, w: float, h: float) -> Array:
		return [
			["p", [hx - hr + 6, hy - hr + 6, hx - hr - w, hy - hr - h, hx - hr + 12, hy - hr + 2], col],
			["p", [hx + hr - 6, hy - hr + 6, hx + hr + w, hy - hr - h, hx + hr - 12, hy - hr + 2], col],
		]
	var head: Array = [["e", hx, hy, hr, hr - 1, skin]]
	var hair := func(col: String) -> Array:
		return [["p", _cap(hx, hy - 2, hr - 1), col, "n"]]
	match race:
		"mensch":
			return head + hair.call("d") + _eyes(hx, hy)
		"elf":
			return ears.call(skin, 9, 6, 2) + head + hair.call("Y") + _eyes(hx, hy)
		"halbork":
			return head + [["p", [hx - 4, hy - hr, hx, hy - hr - 8, hx + 4, hy - hr], "K"]] + _eyes(hx, hy) + [["d", hx - 4, hy + 8, 1.5, "w"], ["d", hx + 5, hy + 8, 1.5, "w"]]
		"zwerg":
			return head + hair.call("U") + _eyes(hx, hy) + [["p", [hx - hr + 1, hy + 2, hx + hr - 1, hy + 2, hx + 8, hy + hr + 12, hx, hy + hr + 16, hx - 8, hy + hr + 12], "U"], ["e", hx, hy + 4, 3, 2.5, skin]]
		"gnom":
			return head + [["e", hx - hr + 2, hy - 4, 5, 6, "G"], ["e", hx + hr - 2, hy - 4, 5, 6, "G"]] + _eyes(hx, hy) + [["e", hx, hy + 4, 4, 3.5, "f"]]
		"halbling":
			var curls: Array = []
			for i in 5:
				curls.append(["e", hx - hr + 4 + i * (hr * 2 - 8) / 4.0, hy - hr + 4, 5, 5, "d"])
			return head + curls + _eyes(hx, hy)
		"kobold":
			return ears.call(skin, 8, 2, -2) + head + horns.call("H", 1, 5) + _eyes(hx, hy, "Y")
		"kellerfee":
			return head + hair.call("P") + _eyes(hx, hy) + [["d", hx - 8, hy + 5, 1.5, "f"], ["d", hx + 8, hy + 5, 1.5, "f"]]
		"echsenmensch", "salamander":
			var spots := "Y" if race == "salamander" else "L"
			return head + [["e", hx + 6, hy + 5, 8, 5, skin, "n"], ["d", hx - 6, hy - 7, 2, spots], ["d", hx + 2, hy - 9, 1.5, spots]] + _eyes(hx, hy, "Y")
		"hobgoblin":
			return ears.call(skin, 11, 4, 0) + head + hair.call("K") + _eyes(hx, hy, "Y")
		"katzenmensch":
			return head + [["p", [hx - hr + 2, hy - 4, hx - hr + 2, hy - hr - 8, hx - 3, hy - hr + 2], skin], ["p", [hx + hr - 2, hy - 4, hx + hr - 2, hy - hr - 8, hx + 3, hy - hr + 2], skin]] + _eyes(hx, hy, "l") + [["d", hx, hy + 5, 1.5, "f"], ["dl", hx - 12, hy + 5, hx - 6, hy + 6, "k"], ["dl", hx + 12, hy + 5, hx + 6, hy + 6, "k"]]
		"troll":
			return head + hair.call("L") + _eyes(hx, hy) + [["e", hx, hy + 5, 5, 4, skin], ["d", hx - 6, hy + 9, 1.5, "w"]]
		"minotaurus":
			return horns.call("h", 8, 6) + head + [["e", hx, hy + 6, 9, 6, "U"], ["d", hx - 3, hy + 6, 1.2, "k"], ["d", hx + 3, hy + 6, 1.2, "k"], ["dl", hx - 3, hy + 10, hx + 3, hy + 10, "y"]] + _eyes(hx, hy - 3)
		"golem":
			return head + [["dl", hx - 8, hy - 8, hx - 2, hy - 2, "D"], ["dl", hx + 6, hy + 4, hx + 10, hy + 9, "D"]] + _eyes(hx, hy, "c")
		"kelleroger":
			return ears.call(skin, 5, -2, -6) + head + _eyes(hx, hy) + [["e", hx, hy + 4, 5, 4, skin], ["p", [hx + 2, hy + 9, hx + 6, hy + 9, hx + 4, hy + 13], "w"]]
		"pilzling":
			return head + [["e", hx, hy - hr + 2, hr + 8, 9, "R"], ["d", hx - 8, hy - hr, 2.5, "w"], ["d", hx + 6, hy - hr - 3, 2, "w"]] + _eyes(hx, hy + 2)
		"vampir":
			return head + [["p", [hx - hr, hy - 2, hx - hr + 2, hy - hr, hx + hr - 2, hy - hr, hx + hr, hy - 2, hx + 4, hy - hr + 6, hx, hy - 4, hx - 4, hy - hr + 6], "K", "n"]] + _eyes(hx, hy, "R") + [["d", hx - 2, hy + 8, 1, "w"], ["d", hx + 3, hy + 8, 1, "w"]]
		"rattling":
			return [["e", hx - hr + 2, hy - hr + 2, 6, 6, skin], ["e", hx + hr - 2, hy - hr + 2, 6, 6, skin], ["d", hx - hr + 2, hy - hr + 2, 3, "f"], ["d", hx + hr - 2, hy - hr + 2, 3, "f"]] + head + [["e", hx + 6, hy + 5, 8, 5, skin, "n"], ["d", hx + 13, hy + 4, 1.5, "f"]] + _eyes(hx, hy)
		"schattenwesen":
			return head + [["p", _cap(hx, hy, hr + 2), "K"]] + _eyes(hx, hy, "c")
		"wasserspeier":
			return horns.call("g", 2, 6) + head + _eyes(hx, hy, "R") + [["dl", hx - 4, hy + 7, hx + 4, hy + 7, "k"]]
		"ghulblut":
			return head + hair.call("D") + _eyes(hx, hy) + [["dl", hx - 10, hy + 4, hx - 4, hy + 8, "r"], ["dl", hx - 9, hy + 7, hx - 7, hy + 5, "r"]]
		"blechmensch":
			return head + [["p", [hx - 6, hy - hr + 2, hx + 6, hy - hr + 2, hx + 2, hy - hr - 10, hx - 2, hy - hr - 10], "G"], ["d", hx - 10, hy + 6, 1.2, "N"], ["d", hx + 10, hy + 6, 1.2, "N"]] + _eyes(hx, hy)
		"drachenblut":
			return horns.call("y", 2, 7) + head + [["d", hx - 7, hy + 6, 1.5, "o"], ["d", hx + 8, hy - 6, 1.5, "o"]] + _eyes(hx, hy, "Y")
	return head + hair.call("d") + _eyes(hx, hy)
