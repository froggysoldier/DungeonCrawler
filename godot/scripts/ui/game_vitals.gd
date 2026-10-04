class_name GameVitals
extends RefCounted
## Der feste Kopf der Seitenleiste: Name, Stufe, Klasse und die Balken für
## HP, Ausdauer, Mana, Blase und Erfahrung, dazu Zustände, Haustier und
## Reittier in einer Zeile. Bleibt sichtbar, egal welcher Reiter offen ist.


static func build(gv: GameView, root: VBoxContainer) -> void:
	var s := gv.s
	var p: Dictionary = s.player
	var b := Player.total_bonuses(s)
	var mh := Player.max_hp(s, b)
	var ma := Player.max_ausdauer(s, b)
	var need := Player.xp_to_next(p.level)
	# Kopfzeile: Name · Stufe · Klasse, rechts freie Punkte
	var head := Kit.hbox(root, 8)
	var name := Kit.label(head, p.name, 16, null, 700)
	name.add_theme_font_override("font", UiFonts.pixel(700))
	name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var who := "Lv [b]%d[/b] %s" % [p.level, Kit.small("(%s/%d XP)" % [J.s(p.xp), need])]
	if p.get("klass") != null and Db.klass(p.klass) != null:
		who += " · " + Kit.col(Kit.esc(Db.klass(p.klass).name), "accent")
	elif p.get("race") != null:
		who += " · " + Kit.esc(GameTabs.race_name(p.race))
	var wt := Kit.text(head, who, 12, "muted")
	wt.autowrap_mode = TextServer.AUTOWRAP_OFF
	wt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var points := int(J.num(p, "statPoints"))
	if points > 0 and Game.has_unlock(s, "stats"):
		Kit.button(head, "+%d Punkte" % points, func(): gv.open_tab("crawler"), "SmallPrimary", false, "Freie Wertepunkte verteilen")
	# Balken: zwei Spalten, XP schmal darunter
	var poisoned := J.some(p.buffs, func(x): return x.name == "Vergiftet")
	var g := Kit.grid(root, 2, 6, 5)
	var hp: int = maxi(0, p.hp)
	var low := float(hp) / mh <= 0.3
	_bar(g, float(hp) / mh, "HP %d/%d" % [hp, mh], "#3d7a1e" if poisoned else "#a1201c", "#8fe04a" if poisoned else "#ff5d5d", low, "Lebenspunkte" + (" (vergiftet)" if poisoned else ""))
	_bar(g, float(p.ausdauer) / ma, "Ausdauer %s/%d" % [J.s(p.ausdauer), ma], "#237a45", "#62d68f", false, "Ausdauer: Angriffe kosten Ausdauer, Warten füllt sie auf")
	if not J.arr(p, "spells").is_empty():
		var mm := Magic.max_mp(s, b)
		_bar(g, J.num(p, "mp") / maxf(1, mm), "Mana %s/%d" % [J.s(J.nn(p, "mp", 0)), mm], "#1e4fb3", "#6fa8ff", false, "Mana für Zauber")
	if Game.has_unlock(s, "inventar"):
		var bl := J.num(p, "blase")
		_bar(g, bl / 100.0, "Blase %d %%" % J.rnd(bl), "#b3261e" if bl >= 80 else "#8a7a1e", "#ff8a4a" if bl >= 80 else "#e0d04a", bl >= 80, "Such eine Toilette, bevor es zu spät ist." if bl >= 80 else "Blase: steigt mit der Zeit")
	if g.get_child_count() % 2 == 1:
		g.add_child(Control.new())
	var xp := Kit.bar(root, float(p.xp) / need, "", "#5a3fc4", "#b39cff", 6)
	xp.tooltip_text = "Erfahrung %s / %d bis Level %d" % [J.s(p.xp), need, p.level + 1]
	# Zustände und Begleiter in einer Zeile
	var bits: Array = []
	for id in Conditions.IDS:
		if Conditions.player_has(s, id):
			bits.append(Kit.col(Conditions.CONDITIONS[id].state, "danger"))
	for x in p.buffs:
		if Conditions.IDS.any(func(id): return Conditions.CONDITIONS[id].buff == x.name):
			continue
		bits.append(Kit.col("%s %s" % [Kit.esc(x.name), Kit.small("(%s)" % J.s(x.turns))], "danger" if x.get("debuff", false) else "ok"))
	if J.num(p, "immobile"):
		bits.append(Kit.col("Festgehalten (%s)" % J.s(p.immobile), "danger"))
	var pet = p.get("pet")
	if pet != null:
		bits.append(Kit.col("%s %s" % [Kit.esc(pet.name), ("%d/%d" % [pet.hp, pet.maxHp]) if pet.alive else "bewusstlos"], "#ffb3e6"))
	var mo = p.get("mount")
	if mo != null:
		bits.append(Kit.col("%s %s" % [Kit.esc(mo.name), "erholt sich" if mo.get("down", false) else "%d/%d" % [mo.hp, mo.maxHp]], "#c8b48a"))
	var party := Crawlers.party(s)
	if not party.is_empty():
		bits.append(Kit.col("Party %d" % (party.size() + 1), "#8fe38f"))
	if not bits.is_empty():
		Kit.text(root, " · ".join(bits), 12)


static func _bar(parent: Node, frac: float, t: String, c0: String, c1: String, pulse: bool, tip: String) -> void:
	var b := Kit.bar(parent, frac, t, c0, c1, 18, pulse)
	b.font_size = UiFonts.px(12)
	b.tooltip_text = tip
