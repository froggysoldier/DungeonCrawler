class_name GameHere
extends RefCounted
## Der Bereich „Hier“ oben in der Seitenleiste:
## Gegenstände am Boden, Treppe, Türen, andere Crawler, Fallen und alles,
## was ein Safe Room bietet (Automat, Wirt, Bett, Toilette, Laden, Boxen),
## in der Gilde die Boxen.

const FURNITURE_NAMES := {"automat": "Gratis-Automat", "wirt": "Wirt an der Theke", "bett": "Bett", "toilette": "Toilette", "schrein": "Schrein", "bildschirm": "Bildschirm"}


static func _row(parent: Node, bb: String, size: int = 14) -> HBoxContainer:
	var h := Kit.hbox(parent, 6)
	var t := Kit.text(h, bb, size)
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return h


static func build(gv: GameView, root: VBoxContainer) -> void:
	var s := gv.s
	var room = Game.current_room(s)
	var items := Game.items_at(s, s.player.pos)
	var any := false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	if not items.is_empty():
		any = true
		Kit.section(v, "Hier liegt")
		for e in items:
			var uid: String = e.item.uid
			var h := Kit.hbox(v, 8)
			var look := Sprites.item_sprite(e.item)
			Kit.icon(h, look[0], look[1], 1)
			Kit.text(h, Kit.col(Kit.esc(Identify.item_name(s, e.item)), Db.t("items", "RARITY_COLORS")[e.item.rarity]), 14).size_flags_vertical = Control.SIZE_SHRINK_CENTER
			Kit.button(h, "Aufheben", func(): gv.act(func(): return Game.pickup(s, uid)), "SmallButton")
			if e.item.kind == "ausruestung" and (e.item.get("slot") != "waffe" or Game.has_unlock(s, "inventar")):
				Kit.button(h, "Anlegen" if e.item.get("slot") == "waffe" else "Anziehen", func(): gv.act(func(): return Game.wear_from_ground(s, uid)), "SmallButton")
	if Game.on_stairs(s):
		any = true
		Kit.spacer(v, 4)
		Kit.button(v, "Hinabsteigen (Enter)", gv.ask_descend, "PrimaryButton").size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var doors := Game.adjacent_open_doors(s)
	if not doors.is_empty():
		any = true
		var f := Kit.flow(v, 4)
		for d in doors:
			var at := {"x": d.x, "y": d.y}
			Kit.button(f, "Tür schließen", func(): gv.act(func(): return Game.close_door(s, at)), "SmallButton")
	var locked := Game.adjacent_locked_doors(s)
	if not locked.is_empty():
		any = true
		Kit.section(v, "Verschlossene Tür")
		for d in locked:
			var at := {"x": d.x, "y": d.y}
			var f := Kit.flow(v, 4)
			if Dungeon.has_key_for(s, at):
				Kit.button(f, "Aufschließen", func(): gv.act(func(): return Game.open_door(s, at)), "SmallButton")
			Kit.button(f, "Schloss knacken (%d %%)" % J.rnd(Dungeon.lockpick_chance(s) * 100), func(): gv.act(func(): return Game.pick_lock(s, at)), "SmallButton")
	var wrecks := Tiefgarage.adjacent_wrecks(s)
	if not wrecks.is_empty():
		any = true
		var fw := Kit.flow(v, 4)
		for wr in wrecks:
			var wat := {"x": wr.x, "y": wr.y}
			Kit.button(fw, "Wrack durchsuchen", func(): gv.act(func(): return Game.search_wreck(s, wat)), "SmallButton")
	var crates := Dungeon.adjacent_crates(s)
	if not crates.is_empty():
		any = true
		var f := Kit.flow(v, 4)
		for c in crates:
			var at := {"x": c.x, "y": c.y}
			var label := "Kiste zerschlagen" if MapGen.tile_at(s.map, c.x, c.y) == "kiste" else "Fass zerschlagen"
			Kit.button(f, label, func(): gv.act(func(): return Game.smash(s, at)), "SmallButton")
	var people := Crawlers.talkable(s)
	if not people.is_empty():
		any = true
		Kit.section(v, "Andere Crawler")
		var healer = Player.heal_item(s)
		for c in people:
			var uid: String = c.uid
			var party: bool = c.get("party", false)
			Kit.text(v, Kit.col("%s · HP %d/%d" % [Kit.esc(Crawlers.describe(c)), c.hp, c.maxHp], "#8fe38f" if party else "#7cc4ff"), 12)
			var f := Kit.flow(v, 4)
			Kit.button(f, "Ansprechen", func(): gv.act(func(): return Game.talk_crawler(s, uid)), "SmallButton")
			var pers: Dictionary = Db.t("crawlers", "PERSONALITIES")[c.personality]
			if party:
				Kit.button(f, "Entlassen", func(): gv.act(func(): return Game.dismiss_crawler(s, uid)), "SmallButton")
			elif c.get("met", false) and pers.join > 0:
				Kit.button(f, "In die Party einladen (%d %%)" % J.rnd(Crawlers.join_chance(s, c) * 100), func(): gv.act(func(): return Game.invite_crawler(s, uid)), "SmallButton")
			elif not c.get("met", false):
				Kit.button(f, "In die Party einladen", func(): gv.act(func(): return Game.invite_crawler(s, uid)), "SmallButton")
			if not c.get("tipGiven", false) and not party:
				Kit.button(f, "Nach Tipps fragen", func(): gv.act(func(): return Game.ask_crawler_tip(s, uid)), "SmallButton")
			if healer != null and c.hp < c.maxHp:
				var hid: String = healer.uid
				Kit.button(f, "%s geben" % Identify.item_name(s, healer), func(): gv.act(func(): return Game.heal_crawler(s, uid, hid)), "SmallButton")
			GameTabs.quest_card(gv, v, Quests.quest_of(s, uid))
	var near_traps := ViewHelpers.disarmable_traps(s)
	if not near_traps.is_empty():
		any = true
		Kit.section(v, "Fallen in der Nähe")
		for tr in near_traps:
			var uid: String = tr.uid
			if tr.get("owner") == "crawler":
				var h := _row(v, Kit.col("Deine " + Kit.esc(Traps.trap_name(tr.kind)), "#6ee07a"))
				Kit.button(h, "Abbauen", func(): gv.act(func(): return Game.disarm_trap(s, uid)), "SmallButton")
			else:
				var h := _row(v, Kit.col(Kit.esc(Traps.trap_name(tr.kind)), "danger"))
				Kit.button(h, "Entschärfen (%d %%)" % J.rnd(Traps.disarm_chance(s, tr) * 100), func(): gv.act(func(): return Game.disarm_trap(s, uid)), "SmallButton")
	if room != null and room.kind == "safe":
		any = true
		_safe_room(gv, v, room)
	elif room != null and room.kind == "guild" and not s.player.boxes.is_empty():
		any = true
		Kit.section(v, "Gilde")
		_boxes(gv, v)
	elif room != null and (room.get("feature") != null or not J.arr(room, "furniture").is_empty()):
		any = _feature_room(gv, v, room) or any
	if any:
		root.add_child(v)
		Kit.spacer(root, 6)
		GameView._line(root)
	else:
		v.free()


