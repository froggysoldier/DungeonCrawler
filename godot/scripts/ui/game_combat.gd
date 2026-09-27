class_name GameCombat
extends RefCounted
## Aktionsleiste und Kampfsequenz (Port aus gameview.ts): 1. womit, 2. wie,
## 3. wohin, 4. wen. Jede Wahl zeigt, was sie kostet und bewirkt; das Ziel
## zeigt die Trefferchance für genau diese Kombination.


static func _vsep(parent: Node) -> void:
	var l := ColorRect.new()
	l.color = UiTheme.LINE
	l.custom_minimum_size = Vector2(1, 26)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)


static func _count_throwables(s: Dictionary) -> int:
	var n := 0
	for it in Player.throwables(s):
		n += int(J.nn(it, "menge", 1))
	return n


## Außerhalb des Kampfes: Körperteil, Ausführung, Fähigkeit, Warten, Zauber.
static func render_actions(gv: GameView, bar: PanelContainer) -> void:
	var s := gv.s
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", 8)
	f.add_theme_constant_override("v_separation", 6)
	bar.add_child(f)
	var thr := _count_throwables(s)
	var weapon = Player.current_weapon(s)
	var grp := HBoxContainer.new()
	grp.add_theme_constant_override("separation", 4)
	f.add_child(grp)
	for p in Combat.ATTACK_PARTS:
		var disabled: bool = (p == "waffe" and weapon == null) or (p == "wurf" and thr == 0)
		var label: String
		if p == "wurf":
			label = "Wurf (%d)" % thr
		elif p == "waffe":
			label = weapon.name if weapon != null else "Waffe"
		else:
			label = Bonuses.PART_NAMES[p]
		var pp: String = p
		Kit.kbutton(grp, label, GameView.PART_KEYS[p], func():
			gv.part = pp
			if pp == "wurf":
				gv.move = "normal"
			if pp != "tritt" and gv.move == "stampfen":
				gv.move = "normal"
			gv.refresh_actions(), "SelButton" if gv.part == p else "Button", disabled, "Taste " + GameView.PART_KEYS[p])
	_vsep(f)
	var grp2 := HBoxContainer.new()
	grp2.add_theme_constant_override("separation", 4)
	f.add_child(grp2)
	for mv in Combat.ATTACK_MOVES:
		var cost := Combat.attack_cost({"part": gv.part, "move": mv})
		var m2: String = mv
		Kit.kbutton(grp2, Combat.MOVE_NAMES[mv], GameView.MOVE_KEYS[mv], func():
			gv.move = m2
			if m2 == "stampfen":
				gv.part = "tritt"
			gv.refresh_actions(), "SelButton" if gv.move == mv else "Button", gv.part == "wurf" and mv != "normal", "Taste %s · kostet %d Ausdauer" % [GameView.MOVE_KEYS[mv], cost])
	var ability = Classes.current_ability(s)
	var cd := int(J.num(s.player, "abilityCooldown"))
	if ability != null:
		_vsep(f)
		Kit.kbutton(f, "Fähigkeit: %s%s" % [ability.name, (" (%d)" % cd) if cd else ""], "F", func(): gv.act(func(): return Classes.use_ability(s, gv.technique())), "AbilityButton", cd > 0, "Taste F · " + ability.description)
	_vsep(f)
	var grp3 := HBoxContainer.new()
	grp3.add_theme_constant_override("separation", 4)
	f.add_child(grp3)
	Kit.button(grp3, "Warten", func(): gv.act(func(): return Game.wait(s)), "Button", false, "Leertaste")
	Kit.button(grp3, "Aufheben", func(): gv.act(func(): return Game.pickup(s)), "Button", false, "G")
	_spell_bar(gv, f)
	var sel := Kit.text(f, "%s [b]%s[/b] · %d Ausdauer" % [Kit.muted("Gewählt:"), Kit.col(Kit.esc(Combat.technique_name(gv.technique())), "accent"), Combat.attack_cost(gv.technique())], 12, "muted")
	sel.autowrap_mode = TextServer.AUTOWRAP_OFF
	sel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	sel.size_flags_vertical = Control.SIZE_SHRINK_CENTER


