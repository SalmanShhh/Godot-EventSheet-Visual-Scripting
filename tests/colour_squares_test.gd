# Godot EventSheets - the square that leads a colour value, on the sheet and in the dialog.
#
# Pins VALUES: the marks a row builds for each colour (one per colour parameter, at the offset its value
# starts), what a run-time value and a non-colour get instead, the project's reading setting applied at
# draw time and never to the text, the quiet amber state for text in a Color slot, and the dialog's text
# field beside the colour button (an expression is never overwritten, a bare hex is written as a call).
@tool
class_name ColourSquaresTest
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")
const NAME := "colour_squares_test"


static func _action(target: String, color: String) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "SetModulate"
	action.params = {"target": target, "color": color}
	return action


static func _event_marks(editor: EventSheetEditor, event: EventRow) -> Array:
	var viewport: EventSheetViewport = editor.get_viewport_control()
	var found: Array = []
	for entry: Variant in viewport.get_flat_rows():
		var row: EventRowData = (entry as Dictionary).get("row")
		if row == null or row.source_resource != event:
			continue
		viewport._row_builder._ensure_event_spans(row)
		for span: SemanticSpan in row.spans:
			if span.metadata is Dictionary and str(span.metadata.get("kind", "")) == "action":
				found.append([span.text, span.metadata.get("colour_marks", [])])
		found.append(["attention", row.attention_note])
	return found


## A line written by hand reads through the shared grammar, not a verb's template: it gets the same square in
## the same place, in an action and in a condition, and a value the grammar would half translate reads as written.
static func _hand_written_lines_get_squares() -> bool:
	var source: String = "extends Node2D\n\nvar tint: Color = Color.WHITE\n\n\nfunc _ready() -> void:\n\tmodulate = Color.RED.lerp(Color.BLUE, 0.5)\n\ttint = Color.WHITE\n\ttint = Color(1, 0, 0)\n\tif tint == Color.RED:\n\t\tprint(1)\n"
	var sheet: EventSheetResource = SUPPORT.reopen(source, true, "")
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(sheet)
	var found: Dictionary = {}
	var viewport: EventSheetViewport = editor.get_viewport_control()
	for entry: Variant in viewport.get_flat_rows():
		var row: EventRowData = (entry as Dictionary).get("row")
		if row == null or not (row.source_resource is EventRow):
			continue
		viewport._row_builder._ensure_event_spans(row)
		for span: SemanticSpan in row.spans:
			if span.metadata is Dictionary and str(span.metadata.get("kind", "")) in ["action", "condition"]:
				var marks: Array = span.metadata.get("colour_marks", [])
				found[span.text] = [(marks[0] as Dictionary).get("at", -1), (marks[0] as Dictionary).get("folded", false), (marks[0] as Dictionary).get("raw", "")] if not marks.is_empty() else []
	var result: bool = SUPPORT.pins(NAME + ": hand-written", [
		["a folded value reads as written, with its folded square", found.get("Set tint to Color.RED.lerp(Color.BLUE, 0.5)", ["absent", found.keys()]), [12, true, "Color.RED.lerp(Color.BLUE, 0.5)"]],
		["a named constant in a variable write", found.get("Set tint to white", ["absent", found.keys()]), [12, false, "Color.WHITE"]],
		["numbers read as written", found.get("Set tint to Color(1, 0, 0)", ["absent", found.keys()]), [12, false, "Color(1, 0, 0)"]],
		["a colour condition", found.get("tint = red", ["absent", found.keys()]), [7, false, "Color.RED"]],
	])
	editor.free()
	return result


