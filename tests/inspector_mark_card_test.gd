@tool
class_name InspectorMarkCardTest
extends RefCounted

## The card behind a variable's Inspector mark: a mark that wears a look names the look, says its
## sentence, tells where to change it and quotes the whole declaration line; a look that is not
## installed says so; a plain mark keeps today's words. The door is open only for a variable the row
## declares itself.

const SUPPORT := preload("res://tests/support.gd")
const NativeVariableMarks := preload("res://addons/eventsheet/editor/interaction/native_variable_marks.gd")


static func run() -> bool:
	var ranged: LocalVariable = LocalVariable.new()
	ranged.name = "health"
	ranged.type_name = "int"
	ranged.default_value = 60
	ranged.exported = true
	ranged.attributes = {"range": {"min": "0", "max": "100", "step": "1"}}
	var mark: Dictionary = NativeVariableMarks.inspector_mark(ranged, "int", 60)
	var card: Dictionary = NativeVariableMarks.badge_card(NativeVariableMarks.BADGE_INSPECTOR, ranged, mark)
	var missing_variable: LocalVariable = LocalVariable.new()
	missing_variable.name = "rating"
	missing_variable.type_name = "int"
	missing_variable.default_value = 3
	missing_variable.exported = true
	missing_variable.attributes = {"look": "star_rating_not_here"}
	var missing_mark: Dictionary = NativeVariableMarks.inspector_mark(missing_variable, "int", 3)
	var missing_card: Dictionary = NativeVariableMarks.badge_card(NativeVariableMarks.BADGE_INSPECTOR, missing_variable, missing_mark)
	var plain_card: Dictionary = NativeVariableMarks.badge_card(NativeVariableMarks.BADGE_INSPECTOR, ranged)
	var tint: LocalVariable = LocalVariable.new()
	tint.name = "tint"
	tint.type_name = "Color"
	tint.default_value = "Color(1, 0.5, 0.25)"
	tint.exported = true
	var tint_card: Dictionary = NativeVariableMarks.badge_card(NativeVariableMarks.BADGE_INSPECTOR, tint, NativeVariableMarks.inspector_mark(tint, "Color", tint.default_value))
	var own: EventRowData = _row(true)
	var elsewhere: EventRowData = _row(false)
	return SUPPORT.pins("inspector_mark_card_test", [
		["a slider mark's card is titled by the look", card["title"], "Slider"],
		["it quotes the declaration line", card["mono"], "@export_range(0, 100, 1) var health: int = 60"],
		["it says the limits and where to change the look", (card["lines"] as PackedStringArray)[(card["lines"] as PackedStringArray).size() - 1], "Click the mark to change the look."],
		["the limits sentence is among its lines", (card["lines"] as PackedStringArray).has("A slider in the Inspector, from 0 to 100."), true],
		["a look that is not installed says so", missing_card["title"], "Look not installed"],
		["and names the file", (missing_card["lines"] as PackedStringArray)[0], "The file star_rating_not_here.gd is missing, so the Inspector shows a plain field."],
		["a plain mark keeps today's title", plain_card["title"], "In the Inspector"],
		["and has no change-the-look line", (plain_card["lines"] as PackedStringArray).has("Click the mark to change the look."), false],
		["a Color's card says the mark is its colour", tint_card["title"], "Colour in the Inspector"],
		["the door is open on a row that declares the variable", NativeVariableMarks.look_door_open(own), true],
		["and shut on one shown from another script", NativeVariableMarks.look_door_open(elsewhere), false],
		["no variable has no declaration line", NativeVariableMarks.declaration_line(null), ""],
	])


static func _row(editable: bool) -> EventRowData:
	var row: EventRowData = EventRowData.new()
	row.variable_row = true
	var span: EventSheetSemanticSpan = EventSheetSemanticSpan.new()
	span.metadata = {"variable_name_span": true, "editable": editable}
	row.spans = [span]
	return row
