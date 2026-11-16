# Godot EventSheets - the open Drawing Prefab card: one surface, Shape first, one Offset row, the shape's
# own named fields with their units as small plain text, a colour button, a texture picked with Godot's
# own picker and kept as uid text, and a "Line look" fold on a line only.
#
# Pinned as data (which fields, in which order, with which words) and by driving the controls the card
# builds: every one writes the key it stands for and no other.
@tool
class_name DrawingPrefabOpenCardTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const PREFIX := "drawing_prefab_open_card_test"
const PREFAB_STEPS := preload("res://addons/eventsheet/editor/inspector/drawing_prefab_steps_property.gd")


static func _step(kind: String, extra: Dictionary) -> Dictionary:
	var step: Dictionary = {"kind": kind, "x": 1.0, "y": 2.0, "p1": 10.0, "p2": 20.0, "p3": 4.0, "color": "#ffd24d", "texture": ""}
	for key: Variant in extra:
		step[str(key)] = extra[key]
	return step


static func _keys(fields: Array) -> String:
	var keys: PackedStringArray = PackedStringArray()
	for field: Variant in fields:
		keys.append(str((field as Dictionary).get("key", "")))
	return ",".join(keys)


static func _labels(fields: Array) -> String:
	var labels: PackedStringArray = PackedStringArray()
	for field: Variant in fields:
		labels.append(str((field as Dictionary).get("label", "")))
	return ",".join(labels)


static func _nodes_of(node: Node, type_name: String, found: Array) -> Array:
	if node.is_class(type_name):
		found.append(node)
	for child: Node in node.get_children():
		_nodes_of(child, type_name, found)
	return found


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _pin_the_fields() and all_passed
	all_passed = _pin_the_controls() and all_passed
	all_passed = _pin_the_texture_is_kept_as_text() and all_passed
	return all_passed


static func _pin_the_fields() -> bool:
	var editor: GDScript = PREFAB_STEPS.ShapeStepsEditor
	var line: Array = editor.call("fields_for", "line")
	var rows: Array = [
		["a circle", _keys(editor.call("fields_for", "circle")), "kind,x,p1,color"],
		["a ring", _keys(editor.call("fields_for", "ring")), "kind,x,p1,p2,color"],
		["a rectangle", _keys(editor.call("fields_for", "rect")), "kind,x,p1,p2,color,help_note"],
		["a line", _keys(line), "kind,x,p1,p2,p3,color,caps,scale_mode,dashed,dash_size,dash_spacing,dash_offset,dash_style"],
		["a cone", _keys(editor.call("fields_for", "cone")), "kind,x,p1,p2,p3,color"],
		["a stamp", _keys(editor.call("fields_for", "stamp")), "kind,x,texture,p1,p2,color,help_note"],
		["a line's names", _labels(line), "Shape,Offset,End X,End Y,Thickness,Colour,End caps,Follows scale,Dashed,Dash,Gap,Offset,Style"],
		["a ring's names", _labels(editor.call("fields_for", "ring")), "Shape,Offset,Radius,Thickness,Colour"],
		["a stamp's names", _labels(editor.call("fields_for", "stamp")), "Shape,Offset,Texture,Scale,Spin,Colour,"],
		["a cone's names", _labels(editor.call("fields_for", "cone")), "Shape,Offset,Facing,FOV,Radius,Colour"],
		["Shape comes first on every kind", str(editor.call("fields_for", "stamp")[0].get("key")), "kind"],
		["Offset is ONE row holding x and y", str(editor.call("fields_for", "line")[1].get("pair")), "y"],
		["no field sits under a section heading", _groups(line), ""],
		["only a line has a Line look fold", _folds(editor.call("fields_for", "circle")), ""],
		["and on a line it holds ends, the scale rule and the dashes", _folds(line), ",,,,,,Line look,Line look,Line look,Line look,Line look,Line look,Line look"],
		["a ring is not offered a scale rule", _keys(editor.call("fields_for", "ring")).contains("scale_mode"), false],
		["the scale rule is a tick over the stored words", str(_field(line, "scale_mode").get("drawer")), "tick_words:uniform,fixed"],
		["its tick says what it does", str(_field(line, "scale_mode").get("tick_text")), "grows with the stamp"],
		["the colour is a colour button", str(_field(line, "color").get("drawer")), "color_button"],
		["a stamp's texture is Godot's resource picker", str(_field(editor.call("fields_for", "stamp"), "texture").get("drawer")), "resource:Texture2D"],
		["a size says its unit as small plain text", str(_field(editor.call("fields_for", "circle"), "p1").get("suffix")), "px"],
		["an angle says degrees", str(_field(editor.call("fields_for", "cone"), "p2").get("suffix")), "°"],
		["a stamp's scale says x", str(_field(editor.call("fields_for", "stamp"), "p1").get("suffix")), "x"],
		["Thickness keeps its px / world / screen choice", str(_field(line, "p3").get("drawer")), "unit:kinds=px|world|screen,store=px"],
		["the Dashed tick redraws the card so the dash fields appear", bool(_field(line, "dashed").get("redraw", false)), true],
		["the Line look fold opens when a look key is not at its default", editor.call("fold_open_for", _step("line", {"caps": "round"}), "Line look"), true],
		["and stays shut for a plain line", editor.call("fold_open_for", _step("line", {}), "Line look"), false],
		["the card does not print its explanation above its fields", editor.call("build_schema").get("help_in_body"), false],
		["the shape names are the plain ones, the stored words are not", editor.call("build_schema").kinds[2].label, "Rectangle"],
		["Shape offers the stored words under plain names", str(editor.call("fields_for", "circle")[0].get("drawer")), "options:circle=Circle,ring=Ring,rect=Rectangle,line=Line,cone=Cone,stamp=Stamp"],
	]
	return SUPPORT.pins(PREFIX, rows)


