class_name GameDialogs
extends RefCounted
## Dialoge und Hinweise der Spielansicht: Tooltip,
## Box-Inhalte, Versus-Bildschirm, Talkshow und die Tastenhilfe.

const FURNITURE_TEXT := {
	"automat": "Gratis-Automat – ein Gegenstand pro Crawler", "haendler": "Händler – kaufen, verkaufen, feilschen",
	"wirt": "Wirt – Essen und ein Zimmer zum Schlafen", "bett": "Bett – acht Stunden Schlaf", "toilette": "Toilette – die Regel gilt",
	"schrein": "Schrein – beten: Segen, Heilung oder Fluch", "schrein_leer": "Erloschener Schrein",
	"nest": "Monsternest – bewohnt", "nest_leer": "Leeres Nest",
	"bildschirm": "Bildschirm – täglich um 21 Uhr die Highlights, hier nimmst du Einladungen an",
}

## Gelände und Hindernisse: Titel, Farbe, Hinweis.
const TERRAIN_TEXT := {
	"wasser": ["Seichtes Wasser", "#7cc4ff", "Löscht Feuer an allem, was hindurchgeht."],
	"schlamm": ["Schlamm", "#c09a6a", "Wer hineintritt, braucht einen Zug, um wieder herauszukommen."],
	"kiste": ["Kiste", "#c09a6a", "Hineinlaufen zum Zerschlagen. Manchmal ist etwas drin."],
	"fass": ["Fass", "#c09a6a", "Hineinlaufen zum Zerschlagen. Manchmal ist etwas drin."],
	"kanal": ["Kanal", "#5a9ac8", "Tief und trüb. Hinüber geht es nur über eine Brücke, aber man sieht und schießt hindurch."],
	"bruecke": ["Brücke", "#c09a6a", "Knarrende Planken über dem Kanal."],
	"oel": ["Ölpfütze", "#a0a0b0", "Rutschig: Wer hineintritt, landet oft auf dem Hintern. Wer brennt, setzt sie in Brand."],
	"wrack": ["Autowrack", "#d08a6a", "Hineinlaufen zum Durchsuchen. Manchmal springt die Alarmanlage an."],
	"wrack_leer": ["Ausgeräumtes Wrack", "#8a8a8a", "Hier ist nichts mehr zu holen."],
}


