class_name Fx
extends RefCounted
## Sichtbare Effekte und Klänge für die Oberfläche.

const COLORS := {
	"schaden": "#ffd0a0",
	"krit": "#ff6a3a",
	"gegenSpieler": "#ff5a4a",
	"heilung": "#6ee07a",
	"info": "#c8c0b0",
	"mana": "#9fb8ff",
}


static func _push(s: Dictionary, f: Dictionary) -> void:
	if s.get("fx") == null:
		s.fx = []
	s.fx.append(f)
	if s.fx.size() > 60:
		s.fx = s.fx.slice(s.fx.size() - 60)


static func shot(s: Dictionary, from: Dictionary, to: Dictionary, style: String) -> void:
	_push(s, {"kind": "shot", "from": J.pcopy(from), "to": J.pcopy(to), "style": style})


## Nahkampf von from nach to: Die Oberfläche zeigt einen Ausfallschritt.
static func strike(s: Dictionary, from: Dictionary, to: Dictionary) -> void:
	_push(s, {"kind": "strike", "from": J.pcopy(from), "to": J.pcopy(to)})


## Treffer an einer Stelle: kurzes Aufblitzen, bei strong (kritisch, schwer) mit Beben.
static func hit(s: Dictionary, at: Dictionary, strong: bool = false) -> void:
	_push(s, {"kind": "hit", "at": J.pcopy(at), "strong": strong})


## Ein Monster stirbt: Die Oberfläche lässt es in Pixel zerfallen.
static func death(s: Dictionary, m: Dictionary) -> void:
	_push(s, {"kind": "death", "at": J.pcopy(m.pos), "defId": m.defId, "color": m.get("color"), "rank": m.rank})


## Stufenaufstieg: goldene Funken um die Spielfigur.
static func level_up(s: Dictionary, at: Dictionary) -> void:
	_push(s, {"kind": "levelup", "at": J.pcopy(at)})


static func float_text(s: Dictionary, at: Dictionary, text: String, color: String) -> void:
	_push(s, {"kind": "text", "at": J.pcopy(at), "text": text, "color": color})


static func drain_fx(s: Dictionary) -> Array:
	var out: Array = s.get("fx") if s.get("fx") != null else []
	s.fx = []
	return out


static func sound(s: Dictionary, sfx: Dictionary) -> void:
	if s.get("sfx") == null:
		s.sfx = []
	s.sfx.append(sfx)
	if s.sfx.size() > 10:
		s.sfx = s.sfx.slice(s.sfx.size() - 10)


static func drain_sfx(s: Dictionary) -> Array:
	var out: Array = s.get("sfx") if s.get("sfx") != null else []
	s.sfx = []
	return out
