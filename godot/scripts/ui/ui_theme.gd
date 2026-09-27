class_name UiTheme
extends RefCounted
## Das Designsystem der Web-Version als Godot-Theme: Farben, Schrift,
## Knöpfe, Karten, Balken. Varianten werden über theme_type_variation gewählt.

const BG := Color("#0b0c10")
const PANEL := Color("#13151b")
const PANEL_2 := Color("#1a1d25")
const PANEL_3 := Color("#222632")
const LINE := Color("#2a2e39")
const LINE_2 := Color("#363b49")
const TEXT := Color("#e9e5dc")
const MUTED := Color("#8f94a1")
const ACCENT := Color("#f4c24f")
const ACCENT_2 := Color("#ff6fae")
const DANGER := Color("#ff5d5d")
const OK := Color("#62d68f")
const INFO := Color("#6cc4ff")
const ACHV := Color("#d58cff")
const LOOT := Color("#ffd27a")

const HEX := {
	"text": "#e9e5dc", "muted": "#8f94a1", "accent": "#f4c24f", "accent2": "#ff6fae", "danger": "#ff5d5d",
	"ok": "#62d68f", "info": "#6cc4ff", "achv": "#d58cff", "loot": "#ffd27a", "system": "#f4c24f",
}

static var _theme: Theme