static func _groups(fields: Array) -> String:
	var groups: PackedStringArray = PackedStringArray()
	for field: Variant in fields:
		groups.append(str((field as Dictionary).get("group", "")))
	return "".join(groups)


static func _folds(fields: Array) -> String:
	var folds: PackedStringArray = PackedStringArray()
	for field: Variant in fields:
		folds.append(str((field as Dictionary).get("fold", "")))
	return ",".join(folds) if not folds.is_empty() and "".join(folds) != "" else ""


static func _field(fields: Array, key: String) -> Dictionary:
	for field: Variant in fields:
		if str((field as Dictionary).get("key", "")) == key:
			return field
	return {}


## Every control the card builds writes the key it stands for. The offset row is one row of two boxes.
static func _pin_the_controls() -> bool:
	var editor: PREFAB_STEPS.ShapeStepsEditor = PREFAB_STEPS.ShapeStepsEditor.new()
	editor.set_steps([_step("line", {"scale_mode": "uniform", "caps": "none", "dashed": false})])
	editor.call("set_unfolded", 0, true)
	var spins: Array = _nodes_of(editor, "SpinBox", [])
	var rows: Array = []
	rows.append(["the offset is two boxes on one row", spins.size() >= 3 and (spins[0] as Node).get_parent() == (spins[1] as Node).get_parent(), true])
	_drive(spins[0] as SpinBox, 7.0)
	_drive(spins[1] as SpinBox, 8.0)
	_drive(spins[2] as SpinBox, 33.0)
	var now: Dictionary = editor.get_steps()[0]
	rows.append(["the first box writes x", float(now.get("x")), 7.0])
	rows.append(["the second writes y", float(now.get("y")), 8.0])
	rows.append(["the next is End X, stored as p1", float(now.get("p1")), 33.0])
	rows.append(["the others stay as they were", [float(now.get("p2")), float(now.get("p3"))], [20.0, 4.0]])
	var buttons: Array = _nodes_of(editor, "ColorPickerButton", [])
	rows.append(["the colour is one button", buttons.size(), 1])
	(buttons[0] as ColorPickerButton).color = Color("#00ff00")
	(buttons[0] as ColorPickerButton).color_changed.emit(Color("#00ff00"))
	rows.append(["a colour is stored as the text it always was", str(editor.get_steps()[0].get("color")), "#00ff00"])
	var checks: Array = _nodes_of(editor, "CheckBox", [])
	var tick: CheckBox = null
	for check: Variant in checks:
		if (check as CheckBox).text == "grows with the stamp":
			tick = check
	rows.append(["the scale rule is a tick", tick != null, true])
	rows.append(["it starts ticked for the stored word uniform", tick.button_pressed if tick != null else false, true])
	if tick != null:
		tick.button_pressed = false
	rows.append(["unticking writes the stored word fixed", str(editor.get_steps()[0].get("scale_mode")), "fixed"])
	if tick != null:
		tick.button_pressed = true
	rows.append(["ticking writes uniform again", str(editor.get_steps()[0].get("scale_mode")), "uniform"])
	# Changing the shape keeps p1, p2 and p3 under their new names.
	var before: Dictionary = editor.get_steps()[0]
	var choices: Array = _nodes_of(editor, "OptionButton", [])
	var shape: OptionButton = choices[0] as OptionButton
	shape.select(2)
	shape.item_selected.emit(2)
	var changed: Dictionary = editor.get_steps()[0]
	rows.append(["the shape drop-down writes the stored word", str(changed.get("kind")), "rect"])
	rows.append(["changing shape keeps p1, p2 and p3", [changed.get("p1"), changed.get("p2"), changed.get("p3")], [before.get("p1"), before.get("p2"), before.get("p3")]])
	rows.append(["and keeps the keys the new shape does not show", str(changed.get("caps")), "none"])
	editor.free()
	return SUPPORT.pins(PREFIX, rows)


static func _pin_the_texture_is_kept_as_text() -> bool:
	var picked: Resource = load("res://eventsheet_addons/drawing_prefab_stamp/icon.svg")
	var text: String = EventSheetCardSchemas.resource_reference(picked)
	var editor: PREFAB_STEPS.ShapeStepsEditor = PREFAB_STEPS.ShapeStepsEditor.new()
	editor.set_steps([_step("stamp", {"texture": "res://eventsheet_addons/drawing_prefab_stamp/icon.svg"})])
	var untouched: String = str(editor.get_steps()[0].get("texture"))
	editor.write_card_key(0, "p1", 2.0)
	var after_other_edit: String = str(editor.get_steps()[0].get("texture"))
	editor.free()
	var compiled: Array = DrawingPrefabResource.compile_steps([_step("stamp", {"texture": text})])
	return SUPPORT.pins(PREFIX, [
		["a picked file is kept as its uid text", text.begins_with("uid://"), true],
		["the stamp node loads uid text", compiled.size() == 1 and compiled[0].get("tex") != null, true],
		["an old typed path still loads as it was", untouched, "res://eventsheet_addons/drawing_prefab_stamp/icon.svg"],
		["and still saves as it was until it is changed", after_other_edit, "res://eventsheet_addons/drawing_prefab_stamp/icon.svg"],
	])


## What a hand on a number box does: the box shows the number and says it changed. (A box that is not in a
## scene tree does not announce a plain assignment.)
static func _drive(spin: SpinBox, value: float) -> void:
	spin.set_value_no_signal(value)
	spin.value_changed.emit(value)
