extends SceneTree
## Holt die gebrauchten Teile aus dem Tiny-Swords-Pack (Pixel Frog, liegt in
## ../asset-pack) nach assets/tinyswords: Knöpfe, Papier, Holzrahmen, Bänder,
## Balken und Gelände. Bögen mit Lücken werden zu lückenlosen 9-Slices
## zusammengesetzt, Knöpfe für die dunkle Oberfläche umgefärbt und für kleine
## Elemente auf halbe Größe gebracht (Umrisse bleiben dabei erhalten).
##
## godot --headless --path godot -s res://tools/import_tinyswords.gd

const FREE := "asset-pack/Assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/"
const UPD := "asset-pack/Assets/Tiny Swords/Tiny Swords (Update 010)/"
const OUT := "res://assets/tinyswords/"

var base := ""
var made := 0


func _init() -> void:
	base = ProjectSettings.globalize_path("res://").path_join("..").simplify_path() + "/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + "ui"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + "terrain"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + "fx"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + "units"))
	_ui()
	_units()
	_terrain()
	_fx()
	print("%d Bilder nach %s" % [made, OUT])
	quit()


func _load(rel: String) -> Image:
	var img := Image.load_from_file(base + rel)
	if img == null:
		push_error("fehlt: " + rel)
		return Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.convert(Image.FORMAT_RGBA8)
	return img


func _save(img: Image, name: String) -> void:
	# Oberflächenteile ohne durchsichtigen Rand, damit die 9-Slice-Ränder passen
	if name.begins_with("ui/"):
		img = img.get_region(img.get_used_rect())
	img.save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	made += 1


# ================================================================ Werkzeuge

## Bogen mit Lücken (Teile im 128er-Raster) zu einem lückenlosen 3x3-Bild.
func _assemble(img: Image, cols: Array, rows: Array) -> Image:
	var w := 0
	var h := 0
	for c in cols:
		w += c[1] - c[0]
	for r in rows:
		h += r[1] - r[0]
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var y := 0
	for r in rows:
		var x := 0
		for c in cols:
			out.blit_rect(img, Rect2i(c[0], r[0], c[1] - c[0], r[1] - r[0]), Vector2i(x, y))
			x += c[1] - c[0]
		y += r[1] - r[0]
	return out


## Halbe Größe: je 2x2 Pixel ein Pixel. Dunkle Umrisse gewinnen immer,
## sonst die häufigste Farbe – so bleiben Linien und Kanten scharf.
func _half(img: Image) -> Image:
	var w := img.get_width() / 2
	var h := img.get_height() / 2
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var px := [img.get_pixel(2 * x, 2 * y), img.get_pixel(2 * x + 1, 2 * y), img.get_pixel(2 * x, 2 * y + 1), img.get_pixel(2 * x + 1, 2 * y + 1)]
			var solid: Array = px.filter(func(c): return c.a > 0.5)
			if solid.size() < 2:
				continue
			var dark: Array = solid.filter(func(c): return c.v < 0.3)
			if not dark.is_empty():
				out.set_pixel(x, y, dark[0])
				continue
			var best: Color = solid[0]
			var best_n := 0
			for c in solid:
				var n: int = solid.filter(func(d): return d.is_equal_approx(c)).size()
				if n > best_n:
					best = c
					best_n = n
			out.set_pixel(x, y, best)
	return out


## Häufigste deckende Farbe.
func _dominant(img: Image) -> Color:
	var count := {}
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.5:
				var k := c.to_html()
				count[k] = int(count.get(k, 0)) + 1
	var best := ""
	for k in count:
		if best == "" or count[k] > count[best]:
			best = k
	return Color.html(best)


## Füllung umfärben: Umriss (dunkel), heller Rand und gelber Hover-Rand
## bleiben, alles andere bekommt den Farbton von target und behält seine
## Helligkeit relativ zur Hauptfarbe (so bleiben Flecken und Schattenkante).
func _recolor(img: Image, target: Color, keep_rim: bool = true) -> Image:
	var out := img.duplicate()
	var ref := _dominant(img)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a <= 0.0 or c.v < 0.3:
				continue
			if keep_rim and ((c.s < 0.25 and c.v > 0.7) or (c.h > 0.1 and c.h < 0.2 and c.s > 0.45 and c.v > 0.85)):
				continue
			var v := clampf(target.v * c.v / ref.v, 0.0, 1.0)
			out.set_pixel(x, y, Color.from_hsv(target.h, target.s, v, c.a))
	return out


