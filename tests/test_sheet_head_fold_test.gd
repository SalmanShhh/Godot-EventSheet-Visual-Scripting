@tool
class_name TestSheetHeadFoldTest
extends RefCounted

# The two things a test sheet says that are the HARNESS rather than the test:
#
#   var passed := true        the verdict bookkeeping every gate opens with
#   static func _check(...)   the eleven lines every file in the folder carries a copy of
#
# Both fold into the head, which already says this is a test sheet and how many checks it makes.
# Neither is removed from anything: the sheet keeps both, the compiler emits both, and the byte
# round-trip is the last gate here for exactly that reason.
#
# The source is written to a `tests/` folder under `user://` because half of what makes a file a test
# sheet is the folder it lives in - a game script with the same lines in it must keep every row.

const SOURCE_PATH := "user://tests/eventforge_test_head_fold_test.gd"
const GAME_PATH := "user://eventforge_test_head_fold_game.gd"

const SOURCE: String = """@tool
class_name EventforgeTestHeadFoldTest
extends RefCounted

static func run() -> bool:
	var passed: bool = true
	var count: int = 2
	passed = _check("two is two", count, 2) and passed
	return passed

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		return true
	print("[FAIL] %s: got %s expected %s" % [label, actual, expected])
	return false
"""


static func run() -> bool:
	var ok: bool = true
	ok = _folds() and ok
	ok = _game_script_keeps_everything() and ok
	ok = _round_trip() and ok
	return ok


## The two folds, by what the opened sheet SAYS: neither the verdict local nor the harness appears in
## any cell, and the check the test actually makes still does.
static func _folds() -> bool:
	var ok: bool = true
	var readings: String = " | ".join(_open_and_read(SOURCE_PATH, SOURCE))
	ok = _check("the verdict bookkeeping does not read as a row",
		readings.contains("passed = true"), false) and ok
	ok = _check("nor does the harness the Check rows are drawn from",
		readings.contains("On Check"), false) and ok
	ok = _check("and the check the test makes still reads as a Check row",
		readings.contains("Check \"two is two\": count = 2"), true) and ok
	# The head is where both went, and it still counts what the file claims.
	ok = _check("the head says what the file is and how many checks it makes",
		" · ".join(EventSheetToolFiles.head_chips(EventSheetToolFiles.KIND_TEST_SHEET,
			EventSheetToolFiles.checks(SOURCE.split("\n")).size())),
		"test sheet · 1 check") and ok
	# An ordinary local is still a local: only the name the file folds its verdict through goes.
	ok = _check("an ordinary local keeps its row",
		readings.contains("count") and readings.contains("2"), true) and ok
	return ok


## The same lines in a GAME script are an ordinary local and an ordinary function, and every row
## stays. What makes a test a test is its folder, and a reading that forgot that would quietly eat
## rows out of somebody's project.
static func _game_script_keeps_everything() -> bool:
	var readings: String = " | ".join(_open_and_read(GAME_PATH, SOURCE))
	return _check("a game script with the same lines keeps its harness row",
		readings.contains("On Check"), true)


## Writes the source, opens it as a sheet, and returns every cell reading.
static func _open_and_read(path: String, source: String) -> PackedStringArray:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var handle: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	handle.store_string(source)
	handle.close()
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(path)
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
			readings.append(span.text.strip_edges())
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


## The promise both folds rest on: nothing was removed from the sheet, so opening the file and saving
## it untouched puts back every byte the file had.
static func _round_trip() -> bool:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(SOURCE_PATH)
	var output: String = str(SheetCompiler.compile(sheet, SOURCE_PATH).get("output", ""))
	return _check("opening the folded test and saving it reproduces every byte", output, SOURCE)


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] test_sheet_head_fold_test: %s" % label)
		return true
	print("[FAIL] test_sheet_head_fold_test: %s - expected %s, got %s" % [label, expected, actual])
	return false