static func _safe_room(gv: GameView, v: VBoxContainer, room: Dictionary) -> void:
	var s := gv.s
	var inside := Combat.is_in_safe_room(s, s.player.pos)
	Kit.section(v, "Safe Room")
	var furn := J.arr(room, "furniture")
	var near := func(kind: String) -> bool:
		for f in furn:
			if f.kind == kind and Fov.chebyshev(f.pos, s.player.pos) <= 1:
				return true
		return false
	var legacy := furn.is_empty()
	var any_near := false
	for f in furn:
		if Fov.chebyshev(f.pos, s.player.pos) <= 1:
			any_near = true
	if inside and not legacy and not any_near:
		var names: Array = []
		for f in furn:
			if f.kind == "haendler":
				var shop = room.get("shop")
				names.append("Händler (%s)" % (String(shop.keeper).split(",")[0] if shop != null else "Laden"))
			else:
				names.append(FURNITURE_NAMES.get(f.kind, f.kind))
		Kit.text(v, "Hier gibt es: %s. Lauf hinein oder klicke zweimal darauf, um sie zu benutzen." % Kit.esc(" · ".join(names)), 12, "muted")
	if legacy or near.call("automat"):
		_subhead(v, "Gratis-Automat")
		var taken: bool = room.get("freebieTaken", false)
		Kit.button(v, "Gratis-Gegenstand abgeholt" if taken else "Gratis-Gegenstand ziehen", func(): _freebie(gv), "SmallButton", taken).size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	if room.get("safeVariant") == "restaurant" and (legacy or near.call("wirt")):
		var hosts: Array = Db.world("RESTAURANT_HOSTS")
		var host: Dictionary = hosts[int(room.id) % hosts.size()]
		_subhead(v, "%s (%s) serviert" % [host.name, host.race])
		for m in Db.world("RESTAURANT_MENU"):
			var mid: String = m.id
			var buff = m.effekt.get("buff")
			var h := _row(v, "%s %s" % [Kit.esc(m.name), Kit.small(Kit.muted(Kit.esc(buff.name if buff != null else "")))])
			Kit.button(h, "%s G" % J.s(m.price), func(): gv.act(func(): return Game.buy_meal(s, mid)), "SmallButton", s.player.gold < m.price)
		Kit.spacer(v, 2)
		Kit.button(v, "Zimmer nehmen und schlafen (8 Std.)", func(): gv.act(func(): return Game.sleep(s)), "SmallButton").size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	if not inside:
		return
	if legacy or near.call("bett"):
		Kit.button(v, "Schlafen (8 Std.)", func(): gv.act(func(): return Game.sleep(s)), "SmallButton").size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	if legacy or near.call("toilette"):
		Kit.button(v, "Toilette benutzen", func(): gv.act(func(): return Game.toilet(s)), "SmallButton").size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	if legacy or near.call("bildschirm") or Invitations.pending(s) != null or Highlights.on_air(s):
		_screen(gv, v)
	var shop = room.get("shop")
	if shop != null and (legacy or near.call("haendler")):
		_shop(gv, v, room, shop)
	_boxes(gv, v)


