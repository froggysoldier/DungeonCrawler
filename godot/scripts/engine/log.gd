class_name Log
extends RefCounted
## Spiel-Log und Einblendungen (Port von src/engine/log.ts).

const MAX_LOG := 300


static func add(s: Dictionary, text: String, kind: String = "info") -> void:
	var counter = s.get("logCounter")
	s.logCounter = (s.log.size() if counter == null else int(counter)) + 1
	s.log.append({"id": s.logCounter, "turn": s.turn, "text": text, "kind": kind})
	if s.log.size() > MAX_LOG:
		s.log = s.log.slice(s.log.size() - MAX_LOG)


static func toast(s: Dictionary, title: String, text: String, kind: String) -> void:
	s.toasts.append({"title": title, "text": text, "kind": kind})
