class_name Rules
extends RefCounted
## Regeln, die sich nicht als JSON ausdrücken lassen: Skill- und
## Zauberstufen, Verzauberungen, Tutorial, Interview-Bedingungen.

# ================================================================ Skills und Zauber

static func skill_xp_needed(level: int) -> int:
	return 25 + level * 20


static func spell_xp_needed(level: int) -> int:
	return 5 + level * 4


static func _pct(n: float) -> String:
	return ("%s %%" % J.s(J.rnd(n * 10) / 10.0)).replace(".", ",")


## Wirkungstext eines Skills (null = keine eigene Beschreibung).
static func skill_effect(id: String, l: int) -> Variant:
	match id:
		"hinterhalt":
			return "+%d %% Schaden gegen ahnungslose Gegner" % (25 * l)
		"anatomie":
			return "+%d %% Treffer auf Kopf, Arme, Beine · +%d %% Zonenwirkung" % [2 * l, 2 * l]
		"sprengmeister":
			return "+%d %% Explosionsschaden · −%d %% Schaden an dir selbst" % [8 * l, mini(75, 5 * l)]
		"abwehr":
			return "Deckung: +%d %% Ausweichen, +%d Rüstung" % [20 + 2 * l, 2 + floori(l / 3.0)]
		"konter":
			return "%d %% Chance auf einen Gegenschlag nach dem Ausweichen" % (3 * l)
		"schmerzresistenz":
			return "−%s Schaden durch Monsterangriffe" % _pct(1.5 * l)
		"giftfestigkeit":
			return "−%d %% Giftschaden" % mini(90, 6 * l)
		"schleichen":
			return "−%d %% Entdeckungschance · −%d Sichtweite der Monster" % [4 * l, floori(l / 4.0)]
		"wahrnehmung":
			return "+%d %% Fallen entdecken · +%d Sichtweite%s" % [3 * l, floori(l / 5.0), " · bessere Einschätzung von Monstern" if l >= 8 else ""]
		"kondition":
			return "+%d max. Ausdauer%s" % [l, (" · +%d Ausdauer pro Zug" % floori(l / 5.0)) if l >= 5 else ""]
		"reiten":
			return "Reittier −%d %% Schaden · Rammen +%d %% · %d %% Benzin gespart" % [mini(60, 4 * l), 8 * l, 5 * l]
		"entfesseln":
			return "+%d %% Chance, dich loszureißen" % (8 * l)
		"erste_hilfe":
			return "Heilgegenstände +%d %% · Schlaf +%d %%" % [8 * l, 10 * l]
		"kochen":
			return "Essen heilt +%d %%" % (15 * l)
		"fallenkunde":
			return "+%d %% Entdecken · +%d %% Entschärfen · +%d Fallenschaden" % [6 * l, 8 * l, 2 * l]
		"handwerk":
			return "Sprengsätze +%d %%%s" % [10 * l, (" · %d %% Chance auf ein Stück extra" % (10 + 2 * l)) if l >= 3 else ""]
		"feilschen":
			return "+%d %% Verhandlungschance · bis %d %% Rabatt · +%d %% beim Verkaufen" % [4 * l, 25 + l, 2 * l]
		"tierkunde":
			return "Haustier +%d %% Schaden · +%d %% Zähmen" % [6 * l, 3 * l]
		"rampenlicht":
			return "+%d %% Follower" % (5 * l)
		"arkane_kunde":
			return "+%d max. Mana · +%d %% Zauberwirkung%s" % [l, 4 * l, " · schnellere Mana-Erholung" if l >= 5 else ""]
	return null


# ================================================================ Verzauberungen

## Boni einer Verzauberung bei gegebener Stärke (AFFIXES[].bonuses).
static func affix_bonuses(id: String, p: int) -> Dictionary:
	match id:
		"staerke": return {"stats": {"str": p}}
		"geschick": return {"stats": {"ges": p}}
		"konst": return {"stats": {"kon": p}}
		"int": return {"stats": {"int": p}}
		"cha": return {"stats": {"cha": p}}
		"leben": return {"maxHp": p * 4}
		"ruestung": return {"ruestung": ceili(p / 2.0)}
		"ausweichen": return {"ausweichen": p * 2}
		"krit": return {"krit": p * 2}
		"regen": return {"hpRegen": ceili(p / 2.0)}
		"xp": return {"xpBonus": p * 3}
		"dornen": return {"dornen": p}
		"tritt": return {"schaden": {"tritt": p * 8}}
		"faust": return {"schaden": {"faust": p * 8}}
		"kopf": return {"schaden": {"kopf": p * 10}}
		"wurf": return {"schaden": {"wurf": p * 8}}
		"waffe": return {"schaden": {"waffe": p * 8}}
		"knie": return {"schaden": {"knie": p * 10}}
		"ellbogen": return {"schaden": {"ellbogen": p * 10}}
		"elefant": return {"maxHp": p * 2, "ruestung": ceili(p / 3.0)}
		"katze": return {"ausweichen": p, "krit": p}
		"faultier": return {"maxAusdauer": p * 2}
		"gluecksritter": return {"xpBonus": p * 2, "krit": p}
		"licht": return {"lichtradius": 1}
	push_error("Unbekannte Verzauberung: %s" % id)
	return {}


# ================================================================ Tutorial