## Gelben Hover-Rand des Packs auf einen umgefärbten Knopf legen.
func _hovered(img: Image, hover: Image) -> Image:
	var out := img.duplicate()
	for y in img.get_height():
		for x in img.get_width():
			var c := hover.get_pixel(x, y)
			if c.a > 0.5 and c.h > 0.1 and c.h < 0.2 and c.s > 0.45 and c.v > 0.85:
				out.set_pixel(x, y, c)
	return out


## Alles außer dem Umriss grau und dunkel (deaktivierte Knöpfe).
func _grey(img: Image, level: float) -> Image:
	var out := img.duplicate()
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a <= 0.0 or c.v < 0.3:
				continue
			out.set_pixel(x, y, Color.from_hsv(0.62, 0.12, c.v * level, c.a))
	return out


## Graustufen-Füllung zum Einfärben per modulate (Balken).
func _white(img: Image) -> Image:
	var out := img.duplicate()
	var ref := _dominant(img)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a <= 0.0:
				continue
			var v := clampf(c.v / ref.v, 0.0, 1.25) * 0.8
			out.set_pixel(x, y, Color(v, v, v, c.a))
	return out


# ================================================================ Oberfläche

func _ui() -> void:
	var b := UPD + "UI/Buttons/"
	var blue := _load(b + "Button_Blue_9Slides.png")
	var blue_p := _load(b + "Button_Blue_9Slides_Pressed.png")
	var hover := _load(b + "Button_Hover_9Slides.png")
	var red := _load(b + "Button_Red_9Slides.png")
	var red_p := _load(b + "Button_Red_9Slides_Pressed.png")
	var off := _load(b + "Button_Disable_9Slides.png")
	# Dunkle Knöpfe für helle Schrift, Gold für Hauptaktionen, Rot für Gefahr
	var slate := Color("#3b5667")
	var gold := Color("#d9a441")
	var sel := Color("#4e4a33")
	var sets := {
		"btn": [_recolor(blue, slate), _hovered(_recolor(blue, Color("#46657a")), hover), _recolor(blue_p, Color("#2f4757"))],
		"btn_primary": [_recolor(blue, gold), _hovered(_recolor(blue, Color("#e8b850")), hover), _recolor(blue_p, Color("#bf8d33"))],
		"btn_danger": [_recolor(red, Color("#9c4a48")), _hovered(_recolor(red, Color("#ad5450")), hover), _recolor(red_p, Color("#82403f"))],
		"btn_sel": [_hovered(_recolor(blue, sel), hover), _hovered(_recolor(blue, Color("#5a5539")), hover), _recolor(blue_p, sel)],
	}
	for k in sets:
		_save(_half(sets[k][0]), "ui/%s" % k)
		_save(_half(sets[k][1]), "ui/%s_hover" % k)
		_save(_half(sets[k][2]), "ui/%s_pressed" % k)
	_save(_half(_grey(off, 0.42)), "ui/btn_disabled")
	# Geschnitzte Fläche (Reiter, Etiketten), dunkel gebeizt
	var carved := _load(UPD + "UI/Banners/Carved_9Slides.png")
	_save(_half(_recolor(carved, Color("#6b5a4a"), false)), "ui/carved")
	_save(_half(_recolor(carved, Color("#8a6e4c"), false)), "ui/carved_active")
	# Papier mit Goldornament (Karten, Dialoge, Hinweise)
	var f := FREE + "UI Elements/UI Elements/"
	var cells := [[0, 64], [128, 192], [256, 320]]
	var paper := _assemble(_load(f + "Papers/SpecialPaper.png"), cells, cells)
	_save(paper, "ui/paper")
	_save(_half(paper), "ui/paper_small")
	var big := [[0, 128], [192, 256], [320, 448]]
	var wood := _assemble(_load(f + "Wood Table/WoodTable.png"), big, big)
	_save(wood, "ui/wood")
	_save(_half(wood), "ui/wood_small")
	var banner := _assemble(_load(f + "Banners/Banner.png"), big, big)
	_save(_half(banner), "ui/parchment")
	# Bänder (3-Slice) für Überschriften
	for c in ["Yellow", "Red", "Blue"]:
		_save(_half(_load(UPD + "UI/Ribbons/Ribbon_%s_3Slides.png" % c)), "ui/ribbon_%s" % c.to_lower())
	# Balken: Holzrahmen und hellgraue Füllung zum Einfärben
	var bar := _assemble(_load(f + "Bars/BigBar_Base.png"), cells, [[0, 64]])
	_save(_half(bar), "ui/bar")
	_save(_half(_white(_load(f + "Bars/BigBar_Fill.png"))), "ui/bar_fill")


