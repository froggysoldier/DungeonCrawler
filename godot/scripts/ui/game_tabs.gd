class_name GameTabs
extends RefCounted
## Die Reiter der Seitenleiste: Crawler, Inventar,
## Handwerk, Skills, Erfolge (mit Statistik) und die Gegenstandskarte.

const EQUIP_ORDER := [
	"kopf", "gesicht", "hals", "schultern", "brust", "ruecken", "arme", "haende", "ring1", "ring2",
	"guertel", "beine", "fuesse", "fussring1", "fussring2", "unterwaesche", "waffe",
]
const EQUIP_EXTRA := {"ring1": "Ring 1", "ring2": "Ring 2", "fussring1": "Fußring 1", "fussring2": "Fußring 2"}


static func equip_name(slot: String) -> String:
	if EQUIP_EXTRA.has(slot):
		return EQUIP_EXTRA[slot]
	return Db.t("items", "SLOT_NAMES").get(slot, slot)


static func rarity_color(r: String) -> String:
	return Db.t("items", "RARITY_COLORS")[r]


static func race_name(id: String) -> String:
	return String(Db.race(id).name).replace(" (bleiben, wie du bist)", "")


# ================================================================ Gegenstandskarte

## Eine Gegenstandskarte mit Werten und (optional) Knöpfen.
static func item_card(gv: GameView, parent: Node, it: Dictionary, with_actions: bool, from: String = "inv") -> VBoxContainer:
	var v := Kit.card(parent, "Item", 2)
	var h := Kit.hbox(v, 10)
	var look := Sprites.item_sprite(it)
	Kit.icon(h, look[0], look[1], 1, Vector2(36, 36)).size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	item_body(gv, Kit.vbox(h, 2), it, with_actions, from)
	return v


static func item_body(gv: GameView, v: Node, it: Dictionary, with_actions: bool, from: String = "inv") -> void:
	var s := gv.s
	var bits: Array = []
	if it.get("slot") != null:
		bits.append(Db.t("items", "SLOT_NAMES")[it.slot])
	if it.kind == "wurf":
		bits.append("Wurfschaden %s" % J.s(it.get("wurfSchaden", 0)))
	if it.get("waffenSchaden"):
		bits.append("Waffenschaden %s" % J.s(it.waffenSchaden))
	if it.kind != "gold":
		bits.append(Db.t("items", "RARITY_NAMES")[it.rarity])
	var known := Identify.describe_item(s, it)
	var bon: Array = known.bonuses.duplicate()
	var eff = it.get("effekt")
	if eff != null:
		if eff.get("heal"):
			bon.append("Heilt %s HP" % J.s(eff.heal))
		if eff.get("healPct"):
			bon.append("Heilt %s %% der HP" % J.s(eff.healPct))
		if eff.get("mana"):
			bon.append("+%s Mana" % J.s(eff.mana))
		if eff.get("manaPct"):
			bon.append("Füllt %s %% Mana" % J.s(eff.manaPct))
		if eff.get("cure"):
			bon.append("Heilt Vergiftung")
	if it.kind == "buch" and it.get("spell") != null:
		bon.append("Lehrt den Zauber: %s" % Db.spell(it.spell).name)
	if eff != null:
		if eff.get("ausdauer"):
			bon.append("+%s Ausdauer" % J.s(eff.ausdauer))
		if eff.get("buff") != null:
			bon.append("%s: %s" % [eff.buff.name, ", ".join(Bonuses.describe(eff.buff.get("bonuses")))])
	if it.get("explosion"):
		bon.append("Explodiert: etwa %s Schaden an allem im Umkreis von einem Feld" % J.s(it.explosion))
	if it.get("trapKind") != null:
		bon.append("Falle zum Aufstellen: %s" % Traps.trap_name(it.trapKind))
	if it.get("upgrades"):
		bon.append("%sx benagelt" % J.s(it.upgrades))
	var pb = it.get("petBonus")
	if pb != null:
		var pbits: Array = []
		if pb.get("hp"):
			pbits.append("+%s HP" % J.s(pb.hp))
		if pb.get("dmg"):
			pbits.append("+%s Schaden" % J.s(pb.dmg))
		bon.append("Haustier: %s" % ", ".join(pbits))
	var menge := J.num(it, "menge")
	var title := Kit.esc(known.name) + (" ×%s" % J.s(menge) if menge > 1 and it.kind != "gold" else "")
	Kit.text(v, "[b]%s[/b]" % Kit.col(title, rarity_color(it.rarity)))
	Kit.text(v, Kit.esc(" · ".join(bits)), 12, "muted")
	if not bon.is_empty():
		Kit.text(v, Kit.esc(", ".join(bon)), 12, "ok")
	if known.get("flavor") != null:
		Kit.text(v, "[i]%s[/i]" % Kit.esc(known.flavor), 12, "muted")
	if known.get("note") != null:
		Kit.text(v, Kit.esc(known.note), 12, "danger")
	if not with_actions:
		return
	var uid: String = it.uid
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", 4)
	f.add_theme_constant_override("v_separation", 4)
	var n := 0
	if it.kind == "ausruestung" and from == "inv" and Game.has_unlock(s, "inventar"):
		Kit.button(f, "Anlegen", func(): gv.act(func(): return Game.equip(s, uid)), "SmallButton")
	if it.kind == "verbrauch":
		Kit.button(f, "Benutzen", func(): gv.act(func(): return Game.use_item(s, uid)), "SmallButton")
	if it.kind == "karte" and from == "inv":
		Kit.button(f, "Lesen", func(): gv.act(func(): return Game.use_item(s, uid)), "SmallPrimary", false, "Das Viertel auf deiner Karte aufdecken")
	if it.kind == "buch":
		Kit.button(f, "Lesen", func(): gv.act(func(): return Game.use_item(s, uid)), "SmallButton")
	if pb != null and from == "inv" and s.player.get("pet") != null:
		Kit.button(f, "Dem Haustier anlegen", func(): gv.act(func(): return Game.pet_gear_on(s, uid)), "SmallButton")
	if it.get("trapKind") != null and from == "inv":
		Kit.button(f, "Hier aufstellen", func(): gv.act(func(): return Game.place_trap(s, uid)), "SmallButton")
	if it.kind == "wurf" and from == "inv":
		var th := Player.throwables(s)
		var picked: bool = not th.is_empty() and th[0].baseId == it.baseId
		if picked:
			Kit.button(f, "Wird als Nächstes geworfen", func(): gv.act(func(): return Game.choose_throwable(s, null)), "SmallButton", s.player.get("wurfWahl") == null)
		else:
			var bid: String = it.baseId
			Kit.button(f, "Als Nächstes werfen", func(): gv.act(func(): return Game.choose_throwable(s, bid)), "SmallButton")
	if from == "equip":
		var slot = J.find(EQUIP_ORDER, func(sl): return is_same(s.player.equipment.get(sl), it))
		if slot != null:
			var sl: String = slot
			Kit.button(f, "Ausziehen", func(): gv.act(func(): return Game.unequip(s, sl)), "SmallButton")
	else:
		Kit.button(f, "Ablegen", func(): gv.act(func(): return Game.drop_item(s, uid)), "SmallButton")
	var room = Game.current_room(s)
	if from == "inv" and room != null and room.kind == "safe" and Game.has_unlock(s, "handel") and it.kind != "box" and it.get("questId") == null:
		Kit.button(f, "Verkaufen (%d G)" % Shop.sell_price(it, s), func(): gv.act(func(): return Game.sell_item(s, uid)), "SmallButton")
	n = f.get_child_count()
	if n > 0:
		Kit.spacer(v, 2)
		v.add_child(f)
	else:
		f.free()


