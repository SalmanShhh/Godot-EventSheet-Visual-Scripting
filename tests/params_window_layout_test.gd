# Godot EventSheets - the parameters window, laid out the familiar way.
#
# The window is titled "Parameters for <object>: <action>", names the object and the action with its
# description on top, gives every parameter one row (name left, box right), says a problem under its
# own row, splits a position into X and Y rows, puts a "click to choose" door on a node parameter,
# describes every dropdown choice, and keeps an Expressions panel beside the form that inserts into
# the focused box. Everything here is built on a detached host, because the window's logic needs no
# display server.
@tool
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")
const NAME := "params_window_layout_test"


static func run() -> bool:
	var host: Node = Node.new()
	var dialog: ACEParamsDialog = ACEParamsDialog.new()
	dialog.init_dialog(host)
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.variables = {"hp": {"type": "int", "default": 100, "exported": false}}
	dialog.set_lint_context_provider(func() -> EventSheetResource: return sheet)
	var definition: ACEDefinition = _definition()
	dialog._definition = definition
	dialog._context = {"mode": "append_action"}
	dialog._build_form(definition, {})
	dialog._fill_header()

	var ok: bool = _test_frame(dialog)
	ok = _test_rows(dialog) and ok
	ok = _test_problem_under_its_row(dialog) and ok
	ok = _test_expressions_panel(dialog) and ok
	ok = _test_object_choice_replaces(dialog) and ok
	ok = _test_key_list_is_described(dialog) and ok
	host.free()
	return ok


## The frame: title, head, buttons, and the Expressions panel beside the form.
static func _test_frame(dialog: ACEParamsDialog) -> bool:
	var panel: Control = dialog._expression_picker._panel
	return SUPPORT.pins(NAME, [
		["the window is titled for the object and the action", dialog._dialog.title,
			"Parameters for Node2D: Move toward"],
		["the head names the object and the action", dialog._header_name.text, "Node2D  ·  Move toward"],
		["and says what the action does under them", dialog._header_about.text,
			"Move toward a point at a fixed speed."],
		["a native action keeps its class-reference door", dialog._header_docs.visible, true],
		["the confirm button reads Done", dialog._dialog.ok_button_text, "Done"],
		["Back leads the buttons", [dialog._back_button.text,
			dialog._back_button.get_index() < dialog._add_another_button.get_index(),
			dialog._add_another_button.get_index() < dialog._dialog.get_ok_button().get_index()], ["Back", true, true]],
		["the Expressions panel sits beside the form", panel.get_parent().get_child(1) == panel, true],
	])


## One row per parameter; a position is two; a unit sits beside an angle; a node row carries its door;
## a dropdown's choices each carry their line.
static func _test_rows(dialog: ACEParamsDialog) -> bool:
	var position_labels: Array = []
	for label: Label in (dialog._rows["position"] as Dictionary)["labels"]:
		position_labels.append(label.text)
	var axes: Array = (dialog._fields["position"] as Control).get_meta("vector_axis_edits")
	(axes[1] as LineEdit).text = "hp"
	var easing: OptionButton = dialog._fields["easing"] as OptionButton
	easing.select(1)
	EventSheetPopupUI.follow_description(easing)
	return SUPPORT.pins(NAME, [
		["every parameter has its row", dialog._rows.keys(), ["speed", "position", "target", "turn", "easing"]],
		["a position splits into one row per axis", position_labels, ["Position X", "Position Y"]],
		["and its boxes compose back into one vector", dialog._extract_value(dialog._fields["position"]),
			"Vector2(4, hp)"],
		["an expression box carries no per-box button",
			_row_line(dialog, "speed").find_children("*", "Button", true, false).size(), 0],
		["a node row carries the door into the node search",
			_texts(_row_line(dialog, "target"), "Button").has("click to choose"), true],
		["an angle shows its unit beside the box", _texts(_row_line(dialog, "turn"), "Label").has("°"), true],
		["each choice carries its line as the item tooltip", easing.get_item_tooltip(1), "slows down as it arrives"],
		["a choice with no line says the code it writes", easing.get_item_tooltip(0), "linear"],
		["the closed dropdown says the chosen one's line", easing.tooltip_text, "slows down as it arrives"],
	])