## Lootboxen zum Öffnen (Safe Room und Gilde).
static func _boxes(gv: GameView, v: VBoxContainer) -> void:
	var boxes: Array = gv.s.player.boxes
	if boxes.is_empty():
		return
	Kit.spacer(v, 6)
	var bh := Kit.hbox(v, 6)
	var bl := Kit.text(bh, "Lootboxen [b]%d[/b]" % boxes.size(), 13)
	bl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if boxes.size() > 1:
		Kit.button(bh, "Alle öffnen", func(): _open_all(gv), "SmallPrimary")
	var shown := boxes if gv.show_all_boxes else boxes.slice(0, 3)
	for bx in shown:
		var uid: String = bx.uid
		var h := _row(v, Kit.col(Kit.esc(bx.name), Db.world("BOX_TIER_COLORS")[bx.box.tier]), 13)
		Kit.button(h, "Öffnen", func(): _open_box(gv, uid), "SmallButton")
	if boxes.size() > 3:
		Kit.button(v, "Weniger anzeigen" if gv.show_all_boxes else "%d weitere anzeigen" % (boxes.size() - 3), func():
			gv.show_all_boxes = not gv.show_all_boxes
			gv.refresh_here(), "LinkBtn").size_flags_horizontal = Control.SIZE_SHRINK_BEGIN


static func _shop(gv: GameView, v: VBoxContainer, room: Dictionary, shop: Dictionary) -> void:
	var s := gv.s
	_subhead(v, "Laden" if room.kind == "safe" else String(shop.get("title", "Wanderhändler")))
	Kit.text(v, Kit.esc(shop.keeper) + (" – wirkt verstimmt" if shop.mood < 70 else ""), 12, "muted")
	var offers: Array = shop.offers
	for i in offers.size():
		var o: Dictionary = offers[i]
		var idx: int = i
		var total := Shop.offer_price(o.price, o.item, s)
		var menge := J.num(o.item, "menge")
		var h := Kit.hbox(v, 6)
		var name_l := Kit.text(h, Kit.col(Kit.esc(Identify.item_name(s, o.item)) + (" ×%s" % J.s(menge) if menge > 1 else ""), Db.t("items", "RARITY_COLORS")[o.item.rarity]), 13)
		name_l.tooltip_text = ", ".join(Identify.describe_item(s, o.item).bonuses)
		name_l.mouse_filter = Control.MOUSE_FILTER_PASS
		name_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		Kit.label(h, "%d G" % total, 12, "muted").size_flags_vertical = Control.SIZE_SHRINK_CENTER
		Kit.button(h, "Kaufen", func(): gv.act(func(): return Game.buy_offer(s, idx)), "SmallButton", s.player.gold < total)
		Kit.button(h, "Feilschen", func(): gv.act(func(): return Game.haggle_offer(s, idx)), "SmallButton", o.get("haggled", false))
	Kit.text(v, "Verkaufen: im Inventar-Tab beim Gegenstand.", 12, "muted")
	GameTabs.quest_card(gv, v, Quests.quest_of(s, str(room.id)))