# ================================================================ Figuren

## Rote Teamfarbe der Einheiten -> Magenta-Stufen (PixelArt.TINT_KEYS), damit
## Kleidung und Kapuze die Farbe der Monsterart annehmen.
const TEAM := {"693d5b": 1, "864659": 1, "924159": 1, "9c4d57": 2, "ab6282": 2, "b65555": 2, "bb655e": 2, "c07265": 3, "e76161": 3, "f76666": 3}
## Bildfläche der Pack-Figuren: 128 x 128, Füße auf Zeile 121.
const UNIT_SIZE := 128
const UNIT_FOOT := 121

## Figuren aus dem Pack: Name -> [Bogen, Feldgröße, [Ruhe-Reihe, Bilder], [Lauf-Reihe, Bilder] oder null,
## Teamfarbe tönbar, Angriff [Bogen oder "" (derselbe), Reihe, Bilder] oder null].
## Die Bögen ohne Reihe sind einzeilig (Reihe 0).
const P := "Units/Red Units/Pawn/Pawn_"
## Bildfläche der Angriffsbilder (Pack-Figuren und Tiny RPG).
const ATTACK_SIZE := 192
const RPG_ATTACK_SIZE := 256
const UNITS := {
	# Spielfigur: der blaue Arbeiter in seinen echten Farben (Ausrüstung: GearLook)
	"spieler_pawn": ["Units/Blue Units/Pawn/Pawn_Idle.png|Units/Blue Units/Pawn/Pawn_Run.png", 192, [0, 8], [0, 6], false, ["Units/Blue Units/Pawn/Pawn_Interact Knife.png", 0, 4]],
	# Menschen und Crawler: rote Einheiten, Teamfarbe in der Farbe der Art
	"mensch": [P + "Idle.png|" + P + "Run.png", 192, [0, 8], [0, 6], true, [P + "Interact Knife.png", 0, 4]],
	"mensch_hammer": [P + "Idle Hammer.png|" + P + "Run Hammer.png", 192, [0, 8], [0, 6], true, [P + "Interact Hammer.png", 0, 3]],
	"mensch_gold": [P + "Idle Gold.png|" + P + "Run Gold.png", 192, [0, 8], [0, 6], true, [P + "Interact Pickaxe.png", 0, 6]],
	"mensch_holz": [P + "Idle Wood.png|" + P + "Run Wood.png", 192, [0, 8], [0, 6], true, [P + "Interact Axe.png", 0, 6]],
	"mensch_messer": [P + "Idle Knife.png|" + P + "Run Knife.png", 192, [0, 8], [0, 6], true, [P + "Interact Knife.png", 0, 4]],
	"krieger": ["Units/Red Units/Warrior/Warrior_Idle.png|Units/Red Units/Warrior/Warrior_Run.png", 192, [0, 8], [0, 6], true, ["Units/Red Units/Warrior/Warrior_Attack1.png", 0, 4]],
	"bogen": ["Units/Red Units/Archer/Archer_Idle.png|Units/Red Units/Archer/Archer_Run.png", 192, [0, 6], [0, 4], true, ["Units/Red Units/Archer/Archer_Shoot.png", 0, 8]],
	"moench": ["Units/Red Units/Monk/Idle.png|Units/Red Units/Monk/Run.png", 192, [0, 6], [0, 4], true, ["Units/Red Units/Monk/Heal.png", 0, 11]],
	# Goblins (Kobolde): Fackel, Dynamit, Fass
	"kobold": ["U:Factions/Goblins/Troops/Torch/Red/Torch_Red.png", 192, [0, 7], [1, 6], true, ["", 2, 6]],
	"kobold_tnt": ["U:Factions/Goblins/Troops/TNT/Red/TNT_Red.png", 192, [0, 6], [1, 6], true, ["", 2, 7]],
	"fass": ["U:Factions/Goblins/Troops/Barrel/Red/Barrel_Red.png", 128, [0, 1], null, true, ["", 1, 6]],
	# Schaf
	"schaf": ["U:Resources/Sheep/HappySheep_Idle.png|U:Resources/Sheep/HappySheep_Bouncing.png", 128, [0, 8], [0, 6], false, null],
}

