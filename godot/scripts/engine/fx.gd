class_name Fx
extends RefCounted
## Sichtbare Effekte und Klänge für die Oberfläche (Port von src/engine/fx.ts).

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
