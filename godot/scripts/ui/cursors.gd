class_name Cursors
extends RefCounted
## Mauszeiger im Pixel-Stil: ein Schwert über Gegnern (angreifen), eine Hand
## über allem, womit man etwas tun kann (Gegenstände, Türen, Möbel, Personen,
## Knöpfe). Sie ersetzen die Systemzeiger „Kreuz“ und „Hand“.

const SCALE := 2
const COLORS := {"o": "#1b1b26", "w": "#e8eef4", "s": "#9aa4b0", "g": "#e0b040", "b": "#7a4a2a", "h": "#f2e6cf", "H": "#cdb894"}

const SWORD := [
	"oo..............",
	"owo.............",
	"oswo............",
	".oswo...........",
	"..oswo..........",
	"...oswo.........",
	"....oswo........",
	".....oswo.......",
	"......oswo.oo...",
	".......oswogo...",
	"........osggo...",
	".......ogggo....",
	"......ogoobbo...",
	".......o..obbo..",
	"...........obbo.",
	"............ooo.",
]

const HAND := [
	".....oo.........",
	"....ohho........",
	"....ohho........",
	"....ohho........",
	"....ohhooo......",
	"....ohhohhoo....",
	".oo.ohhohhohoo..",
	"ohhoohhhhhhohho.",
	"ohhhohhhhhhhhho.",
	".ohhhhhhhhhhhho.",
	"..ohhhhhhhhhhho.",
	"..ohhhhhhhhhHo..",
	"...ohhhhhhhHHo..",
	"...ohhhhhhHHo...",
	"....ohhhhHHHo...",
	"....oooooooo....",
]

static var _done := false


static func image(rows: Array) -> Image:
	var h := rows.size()
	var w: int = String(rows[0]).length()
	var img := Image.create(w * SCALE, h * SCALE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in h:
		var row: String = rows[y]
		for x in w:
			var ch := row[x]
			if not COLORS.has(ch):
				continue
			var c := Color(COLORS[ch])
			for dy in SCALE:
				for dx in SCALE:
					img.set_pixel(x * SCALE + dx, y * SCALE + dy, c)
	return img


## Einmal beim Start: Schwert und Hand als Zeiger anmelden.
static func install() -> void:
	if _done or DisplayServer.get_name() == "headless":
		return
	_done = true
	Input.set_custom_mouse_cursor(image(SWORD), Input.CURSOR_CROSS, Vector2(1, 1))
	Input.set_custom_mouse_cursor(image(HAND), Input.CURSOR_POINTING_HAND, Vector2(5 * SCALE, 0))
