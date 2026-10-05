class_name ContextMenu
extends RefCounted
## Rechtsklick auf die Karte: ein Menü mit allem, was man mit dem Feld tun
## kann (aufheben, angreifen, ansprechen, benutzen, öffnen, zerschlagen,
## entschärfen, hinabsteigen, hingehen, untersuchen). Liegt das Ziel nicht in
## Reichweite, läuft die Figur erst hin und handelt dann.


## Aktionen für ein Feld: [[Text, Callable], ...].
static func actions(gv: GameView, t: Vector2i) -> Array:
	var s := gv.s
	var m: Dictionary = s.map
	if not MapGen.in_bounds(m, t.x, t.y):
		return []
	var i := MapGen.idx(m, t.x, t.y)
	if not m.explored[i]:
		return []
	var tp := {"x": t.x, "y": t.y}
	var seen := gv._vis_now().has(i)
	var on_player: bool = t.x == s.player.pos.x and t.y == s.player.pos.y
	var out: Array = []
	var mon = Ai.monster_at(s, tp) if seen else null
	if mon != null:
		var name: String = Identify.describe_monster(s, mon).name
		var uid: String = mon.uid
		out.append(["Angreifen: %s" % name, func(): gv.attack_or_approach(uid)])
	var npc = Crawlers.crawler_at(s, tp) if seen else null
	if npc != null and not npc.get("party", false):
		var cuid: String = npc.uid
		out.append(["Ansprechen: %s" % Crawlers.describe(npc), func(): gv.go_then(tp, true, func(): return Game.talk_crawler(s, cuid))])
	for e in Game.items_at(s, tp).slice(0, 5):
		var iuid: String = e.item.uid
		var iname := Identify.item_name(s, e.item)
		var wearable: bool = e.item.kind == "ausruestung" and (e.item.get("slot") != "waffe" or Game.has_unlock(s, "inventar"))
		var verb := "Anlegen" if e.item.get("slot") == "waffe" else "Anziehen"
		if on_player:
			out.append(["Aufheben: %s" % iname, func(): gv.act(func(): return Game.pickup(s, iuid))])
			if wearable:
				out.append(["%s: %s" % [verb, iname], func(): gv.act(func(): return Game.wear_from_ground(s, iuid))])
		else:
			out.append(["Aufheben: %s" % iname, func(): gv.go_then(tp, false, func(): return Game.pickup(s, iuid))])
			if wearable:
				out.append(["%s: %s" % [verb, iname], func(): gv.go_then(tp, false, func(): return Game.wear_from_ground(s, iuid))])
	var fu = MapGen.furniture_at(m, tp)
	if fu != null:
		var f: Dictionary = fu
		out.append(["Benutzen: %s" % GameHere.FURNITURE_NAMES.get(f.kind, String(f.kind).capitalize()), func(): gv.go_then(tp, true, func(): return Game.use_furniture(s, f))])
	var tile: String = m.tiles[i]
	if tile == "door":
		out.append(["Tür öffnen", func(): gv.go_then(tp, true, func(): return Game.move_step(s, tp))])
	if Dungeon.is_crate(tile):
		out.append(["Kiste zerschlagen" if tile == "kiste" else "Fass zerschlagen", func(): gv.go_then(tp, true, func(): return Game.smash(s, tp))])
	if tile == Tiefgarage.WRECK:
		out.append(["Wrack durchsuchen", func(): gv.go_then(tp, true, func(): return Game.search_wreck(s, tp))])
	var trap = Traps.known_trap_at(s, tp)
	if trap != null:
		var tuid: String = trap.uid
		var what: String = "Abbauen" if trap.get("owner") == "crawler" else "Entschärfen"
		out.append(["%s: %s" % [what, Traps.trap_name(trap.kind)], func(): gv.go_then(tp, true, func(): return Game.disarm_trap(s, tuid))])
	if tile == "stairs":
		if on_player:
			out.append(["Hinabsteigen", func(): gv.ask_descend()])
		else:
			out.append(["Zur Treppe gehen", func(): gv.go_then(tp, false, func(): return {"ok": true})])
	if on_player:
		out.append(["Einen Zug warten", func(): gv.act(func(): return Game.wait(s))])
	elif mon == null and npc == null and fu == null and MapGen.is_walkable(m, t.x, t.y):
		out.append(["Hierher gehen", func(): gv.go_then(tp, false, func(): return {"ok": true})])
	out.append(["Untersuchen", func(): gv.examine(t)])
	return out


## Menü an der Mausposition öffnen.
static func open(gv: GameView, t: Vector2i, at: Vector2) -> void:
	var list := actions(gv, t)
	if list.is_empty():
		return
	gv.context_count += 1
	var menu := PopupMenu.new()
	menu.add_theme_font_size_override("font_size", UiFonts.px(15))
	for k in list.size():
		menu.add_item(list[k][0], k)
	menu.id_pressed.connect(func(id: int): list[id][1].call())
	menu.popup_hide.connect(func(): menu.queue_free.call_deferred())
	gv.add_child(menu)
	menu.position = Vector2i(at)
	menu.popup()