static func run() -> bool:
	if not _hand_written_lines_get_squares():
		return false
	var rows: Array = []
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnReady"
	event.actions.append(_action("$Player", "Color(\"#ff8000\")"))
	event.actions.append(_action("$Lamp", "Color(2, 0.5, 0)"))
	event.actions.append(_action("$Coin", "Color.ORANGE"))
	event.actions.append(_action("$Sword", "lerp(start_tint, end_tint, t)"))
	event.actions.append(_action("$Shade", "\"orange-ish\""))
	sheet.events.append(event)
	var tint: LocalVariable = LocalVariable.new()
	tint.name = "tint"
	tint.type_name = "Color"
	tint.default_value = "Color(\"#FF8000\")"
	tint.expression_default = true
	tint.exported = true
	sheet.events.append(tint)
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(sheet)

	ProjectSettings.set_setting(EventSheetColourValue.SETTING_NAME, null)
	var built: Array = _event_marks(editor, event)
	var player: Array = built[0][1]
	var lamp: Array = built[1][1]
	var coin: Array = built[2][1]
	var sword: Array = built[3][1]
	var shade: Array = built[4][1]
	rows.append(["Player reads as the hex it was typed", str(built[0][0]).ends_with("#ff8000"), true])
	rows.append(["Player has one square", player.size(), 1])
	rows.append(["Player's square is its colour", (player[0] as Dictionary)["color"], Color8(255, 128, 0)])
	rows.append(["Player's square belongs to the colour parameter", (player[0] as Dictionary)["param"], "color"])
	rows.append(["Player's square starts at its value", str(built[0][0]).substr(int((player[0] as Dictionary)["at"]), 7), "#ff8000"])
	rows.append(["Lamp keeps its numbers and marks it overbright", [str(built[1][0]).ends_with("Color(2, 0.5, 0)"), (lamp[0] as Dictionary)["hdr"]], [true, true]])
	rows.append(["Lamp's square is held at 1", (lamp[0] as Dictionary)["color"], Color(1.0, 0.5, 0.0, 1.0)])
	rows.append(["Coin reads as the word", str(built[2][0]).ends_with("orange"), true])
	rows.append(["Coin's square is orange", (coin[0] as Dictionary)["color"], Color.ORANGE])
	rows.append(["a value worked out while the game runs has no square", sword.is_empty() or not bool((sword[0] as Dictionary).get("square", true)), true])
	rows.append(["text that is not a colour has no square", shade.is_empty() or not bool((shade[0] as Dictionary).get("square", true)), true])
	rows.append(["text in a Color slot puts the row in the amber state, in words",
		str(built[5][1]).begins_with("Color expects a Color. \"orange-ish\" is a piece of text"), true])

	# The reading is applied when the row is built and never reaches the text the sheet holds.
	ProjectSettings.set_setting(EventSheetColourValue.SETTING_NAME, "RGB 0-255")
	editor.get_viewport_control().rebuild_rows()
	var read: Array = _event_marks(editor, event)
	rows.append(["Player reads in 0-255 when asked", str(read[0][0]).ends_with("255, 128, 0"), true])
	rows.append(["Lamp falls back to as written", str(read[1][0]).ends_with("Color(2, 0.5, 0)"), true])
	rows.append(["the stored text is untouched", str((event.actions[0] as ACEAction).params["color"]), "Color(\"#ff8000\")"])
	ProjectSettings.set_setting(EventSheetColourValue.SETTING_NAME, null)

	# A variable's value leads with a square and reads as it was written.
	var variable_marks: Array = []
	var variable_text: String = ""
	var viewport: EventSheetViewport = editor.get_viewport_control()
	viewport.rebuild_rows()
	for entry: Variant in viewport.get_flat_rows():
		var row: EventRowData = (entry as Dictionary).get("row")
		if row == null or not row.variable_row:
			continue
		for span: SemanticSpan in row.spans:
			if span.metadata is Dictionary and bool(span.metadata.get("variable_value_span", false)):
				variable_marks = span.metadata.get("colour_marks", [])
				variable_text = span.text
	rows.append(["a variable reads as it was written", variable_text, "#FF8000"])
	rows.append(["a variable's square leads its value", [(variable_marks[0] as Dictionary)["at"], (variable_marks[0] as Dictionary)["color"]], [0, Color8(255, 128, 0)]])

	# The dialog: the button beside a text field; an expression is kept, a bare hex is written as a call.
	var dialog: ACEParamsDialog = ACEParamsDialog.new()
	var column: Control = dialog._create_color_field("color", "other.modulate")
	var edit: LineEdit = dialog._fields["color"]
	rows.append(["the field shows an expression untouched", edit.text, "other.modulate"])
	rows.append(["the value written is the expression, byte for byte", dialog._extract_value(edit), "other.modulate"])
	rows.append(["the button is hatched for a run-time value", column.get_child(0).get_child(0).has_meta("hatched"), true])
	edit.text = "#ff8000"
	rows.append(["a bare hex is written as a Color call", dialog._extract_value(edit), "Color(\"#ff8000\")"])
	edit.text = "orange"
	rows.append(["a bare name is written as a Color call", dialog._extract_value(edit), "Color(\"orange\")"])
	edit.text = "Color8(255, 128, 0)"
	rows.append(["a Color8 call is written as typed", dialog._extract_value(edit), "Color8(255, 128, 0)"])
	edit.text = "\"orange-ish\""
	edit.text_changed.emit(edit.text)
	rows.append(["text that is not a colour is said so under the field", (column.get_child(1) as Label).visible, true])
	column.free()
	editor.free()
	return SUPPORT.pins(NAME, rows)
