# Godot EventSheets - the bold overlay on a row's parameters lands on the very word it re-draws.
#
# Opened in a user's project, player.gd's "Accelerate x toward direction * speed at acceleration
# (per second)" drew `acceleration` as two smeared copies. The base pass draws the sentence piece by
# piece at the edges of its coloured words, each piece measured on its own; the bold overlay placed
# each parameter by the width of the whole text in front of it. Pieces measured one by one do not add
# up to the prefix measured whole - a pixel or more per piece - so the overlay landed beside the word.
# The overlay now takes its x from the same walk the base pass makes.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "param_emphasis_lands_on_its_word_test"

const TEXT := "Accelerate x toward direction * speed at acceleration (per second)"
## The two parameters, and the two variable names the theme colours, as the row builder stamps them.
const PARAM_RANGES: Array = [[20, 17], [41, 12]]
const WORD_RANGES: Array = [[32, 5, "variable"], [41, 12, "variable"]]


static func run() -> bool:
	var font: Font = ThemeDB.fallback_font
	var size: int = 14
	# Where the base pass puts each word: the pieces it draws, each measured as it is drawn.
	var speed_x: float = _width(TEXT.substr(0, 32), font, size)
	var acceleration_x: float = speed_x + _width("speed", font, size) + _width(" at ", font, size)
	var placed: Dictionary = {}
	for overlay_run: Array in EventRowRenderer.emphasis_runs(TEXT, PARAM_RANGES, WORD_RANGES, font, size):
		placed[str(overlay_run[1])] = float(overlay_run[0])
	return SUPPORT.pins(P, [
		["the overlay re-draws the parameters' words, split where their colours change", placed.keys(),
			["direction * ", "speed", "acceleration"]],
		["each lands where the base pass drew it", [placed.get("speed"), placed.get("acceleration")],
			[speed_x, acceleration_x]],
		["the base pass's walk is the one the overlay asks",
			EventRowRenderer.base_pass_x(TEXT, 41, WORD_RANGES, font, size), acceleration_x],
	])


static func _width(text: String, font: Font, size: int) -> float:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x
