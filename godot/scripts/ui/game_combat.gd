class_name GameCombat
extends RefCounted
## Aktionsleiste und Kampfsequenz: 1. womit, 2. wie,
## 3. wohin, 4. wen. Jede Wahl zeigt, was sie kostet und bewirkt; das Ziel
## zeigt die Trefferchance für genau diese Kombination.


static func _vsep(parent: Node) -> void:
	var l := ColorRect.new()
	l.color = UiTheme.LINE
	l.custom_minimum_size = Vector2(1, 26)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)


## Außerhalb des Kampfes eine schlanke Zeile: gewählter Angriff, Fähigkeit,
## Warten, Aufheben, Zauber. Körperteil und Ausführung wählt man im Kampf
## (oder jederzeit mit 1–7 und Q–R).
static func render_actions(gv: GameView, bar: PanelContainer) -> void:
	var s := gv.s
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", 8)
	f.add_theme_constant_override("v_separation", 6)
	bar.add_child(f)
	var tech := gv.technique()
	var sel := Kit.text(f, "%s [b]%s[/b] %s" % [Kit.muted("Angriff:"), Kit.col(Kit.esc(Combat.technique_name(tech)), "accent"), Kit.muted("· %d Ausdauer" % Combat.attack_cost(tech))], 13)
	sel.autowrap_mode = TextServer.AUTOWRAP_OFF
	sel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	sel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sel.tooltip_text = "Körperteil mit 1–7, Ausführung mit Q, W, E, R. Im Kampf öffnet sich die volle Auswahl."
	sel.mouse_filter = Control.MOUSE_FILTER_PASS
	var ability = Classes.current_ability(s)
	var cd := int(J.num(s.player, "abilityCooldown"))
	if ability != null:
		_vsep(f)
		Kit.kbutton(f, "%s%s" % [ability.name, (" (%d)" % cd) if cd else ""], "F", func(): gv.action(func(): return Classes.use_ability(s, gv.technique())), "AbilityButton", cd > 0, "Taste F · " + ability.description, "", 12)
	var known := Techniques.learned(s).filter(func(d): return d.art != "ausfuehrung")
	if not known.is_empty():
		_vsep(f)
		var tg := HBoxContainer.new()
		tg.add_theme_constant_override("separation", 4)
		f.add_child(tg)
		var near = _technique_target(gv)
		for d in known:
			var id: String = d.id
			var tcd := Techniques.cooldown(s, id)
			var block = Techniques.blocker(s, d, near)
			Kit.button(tg, "%s%s" % [d.name, (" (%d)" % tcd) if tcd else ""], func(): use_technique(gv, id), "SmallButton", tcd > 0, technique_tip(s, d, block))
	_vsep(f)
	var grp := HBoxContainer.new()
	grp.add_theme_constant_override("separation", 4)
	f.add_child(grp)
	_hot(grp, "Warten", "Leer", func(): gv.act(func(): return Game.wait(s)), false, false, "Ein Zug vergeht")
	_hot(grp, "Aufheben", "G", func(): gv.act(func(): return Game.pickup(s)), false, false, "Aufheben, was hier liegt")
	if s.player.get("mount") != null:
		_hot(grp, "Absteigen" if s.player.get("riding", false) else "Aufsitzen", "M", func(): gv.act(func(): return Game.ride_toggle(s)), false)
	_spell_bar(gv, f)


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
		Kit.button(grp, "%s %d MP%s" % [def.name, cost, (" (%d)" % cd) if cd else ""], func(): _spell(gv, id), "SmallSel" if pending else "SmallButton", disabled and not pending, def.description)
	if gv.pending_spell == "geschoss":
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
		gv.action(func(): return Game.cast(gv.s, id))
		return
	gv.pending_spell = null if gv.pending_spell == id else id
	gv.refresh_actions()


