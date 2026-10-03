class_name UiTheme
extends RefCounted
## Das Designsystem als Godot-Theme im Pixel-Stil: Farben, Schriften,
## Knöpfe, Karten, Balken. Flächen sind PixelBox-Rahmen (abgestufte Ecken,
## harte Schatten), Knöpfe und Überschriften nutzen die Pixel-Schrift,
## Fließtext bleibt Montserrat. Varianten über theme_type_variation.

## Farben nach dem Tiny-Swords-Pack (Pixel Frog): Marine-Umriss, Schiefer,
## Sand, Gold. Flächen bleiben dunkel, damit heller Text gut lesbar ist.
const BG := Color("#1a1f30")
const PANEL := Color("#232a3c")
const PANEL_2 := Color("#2a3246")
const PANEL_3 := Color("#323b52")
const LINE := Color("#3a4459")
const LINE_2 := Color("#4b566e")
const OUTLINE := Color("#161c2e")
const TEXT := Color("#f3ead2")
const MUTED := Color("#a6abb8")
const ACCENT := Color("#f1d36b")
const ACCENT_2 := Color("#ec8f8a")
const DANGER := Color("#ef6b62")
const OK := Color("#a3d16c")
const INFO := Color("#8ccbd6")
const ACHV := Color("#cf9fe0")
const LOOT := Color("#f2c872")

const HEX := {
	"text": "#f3ead2", "muted": "#a6abb8", "accent": "#f1d36b", "accent2": "#ec8f8a", "danger": "#ef6b62",
	"ok": "#a3d16c", "info": "#8ccbd6", "achv": "#cf9fe0", "loot": "#f2c872", "system": "#f1d36b",
}

const TS := "res://assets/tinyswords/ui/"

static var _theme: Theme
static var _colors := {}


## Farbe aus einer Angabe wie in CSS: Color, "#rgb", "#rrggbb", "rgba(r, g, b, a)".
static func css(v: Variant) -> Color:
	if v is Color:
		return v
	var key: String = v
	var c = _colors.get(key)
	if c != null:
		return c
	var out := Color.BLACK
	var t := key.strip_edges()
	if t.begins_with("#"):
		var h := t.substr(1)
		if h.length() == 3:
			h = h[0] + h[0] + h[1] + h[1] + h[2] + h[2]
		out = Color.html("#" + h)
	elif t.begins_with("rgb"):
		var inner := t.substr(t.find("(") + 1, t.rfind(")") - t.find("(") - 1)
		var parts := inner.split(",")
		out = Color(float(parts[0]) / 255.0, float(parts[1]) / 255.0, float(parts[2]) / 255.0, float(parts[3]) if parts.size() > 3 else 1.0)
	elif t == "transparent":
		out = Color(0, 0, 0, 0)
	elif t == "white":
		out = Color.WHITE
	_colors[key] = out
	return out


## Größe der Pixel-Schrift zu einer früheren Montserrat-Größe.
static func pixel_size(size: int) -> int:
	return 16 if size <= 13 else (18 if size <= 15 else 20)


## Pixel-Rahmen. radius wählt die Eckenstufe, border_w zählt in Kunstpixeln (2 px).
static func box(bg: Color, border: Color = Color(0, 0, 0, 0), radius: int = 8, border_w: int = 1, pad: Vector4 = Vector4(10, 6, 10, 6)) -> PixelBox:
	var sb := PixelBox.new()
	sb.bg_color = bg
	sb.border_color = border
	if border.a > 0:
		sb.set_border_width_all(border_w * sb.unit)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad.x
	sb.content_margin_top = pad.y
	sb.content_margin_right = pad.z
	sb.content_margin_bottom = pad.w
	return sb


## Knopf-Rahmen: wie box, dazu Innenrand und ein Kunstpixel harter Schatten.
static func bbox(bg: Color, border: Color, radius: int = 8, pad: Vector4 = Vector4(10, 6, 10, 6), shadow: bool = true) -> PixelBox:
	var sb := box(bg, border, radius, 1, pad)
	sb.bevel = 0.1
	if shadow:
		sb.shadow_color = Color(0, 0, 0, 0.5)
		sb.shadow_size = 1
		sb.shadow_offset = Vector2(0, 2)
	return sb