## Zauberleiste: jeder bekannte Zauber als Knopf, mit Kosten und Abklingzeit.
static func _spell_bar(gv: GameView, f: Node) -> void:
	var s := gv.s
	var p: Dictionary = s.player
	var spells := J.arr(p, "spells")
	if spells.is_empty():
		return
	_vsep(f)
	var grp := HBoxContainer.new()
	grp.add_theme_constant_override("separation", 4)
	f.add_child(grp)
	for k in spells:
		var def: Dictionary = Db.spell(k.id)
		var cd := int(J.num(J.nn(p, "spellCooldowns", {}), k.id))
		var cost := Magic.spell_cost(k.id, gv.missile_mana)
		var pending: bool = gv.pending_spell == k.id
		var disabled := cd > 0 or J.num(p, "mp") < cost
		var id: String = k.id
		Kit.button(grp, "%s (%d MP)%s" % [def.name, cost, (" – %d" % cd) if cd else ""], func(): _spell(gv, id), "SpellSel" if pending else "SpellButton", disabled and not pending, def.description)
	if J.some(spells, func(k): return k.id == "geschoss"):
		Kit.label(grp, "Geschoss-Mana:", 12, "muted").size_flags_vertical = Control.SIZE_SHRINK_CENTER
		for m in [3, 4, 5, 6]:
			var mana: int = m
			Kit.button(grp, str(m), func():
				gv.missile_mana = mana
				gv.refresh_actions(), "SelButton" if gv.missile_mana == m else "Button")
	if gv.pending_spell != null:
		var target: String = Db.spell(gv.pending_spell).target
		Kit.label(grp, "Klicke auf %s (Esc bricht ab)" % ("ein freies Feld" if target == "feld" else "einen Gegner"), 12, "accent").size_flags_vertical = Control.SIZE_SHRINK_CENTER


static func _spell(gv: GameView, id: String) -> void:
	var def: Dictionary = Db.spell(id)
	if def.target == "selbst":
		gv.pending_spell = null
		gv.act(func(): return Game.cast(gv.s, id))
		return
	gv.pending_spell = null if gv.pending_spell == id else id
	gv.refresh_actions()


static func _col(parent: Node, title: String, ratio: float, hint: String = "") -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_stretch_ratio = ratio
	parent.add_child(v)
	var h := Kit.hbox(v, 6)
	var l := Kit.label(h, title.to_upper(), 12, Color("#ff9b85"), 700)
	l.add_theme_font_override("font", UiFonts.get_font(700, false, 1))
	if hint != "":
		Kit.label(h, hint, 12, "muted")
	return v


static func _sub(parent: Node, text: String) -> void:
	Kit.spacer(parent, 2)
	Kit.label(parent, text, 11, "muted")