## Hinweistext zu einem Feld (BBCode) oder null.
static func tooltip_for(gv: GameView, t: Variant, detail: bool = false) -> Variant:
	var s := gv.s
	var m: Dictionary = s.map
	if not MapGen.in_bounds(m, t.x, t.y):
		return null
	var tp := GameView._pos(t)
	var i := MapGen.idx(m, t.x, t.y)
	var vis := gv._vis_now()
	var visible := vis.has(i)
	var known: bool = visible or (Game.has_unlock(s, "minimap") and m.explored[i])
	if not known:
		return null
	var parts: Array = []
	var mon = Ai.monster_at(s, tp) if visible else null
	if mon != null:
		var tech := gv.technique()
		var blocker = Combat.technique_blocker(s, mon, tech)
		var info := Identify.describe_monster(s, mon)
		var color = "#b0a898" if info.insight >= 3 else mon.color
		var look := Sprites.monster_sprite(mon)
		var fig := Kit.img(look[0], look[1], 1)
		parts.append("%s [b]%s[/b]%s" % [fig, Kit.col(Kit.esc(info.name), color), (" " + Kit.muted(Kit.esc(info.rank))) if info.rank != null else ""])
		parts.append(Kit.muted("%s · %s" % [Kit.esc(info.level), Identify.INSIGHT_NAMES[info.insight]]))
		parts.append("Herausforderung: [b]%s[/b] %s" % [Kit.col(Kit.esc(info.challenge.name), info.challenge.color), Kit.small(Kit.muted("(%s)" % Kit.esc(info.challenge.hint)))])
		var hl := Kit.esc(info.health)
		if J.num(mon, "downed") > 0:
			hl += " · " + Kit.col("am Boden", "#7cc4ff")
		if mon.get("asleep", false):
			hl += " · " + Kit.col("schläft", "#6ee07a")
		elif not mon.get("aware", false):
			hl += " · " + Kit.col("ahnungslos", "#6ee07a")
		parts.append(hl)
		var conds := Conditions.condition_list(mon)
		if not conds.is_empty():
			parts.append(" · ".join(conds.map(func(c): return Kit.col("%s (%s)" % [Kit.esc(c.state), J.s(c.turns)], c.color))))
		if info.combat != null:
			parts.append(Kit.esc(info.combat))
		if info.abilities != null:
			parts.append(Kit.col(Kit.esc(info.abilities), "#ff9dff"))
		if blocker != null:
			parts.append(Kit.muted("%s: %s" % [Kit.esc(Combat.technique_name(tech)), Kit.esc(blocker)]))
		elif info.showHitChance:
			parts.append("%s: [b]%d %%[/b] Trefferchance" % [Kit.esc(Combat.technique_name(tech)), Combat.hit_chance(s, mon, tech)])
		else:
			parts.append("%s: Trefferchance nicht einschätzbar" % Kit.esc(Combat.technique_name(tech)))
		if info.flavor != null:
			parts.append(Kit.small(Kit.muted(Kit.esc(info.flavor))))
	var npc = Crawlers.crawler_at(s, tp) if visible else null
	if npc != null:
		var party: bool = npc.get("party", false)
		var state := "In deiner Party" if party else ("Crawler" if npc.get("met", false) else "Ein anderer Crawler. Stell dich daneben, um zu reden.")
		parts.append("[b]%s[/b]\n%s · HP %d/%d" % [Kit.col(Kit.esc(Crawlers.describe(npc)), "#8fe38f" if party else "#7cc4ff"), state, npc.hp, npc.maxHp])
	var trap = Traps.known_trap_at(s, tp)
	if trap != null:
		var own: bool = trap.get("owner") == "crawler"
		parts.append("[b]%s[/b]" % Kit.col(("Deine " if own else "") + Kit.esc(Traps.trap_name(trap.kind)), "#6ee07a" if own else "danger"))
	var items := Game.items_at(s, tp)
	if not items.is_empty():
		var lines: Array = []
		for e in items:
			var seen := Identify.item_at_distance(s, e.item, tp)
			if seen.state == "fern":
				var far := Kit.muted(Kit.esc(seen.text))
				if not lines.has(far):
					lines.append(far)
				continue
			var look := Sprites.item_sprite(e.item)
			var line := Kit.img(look[0], look[1], 0.5) + " " + Kit.col(Kit.esc(seen.text), GameTabs.rarity_color(e.item.rarity))
			if detail and seen.state == "erkannt":
				var d := Identify.describe_item(s, e.item)
				var extra: Array = []
				if not d.bonuses.is_empty():
					extra.append(", ".join(d.bonuses))
				var nf = d.get("note") if d.get("note") != null else d.get("flavor")
				if nf != null:
					extra.append(nf)
				if not extra.is_empty():
					line += "\n" + Kit.small(Kit.muted(Kit.esc(" – ".join(extra))))
			lines.append(line)
		parts.append("\n".join(lines))
	var ri: int = m.roomAt[i]
	var room = m.rooms[ri] if ri >= 0 else null
	var fu = MapGen.furniture_at(m, tp)
	if fu != null:
		parts.append("[b]%s[/b]\n%s" % [Kit.col(FURNITURE_TEXT.get(fu.kind, fu.kind), "#9fd0ff"), Kit.small(Kit.muted("Hineinlaufen zum Benutzen"))])
	if m.tiles[i] == "stairs":
		parts.append("[b]%s[/b]" % Kit.col("Treppenhaus nach unten", "#ffcc33"))
	if J.some(BossFight.danger_tiles(s), func(q): return q.x == tp.x and q.y == tp.y):
		parts.append("[b]%s[/b]\n%s" % [Kit.col("Gefahrenzone", "#ff5a3a"), Kit.small(Kit.muted("Hier schlägt im nächsten Zug ein Spezialangriff ein. Weg da!"))])
	if TERRAIN_TEXT.has(m.tiles[i]):
		var tt: Array = TERRAIN_TEXT[m.tiles[i]]
		parts.append("[b]%s[/b]\n%s" % [Kit.col(tt[0], tt[1]), Kit.small(Kit.muted(tt[2]))])
	if m.tiles[i] == "door" and Dungeon.lock_at(s, tp) != null:
		parts.append("[b]%s[/b]\n%s" % [Kit.col("Verschlossene Tür", "#feae34"), Kit.small(Kit.muted("Mit dem passenden Schlüssel aufschließen oder das Schloss knacken."))])
	if (m.tiles[i] == "door" or m.tiles[i] == "dooropen") and Game.is_lair_door(s, tp):
		parts.append("[b]%s[/b]\n%s" % [Kit.col("Tür zur Boss-Kammer", "#ff7a6a"), Kit.small(Kit.muted("Sie verriegelt sich hinter dir, bis der Boss besiegt ist."))])
	if room != null and room.get("visited", false):
		parts.append(Kit.small(Kit.muted(Kit.esc(room.name))))
	return "\n".join(parts) if not parts.is_empty() else null


