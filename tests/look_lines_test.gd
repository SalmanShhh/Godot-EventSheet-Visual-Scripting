# Godot EventSheets - the looks that keep Godot's own export line.
#
# A progress bar, a row of toggle buttons and a unit number are written as Godot's own `@export_range` /
# `@export_enum` line plus a `# @inspector_look` comment, so without the plugin the variable shows Godot's
# control with the same limits. This pins: what the compiler writes for each, that the new file reopens as
# the same look and re-emits byte for byte, that the OLD `@export_custom` marker still reopens as the
# marker spelling and re-emits byte for byte, and what the drawers' marker rebuild answers for each
# Godot hint. Every fixture is a file's text, so the annotations are read the way a script on disk is.
@tool
class_name LookLinesTest
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")
const P: String = "look_lines_test"
const VERIFY_PATH: String = "user://look_lines_test_verify.gd"

const PROGRESS_NEW: String = "# @inspector_look progress_bar\n@export_range(0, 200) var health: int = 120\n"
const PROGRESS_OLD: String = "@export_custom(PROPERTY_HINT_NONE, \"eventsheet:progress_bar:0:200\") var health: int = 120\n"
const PROGRESS_FLOAT_NEW: String = "# @inspector_look progress_bar\n@export_range(0, 100) var speed: float = 90.5\n"
const PROGRESS_GROUPED_NEW: String = "# @inspector_look progress_bar\n@export_group(\"Vitals\")\n## Hit points - drag the bar.\n@export_range(0, 200) var health: int = 120\n"


static func run() -> bool:
	var ok: bool = true

	# --- Writer: a new pick writes Godot's line and the comment. ---
	ok = _eq("progress_bar writes Godot's range and the look comment",
		_emit("int", 120, {"drawer": "progress_bar", "look_line": true, "range": {"min": "0", "max": "200", "step": "1"}}),
		"# @inspector_look progress_bar\n@export_range(0, 200) var health: int = 120") and ok
	ok = _eq("a float bar keeps Godot's own step (none written)",
		_emit("float", 90.5, {"drawer": "progress_bar", "look_line": true, "range": {"min": "0", "max": "100"}}),
		"# @inspector_look progress_bar\n@export_range(0, 100) var health: float = 90.5") and ok
	ok = _eq("a step the file wrote is kept",
		_emit("float", 1.0, {"drawer": "progress_bar", "look_line": true, "range": {"min": "0", "max": "10", "step": "0.5"}}),
		"# @inspector_look progress_bar\n@export_range(0, 10, 0.5) var health: float = 1.0") and ok
	ok = _eq("the old attributes (no flag) still write the marker",
		_emit("int", 120, {"drawer": "progress_bar", "range": {"min": "0", "max": "200"}}),
		"@export_custom(PROPERTY_HINT_NONE, \"eventsheet:progress_bar:0:200\") var health: int = 120") and ok
	ok = _eq("a bar on a type that cannot hold it writes neither line nor comment",
		_emit("String", "x", {"drawer": "progress_bar", "look_line": true}), "@export var health: String = \"x\"") and ok

	# --- Reader: both spellings reopen as the look and re-emit untouched. ---
	for fixture: String in [PROGRESS_NEW, PROGRESS_FLOAT_NEW, PROGRESS_GROUPED_NEW, PROGRESS_OLD]:
		var sheet: EventSheetResource = SUPPORT.reopen("extends Node\n\n" + fixture, true)
		var variable: LocalVariable = _first_variable(sheet)
		ok = _eq("reads as a progress bar: %s" % fixture.get_slice("\n", 0), str(variable.attributes.get("drawer", "")) if variable != null else "none", "progress_bar") and ok
		ok = _eq("keeps its spelling: %s" % fixture.get_slice("\n", 0),
			bool(variable.attributes.get("look_line", false)) if variable != null else false, fixture.begins_with("# @inspector_look")) and ok
		ok = _eq("re-emits byte for byte: %s" % fixture.get_slice("\n", 0),
			SUPPORT.reemit("extends Node\n\n" + fixture, VERIFY_PATH), "extends Node\n\n" + fixture) and ok
	ok = _eq("a look comment on a variable that cannot wear it stays a comment, byte for byte",
		SUPPORT.reemit("extends Node\n\n# @inspector_look progress_bar\n@export var label: String = \"x\"\n", VERIFY_PATH),
		"extends Node\n\n# @inspector_look progress_bar\n@export var label: String = \"x\"\n") and ok

	# --- The drawers' marker rebuild: Godot's hint plus the comment body. ---
	ok = _eq("a range hint rebuilds the progress bar marker",
		EventForgeLookLines.marker_for("progress_bar", PROPERTY_HINT_RANGE, "0,200,1"), "eventsheet:progress_bar:0:200") and ok
	ok = _eq("a hint of another kind rebuilds nothing",
		EventForgeLookLines.marker_for("progress_bar", PROPERTY_HINT_ENUM, "a,b"), "") and ok
	ok = _eq("a word that is not one of these rebuilds nothing",
		EventForgeLookLines.marker_for("swatch_row", PROPERTY_HINT_RANGE, "0,1"), "") and ok

	# --- The Variable window's hover names the Godot line. ---
	ok = _eq("the hover says the Godot line, not the marker",
		EventSheetInspectorLookCatalogue.entry("progress_bar").get("writes", ""), "@export_range(0, 100) + # @inspector_look progress_bar") and ok
	ok = _eq("a new pick through the Variable window's fold carries the flag",
		bool(EventSheetInspectorLooks.fold("progress_bar", {"min": "0", "max": "50", "step": "1"}, "int").get("look_line", false)), true) and ok
	return ok


static func _first_variable(sheet: EventSheetResource) -> LocalVariable:
	if sheet == null:
		return null
	for row: Variant in sheet.events:
		if row is LocalVariable:
			return row as LocalVariable
	return null


static func _emit(type_name: String, default_value: Variant, attributes: Dictionary) -> String:
	var variable: LocalVariable = LocalVariable.new()
	variable.name = "health"
	variable.type_name = type_name
	variable.default_value = default_value
	variable.exported = true
	variable.attributes = attributes
	return EventSheetCompiler._emit_tree_variable_line(variable)


static func _eq(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check(P, label, actual, expected)