## Im Kampf: die vierteilige Kampfsequenz.
static func render_combat(gv: GameView, bar: PanelContainer) -> void:
	var s := gv.s
	var p: Dictionary = s.player
	var targets := gv.combat_targets()
	if not J.some(targets, func(m): return m.uid == gv.target_uid):
		gv.target_uid = targets[0].uid if not targets.is_empty() else null
	var tech := gv.technique()
	var weapon = Player.current_weapon(s)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 6)
	bar.add_child(outer)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 12)
	outer.add_child(cols)

	# 1 · Womit?
	var c1 := _col(cols, "1 · Womit?", 1.35)
	var b1 := Kit.flow(c1, 4)
	for part in ["faust", "tritt", "knie", "ellbogen", "kopf", "waffe"]:
		var disabled: bool = part == "waffe" and weapon == null
		var label: String = (weapon.name if weapon != null else "Waffe") if part == "waffe" else Bonuses.PART_NAMES[part]
		var sel: bool = gv.part == part and gv.pending_spell == null
		var pp: String = part
		Kit.kbutton(b1, label, GameView.PART_KEYS[part], func():
			gv.pending_spell = null
			gv.part = pp
			if pp != "tritt" and gv.move == "stampfen":
				gv.move = "normal"
			gv.refresh_actions(), "SelButton" if sel else "Button", disabled)
	var throw_list := {}
	var order: Array = []
	for it in Player.throwables(s):
		if not throw_list.has(it.baseId):
			throw_list[it.baseId] = {"name": Identify.item_name(s, it), "n": 0, "explosive": it.get("explosion") != null and it.explosion}
			order.append(it.baseId)
		throw_list[it.baseId].n += int(J.nn(it, "menge", 1))
	var th := Player.throwables(s)
	var next_throw = th[0].baseId if not th.is_empty() else null
	if not order.is_empty():
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 4)
		c1.add_child(h)
		Kit.label(h, "Werfen", 11, "muted")
		h.add_child(Kit.keycap("7"))
		var bt := Kit.flow(c1, 4)
		for id in order:
			var e: Dictionary = throw_list[id]
			var bid: String = id
			var sel: bool = gv.part == "wurf" and next_throw == id and gv.pending_spell == null
			Kit.button(bt, "%s ×%d%s" % [e.name, e.n, " (explodiert)" if e.explosive else ""], func():
				gv.pending_spell = null
				Game.choose_throwable(s, bid)
				gv.part = "wurf"
				gv.move = "normal"
				gv.refresh_actions(), "SelButton" if sel else "Button")
	var spells := J.arr(p, "spells")
	if not spells.is_empty():
		_sub(c1, "Zauber (%s MP)" % J.s(J.nn(p, "mp", 0)))
		var bs := Kit.flow(c1, 4)
		for k in spells:
			var def: Dictionary = Db.spell(k.id)
			var cd := int(J.num(J.nn(p, "spellCooldowns", {}), k.id))
			var cost := Magic.spell_cost(k.id, gv.missile_mana)
			var disabled := cd > 0 or J.num(p, "mp") < cost
			var id: String = k.id
			Kit.button(bs, "%s (%d MP)%s" % [def.name, cost, (" – %d" % cd) if cd else ""], func(): _spell(gv, id), "SpellSel" if gv.pending_spell == k.id else "SpellButton", disabled, def.description)
	_sub(c1, "Sonstiges")
	var bo := Kit.flow(c1, 4)
	Kit.button(bo, "Deckung", func(): gv.act(func(): return Game.defend(s)), "Button", false, "Bis zum nächsten Zug +20 % Ausweichen, +2 Rüstung, +2 Ausdauer")
	var potion = J.find(p.inventory, func(i): return i.kind == "verbrauch" and i.get("effekt") != null and (J.num(i.effekt, "heal") or J.num(i.effekt, "healPct")))
	if potion != null:
		var puid: String = potion.uid
		Kit.button(bo, "%s trinken" % Identify.item_name(s, potion), func(): gv.act(func(): return Game.use_item(s, puid)))
	var ability = Classes.current_ability(s)
	var cd := int(J.num(p, "abilityCooldown"))
	if ability != null:
		Kit.kbutton(bo, "%s%s" % [ability.name, (" (%d)" % cd) if cd else ""], "F", func(): gv.act(func(): return Classes.use_ability(s, gv.technique())), "AbilityButton", cd > 0, ability.description)
	Kit.button(bo, "Warten", func(): gv.act(func(): return Game.wait(s)))

	# 2 · Wie?
	var c2 := _col(cols, "2 · Wie?", 0.8)
	var target = J.find(targets, func(m): return m.uid == gv.target_uid)
	for mv in Combat.ATTACK_MOVES:
		var probe := tech.duplicate()
		probe.move = mv
		var blocker = Combat.technique_blocker(s, target, probe) if target != null else null
		var m2: String = mv
		var cp := Kit.kbutton(c2, Combat.MOVE_NAMES[mv], GameView.MOVE_KEYS[mv], func():
			gv.move = m2
			if m2 == "stampfen":
				gv.part = "tritt"
			gv.refresh_actions(), "SelButton" if gv.move == mv else "Button", gv.part == "wurf" and mv != "normal", blocker if blocker != null else "", Kit.muted("· %d Ausdauer" % Combat.attack_cost(probe)))
		cp.size_flags_horizontal = Control.SIZE_FILL
	Kit.text(c2, "Ausdauer %s/%d" % [J.s(p.ausdauer), Player.max_ausdauer(s)], 12, "muted")

	# 3 · Wohin?
	var c3 := _col(cols, "3 · Wohin?", 1.2)
	for z in Combat.HIT_ZONES:
		var zd: Dictionary = Combat.ZONES[z]
		var zz: String = z
		var cp := Kit.rbutton(c3, "[b]%s[/b]\n%s" % [Kit.esc(zd.name), Kit.small(Kit.esc(zd.effekt))], func():
			gv.zone = zz
			gv.refresh_actions(), "SelButton" if gv.zone == z else "Button", false, zd.effekt, 13)
		var rt: RichTextLabel = cp.get_child(0)
		rt.add_theme_constant_override("line_separation", 1)
		var cap := Kit.keycap(GameView.ZONE_KEYS[z])
		cap.position = Vector2(0, 0)
		cp.add_child(cap)
		cap.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		cap.size_flags_horizontal = Control.SIZE_SHRINK_END
		cap.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	# 4 · Wen?
	var c4 := _col(cols, "4 · Wen?", 1.5, "(Tab wechselt, Enter greift an)")
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 0)
	c4.add_child(scroll)
	var list := Kit.vbox(scroll, 5)
	if targets.is_empty():
		Kit.text(list, "Kein Gegner in Sicht.", 12, "muted")
	for m in targets:
		_target_row(gv, list, m)
	list.minimum_size_changed.connect(func():
		if is_instance_valid(scroll):
			scroll.custom_minimum_size.y = minf(250, list.get_combined_minimum_size().y))
	scroll.custom_minimum_size.y = minf(250, list.get_combined_minimum_size().y)

	var sum := "KAMPF · Gewählt: [b]%s[/b]" % Kit.col(Kit.esc(Db.spell(gv.pending_spell).name if gv.pending_spell != null else Combat.technique_name(tech)), "accent")
	if gv.pending_spell == null:
		sum += " · %d Ausdauer" % Combat.attack_cost(tech)
	sum += " · Bewegen mit Pfeiltasten oder Klick auf die Karte"
	Kit.text(outer, sum, 12, "muted")