# ================================================================ Boxen

## Enthüllte Gegenstände. Mit tier (Box-Stufe) springt vorher eine Truhe auf.
static func reveal_items(gv: GameView, title: String, items: Array, tier: Variant = null) -> Modals.Job:
	return gv.modals().html(title, func(root: VBoxContainer):
		var delay := _chest(root, tier)
		var list := Kit.vbox(root, 8)
		for n in items.size():
			var v := GameTabs.item_card(gv, list, items[n], false)
			_pop(v.get_parent(), delay + n * 0.25), "Super!")


## Boxen öffnen (eine, alle einer Art und Stufe oder alle): Eine Box nach
## der anderen springt mit ihrer Truhe auf, erst „Nächste Box“ öffnet die
## nächste. „Schließen“ lässt die übrigen zu.
static func open_boxes(gv: GameView, uids: Array) -> Modals.Job:
	var list: Array = uids.filter(func(u): return J.some(gv.s.player.boxes, func(x): return x.uid == u))
	if list.is_empty() or not gv.act(func(): return {"ok": true}):
		return null
	if not Combat.can_open_boxes(gv.s, gv.s.player.pos):
		Log.add(gv.s, "Lootboxen kannst du nur in einem Safe Room oder einer Gilde öffnen.", "info")
		gv.refresh()
		return null
	return show_boxes(gv, list)


## Eine Box öffnen, während das Box-Fenster offen ist (gv.act wartet sonst
## auf das Fenster). Neue Dialoge stellen sich hinten an.
static func _open_one(gv: GameView, uid: String) -> Variant:
	var box = J.find(gv.s.player.boxes, func(x): return x.uid == uid)
	if box == null:
		return null
	var res := Game.open_box(gv.s, uid)
	var sfx := Fx.drain_sfx(gv.s)
	Fx.drain_fx(gv.s)
	if gv.sound():
		gv.sound().play_sfx(sfx)
	gv.after_action()
	if not res.get("ok", false):
		if res.get("message") != null:
			Log.add(gv.s, res.message, "info")
		return null
	return {"name": box.name, "items": res.contents, "tier": box.box.tier}


