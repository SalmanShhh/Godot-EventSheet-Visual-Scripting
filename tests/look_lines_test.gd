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
const NativeVariableMarks := preload("res://addons/eventsheet/editor/interaction/native_variable_marks.gd")
const P: String = "look_lines_test"
const VERIFY_PATH: String = "user://look_lines_test_verify.gd"

const PROGRESS_NEW: String = "# @inspector_look progress_bar\n@export_range(0, 200) var health: int = 120\n"
const PROGRESS_OLD: String = "@export_custom(PROPERTY_HINT_NONE, \"eventsheet:progress_bar:0:200\") var health: int = 120\n"
const PROGRESS_FLOAT_NEW: String = "# @inspector_look progress_bar\n@export_range(0, 100) var speed: float = 90.5\n"
const TOGGLE_STRING_NEW: String = "# @inspector_look toggle_row
@export_enum(\"easy\", \"normal\", \"hard\") var difficulty: String = \"normal\"
"
const TOGGLE_SEGMENTED_NEW: String = "# @inspector_look toggle_row:segmented
@export_enum(\"test\", \"through walls\") var depth: String = \"test\"
"
const TOGGLE_ICONS_NEW: String = "# @inspector_look toggle_row:icons=vector_shapes_dash
@export_enum(\"plain\", \"angled\", \"rounded\") var dash_style: String = \"plain\"
"
const TOGGLE_INT_NEW: String = "# @inspector_look toggle_row
@export_enum(\"a\", \"b\", \"c\") var idx: int = 0
"
const TOGGLE_STRING_OLD: String = "@export_custom(PROPERTY_HINT_NONE, \"eventsheet:toggle_row:test,through walls:segmented\") var depth: String = \"test\"
"
const TOGGLE_INT_OLD: String = "@export_custom(PROPERTY_HINT_NONE, \"eventsheet:toggle_row:a,b,c\") var idx: int = 0
"
const UNIT_NEW: String = "# @inspector_look unit:kinds=px|world|screen,store=px
@export_range(0, 1, 0.001, \"or_greater\", \"or_less\", \"hide_slider\", \"suffix:px\") var thickness: float = 2.0
"
const UNIT_ANGLE_NEW: String = "# @inspector_look unit:kinds=deg|turn|rad,store=deg
@export_range(0, 1, 0.001, \"or_greater\", \"or_less\", \"hide_slider\", \"suffix:deg\") var start_angle: float = 0.0
"
const UNIT_OLD: String = "@export_custom(PROPERTY_HINT_NONE, \"eventsheet:unit:kinds=px|world|screen,store=px\") var thickness: float = 2.0
"
const HIDDEN_UNIT_PROPERTY: String = "# @inspector_look unit:kinds=px|world|screen,store=px
@export_group(\"Stroke\")
## Stroke width.
## @ace_hidden
@export_range(0, 1, 0.001, \"or_greater\", \"or_less\", \"hide_slider\", \"suffix:px\") var thickness: float = 2.0:
	set(value):
		thickness = value
		queue_redraw()
"
const HIDDEN_TOGGLE_PROPERTY: String = "# @inspector_look toggle_row:segmented
## What the ends look like.
## @ace_hidden
@export_enum(\"none\", \"square\", \"round\") var caps: String = \"round\":
	set(value):
		caps = value
"
const HIDDEN_PROGRESS: String = "# @inspector_look progress_bar
## Hit points.
## @ace_hidden
@export_range(0, 200) var health: int = 120
"
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

	# --- Toggle buttons: Godot's dropdown line, the look on the comment. ---
	ok = _eq("a text toggle row writes Godot's enum and the look comment",
		_emit("String", "normal", {"drawer": "toggle_row", "look_line": true, "toggle_options": ["easy", "normal", "hard"]}),
		"# @inspector_look toggle_row
@export_enum(\"easy\", \"normal\", \"hard\") var health: String = \"normal\"") and ok
	ok = _eq("the segmented and icon tails ride the comment",
		_emit("String", "round", {"drawer": "toggle_row", "look_line": true, "toggle_options": ["none", "round"], "toggle_segmented": true, "toggle_icons": "res://icons/%s.svg"}),
		"# @inspector_look toggle_row:segmented:icons=res://icons/%s.svg
@export_enum(\"none\", \"round\") var health: String = \"round\"") and ok
	ok = _eq("an int toggle row writes Godot's int enum, the stored number unchanged",
		_emit("int", 1, {"drawer": "toggle_row", "look_line": true, "toggle_options": ["a", "b", "c"]}),
		"# @inspector_look toggle_row
@export_enum(\"a\", \"b\", \"c\") var health: int = 1") and ok
	ok = _eq("the old toggle attributes (no flag) still write the marker",
		_emit("String", "normal", {"drawer": "toggle_row", "toggle_options": ["easy", "normal"]}),
		"@export_custom(PROPERTY_HINT_NONE, \"eventsheet:toggle_row:easy,normal\") var health: String = \"normal\"") and ok
	ok = _eq("a choice that cannot ride the enum writes neither line nor comment",
		_emit("String", "a", {"drawer": "toggle_row", "look_line": true, "toggle_options": ["a:b"]}), "@export var health: String = \"a\"") and ok
	for toggle_fixture: String in [TOGGLE_STRING_NEW, TOGGLE_SEGMENTED_NEW, TOGGLE_ICONS_NEW, TOGGLE_INT_NEW, TOGGLE_STRING_OLD, TOGGLE_INT_OLD]:
		var toggle_variable: LocalVariable = _first_variable(SUPPORT.reopen("extends Node

" + toggle_fixture, true))
		var is_new: bool = toggle_fixture.begins_with("# @inspector_look")
		ok = _eq("reads as toggle buttons: %s" % toggle_fixture.get_slice("
", 0), str(toggle_variable.attributes.get("drawer", "")) if toggle_variable != null else "none", "toggle_row") and ok
		ok = _eq("keeps its spelling: %s" % toggle_fixture.get_slice("
", 0),
			bool(toggle_variable.attributes.get("look_line", false)) if toggle_variable != null else false, is_new) and ok
		ok = _eq("its choices are the toggle options, not a combo: %s" % toggle_fixture.get_slice("
", 0),
			(toggle_variable.options.size() if toggle_variable != null else -1), 0) and ok
		ok = _eq("re-emits byte for byte: %s" % toggle_fixture.get_slice("
", 0),
			SUPPORT.reemit("extends Node

" + toggle_fixture, VERIFY_PATH), "extends Node

" + toggle_fixture) and ok
	ok = _eq("a plain @export_enum with no comment stays a combo, byte for byte",
		SUPPORT.reemit("extends Node

@export_enum(\"a\", \"b\") var mode: String = \"a\"
", VERIFY_PATH),
		"extends Node

@export_enum(\"a\", \"b\") var mode: String = \"a\"
") and ok
	ok = _eq("an int enum with numbers cannot be toggle buttons: the comment stays a comment",
		SUPPORT.reemit("extends Node

# @inspector_look toggle_row
@export_enum(\"Slow:30\", \"Fast:60\") var rate: int = 30
", VERIFY_PATH),
		"extends Node

# @inspector_look toggle_row
@export_enum(\"Slow:30\", \"Fast:60\") var rate: int = 30
") and ok
	ok = _eq("an enum hint rebuilds the toggle row marker",
		EventForgeLookLines.marker_for("toggle_row:segmented", PROPERTY_HINT_ENUM, "none,square,round"), "eventsheet:toggle_row:none,square,round:segmented") and ok
	ok = _eq("an int enum's numbered hint is read as its words",
		EventForgeLookLines.marker_for("toggle_row", PROPERTY_HINT_ENUM, "a:0,b:1,c:2"), "eventsheet:toggle_row:a,b,c") and ok
	ok = _eq("the toggle row hover names the Godot line",
		EventSheetInspectorLookCatalogue.entry("toggle_row").get("writes", ""), "@export_enum(\"easy\", \"normal\", \"hard\") + # @inspector_look toggle_row") and ok
	ok = _eq("a new toggle row pick through the Variable window carries the flag",
		bool(EventSheetInspectorLooks.fold("toggle_row", {"choices": "a, b"}, "String").get("look_line", false)), true) and ok

	# --- Unit numbers: Godot's range with the stored unit as its suffix, the look on the comment. ---
	var unit_range: String = "@export_range(0, 1, 0.001, \"or_greater\", \"or_less\", \"hide_slider\", \"suffix:px\")"
	ok = _eq("a unit number writes Godot's suffixed range and the look comment",
		_emit("float", 2.0, {"drawer": "unit", "look_line": true, "unit_kinds": ["px", "world", "screen"], "unit_store": "px"}),
		"# @inspector_look unit:kinds=px|world|screen,store=px
%s var health: float = 2.0" % unit_range) and ok
	ok = _eq("the stored unit that is not the first reads as the suffix",
		_emit("float", 90.0, {"drawer": "unit", "look_line": true, "unit_kinds": ["deg", "turn", "rad"], "unit_store": "rad"}),
		"# @inspector_look unit:kinds=deg|turn|rad,store=rad
@export_range(0, 1, 0.001, \"or_greater\", \"or_less\", \"hide_slider\", \"suffix:rad\") var health: float = 90.0") and ok
	ok = _eq("the old unit attributes (no flag) still write the marker",
		_emit("float", 2.0, {"drawer": "unit", "unit_kinds": ["px", "world"], "unit_store": "px"}),
		"@export_custom(PROPERTY_HINT_NONE, \"eventsheet:unit:kinds=px|world,store=px\") var health: float = 2.0") and ok
	ok = _eq("a unit on a whole number writes neither line nor comment",
		_emit("int", 2, {"drawer": "unit", "look_line": true, "unit_kinds": ["px"]}), "@export var health: int = 2") and ok
	for unit_fixture: String in [UNIT_NEW, UNIT_ANGLE_NEW, UNIT_OLD]:
		var unit_variable: LocalVariable = _first_variable(SUPPORT.reopen("extends Node

" + unit_fixture, true))
		var unit_is_new: bool = unit_fixture.begins_with("# @inspector_look")
		ok = _eq("reads as a unit number: %s" % unit_fixture.get_slice("
", 0), str(unit_variable.attributes.get("drawer", "")) if unit_variable != null else "none", "unit") and ok
		ok = _eq("keeps its spelling: %s" % unit_fixture.get_slice("
", 0),
			bool(unit_variable.attributes.get("look_line", false)) if unit_variable != null else false, unit_is_new) and ok
		ok = _eq("re-emits byte for byte: %s" % unit_fixture.get_slice("
", 0),
			SUPPORT.reemit("extends Node

" + unit_fixture, VERIFY_PATH), "extends Node

" + unit_fixture) and ok
	ok = _eq("a range that is not the unit's own keeps its comment as a comment, byte for byte",
		SUPPORT.reemit("extends Node

# @inspector_look unit:kinds=px|world,store=px
@export_range(0, 10, 0.5, \"suffix:px\") var width: float = 2.0
", VERIFY_PATH),
		"extends Node

# @inspector_look unit:kinds=px|world,store=px
@export_range(0, 10, 0.5, \"suffix:px\") var width: float = 2.0
") and ok
	ok = _eq("the unit marker is the comment body, whole",
		EventForgeLookLines.marker_for("unit:kinds=px|world|screen,store=px", PROPERTY_HINT_RANGE, "0,1,0.001,or_greater,or_less,hide_slider,suffix:px"), "eventsheet:unit:kinds=px|world|screen,store=px") and ok
	ok = _eq("the unit hover names the Godot line",
		EventSheetInspectorLookCatalogue.entry("unit").get("writes", ""), unit_range + " + # @inspector_look unit:kinds=px|world|screen,store=px") and ok
	ok = _eq("a new unit pick through the Variable window carries the flag",
		bool(EventSheetInspectorLooks.fold("unit", {"units": "px|world, store=px"}, "float").get("look_line", false)), true) and ok

	# --- A hidden field in a pack: the group, the doc and `## @ace_hidden` sit between the comment and the declaration, and the
	# declaration may be a property with a setter. The look is still read, and the whole block still writes back. ---
	for pack_fixture: String in [HIDDEN_UNIT_PROPERTY, HIDDEN_TOGGLE_PROPERTY, HIDDEN_PROGRESS]:
		var pack_variable: LocalVariable = _first_variable(SUPPORT.reopen("extends Node

" + pack_fixture, true))
		ok = _eq("a hidden pack field keeps its look: %s" % pack_fixture.get_slice("
", 0),
			[str(pack_variable.attributes.get("drawer", "")) if pack_variable != null else "none", bool(pack_variable.attributes.get("look_line", false)) if pack_variable != null else false],
			[pack_fixture.get_slice("
", 0).get_slice(" ", 2).get_slice(":", 0), true]) and ok
		ok = _eq("...and writes back byte for byte: %s" % pack_fixture.get_slice("
", 0),
			SUPPORT.reemit("extends Node

" + pack_fixture, VERIFY_PATH), "extends Node

" + pack_fixture) and ok
	ok = _eq("a hidden field with no look comment is read exactly as before: its doc stays a code row",
		SUPPORT.reemit("extends Node

@export_group(\"Stroke\")
## Width.
## @ace_hidden
@export var width: float = 1.0
", VERIFY_PATH),
		"extends Node

@export_group(\"Stroke\")
## Width.
## @ace_hidden
@export var width: float = 1.0
") and ok

	# --- The row mark: a variable written the Godot way wears the same mark as the old marker line. ---
	var mark_pairs: Array = [
		[PROGRESS_NEW, PROGRESS_OLD, "int", 120],
		[TOGGLE_SEGMENTED_NEW, TOGGLE_STRING_OLD, "String", "test"],
		[UNIT_NEW, UNIT_OLD, "float", 2.0]]
	for pair: Array in mark_pairs:
		var new_mark: Dictionary = NativeVariableMarks.inspector_mark(_first_variable(SUPPORT.reopen("extends Node

" + str(pair[0]), true)), str(pair[2]), pair[3])
		var old_mark: Dictionary = NativeVariableMarks.inspector_mark(_first_variable(SUPPORT.reopen("extends Node

" + str(pair[1]), true)), str(pair[2]), pair[3])
		ok = _eq("the mark of %s is the old line's mark" % str(pair[0]).get_slice("
", 0), new_mark, old_mark) and ok
		ok = _eq("...and it names a look: %s" % str(pair[0]).get_slice("
", 0), str(new_mark.get("look_id", "")).is_empty(), false) and ok

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
