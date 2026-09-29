class_name Selection
extends RefCounted
## Rassen- und Klassenwahl auf Etage 3.


static func _item_label(id: String) -> String:
	var b = Db.base_item(id)
	return b.name if b != null else id


static func _specials(parent: Node, list: Variant) -> void:
	var st: Dictionary = Db.t("specials", "SPECIAL_TEXT")
	for sp in (list if list != null else []):
		var t = st.get(sp)
		Kit.text(parent, "[b]%s:[/b] %s" % [Kit.esc(t.name if t != null else sp), Kit.muted(Kit.esc(t.text if t != null else ""))], 12)


static func _bonus(parent: Node, lines: Array) -> void:
	if not lines.is_empty():
		Kit.text(parent, Kit.esc(" · ".join(lines)), 12, "ok")


static func _head(parent: Node, bb: String) -> void:
	Kit.text(parent, "[b]%s[/b]" % Kit.col(bb, "accent"), 14)


static func _race_detail(parent: Node, r: Dictionary, p: Dictionary = {}) -> void:
	var v := Kit.card(parent, "Item", 4)
	var top := Kit.hbox(v, 12)
	# So sieht die Figur mit dieser Rasse (und der jetzigen Ausrüstung) aus
	var look := Sprites.hero_name({"race": r.id, "equipment": J.nn(p, "equipment", {})})
	var st := Kit.Stage.new()
	st.items = [{"name": look, "scale": 3, "foot": Vector2(48, 98)}]
	st.custom_minimum_size = Vector2(96, 110)
	st.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(st)
	var tv := Kit.vbox(top, 4)
	tv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_head(tv, "Rasse: " + Kit.esc(GameTabs.race_name(r.id)))
	Kit.text(tv, Kit.esc(r.description), 12)
	_bonus(v, Bonuses.describe(r.get("bonuses")))
	if r.id == "mensch":
		Kit.text(v, "[b]Anpassungsfähig:[/b] %s" % Kit.muted("4 freie Stat-Punkte zum Verteilen."), 12)
	_specials(v, r.get("specials"))
	var talent = Db.skill(r.talent) if r.get("talent") != null else null
	if talent != null:
		Kit.text(v, "[b]Begabung: %s[/b] %s" % [Kit.esc(talent.name), Kit.muted("– wird gelernt und wächst 50 % schneller. " + Kit.esc(talent.description))], 12)
	Kit.text(v, "[i]%s[/i]" % Kit.esc(r.comment), 12, "muted")


static func _class_detail(parent: Node, c: Dictionary) -> void:
	var v := Kit.card(parent, "Item", 4)
	var ab: Dictionary = Db.t("classes", "ABILITIES")[c.ability]
	_head(v, "Klasse: %s %s" % [Kit.esc(c.name), Kit.small(Kit.muted("%s · %s" % [Db.t("classes", "ARCHETYPE_NAMES")[c.archetype], Db.t("classes", "CLASS_RARITY_NAMES")[c.rarity]]))])
	Kit.text(v, Kit.esc(c.description), 12)
	_bonus(v, Bonuses.describe(c.get("bonuses")))
	Kit.text(v, "[b]Fähigkeit: %s[/b] %s – %s" % [Kit.esc(ab.name), Kit.muted("(alle %s Züge)" % J.s(ab.cooldown)), Kit.col(Kit.esc(ab.description), "info")], 12)
	Kit.text(v, "[b]Klassenskills[/b] %s" % Kit.muted("(wachsen 50 % schneller)"), 12)
	for i in c.skills.size():
		var d = Db.skill(c.skills[i])
		if d != null:
			Kit.text(v, "[b]%s[/b]%s %s" % [Kit.esc(d.name), (" " + Kit.muted("(+2 Stufen)")) if i == 0 else "", Kit.muted("– " + Kit.esc(d.description))], 12)
	var spells: Array = J.arr(c, "spells").map(func(id): return Db.spell(id)).filter(func(x): return x != null)
	if not spells.is_empty():
		Kit.text(v, "[b]Startzauber:[/b] " + ", ".join(spells.map(func(sp): return "%s %s" % [Kit.esc(sp.name), Kit.muted("(%s)" % Kit.esc(sp.description))])), 12)
	var gear := J.arr(c, "gear")
	if not gear.is_empty():
		Kit.text(v, "[b]Startausrüstung:[/b] " + Kit.esc(", ".join(gear.map(func(g): return ("%dx " % g[1] if g[1] > 1 else "") + _item_label(g[0])))), 12)
	_specials(v, c.get("specials"))
	if c.get("requirement") != null:
		Kit.text(v, "[b]Freigeschaltet durch:[/b] " + Kit.muted(Kit.esc(c.requirement.text)), 12)
	Kit.text(v, "[i]%s[/i]" % Kit.esc(c.comment), 12, "muted")


## Werte vor und nach der Wahl.
static func _stats_preview(parent: Node, s: Dictionary, r: Dictionary, c: Dictionary) -> void:
	var v := Kit.card(parent, "Item", 4)
	_head(v, "Deine Grundwerte")
	var g := Kit.grid(v, 2, 12, 2)
	for k in Bonuses.STAT_NAMES:
		var before: int = s.player.stats[k]
		var delta := int(J.num(J.nn(r.get("bonuses", {}), "stats", {}), k) + J.num(J.nn(c.get("bonuses", {}), "stats", {}), k))
		var after := maxi(1, before + delta)
		Kit.label(g, Bonuses.STAT_NAMES[k], 12)
		var val := "[b]%d[/b]" % before
		if delta:
			val += " [b]%s[/b]" % Kit.col("→ %d" % after, "ok" if delta > 0 else "danger")
		Kit.text(g, val, 12)