## Der Bildschirm: Highlights ansehen, Einladungen annehmen oder absagen.
static func _screen(gv: GameView, v: VBoxContainer) -> void:
	var s := gv.s
	_subhead(v, "Bildschirm")
	if Highlights.on_air(s):
		Kit.button(v, "Abgrund am Abend ansehen", func(): gv.act(func(): return Game.watch_screen(s)), "SmallPrimary").size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	else:
		Kit.text(v, Kit.esc(Highlights.screen_text(s)), 12, "muted")
	var inv = Invitations.pending(s)
	if inv != null:
		Kit.text(v, "Einladung: [b]%s[/b] (gilt noch %s)" % [Kit.esc(Invitations.format_name(inv.format)), ViewHelpers.format_time(maxi(0, int(inv.until) - int(s.turn)))], 13)
		var f := Kit.flow(v, 4)
		Kit.button(f, "Teilnehmen", func(): gv.act(func(): return Game.accept_invitation(s)), "SmallPrimary")
		Kit.button(f, "Absagen", func(): gv.act(func(): return Game.decline_invitation(s)), "SmallButton")


## Besondere Räume: Schrein, Nest, Wanderhändler.
static func _feature_room(gv: GameView, v: VBoxContainer, room: Dictionary) -> bool:
	var s := gv.s
	var any := false
	for f in J.arr(room, "furniture"):
		if Fov.chebyshev(f.pos, s.player.pos) > 1:
			continue
		match f.kind:
			"schrein":
				any = true
				Kit.section(v, "Schrein")
				Kit.text(v, "Eine flackernde Kerze, ein paar Opfergaben. Beten kann helfen. Oder auch nicht.", 12, "muted")
				var ff: Dictionary = f
				Kit.button(v, "Beten", func(): gv.act(func(): return Game.use_furniture(s, ff)), "SmallButton").size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			"schrein_leer":
				any = true
				Kit.text(v, "Der Schrein ist erloschen.", 12, "muted")
			"toilette":
				any = true
				Kit.section(v, "Toilette")
				Kit.text(v, "Eine einsame Toilette. Die Regel gilt hier genauso.", 12, "muted")
				Kit.button(v, "Toilette benutzen", func(): gv.act(func(): return Game.toilet(s)), "SmallButton").size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			"haendler":
				if room.get("shop") != null:
					any = true
					_shop(gv, v, room, room.shop)
	return any


static func _subhead(v: Node, text: String) -> void:
	Kit.spacer(v, 4)
	Kit.label(v, text, 13, null, 700)


static func _freebie(gv: GameView) -> void:
	var got := {"item": null}
	gv.act(func():
		var res := Game.take_freebie(gv.s)
		got.item = res.get("item")
		return res)
	if got.item != null:
		GameDialogs.reveal_items(gv, "Gratis-Automat", [got.item])


static func _open_box(gv: GameView, uid: String) -> void:
	var box = J.find(gv.s.player.boxes, func(x): return x.uid == uid)
	var got := {"items": null}
	gv.act(func():
		var res := Game.open_box(gv.s, uid)
		got.items = res.get("contents")
		return res)
	if got.items != null and box != null:
		GameDialogs.reveal_items(gv, box.name, got.items, box.box.tier)


static func _open_all(gv: GameView) -> void:
	var opened: Array = []
	for box in gv.s.player.boxes.duplicate():
		var got := {"items": null}
		var uid: String = box.uid
		var ok := gv.act(func():
			var res := Game.open_box(gv.s, uid)
			got.items = res.get("contents")
			return res)
		if not ok or got.items == null:
			break
		opened.append({"name": box.name, "items": got.items, "tier": box.box.tier})
	if not opened.is_empty():
		GameDialogs.reveal_boxes(gv, opened)