# ================================================================ Crawler

## Die Spielfigur mit Haustier als kleine Pixel-Bühne.
static func portrait(s: Dictionary) -> Control:
	var st := Kit.Stage.new()
	st.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Die Pack-Figur ist größer als eine Kachel: doppelt vergrößert passt sie ganz hinein
	st.items = [{"name": Sprites.hero_name(s.player), "scale": 2, "foot": Vector2(48, 106)}]
	st.custom_minimum_size = Vector2(96, 112)
	var pet = s.player.get("pet")
	if pet != null:
		var look := Sprites.pet_sprite(String(pet.get("species", "")))
		st.items.append({"name": look[0], "tint": look[1], "scale": 2, "foot": Vector2(112, 106), "flip": true, "mod": Color.WHITE if pet.alive else Color(1, 1, 1, 0.4)})
		st.custom_minimum_size.x = 146
	return st


## Abschnitt mit Knopf zum Ein- und Ausklappen. Gibt zurück, ob er offen ist.
static func fold(gv: GameView, root: Node, id: String, title: String, extra_bb: String = "", default_open: bool = true) -> bool:
	var open: bool = gv.folds.get(id, default_open)
	var h := Kit.section(root, title, extra_bb)
	var b := Kit.button(h, "−" if open else "+", func():
		gv.folds[id] = not open
		gv.refresh_side(), "SmallButton", false, "Einklappen" if open else "Ausklappen")
	b.custom_minimum_size = Vector2(24, 0)
	return open


static func crawler_tab(gv: GameView, root: VBoxContainer) -> void:
	var s := gv.s
	var p: Dictionary = s.player
	var b := Player.total_bonuses(s)
	var who := "früher: %s" % Kit.esc(p.background)
	if p.get("race") != null:
		who += " · " + Kit.esc(race_name(p.race))
	if p.get("klass") != null:
		who += " · [b]%s[/b]" % Kit.col(Kit.esc(Db.klass(p.klass).name), "accent")
	var me := Kit.hbox(root, 10)
	me.add_child(portrait(s))
	var mv := Kit.vbox(me, 2)
	mv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	Kit.label(mv, p.name, 20, null, 700).add_theme_font_override("font", UiFonts.pixel(700))
	Kit.text(mv, who, 12, "muted")
	if not Game.has_unlock(s, "stats"):
		Kit.spacer(root, 6)
		Kit.locked(root, "Gesperrt: Deine Werte siehst du erst nach dem Tutorial.\nFinde die [b]Gilde der Einweisung[/b].")
		Kit.section(root, "In der Hand")
		if p.get("hand") != null:
			item_row(gv, root, p.hand, "hand")
		else:
			Kit.text(root, "Nichts. Heb etwas auf (G).", 14, "muted")
		return
	var st := Player.effective_stats(s, b)
	var points := int(J.num(p, "statPoints"))
	Kit.section(root, "Werte", Kit.col("(%d Punkte frei)" % points, "ok") if points else "")
	var g := Kit.grid(root, 3, 10, 4)
	for k in Bonuses.STAT_NAMES:
		Kit.label(g, Bonuses.STAT_NAMES[k]).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var diff: float = st[k] - p.stats[k]
		var val := "[b]%s[/b]" % J.s(st[k])
		if diff:
			val += " " + Kit.small(Kit.muted("(%s%s)" % ["+" if diff > 0 else "", J.s(diff)]))
		var rt := Kit.text(g, val)
		rt.autowrap_mode = TextServer.AUTOWRAP_OFF
		rt.size_flags_horizontal = Control.SIZE_SHRINK_END
		if points:
			var key: String = k
			Kit.button(g, "+", func(): gv.act(func(): return Game.allocate_stat(s, key)), "SmallButton")
		else:
			g.add_child(Control.new())
	Kit.section(root, "Kampf")
	var w = Player.current_weapon(s)
	var kv := Kit.grid(root, 2, 10, 4)
	for row in [
		["Rüstung", J.s(J.num(b, "ruestung"))],
		["Ausweichen", "%d %%" % J.rnd(Player.ausweichen(s, b))],
		["Krit-Chance", "%s %%" % J.s(5 + J.num(b, "krit") + maxf(0, st.ges - 5))],
		["Waffe", w.name if w != null else "–"],
		["Sichtweite", FreeMove.meters(Player.lichtradius(s, b))],
	]:
		Kit.label(kv, row[0]).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		Kit.label(kv, row[1], 14, null, 700)
	if not p.buffs.is_empty():
		Kit.section(root, "Effekte")
		for x in p.buffs:
			var debuff: bool = x.get("debuff", false)
			var line := "%s %s%s %s" % ["Negativ:" if debuff else "Positiv:", Kit.esc(x.name), (" (−%s HP/Zug)" % J.s(x.dot)) if x.get("dot") else "", Kit.muted("(%s Züge)" % J.s(x.turns))]
			Kit.text(root, line, 12, "danger" if debuff else null)
	if p.get("klass") != null:
		var kd = Db.klass(p.klass)
		var rd = Db.race(p.race) if p.get("race") != null else null
		var specials: Array = []
		if rd != null:
			specials.append_array(J.arr(rd, "specials"))
		if kd != null:
			specials.append_array(J.arr(kd, "specials"))
		if fold(gv, root, "klasse", "Klasse und Rasse"):
			if kd != null:
				Kit.text(root, "[b]%s[/b] %s · Fähigkeit: %s" % [Kit.esc(kd.name), Kit.muted("(%s)" % Db.t("classes", "ARCHETYPE_NAMES")[kd.archetype]), Kit.esc(Db.t("classes", "ABILITIES")[kd.ability].name)], 12)
			if not J.arr(p, "classSkills").is_empty():
				Kit.text(root, "Klassenskills: %s" % Kit.esc(", ".join(p.classSkills.map(func(id): return Db.skill(id).name if Db.skill(id) != null else id))), 12, "muted")
			for sp in specials:
				var t = Db.t("specials", "SPECIAL_TEXT").get(sp)
				Kit.text(root, "[b]%s:[/b] %s" % [Kit.esc(t.name if t != null else sp), Kit.muted(Kit.esc(t.text if t != null else ""))], 12)
	if not J.arr(p, "traits").is_empty() and fold(gv, root, "traits", "Eigenschaften", Kit.muted("(%d)" % p.traits.size()), false):
		for id in p.traits:
			var t = Db.trait_def(id)
			if t == null:
				continue
			Kit.text(root, "[b]%s[/b] %s\n%s" % [Kit.esc(t.name), Kit.muted("(%s)" % Db.t("traits", "TRAIT_KIND_NAMES")[t.kind]), Kit.muted(Kit.esc(t.description))], 12)
	if J.num(p, "immobile"):
		Kit.text(root, "Festgehalten: noch %s Züge (oder losreißen, indem du dich bewegst)" % J.s(p.immobile), 12, "danger")
	if not p.curses.is_empty():
		Kit.section(root, "Flüche")
		for c in p.curses:
			Kit.text(root, Kit.esc(c), 12, "danger")
	if p.get("pet") != null:
		_pet(gv, root)
	if p.get("mount") != null:
		var mo: Dictionary = p.mount
		var md: Dictionary = Db.t("mounts", "MOUNTS")[mo.id]
		Kit.section(root, "Reittier")
		var line := "[b]%s[/b] · %s" % [Kit.esc(mo.name), "erholt sich (schlafen)" if mo.get("down", false) else "HP %d/%d" % [mo.hp, mo.maxHp]]
		if mo.get("fuel") != null:
			line += " · Tank %s/%s" % [J.s(mo.fuel), J.s(md.fuel)]
		line += " · Tempo %s Schritte pro Zug · Rammen +%s Schaden" % [J.s(md.speed), J.s(md.ram)]
		if md.get("ruestung"):
			line += " · +%s Rüstung" % J.s(md.ruestung)
		Kit.text(root, line, 12)
		Kit.text(root, "Beritten: Anlauf rammt ohne Anlauf zu Fuß und kostet nur 1 Ausdauer. Ein Teil der Treffer geht auf das Reittier.", 12, "muted")
		var f := Kit.flow(root, 4)
		Kit.button(f, "Absteigen (M)" if p.get("riding", false) else "Aufsitzen (M)", func(): gv.act(func(): return Game.ride_toggle(s)), "SmallButton")
		if md.kind == "fahrzeug":
			Kit.button(f, "Tanken", func(): gv.act(func(): return Game.refuel_mount(s)), "SmallButton")