## Hinweis zu einer Technik: Wirkung, Kosten, Abklingzeit, warum es gerade
## nicht geht.
static func technique_tip(s: Dictionary, d: Dictionary, block: Variant) -> String:
	var bits: Array = [d.name]
	if int(J.nn(d, "cost", 0)) > 0:
		bits.append("%d Ausdauer" % int(d.cost))
	if int(J.num(d, "mp")) > 0:
		bits.append("%d Mana" % int(d.mp))
	if int(J.nn(d, "cd", 0)) > 0:
		bits.append("Abklingzeit %d" % int(d.cd))
	if d.get("free"):
		bits.append("kostet nicht die Aktion")
	var out := "%s\n%s" % [" · ".join(bits), d.description]
	if block != null:
		out += "\n" + String(block)
	return out


## Ziel einer Angriffstechnik: das gewählte Ziel, sonst der nächste sichtbare
## Gegner.
static func _technique_target(gv: GameView) -> Variant:
	var list := gv.combat_targets()
	var t = J.find(list, func(m): return m.uid == gv.target_uid)
	if t == null and not list.is_empty():
		t = list[0]
	return t


## Technik einsetzen. Angriffe gehen auf das gewählte Ziel; steht es zu
## weit weg, läuft die Figur erst hin (außer beim Hechtsprung). Techniken,
## die die Aktion nicht kosten, beenden auch keine verbrauchte Runde.
static func use_technique(gv: GameView, id: String) -> void:
	var s := gv.s
	var d = Techniques.def(id)
	var cur := gv.technique()
	var run := gv.act if d.get("free") else gv.action
	if d.art != "angriff":
		run.call(func(): return Game.use_technique(s, id, null, cur))
		return
	var target = _technique_target(gv)
	if target == null:
		gv.say("Kein Ziel in Sicht für %s." % d.name)
		return
	var uid: String = target.uid
	gv.target_uid = uid
	var t := Techniques.attack_t(d, cur)
	var reach := Combat.WURF_RANGE if t.part == "wurf" else int(J.nn(d, "leap", 1))
	var fn := func(): return Game.use_technique(s, id, uid, cur)
	if Fov.chebyshev(s.player.pos, target.pos) > reach:
		gv.go_then(target.pos, true, fn)
		return
	run.call(fn)


## Gruppe der Hotbar: kleine Überschrift links, daneben die Knöpfe.
static func _group(parent: Node, title: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 3)
	parent.add_child(h)
	var l := Kit.label(h, title.to_upper(), 11, "muted")
	l.add_theme_font_override("font", UiFonts.pixel(700, 1))
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	Kit.spacer(h, 3)
	return h


## Kleiner Knopf mit Tastenkappe; gewählt in Gold.
static func _hot(parent: Node, text: String, key: String, cb: Callable, selected: bool, disabled: bool = false, tip: String = "") -> ClickPanel:
	return Kit.kbutton(parent, text, key, cb, "SmallSel" if selected else "SmallButton", disabled, tip, "", 12)


## Im Kampf: eine schmale Hotbar wie in Baldur's Gate. Oben Runde, Bewegung,
## Aktion, Ziel und „Runde beenden“; darunter in einer Reihe Angriff (womit),
## Ausführung (wie), Trefferzone (wohin), Zauber und Sonstiges. Erklärungen
## stehen in den Tooltips, Gegner wählt man auf dem Boden (Klick, Tab).
## Die Knopfreihe wird nur neu gebaut, wenn sich ihr Inhalt ändert (Waffe,
## Wurfgeschosse, Zauber …); sonst werden nur Auswahl und Sperren nachgezogen.
static func render_combat(gv: GameView, bar: PanelContainer) -> void:
	var s := gv.s
	var targets := gv.combat_targets()
	if not J.some(targets, func(m): return m.uid == gv.target_uid):
		gv.target_uid = targets[0].uid if not targets.is_empty() else null
	var target = J.find(targets, func(m): return m.uid == gv.target_uid)
	var skey := _static_key(gv)
	var reuse: bool = skey == gv.bar_static_key and is_instance_valid(gv.bar_top) and is_instance_valid(gv.bar_row) and gv.bar_row.get_parent() != null and gv.bar_row.get_parent().get_parent() == bar
	if not reuse:
		Kit.clear(bar)
		var outer := VBoxContainer.new()
		outer.add_theme_constant_override("separation", 6)
		bar.add_child(outer)
		gv.bar_top = Kit.hbox(outer, 14)
		var row := HFlowContainer.new()
		row.add_theme_constant_override("h_separation", 18)
		row.add_theme_constant_override("v_separation", 6)
		outer.add_child(row)
		gv.bar_row = row
		gv.hot = []
		gv.bar_parts = {}
		_build_row(gv, row)
		gv.bar_static_key = skey
	else:
		Kit.clear(gv.bar_top)
	_build_top(gv, gv.bar_top, target)
	_update_hot(gv, target)