## Hautfarbe der Goblins (grün) und der Menschen, für Abwandlungen.
const GOBLIN_SKIN := ["417168", "38b251", "95d562"]
## Abwandlungen: neuer Name -> [Figur, Hautfarben (dunkel, mittel, hell)].
const SKINS := {
	"fischmensch": ["kobold", ["2f5a7a", "3e8fb8", "8cc8e0"]],
	"wechselbalg": ["kobold", ["5a3f78", "8a62b0", "c09ee0"]],
	"gnom": ["kobold", ["8a5a4a", "d89a7a", "f0c8a8"]],
}


func _sheet(spec: String) -> Image:
	if spec.begins_with("U:"):
		return _load(UPD + spec.substr(2))
	return _load(FREE + spec)


## Ein Feld eines Bogens: ohne eingebauten Schatten, Teamfarbe auf Wunsch tönbar.
func _cell(sheet: Image, size: int, row: int, col: int, tint: bool) -> Image:
	var fr := sheet.get_region(Rect2i(col * size, row * size, size, size))
	var keys: Array = PixelArt.TINT_KEYS.map(func(k): return Color(k))
	for y in size:
		for x in size:
			var c := fr.get_pixel(x, y)
			if c.a < 0.99:
				fr.set_pixel(x, y, Color(0, 0, 0, 0))
			elif tint and TEAM.has(c.to_html(false)):
				fr.set_pixel(x, y, keys[TEAM[c.to_html(false)]])
	return fr


static func _bottom(img: Image) -> int:
	var used := img.get_used_rect()
	return used.end.y - 1


## Feld auf die Bildfläche der Figuren setzen, Füße (Unterkante der Ruhefigur)
## auf UNIT_FOOT. Angriffe bekommen eine größere Fläche (canvas) für den
## Schwung, die Füße bleiben gleich weit über dem unteren Rand.
func _place(fr: Image, bottom: int, canvas: int = UNIT_SIZE) -> Image:
	var out := Image.create(canvas, canvas, false, Image.FORMAT_RGBA8)
	var ox := (canvas - fr.get_width()) / 2
	out.blend_rect(fr, Rect2i(Vector2i.ZERO, fr.get_size()), Vector2i(ox, UNIT_FOOT + canvas - UNIT_SIZE - bottom))
	return out


func _recolor_skin(img: Image, from: Array, to: Array) -> Image:
	var out := img.duplicate()
	for y in img.get_height():
		for x in img.get_width():
			var i := from.find(img.get_pixel(x, y).to_html(false))
			if i >= 0 and img.get_pixel(x, y).a > 0.5:
				out.set_pixel(x, y, Color(to[i]))
	return out