static func tutorial_pages(guide_name: String, guide_description: String, former_crawler: bool) -> Array:
	var intro: String
	if former_crawler:
		intro = "Hinter dem Tresen steht %s. Du kennst das Gesicht – es ist ein früherer Crawler aus einer vergangenen Staffel. Einer von *deinen*. Mit einem unterschriebenen Vertrag dient %s jetzt der Show. „Hätte nicht gedacht, dass wir uns so wiedersehen“, sagt er. „Ich gebe dir alles mit, was ich weiß.“" % [guide_name, guide_name]
	else:
		intro = "Hinter dem Tresen steht %s. „Ah. Ein Neuer. Ich bin %s, dein Guide. Ich war mal wie du – ein Crawler. Dann habe ich einen Vertrag unterschrieben. Jetzt sitze ich hier und erkläre Leuten, wie sie nicht sterben. Die meisten hören nicht zu.“" % [guide_description, guide_name]
	return [
		intro,
		"„Also, die Grundlagen. Du bist in einer Gameshow. Die ganze Galaxis schaut zu. Jede Etage hat einen Timer – wenn er abläuft, stürzt die Etage ein. Bist du dann nicht im Treppenhaus, bist du tot. Punkt.“",
		"„Ab jetzt hast du ein Inventar. Du kannst also mehr tragen als das, was du in der Hand hältst. Glückwunsch. Außerdem siehst du jetzt deine Werte, und deine Karte merkt sich, wo du schon warst.“",
		"„Kämpfen: Die Systemstimme beobachtet, WIE du kämpfst. Tritt viel, und du wirst besser im Treten. Wirf Steine, und du wirst besser im Werfen. Probier Dinge aus. Wer immer dasselbe macht, wird darin gut – aber auch vorhersehbar.“",
		"„Bosse: Jedes Viertel hat einen Nachbarschafts-Boss. Solange er lebt, spawnen dort neue Monster nach. Er verlässt seine Kammer nicht. Wenn du ihn tötest, lässt er eine Gebietskarte fallen – heb sie auf. Und in der Mitte der Etage haust etwas Größeres. Die Treppe liegt direkt hinter ihm.“",
		"„Safe Rooms erkennst du am grünen Schimmern. Dort darf niemand Gewalt anwenden. Monster, die dich dort angreifen, werden weggebeamt. Dort und in der Gilde kannst du Lootboxen öffnen. Und schlafen. Schlaf ist wichtig. Tot sein ist schlimmer.“",
		"„Achievements bekommst du für… alles Mögliche. Je verrückter oder schwieriger, desto besser die Box. Die Systemstimme hat einen, äh, speziellen Humor. Gewöhn dich dran.“",
		"„Du hast jetzt auch Mana – so viel, wie du Intelligenz hast. Ich schenke dir den Zauber Heilen. Weitere Zauber lernst du aus Zauberbüchern. Das Buch zerfällt beim Lesen, der Zauber bleibt. Tränke helfen auch, aber dein Körper verträgt nur alle paar Minuten einen.“",
		"„Und jetzt die wichtigste Regel des ganzen Dungeons. Ich meine das ernst. Du darfst dich NUR in einer Toilette erleichtern. In jedem Safe Room gibt es eine. Wer es nicht rechtzeitig schafft, ruft ein Wutelementar herbei. Die haben noch nie jemanden am Leben gelassen. Behalte deine Blase im Auge.“",
		"„Letzte Sache. Wenn du stirbst, ist es vorbei. Keine zweite Runde für dich. Aber… die Show merkt sich alles. Und wer weiß, vielleicht begegnest du dir irgendwann selbst wieder. Viel Glück. Du wirst es brauchen.“",
	]


# ================================================================ Interview

## Antwort a[id] ist eine der genannten (is(a, id, ...idx)).
static func _is(a: Dictionary, id: String, idx: Array) -> bool:
	return a.get(id) != null and idx.has(int(a[id]))


## Bedingungen der Folgefragen: [Fragen-ID, Antwort-Indizes, verneint].
const QUESTION_WHEN := {
	"handwerk": ["beruf", [0], false],
	"gesundheit": ["beruf", [2], false],
	"sicherheit": ["beruf", [3], false],
	"gastro": ["beruf", [4], false],
	"sport": ["beruf", [5], false],
	"it": ["beruf", [7], false],
	"natur": ["beruf", [9], false],
	"buero": ["beruf", [1], false],
	"bildung": ["beruf", [6], false],
	"kunst": ["beruf", [8], false],
	"handel": ["beruf", [10], false],
	"frei": ["beruf", [11], false],
	"medien": ["beruf", [12], false],
	"logistik": ["beruf", [13], false],
	"finanzen": ["beruf", [14], false],
	"soziales": ["beruf", [15], false],
	"technik": ["beruf", [16], false],
	"dienst": ["beruf", [17], false],
	"ausbildung": ["beruf", [18], false],
	"kampfsport": ["hobbysport", [1], false],
	"hand": ["ort", [2, 3, 5], true],
	"hose": ["kleidung", [0, 5], true],
}


static func question_visible(q: Dictionary, a: Dictionary) -> bool:
	var w = QUESTION_WHEN.get(q.id)
	if w == null:
		return true
	var hit := _is(a, w[0], w[1])
	return not hit if w[2] else hit


static func visible_questions(a: Dictionary) -> Array:
	return Db.t("interview", "INTERVIEW").filter(func(q): return question_visible(q, a))


## Kombinationen im Interview (INTERVIEW_COMBOS[i].when), in derselben Reihenfolge.
static func combo_when(i: int, a: Dictionary) -> bool:
	match i:
		0: return _is(a, "sport", [1]) and _is(a, "kampfsport", [3])
		1: return _is(a, "sicherheit", [2]) and _is(a, "konflikt", [1])
		2: return _is(a, "handwerk", [4]) and _is(a, "angst", [0])
		3: return _is(a, "it", [1]) and _is(a, "sozial", [2])
	return false