## Die Show: Highlights, Einladungen und was als Nächstes möglich ist.
static func _show_card(s: Dictionary, root: VBoxContainer) -> void:
	if not Game.has_unlock(s, "zuschauer"):
		return
	var h := Highlights.state(s)
	var c := Kit.card(root)
	Kit.text(c, "[b]%s[/b]" % Kit.col("Abgrund am Abend", "achv"), 13)
	Kit.text(c, "Täglich um 21 Uhr am Bildschirm im Safe Room. Ins Programm kommt, wer spektakulär kämpft: besondere Kills, viele Kills, Bosse. Bisher %d-mal dabei, %d-mal die Szene des Tages." % [int(h.featured), int(h.top)], 12, "muted")
	var inv = Invitations.pending(s)
	if inv != null:
		Kit.text(c, "Einladung: [b]%s[/b] – im Safe Room am Bildschirm annehmen (noch %s)." % [Kit.esc(Invitations.format_name(inv.format)), ViewHelpers.format_time(maxi(0, int(inv.until) - int(s.turn)))], 12, "accent")
	var names := []
	for id in Invitations.formats():
		var f: Dictionary = Invitations.formats()[id]
		var ok: bool = int(s.viewers.follower) >= int(f.minFollower)
		names.append(("%s ab %s Follower" % [Invitations.format_name(id), J.de(int(f.minFollower))]) + ("" if ok else " (noch nicht)"))
	Kit.text(c, "Einladungen: " + Kit.esc(" · ".join(names)), 12, "muted")


## Ziele: Aufträge, Sponsoren, Viertel der Etage und Party.
static func goals_tab(gv: GameView, root: VBoxContainer) -> void:
	var s := gv.s
	var ev = ShowEvents.active_def(s)
	if ev != null:
		var c := Kit.card(root)
		Kit.text(c, "[b]%s[/b] %s" % [Kit.col("Einlage: " + Kit.esc(ev.name), "achv"), Kit.muted("(noch %d Züge)" % int(s.showEvent.left))], 13)
		Kit.text(c, Kit.esc(ev.text), 12, "muted")
		var tid = s.showEvent.get("bountyUid")
		var target = J.find(s.monsters, func(m): return m.uid == tid) if tid != null else null
		if target != null:
			Kit.text(c, "Ziel: %s im %s · %d Gold" % [Kit.esc(Identify.name_of(s, target, "nom")), Kit.esc(s.map.hoods[MapGen.hood_of(s.map, target.pos)].name), int(target.bounty)], 12, "accent")
	_show_card(s, root)
	var open := Quests.active_quests(s)
	var done_count := Quests.quests(s).filter(func(q): return q.status == "erledigt").size()
	Kit.section(root, "Aufträge", Kit.muted("(%d erledigt)" % done_count) if done_count else "")
	if not Game.has_unlock(s, "auftraege"):
		Kit.text(root, "Aufträge gibt es ab Etage %d." % Game.unlock_floor("auftraege"), 12, "muted")
	elif open.is_empty():
		Kit.text(root, "Keine offenen Aufträge. Ladenbesitzer und andere Crawler vergeben welche – sprich sie an.", 12, "muted")
	for q in open:
		var v := Kit.card(root)
		var ready := Quests.can_turn_in(s, q)
		Kit.text(v, "[b]%s[/b] %s" % [Kit.col(Kit.esc(q.title), "ok" if ready else "accent"), Kit.muted("von " + Kit.esc(q.giver.name))], 13)
		Kit.text(v, Kit.esc(Quests.hint(s, q)), 12, "ok" if ready else "muted")
		if q.kind == "jagd" and J.num(q, "count") > 1:
			Kit.progress(v, J.num(q, "progress") / maxf(1, J.num(q, "count")), "%s von %s" % [J.s(q.progress), J.s(q.count)])
	if Game.has_unlock(s, "zuschauer"):
		_sponsors(gv, root)
	var hoods: Array = s.map.hoods
	var left: int = hoods.filter(func(h): return h.bossAlive).size()
	Kit.section(root, "Viertel", Kit.muted("(%d von %d Bossen besiegt)" % [hoods.size() - left, hoods.size()]))
	for h in hoods:
		var state := Kit.col("Boss besiegt", "ok") if not h.bossAlive else Kit.col("Boss lebt", "danger")
		Kit.text(root, "%s · %s%s" % [Kit.esc(h.name), state, Kit.muted(" · Karte gefunden") if h.get("mapFound", false) else ""], 12)
	var members := Crawlers.party(s)
	if not members.is_empty():
		Kit.section(root, "Party (%d von 4)" % (members.size() + 1))
		for c in members:
			Kit.text(root, "[b]%s[/b] · Level %d · HP %d/%d · %s Kills %s" % [Kit.col(Kit.esc(c.name), "#8fe38f"), c.level, c.hp, c.maxHp, J.s(J.nn(c, "kills", 0)), Kit.muted("(früher %s)" % Kit.esc(c.background))], 12)
	if not J.arr(s, "fallen").is_empty():
		Kit.spacer(root, 6)
		Kit.text(root, "Gefallen: " + Kit.esc(", ".join(s.fallen)), 12, "muted")