static func _target_row(gv: GameView, list: Node, m: Dictionary) -> void:
	var s := gv.s
	var p: Dictionary = s.player
	var info := Identify.describe_monster(s, m)
	var d := Fov.chebyshev(m.pos, p.pos)
	var chance := ""
	var blocker = null
	var tech := gv.technique()
	if gv.pending_spell != null:
		var def: Dictionary = Db.spell(gv.pending_spell)
		if def.target != "gegner":
			blocker = "Dieser Zauber braucht kein Ziel."
		elif d > int(J.nn(def, "range", 6)):
			blocker = "Zu weit weg für den Zauber."
		chance = "" if blocker != null else "Zauber trifft sicher"
	else:
		blocker = Combat.technique_blocker(s, m, tech)
		if blocker == null:
			chance = ("%d %% Treffer" % Combat.hit_chance(s, m, tech)) if info.showHitChance else "Trefferchance unklar"
	var states: Array = []
	if m.get("asleep", false):
		states.append("schläft")
	elif not m.get("aware", false):
		states.append("ahnungslos")
	if J.num(m, "downed") > 0:
		states.append("am Boden")
	if m.get("stunned"):
		states.append("benommen")
	if m.get("slowed"):
		states.append("humpelt")
	if m.get("weakened"):
		states.append("geschwächt")
	var conds := ", ".join(Conditions.condition_list(m).map(func(c): return Kit.col(Kit.esc(c.state), c.color)))
	var sel: bool = m.uid == gv.target_uid
	var uid: String = m.uid
	var cp := ClickPanel.new("Button")
	cp.fixed_panel = UiTheme.get_theme().get_stylebox("panel", "TargetSel" if sel else "Target")
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cp.add_child(v)
	var name_col = "#b0a898" if info.insight >= 3 else m.color
	Kit.text(v, "[b]%s[/b] %s %s" % [Kit.col(Kit.esc(info.name), name_col), Kit.small(Kit.muted("%s · %d %s" % [Kit.esc(info.level), d, "Feld" if d == 1 else "Felder"])), Kit.small(Kit.col(Kit.esc(info.challenge.name), info.challenge.color))], 13)
	var line := Kit.esc(info.health)
	if not states.is_empty():
		line += " · " + Kit.col(Kit.esc(", ".join(states)), "#7cc4ff")
	if conds != "":
		line += " · " + conds
	Kit.text(v, line, 12)
	var h := Kit.hbox(v, 6)
	var ct := Kit.text(h, Kit.esc(blocker if blocker != null else chance), 12, "muted" if blocker != null else "ok")
	ct.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var btn := Kit.button(h, "Zaubern" if gv.pending_spell != null else "Angreifen", func(): gv.strike(uid), "SmallPrimary", blocker != null)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	cp.pressed.connect(func():
		gv.target_uid = uid
		gv.refresh_actions())
	list.add_child(cp)
