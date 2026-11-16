# Godot EventSheets - who draws a Drawing Prefab's steps, and what the card says about each shape.
#
# THE STEPS ARE DRAWN AS CARDS. Godot asks the Inspector plugin added LAST first, and the first one
# that claims a property draws it. The prefab's own plugin claims `steps` with the card editor; the
# generic attribute drawers claim it too, as a table, because the export carries a table marker. So
# the prefab's plugin has to be added AFTER the attribute drawers, or the table wins and the cards
# are never seen. The suite cannot open an Inspector, so the order is pinned where it is written.
#
# The rest pins two sentences the card says about shapes: a rectangle is drawn right and down from
# its offset (all three renderers draw it from that corner), and only a line is offered the rule
# for whether its thickness follows the scale, because only a line's renderer reads it.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const TEST_NAME := "drawing_prefab_steps_drawer_test"

const PLUGIN_PATH := "res://addons/eventforge/plugin.gd"
const STEPS_PROPERTY_PATH := "res://addons/eventsheet/editor/inspector/drawing_prefab_steps_property.gd"
const PREFAB_SCRIPT_PATH := "res://eventsheet_addons/drawing_prefab_resource/drawing_prefab_resource.gd"


static func run() -> bool:
	var ok: bool = true
	ok = _order_pins() and ok
	ok = _shape_word_pins() and ok
	ok = _read_only_pins() and ok
	return ok


## The prefab's plugin is added after the generic drawers, and the steps export still carries the
## table marker the generic drawers would otherwise draw it with.
static func _order_pins() -> bool:
	var source: String = FileAccess.get_file_as_string(PLUGIN_PATH)
	var prefab_at: int = source.find("add_inspector_plugin(_drawing_prefab_inspector)")
	var drawers_at: int = source.find("add_inspector_plugin(_attribute_drawers_plugin)")
	var steps_hint: String = ""
	for property: Dictionary in (load(PREFAB_SCRIPT_PATH) as Script).get_script_property_list():
		if str(property.get("name", "")) == "steps":
			steps_hint = str(property.get("hint_string", ""))
	return SUPPORT.pins(TEST_NAME, [
		["the prefab's plugin is registered", prefab_at >= 0, true],
		["the generic drawers are registered", drawers_at >= 0, true],
		["the prefab's plugin is added after the generic drawers, so Godot asks it first", prefab_at > drawers_at, true],
		["the steps export still carries the table marker, which is why the order matters",
			steps_hint.begins_with("eventsheet:table:"), true],
	])


static func _shape_word_pins() -> bool:
	var editor: GDScript = (load(STEPS_PROPERTY_PATH) as GDScript).get_script_constant_map().get("ShapeStepsEditor") as GDScript
	var help: Dictionary = editor.get_script_constant_map().get("SHAPE_HELP", {})
	var ring_keys: PackedStringArray = PackedStringArray()
	for field: Variant in editor.call("fields_for", "ring"):
		ring_keys.append(str((field as Dictionary).get("key", "")))
	var line_keys: PackedStringArray = PackedStringArray()
	for field: Variant in editor.call("fields_for", "line"):
		line_keys.append(str((field as Dictionary).get("key", "")))
	return SUPPORT.pins(TEST_NAME, [
		["a rectangle is not said to be centred", str(help.get("rect", "")).contains("centred"), false],
		["a rectangle is said to be drawn from its offset", str(help.get("rect", "")).contains("right and down from the offset"), true],
		["a ring is not offered the scale rule nothing reads", ring_keys.has("scale_mode"), false],
		["a line still is", line_keys.has("scale_mode"), true],
	])


## A locked prefab shows its cards but cannot be edited from them. An EditorProperty can only be built
## by the editor, so the suite reads where the lock is passed on (a drawer that is not editable
## disables every control, which the card drawer's own tests pin); the real editor run drives it.
static func _read_only_pins() -> bool:
	var prefab_source: String = FileAccess.get_file_as_string(STEPS_PROPERTY_PATH)
	var shared_source: String = FileAccess.get_file_as_string("res://addons/eventsheet/editor/attribute_drawers.gd")
	return SUPPORT.pins(TEST_NAME, [
		["the prefab's steps property passes the lock to its cards",
			prefab_source.contains("func _set_read_only(read_only: bool) -> void:
	_editor.set_editable(not read_only)"), true],
		["the shared card list property passes the lock to its list",
			shared_source.contains("func _set_read_only(read_only: bool) -> void:
		_list.call(\"set_editable\", not read_only)"), true],
	])