static func show_selection(gv: GameView) -> Modals.Job:
	var s := gv.s
	var races := Classes.race_options(s)
	J.sort(races, func(a, b): return int(b.available) - int(a.available))
	var classes := Classes.class_options(s)
	var archetypes: Array = J.uniq(classes.map(func(c): return c.klass.archetype))
	var rec = J.find(classes, func(c): return c.get("recommended", false))
	var state := {
		"race": "mensch",
		"klass": rec.klass.id if rec != null else (classes[0].klass.id if not classes.is_empty() else ""),
		"filter": "alle",
	}
	var build := func(root: VBoxContainer, close: Callable) -> void:
		Modals.title(root, "Wer willst du sein?")
		Modals.speaker(root, "Gilde der Einweisung · %s" % s.guideName)
		Kit.text(root, "Die Systemstimme hat deine Akte gelesen. Deine Klassenliste richtet sich danach, wie du bisher gekämpft und gelebt hast. Seltene Klassen tauchen nur auf, wenn du dir etwas Besonderes verdient hast.", 12, "muted")
		Kit.spacer(root, 4)
		var cols := Kit.hbox(root, 14)
		var vh := gv.get_viewport_rect().size.y
		var col_a := Kit.vbox(cols, 4)
		col_a.size_flags_stretch_ratio = 1.0
		Kit.section(col_a, "Rasse")
		var sa := ScrollContainer.new()
		sa.custom_minimum_size = Vector2(0, vh * 0.56)
		sa.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		col_a.add_child(sa)
		var race_el := Kit.vbox(sa, 6)
		var col_b := Kit.vbox(cols, 4)
		col_b.size_flags_stretch_ratio = 1.1
		Kit.section(col_b, "Deine Klassenliste")
		var filter_el := Kit.flow(col_b, 4)
		var sb := ScrollContainer.new()
		sb.custom_minimum_size = Vector2(0, vh * 0.5)
		sb.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		col_b.add_child(sb)
		var class_el := Kit.vbox(sb, 6)
		var sd := ScrollContainer.new()
		sd.custom_minimum_size = Vector2(0, vh * 0.6)
		sd.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sd.size_flags_stretch_ratio = 1.3
		sd.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		cols.add_child(sd)
		var detail_el := Kit.vbox(sd, 8)
		var f := Modals.foot(root)
		var summary: RichTextLabel = f[0]
		summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var fns := {}
		fns.draw = func() -> void:
			Kit.clear(race_el)
			for ro in races:
				var r: Dictionary = ro.race
				var avail: bool = ro.available
				var face := Kit.img(Sprites.hero_name({"race": r.id}), null, 1)
				var bb := "%s [b]%s[/b]\n%s" % [face, Kit.esc(r.name), Kit.small(Kit.esc(r.description))]
				if not avail:
					bb += "\n" + Kit.small(Kit.col("Gesperrt – Bedingung: " + Kit.esc(r.requirement.text if r.get("requirement") != null else ""), "danger"))
				var rid: String = r.id
				Kit.rbutton(race_el, bb, func():
					state.race = rid
					fns.draw.call(), "ChoiceSel" if r.id == state.race else "ChoiceButton", not avail, "", 14)
			Kit.clear(filter_el)
			var arch_names: Dictionary = Db.t("classes", "ARCHETYPE_NAMES")
			var filters: Array = [["alle", "Alle"]]
			for a in archetypes:
				filters.append([a, arch_names[a]])
			for fl in filters:
				var fid: String = fl[0]
				var b := Kit.button(filter_el, fl[1], func():
					state.filter = fid
					fns.draw.call(), "SelButton" if state.filter == fid else "SmallButton")
				b.add_theme_font_size_override("font_size", 12)
			Kit.clear(class_el)
			var rare_names: Dictionary = Db.t("classes", "CLASS_RARITY_NAMES")
			for co in classes:
				var c: Dictionary = co.klass
				if state.filter != "alle" and c.archetype != state.filter:
					continue
				var tags := ""
				if co.get("recommended", false):
					tags += " " + Kit.col("[b] Empfohlen [/b]", "accent")
				if c.rarity != "normal":
					tags += " " + Kit.col("[b] %s [/b]" % rare_names[c.rarity], "#7cc4ff" if c.rarity == "selten" else "#d070ff")
				var bb := "[b]%s[/b]%s\n%s\n%s" % [Kit.esc(c.name), tags, Kit.small(Kit.muted("%s · Fähigkeit: %s" % [arch_names[c.archetype], Kit.esc(Db.t("classes", "ABILITIES")[c.ability].name)])), Kit.small(Kit.esc(c.description))]
				var cid: String = c.id
				Kit.rbutton(class_el, bb, func():
					state.klass = cid
					fns.draw.call(), "ChoiceSel" if c.id == state.klass else "ChoiceButton", false, "", 14)
			Kit.clear(detail_el)
			var r: Dictionary = J.find(races, func(x): return x.race.id == state.race).race
			var cc = J.find(classes, func(x): return x.klass.id == state.klass)
			_race_detail(detail_el, r, s.player)
			if cc != null:
				_class_detail(detail_el, cc.klass)
				_stats_preview(detail_el, s, r, cc.klass)
			summary.text = "%s · %s" % [Kit.esc(GameTabs.race_name(r.id)), Kit.esc(cc.klass.name if cc != null else "")]
		Kit.button(f[1], "Festlegen", func():
			var res := Classes.choose(s, state.race, state.klass)
			if not res.get("ok", false):
				summary.text = Kit.esc(J.nn(res, "message", "Das geht nicht."))
				return
			close.call(), "PrimaryButton")
		fns.draw.call()
	return gv.modals().custom(build, 1280)