## Was die Knopfreihe enthält (ändert es sich, wird sie neu gebaut).
static func _static_key(gv: GameView) -> String:
	var s := gv.s
	var p: Dictionary = s.player
	var w = Player.current_weapon(s)
	var th := Player.throwables(s)
	var throw := ""
	if not th.is_empty():
		var n := 0
		for x in th:
			if x.baseId == th[0].baseId:
				n += int(J.nn(x, "menge", 1))
		throw = "%s:%d:%d" % [th[0].baseId, n, J.uniq(th.map(func(x): return x.baseId)).size()]
	var spells := J.arr(p, "spells").map(func(k): return "%s:%d:%d" % [k.id, Magic.spell_cost(k.id, gv.missile_mana), int(J.num(J.nn(p, "spellCooldowns", {}), k.id))])
	var ability = Classes.current_ability(s)
	var techs := Techniques.learned(s).map(func(d): return "%s:%d" % [d.id, Techniques.cooldown(s, d.id)])
	return "%s|%s|%s|%s|%s|%s|%s|%s" % [w.name if w != null else "", throw, ",".join(spells), Player.heal_item(s) != null, (ability.name + str(J.num(p, "abilityCooldown"))) if ability != null else "", str(gv.pending_spell), Rounds.active(s), ",".join(techs)]


## Knopf der Hotbar, dessen Auswahl, Sperre und Hinweis sich nachziehen lassen.
static func _live(gv: GameView, parent: Node, text: String, key: String, cb: Callable, sel: Callable, dis: Callable, tip: Callable, variant: String = "") -> ClickPanel:
	var cp := Kit.kbutton(parent, text, key, cb, variant if variant != "" else "SmallButton", false, "", "", 12)
	gv.hot.append({"cp": cp, "sel": sel, "dis": dis, "tip": tip, "variant": variant})
	return cp


static func _update_hot(gv: GameView, target: Variant) -> void:
	for e in gv.hot:
		var cp: ClickPanel = e.cp
		if not is_instance_valid(cp):
			continue
		if e.variant == "":
			cp.variant = "SmallSel" if e.sel.call() else "SmallButton"
		cp.disabled = e.dis.call()
		cp.tooltip_text = e.tip.call(target)
		cp._applied = ""
		cp._apply()