static func _pet(gv: GameView, root: VBoxContainer) -> void:
	var s := gv.s
	var pet: Dictionary = s.player.pet
	Kit.section(root, "Haustier")
	Kit.text(root, "[b]%s[/b] · %s · Stufe %s · %s · Schaden %s–%s" % [Kit.col(Kit.esc(pet.name), "#ffb3e6"), Kit.esc(PetEvo.form_name(pet)), J.s(pet.level), ("HP %d/%d" % [pet.hp, pet.maxHp]) if pet.alive else "bewusstlos", J.s(pet.dmg[0]), J.s(pet.dmg[1])], 12)
	var pa: Dictionary = Db.t("pets", "PET_ABILITIES")
	for a in J.arr(pet, "abilities"):
		var d = pa.get(a)
		if d != null:
			Kit.text(root, "[b]%s:[/b] %s" % [Kit.esc(d.name), Kit.muted(Kit.esc(d.text))], 12)
	if pet.get("gear") != null:
		var h := Kit.hbox(root, 6)
		Kit.text(h, "Halsband: " + Kit.esc(Identify.item_name(s, pet.gear)), 12).size_flags_vertical = Control.SIZE_SHRINK_CENTER
		Kit.button(h, "Abnehmen", func(): gv.act(func(): return Game.pet_gear_off(s)), "SmallButton")
	else:
		Kit.text(root, "Kein Halsband. Halsbänder gibt es in Haustier-Boxen.", 12, "muted")
	if pet.get("evolveReady", false):
		var v := Kit.card(root)
		Kit.text(v, "[b]%s[/b]" % Kit.col("Entwicklung möglich", "accent"))
		for f in PetEvo.evolve_options(pet):
			var ab: Dictionary = pa[f.ability]
			Kit.text(v, "[b]%s[/b]: %s\n%s" % [Kit.esc(f.name), Kit.esc(f.flavor), Kit.muted("+%s HP, +%s–%s Schaden, Fähigkeit: %s – %s" % [J.s(f.hp), J.s(f.dmg[0]), J.s(f.dmg[1]), Kit.esc(ab.name), Kit.esc(ab.text)])], 12)
			var fid: String = f.id
			Kit.button(v, "%s wählen" % f.name, func(): gv.act(func(): return Game.evolve_pet_to(s, fid)), "SmallButton").size_flags_horizontal = Control.SIZE_SHRINK_BEGIN


## Angebot oder Abgabe eines Auftrags beim Auftraggeber.
static func quest_card(gv: GameView, parent: Node, q: Variant) -> void:
	if q == null:
		return
	var s := gv.s
	var id: String = q.id
	if q.status == "angebot":
		var v := Kit.card(parent)
		Kit.text(v, "[b]%s[/b]" % Kit.col("Auftrag: " + Kit.esc(q.title), "accent"))
		Kit.text(v, Kit.esc(q.text), 12, "muted")
		Kit.text(v, "Belohnung: %s Gold, %s XP%s" % [J.s(q.reward.gold), J.s(q.reward.xp), ", eine Lootbox" if q.reward.get("box") else ""], 12, "ok")
		var f := Kit.flow(v, 4)
		Kit.button(f, "Annehmen", func(): gv.act(func(): return Game.accept_quest_offer(s, id)), "SmallButton")
		Kit.button(f, "Ablehnen", func(): gv.act(func(): return Game.decline_quest_offer(s, id)), "SmallButton")
		return
	if Quests.can_turn_in(s, q):
		Kit.button(parent, "Auftrag abgeben: " + q.title, func(): gv.act(func(): return Game.turn_in_quest(s, id)), "SmallPrimary").size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		return
	Kit.text(parent, "Offener Auftrag: %s – %s" % [Kit.esc(q.title), Kit.esc(Quests.hint(s, q))], 12, "muted")


static func _sponsors(gv: GameView, root: VBoxContainer) -> void:
	var s := gv.s
	Kit.section(root, "Sponsoren")
	var n := 0
	for st in Sponsors.states(s):
		if st.status == "none" and st.interest < 20:
			continue
		var d = Db.sponsor(st.id)
		if d == null:
			continue
		n += 1
		var id: String = d.id
		match st.status:
			"offer":
				var v := Kit.card(root)
				Kit.text(v, "[b]%s[/b]" % Kit.col("Angebot: " + Kit.esc(d.name), "accent"))
				Kit.text(v, Kit.esc(d.description), 12, "muted")
				Kit.text(v, "Mag nicht: " + Kit.esc(d.dislike.text), 12, "ok")
				var f := Kit.flow(v, 4)
				Kit.button(f, "Annehmen", func(): gv.act(func(): return Game.accept_sponsor_offer(s, id)), "SmallButton")
				Kit.button(f, "Ablehnen", func(): gv.act(func(): return Game.decline_sponsor_offer(s, id)), "SmallButton")
			"active":
				var w: Dictionary = d.wishes[st.wish]
				Kit.text(root, "[b]%s[/b] · Gunst %s · %s Wünsche erfüllt\nWunsch: %s %s" % [Kit.col(Kit.esc(d.name), "#8fe38f"), J.s(st.favor), J.s(st.completed), Kit.esc(w.text), Kit.muted("(%s/%s)" % [J.s(st.progress), J.s(w.count)])], 12)
			"dropped":
				Kit.text(root, "%s: Sponsoring beendet." % Kit.esc(d.name), 12, "muted")
			_:
				Kit.text(root, "%s beobachtet dich (Interesse %d %%)" % [Kit.esc(d.name), J.rnd(st.interest)], 12, "muted")
	if n == 0:
		Kit.text(root, "Noch interessiert sich niemand für dich. Mach eine gute Show.", 12, "muted")


# ================================================================ Inventar

static func inventory_tab(gv: GameView, root: VBoxContainer) -> void:
	var s := gv.s
	var p: Dictionary = s.player
	if not Game.has_unlock(s, "inventar"):
		Kit.locked(root, "Gesperrt: Kein Inventar. Du kannst nur einen Gegenstand in der Hand halten.\nFinde die [b]Gilde der Einweisung[/b].")
		Kit.section(root, "In der Hand")
		if p.get("hand") != null:
			item_row(gv, root, p.hand, "hand")
		else:
			Kit.text(root, "Nichts.", 14, "muted")
	else:
		Kit.section(root, "Dabei (%d)" % p.inventory.size())
		if p.inventory.is_empty():
			Kit.text(root, "Leer.", 14, "muted")
		else:
			Kit.text(root, "Klicke auf einen Eintrag für Einzelheiten und Aktionen.", 12, "muted")
		for it in p.inventory:
			item_row(gv, root, it)
	_box_list(gv, root)


