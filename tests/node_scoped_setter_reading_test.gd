# EventForge - A setter that names the node it sets reads on THAT node. `n.position =
# n.position.snapped(Vector2(8, 8))` inside a For each is `n ▸ Set position to position snapped to
# 8, 8`: the object column says whose position it is, the value drops the receiver it would only be
# repeating, and `snapped` reads as the grid it pulls the value onto - the same words the
# free-function spelling `snapped(x, 8)` already reads.
#
# Display only: every shape here still recompiles byte-identically.
@tool
class_name NodeScopedSetterReadingTest
extends RefCounted

const EDITOR_SCRIPT := "@tool\nextends EditorScript\n\n\nfunc _run() -> void:\n\tfor n in EditorInterface.get_selection().get_selected_nodes():\n\t\tn.position = n.position.snapped(Vector2(8, 8))\n"
const LOOP := "extends Node2D\n\n\nfunc _ready() -> void:\n\tfor n in get_children():\n\t\tn.position = n.position.snapped(Vector2(8, 8))\n"
const OWN := "extends Node2D\n\n\nfunc _ready() -> void:\n\tposition = position.snapped(Vector2(8, 8))\n"
const PLAIN := "extends Node2D\n\n\nfunc _ready() -> void:\n\tposition = Vector2(100, 200)\n"
const OTHER := "extends Node2D\n\n\nfunc _ready() -> void:\n\tfor n in get_children():\n\t\tn.position = other.position\n"


static func run() -> bool:
	var ok: bool = true
	ok = _check("an editor tool's snap-the-selection line reads on the loop's own object",
		_action(EDITOR_SCRIPT), "n | Set position to position snapped to 8, 8") and ok
	ok = _check("the same line in a plain loop reads the same",
		_action(LOOP), "n | Set position to position snapped to 8, 8") and ok
	ok = _check("the script's own position keeps the script's object",
		_action(OWN), "Node2D | Set position to position snapped to 8, 8") and ok
	ok = _check("a plain place setter is unchanged",
		_action(PLAIN), "Node2D | Set position to (100, 200)") and ok
	# The receiver only comes off when the value REPEATS the target's own: a value reaching through
	# another object keeps every word of it, because that is what the line does.
	ok = _check("a value from another object keeps its receiver",
		_action(OTHER), "n | Set position to other.position") and ok
	for entry: Array in [
		["the editor tool", EDITOR_SCRIPT], ["the plain loop", LOOP], ["the own-position line", OWN],
		["the plain setter", PLAIN], ["the other-object value", OTHER]
	]:
		ok = _check("%s round-trips byte-identically" % str(entry[0]),
			_roundtrip(str(entry[1])), str(entry[1])) and ok
	return ok


## The sheet's first action row as `<object> | <words>`.
static func _action(source: String) -> String:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external_source(source)
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(sheet)
	var found: String = "<none>"
	for entry: Dictionary in dock._active_view().get_flat_rows():
		var row: EventRowData = entry.get("row")
		if row == null:
			continue
		for span: SemanticSpan in row.spans:
			if not (span.metadata is Dictionary):
				continue
			var metadata: Dictionary = span.metadata as Dictionary
			if str(metadata.get("lane", "")) != "action" or str(metadata.get("kind", "")) == "add_action":
				continue
			found = "%s | %s" % [str(metadata.get("object_label", "")), str(span.text)]
			break
		if found != "<none>":
			break
	dock.free()
	return found


static func _roundtrip(source: String) -> String:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external_source(source)
	sheet.external_source_path = "user://eventforge_node_scoped_setter.gd"
	return str(SheetCompiler.compile(sheet, "user://eventforge_node_scoped_setter.gd").get("output", ""))


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] node_scoped_setter_reading_test: %s" % label)
		return true
	print("[FAIL] node_scoped_setter_reading_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