## 9-Slice aus dem Tiny-Swords-Pack. edge = Ränder im Bild (links, oben,
## rechts, unten), pad = Innenabstand des Inhalts.
static func tex(name: String, edge: Vector4, pad: Vector4, tint: Color = Color.WHITE) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = load(TS + name + ".png")
	sb.texture_margin_left = edge.x
	sb.texture_margin_top = edge.y
	sb.texture_margin_right = edge.z
	sb.texture_margin_bottom = edge.w
	sb.content_margin_left = pad.x
	sb.content_margin_top = pad.y
	sb.content_margin_right = pad.z
	sb.content_margin_bottom = pad.w
	sb.modulate_color = tint
	return sb


## Knopf aus dem Pack: Rand (Umriss, heller Rahmen) oben 4, unten mit der
## dunklen Standkante 8 Pixel. Gedrückt sitzt der Inhalt 2 Pixel tiefer.
const BTN_EDGE := Vector4(10, 8, 10, 12)


static func btn(name: String, pad: Vector4, pressed: bool = false) -> StyleBoxTexture:
	var p := Vector4(pad.x, pad.y + 2, pad.z, pad.w - 2) if pressed else pad
	return tex(name, BTN_EDGE, p)


## Satz aus normal, hover, gedrückt, aus für eine Knopffarbe.
static func btn_set(t: Theme, type: String, kind: String, pad: Vector4, font_color: Color, size: int = 14, weight: int = 500, pixel: bool = true, hover_color: Color = Color(0, 0, 0, 0)) -> void:
	_button(t, type, btn(kind, pad), btn(kind + "_hover", pad), btn(kind + "_pressed", pad, true), btn("btn_disabled", pad), font_color, hover_color, size, weight, pixel)


static func _button(t: Theme, type: String, normal: StyleBox, hover: StyleBox, pressed: StyleBox, disabled: StyleBox, font_color: Color, hover_color: Color = Color(0, 0, 0, 0), size: int = 14, weight: int = 500, pixel: bool = true) -> void:
	if type != "Button":
		t.set_type_variation(type, "Button")
	t.set_stylebox("normal", type, normal)
	t.set_stylebox("hover", type, hover)
	t.set_stylebox("pressed", type, pressed)
	t.set_stylebox("hover_pressed", type, pressed)
	t.set_stylebox("disabled", type, disabled)
	t.set_stylebox("focus", type, box(Color(0, 0, 0, 0), ACCENT, 8, 1))
	t.set_color("font_color", type, font_color)
	t.set_color("font_hover_color", type, hover_color if hover_color.a > 0 else font_color)
	t.set_color("font_pressed_color", type, hover_color if hover_color.a > 0 else font_color)
	t.set_color("font_hover_pressed_color", type, hover_color if hover_color.a > 0 else font_color)
	t.set_color("font_focus_color", type, font_color)
	t.set_color("font_disabled_color", type, Color(MUTED, 0.6) if font_color.v < 0.2 else Color(font_color, 0.38))
	t.set_font_size("font_size", type, pixel_size(size) if pixel else size)
	t.set_font("font", type, UiFonts.pixel(weight) if pixel else UiFonts.get_font(weight))


static func _panel(t: Theme, type: String, sb: StyleBox) -> void:
	t.set_type_variation(type, "PanelContainer")
	t.set_stylebox("panel", type, sb)