## Lootboxen nach Art und Stufe gruppiert: eine öffnen, alle dieser Art und
## Stufe oder alle auf einmal. Gezeigt werden sie dann einzeln nacheinander.
static func _box_list(gv: GameView, root: VBoxContainer) -> void:
	var s := gv.s
	var p: Dictionary = s.player
	var h := Kit.section(root, "Lootboxen (%d)" % p.boxes.size())
	if p.boxes.is_empty():
		Kit.text(root, "Keine. Achievements bringen Boxen!", 14, "muted")
		return
	var can := Combat.can_open_boxes(s, p.pos)
	if p.boxes.size() > 1:
		var all: Array = p.boxes.map(func(b): return b.uid)
		Kit.button(h, "Alle öffnen (%d)" % all.size(), func(): GameDialogs.open_boxes(gv, all), "SmallPrimary", not can)
	if not can:
		Kit.text(root, "Öffnen kannst du sie in einem Safe Room oder einer Gilde.", 12, "muted")
	var tiers: Array = Db.world("BOX_TIERS")
	var groups := {}
	var order: Array = []
	for bx in p.boxes:
		var key := "%s|%s" % [bx.box.type, bx.box.tier]
		if not groups.has(key):
			groups[key] = []
			order.append(key)
		groups[key].append(bx)
	# Wertvollste zuerst
	order.sort_custom(func(a, b): return tiers.find(groups[a][0].box.tier) > tiers.find(groups[b][0].box.tier))
	for key in order:
		var list: Array = groups[key]
		var first: Dictionary = list[0]
		var row := Kit.hbox(root, 8)
		var look := Sprites.item_sprite(first)
		Kit.icon(row, look[0], look[1], 1, Vector2(28, 28))
		var name := Kit.text(row, "%s%s" % [Kit.col(Kit.esc(first.name), Db.world("BOX_TIER_COLORS")[first.box.tier]), (" ×%d" % list.size()) if list.size() > 1 else ""], 15)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var one: String = first.uid
		Kit.button(row, "Öffnen", func(): GameDialogs.open_boxes(gv, [one]), "SmallButton", not can)
		if list.size() > 1:
			var uids: Array = list.map(func(b): return b.uid)
			Kit.button(row, "Alle %d" % list.size(), func(): GameDialogs.open_boxes(gv, uids), "SmallButton", not can, "Alle Boxen dieser Art und Stufe nacheinander öffnen")


