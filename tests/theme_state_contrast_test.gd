# The states a row can be in - flagged with an error, unable to run, firing during a run, a selected cell - are told
# by a wash over the row's cells and a coloured number in the margin, no longer by a bar at its left edge. So the
# wash has to be SEEN and the words under it have to stay READABLE, in every theme the plugin ships, dark or pale:
# a hue chosen for a thin bar can be the wrong hue for a flood of colour (a pale-green wash that lifts a dark
# cell until its words fall under the body-text bar, a wash so quiet on a pale cell that the row looks plain).
#
# Each shipped theme is held to the same pairs the renderer draws: the sentence of each lane over its cell with each
# state's wash laid on it (the same wash helper the renderer calls), and the sentence over a selected cell's fill.
@tool
class_name ThemeStateContrastTest
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")
const TEST_NAME: String = "theme_state_contrast_test"
const Wash := preload("res://addons/eventsheet/editor/state_wash.gd")

## Every shipped theme: the nine in the demo folder and the three in the addon.
const PRESET_PATHS := [
	"res://demo/themes/catppuccin_mocha_theme.tres",
	"res://demo/themes/designer_template_theme.tres",
	"res://demo/themes/dracula_theme.tres",
	"res://demo/themes/gruvbox_dark_theme.tres",
	"res://demo/themes/high_contrast_theme.tres",
	"res://demo/themes/monokai_theme.tres",
	"res://demo/themes/nord_theme.tres",
	"res://demo/themes/soft_light_theme.tres",
	"res://demo/themes/solarized_light_theme.tres",
	"res://addons/eventsheet/themes/classic_sheet_theme.tres",
	"res://addons/eventsheet/themes/editor_native_theme.tres",
	"res://addons/eventsheet/themes/mockup_slate_theme.tres",
]

## The least a state's wash changes a cell, as the largest change in any colour channel: below this the row looks plain.
const WASH_SEEN: float = 0.05
## What the sentence of a cell must keep while an error or cannot-run wash lies over it, and while a firing wash does. A
## firing row flashes and fades with every pass of the game, so its words are held to a lower bar than a row that stays
## flagged until it is fixed.
const WORDS_BAR: float = 4.0
const FIRING_WORDS_BAR: float = 3.5
## What the sentence over a selected cell must keep: the cell is tinted a fifth over with its own ink.
const SELECTED_BAR: float = 3.0
## What a variable row's scope word must keep on the row's wash (a mark, not a sentence).
const SCOPE_BAR: float = 3.0


static func run() -> bool:
	var ok: bool = true
	for path: String in PRESET_PATHS:
		var style: EventSheetEditorStyle = load(path) as EventSheetEditorStyle
		if style == null:
			ok = SUPPORT.pin_value(TEST_NAME, "%s loads" % path.get_file(), false, true) and ok
			continue
		ok = _test_state_washes(path.get_file(), style) and ok
	return ok


## One theme's washes: each state seen, and the sentence of each lane still readable under it.
static func _test_state_washes(name: String, style: EventSheetEditorStyle) -> bool:
	var ok: bool = true
	var event_style: EventSheetEventStyle = style.get_event_style()
	var reading: EventSheetReadingStyle = style.get_reading_style()
	var pale: bool = Wash.is_pale_ground(event_style)
	var states: Dictionary = {
		"an error row": [reading.error_stripe_color, EventSheetRowRenderer.ERROR_WASH_ALPHA, "error_stripe_color", WORDS_BAR],
		"a cannot-run row": [reading.error_stripe_color, EventSheetRowRenderer.CANNOT_RUN_WASH_ALPHA, "error_stripe_color", WORDS_BAR],
		"a firing row": [reading.firing_stripe_color, EventSheetRowRenderer.FIRING_WASH_ALPHA, "firing_stripe_color", FIRING_WORDS_BAR],
	}
	var lanes: Dictionary = {
		"condition": [event_style.condition_lane_color, style.get_condition_style().get("text_color")],
		"action": [event_style.action_lane_color, style.get_action_style().get("text_color")],
	}
	for state: String in states:
		var entry: Array = states[state]
		var wash: Color = Wash.wash_color(entry[0] as Color, float(entry[1]), pale)
		for lane: String in lanes:
			var plate: Color = _opaque(event_style, lanes[lane][0] as Color)
			var words: Color = lanes[lane][1] as Color
			var washed: Color = Wash.under_washes(plate, [wash])
			var change: float = maxf(absf(washed.r - plate.r), maxf(absf(washed.g - plate.g), absf(washed.b - plate.b)))
			ok = SUPPORT.pin_value(TEST_NAME, "%s: %s is told from a plain one on the %s cell (change %.3f; set %s)" % [name, state, lane, change, entry[2]],
				change >= WASH_SEEN, true) and ok
			var ratio: float = EventSheetEditorThemeDeriver.contrast_ratio(words, washed)
			ok = SUPPORT.pin_value(TEST_NAME, "%s: the %s sentence reads on %s (%.1f to 1; the bar is %.1f; set %s)" % [name, lane, state, ratio, float(entry[3]), entry[2]],
				ratio >= float(entry[3]), true) and ok
	# A variable's scope word is drawn in variable_row_rule_color, on the variable row's own wash.
	# A look that writes variables as Inspector rows (Editor Native) draws no scope word, so the pair is not drawn there.
	if not event_style.inspector_variable_rows:
		var variable_ground: Color = _opaque(event_style, reading.variable_row_wash_color)
		var scope_ratio: float = EventSheetEditorThemeDeriver.contrast_ratio(_opaque(event_style, reading.variable_row_rule_color), variable_ground)
		ok = SUPPORT.pin_value(TEST_NAME, "%s: a variable's scope word reads on its row (%.1f to 1; the bar is %.1f; set variable_row_rule_color)" % [name, scope_ratio, SCOPE_BAR],
			scope_ratio >= SCOPE_BAR, true) and ok
	for lane: String in lanes:
		var words_on_lane: Color = lanes[lane][1] as Color
		var selected: Color = _opaque(event_style, lanes[lane][0] as Color).lerp(Color(words_on_lane.r, words_on_lane.g, words_on_lane.b, 1.0), 0.28)
		var selected_ratio: float = EventSheetEditorThemeDeriver.contrast_ratio(words_on_lane, selected)
		ok = SUPPORT.pin_value(TEST_NAME, "%s: the %s sentence reads on a selected cell (%.1f to 1; the bar is %.1f)" % [name, lane, selected_ratio, SELECTED_BAR],
			selected_ratio >= SELECTED_BAR, true) and ok
	return ok


## A translucent fill as the colour that reaches the screen over the sheet's canvas.
static func _opaque(event_style: EventSheetEventStyle, color: Color) -> Color:
	return event_style.sheet_background_color.lerp(Color(color.r, color.g, color.b, 1.0), color.a)