## A problem is one sentence under its own row, in its tone, and the row the strip speaks about is lit.
static func _test_problem_under_its_row(dialog: ACEParamsDialog) -> bool:
	var speed: CodeEdit = dialog._fields["speed"] as CodeEdit
	speed.text = "missing_thing * 2"
	dialog._validate_expression_field(speed)
	var note: EventSheetPopupUI.StateNote = (dialog._rows["speed"] as Dictionary)["note"]
	var quiet: EventSheetPopupUI.StateNote = (dialog._rows["target"] as Dictionary)["note"]
	dialog._describe_field("speed")
	return SUPPORT.pins(NAME, [
		["the row with the problem says it under itself", [note.visible, note.tone], [true, "error"]],
		["in the words the strip uses", note.text.begins_with("missing_thing is not a variable"), true],
		["a row with nothing wrong says nothing", quiet.visible, false],
		["the strongest problem stands beside Done", dialog._ok_reason.text, "fix Speed first"],
		["the focused row is lit", _wash(dialog, "speed") > 0.0, true],
		["and only that one", _wash(dialog, "target"), 0.0],
	])


## Double-click in the Expressions panel inserts at the caret of the box that last had focus.
static func _test_expressions_panel(dialog: ACEParamsDialog) -> bool:
	var speed: CodeEdit = dialog._fields["speed"] as CodeEdit
	speed.text = "220"
	speed.set_caret_column(3)
	dialog._expression_picker.aim("speed", speed)
	dialog._expression_picker._insert_into_expression_target(" * 2")
	return SUPPORT.pins(NAME, [
		["the panel inserts into the focused box", speed.text, "220 * 2"],
		["and says how", _texts(dialog._expression_picker._panel, "Label").has(
			"Double-click to insert into the focused box."), true],
	])


## Choosing an object answers the whole parameter: the pick replaces the box, it is not typed into it.
static func _test_object_choice_replaces(dialog: ACEParamsDialog) -> bool:
	dialog._node_picker._ensure_node_picker_ui()
	dialog._node_picker._node_picker_target_key = "target"
	dialog._node_picker._hand_back("%Enemy")
	return SUPPORT.check(NAME, "a picked node replaces what the box said",
		(dialog._fields["target"] as LineEdit).text, "%Enemy")


## The press-a-key field's fallback list is a described dropdown too.
static func _test_key_list_is_described(dialog: ACEParamsDialog) -> bool:
	var field: Control = dialog._create_key_capture_field("key", "")
	var fallback: OptionButton = field.find_children("*", "OptionButton", true, false)[0] as OptionButton
	var told: String = fallback.get_item_tooltip(1)
	field.free()
	return SUPPORT.check(NAME, "each key in the fallback list says which key it is", told, "The Space key")


## The line a parameter's name and box sit on.
static func _row_line(dialog: ACEParamsDialog, key: String) -> Control:
	var panel: PanelContainer = ((dialog._rows[key] as Dictionary)["panels"] as Array)[0]
	return panel.get_child(0).get_child(0) as Control


## How strongly a row's panel is lit (its wash's alpha).
static func _wash(dialog: ACEParamsDialog, key: String) -> float:
	var panel: PanelContainer = ((dialog._rows[key] as Dictionary)["panels"] as Array)[0]
	return (panel.get_theme_stylebox("panel") as StyleBoxFlat).bg_color.a


## The texts of every control of one class under `node`.
static func _texts(node: Node, class_title: String) -> Array:
	var texts: Array = []
	for found: Node in node.find_children("*", class_title, true, false):
		texts.append(str(found.get("text")))
	return texts


## A native node's action with one parameter of each row shape this window lays out differently.
static func _definition() -> ACEDefinition:
	var definition: ACEDefinition = ACEDefinition.new()
	definition.provider_id = "Core"
	definition.id = "ParamsLayoutProbe"
	definition.display_name = "Move toward"
	definition.description = "Move toward a point at a fixed speed."
	definition.ace_type = ACEDefinition.ACEType.ACTION
	definition.metadata = {"node_type": "Node2D", "codegen_template": "move({speed}, {position}, {target}, {turn}, {easing})"}
	definition.parameters = [
		{"id": "speed", "display_name": "Speed", "type_name": "float", "hint": "expression", "default_value": "220"},
		{"id": "position", "display_name": "Position", "type_name": "Vector2", "hint": "", "default_value": "Vector2(4, 8)"},
		{"id": "target", "display_name": "Target", "type_name": "String", "hint": "scene_node", "default_value": "self"},
		{"id": "turn", "display_name": "Turn", "type_name": "float", "hint": "angle", "default_value": "90"},
		{"id": "easing", "display_name": "Easing", "type_name": "String", "hint": "", "default_value": "linear",
			"options": [{"key": "linear", "label": "Even"}, {"key": "ease_out", "label": "Ease out",
				"note": "slows down as it arrives"}]},
	]
	return definition
