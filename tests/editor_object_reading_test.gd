@tool
class_name EditorObjectReadingTest
extends RefCounted

# Pins the Editor object (R30 / R31 / R34) - the reading an opened @tool script gets when what it
# talks to is the EDITOR rather than the game.
#
# Four gates, in the order they matter:
#   1. an opened EditorPlugin reads with an Editor object - On plugin enabled / disabled instead of
#      the "on created" a plugin never meant, the menu / dock / object-type actions one per row, and
#      the 2D overlay pass as a trigger with the Drawing actions under it;
#   2. an opened EditorScript reads the same way, and its selection loop reads as the sheet's own
#      For each over Editor.SelectedObjects;
#   3. the undo history is a local OBJECT variable and every step is an action on it;
#   4. the promise all of it rests on - the file still saves byte-identically.
#
# The sources live here as strings rather than in tests/fixtures/ because the lifter's byte gate
# compares against what the COMPILER would emit, and the compiler puts ONE blank line between
# functions, so a checked-in two-blank-line file could never lift and the fixture would test nothing.

const PLUGIN_PATH := "user://eventforge_editor_object_plugin.gd"
const SCRIPT_PATH := "user://eventforge_editor_object_script.gd"

const PLUGIN_SOURCE: String = """@tool
extends EditorPlugin

var dock: Control = null

func _enter_tree() -> void:
	add_tool_menu_item("Snap Selection", _snap)
	add_control_to_dock(EditorPlugin.DOCK_SLOT_LEFT_UL, dock)
	add_custom_type("Waypoint", "Node2D", null, null)

func _exit_tree() -> void:
	remove_tool_menu_item("Snap Selection")

func _forward_canvas_draw_over_viewport(overlay: Control) -> void:
	overlay.draw_circle(Vector2.ZERO, 6, Color.YELLOW)

func _align_left() -> void:
	var ur = get_undo_redo()
	ur.create_action("Align Left")
	ur.add_do_property(dock, "position:x", 0)
	ur.add_undo_property(dock, "position:x", dock.position.x)
	ur.add_do_method(self, "_refresh")
	ur.commit_action()
"""

const SCRIPT_SOURCE: String = """@tool
extends EditorScript

func _run() -> void:
	for n in EditorInterface.get_selection().get_selected_nodes():
		n.position = n.position.snapped(Vector2(8, 8))
"""

## What the opened plugin must say, in the sheet's own words.
const EXPECTED_PLUGIN: Array[String] = [
	"Editor ▸ On Plugin Enabled",
	"Editor ▸ Add Tools menu item \"Snap Selection\"",
	"Editor ▸ Add dock dock at left, top",
	"Editor ▸ Add object type \"Waypoint\"",
	"Editor ▸ On Plugin Disabled",
	"Editor ▸ Remove Tools menu item \"Snap Selection\"",
	"Editor ▸ On Draw Over 2D Viewport",
	"overlay ▸ Draw circle at (0, 0), radius 6, yellow",
	"ur ▸ Begin undoable action \"Align Left\"",
	"ur ▸ Add do step: set dock's x to 0",
	"ur ▸ Add do step: call Refresh",
	"ur ▸ Commit undoable action"
]

## And what the opened editor script must say - the trigger and the loop, stacked in one event, with
## the selection named as the Editor expression it is rather than as the engine call behind it.
const EXPECTED_SCRIPT: Array[String] = [
	"Editor ▸ On Editor Run",
	"System ▸ For each n in Editor.SelectedObjects"
]


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _plugin_reads_with_the_editor_object() and all_passed
	all_passed = _script_reads_with_the_editor_object() and all_passed
	all_passed = _undo_history_is_an_object_variable() and all_passed
	all_passed = _triggers_resolve_to_the_editor_callbacks() and all_passed
	all_passed = _round_trips_byte_for_byte() and all_passed
	return all_passed


static func _plugin_reads_with_the_editor_object() -> bool:
	var ok: bool = true
	var readings: PackedStringArray = _render(_import(PLUGIN_PATH, PLUGIN_SOURCE))
	for expected: String in EXPECTED_PLUGIN:
		ok = _check("the opened plugin reads \"%s\"" % expected, readings.has(expected), true) and ok
	# The rename is the whole point of R30: a plugin's `_enter_tree` is not "on created".
	ok = _check("a plugin's _enter_tree no longer reads as On Enter Tree",
		readings.has("Editor ▸ On Enter Tree"), false) and ok
	return ok


static func _script_reads_with_the_editor_object() -> bool:
	var ok: bool = true
	var joined: String = "\n".join(_render(_import(SCRIPT_PATH, SCRIPT_SOURCE)))
	for expected: String in EXPECTED_SCRIPT:
		ok = _check("the opened editor script reads \"%s\"" % expected, joined.contains(expected), true) and ok
	return ok