static func _build_top(gv: GameView, top: HBoxContainer, target: Variant) -> void:
	var s := gv.s
	var round_box := Kit.hbox(top, 14)
	gv.bar_parts.runde = round_box
	if Rounds.active(s):
		var left := int(s.round.move)
		var full := maxi(int(s.round.max), left)
		var acted: bool = s.round.get("acted", false)
		Kit.label(round_box, "RUNDE %d" % int(s.round.n), 14, Color("#ff9b85"), 700).add_theme_font_override("font", UiFonts.pixel(700, 1))
		var mv := Kit.hbox(round_box, 6)
		Kit.label(mv, "Bewegung", 12, "muted").size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var meter := MoveBar.new()
		meter.frac = float(left) / maxf(1.0, float(full))
		meter.custom_minimum_size = Vector2(110, 10)
		meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		meter.tooltip_text = "Wie weit du in dieser Runde noch laufen kannst. Die Linie zum Mauszeiger ist grün, solange es reicht."
		mv.add_child(meter)
		gv.move_meter = meter
		gv.move_label = Kit.label(mv, "%s / %s" % [FreeMove.meters(left), FreeMove.meters(int(s.round.max))], 13, Color("#8cc8ff"), 700)
		gv.move_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var ac := Kit.label(round_box, "Aktion verbraucht" if acted else "Aktion bereit", 13, Color("#e0a040") if acted else Color("#6ee07a"), 700)
		ac.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ac.tooltip_text = "Eine Aktion pro Runde (Angriff, Zauber, Trank, Deckung, Spurt). Danach darfst du mit der übrigen Bewegung noch laufen." if not acted else "Aktion verbraucht: Du kannst noch laufen. Ein weiterer Angriff beginnt die nächste Runde."
		ac.mouse_filter = Control.MOUSE_FILTER_PASS
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	gv.bar_parts.ziel = _target_chip(gv, top, target)
	if Rounds.active(s):
		gv.bar_parts.ende = Kit.kbutton(top, "Runde beenden", "Leer", func(): gv.act(func(): return Game.wait(s)), "PrimaryButton", false, "Die Gegner sind dran, danach beginnt eine neue Runde")