func _units() -> void:
	var dir := ProjectSettings.globalize_path(OUT + "units")
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	var made_frames := {}
	for name in UNITS:
		var u: Array = UNITS[name]
		var files := String(u[0]).split("|")
		var size: int = u[1]
		var idle: Array = u[2]
		var run = u[3]
		var tint: bool = u[4]
		var idle_sheet := _sheet(files[0])
		var run_sheet := _sheet(files[1]) if files.size() > 1 else idle_sheet
		var start: int = idle[2] if idle.size() > 2 else 0
		var first := _cell(idle_sheet, size, idle[0], start, tint)
		var bottom := _bottom(first)
		var frames: Array = []
		for i in idle[1]:
			frames.append(_place(_cell(idle_sheet, size, idle[0], start + i, tint), bottom))
		var runs: Array = []
		if run != null:
			for i in run[1]:
				runs.append(_place(_cell(run_sheet, size, run[0], i, tint), bottom))
		var hits: Array = []
		var atk = u[5]
		if atk != null:
			var atk_sheet := idle_sheet if atk[0] == "" else _sheet(atk[0])
			for i in atk[2]:
				hits.append(_place(_cell(atk_sheet, size, atk[1], i, tint), bottom, ATTACK_SIZE))
		made_frames[name] = [frames, runs, hits]
		_save_unit(name, frames, runs, hits)
	for name in SKINS:
		var base: Array = made_frames[SKINS[name][0]]
		var skin := func(i): return _recolor_skin(i, GOBLIN_SKIN, SKINS[name][1])
		_save_unit(name, base[0].map(skin), base[1].map(skin), base[2].map(skin))
	_rpg_units()
	_royal_mage()


# ---------------------------------------------------------------- Tiny RPG Character Pack

const RPG := "asset-pack/Assets/Tiny RPG Character Asset Pack 01 v2.0 -Full 22 Characters/Tiny RPG Character Asset Pack 01 v2.0 -Full 22 Characters/Characters(100x100 split)/"
## Figuren aus dem Tiny RPG Character Pack (100er Felder, vergrößert auf eine
## Bildfläche von 192): Name -> [Figur, Ruhe-, Lauf- ("" ohne) und
## Angriffs-Animation, Vergrößerung, tönbar (Schleim), Schwebehöhe in
## Bildpixeln]. Die Vergrößerung gleicht die Größen an: Menschen etwa so groß
## wie die Spielfigur, kleine Skelette auch, Orks und Werbär größer.
const RPG_SIZE := 192
const RPG_FOOT := 185
const RPG_UNITS := {
	"rpg_schleim": ["Slime", "Idle", "Walk", "Attack01", 3, true],
	"rpg_fledermaus": ["Bat", "Flying", "", "Attack01", 3, false, 33],
	"rpg_skelett": ["Skeleton", "Idle", "Walk", "Attack01", 4],
	"rpg_skelett_schwert": ["Greatsword Skeleton", "Idle", "Walk", "Attack01", 3],
	"rpg_skelett_ruestung": ["Armored Skeleton", "Idle", "Walk", "Attack01", 3],
	"rpg_skelett_bogen": ["Skeleton Archer", "Idle", "Walk", "Attack", 3],
	"rpg_ork": ["Orc", "Idle", "Walk", "Attack01", 4],
	"rpg_ork_ruestung": ["Armored Orc", "Idle", "Walk", "Attack01", 4],
	"rpg_ork_elite": ["Elite Orc", "Idle", "Walk", "Attack01", 3],
	"rpg_ork_reiter": ["Orc rider", "Idle", "Walk", "Attack01", 3],
	"rpg_werbaer": ["Werebear", "Idle", "Walk", "Attack01", 4],
	"rpg_werwolf": ["Werewolf", "Idle", "Walk", "Attack01", 3],
	"rpg_nekromant": ["Necromancer", "Idle", "Walk", "Attack01", 3],
	"rpg_zauberer": ["Wizard", "Idle", "Walk", "Attack01", 3],
	"rpg_priester": ["Priest", "Idle", "Walk", "Attack", 3],
	"rpg_ritter": ["Knight", "Idle", "Walk", "Attack01", 3],
	"rpg_templer": ["Knight Templar", "Idle", "Walk01", "Attack01", 3],
	"rpg_soldat": ["Soldier", "Idle", "Walk", "Attack01", 3],
	"rpg_schwertkaempfer": ["Swordsman", "Idle", "Walk", "Attack01", 3],
	"rpg_bogenschuetzin": ["Archer", "Idle", "Walk", "Attack01", 3],
	"rpg_lanzenreiter": ["Lancer", "Idle", "Walk01", "Attack01", 3],
	"rpg_axtkaempfer": ["Armored Axeman", "Idle", "Walk", "Attack01", 3],
}


