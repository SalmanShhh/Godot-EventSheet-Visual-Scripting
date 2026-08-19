# EventForge - R32. An Inspector button is the smallest editor tool there is - one line - and it now
# reads as one row: `button Bake  in the Inspector · calls Bake`. Until this it opened as a Script
# block, because the structured export lift did not know `@export_tool_button` and the generic hinted
# emission (`var bake: Variant = _bake`) could never reproduce a line that annotates no type.
#
# Three things are pinned here:
#   1. The lift, byte-gated: both the one-argument and the two-argument spelling re-emit exactly.
#   2. The reading: the button's own LABEL leads the row, the type chip says "button", the value is
#      gone (there is nothing to tune) and the note says where it lives and what it calls.
#   3. Add Inspector Button writes the line AND the empty function it calls, in one step.
@tool
class_name InspectorButtonSettingTest
extends RefCounted

const TWO_ARGUMENTS := "@tool\nclass_name BakerTwo\nextends Node\n\n@export_tool_button(\"Bake\", \"Bake\") var bake = _bake\n\n\nfunc _bake() -> void:\n\tpass\n"
const ONE_ARGUMENT := "@tool\nclass_name BakerOne\nextends Node\n\n@export_tool_button(\"Rebuild\") var rebuild = _rebuild\n\n\nfunc _rebuild() -> void:\n\tpass\n"
const PROBE_PATH := "user://eventforge_inspector_button_probe.gd"


static func run() -> bool:
	var ok: bool = true
	ok = _check("a two-argument Inspector button reads as a button setting",
		_setting_row(TWO_ARGUMENTS),
		"Instance button | Bake | Inspector | in the Inspector · calls Bake") and ok
	ok = _check("a one-argument one reads the same way",
		_setting_row(ONE_ARGUMENT),
		"Instance button | Rebuild | Inspector | in the Inspector · calls Rebuild") and ok
	ok = _check("the two-argument line round-trips byte-identically",
		_roundtrip(TWO_ARGUMENTS), TWO_ARGUMENTS) and ok
	ok = _check("the one-argument line round-trips byte-identically",
		_roundtrip(ONE_ARGUMENT), ONE_ARGUMENT) and ok
	ok = _check("Add Inspector Button writes the line and the function it calls",
		_added_button(), "@export_tool_button(\"Bake\") var _btn_bake: Callable = bake") and ok
	return ok


## The first variable row of the opened script's head, as `<chip> | <name> | … ` - the shape a reader
## sees in the Instance variables folder.
static func _setting_row(source: String) -> String:
	var sheet: EventSheetResource = _imported(source)
	sheet.read_only = true
	var view: EventSheetViewport = EventSheetViewport.new()
	view.set_ace_registry(EventSheetACERegistry.new())
	var style: EventSheetEditorStyle = EventSheetEditorStyle.new()
	style.ensure_defaults()
	sheet.editor_style = style
	view.set_sheet(sheet)
	view.set_reading_mode(true)
	# The settings folder is CLOSED on a preview, so the flat list stops at the bar - the rows are
	# its children, which is where the reading lives.
	var found: String = "<none>"
	for entry: Dictionary in view.get_flat_rows():
		found = _first_variable_row(entry.get("row"))
		if found != "<none>":
			break
	view.free()
	return found


static func _first_variable_row(row: EventRowData) -> String:
	if row == null:
		return "<none>"
	if row.row_uid.begins_with("variable_reading_"):
		var parts: PackedStringArray = PackedStringArray()
		for span: SemanticSpan in row.spans:
			parts.append(str(span.text))
		return " | ".join(parts)
	for child: EventRowData in row.children:
		var nested: String = _first_variable_row(child)
		if nested != "<none>":
			return nested
	return "<none>"


## The sheet the plugin's own Add Inspector Button command writes, as the one line it adds.
static func _added_button() -> String:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.tool_mode = true
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(sheet)
	dock.add_inspector_button("Bake")
	var emitted: String = str(SheetCompiler.compile(dock._current_sheet, PROBE_PATH).get("output", ""))
	var functions: int = dock._current_sheet.functions.size()
	dock.free()
	if functions != 1:
		return "<no function was written>"
	for line: String in emitted.split("\n"):
		if line.begins_with("@export_tool_button("):
			return line
	return "<no button line was written>"


static func _imported(source: String) -> EventSheetResource:
	var file: FileAccess = FileAccess.open(PROBE_PATH, FileAccess.WRITE)
	file.store_string(source)
	file.close()
	return GDScriptImporter.new().import_external(PROBE_PATH)


static func _roundtrip(source: String) -> String:
	return str(SheetCompiler.compile(_imported(source), PROBE_PATH).get("output", ""))


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] inspector_button_setting_test: %s" % label)
		return true
	print("[FAIL] inspector_button_setting_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
