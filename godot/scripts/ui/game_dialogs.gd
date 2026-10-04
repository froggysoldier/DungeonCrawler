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


## Mehrere Boxen auf einmal: Inhalt nach Box gruppiert, die Truhe in der besten Stufe.
static func reveal_boxes(gv: GameView, list: Array) -> Modals.Job:
	var tiers: Array = Db.world("BOX_TIERS")
	var best = null
	for b in list:
		if b.get("tier") != null and (best == null or tiers.find(b.tier) > tiers.find(best)):
			best = b.tier
	return gv.modals().html("%d Lootboxen geöffnet" % list.size(), func(root: VBoxContainer):
		var delay := _chest(root, best)
		for bi in list.size():
			var b: Dictionary = list[bi]
			Kit.section(root, b.name)
			var box := Kit.vbox(root, 8)
			for n in b.items.size():
				var v := GameTabs.item_card(gv, box, b.items[n], false)
				_pop(v.get_parent(), delay + minf(2.0, bi * 0.15 + n * 0.08)), "Super!")


## Truhe über den Gegenständen; gibt zurück, wie lange die Karten warten.
static func _chest(root: VBoxContainer, tier: Variant) -> float:
	if tier == null:
		return 0.0
	var c := Chest.new()
	c.tier = String(tier)
	c.color = Color(String(Db.world("BOX_TIER_COLORS").get(c.tier, "#c8a060")))
	c.sound = SoundBox.instance
	root.add_child(c)
	return Chest.OPEN_AT + 0.2


## Die Truhe wackelt, springt auf, strahlt in der Farbe der Box-Stufe und
## sprüht Funken. Alles in Kunstpixeln (PX Bildschirmpixel). Strahlen und
## Leuchten zeichnet die Truhe selbst (additiv), Truhe und Funken ein Kind davor.
class Chest:
	extends Control
	const OPEN_AT := 0.8
	## Strahlenraster und Kunstpixel der Truhe (32er-Bild, 128 Bildschirmpixel breit)
	const PX := 8
	const ART := 4
	const R := 17
	var tier := "bronze"
	var color := Color.WHITE
	var sound: SoundBox = null
	var _t0 := 0.0
	var _played := false
	var _front := Control.new()

	func _init() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		custom_minimum_size = Vector2(0, 196)
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
		if not _played and elapsed() >= OPEN_AT - 0.3:
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
		var k := elapsed() - OPEN_AT
		if k < 0.0:
			return
		var intro := minf(1.0, k / 0.25)
		var glow := color.lightened(0.35)
		var mid := _mid()
		# Acht Strahlen in festen Richtungen (sauber im Pixelraster): gerade lang
		# und zwei Pixel breit, schräge kürzer; sie pulsieren
		var rays: Array = []
		for i in 8:
			var q := i * TAU / 8.0
			var pulse := 0.85 + 0.15 * sin(k * 5.0 + i * 1.7)
			rays.append([Vector2(cos(q), sin(q)), (R if i % 2 == 0 else R * 0.8) * PX * pulse])
		for gy in range(-R, R + 1):
			for gx in range(-R, R + 1):
				var v := (Vector2(gx, gy) + Vector2(0.5, 0.5)) * PX
				var d := v.length()
				if d > R * PX:
					continue
				# Helle Scheibe um die Öffnung
				var a := 0.85 * clampf(1.0 - d / (4.5 * PX), 0.0, 1.0)
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
		# Heller Ring beim Aufspringen
		if k < 0.3:
			var rad := 3.0 * PX + k * 360.0
			for i in 28:
				var q := i * TAU / 28.0
				_square((mid + Vector2(cos(q), sin(q)) * rad / PX).floor() * PX, Color(1, 1, 1, 1.0 - k / 0.3))

	func _draw_front() -> void:
		var t := elapsed()
		var origin := _origin()
		if t < OPEN_AT:
			# Immer stärkeres Wackeln
			var amp := 1.0 + 2.0 * t / OPEN_AT
			var dx := roundf(sin(t * 55.0) * amp) * 2.0
			PixelArt.draw(_front, "ding/truhe", origin + Vector2(dx, 0), ART, color)
			return
		var k := t - OPEN_AT
		var mid := _mid()
		PixelArt.draw(_front, "ding/truhe_offen", origin, ART, color)
		# Funken: ein Schwall nach oben, der zurückfällt, dann steigendes Glitzern
		var spark := color.lightened(0.45)
		if k < 1.4:
			for i in 16:
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
		["Laufen", "Klick auf ein bekanntes Feld · Pfeiltasten oder Ziffernblock (gedrückt halten = weiterlaufen)"],
		["Angreifen", "Klick auf einen Gegner oder in ihn hineinlaufen · im Kampf Enter"],
		["Körperteil", "1 Faust · 2 Tritt · 3 Knie · 4 Ellbogen · 5 Kopfstoß · 6 Waffe · 7 Wurf"],
		["Ausführung", "Q Normal · W Sprung · E Stampfen · R Anlauf"],
		["Trefferzone", "Y Kopf · X Körper · C Arme · V Beine"],
		["Ziel wechseln", "Tab"],
		["Warten", "Leertaste (wer brennt, wälzt sich am Boden)"],
		["Aufheben", "G"],
		["Treppe nehmen", "Enter auf der Treppe"],
		["Klassenfähigkeit", "F (ab Etage 3)"],
		["Reittier", "M"],
		["Zoom", "Mausrad · Plus und Minus"],
		["Übersichtskarte", "K oder Klick auf die kleine Karte"],
		["Untersuchen", "Rechtsklick auf Feld, Gegner oder Gegenstand"],
		["Text sofort zeigen", "Klick auf den Text oder das Log"],
		["Reiter", "P Crawler · Z Ziele · I Inventar · B Handwerk · L Skills · O Erfolge · Tab blättert (außerhalb des Kampfes)"],
		["Bereich „Hier“", "N klappt ein und aus"],
		["Log", "Filter oben rechts im Log: Alles, Kampf, Beute und Erfolge, Gespräche"],
		["Menü", "Esc (Ton, Musik, Tippgeräusch)"],
		["Hilfe", "H"],
	]
	gv.modals().html("Steuerung", func(root: VBoxContainer):
		var g := Kit.grid(root, 2, 16, 8)
		for r in rows:
			Kit.label(g, r[0], 14, UiTheme.ACCENT, 700)
			Kit.text(g, Kit.esc(r[1]), 14))