static func _build_row(gv: GameView, row: HFlowContainer) -> void:
	var s := gv.s
	var p: Dictionary = s.player
	var weapon = Player.current_weapon(s)
	var none := func(_t): return ""
	var g1 := _group(row, "Womit")
	gv.bar_parts.womit = g1
	for part in ["faust", "tritt", "knie", "ellbogen", "kopf", "waffe"]:
		var label: String = (weapon.name if weapon != null else "Waffe") if part == "waffe" else Bonuses.PART_NAMES[part]
		var pp: String = part
		var no_weapon: bool = part == "waffe" and weapon == null
		_live(gv, g1, label, GameView.PART_KEYS[part], func():
			gv.pending_spell = null
			gv.part = pp
			if pp != "tritt" and gv.move == "stampfen":
				gv.move = "normal"
			gv.refresh_actions(),
			func(): return gv.part == pp and gv.pending_spell == null,
			func(): return no_weapon,
			func(_t):
				var probe := gv.technique()
				probe.part = pp
				return "%s · %d Ausdauer" % [label, Combat.attack_cost(probe)])
	var th := Player.throwables(s)
	if not th.is_empty():
		var it: Dictionary = th[0]
		var n := 0
		for x in th:
			if x.baseId == it.baseId:
				n += int(J.nn(x, "menge", 1))
		var kinds := J.uniq(th.map(func(x): return x.baseId)).size()
		_live(gv, g1, "%s ×%d" % [Identify.item_name(s, it), n], "7", func():
			gv.pending_spell = null
			if gv.part == "wurf" and kinds > 1:
				# Noch einmal: zur nächsten Art Wurfgeschoss wechseln
				var ids: Array = J.uniq(Player.throwables(s).map(func(x): return x.baseId))
				Game.choose_throwable(s, ids[(ids.find(it.baseId) + 1) % ids.size()])
			gv.part = "wurf"
			gv.move = "normal"
			gv.refresh_actions(),
			func(): return gv.part == "wurf" and gv.pending_spell == null,
			func(): return false,
			func(_t): return "Werfen%s" % (" · noch einmal klicken wechselt die Art" if kinds > 1 else ""))
	var g2 := _group(row, "Wie")
	gv.bar_parts.wie = g2
	for mv2 in Combat.ATTACK_MOVES:
		var m2: String = mv2
		_live(gv, g2, Combat.MOVE_NAMES[mv2], GameView.MOVE_KEYS[mv2], func():
			var locked = Techniques.move_blocker(s, m2)
			if locked != null:
				gv.say(locked)
				return
			gv.move = m2
			if m2 == "stampfen":
				gv.part = "tritt"
			gv.refresh_actions(),
			func(): return gv.move == m2,
			func(): return (gv.part == "wurf" and m2 != "normal") or not Techniques.move_ok(s, m2),
			func(target):
				var locked = Techniques.move_blocker(s, m2)
				if locked != null:
					return "%s · %s" % [Combat.MOVE_NAMES[m2], locked]
				var probe := gv.technique()
				probe.move = m2
				var blocker = Combat.technique_blocker(s, target, probe) if target != null else null
				return "%s · %d Ausdauer%s" % [Combat.MOVE_NAMES[m2], Combat.attack_cost(probe), (" · " + String(blocker)) if blocker != null else ""])
	var g3 := _group(row, "Wohin")
	gv.bar_parts.wohin = g3
	for z in Combat.HIT_ZONES:
		var zd: Dictionary = Combat.ZONES[z]
		var zz: String = z
		var tip: String = "%s: %s" % [zd.name, zd.effekt]
		_live(gv, g3, zd.name, GameView.ZONE_KEYS[z], func():
			gv.zone = zz
			gv.refresh_actions(),
			func(): return gv.zone == zz,
			func(): return false,
			func(_t): return tip)
	var known := Techniques.learned(s).filter(func(d): return d.art != "ausfuehrung")
	if not known.is_empty():
		var gt := _group(row, "Techniken")
		gv.bar_parts.techniken = gt
		for d in known:
			var dd: Dictionary = d
			var id: String = d.id
			var tcd := Techniques.cooldown(s, id)
			_live(gv, gt, "%s%s" % [d.name, (" (%d)" % tcd) if tcd else ""], "", func(): use_technique(gv, id),
				func(): return false,
				func(): return Techniques.cooldown(s, id) > 0 or int(p.ausdauer) < int(J.nn(dd, "cost", 0)),
				func(target):
					var tgt = target if dd.art == "angriff" else null
					var block = Techniques.blocker(s, dd, tgt) if dd.art != "angriff" or target != null else null
					return technique_tip(s, dd, block),
				"AbilityButton" if dd.get("free") else "")
	var spells := J.arr(p, "spells")
	if not spells.is_empty():
		var g4 := _group(row, "Zauber")
		for k in spells:
			var def: Dictionary = Db.spell(k.id)
			var cd := int(J.num(J.nn(p, "spellCooldowns", {}), k.id))
			var cost := Magic.spell_cost(k.id, gv.missile_mana)
			var id: String = k.id
			var stip: String = "%s · %d MP · %s" % [def.name, cost, def.description]
			_live(gv, g4, "%s %d%s" % [def.name, cost, (" (%d)" % cd) if cd else ""], "", func(): _spell(gv, id),
				func(): return gv.pending_spell == id,
				func(): return cd > 0 or J.num(p, "mp") < cost,
				func(_t): return stip)
	var g5 := _group(row, "Sonstiges")
	gv.bar_parts.sonstiges = g5
	_live(gv, g5, "Deckung", "", func(): gv.action(func(): return Game.defend(s)), func(): return false, func(): return false,
		func(_t): return "Bis zum nächsten Zug +20 % Ausweichen, +2 Rüstung, +2 Ausdauer")
	_live(gv, g5, "Spurt", "S", func(): gv.act(func(): return Game.dash(s)), func(): return false,
		func(): return int(p.ausdauer) < Game.DASH_COST or J.num(p, "immobile") > 0,
		func(_t): return "Aktion gegen Bewegung: noch einmal %s in dieser Runde, kostet %d Ausdauer" % [FreeMove.meters(int(s.round.max)) if Rounds.active(s) else "die volle Bewegung", Game.DASH_COST])
	var potion = Player.heal_item(s)
	if potion != null:
		_live(gv, g5, "Trank", "", func():
			var pot = Player.heal_item(s)
			if pot != null:
				var puid: String = pot.uid
				gv.action(func(): return Game.use_item(s, puid)),
			func(): return false, func(): return false,
			func(_t):
				var pot = Player.heal_item(s)
				return "%s trinken" % Identify.item_name(s, pot) if pot != null else "Trank trinken")
	var ability = Classes.current_ability(s)
	if ability != null:
		var cd := int(J.num(p, "abilityCooldown"))
		var atip: String = ability.description
		_live(gv, g5, "%s%s" % [ability.name, (" (%d)" % cd) if cd else ""], "F", func(): gv.action(func(): return Classes.use_ability(s, gv.technique())),
			func(): return false, func(): return cd > 0, func(_t): return atip, "AbilityButton")
	_live(gv, g5, "Warten", "", func(): gv.act(func(): return Game.wait(s)), func(): return false, func(): return false,
		func(_t): return "Runde beenden ohne Aktion (Leertaste)")
	if gv.pending_spell != null:
		var tgt: String = Db.spell(gv.pending_spell).target
		var hint := Kit.label(row, "Klicke auf %s (Esc bricht ab)" % ("eine freie Stelle am Boden" if tgt == "feld" else "einen Gegner"), 13, "accent")
		hint.size_flags_vertical = Control.SIZE_SHRINK_END