## R31. The declaration row says what `ur` IS, so a reader can tell it is something to call actions on.
static func _undo_history_is_an_object_variable() -> bool:
	var ok: bool = true
	var declaration: Dictionary = EventSheetSentence.statement("var ur = get_undo_redo()")
	ok = _check("the undo history declares as an object", str(declaration.get("type_word", "")), "object") and ok
	ok = _check("the undo history reads as the editor's own", str(declaration.get("value", "")), "Editor.UndoHistory") and ok
	var undo_step: Dictionary = EventSheetSentence.statement("ur.add_undo_property(n, \"position:x\", left)")
	ok = _check("an undo step belongs to the variable", str(undo_step.get("object", "")), "ur") and ok
	ok = _check("an undo step says what it restores", _text_of(undo_step),
		"Add undo step: set n's x to left") and ok
	return ok


## R30 / R34. Every new trigger resolves to the editor callback it names, with the return type Godot
## declares for it - the viewport-input hook ANSWERS, and a `-> void` there would not compile.
static func _triggers_resolve_to_the_editor_callbacks() -> bool:
	var ok: bool = true
	for pair: Array in [
		["OnPluginEnabled", "_enter_tree"], ["OnPluginDisabled", "_exit_tree"],
		["OnEditorObjectSelected", "_edit"], ["OnDrawOver2DViewport", "_forward_canvas_draw_over_viewport"],
		["On2DViewportInput", "_forward_canvas_gui_input"], ["OnDrawGizmo", "_redraw"]
	]:
		var event: EventRow = EventRow.new()
		event.trigger_provider_id = "Core"
		event.trigger_id = str(pair[0])
		var resolved: Dictionary = TriggerResolver.resolve_trigger(event)
		ok = _check("%s compiles to %s" % [pair[0], pair[1]], str(resolved.get("function_name", "")), str(pair[1])) and ok
	var input_event: EventRow = EventRow.new()
	input_event.trigger_provider_id = "Core"
	input_event.trigger_id = "On2DViewportInput"
	ok = _check("the viewport-input hook answers a bool",
		str(TriggerResolver.resolve_trigger(input_event).get("return_type", "")), "bool") and ok
	var enabled_event: EventRow = EventRow.new()
	enabled_event.trigger_provider_id = "Core"
	enabled_event.trigger_id = "OnPluginEnabled"
	ok = _check("every other callback still answers nothing",
		str(TriggerResolver.resolve_trigger(enabled_event).get("return_type", "")), "void") and ok
	return ok


## A reading may never cost a byte: opening either file and saving it untouched reproduces it exactly.
static func _round_trips_byte_for_byte() -> bool:
	var ok: bool = true
	for pair: Array in [[PLUGIN_PATH, PLUGIN_SOURCE], [SCRIPT_PATH, SCRIPT_SOURCE]]:
		var sheet: EventSheetResource = _import(str(pair[0]), str(pair[1]))
		var output: String = str(SheetCompiler.compile(sheet, str(pair[0])).get("output", ""))
		ok = _check("opening %s and saving it reproduces every byte" % str(pair[0]).get_file(),
			output, str(pair[1])) and ok
	return ok


static func _import(path: String, source: String) -> EventSheetResource:
	var handle: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	handle.store_string(source)
	handle.close()
	return GDScriptImporter.new().import_external(path)


## The plain text of a sentence reading, its segments joined the way the canvas draws them.
static func _text_of(reading: Dictionary) -> String:
	var text: String = ""
	for segment: Variant in reading.get("segments", []):
		text += str((segment as Dictionary).get("text", ""))
	return text


## The readings of one sheet, straight off the canvas's own spans.
static func _render(sheet: EventSheetResource) -> PackedStringArray:
	sheet.read_only = true
	var style: EventSheetEditorStyle = EventSheetEditorStyle.new()
	style.ensure_defaults()
	sheet.editor_style = style
	var viewport: EventSheetViewport = EventSheetViewport.new()
	viewport.set_ace_registry(EventSheetACERegistry.new())
	viewport.set_sheet(sheet)
	viewport.set_reading_mode(true)
	var readings: PackedStringArray = PackedStringArray()
	for row_data: EventRowData in _walk(viewport._root_rows, viewport):
		for span: SemanticSpan in row_data.spans:
			var label: String = str(span.metadata.get("object_label", ""))
			var text: String = span.text.strip_edges()
			readings.append("%s ▸ %s" % [label, text] if not label.is_empty() else text)
	viewport.free()
	return readings


## Every row in the tree, parents before children.
static func _walk(rows: Array, viewport: EventSheetViewport) -> Array:
	var found: Array = []
	for row_data: EventRowData in rows:
		viewport._row_builder._ensure_event_spans(row_data)
		found.append(row_data)
		found.append_array(_walk(row_data.children, viewport))
	return found


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] editor object: %s" % label)
		return true
	print("[FAIL] editor object: %s - expected %s, got %s" % [label, str(expected), str(actual)])
	return false