func _rpg_frames(who: String, anim: String, scale: int, tint: bool) -> Array:
	var img := _load(RPG + "%s/%s/%s_%s.png" % [who, who, who, anim])
	var out: Array = []
	for i in img.get_width() / 100:
		var fr := img.get_region(Rect2i(i * 100, 0, 100, 100))
		for y in 100:
			for x in 100:
				var c := fr.get_pixel(x, y)
				if c.a < 0.99:
					fr.set_pixel(x, y, Color(0, 0, 0, 0))
				elif tint and c.s > 0.3 and c.h > 0.15 and c.h < 0.45:
					# Grün des Schleims -> Magenta-Stufen nach Helligkeit
					var k := clampi(int(c.v * 5.0), 0, 4)
					fr.set_pixel(x, y, Color(PixelArt.TINT_KEYS[k]))
		var used := fr.get_used_rect()
		if used.size.x == 0:
			continue
		var big := fr.duplicate() as Image
		big.resize(100 * scale, 100 * scale, Image.INTERPOLATE_NEAREST)
		out.append(big)
	return out


func _rpg_units() -> void:
	for name in RPG_UNITS:
		var u: Array = RPG_UNITS[name]
		var scale: int = u[4]
		var tint: bool = u.size() > 5 and u[5]
		var idle := _rpg_frames(u[0], u[1], scale, tint)
		var runs := _rpg_frames(u[0], u[2], scale, tint) if u[2] != "" else []
		var hits := _rpg_frames(u[0], u[3], scale, tint)
		# Fliegende schweben über dem Boden (Höhe in Bildpixeln)
		var bottom := _bottom(idle[0]) + (int(u[6]) if u.size() > 6 else 0)
		var put := func(f): return _place_big(f, bottom)
		_save_unit(name, idle.map(put), runs.map(put), hits.map(func(f): return _place_big(f, bottom, RPG_ATTACK_SIZE)))


## Vergrößertes Feld mittig auf die Bildfläche, Füße auf RPG_FOOT (bei
## größerer Fläche gleich weit über dem unteren Rand).
func _place_big(fr: Image, bottom: int, canvas: int = RPG_SIZE) -> Image:
	var out := Image.create(canvas, canvas, false, Image.FORMAT_RGBA8)
	var src := Rect2i((fr.get_width() - canvas) / 2, bottom - RPG_FOOT - canvas + RPG_SIZE, canvas, canvas)
	out.blit_rect(fr, src, Vector2i.ZERO)
	return out


## Royal Mage (32er Felder, Reihen: Ruhe, Laufen, Angriff, Treffer, Tod,
## Zauber entsteht, Zauber fliegt, Zauber trifft), dreifach vergrößert wie die
## Menschen aus dem Tiny RPG Pack.
const MAGE := "asset-pack/Assets/Royal Mage Sprite Sheet.png"


func _mage_row(row: int, scale: int) -> Array:
	var img := _load(MAGE)
	var out: Array = []
	for i in 8:
		var fr := img.get_region(Rect2i(i * 32, row * 32, 32, 32))
		if fr.get_used_rect().size.x == 0:
			continue
		fr.resize(32 * scale, 32 * scale, Image.INTERPOLATE_NEAREST)
		out.append(fr)
	return out


func _royal_mage() -> void:
	var idle := _mage_row(0, 3)
	var runs := _mage_row(1, 3)
	var hits := _mage_row(2, 3)
	var bottom := _bottom(idle[0])
	var put := func(f): return _place_big(f, bottom)
	_save_unit("magier", idle.map(put), runs.map(put), hits.map(func(f): return _place_big(f, bottom, RPG_ATTACK_SIZE)))


## Zauberkugel im Flug (Geschoss) und ihr Aufschlag (Effekt), je ein Streifen.
func _royal_mage_fx() -> void:
	for pair in [[6, "zauber_flug"], [7, "zauber_treffer"]]:
		var frames := _mage_row(pair[0], 1)
		var strip := Image.create(32 * frames.size(), 32, false, Image.FORMAT_RGBA8)
		for i in frames.size():
			strip.blit_rect(frames[i], Rect2i(0, 0, 32, 32), Vector2i(i * 32, 0))
		_save(strip, "fx/" + pair[1])


