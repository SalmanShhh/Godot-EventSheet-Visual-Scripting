# A row that is firing, flagged or cannot run is told by a wash over its cells, and on a pale sheet that wash has
# to be seen over WHITE cells: the cell plates are opaque and painted after the row's own fill, so each takes
# the same wash itself, from a deeper hue at a stronger strength than a dark sheet needs, and every word keeps
# its contrast against the washed plate. The dark sheets keep the strengths they had.
@tool
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")
const TEST_NAME: String = "state_wash_light_test"
const Wash := preload("res://addons/eventsheet/editor/state_wash.gd")
const LIGHT_LOOKS: PackedStringArray = ["res://demo/themes/solarized_light_theme.tres"]
const DARK_LOOKS: PackedStringArray = [
	"res://addons/eventsheet/themes/classic_sheet_theme.tres", "res://demo/themes/high_contrast_theme.tres",
]


static func run() -> bool:
	var ok: bool = true
	ok = _test_the_strengths() and ok
	for path: String in LIGHT_LOOKS:
		ok = _test_a_pale_look(path, load(path) as EventSheetEditorStyle) and ok
	ok = _test_a_pale_look("the look derived from a light editor", _derived_light()) and ok
	for path: String in DARK_LOOKS:
		ok = _test_a_dark_look_keeps_its_strengths(path) and ok
	return ok


static func _test_the_strengths() -> bool:
	var hue: Color = Color("#ff5555")
	var dark: Color = Wash.wash_color(hue, 0.12, false)
	var pale: Color = Wash.wash_color(hue, 0.12, true)
	return SUPPORT.pins(TEST_NAME, [
		["a dark sheet keeps the hue as it is", dark, Color(hue.r, hue.g, hue.b, 0.12)],
		["a pale sheet's wash is stronger", pale.a > dark.a, true],
		["and its hue is deeper", pale.get_luminance() < hue.get_luminance(), true],
		["a wash is never stronger than a plate can take", Wash.wash_color(hue, 0.9, true).a <= 0.6001, true],
		["no wash laid on a plate leaves it as it was", Wash.under_washes(Color.WHITE, []), Color.WHITE],
		["a plate keeps its own opacity", Wash.under_washes(Color(1, 1, 1, 0.5), [pale]).a, 0.5],
	])


static func _derived_light() -> EventSheetEditorStyle:
	var base_color: Color = Color("#ebebef")
	var style: EventSheetEditorStyle = EventSheetEditorStyle.new()
	style.ensure_defaults()
	EventSheetGodotTheme.apply(style, base_color, base_color.darkened(0.15), base_color.darkened(0.25), Color("#1a73d9"), Color("#1c1c1e"))
	return style


static func _test_a_pale_look(path: String, style: EventSheetEditorStyle) -> bool:
	var ok: bool = true
	var event_style: EventSheetEventStyle = style.get_event_style()
	var reading: EventSheetReadingStyle = style.get_reading_style()
	ok = SUPPORT.pin_value(TEST_NAME, "%s is a pale ground" % path.get_file(), Wash.is_pale_ground(event_style), true) and ok
	var plate: Color = Color.WHITE
	var ink: Color = reading.primary_text_color
	var states: Dictionary = {
		"flagged": [reading.error_stripe_color, EventSheetRowRenderer.ERROR_WASH_ALPHA],
		"cannot run": [reading.error_stripe_color, EventSheetRowRenderer.CANNOT_RUN_WASH_ALPHA],
		"firing": [reading.firing_stripe_color, EventSheetRowRenderer.FIRING_WASH_ALPHA],
	}
	for state: String in states:
		var entry: Array = states[state]
		var washed: Color = Wash.under_washes(plate, [Wash.wash_color(entry[0] as Color, float(entry[1]), true)])
		var seen: float = absf(washed.get_luminance() - plate.get_luminance())
		var contrast: float = EventSheetLookStyle.contrast_ratio(ink, washed)
		ok = SUPPORT.pin_value(TEST_NAME, "%s: a %s cell is told from a plain one (%.3f)" % [path.get_file(), state, seen], seen >= 0.06, true) and ok
		ok = SUPPORT.pin_value(TEST_NAME, "%s: its words keep their contrast (%.1f)" % [path.get_file(), contrast],
			contrast >= Wash.WASH_TEXT_CONTRAST, true) and ok
	return ok


static func _test_a_dark_look_keeps_its_strengths(path: String) -> bool:
	var style: EventSheetEditorStyle = load(path) as EventSheetEditorStyle
	return SUPPORT.pin_value(TEST_NAME, "%s is not a pale ground" % path.get_file(),
		Wash.is_pale_ground(style.get_event_style()), false)
