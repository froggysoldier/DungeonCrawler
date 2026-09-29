class_name GameDialogs
extends RefCounted
## Dialoge und Hinweise der Spielansicht: Tooltip,
## Box-Inhalte, Versus-Bildschirm, Talkshow und die Tastenhilfe.

const FURNITURE_TEXT := {
	"automat": "Gratis-Automat – ein Gegenstand pro Crawler", "haendler": "Händler – kaufen, verkaufen, feilschen",
	"wirt": "Wirt – Essen und ein Zimmer zum Schlafen", "bett": "Bett – acht Stunden Schlaf", "toilette": "Toilette – die Regel gilt",
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
		var fig := Kit.img(look[0], look[1], 2 if PixelArt.size_of(look[0]).y <= 16 else 1)
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
			var look := Sprites.item_sprite(e.item)
			var line := Kit.img(look[0], look[1]) + " " + Kit.col(Kit.esc(Identify.item_name(s, e.item)), GameTabs.rarity_color(e.item.rarity))
			if detail:
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
	if (m.tiles[i] == "door" or m.tiles[i] == "dooropen") and Game.is_lair_door(s, tp):
		parts.append("[b]%s[/b]\n%s" % [Kit.col("Tür zur Boss-Kammer", "#ff7a6a"), Kit.small(Kit.muted("Sie verriegelt sich hinter dir, bis der Boss besiegt ist."))])
	if room != null and room.get("visited", false):
		parts.append(Kit.small(Kit.muted(Kit.esc(room.name))))
	return "\n".join(parts) if not parts.is_empty() else null


# ================================================================ Boxen

static func reveal_items(gv: GameView, title: String, items: Array) -> Modals.Job:
	return gv.modals().html(title, func(root: VBoxContainer):
		var list := Kit.vbox(root, 8)
		for n in items.size():
			var v := GameTabs.item_card(gv, list, items[n], false)
			_pop(v.get_parent(), n * 0.25), "Super!")


## Mehrere Boxen auf einmal: Inhalt nach Box gruppiert.
static func reveal_boxes(gv: GameView, list: Array) -> Modals.Job:
	return gv.modals().html("%d Lootboxen geöffnet" % list.size(), func(root: VBoxContainer):
		for bi in list.size():
			var b: Dictionary = list[bi]
			Kit.section(root, b.name)
			var box := Kit.vbox(root, 8)
			for n in b.items.size():
				var v := GameTabs.item_card(gv, box, b.items[n], false)
				_pop(v.get_parent(), minf(2.0, bi * 0.15 + n * 0.08)), "Super!")


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
		hero.draw_fn = func(ci: CanvasItem): Sprites.draw_hero(ci, Vector2(110, 226), 10, false, hero_look)
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
		# Eigene Boss-Figuren sind größer: kleiner vergrößern, damit sie ins Bild passen
		var sc := 10 if PixelArt.size_of(look).y <= 16 else 8
		bp.draw_fn = func(ci: CanvasItem): Sprites.draw_portrait(ci, look, col, Vector2(110, 226), sc, {"crown": true, "flip": true, "unknown": unk})
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
		Modals.speaker(root, "Veronika Glanz")
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
			one_button.call("Weiter" if st.page < intro.size() - 1 else "Zur ersten Frage", func():
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
			no_el.text = "Frage %d von %d" % [show.index + 1, show.questions.size()]
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
		["Hilfe", "H"],
	]
	gv.modals().html("Steuerung", func(root: VBoxContainer):
		var g := Kit.grid(root, 2, 16, 8)
		for r in rows:
			Kit.label(g, r[0], 14, UiTheme.ACCENT, 700)
			Kit.text(g, Kit.esc(r[1]), 14))
