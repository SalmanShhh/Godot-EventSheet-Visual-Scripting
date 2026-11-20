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
## The same on a firing row, held a notch lower for the reason the firing row's own words are.
const FIRING_SELECTED_BAR: float = 2.5
## What a variable row's scope word must keep on the row's wash (a mark, not a sentence).
const SCOPE_BAR: float = 3.0
## What a small mark or a chip's word must keep on its plate.
const MARK_BAR: float = 3.0


static func run() -> bool:
	var ok: bool = true
	for path: String in PRESET_PATHS:
		var style: EventSheetEditorStyle = load(path) as EventSheetEditorStyle
		if style == null:
			ok = SUPPORT.pin_value(TEST_NAME, "%s loads" % path.get_file(), false, true) and ok
			continue
		ok = _test_state_washes(path.get_file(), style) and ok
		ok = _test_marks(path.get_file(), style) and ok
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
	# A selected cell is drawn as the renderer draws it: the plate AS THE ROW'S STATE LEAVES IT (any error, cannot-run or
	# firing wash laid on it), then the cell's own ink over it at the chip's selection strength. Every word the cell holds
	# is measured on that, in every state: the sentence, the object's name and (in the action lane) the action's accent.
	var combos: Dictionary = {
		"a plain row": [[], SELECTED_BAR],
		"an error row": [["an error row"], SELECTED_BAR],
		"a cannot-run row": [["a cannot-run row"], SELECTED_BAR],
		"a firing row": [["a firing row"], FIRING_SELECTED_BAR],
	}
	for combo: String in combos:
		var washes: Array[Color] = []
		for state: String in combos[combo][0]:
			washes.append(Wash.wash_color(states[state][0] as Color, float(states[state][1]), pale))
		for lane: String in lanes:
			var cell_ink: Color = lanes[lane][1] as Color
			var washed_plate: Color = Wash.under_washes(_opaque(event_style, lanes[lane][0] as Color), washes)
			# The renderer takes the lighter hold on a row that wears a state wash.
			var hold: float = EventSheetRowRenderer.CHIP_SELECT_FILL_ALPHA if washes.is_empty() else EventSheetRowRenderer.CHIP_SELECT_FILL_ALPHA_STATED
			var selected: Color = washed_plate.lerp(Color(cell_ink.r, cell_ink.g, cell_ink.b, 1.0), hold)
			var words: Dictionary = {"sentence": [cell_ink, "the lane's text_color"], "object name": [event_style.object_label_color, "object_label_color"]}
			if lane == "action":
				words["action accent"] = [event_style.ace_action_accent_color, "ace_action_accent_color"]
			for word: String in words:
				var selected_ratio: float = EventSheetEditorThemeDeriver.contrast_ratio(words[word][0] as Color, selected)
				ok = SUPPORT.pin_value(TEST_NAME, "%s: the %s's %s reads on a selected cell of %s (%.1f to 1; the bar is %.1f; set %s)" % [name, lane, word, combo, selected_ratio, float(combos[combo][1]), words[word][1]],
					selected_ratio >= float(combos[combo][1]), true) and ok
	return ok


## A translucent fill as the colour that reaches the screen over the sheet's canvas.
static func _opaque(event_style: EventSheetEventStyle, color: Color) -> Color:
	return event_style.sheet_background_color.lerp(Color(color.r, color.g, color.b, 1.0), color.a)


## The marks and plates outside the rows: the pattern chip, the amber of a quiet finding, the Inspector drawer's note
## and the Manual's active contents entry, each against the ground it is drawn on.
static func _test_marks(name: String, style: EventSheetEditorStyle) -> bool:
	var ok: bool = true
	var event_style: EventSheetEventStyle = style.get_event_style()
	var reading: EventSheetReadingStyle = style.get_reading_style()
	var chrome: EventSheetChromeStyle = style.get_chrome_style()
	var manual: EventSheetManualStyle = style.get_manual_style()
	var ground: Color = _opaque(event_style, Color(event_style.row_background_color.r, event_style.row_background_color.g, event_style.row_background_color.b, 1.0))
	# The quiet amber state: the warning colour is the event's number in the margin and the help strip's mark.
	var gutter: Color = _flatten(event_style.gutter_background_color, ground)
	var amber_ratio: float = EventSheetEditorThemeDeriver.contrast_ratio(chrome.object_bar_warning_color, gutter)
	ok = SUPPORT.pin_value(TEST_NAME, "%s: the amber of a quiet finding reads in the margin (%.1f to 1; the bar is %.1f; set object_bar_warning_color)" % [name, amber_ratio, MARK_BAR],
		amber_ratio >= MARK_BAR, true) and ok
	var header_ratio: float = EventSheetEditorThemeDeriver.contrast_ratio(chrome.drawer_header_text_color, _flatten(chrome.drawer_well_color, ground))
	ok = SUPPORT.pin_value(TEST_NAME, "%s: the Inspector drawer's heading reads on its well (%.1f to 1; the bar is %.1f; set drawer_header_text_color)" % [name, header_ratio, WORDS_BAR],
		header_ratio >= WORDS_BAR, true) and ok
	# The Manual's active contents entry, where the theme states both halves of the pill.
	if EventSheetManualStyle.has_opinion(manual.contents_active_background_color) and EventSheetManualStyle.has_opinion(manual.contents_active_text_color):
		var pill_ratio: float = EventSheetEditorThemeDeriver.contrast_ratio(manual.contents_active_text_color, _flatten(manual.contents_active_background_color, ground))
		ok = SUPPORT.pin_value(TEST_NAME, "%s: the Manual's active contents entry reads on its pill (%.1f to 1; the bar is %.1f; set contents_active_text_color)" % [name, pill_ratio, WORDS_BAR],
			pill_ratio >= WORDS_BAR, true) and ok
	return ok


## A colour with any translucence laid over an opaque ground.
static func _flatten(color: Color, ground: Color) -> Color:
	return ground.lerp(Color(color.r, color.g, color.b, 1.0), color.a)