## Boxen nacheinander öffnen und zeigen.
static func show_boxes(gv: GameView, uids: Array) -> Modals.Job:
	var build := func(root: VBoxContainer, close: Callable) -> void:
		var st := {"i": 0}
		var title := Modals.title(root, "")
		var counter := Kit.label(root, "", 13, "muted")
		var stage := Kit.vbox(root, 8)
		var f := Modals.foot(root)
		f[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
		Kit.button(f[1], "Schließen", func(): close.call(), "Button", false, "Die übrigen Boxen bleiben zu und warten im Inventar")
		var next := Kit.button(f[1], "Weiter", Callable(), "PrimaryButton")
		var show := func() -> bool:
			Kit.clear(stage)
			var b = _open_one(gv, uids[st.i])
			if b == null:
				return false
			title.text = b.name
			title.add_theme_color_override("font_color", Color(String(Db.world("BOX_TIER_COLORS").get(b.tier, "#ffd34a"))).lightened(0.2))
			var left: int = uids.size() - st.i - 1
			counter.text = ("Box %d von %d" % [st.i + 1, uids.size()]) if uids.size() > 1 else ""
			var delay := _chest(stage, b.tier)
			# Fundstücke in einem eigenen Bereich, damit die Knöpfe immer
			# sichtbar bleiben
			var sc := ScrollContainer.new()
			sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			sc.custom_minimum_size = Vector2(0, 260)
			stage.add_child(sc)
			var lst := Kit.vbox(sc, 8)
			lst.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			for n in b.items.size():
				var v := GameTabs.item_card(gv, lst, b.items[n], false)
				_pop(v.get_parent(), delay + n * 0.35)
			next.text = ("Nächste Box (%d übrig)" % left) if left > 0 else "Super!"
			return true
		var advance := func() -> void:
			if st.i < uids.size() - 1:
				st.i += 1
				if not show.call():
					close.call()
			else:
				close.call()
		next.pressed.connect(advance)
		gv.modals()._job.on_key = func(ev: InputEventKey) -> void:
			if ev.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
				advance.call()
			elif ev.keycode == KEY_ESCAPE:
				close.call()
		if not show.call():
			close.call.call_deferred()
	return gv.modals().custom(build, 700)


## Truhe über den Gegenständen; gibt zurück, wie lange die Karten warten.
static func _chest(root: VBoxContainer, tier: Variant) -> float:
	if tier == null:
		return 0.0
	var c := Chest.new()
	c.tier = String(tier)
	c.color = Color(String(Db.world("BOX_TIER_COLORS").get(c.tier, "#c8a060")))
	c.sound = SoundBox.instance
	c.setup()
	root.add_child(c)
	return c.open_at + 0.35


## Die Truhe wackelt, springt auf, strahlt in der Farbe der Box-Stufe und
## sprüht Funken. Je wertvoller die Stufe, desto länger die Spannung und desto
## prächtiger der Auftritt:
##   Bronze: Staubwolke und ein paar Funken
##   Silber: vier Strahlen, silbernes Glitzern
##   Gold: acht Strahlen, Licht dringt schon vorher aus den Ritzen, Goldregen
##   Platin: Lichtringe, eisblaues Funkeln, die Truhe bebt beim Aufspringen
##   Legendär: drehende Strahlen, aufsteigende Glut
##   Himmlisch: drehender Strahlenkranz, Sternenhimmel in allen Farben
## Alles in Kunstpixeln (PX Bildschirmpixel). Strahlen und Leuchten zeichnet die
## Truhe selbst (additiv), Truhe und Funken ein Kind davor.
class Chest:
	extends Control
	## Strahlenraster und Kunstpixel der Truhe (32er-Bild, 192 Bildschirmpixel breit)
	const PX := 8
	const ART := 6
	const R := 22
	var tier := "bronze"
	var color := Color.WHITE
	var sound: SoundBox = null
	## Stufe 0 (Bronze) bis 5 (Himmlisch) und wann die Truhe aufspringt.
	var level := 0
	var open_at := 0.9
	var _t0 := 0.0
	var _played := false
	var _front := Control.new()

	func setup() -> void:
		level = maxi(0, Db.world("BOX_TIERS").find(tier))
		open_at = 1.5 + level * 0.35

	func _init() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		custom_minimum_size = Vector2(0, 300)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = mat
		_front.set_anchors_preset(Control.PRESET_FULL_RECT)
		_front.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_front.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_front.draw.connect(_draw_front)
		add_child(_front)
		_t0 = Time.get_ticks_msec() / 1000.0

	func elapsed() -> float:
		return Time.get_ticks_msec() / 1000.0 - _t0

	func _process(_d: float) -> void:
		# Der Klang knarzt zuerst und macht nach 0,3 s „Plopp“
		if not _played and elapsed() >= open_at - 0.3:
			_played = true
			if sound != null:
				sound.play_box(tier)
		queue_redraw()
		_front.queue_redraw()

	func _origin() -> Vector2:
		return Vector2(floorf(size.x / 2.0 / PX) * PX - 16 * ART, size.y - 24 * ART)

	## Mitte der Öffnung, auf dem Pixelraster.
	func _mid() -> Vector2:
		return _origin() + Vector2(16 * ART, 12 * ART)

	func _square(at: Vector2, c: Color) -> void:
		draw_rect(Rect2(at, Vector2(PX, PX)), c)

	func _draw() -> void:
		var t := elapsed()
		var k := t - open_at
		var mid := _mid()
		var glow := color.lightened(0.35)
		# Ab Gold dringt schon vor dem Aufspringen Licht aus den Ritzen
		if k < 0.0:
			if level >= 2:
				var pre := clampf(t / open_at, 0.0, 1.0)
				for gx in range(-3, 4):
					var a := pre * pre * (0.9 - absf(gx) * 0.18) * (0.75 + 0.25 * sin(t * 18.0 + gx))
					if a > 0.05:
						_square(mid + Vector2(gx, -1) * PX, Color(glow, ceilf(a * 4.0) / 4.0))
			return
		var intro := minf(1.0, k / 0.25)
		# Strahlen je Stufe: Bronze keine, Silber 4, Gold und Platin 8, darüber
		# 12 bzw. 16, ab Legendär drehen sie sich langsam
		var count: int = [0, 4, 8, 8, 12, 16][mini(level, 5)]
		var spin := k * 0.5 if level >= 4 else 0.0
		var rays: Array = []
		for i in count:
			var q := i * TAU / count + spin
			var pulse := 0.85 + 0.15 * sin(k * 5.0 + i * 1.7)
			rays.append([Vector2(cos(q), sin(q)), (R if i % 2 == 0 else R * 0.8) * PX * pulse * (0.7 if level == 1 else 1.0)])
		for gy in range(-R, R + 1):
			for gx in range(-R, R + 1):
				var v := (Vector2(gx, gy) + Vector2(0.5, 0.5)) * PX
				var d := v.length()
				if d > R * PX:
					continue
				# Helle Scheibe um die Öffnung (wächst mit der Stufe)
				var a := 0.85 * clampf(1.0 - d / ((3.0 + level * 0.8) * PX), 0.0, 1.0)
				for ray in rays:
					var dir: Vector2 = ray[0]
					var reach: float = ray[1]
					var along := v.dot(dir)
					if along <= 0.0 or along >= reach:
						continue
					var perp := absf(v.x * dir.y - v.y * dir.x)
					if perp < PX * 0.7:
						a = maxf(a, 0.95 * pow(1.0 - along / reach, 0.6))
				a = ceilf(a * intro * 4.0) / 4.0
				if a > 0.0:
					_square(mid + Vector2(gx, gy) * PX, Color(glow, a))
		# Heller Ring beim Aufspringen, ab Platin wiederkehrende Lichtringe
		if k < 0.3:
			var rad := 3.0 * PX + k * 360.0
			for i in 28:
				var q := i * TAU / 28.0
				_square((mid + Vector2(cos(q), sin(q)) * rad / PX).floor() * PX, Color(1, 1, 1, 1.0 - k / 0.3))
		if level >= 3:
			var ph := fmod(k, 0.9) / 0.9
			var rr := (3.0 + ph * (R - 3)) * PX
			for i in 36:
				var q := i * TAU / 36.0
				_square((mid + Vector2(cos(q), sin(q)) * rr / PX).floor() * PX, Color(glow, 0.6 * (1.0 - ph) * intro))

	func _draw_front() -> void:
		var t := elapsed()
		var origin := _origin()
		var spark := color.lightened(0.45)
		if t < open_at:
			# Immer stärkeres Wackeln, kurz vor dem Aufspringen hüpft die Truhe
			var amp := 1.0 + (2.0 + level * 0.6) * t / open_at
			var dx := roundf(sin(t * 55.0) * amp) * 2.0
			var hop := -roundf(maxf(0.0, sin((t / open_at) * PI * (2 + level))) * level * 1.5) * 2.0 if t > open_at * 0.5 else 0.0
			PixelArt.draw(_front, "ding/truhe", origin + Vector2(dx, hop), ART, color)
			return
		var k := t - open_at
		var mid := _mid()
		# Ab Platin bebt die Truhe beim Aufspringen
		var shake := Vector2.ZERO
		if level >= 3 and k < 0.35:
			shake = Vector2(roundf(sin(k * 90.0) * 2.0) * 2.0, roundf(cos(k * 70.0)) * 2.0)
		PixelArt.draw(_front, "ding/truhe_offen", origin + shake, ART, color)
		var w := size.x
		# Bronze: Staubwolke
		if level == 0 and k < 0.9:
			for i in 10:
				var a := PI + float(i) / 9.0 * PI
				var p := mid + Vector2(0, 40) + Vector2(cos(a) * 3.0, sin(a) * 0.6) * k * 70.0
				_front.draw_rect(Rect2((p / PX).floor() * PX, Vector2(PX, PX)), Color(0.75, 0.68, 0.55, 0.6 * (1.0 - k / 0.9)))
		# Gold und mehr: Goldregen über die ganze Breite
		if level >= 2 and k < 2.4:
			for i in 26:
				var x := fmod(float(i * 97 % 101) / 101.0 * w + i * 13.0, w)
				var y := -20.0 + fmod(k * (160.0 + (i % 5) * 30.0) + i * 23.0, size.y + 30.0)
				var c := Color("#ffd700") if i % 3 else Color("#fff4b0")
				_front.draw_rect(Rect2(Vector2(floorf(x / 4) * 4, floorf(y / 4) * 4), Vector2(8, 4) if i % 2 else Vector2(4, 8)), Color(c, 0.9 * minf(1.0, (2.4 - k) / 0.6)))
		# Legendär: aufsteigende Glut
		if level == 4:
			for i in 18:
				var ph := fmod(k * 0.5 + i / 18.0, 1.0)
				var p := mid + Vector2(float((i * 29) % 21 - 10) * PX * 0.8 + sin(ph * 6.0 + i) * 6.0, -ph * 180.0)
				_front.draw_rect(Rect2((p / 4).floor() * 4, Vector2(4, 4)), Color(Color("#ff7a1a") if i % 2 else Color("#ffd04a"), sin(ph * PI)))
		# Himmlisch: funkelnder Sternenhimmel in allen Farben
		if level >= 5:
			var cols := [Color("#ff8ad8"), Color("#8ad8ff"), Color("#fff08a"), Color("#b08aff"), Color("#8affb0")]
			for i in 40:
				var p := Vector2(fmod(i * 173.0, maxf(1.0, w)), fmod(i * 61.0, size.y - 20.0))
				var tw := 0.5 + 0.5 * sin(k * 4.0 + i * 1.3)
				var sz := 4.0 if tw < 0.8 else 8.0
				_front.draw_rect(Rect2((p / 4).floor() * 4, Vector2(sz, sz)), Color(cols[i % cols.size()], tw * minf(1.0, k / 0.5)))
		# Funken: ein Schwall nach oben, der zurückfällt, dann steigendes Glitzern
		if k < 1.4:
			for i in 8 + level * 6:
				var a := -PI / 2 + (float((i * 37) % 16) / 15.0 - 0.5) * 2.2
				var speed := 150.0 + float((i * 53) % 7) * 22.0
				var p := mid + Vector2(cos(a), sin(a)) * speed * k + Vector2(0, 170.0 * k * k)
				var c := Color(Color.WHITE if i % 3 == 0 else spark, 1.0 - k / 1.4)
				_front.draw_rect(Rect2((p / (PX / 2)).floor() * (PX / 2), Vector2(PX / 2, PX / 2) * (2 if i % 4 == 0 else 1)), c)
		for i in 6:
			var ph := fmod(k * 0.6 + i / 6.0, 1.0)
			var p := mid + Vector2(float((i * 41) % 11 - 5) * PX, -ph * 90.0 - 12.0)
			_front.draw_rect(Rect2((p / (PX / 2)).floor() * (PX / 2), Vector2(PX / 2, PX / 2)), Color(spark, sin(ph * PI) * 0.9 * minf(1.0, k / 0.25)))


## Aufploppen wie die CSS-Animation „pop“.
static func _pop(c: Control, delay: float) -> void:
	c.modulate.a = 0.0
	c.pivot_offset = Vector2(150, 30)
	c.scale = Vector2(0.8, 0.8)
	var tw := c.create_tween().set_parallel()
	tw.tween_property(c, "modulate:a", 1.0, 0.4).set_delay(delay)
	tw.tween_property(c, "scale", Vector2.ONE, 0.4).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ================================================================ Versus

## Porträt einer Figur für den Versus-Bildschirm (Pixel-Figur, 10× vergrößert).
class Portrait:
	extends Control
	var draw_fn: Callable

	func _init() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func _draw() -> void:
		draw_fn.call(self)


## Versus-Bildschirm beim Betreten einer Boss-Kammer: Crawler gegen Boss.
static func maybe_versus(gv: GameView) -> void:
	var s := gv.s
	var uid = s.get("pendingVersus")
	if uid == null:
		return
	s.erase("pendingVersus")
	var boss = J.find(s.monsters, func(m): return m.uid == uid)
	if boss == null:
		return
	var info := Identify.describe_monster(s, boss)
	var p: Dictionary = s.player
	var klass = Db.klass(p.klass).name if p.get("klass") != null else null
	var race = GameTabs.race_name(p.race) if p.get("race") != null else null
	var rank := "Borough-Boss" if boss.rank == "boroughboss" else "Nachbarschafts-Boss"
	if gv.sound():
		gv.sound().play_versus()
	var who := " · ".join([race, klass].filter(func(x): return x != null))
	var build := func(root: VBoxContainer, close: Callable) -> void:
		var row := Kit.hbox(root, 10)
		var left := Kit.vbox(row, 2)
		var hero := Portrait.new()
		hero.custom_minimum_size = Vector2(220, 240)
		hero.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var hero_look := Sprites.hero_name(p)
		hero.draw_fn = func(ci: CanvasItem): Sprites.draw_hero(ci, Vector2(110, 236), 3, false, hero_look)
		left.add_child(hero)
		_center_label(left, p.name, 30, UiTheme.ACCENT, 700, true)
		_center_label(left, "%s · Level %d" % [who if who != "" else "Crawler", p.level], 13, UiTheme.MUTED)
		_center_label(left, "HP %d / %d" % [maxi(0, p.hp), Player.max_hp(s)], 13, UiTheme.MUTED)
		var vs := Kit.label(row, "VS", 80, Color.WHITE)
		vs.add_theme_font_override("font", UiFonts.pixel(700))
		vs.add_theme_color_override("font_outline_color", Color("#c8321e"))
		vs.add_theme_constant_override("outline_size", 12)
		vs.add_theme_color_override("font_shadow_color", Color("#e9aa2c"))
		vs.add_theme_constant_override("shadow_offset_x", 4)
		vs.add_theme_constant_override("shadow_offset_y", 4)
		vs.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var right := Kit.vbox(row, 2)
		var bp := Portrait.new()
		bp.custom_minimum_size = Vector2(220, 240)
		bp.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var look := Sprites.sprite_name(boss.defId)
		var col = boss.color
		var unk: bool = info.insight >= 3
		bp.draw_fn = func(ci: CanvasItem): Sprites.draw_portrait(ci, look, col, Vector2(110, 226), 6, {"crown": true, "flip": true, "unknown": unk})
		right.add_child(bp)
		_center_label(right, info.name, 30, Color("#ff7a6a"), 700, true)
		_center_label(right, "%s · %s" % [rank, info.level], 13, UiTheme.MUTED)
		_center_label(right, info.challenge.name, 13, Color(info.challenge.color))
		# Beide Seiten blenden nacheinander ein, dann springt das VS herein
		for pair in [[left, 0.0], [right, 0.12]]:
			var c: Control = pair[0]
			c.modulate.a = 0.0
			c.create_tween().tween_property(c, "modulate:a", 1.0, 0.5).set_delay(pair[1])
		vs.pivot_offset = Vector2(50, 40)
		vs.scale = Vector2(2.4, 2.4)
		vs.rotation = -0.2
		vs.modulate.a = 0.0
		var tv := vs.create_tween().set_parallel()
		tv.tween_property(vs, "scale", Vector2.ONE, 0.45).set_delay(0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tv.tween_property(vs, "rotation", 0.0, 0.45).set_delay(0.3)
		tv.tween_property(vs, "modulate:a", 1.0, 0.2).set_delay(0.3)
		if info.flavor != null:
			Kit.spacer(root, 6)
			Kit.text(root, "[center][i]%s[/i][/center]" % Kit.esc(info.flavor), 14, "muted")
		var f := Modals.foot(root)
		f[0].text = "Die Tür ist verriegelt, bis einer von euch am Boden liegt."
		f[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
		Kit.button(f[1], "Kampf!", func():
			close.call()
			gv.refresh(), "PrimaryButton")
		gv.modals()._job.on_key = func(ev: InputEventKey) -> void:
			if ev.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
				close.call()
				gv.refresh()
	gv.modals().custom(build, 820, "VersusModal")


static func _center_label(parent: Node, text: String, size: int, color: Color, weight: int = 400, pixel: bool = false) -> void:
	var l := Kit.label(parent, text, size, color, 400 if pixel else weight)
	if pixel:
		l.add_theme_font_override("font", UiFonts.pixel(weight))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(240, 0)


# ================================================================ Talkshow

## Die Talkshow: Einleitung, dann Fragen mit Antwortmöglichkeiten.
static func run_talk_show(gv: GameView, title: String, intro: Array) -> Modals.Job:
	var s := gv.s
	var build := func(root: VBoxContainer, close: Callable) -> void:
		Modals.title(root, title)
		Modals.speaker(root, String(J.nn(s.get("talkShow"), "host", "")))
		var q_el := Modals.page(root)
		var a_el := Kit.vbox(root, 6)
		var f := Modals.foot(root)
		var no_el: RichTextLabel = f[0]
		no_el.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var f_el := Kit.text(f[1], "", 12, "muted")
		f_el.autowrap_mode = TextServer.AUTOWRAP_OFF
		var st := {"typing": null, "page": 0}
		var type := func(bb: String) -> void:
			var ty = st.typing
			if ty != null and is_instance_valid(ty):
				ty.finish()
			st.typing = Typing.type_text(q_el, bb, 18)
		var busy := func() -> bool:
			var ty = st.typing
			return ty != null and is_instance_valid(ty) and not ty.is_done()
		var one_button := func(label: String, on_click: Callable) -> void:
			Kit.clear(a_el)
			var b := Kit.button(a_el, label, func():
				# Erster Klick zeigt den Text sofort ganz, zweiter geht weiter
				if busy.call():
					st.typing.finish()
				else:
					on_click.call(), "PrimaryButton")
			b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		var follower := func() -> void:
			var d: int = int(J.num(s.get("talkShow"), "followerDelta"))
			f_el.text = "Follower %s (%s%s in dieser Sendung)" % [J.de(s.viewers.follower), "+" if d >= 0 else "", J.de(d)]
		var fns := {}
		fns.intro = func() -> void:
			no_el.text = "Einleitung %d / %d" % [st.page + 1, intro.size()]
			type.call(Kit.esc(intro[st.page]))
			one_button.call("Weiter" if st.page < intro.size() - 1 else "Los geht's", func():
				st.page += 1
				if st.page < intro.size():
					fns.intro.call()
				else:
					fns.ask.call())
		fns.ask = func() -> void:
			var show = s.get("talkShow")
			if show == null or show.get("done", false):
				close.call()
				return
			var q: Dictionary = show.questions[show.index]
			no_el.text = "%s %d von %d" % [J.nn(show, "roundLabel", "Frage"), show.index + 1, show.questions.size()]
			follower.call()
			type.call(Kit.esc(q.text))
			Kit.clear(a_el)
			var tones: Dictionary = Db.t("talkshow", "TONE_NAMES")
			for i in q.answers.size():
				var a: Dictionary = q.answers[i]
				var idx: int = i
				var cp := Kit.rbutton(a_el, "%s %s" % [Kit.small(Kit.muted(Kit.esc(tones[a.tone]) + ":")), Kit.esc(a.label)], func(): fns.answer.call(idx), "Button", false, "", 14)
				cp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fns.answer = func(i: int) -> void:
			var res := Game.answer_talk_show(s, i)
			if not res.get("ok", false):
				close.call()
				return
			follower.call()
			var d := int(J.nn(res, "delta", 0))
			var bb := Kit.esc(J.nn(res, "reaction", ""))
			bb += "\n\n[b]%s[/b]" % Kit.col("%s%s Follower" % ["+" if d >= 0 else "", J.de(d)], "ok" if d >= 0 else "danger")
			var fin: bool = res.get("finished", false)
			if fin:
				bb += "\n\n" + Kit.esc(J.nn(res, "outro", ""))
			type.call(bb)
			one_button.call("Zurück in den Dungeon" if fin else "Nächste Frage", func():
				if not fin:
					fns.ask.call()
					return
				close.call()
				gv.refresh())
		fns.intro.call()
	return gv.modals().custom(build)


# ================================================================ Hilfe

## Alle Tasten und Bedienhinweise auf einen Blick.
static func show_help(gv: GameView) -> void:
	var rows := [
		["Laufen", "Klick auf den Boden: frei dorthin laufen · linke Maustaste gedrückt halten: der Maus folgen · Pfeiltasten (zwei zugleich = schräg) oder Ziffernblock"],
		["Kampfrunde", "Pro Runde Bewegung (in Metern) und eine Aktion · Klick auf den Boden läuft frei dorthin, die Linie zeigt grün, was noch reicht · Klick auf einen Gegner läuft hin und greift an · Enter greift das gewählte Ziel an · Leertaste beendet die Runde"],
		["Körperteil", "1 Faust · 2 Tritt · 3 Knie · 4 Ellbogen · 5 Kopfstoß · 6 Waffe · 7 Wurf"],
		["Ausführung", "Q Normal · W Sprung · E Stampfen · R Anlauf"],
		["Trefferzone", "Y Kopf · X Körper · C Arme · V Beine"],
		["Ziel wechseln", "Tab"],
		["Warten / Runde beenden", "Leertaste (wer brennt, wälzt sich am Boden)"],
		["Spurt", "S im Kampf: Die Aktion der Runde wird zu Bewegung (noch einmal der volle Vorrat, 2 Ausdauer)"],
		["Aufheben", "G"],
		["Treppe nehmen", "Enter auf der Treppe"],
		["Klassenfähigkeit", "F (ab Etage 3)"],
		["Reittier", "M"],
		["Zoom", "Mausrad · Plus und Minus"],
		["Übersichtskarte", "K oder Klick auf die kleine Karte"],
		["Rechtsklick", "Menü mit allem, was auf dem Feld geht: aufheben, angreifen, ansprechen, benutzen, öffnen, untersuchen, hingehen"],
		["Text sofort zeigen", "Knopf „Text überspringen“ unten, Klick auf den Text oder „Überspringen“ im Chat"],
		["Reiter oben", "P Crawler · Z Ziele · I Inventar · A Ausrüstung · B Handwerk · L Skills · O Erfolge · klappen über dem Spielfeld auf, dieselbe Taste, Esc oder ein Klick daneben klappt zu · Tab blättert (außerhalb des Kampfes)"],
		["Bereich „Hier“", "N klappt ein und aus"],
		["Chat links", "Alles, was passiert. Filter: Alles, Kampf, Funde, Gespräche. „Überspringen“ zeigt alle Zeilen sofort"],
		["Menü", "Esc (Ton, Musik, Tippgeräusch)"],
		["Hilfe", "H"],
	]
	gv.modals().html("Steuerung", func(root: VBoxContainer):
		var g := Kit.grid(root, 2, 16, 8)
		for r in rows:
			Kit.label(g, r[0], 14, UiTheme.ACCENT, 700)
			Kit.text(g, Kit.esc(r[1]), 14))