static func get_theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = UiFonts.get_font(400)
	t.default_font_size = 14
	t.set_color("font_color", "Label", TEXT)
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_font("normal_font", "RichTextLabel", UiFonts.get_font(400))
	t.set_font("bold_font", "RichTextLabel", UiFonts.get_font(700))
	t.set_font("italics_font", "RichTextLabel", UiFonts.get_font(400, true))
	t.set_font("bold_italics_font", "RichTextLabel", UiFonts.get_font(700, true))
	t.set_font_size("normal_font_size", "RichTextLabel", 14)
	t.set_font_size("bold_font_size", "RichTextLabel", 14)
	t.set_font_size("italics_font_size", "RichTextLabel", 14)
	t.set_font_size("bold_italics_font_size", "RichTextLabel", 14)
	t.set_constant("line_separation", "RichTextLabel", 3)
	t.set_color("selection_color", "RichTextLabel", Color(ACCENT, 0.35))

	# Knöpfe: Tiny-Swords-Knöpfe (umgefärbt), Innenabstand über dem Rahmen
	var pad := Vector4(12, 6, 12, 9)
	btn_set(t, "Button", "btn", pad, TEXT)
	btn_set(t, "PrimaryButton", "btn_primary", pad, OUTLINE, 14, 700)
	btn_set(t, "DangerButton", "btn_danger", pad, TEXT, 14, 700)
	btn_set(t, "SelButton", "btn_sel", pad, ACCENT)
	var small_pad := Vector4(9, 3, 9, 7)
	btn_set(t, "SmallButton", "btn", small_pad, TEXT, 12)
	btn_set(t, "SmallSel", "btn_sel", small_pad, ACCENT, 12)
	btn_set(t, "SmallPrimary", "btn_primary", small_pad, OUTLINE, 12, 700)
	btn_set(t, "PillButton", "btn", Vector4(11, 3, 11, 7), TEXT, 12)
	# Reiter: geschnitztes Holz, der aktive heller mit Goldschrift
	var tab_pad := Vector4(4, 6, 4, 6)
	var tn := StyleBoxEmpty.new()
	for k in ["left", "top", "right", "bottom"]:
		tn.set("content_margin_" + k, tab_pad.x if k in ["left", "right"] else tab_pad.y)
	_button(t, "TabButton", tn, tex("carved", Vector4(8, 8, 8, 8), tab_pad, Color(1, 1, 1, 0.45)), tn, tn, MUTED, TEXT, 13, 600)
	var ta := tex("carved_active", Vector4(8, 8, 8, 8), tab_pad)
	_button(t, "TabActive", ta, ta, ta, ta, ACCENT, ACCENT, 13, 600)
	# Link
	var ln := StyleBoxEmpty.new()
	ln.content_margin_top = 2
	ln.content_margin_bottom = 2
	_button(t, "LinkBtn", ln, ln, ln, ln, INFO, Color("#b5e2ea"), 12)
	# Fähigkeit und Zauber
	btn_set(t, "AbilityButton", "btn_danger", pad, Color("#ffe3d6"))
	btn_set(t, "SpellButton", "btn", pad, Color("#b9dcff"))
	btn_set(t, "SpellSel", "btn_sel", pad, Color("#b9dcff"))
	# Antworten im Interview
	var ap := Vector4(18, 11, 18, 14)
	_button(t, "AnswerButton", btn("btn", ap), btn("btn_hover", Vector4(22, 11, 14, 14)), btn("btn_pressed", ap, true), btn("btn_disabled", ap), TEXT, Color(0, 0, 0, 0), 15, 500, false)
	# Wahl (Rasse, Klasse)
	var cp := Vector4(14, 9, 14, 12)
	btn_set(t, "ChoiceButton", "btn", cp, TEXT)
	btn_set(t, "ChoiceSel", "btn_sel", cp, TEXT)
	# Zoom
	btn_set(t, "RoundButton", "btn", Vector4(0, 0, 0, 3), TEXT, 18, 700)
	# Kampf: Ziele
	btn_set(t, "CatButton", "btn", Vector4(12, 8, 12, 11), TEXT, 14, 700)

	# Flächen: Schieferpapier mit Goldecken, Holz, geschnitzte Schilder
	var paper_edge := Vector4(28, 28, 28, 28)
	var small_edge := Vector4(14, 14, 14, 14)
	_panel(t, "Card", tex("paper", paper_edge, Vector4(34, 32, 34, 32)))
	_panel(t, "Item", tex("paper_small", small_edge, Vector4(12, 10, 12, 10)))
	_panel(t, "Locked", tex("paper_small", small_edge, Vector4(14, 14, 14, 14), Color(1, 1, 1, 0.55)))
	_panel(t, "Modal", tex("paper", paper_edge, Vector4(30, 28, 30, 28)))
	_panel(t, "VersusModal", tex("paper", paper_edge, Vector4(30, 28, 30, 28), Color("#f0b4a8")))
	var tp := tex("paper_small", small_edge, Vector4(13, 10, 13, 10))
	_panel(t, "Tip", tp)
	var carved_edge := Vector4(8, 8, 8, 8)
	_panel(t, "Pill", tex("carved", carved_edge, Vector4(11, 4, 11, 4)))
	_panel(t, "PillWarn", tex("carved", carved_edge, Vector4(11, 4, 11, 4), Color("#ff9a8a")))
	_panel(t, "PillTimer", tex("carved_active", carved_edge, Vector4(11, 4, 11, 4)))
	_panel(t, "RoomLabel", tex("carved", carved_edge, Vector4(12, 5, 12, 5), Color(1, 1, 1, 0.92)))
	_panel(t, "TopBar", box(Color("#20263a"), Color(0, 0, 0, 0), 0, 0, Vector4(12, 7, 12, 7)))
	_panel(t, "Side", box(PANEL, Color(0, 0, 0, 0), 0, 0, Vector4(0, 0, 0, 0)))
	_panel(t, "Bottom", box(Color("#1e2435"), Color(0, 0, 0, 0), 0, 0, Vector4(0, 0, 0, 0)))
	_panel(t, "ActionBar", box(Color(0, 0, 0, 0.12), Color(0, 0, 0, 0), 0, 0, Vector4(10, 8, 10, 8)))
	var cb := box(Color("#3a2028", 0.92), Color(0, 0, 0, 0), 0, 0, Vector4(10, 10, 10, 10))
	cb.border_color = Color(DANGER, 0.5)
	cb.border_width_top = 2
	_panel(t, "CombatBar", cb)
	_panel(t, "Target", tex("paper_small", small_edge, Vector4(11, 8, 11, 8)))
	_panel(t, "TargetSel", tex("paper_small", small_edge, Vector4(11, 8, 11, 8), Color("#ffb39e")))
	_panel(t, "Quote", box(Color(ACCENT, 0.08), Color(0, 0, 0, 0), 10, 0, Vector4(16, 12, 16, 12)))
	_panel(t, "Toast", tex("paper_small", small_edge, Vector4(16, 11, 14, 11)))
	_panel(t, "MiniWrap", tex("paper_small", Vector4(14, 14, 14, 14), Vector4(8, 8, 8, 8), Color(1, 1, 1, 0.9)))
	_panel(t, "Tabs", box(Color(0, 0, 0, 0.15), Color(0, 0, 0, 0), 0, 0, Vector4(8, 7, 8, 7)))
	_panel(t, "Speaker", tex("carved", carved_edge, Vector4(10, 3, 10, 3)))
	_panel(t, "Rec", box(ACCENT, Color(0, 0, 0, 0), 99, 0, Vector4(8, 1, 8, 1)))
	_panel(t, "Ribbon", tex("ribbon_yellow", Vector4(18, 0, 18, 0), Vector4(22, 3, 22, 9)))
	_panel(t, "RibbonRed", tex("ribbon_red", Vector4(18, 0, 18, 0), Vector4(22, 3, 22, 9)))
	_panel(t, "RibbonBlue", tex("ribbon_blue", Vector4(18, 0, 18, 0), Vector4(22, 3, 22, 9)))
	_panel(t, "Wood", tex("wood_small", Vector4(20, 20, 20, 24), Vector4(14, 14, 14, 16)))

	# Eingabefeld
	t.set_stylebox("normal", "LineEdit", tex("carved", Vector4(8, 8, 8, 8), Vector4(12, 8, 12, 8), Color("#8a8a9a")))
	t.set_stylebox("focus", "LineEdit", box(Color(0, 0, 0, 0), ACCENT, 8, 1, Vector4(12, 8, 12, 8)))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("font_placeholder_color", "LineEdit", Color(MUTED, 0.7))
	t.set_color("caret_color", "LineEdit", ACCENT)
	t.set_color("selection_color", "LineEdit", Color(ACCENT, 0.35))
	t.set_font_size("font_size", "LineEdit", 15)

	# Bildlaufleisten
	var grab := box(Color("#8a6e4c"), OUTLINE, 8, 1, Vector4(4, 4, 4, 4))
	var grab_h := box(Color("#b08a5c"), OUTLINE, 8, 1, Vector4(4, 4, 4, 4))
	var track := StyleBoxEmpty.new()
	track.content_margin_left = 3
	track.content_margin_right = 3
	for sb_type in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("grabber", sb_type, grab)
		t.set_stylebox("grabber_highlight", sb_type, grab_h)
		t.set_stylebox("grabber_pressed", sb_type, grab_h)
		t.set_stylebox("scroll", sb_type, track)
		t.set_stylebox("scroll_focus", sb_type, track)

	# Hinweise (Tooltips)
	t.set_stylebox("panel", "TooltipPanel", tp)
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_font_size("font_size", "TooltipLabel", 13)
	_theme = t
	return t