## Eine Zeile der Liste: Symbol, Name, Art. Ein Klick klappt Werte und
## Aktionen auf, ein zweiter wieder zu.
static func item_row(gv: GameView, parent: Node, it: Dictionary, from: String = "inv", label: String = "") -> void:
	var s := gv.s
	var key := "item:%s" % it.uid
	var open: bool = gv.folds.get(key, false)
	var row := ClickPanel.new("ListRow")
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(row)
	var h := Kit.hbox(row, 8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var look := Sprites.item_sprite(it)
	Kit.icon(h, look[0], look[1], 1, Vector2(28, 28))
	var menge := J.num(it, "menge")
	var name := Kit.esc(Identify.item_name(s, it)) + (" ×%s" % J.s(menge) if menge > 1 and it.kind != "gold" else "")
	var rt := Kit.text(h, Kit.col(name, rarity_color(it.rarity)), 15)
	rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var kind := label if label != "" else _kind_name(it)
	var k := Kit.label(h, kind, 12, "muted")
	k.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var arrow := Kit.label(h, "-" if open else "+", 16, UiTheme.ACCENT)
	arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	arrow.custom_minimum_size.x = 14
	row.pressed.connect(func():
		gv.folds[key] = not open
		gv.refresh_side())
	if open:
		var m := Kit.margin(parent, 38, 0, 6, 6)
		item_body(gv, Kit.vbox(m, 2), it, true, from)


static func _kind_name(it: Dictionary) -> String:
	if it.get("slot") != null:
		return Db.t("items", "SLOT_NAMES").get(it.slot, "")
	match String(it.kind):
		"verbrauch": return "Verbrauch"
		"wurf": return "Wurfwaffe"
		"buch": return "Buch"
		"material": return "Material"
		"box": return "Box"
		"karte": return "Gebietskarte"
	return ""


## Eigene Seite für die getragene Ausrüstung: belegte Plätze als Liste zum
## Aufklappen, darunter die freien Plätze.
static func gear_tab(gv: GameView, root: VBoxContainer) -> void:
	var s := gv.s
	var p: Dictionary = s.player
	var worn: Array = EQUIP_ORDER.filter(func(slot): return p.equipment.get(slot) != null)
	Kit.section(root, "Am Körper (%d)" % worn.size())
	if worn.is_empty():
		Kit.text(root, "Du trägst nichts Besonderes. Kleidung vom Boden ziehst du per Rechtsklick an.", 14, "muted")
	for slot in worn:
		item_row(gv, root, p.equipment[slot], "equip", equip_name(slot))
	var free: Array = EQUIP_ORDER.filter(func(slot): return p.equipment.get(slot) == null)
	if not free.is_empty():
		Kit.section(root, "Frei")
		Kit.text(root, Kit.esc(", ".join(free.map(func(slot): return equip_name(slot)))), 13, "muted")


# ================================================================ Handwerk

static func craft_tab(gv: GameView, root: VBoxContainer) -> void:
	var s := gv.s
	if not Game.has_unlock(s, "inventar"):
		Kit.locked(root, "Gesperrt: Ohne Inventar kein Handwerk.\nFinde die [b]Gilde der Einweisung[/b].")
		return
	var bench := Crafting.has_workbench(s)
	var intro := "Aus Kram, den du findest, baust du Sprengsätze, Fallen und Verbände. "
	if bench:
		intro += "[b]%s[/b]" % Kit.col("Eine Werkbank ist in Reichweite.", "ok")
	else:
		intro += "Aufwendige Rezepte brauchen eine Werkbank: in Werkstätten, Schmieden und Safe Rooms – oder eine Klappwerkbank im Rucksack."
	Kit.text(root, intro, 12, "muted")
	Kit.spacer(root, 4)
	for row in Crafting.all_recipes(s):
		var r: Dictionary = row.recipe
		var missing: Array = row.missing
		var v := Kit.card(root)
		var ing := ", ".join(r.ingredients.map(func(x): return "%sx %s" % [J.s(x.n), x.label]))
		Kit.text(v, "[b]%s[/b]%s" % [Kit.esc(r.name), (" " + Kit.small(Kit.muted("(Werkbank)"))) if r.get("workbench", false) else ""])
		Kit.text(v, Kit.esc(ing), 12, "muted")
		Kit.text(v, Kit.esc(r.description), 12, "ok")
		if not missing.is_empty():
			Kit.text(v, "Es fehlt: " + Kit.esc(", ".join(missing)), 12, "danger")
		var rid: String = r.id
		Kit.button(v, "Herstellen", func(): gv.act(func(): return Game.craft_item(s, rid)), "SmallButton", not missing.is_empty()).size_flags_horizontal = Control.SIZE_SHRINK_BEGIN


# ================================================================ Skills

## Techniken: gelernte mit Wirkung und Kosten, darunter die noch gesperrten
## mit der Bedingung (Skill-Stufe oder Wert) und wie weit man ist.
static func _technique_list(s: Dictionary, root: VBoxContainer) -> void:
	var learned := Techniques.learned(s)
	Kit.section(root, "Techniken (%d von %d)" % [learned.size(), Techniques.all().size()])
	Kit.text(root, "Skills und Werte schalten neue Kampfweisen frei: Ausführungen wie Stampfen, Sonderangriffe und Techniken für dich selbst. Im Kampf stehen sie in der Kampfleiste unter „Techniken“.", 12, "muted")
	var art_names := {"ausfuehrung": "Ausführung", "angriff": "Angriff", "selbst": "Selbst"}
	for d in learned:
		var v := Kit.vbox(root, 2)
		var top := Kit.hbox(v, 6)
		Kit.text(top, "[b]%s[/b] %s" % [Kit.esc(d.name), Kit.small(Kit.muted(art_names.get(d.art, "")))])
		var costs: Array = []
		if int(J.nn(d, "cost", 0)) > 0:
			costs.append("%d Ausdauer" % int(d.cost))
		if int(J.num(d, "mp")) > 0:
			costs.append("%d Mana" % int(d.mp))
		if int(J.nn(d, "cd", 0)) > 0:
			costs.append("Abklingzeit %d" % int(d.cd))
		if not costs.is_empty():
			Kit.label(top, " · ".join(costs), 12, "muted").size_flags_horizontal = Control.SIZE_SHRINK_END
		Kit.text(v, Kit.esc(d.description), 12, "ok")
	var locked := Techniques.all().filter(func(d): return not Techniques.known(s, d.id))
	if not locked.is_empty():
		Kit.spacer(root, 4)
		Kit.label(root, "NOCH GESPERRT", 16, "muted").add_theme_font_override("font", UiFonts.pixel(500, 1))
		for d in locked:
			var v := Kit.vbox(root, 1)
			Kit.text(v, "[b]%s[/b] %s" % [Kit.esc(d.name), Kit.small(Kit.muted("ab " + Kit.esc(Techniques.needs_text(d))))], 13, "muted")
			Kit.text(v, Kit.esc(d.description), 11, "muted")


static func skills_tab(gv: GameView, root: VBoxContainer) -> void:
	var s := gv.s
	var p: Dictionary = s.player
	if not Game.has_unlock(s, "skills"):
		Kit.locked(root, "Gesperrt: Die Skill-Übersicht gibt’s nach dem Tutorial. Gelernt wird trotzdem schon!")
	Kit.section(root, "Gelernte Skills")
	if p.skills.is_empty():
		Kit.text(root, "Noch keine. Kämpfe – der Dungeon beobachtet dich.", 14, "muted")
	var by_cat := {}
	var cat_order: Array = []
	for st in p.skills:
		var def = Db.skill(st.id)
		if def == null:
			continue
		if not by_cat.has(def.category):
			by_cat[def.category] = []
			cat_order.append(def.category)
		by_cat[def.category].append(st)
	var cat_names: Dictionary = Db.t("skills", "SKILL_CATEGORY_NAMES")
	for cat in cat_order:
		Kit.spacer(root, 4)
		Kit.label(root, String(cat_names[cat]).to_upper(), 16, "muted").add_theme_font_override("font", UiFonts.pixel(500, 1))
		for st in by_cat[cat]:
			var def: Dictionary = Db.skill(st.id)
			var need := Rules.skill_xp_needed(st.level)
			var is_max: bool = st.level >= def.maxLevel
			var v := Kit.vbox(root, 2)
			var top := Kit.hbox(v, 6)
			var cls := (" " + Kit.small(Kit.col("Klassenskill", "accent2"))) if J.arr(p, "classSkills").has(st.id) else ""
			Kit.text(top, "[b]%s[/b]%s" % [Kit.esc(def.name), cls])
			Kit.label(top, "Stufe %d/%d" % [st.level, def.maxLevel], 14).size_flags_horizontal = Control.SIZE_SHRINK_END
			Kit.text(v, "Jetzt: " + Kit.esc(Skills.effect_text(def, st.level)), 12, "ok")
			if is_max:
				Kit.text(v, "Gemeistert.", 12, "muted")
			else:
				Kit.text(v, "Nächste Stufe: " + Kit.esc(Skills.effect_text(def, st.level + 1)), 12, "muted")
				if Game.has_unlock(s, "skills"):
					Kit.progress(v, float(st.xp) / need, "%d von %d" % [floori(st.xp), need])
			Kit.spacer(root, 2)
	_technique_list(s, root)
	var dyn := J.arr(p, "dynSkills")
	Kit.section(root, "Vom Beobachter entdeckt")
	if dyn.is_empty():
		Kit.text(root, "Noch nichts. Die Systemstimme beobachtet, gegen wen, wie und in welcher Lage du kämpfst, und formt daraus eigene Skills.", 12, "muted")
	for k in dyn:
		var need := Observer.dyn_xp_needed(k.level)
		var v := Kit.vbox(root, 2)
		var top := Kit.hbox(v, 6)
		Kit.text(top, "[b]%s[/b]" % Kit.esc(k.name))
		Kit.label(top, "Stufe %d/10" % k.level).size_flags_horizontal = Control.SIZE_SHRINK_END
		Kit.text(v, Kit.esc(k.description), 12, "muted")
		Kit.progress(v, float(k.xp) / need)
	var hints := Observer.skill_hints(s)
	if not hints.is_empty():
		Kit.section(root, "Die Systemstimme beobachtet …")
		for h in hints:
			_progress_row(root, Kit.esc(h.name), "%s/%s" % [J.s(h.progress), J.s(h.needed)], float(h.progress) / h.needed)
	var found: Array = []
	for d in Db.t("skills", "SKILLS"):
		if d.unlockAt >= 9999 or J.some(p.skills, func(k): return k.id == d.id):
			continue
		var prog := Skills.skill_progress(s, d)
		if prog > 0:
			found.append({"d": d, "prog": prog})
	J.sort(found, func(a, b2): return b2.prog / b2.d.unlockAt - a.prog / a.d.unlockAt)
	if not found.is_empty():
		Kit.section(root, "Du spürst Fortschritt…")
		for x in found:
			_progress_row(root, Kit.esc(x.d.name), "%s/%s" % [J.s(x.prog), J.s(x.d.unlockAt)], x.prog / x.d.unlockAt)
	var uses: Array = []
	for key in p.techniqueUses:
		if not String(key).begins_with("_"):
			uses.append([key, p.techniqueUses[key]])
	J.sort(uses, func(a, b2): return b2[1] - a[1])
	uses = uses.slice(0, 8)
	if not uses.is_empty():
		Kit.section(root, "Dein Kampfstil")
		var total := 0.0
		for u in uses:
			total += u[1]
		for u in uses:
			var parts: PackedStringArray = String(u[0]).split("+")
			var h := Kit.hbox(root, 6)
			Kit.text(h, Kit.esc(Combat.technique_name({"part": parts[0], "move": parts[1] if parts.size() > 1 else "normal"})), 12)
			Kit.label(h, "%s× · %d %%" % [J.s(u[1]), J.rnd(100 * u[1] / total)], 12, "muted").size_flags_horizontal = Control.SIZE_SHRINK_END


static func _progress_row(root: Node, name_bb: String, count: String, frac: float) -> void:
	var v := Kit.vbox(root, 2)
	var top := Kit.hbox(v, 6)
	Kit.text(top, name_bb)
	Kit.label(top, count, 14, "muted").size_flags_horizontal = Control.SIZE_SHRINK_END
	Kit.progress(v, frac)
	Kit.spacer(root, 2)


# ================================================================ Erfolge

static func achievements_tab(gv: GameView, root: VBoxContainer) -> void:
	var s := gv.s
	var all_defs: Array = Db.t("achievements", "ACHIEVEMENTS")
	var have := {}
	for id in s.achievements:
		have[id] = true
	var done := all_defs.filter(func(a): return have.has(a.id))
	var patterns := J.arr(s, "dynAchievements")
	Kit.text(root, "Diese Staffel: %d Achievements · Karriere insgesamt: %d" % [done.size() + patterns.size(), gv.meta.achievementsEver.size()], 12, "muted")
	var nav := Kit.hbox(root, 6)
	for x in [["erfolge", "Erfolge"], ["statistik", "Statistik"]]:
		var id: String = x[0]
		Kit.button(nav, x[1], func():
			gv.achv_view = id
			gv.refresh_side(), "PrimaryButton" if gv.achv_view == id else "Button").size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if gv.achv_view == "statistik":
		stats_view(gv, root)
		return
	var tiers: Dictionary = Db.world("BOX_TIER_COLORS")
	var recent: Array = []
	for i in range(s.achievements.size() - 1, maxi(-1, s.achievements.size() - 5), -1):
		var a = Db.achievement(s.achievements[i])
		if a != null:
			recent.append(a)
	if not recent.is_empty():
		Kit.section(root, "Zuletzt erreicht")
		for a in recent:
			_achv_card(root, a, false, tiers)
	if not patterns.is_empty():
		var open: bool = gv.achv_open.has("muster")
		_cat_button(gv, root, "muster", "%s Entdeckte Muster" % ("−" if open else "+"), str(patterns.size()))
		if open:
			for i in range(patterns.size() - 1, -1, -1):
				_achv_card(root, patterns[i], false, tiers)
	var ever: Array = gv.meta.achievementsEver
	var goals := ViewHelpers.next_goals(s)
	for c in Db.t("achievements", "ACHIEVEMENT_CATEGORIES"):
		var all := all_defs.filter(func(a): return a.category == c.id)
		var got := all.filter(func(a): return have.has(a.id))
		var open: bool = gv.achv_open.has(c.id)
		_cat_button(gv, root, c.id, "%s %s" % ["−" if open else "+", c.name], "%d / %d" % [got.size(), all.size()])
		Kit.progress(root, float(got.size()) / all.size() if not all.is_empty() else 0.0)
		if not open:
			continue
		var next := goals.filter(func(g): return g.category == c.id and g.value < g.target)
		J.sort(next, func(a, b2): return b2.value / b2.target - a.value / a.target)
		next = next.slice(0, 6)
		if not next.is_empty():
			Kit.text(root, "Nächste Ziele", 12, "muted")
			for g in next:
				var v := Kit.vbox(root, 2)
				var top := Kit.hbox(v, 6)
				Kit.text(top, Kit.esc(g.description), 12)
				Kit.label(top, "%s / %s" % [J.de(g.value), J.de(g.target)], 12, "muted").size_flags_horizontal = Control.SIZE_SHRINK_END
				Kit.progress(v, minf(1.0, float(g.value) / g.target))
		for i in range(got.size() - 1, -1, -1):
			_achv_card(root, got[i], false, tiers)
		var old := all.filter(func(a): return not have.has(a.id) and ever.has(a.id))
		if not old.is_empty():
			Kit.text(root, "Aus früheren Staffeln", 12, "muted")
			for a in old:
				_achv_card(root, a, true, tiers)
		var hidden: int = all.size() - got.size() - old.size()
		if hidden > 0:
			Kit.text(root, "Noch %d geheime Achievements in dieser Kategorie." % hidden, 12, "muted")


static func _cat_button(gv: GameView, root: Node, id: String, label: String, count: String) -> void:
	Kit.spacer(root, 4)
	var cp := ClickPanel.new("CatButton")
	cp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cp.add_child(h)
	var l := Kit.label(h, label, 14, null, 700)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cp.track_label(l)
	Kit.label(h, count, 14, "muted")
	cp.pressed.connect(func():
		if gv.achv_open.has(id):
			gv.achv_open.erase(id)
		else:
			gv.achv_open[id] = true
		gv.refresh_side())
	root.add_child(cp)


static func _achv_card(root: Node, a: Dictionary, locked: bool, tiers: Dictionary) -> void:
	var v := Kit.card(root, "Item", 2)
	var color = tiers.get(a.get("tier", "")) if not locked and a.get("tier") != null else UiTheme.HEX.achv
	Kit.text(v, "[b]%s[/b]%s" % [Kit.col(Kit.esc(a.name), color if color != null else UiTheme.HEX.achv), (" " + Kit.small(Kit.col("MEISTERLEISTUNG", "accent"))) if a.get("meister", false) else ""])
	Kit.text(v, Kit.esc(a.description), 12)
	if not locked:
		Kit.text(v, "[i]%s[/i]" % Kit.esc(a.comment), 12, "muted")
	else:
		v.get_parent().modulate.a = 0.45


## Alles, was der Dungeon über dich mitzählt.
static func stats_view(gv: GameView, root: VBoxContainer) -> void:
	var s := gv.s
	var v := func(k: String) -> float: return Stats.stat(s, k)
	var rows := func(title: String, list: Array) -> void:
		var shown := list.filter(func(x): return not (x[1] is String and x[1] == "0") and not ((x[1] is int or x[1] is float) and x[1] == 0))
		if shown.is_empty():
			return
		Kit.section(root, title)
		for x in shown:
			var h := Kit.hbox(root, 6)
			Kit.text(h, Kit.esc(x[0]), 12)
			var val: String = J.de(J.rnd(x[1])) if not (x[1] is String) else x[1]
			Kit.label(h, val, 12, "muted").size_flags_horizontal = Control.SIZE_SHRINK_END
			GameView._line(root)
	var hits: float = v.call("treffer")
	var tries: float = hits + v.call("fehlschlaege")
	var c: Dictionary = s.counters
	rows.call("Kampf", [
		["Besiegte Gegner", v.call("kills")],
		["Treffer", hits],
		["Trefferquote", ("%d %%" % J.rnd(100 * hits / tries)) if tries else 0],
		["Kritische Treffer", v.call("krits")],
		["Schaden ausgeteilt", v.call("schaden.ausgeteilt")],
		["Höchster Einzeltreffer", v.call("max.treffer")],
		["Längste Killserie", v.call("max.killserie")],
		["Kills ohne erlittenen Treffer (Rekord)", v.call("max.sauber")],
		["Gegner zu Boden geworfen", c.knockdowns],
		["Benommen gemacht", v.call("zonen.benommen")],
		["Humpeln lassen", v.call("zonen.humpelt")],
		["Geschwächt", v.call("zonen.geschwaecht")],
		["Kills durch Konter", v.call("kills.konter")],
		["Blutungen zugefügt", v.call("zustand.blutung")],
		["Gegner in Brand gesetzt", v.call("zustand.brennen")],
		["Gegner vergiftet", v.call("zustand.gift")],
		["Gegnern Angst eingejagt", v.call("zustand.furcht")],
		["Gegner geblendet", v.call("zustand.blind")],
		["Kills an stärkeren Gegnern (3+ Stufen)", v.call("kills.staerker")],
		["Kills an schlafenden Gegnern", v.call("kills.schlafend")],
		["Kills an fliehenden Gegnern", v.call("kills.fliehend")],
	])
	var part_labels := Bonuses.PART_NAMES.duplicate()
	part_labels.merge({"zauber": "Zauber", "falle": "Fallen", "bombe": "Sprengsätze", "haustier": "Haustier", "party": "Party", "sonstiges": "Sonstiges", "blutung": "Blutung", "feuer": "Feuer", "gift": "Gift"}, true)
	var by_key := func(prefix: String, label: Callable) -> Array:
		var out: Array = []
		var st: Dictionary = J.nn(s, "stats", {})
		for k in st:
			if String(k).begins_with(prefix):
				out.append([label.call(String(k).substr(prefix.length())), st[k]])
		J.sort(out, func(a, b2): return b2[1] - a[1])
		return out
	rows.call("Kills nach Angriffsart", by_key.call("kills.teil.", func(id): return part_labels.get(id, id)))
	rows.call("Kills nach Ausführung", by_key.call("kills.bewegung.", func(id): return Combat.MOVE_NAMES.get(id, id)))
	rows.call("Kills nach Trefferzone", by_key.call("kills.zone.", func(id): return Combat.ZONES[id].name if Combat.ZONES.has(id) else id))
	var beasts: Array = by_key.call("kills.art.", func(id):
		if v.call("bekannt." + id):
			var m = Db.monster(id)
			return m.name if m != null else id
		return "Unbekannte Art")
	beasts = beasts.slice(0, 12)
	var best_rows: Array = [
		["Verschiedene Arten besiegt", v.call("bestiarium.arten")],
		["Elite-Gegner", v.call("kills.elite")],
		["Bosse", v.call("kills.boss")],
		["Nicht einschätzbare Gegner besiegt", v.call("kills.unbekannt")],
	]
	best_rows.append_array(beasts)
	rows.call("Bestiarium", best_rows)
	var wach: float = v.call("max.wach")
	rows.call("Überleben", [
		["Schaden eingesteckt", v.call("schaden.erlitten")],
		["Ausgewichen", v.call("ausgewichen")],
		["Knapp überlebt (unter 10 %)", v.call("knapp.ueberlebt")],
		["Zustände überstanden", v.call("zustand.erlitten")],
		["Tränke getrunken", c.potionsDrunk],
		["Mahlzeiten", c.mealsEaten],
		["Geschlafen", v.call("geschlafen")],
		["Längste Zeit ohne Schlaf", ("%d Std." % floori(wach * 3 / 60)) if wach else 0],
		["Toilettenbesuche", v.call("toilette")],
	])
	var erk: float = v.call("max.erkundet")
	rows.call("Erkundung", [
		["Schritte", c.steps],
		["Räume entdeckt", v.call("raeume.entdeckt")],
		["Safe Rooms entdeckt", v.call("saferooms.entdeckt")],
		["Türen geöffnet", v.call("tueren.geoeffnet")],
		["Türen geschlossen", v.call("tueren.geschlossen")],
		["Beste Erkundung einer Etage", ("%s %%" % J.s(erk)) if erk else 0],
		["Schritte auf dem Reittier", v.call("reittier.schritte")],
	])
	rows.call("Beute und Handel", [
		["Gegenstände aufgehoben", v.call("gegenstaende.aufgehoben")],
		["Boxen geöffnet", v.call("boxen.geoeffnet")],
		["Gold verdient", c.goldEarned],
		["Höchster Goldstand", v.call("max.gold")],
		["Gekauft", v.call("gekauft")],
		["Gold ausgegeben", v.call("gold.ausgegeben")],
		["Verkauft", v.call("verkauft")],
		["Preisverhandlungen gewonnen", v.call("feilschen.gewonnen")],
		["Rubbellose", v.call("lose")],
		["Davon Nieten", v.call("lose.nieten")],
	])
	rows.call("Handwerk und Fallen", [
		["Hergestellt", c.crafted],
		["Eigene Fallen aufgestellt", v.call("fallen.aufgestellt")],
		["Fallen entdeckt", c.trapsFound],
		["Fallen entschärft", c.trapsDisarmed],
		["Selbst in Fallen getreten", c.trapsTriggered],
		["Aus Fallen befreit", v.call("befreit")],
		["Zauber gewirkt", v.call("zauber.gewirkt")],
	])
	rows.call("Andere Crawler und Show", [
		["Crawler angesprochen", v.call("crawler.getroffen")],
		["Party-Beitritte", v.call("party.beigetreten")],
		["Party-Mitglieder verloren", v.call("party.verloren")],
		["Verletzte Crawler versorgt", v.call("crawler.geheilt")],
		["Aufträge erledigt", v.call("auftraege.erledigt")],
		["Aufträge verpatzt", v.call("auftraege.verpatzt")],
		["Sponsorenwünsche erfüllt", v.call("sponsor.wuensche")],
		["Geschenke aus dem Publikum", v.call("fangeschenke")],
		["Talkshow-Auftritte", v.call("talkshows")],
		["Follower", s.viewers.follower],
	])