## Nur die übrige Bewegung nachziehen (Balken und Zahl).
static func update_move(gv: GameView) -> void:
	var s := gv.s
	if not Rounds.active(s):
		return
	var left := int(s.round.move)
	var meter: MoveBar = gv.move_meter
	meter.frac = float(left) / maxf(1.0, float(maxi(int(s.round.max), left)))
	meter.queue_redraw()
	if is_instance_valid(gv.move_label):
		gv.move_label.text = "%s / %s" % [FreeMove.meters(left), FreeMove.meters(int(s.round.max))]


## Gewähltes Ziel als kleiner Chip: Name, Abstand, Chance, Angreifen (Enter).
## Andere Ziele wählt man mit Klick auf den Gegner oder Tab.
static func _target_chip(gv: GameView, parent: Node, m: Variant) -> Control:
	if m == null:
		var none := Kit.label(parent, "Kein Gegner in Sicht", 12, "muted")
		none.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		return none
	var s := gv.s
	var info := Identify.describe_monster(s, m)
	var d := Fov.chebyshev(m.pos, s.player.pos)
	var blocker = Combat.technique_blocker(s, m, gv.technique())
	var text := ""
	var approach := false
	if gv.pending_spell != null:
		text = "Zauber"
	elif blocker == null:
		text = gv._hit_text(m)
	elif d > 1 and gv.part != "wurf":
		# Wie weit es ist, zeigt die Linie zum Mauszeiger (grün reicht, rot nicht)
		approach = true
		text = "hinlaufen und zuschlagen"
	else:
		text = String(blocker).trim_suffix(".")
	var chip := Kit.hbox(parent, 8)
	var nm := Kit.text(chip, "%s [b]%s[/b] · %s" % [Kit.muted("Ziel"), Kit.col(Kit.esc(info.name), "#b0a898" if info.insight >= 3 else m.color), Kit.col(Kit.esc(text), "ok" if blocker == null or approach else "muted")], 13)
	nm.autowrap_mode = TextServer.AUTOWRAP_OFF
	nm.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	nm.tooltip_text = "%s, %s. Ziel wechseln: Klick auf einen Gegner oder Tab." % [info.name, info.health]
	nm.mouse_filter = Control.MOUSE_FILTER_PASS
	var uid: String = m.uid
	var b := Kit.kbutton(chip, "Zaubern" if gv.pending_spell != null else "Angreifen", "Enter", func():
		if approach:
			gv.attack_or_approach(uid)
		else:
			gv.strike(uid), "SmallPrimary", blocker != null and not approach and gv.pending_spell == null, "", "", 12)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return chip


## Balken der übrigen Bewegung.
class MoveBar:
	extends Control
	var frac := 1.0

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.45))
		draw_rect(Rect2(Vector2(1, 1), Vector2((size.x - 2) * clampf(frac, 0.0, 1.0), size.y - 2)), Color("#5aa8ff"))
		draw_rect(Rect2(Vector2(1, 1), Vector2((size.x - 2) * clampf(frac, 0.0, 1.0), 2)), Color(1, 1, 1, 0.3))