func _save_unit(name: String, frames: Array, runs: Array, hits: Array = []) -> void:
	for i in frames.size():
		_save(frames[i], "units/%s_%d" % [name, i])
	for i in runs.size():
		_save(runs[i], "units/%s_lauf%d" % [name, i])
	for i in hits.size():
		_save(hits[i], "units/%s_angriff%d" % [name, i])


# ================================================================ Gelände

## Klippen-Block des Tilesets (erhöhte Fläche, rechts): 4 Spalten (links,
## Mitte, rechts, einzeln) x 6 Reihen (oben, Mitte, unten, einzeln, Felswand,
## Felswand am Wasser). Für jede Etage umgefärbt: Oberseite = Fels von oben,
## Wand = Mauerwerk zum Raum hin.
const WALLS := {
	1: {"top": "#5d4c4b", "face": "#6f9a98", "rim": "#a99a8a"},
	2: {"top": "#4d5262", "face": "#8e979c", "rim": "#a3a9b5"},
	3: {"top": "#4f6a45", "face": "#58806f", "rim": "#9fbf8a"},
}


func _is_grass(c: Color) -> bool:
	return c.h > 0.1 and c.h < 0.36 and c.s > 0.28 and c.v >= 0.3


func _is_stone(c: Color) -> bool:
	return c.h > 0.4 and c.h < 0.6 and c.s > 0.12 and c.v >= 0.3 and c.v < 0.9


func _is_rim(c: Color) -> bool:
	return c.h > 0.3 and c.h < 0.5 and c.s <= 0.3 and c.v >= 0.85


## Pixel einer Klasse umfärben, Helligkeit relativ zur Hauptfarbe der Klasse.
func _recolor_where(img: Image, pred: Callable, target: Color, contrast: float = 1.0) -> void:
	var count := {}
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.5 and pred.call(c):
				var k := c.to_html()
				count[k] = int(count.get(k, 0)) + 1
	var ref_k := ""
	for k in count:
		if ref_k == "" or count[k] > count[ref_k]:
			ref_k = k
	if ref_k == "":
		return
	var ref := Color.html(ref_k)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.0 and pred.call(c):
				var k := 1.0 + contrast * (c.v / ref.v - 1.0)
				img.set_pixel(x, y, Color.from_hsv(target.h, target.s, clampf(target.v * k, 0.0, 1.0), c.a))


func _terrain() -> void:
	var t := FREE + "Terrain/Tileset/"
	var block := _load(t + "Tilemap_color1.png").get_region(Rect2i(320, 0, 256, 384))
	for fl in WALLS:
		var w: Dictionary = WALLS[fl]
		var img := block.duplicate()
		_recolor_where(img, _is_grass, Color(w.top), 1.8)
		_recolor_where(img, _is_stone, Color(w.face))
		_recolor_where(img, _is_rim, Color(w.rim))
		_save(img, "terrain/wall_%d" % fl)
	for i in [1, 2, 3, 4, 5]:
		var img := _load(t + "Tilemap_color%d.png" % i)
		_save(img, "terrain/tilemap_%d" % i)
	_save(_load(t + "Water Foam.png"), "terrain/foam")
	_save(_load(t + "Shadow.png"), "terrain/shadow")
	var w := _load(t + "Water Background color.png")
	_save(w, "terrain/water")
	for i in [1, 2, 3, 4]:
		_save(_load(FREE + "Terrain/Decorations/Rocks/Rock%d.png" % i), "terrain/rock_%d" % i)
		_save(_load(FREE + "Terrain/Decorations/Bushes/Bushe%d.png" % i), "terrain/bush_%d" % i)


# ================================================================ Effekte

func _fx() -> void:
	var p := FREE + "Particle FX/"
	for n in ["Explosion_01", "Explosion_02", "Fire_01", "Fire_02", "Fire_03", "Dust_01", "Dust_02", "Water Splash"]:
		_save(_load(p + n + ".png"), "fx/" + n.to_lower().replace(" ", "_"))
	_royal_mage_fx()
