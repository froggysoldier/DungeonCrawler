class_name Rounds
extends RefCounted
## Kampfrunden wie in Baldur's Gate: Sobald ein wacher Gegner den Crawler
## sieht, läuft der Kampf in Runden. Pro Runde gibt es einen Bewegungsvorrat
## (Felder) und eine Aktion (Angriff, Zauber, Gegenstand, Deckung). Schritte
## innerhalb des Vorrats kosten keine Spielzeit, die Gegner warten; auch nach
## der Aktion darf man mit der übrigen Bewegung weiterlaufen. Die Runde endet
## mit „Runde beenden“ (Warten) oder von selbst, wenn Aktion und Bewegung
## verbraucht sind. Dann sind die Gegner dran, laufen bis zu ihrer Reichweite
## und greifen an. Außerhalb des Kampfes ist jeder Schritt ein Zug wie bisher.
##
## Zustand: s.round = {"move": übrige Felder, "max": Vorrat, "n": Runde,
## "acted": Aktion verbraucht}.

const BASE_MOVE := 6


## Läuft gerade eine Kampfrunde?
static func active(s: Dictionary) -> bool:
	return s.get("round") != null


## Sieht ein wacher Gegner den Crawler (und er ihn)?
static func in_combat(s: Dictionary) -> bool:
	if s.status != "playing":
		return false
	for m in s.monsters:
		if m.get("aware", false) and not m.get("asleep", false) and m.hp > 0 and Sight.player_sees(s, m.pos):
			return true
	return false


## Bewegungsvorrat pro Runde: 6 Felder, Geschick und Reittier helfen,
## festgehalten oder im Schlamm geht es nur ein Feld.
static func budget(s: Dictionary) -> int:
	var p: Dictionary = s.player
	var st := Player.effective_stats(s)
	var n := BASE_MOVE + clampi(floori((int(st.ges) - 5) / 3.0), -1, 3)
	if Mounts.is_riding(s):
		n += 2
	if p.get("immobile"):
		n = 1
	return clampi(n, 1, 12)


## Nach jedem Zug: Kampf beginnt, neue Runde, oder der Kampf ist vorbei.
static func after_turn(s: Dictionary) -> void:
	if s.status != "playing":
		s.erase("round")
		return
	if in_combat(s):
		var first := not active(s)
		var n := budget(s)
		s.round = {"move": n, "max": n, "n": 1 if first else int(s.round.n) + 1, "acted": false}
		if first:
			Log.add(s, "Kampf! Ab jetzt in Runden: pro Runde bis zu %d Felder Bewegung und eine Aktion." % n, "gefahr")
	elif active(s):
		s.erase("round")
		Log.add(s, "Der Kampf ist vorbei. Du bewegst dich wieder frei.", "system")


## Ein Schritt in der Runde. Gibt false zurück, wenn der Vorrat leer ist.
static func can_move(s: Dictionary) -> bool:
	return not active(s) or int(s.round.move) > 0


## Endet mit dieser Handlung die Runde? kind: "move" (ein Schritt),
## "action" (Angriff, Zauber, Gegenstand …), "end" (Runde beenden).
## Ohne Kampf endet jede Handlung den Zug. Nach einem Schritt ohne sichtbaren
## Gegner endet der Kampf.
static func spend(s: Dictionary, kind: String) -> bool:
	if not active(s):
		return true
	match kind:
		"move":
			s.round.move = maxi(0, int(s.round.move) - 1)
			if not in_combat(s):
				s.erase("round")
				Log.add(s, "Der Kampf ist vorbei. Du bewegst dich wieder frei.", "system")
				return false
			return bool(s.round.get("acted", false)) and int(s.round.move) <= 0
		"action":
			if s.round.get("acted", false):
				return true
			s.round.acted = true
			return int(s.round.move) <= 0
	return true


## Vor einer Aktion: Ist die Aktion dieser Runde schon verbraucht, endet die
## Runde zuerst (die Gegner sind dran), dann folgt die Aktion in der neuen.
static func before_action(s: Dictionary) -> void:
	if active(s) and s.round.get("acted", false):
		Game.end_turn(s, false, "end")


## Wie weit ein Gegner in seiner Runde läuft.
static func monster_speed(m: Dictionary) -> int:
	if m.behavior == "stationary":
		return 1
	var n := 4
	match m.get("size", "mittel"):
		"winzig", "klein":
			n = 5
		"gross":
			n = 4
		"riesig":
			n = 3
	if Abilities.has(m, "schnell"):
		n += 2
	if Abilities.has(m, "fliegend"):
		n += 1
	return n