static func box(bg: Color, border: Color = Color(0, 0, 0, 0), radius: int = 8, border_w: int = 1, pad: Vector4 = Vector4(10, 6, 10, 6)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	if border.a > 0:
		sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad.x
	sb.content_margin_top = pad.y
	sb.content_margin_right = pad.z
	sb.content_margin_bottom = pad.w
	sb.anti_aliasing = true
	return sb


static func _button(t: Theme, type: String, normal: StyleBoxFlat, hover: StyleBoxFlat, pressed: StyleBoxFlat, disabled: StyleBoxFlat, font_color: Color, hover_color: Color = Color(0, 0, 0, 0), size: int = 14, weight: int = 500) -> void:
	if type != "Button":
		t.set_type_variation(type, "Button")
	t.set_stylebox("normal", type, normal)
	t.set_stylebox("hover", type, hover)
	t.set_stylebox("pressed", type, pressed)
	t.set_stylebox("hover_pressed", type, pressed)
	t.set_stylebox("disabled", type, disabled)
	t.set_stylebox("focus", type, box(Color(0, 0, 0, 0), ACCENT, normal.corner_radius_top_left, 2))
	t.set_color("font_color", type, font_color)
	t.set_color("font_hover_color", type, hover_color if hover_color.a > 0 else font_color)
	t.set_color("font_pressed_color", type, hover_color if hover_color.a > 0 else font_color)
	t.set_color("font_hover_pressed_color", type, hover_color if hover_color.a > 0 else font_color)
	t.set_color("font_focus_color", type, font_color)
	t.set_color("font_disabled_color", type, Color(font_color, 0.38))
	t.set_font_size("font_size", type, size)
	t.set_font("font", type, UiFonts.get_font(weight))


static func _panel(t: Theme, type: String, sb: StyleBoxFlat) -> void:
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

	# Knöpfe
	var pad := Vector4(10, 6, 10, 6)
	var n := box(Color("#1f222c"), LINE_2, 8, 1, pad)
	n.shadow_color = Color(0, 0, 0, 0.35)
	n.shadow_size = 1
	n.shadow_offset = Vector2(0, 1)
	var h := box(Color("#262a35"), Color(ACCENT, 0.6), 8, 1, pad)
	var p := box(Color("#181b22"), Color(ACCENT, 0.6), 8, 1, Vector4(pad.x, pad.y + 1, pad.z, pad.w - 1))
	var d := box(Color("#1f222c", 0.6), Color(LINE_2, 0.6), 8, 1, pad)
	_button(t, "Button", n, h, p, d, TEXT)
	var pn := box(Color("#f0b53a"), Color("#f7c65a"), 8, 1, pad)
	pn.shadow_color = Color(ACCENT, 0.25)
	pn.shadow_size = 6
	pn.shadow_offset = Vector2(0, 3)
	var ph := box(Color("#f7c24a"), Color("#ffe08c"), 8, 1, pad)
	var pp := box(Color("#e0a42a"), Color("#f7c65a"), 8, 1, Vector4(pad.x, pad.y + 1, pad.z, pad.w - 1))
	var pd := box(Color("#f0b53a", 0.4), Color("#f7c65a", 0.4), 8, 1, pad)
	_button(t, "PrimaryButton", pn, ph, pp, pd, Color("#1c1405"), Color("#1c1405"), 14, 700)
	# Ausgewählt (Aktionsleiste, Kampf, Wahl)
	var sn := box(Color("#2b2616"), ACCENT, 7, 1, pad)
	_button(t, "SelButton", sn, box(Color("#342d18"), ACCENT, 7, 1, pad), sn, box(Color("#2b2616", 0.5), Color(ACCENT, 0.5), 7, 1, pad), ACCENT)
	# Kleine Knöpfe
	var small_pad := Vector4(8, 3, 8, 3)
	_button(t, "SmallButton", box(Color("#1f222c"), LINE_2, 7, 1, small_pad), box(Color("#262a35"), Color(ACCENT, 0.6), 7, 1, small_pad), box(Color("#181b22"), Color(ACCENT, 0.6), 7, 1, small_pad), box(Color("#1f222c", 0.6), Color(LINE_2, 0.6), 7, 1, small_pad), TEXT, Color(0, 0, 0, 0), 12)
	_button(t, "SmallPrimary", box(Color("#f0b53a"), Color("#f7c65a"), 7, 1, small_pad), box(Color("#f7c24a"), Color("#ffe08c"), 7, 1, small_pad), box(Color("#e0a42a"), Color("#f7c65a"), 7, 1, small_pad), box(Color("#f0b53a", 0.4), Color("#f7c65a", 0.4), 7, 1, small_pad), Color("#1c1405"), Color("#1c1405"), 12, 700)
	# Pillen in der Kopfzeile
	var pill_pad := Vector4(11, 3, 11, 3)
	_button(t, "PillButton", box(Color("#1f222c"), LINE_2, 99, 1, pill_pad), box(Color("#262a35"), Color(ACCENT, 0.6), 99, 1, pill_pad), box(Color("#181b22"), Color(ACCENT, 0.6), 99, 1, pill_pad), box(Color("#1f222c", 0.6), Color(LINE_2, 0.6), 99, 1, pill_pad), TEXT, Color(0, 0, 0, 0), 12)
	# Reiter
	var tab_pad := Vector4(2, 7, 2, 7)
	var tn := box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 7, 1, tab_pad)
	_button(t, "TabButton", tn, box(Color(1, 1, 1, 0.04), Color(0, 0, 0, 0), 7, 1, tab_pad), tn, tn, MUTED, TEXT, 13, 600)
	var ta := box(Color("#222530"), LINE_2, 7, 1, tab_pad)
	ta.border_width_bottom = 2
	ta.border_color = LINE_2
	ta.border_width_bottom = 1
	_button(t, "TabActive", ta, ta, ta, ta, ACCENT, ACCENT, 13, 600)
	# Link
	var ln := box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0, Vector4(0, 2, 0, 2))
	_button(t, "LinkBtn", ln, ln, ln, ln, INFO, Color("#9fd8ff"), 12)
	# Fähigkeit und Zauber
	_button(t, "AbilityButton", box(Color("#1f222c"), ACCENT_2, 7, 1, pad), box(Color("#2a2030"), ACCENT_2, 7, 1, pad), box(Color("#181b22"), ACCENT_2, 7, 1, pad), box(Color("#1f222c", 0.6), Color(ACCENT_2, 0.5), 7, 1, pad), ACCENT_2)
	_button(t, "SpellButton", box(Color("#1f222c"), Color("#3d5a9e"), 7, 1, pad), box(Color("#232a3a"), Color("#6fa8ff"), 7, 1, pad), box(Color("#1c2a4a"), Color("#6fa8ff"), 7, 1, pad), box(Color("#1f222c", 0.6), Color("#3d5a9e", 0.5), 7, 1, pad), Color("#9ec0ff"))
	_button(t, "SpellSel", box(Color("#1c2a4a"), Color("#6fa8ff"), 7, 1, pad), box(Color("#1c2a4a"), Color("#8fbcff"), 7, 1, pad), box(Color("#1c2a4a"), Color("#6fa8ff"), 7, 1, pad), box(Color("#1c2a4a", 0.6), Color("#6fa8ff", 0.5), 7, 1, pad), Color("#9ec0ff"))
	# Antworten im Interview
	var ap := Vector4(16, 12, 16, 12)
	_button(t, "AnswerButton", box(Color("#1c1f27"), LINE_2, 10, 1, ap), box(Color("#2a2718"), Color(ACCENT, 0.55), 10, 1, Vector4(20, 12, 12, 12)), box(Color("#181b22"), Color(ACCENT, 0.55), 10, 1, ap), box(Color("#1c1f27", 0.6), LINE_2, 10, 1, ap), TEXT, Color(0, 0, 0, 0), 15, 500)
	# Wahl (Rasse, Klasse)
	var cp := Vector4(12, 10, 12, 10)
	_button(t, "ChoiceButton", box(Color("#1c1f27"), LINE_2, 10, 1, cp), box(Color("#23262f"), Color(ACCENT, 0.6), 10, 1, cp), box(Color("#181b22"), Color(ACCENT, 0.6), 10, 1, cp), box(Color("#1c1f27", 0.5), LINE_2, 10, 1, cp), TEXT)
	_button(t, "ChoiceSel", box(Color("#2b2616"), ACCENT, 10, 1, cp), box(Color("#342d18"), ACCENT, 10, 1, cp), box(Color("#2b2616"), ACCENT, 10, 1, cp), box(Color("#2b2616", 0.5), ACCENT, 10, 1, cp), TEXT)
	# Zoom
	var zp := Vector4(0, 0, 0, 0)
	_button(t, "RoundButton", box(Color(16 / 255.0, 18 / 255.0, 24 / 255.0, 0.8), Color(1, 1, 1, 0.12), 17, 1, zp), box(Color(40 / 255.0, 44 / 255.0, 54 / 255.0, 0.9), Color(ACCENT, 0.6), 17, 1, zp), box(Color(12 / 255.0, 14 / 255.0, 19 / 255.0, 0.9), Color(ACCENT, 0.6), 17, 1, zp), box(Color(16 / 255.0, 18 / 255.0, 24 / 255.0, 0.5), Color(1, 1, 1, 0.06), 17, 1, zp), TEXT, Color(0, 0, 0, 0), 18, 700)
	# Kampf: Ziele
	_button(t, "CatButton", box(Color("#1b1e26"), LINE, 9, 1, Vector4(11, 9, 11, 9)), box(Color("#20232c"), LINE_2, 9, 1, Vector4(11, 9, 11, 9)), box(Color("#1b1e26"), LINE_2, 9, 1, Vector4(11, 9, 11, 9)), box(Color("#1b1e26"), LINE, 9, 1, Vector4(11, 9, 11, 9)), TEXT, Color(0, 0, 0, 0), 14, 700)

	# Flächen
	_panel(t, "Card", box(Color(24 / 255.0, 27 / 255.0, 34 / 255.0, 0.96), LINE, 16, 1, Vector4(32, 32, 32, 32)))
	_panel(t, "Item", box(Color("#1a1d25"), LINE, 10, 1, Vector4(11, 9, 11, 9)))
	_panel(t, "Locked", box(Color(1, 1, 1, 0.015), LINE_2, 10, 1, Vector4(14, 14, 14, 14)))
	var md := box(Color("#171a21"), Color(ACCENT, 0.35), 16, 1, Vector4(26, 24, 26, 24))
	md.shadow_color = Color(0, 0, 0, 0.65)
	md.shadow_size = 30
	md.shadow_offset = Vector2(0, 12)
	_panel(t, "Modal", md)
	var vm := md.duplicate()
	vm.bg_color = Color("#161218")
	vm.border_color = Color(1, 110 / 255.0, 90 / 255.0, 0.45)
	_panel(t, "VersusModal", vm)
	var tp := box(Color(14 / 255.0, 16 / 255.0, 22 / 255.0, 0.95), LINE_2, 10, 1, Vector4(12, 9, 12, 9))
	tp.shadow_color = Color(0, 0, 0, 0.55)
	tp.shadow_size = 16
	tp.shadow_offset = Vector2(0, 8)
	_panel(t, "Tip", tp)
	_panel(t, "Pill", box(Color(1, 1, 1, 0.035), LINE, 99, 1, Vector4(11, 4, 11, 4)))
	_panel(t, "PillWarn", box(Color(1, 93 / 255.0, 93 / 255.0, 0.22), DANGER, 99, 1, Vector4(11, 4, 11, 4)))
	_panel(t, "PillTimer", box(Color(1, 1, 1, 0.035), Color(ACCENT, 0.3), 99, 1, Vector4(11, 4, 11, 4)))
	_panel(t, "RoomLabel", box(Color(12 / 255.0, 14 / 255.0, 19 / 255.0, 0.72), Color(1, 1, 1, 0.08), 99, 1, Vector4(12, 5, 12, 5)))
	_panel(t, "TopBar", box(Color("#14171d"), Color(0, 0, 0, 0), 0, 0, Vector4(12, 7, 12, 7)))
	_panel(t, "Side", box(Color("#13151b"), Color(0, 0, 0, 0), 0, 0, Vector4(0, 0, 0, 0)))
	_panel(t, "Bottom", box(Color("#111318"), Color(0, 0, 0, 0), 0, 0, Vector4(0, 0, 0, 0)))
	_panel(t, "ActionBar", box(Color(0, 0, 0, 0.15), Color(0, 0, 0, 0), 0, 0, Vector4(10, 8, 10, 8)))
	var cb := box(Color(40 / 255.0, 14 / 255.0, 12 / 255.0, 0.9), Color(0, 0, 0, 0), 0, 0, Vector4(10, 10, 10, 10))
	cb.border_width_top = 1
	cb.border_color = Color(1, 93 / 255.0, 93 / 255.0, 0.45)
	_panel(t, "CombatBar", cb)
	_panel(t, "Target", box(Color("#1a1719"), Color("#3a2f33"), 10, 1, Vector4(9, 7, 9, 7)))
	_panel(t, "TargetSel", box(Color("#24161a"), Color("#ff8a6a"), 10, 1, Vector4(9, 7, 9, 7)))
	_panel(t, "Quote", box(Color(ACCENT, 0.07), Color(0, 0, 0, 0), 10, 0, Vector4(16, 12, 16, 12)))
	var toast := box(Color(20 / 255.0, 22 / 255.0, 29 / 255.0, 0.95), LINE_2, 10, 1, Vector4(14, 10, 14, 10))
	toast.border_width_left = 4
	toast.shadow_color = Color(0, 0, 0, 0.5)
	toast.shadow_size = 14
	_panel(t, "Toast", toast)
	_panel(t, "MiniWrap", box(Color(10 / 255.0, 12 / 255.0, 17 / 255.0, 0.82), Color(1, 1, 1, 0.1), 10, 1, Vector4(6, 6, 6, 6)))
	_panel(t, "Tabs", box(Color(0, 0, 0, 0.18), Color(0, 0, 0, 0), 0, 0, Vector4(8, 7, 8, 7)))
	_panel(t, "Speaker", box(Color(ACCENT_2, 0.1), Color(ACCENT_2, 0.3), 99, 1, Vector4(10, 3, 10, 3)))
	_panel(t, "Rec", box(ACCENT, Color(0, 0, 0, 0), 99, 0, Vector4(8, 1, 8, 1)))

	# Eingabefeld
	t.set_stylebox("normal", "LineEdit", box(Color("#0f1116"), LINE_2, 8, 1, Vector4(10, 8, 10, 8)))
	t.set_stylebox("focus", "LineEdit", box(Color(0, 0, 0, 0), ACCENT, 8, 2, Vector4(10, 8, 10, 8)))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("font_placeholder_color", "LineEdit", Color(MUTED, 0.7))
	t.set_color("caret_color", "LineEdit", ACCENT)
	t.set_color("selection_color", "LineEdit", Color(ACCENT, 0.35))
	t.set_font_size("font_size", "LineEdit", 15)

	# Bildlaufleisten
	var grab := box(Color("#343948"), Color(0, 0, 0, 0), 8, 0, Vector4(4, 4, 4, 4))
	var grab_h := box(Color("#454b5d"), Color(0, 0, 0, 0), 8, 0, Vector4(4, 4, 4, 4))
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
