# Godot EventSheets - the engine's own CSV reader as a sentence, and the FILES band above it.
#
# Two halves, proven the way the rest of the table vocabulary is: the EMITTED code is pinned (a
# shipped template is a compatibility covenant), and the BEHAVIOUR is proven at run time by building
# the emitted lines into a real GDScript, reloading it and calling it - so the values a game would
# see are the values checked here.
#
# WHAT IS WORTH TESTING HERE, and why:
#   - THE READ IS SEVERAL STATEMENTS. Table Of File compiles to a lambda called on the spot, because
#     an expression field holds one expression and a loop is not one. The trap is indentation: the
#     lambda's body lines are emitted INSIDE an event body, so the test compiles a real sheet and
#     runs the whole emitted file, not just the expression on its own.
#   - THE QUOTING IS THE ENGINE'S. The fixture holds a quoted cell containing the separator and a
#     doubled "" inside another, and the test asserts the values Godot's own reader gives - and then
#     writes them back and asserts the FILE'S BYTES, which is the only way to prove the reader and
#     the writer are each other's inverse.
#   - THE FIRST LINE IS A SHAPE, NOT A VALUE. Both answers of the headers dropdown are pinned, in
#     both verbs, because they compile through the optional-segment idiom and a segment that leaks
#     its marks into the output is a parse error a reader would meet at run time.
#   - THE BAND IS DERIVED. The files band classifies a row by the engine calls its template makes, so
#     the test pins a written path, a read path, a path that is BOTH, the scale law's counting band
#     and the ask - and, deliberately, that a sheet touching no file grows no band at all.
@tool
class_name FilesBandAndEngineTableTest
extends RefCounted

const MODULE_PATH := "res://addons/eventforge/registration/modules/table_aces.gd"
const PROBE_CSV := "user://files_band_probe.csv"
const PROBE_OUT := "user://files_band_probe_out.csv"

## Three traps in one fixture: a quoted cell holding the separator, a doubled "" inside a quoted
## cell, and a trailing newline (which the engine's reader answers with one final empty line).
const ITEMS_CSV := "id,label,price\n1,\"sword, long\",10\n2,\"say \"\"hi\"\"\",5\n"


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _run_registration() and all_passed
	all_passed = _run_emission() and all_passed
	all_passed = _run_runtime() and all_passed
	all_passed = _run_loop() and all_passed
	all_passed = _run_band() and all_passed
	if all_passed:
		print("[PASS] files_band_and_engine_table_test: the engine's CSV reader as a sentence, and the files band")
	return all_passed


## The three verbs register with the ids, kinds and defaults the picker groups them by.
static func _run_registration() -> bool:
	var ok: bool = true
	var by_id: Dictionary = _by_id()
	for ace_id: String in ["FileTable", "WriteFileTable", "ForEachLineInFile"]:
		ok = _check("%s is registered" % ace_id, by_id.has(ace_id), true) and ok
	ok = _check("Table Of File reads as a name", str(by_id["FileTable"].display_name), "Table Of File") and ok
	ok = _check("Write Table To File reads as a name", str(by_id["WriteFileTable"].display_name), "Write Table To File") and ok
	ok = _check("For Each Line In File reads as a name", str(by_id["ForEachLineInFile"].display_name), "For Each Line In File") and ok
	ok = _check("the read is an expression", int(by_id["FileTable"].ace_type), int(ACEDescriptor.ACEType.EXPRESSION)) and ok
	ok = _check("the write is an action", int(by_id["WriteFileTable"].ace_type), int(ACEDescriptor.ACEType.ACTION)) and ok
	ok = _check("the file loop is a condition", int(by_id["ForEachLineInFile"].ace_type), int(ACEDescriptor.ACEType.CONDITION)) and ok
	ok = _check("the two table verbs group with the tables", str(by_id["FileTable"].category), "Files: Tables") and ok
	ok = _check("the write groups with them", str(by_id["WriteFileTable"].category), "Files: Tables") and ok
	ok = _check("the file loop groups with the loops", str(by_id["ForEachLineInFile"].category), "Loops") and ok
	# A path field says its place, which is the whole reason the hint exists - and it is also what
	# puts the row on the files band below.
	ok = _check("the read's path field says its place", _param_hint(by_id, "FileTable", "path"), "file_path") and ok
	ok = _check("the write's path field says its place", _param_hint(by_id, "WriteFileTable", "path"), "file_path") and ok
	ok = _check("the file loop's path field says its place", _param_hint(by_id, "ForEachLineInFile", "path"), "file_path") and ok
	# Defaults are what the row shows the moment it is dropped, so each must stand on its own.
	ok = _check("the read opens on a res:// data file", _param_default(by_id, "FileTable", "path"), "\"res://data/items.csv\"") and ok
	ok = _check("the write opens on a user:// file", _param_default(by_id, "WriteFileTable", "path"), "\"user://scores.csv\"") and ok
	ok = _check("the file loop opens on a user:// file", _param_default(by_id, "ForEachLineInFile", "path"), "\"user://log.txt\"") and ok
	ok = _check("the first-line question opens on naming the columns",
		_param_default(by_id, "FileTable", "headers"), EventForgeTableACEs.HEADERS_NAMED) and ok
	ok = _check("and offers the plain answer beside it",
		str((by_id["FileTable"].params[2].options[1] as Dictionary).get("key", "")),
		EventForgeTableACEs.HEADERS_PLAIN) and ok
	return ok


## What the two verbs compile to, in both answers of the first-line question.
static func _run_emission() -> bool:
	var ok: bool = true
	var named: String = _emitted("FileTable", {"path": "\"res://data/items.csv\"",
		"separator": "\",\"", "headers": EventForgeTableACEs.HEADERS_NAMED})
	ok = _check("the read opens the file for reading",
		named.contains("FileAccess.open(__path, FileAccess.READ)"), true) and ok
	ok = _check("and asks the ENGINE for a line of cells",
		named.contains("__file.get_csv_line(\",\")"), true) and ok
	ok = _check("a missing file is no rows, not a crash", named.contains("\tif __file == null:\n\t\treturn []"), true) and ok
	ok = _check("the lambda is called with the path the row holds",
		named.ends_with(").call(\"res://data/items.csv\")"), true) and ok
	ok = _check("naming the columns builds a record", named.contains("var __record: Dictionary = {}"), true) and ok
	ok = _check("and does NOT also append the raw cells", named.contains("__rows.append(__cells)"), false) and ok
	ok = _check("no segment mark survives into the code", named.contains("{?"), false) and ok
	ok = _check("no unsubstituted placeholder survives", named.contains("{separator}"), false) and ok

	var plain: String = _emitted("FileTable", {"path": "\"res://data/items.csv\"",
		"separator": "\",\"", "headers": EventForgeTableACEs.HEADERS_PLAIN})
	ok = _check("the plain answer appends the cells", plain.contains("\t\t__rows.append(__cells)"), true) and ok
	ok = _check("and never reads a header line", plain.contains("var __columns"), false) and ok
	ok = _check("and builds no record", plain.contains("var __record"), false) and ok

	var write_named: String = _emitted("WriteFileTable", {"path": "\"user://scores.csv\"",
		"table": "scores", "separator": "\",\"", "headers": EventForgeTableACEs.HEADERS_NAMED,
		"uid": "7"})
	ok = _check("the write opens the file for writing",
		write_named.contains("FileAccess.open(\"user://scores.csv\", FileAccess.WRITE)"), true) and ok
	ok = _check("and guards the handle", write_named.contains("if __file_7:"), true) and ok
	ok = _check("and hands cells to the ENGINE'S writer",
		write_named.contains("__file_7.store_csv_line(__cells_7, \",\")"), true) and ok
	ok = _check("the column line comes from the first record's own fields",
		write_named.contains("PackedStringArray(scores[0].keys()) if not scores.is_empty()"), true) and ok
	ok = _check("and the file is closed", write_named.contains("__file_7.close()"), true) and ok
	var write_plain: String = _emitted("WriteFileTable", {"path": "\"user://scores.csv\"",
		"table": "scores", "separator": "\",\"", "headers": EventForgeTableACEs.HEADERS_PLAIN,
		"uid": "7"})
	ok = _check("the plain answer writes no column line", write_plain.contains("store_csv_line(__columns_7"), false) and ok

	# THE ECHO IS THE LINE. The params dialog's IN CODE strip fills an expression's template itself,
	# and it used to drop the values in WITHOUT collapsing the stated choice first - so it read out
	# the template's own `{?headers=…}` marks, a line no file will ever hold. Read Text File (or a
	# fallback) has the same shape, so both are pinned here.
	var definition: ACEDefinition = EventSheetACEAdapter.from_eventforge_descriptor(
		ACERegistry.find_descriptor("Core", "FileTable"))
	var echo: String = ACEParamsDialog.row_code_line(definition, {"path": "\"res://data/items.csv\"",
		"separator": "\",\"", "headers": EventForgeTableACEs.HEADERS_NAMED})
	ok = _check("the dialog's code echo carries no segment marks", echo.contains("{?"), false) and ok
	ok = _check("and shows the shape the choice picked", echo.contains("var __record: Dictionary = {}"), true) and ok
	var fallback_echo: String = ACEParamsDialog.row_code_line(
		EventSheetACEAdapter.from_eventforge_descriptor(
			ACERegistry.find_descriptor("Core", "ReadTextFileOr")),
		{"path": "\"user://save.dat\"", "fallback": "\"\""})
	ok = _check("the guarded read's echo is clean too", fallback_echo.contains("{?"), false) and ok

	# The whole read, emitted INSIDE an event body by the real compiler: the lambda's body lines land
	# under the event's own indentation, which is the failure a single-line expression never meets.
	var compiled: String = _compiled_read(named)
	ok = _check("the read lands in the assignment the Set row writes",
		compiled.contains("\titems = (func(__path: String) -> Array:"), true) and ok
	ok = _check("and its body is indented under the event", compiled.contains("\t\tvar __rows: Array = []"), true) and ok
	ok = _check("and the whole emitted file parses", _parses(compiled), true) and ok
	return ok


## The values a game would see, and the bytes it would write.
static func _run_runtime() -> bool:
	var ok: bool = true
	var file: FileAccess = FileAccess.open(PROBE_CSV, FileAccess.WRITE)
	file.store_string(ITEMS_CSV)
	file.close()

	var records: Array = _call(_emitted("FileTable", {"path": _quote(PROBE_CSV),
		"separator": "\",\"", "headers": EventForgeTableACEs.HEADERS_NAMED}))
	ok = _check("one record per row, the header line consumed", records.size(), 2) and ok
	ok = _check("the column names become the keys", _field(records, 0, "price"), "10") and ok
	ok = _check("a quoted cell keeps the separator inside it", _field(records, 0, "label"), "sword, long") and ok
	ok = _check("a doubled quote inside a quoted cell is ONE quote", _field(records, 1, "label"), "say \"hi\"") and ok
	ok = _check("the trailing newline adds no phantom record", _field(records, 1, "id"), "2") and ok

	var rows: Array = _call(_emitted("FileTable", {"path": _quote(PROBE_CSV),
		"separator": "\",\"", "headers": EventForgeTableACEs.HEADERS_PLAIN}))
	ok = _check("read plainly, the header line is a row like any other", rows.size(), 3) and ok
	ok = _check("and the first row IS the header line", Array(rows[0] as PackedStringArray), ["id", "label", "price"] as Array) and ok

	var missing: Array = _call(_emitted("FileTable", {"path": "\"user://files_band_no_such_file.csv\"",
		"separator": "\",\"", "headers": EventForgeTableACEs.HEADERS_NAMED}))
	ok = _check("a file that is not there is no rows, not an error", missing.size(), 0) and ok

	# The inverse: write those records back and compare the FILE'S BYTES with the fixture. This is
	# the whole claim of the pair - the engine quotes on the way out exactly as it unquotes coming in.
	_run_write(records)
	ok = _check("the write is the read's inverse, byte for byte",
		FileAccess.get_file_as_string(PROBE_OUT), ITEMS_CSV) and ok

	DirAccess.remove_absolute(PROBE_CSV)
	DirAccess.remove_absolute(PROBE_OUT)
	return ok


## The file loop: the collection it hands the loop lane, and the values that loop walks.
static func _run_loop() -> bool:
	var ok: bool = true
	var by_id: Dictionary = _by_id()
	ok = _check("the file loop declares itself looping", bool(by_id["ForEachLineInFile"].is_looping), true) and ok
	ok = _check("and names its iterator `line`", str(by_id["ForEachLineInFile"].looping_iterator), "line") and ok
	var collection: String = _emitted("ForEachLineInFile", {"path": _quote(PROBE_CSV)})
	ok = _check("the collection is one expression, so it can ride in the loop lane",
		collection.split("\n").size(), 1) and ok

	var file: FileAccess = FileAccess.open(PROBE_CSV, FileAccess.WRITE)
	file.store_string("first\r\n\r\nsecond\rthird")
	file.close()
	var lines: Array = _call(collection)
	ok = _check("blank lines are skipped and every ending is handled", lines, ["first", "second", "third"] as Array) and ok
	DirAccess.remove_absolute(PROBE_CSV)

	# And the pick filter it becomes compiles to a plain for loop naming that iterator.
	var definition: ACEDefinition = EventSheetACEAdapter.from_eventforge_descriptor(by_id["ForEachLineInFile"])
	ok = _check("the definition metadata carries the iterator",
		str(definition.metadata.get("looping_iterator", "")), "line") and ok
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	var row: EventRow = EventRow.new()
	row.trigger_provider_id = "Core"
	row.trigger_id = "OnReady"
	var pick: PickFilter = PickFilter.new()
	pick.collection_kind = PickFilter.CollectionKind.EXPRESSION
	pick.collection_value = collection
	pick.iterator_name = "line"
	row.pick_filters.append(pick)
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "Print"
	action.codegen_template = "print(line)"
	row.actions.append(action)
	sheet.events.append(row)
	var output: String = str(SheetCompiler.compile(sheet, "user://files_band_loop_probe.gd").get("output", ""))
	ok = _check("it compiles as a for over the file's lines",
		output.contains("for line in " + collection + ":"), true) and ok
	if FileAccess.file_exists("user://files_band_loop_probe.gd"):
		DirAccess.remove_absolute("user://files_band_loop_probe.gd")
	return ok


## The band: what a sheet says it touches, read off its own rows.
static func _run_band() -> bool:
	var ok: bool = true
	var empty: EventSheetResource = EventSheetResource.new()
	empty.host_class = "Node"
	empty.events.append(_event([_action("Print", {})]))
	ok = _check("a sheet that touches no file grows no band",
		EventSheetFileFacts.bands(empty).size(), 0) and ok

	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	sheet.events.append(_event([
		_action("WriteTextFile", {"path": "\"user://save.dat\"", "text": "\"x\""}),
		_action("CopyFile", {"from": "\"user://old.dat\"", "to": "\"user://backup.dat\""}),
	]))
	sheet.events.append(_event([_action("SetVar", {"var_name": "items", "value": "0"})],
		[_condition("ForEachLineInFile", {"path": "\"res://data/levels.txt\""})]))
	var readings: Array[Dictionary] = EventSheetFileFacts.bands(sheet)
	ok = _check("one band per path the sheet touches", readings.size(), 4) and ok
	ok = _check("a written path says so, with its place still on it",
		str(readings[0].get("value", "")), "user://save.dat - written") and ok
	ok = _check("and echoes the line the file holds",
		str(readings[0].get("echo", "")), "var __file_{uid} = FileAccess.open(\"user://save.dat\", FileAccess.WRITE)") and ok
	ok = _check("a read path says so", str(readings[3].get("value", "")), "res://data/levels.txt - read") and ok
	ok = _check("a copy's destination is read and written, because a copy does both",
		str(readings[2].get("value", "")), "user://backup.dat - read and written") and ok

	# The same path written by one row and read by another is ONE fact about ONE file.
	var both: EventSheetResource = EventSheetResource.new()
	both.host_class = "Node"
	both.events.append(_event([_action("WriteTextFile", {"path": "\"user://log.txt\"", "text": "\"x\""})],
		[_condition("FileExists", {"path": "\"user://log.txt\""})]))
	var both_bands: Array[Dictionary] = EventSheetFileFacts.bands(both)
	ok = _check("a path read and written is one band", both_bands.size(), 1) and ok
	ok = _check("saying both", str(both_bands[0].get("value", "")), "user://log.txt - read and written") and ok

	# The band scale law: name what fits, count the rest.
	var many: EventSheetResource = EventSheetResource.new()
	many.host_class = "Node"
	var actions: Array = []
	for index: int in 6:
		actions.append(_action("WriteTextFile", {"path": "\"user://run%d.txt\"" % index, "text": "\"x\""}))
	many.events.append(_event(actions))
	var many_bands: Array[Dictionary] = EventSheetFileFacts.bands(many)
	ok = _check("four paths are named and the rest are counted", many_bands.size(),
		EventSheetFileFacts.SHOWN_LIMIT + 1) and ok
	ok = _check("the counting band says how many more",
		str(many_bands[EventSheetFileFacts.SHOWN_LIMIT].get("value", "")),
		EventSheetL10n.translate("and %d more path(s)") % 2) and ok

	# A path can also sit INSIDE a value: the table read is one expression with the file quoted in the
	# middle of it, and a path field is not where it lives. The band reads the row's own emitted line
	# for it, which is what puts the flagship read on the band at all.
	var inside: EventSheetResource = EventSheetResource.new()
	inside.host_class = "Node"
	inside.events.append(_event([_action("SetVar", {"var_name": "items",
		"value": _emitted("FileTable", {"path": "\"res://data/items.csv\"", "separator": "\",\"",
			"headers": EventForgeTableACEs.HEADERS_NAMED})})]))
	var inside_bands: Array[Dictionary] = EventSheetFileFacts.bands(inside)
	ok = _check("a path quoted inside an expression is still on the band", inside_bands.size(), 1) and ok
	ok = _check("read, because the line it sits in reads",
		str(inside_bands[0].get("value", "")), "res://data/items.csv - read") and ok

	# And a verbatim block is a row of the file like any other, so hand-written file code counts.
	var hand: EventSheetResource = EventSheetResource.new()
	hand.host_class = "Node"
	var block: RawCodeRow = RawCodeRow.new()
	block.code = "var f = FileAccess.open(\"user://notes.txt\", FileAccess.WRITE)\nf.store_string(\"hi\")"
	hand.events.append(block)
	var hand_bands: Array[Dictionary] = EventSheetFileFacts.bands(hand)
	ok = _check("a hand-written FileAccess call is a file this sheet touches", hand_bands.size(), 1) and ok
	ok = _check("and it is read as a write", str(hand_bands[0].get("value", "")),
		"user://notes.txt - written") and ok

	# A path-shaped string that nothing opens is NOT a file the sheet touches - a scene a row loads
	# is not a file this band is about.
	var scene_only: EventSheetResource = EventSheetResource.new()
	scene_only.host_class = "Node"
	var scene_block: RawCodeRow = RawCodeRow.new()
	scene_block.code = "var copy = load(\"res://enemy.tscn\").instantiate()"
	scene_only.events.append(scene_block)
	ok = _check("a loaded scene is not a file the band is about",
		EventSheetFileFacts.bands(scene_only).size(), 0) and ok

	# The ask: a row whose verb is declared on a file chooser, found by that class rather than by id.
	var asking: EventSheetResource = EventSheetResource.new()
	asking.host_class = "Node"
	asking.events.append(_event([_action("OpenFileChooser", {})]))
	var asking_bands: Array[Dictionary] = EventSheetFileFacts.bands(asking)
	ok = _check("a sheet that stops to ask says so once", asking_bands.size(), 1) and ok
	ok = _check("in the band's own words", str(asking_bands[0].get("value", "")),
		EventSheetL10n.translate("asks the player to pick a file")) and ok

	# A CHOOSER SOMEBODY WROTE BY HAND IS THE SAME FACT. The ask is found by the LINE it opens, and a
	# verbatim block is a row of the file like any other - the band already reads one for its paths.
	var hand_asking: EventSheetResource = EventSheetResource.new()
	hand_asking.host_class = "Node"
	var chooser_block: RawCodeRow = RawCodeRow.new()
	chooser_block.code = "DisplayServer.file_dialog_show(\"Open\", \"\", \"\", false," \
		+ " DisplayServer.FILE_DIALOG_MODE_OPEN_FILE, PackedStringArray(), _answer)"
	hand_asking.events.append(chooser_block)
	var hand_asking_bands: Array[Dictionary] = EventSheetFileFacts.bands(hand_asking)
	ok = _check("a hand-written chooser is a sheet that asks", hand_asking_bands.size(), 1) and ok
	ok = _check("said in the same words", str(hand_asking_bands[0].get("value", "")),
		EventSheetL10n.translate("asks the player to pick a file")) and ok

	# THE SCALE LAW APPLIES TO WATCHES TOO. Ten watches would otherwise wear ten bands on top of the
	# paths and the ask, and a head longer than the sheet is not a head.
	var watching: EventSheetResource = EventSheetResource.new()
	watching.host_class = "Node"
	var watch_lines: PackedStringArray = PackedStringArray()
	for index: int in 6:
		watch_lines.append("$FolderWatcher.watch_folder(\"user://mods%d\", 2.0)" % index)
	var watch_block: RawCodeRow = RawCodeRow.new()
	watch_block.code = "\n".join(watch_lines)
	watching.events.append(watch_block)
	var watch_bands: Array[Dictionary] = EventSheetFileFacts.bands(watching)
	ok = _check("four watches are named and the rest are counted", watch_bands.size(),
		EventSheetFileFacts.SHOWN_LIMIT + 1) and ok
	ok = _check("and the counting band says how many more",
		str(watch_bands[EventSheetFileFacts.SHOWN_LIMIT].get("value", "")),
		EventSheetL10n.translate("and %d more watched folder(s)") % 2) and ok

	# A FUNCTION LIFTED OUT OF A HAND-WRITTEN FILE holds its rows in `rows`, not in `events`, which is
	# exactly the shape this plugin is for. The Doctor's walk always read both; the band read one.
	var lifted: EventSheetResource = EventSheetResource.new()
	lifted.host_class = "Node"
	var helper: EventFunction = EventFunction.new()
	helper.function_name = "save_it"
	var lifted_row: EventRow = EventRow.new()
	lifted_row.actions.append(_action("WriteTextFile", {"path": "\"user://lifted.txt\"",
		"text": "\"x\""}))
	helper.rows.append(lifted_row)
	lifted.functions.append(helper)
	var lifted_bands: Array[Dictionary] = EventSheetFileFacts.bands(lifted)
	ok = _check("a path in a lifted function is still on the band", lifted_bands.size(), 1) and ok
	ok = _check("and read the same way", str(lifted_bands[0].get("value", "")),
		"user://lifted.txt - written") and ok

	# And the band sits in the head's reading order, after what the sheet's node collides with.
	ok = _check("the files band is a band the head knows",
		EventSheetHeadBands.SCENE_BANDS.has(EventSheetHeadBands.BAND_FILES), true) and ok
	ok = _check("and reads after the collisions band",
		Array(EventSheetHeadBands.ORDER).find(EventSheetHeadBands.BAND_FILES)
			- Array(EventSheetHeadBands.ORDER).find(EventSheetHeadBands.BAND_COLLISIONS), 1) and ok
	var built: Array[Dictionary] = EventSheetHeadBands.bands({"files": readings})
	var files_bands: Array[Dictionary] = []
	for band: Dictionary in built:
		if str(band.get("kind", "")) == EventSheetHeadBands.BAND_FILES:
			files_bands.append(band)
	ok = _check("and the head really builds one band per reading", files_bands.size(), 4) and ok
	ok = _check("each wearing the files leader", str(files_bands[0].get("leader", "")), "files") and ok
	return ok


# -- the pieces ------------------------------------------------------------------------------


## The read compiled by the real compiler inside an event body, which is where its indentation is
## decided. Returns the whole emitted file.
static func _compiled_read(expression: String) -> String:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	# The variable is declared on the sheet so the emitted file is a WHOLE file that parses - the
	# indentation of a multi-line expression is only provable by parsing what the compiler wrote.
	sheet.variables["items"] = {"type": "Array", "default": []}
	var row: EventRow = EventRow.new()
	row.trigger_provider_id = "Core"
	row.trigger_id = "OnReady"
	row.actions.append(_action("SetVar", {"var_name": "items", "value": expression}))
	sheet.events.append(row)
	var output: String = str(SheetCompiler.compile(sheet, "user://files_band_compile_probe.gd").get("output", ""))
	if FileAccess.file_exists("user://files_band_compile_probe.gd"):
		DirAccess.remove_absolute("user://files_band_compile_probe.gd")
	return output


## Writes the records back out through the shipped write template, exactly as a sheet would.
static func _run_write(records: Array) -> void:
	var written: String = _emitted("WriteFileTable", {"path": _quote(PROBE_OUT), "table": "__table",
		"separator": "\",\"", "headers": EventForgeTableACEs.HEADERS_NAMED, "uid": "1"})
	var lines: PackedStringArray = PackedStringArray(["@tool", "extends RefCounted", "", "",
		"static func probe(__table: Array) -> void:"])
	for line: String in written.split("\n"):
		lines.append("\t" + line)
	var script: GDScript = GDScript.new()
	script.source_code = "\n".join(lines) + "\n"
	if script.reload() != OK:
		print("  [FAIL] files_band_and_engine_table_test: the emitted write did not compile")
		return
	script.call("probe", records)


## Runs an emitted expression for real - the pinned text is also the text that is run.
static func _call(expression: String) -> Array:
	var lines: PackedStringArray = PackedStringArray(["@tool", "extends RefCounted", "", "",
		"static func probe() -> Variant:", "\tif true:"])
	for line: String in ("return %s" % expression).split("\n"):
		lines.append("\t\t" + line)
	lines.append("\treturn null")
	var script: GDScript = GDScript.new()
	script.source_code = "\n".join(lines) + "\n"
	if script.reload() != OK:
		print("  [FAIL] files_band_and_engine_table_test: an emitted expression did not compile")
		return []
	var value: Variant = script.call("probe")
	if value is Array:
		return value as Array
	if value is PackedStringArray:
		return Array(value as PackedStringArray)
	return []


## True when a whole emitted file parses - the only proof that a multi-line expression landed at the
## indentation the compiler meant it to.
static func _parses(source: String) -> bool:
	var script: GDScript = GDScript.new()
	script.source_code = source
	return script.reload() == OK


static func _event(actions: Array, conditions: Array = []) -> EventRow:
	var row: EventRow = EventRow.new()
	row.trigger_provider_id = "Core"
	row.trigger_id = "OnReady"
	for entry: Variant in conditions:
		row.conditions.append(entry)
	for entry: Variant in actions:
		row.actions.append(entry)
	return row


static func _action(ace_id: String, params: Dictionary) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	action.params = params
	return action


static func _condition(ace_id: String, params: Dictionary) -> ACECondition:
	var condition: ACECondition = ACECondition.new()
	condition.provider_id = "Core"
	condition.ace_id = ace_id
	condition.params = params
	return condition


static func _emitted(ace_id: String, params: Dictionary) -> String:
	var by_id: Dictionary = _by_id()
	if not by_id.has(ace_id):
		return ""
	return ActionCodegen._apply_template(str(by_id[ace_id].codegen_template), params)


static func _by_id() -> Dictionary:
	var by_id: Dictionary = {}
	for descriptor: ACEDescriptor in load(MODULE_PATH).get_descriptors():
		by_id[descriptor.ace_id] = descriptor
	return by_id


static func _param_default(by_id: Dictionary, ace_id: String, param_id: String) -> String:
	if not by_id.has(ace_id):
		return ""
	for param: ACEParam in by_id[ace_id].params:
		if param.id == param_id:
			return str(param.default_value)
	return ""


static func _param_hint(by_id: Dictionary, ace_id: String, param_id: String) -> String:
	if not by_id.has(ace_id):
		return ""
	for param: ACEParam in by_id[ace_id].params:
		if param.id == param_id:
			return str(param.hint)
	return ""


static func _field(records: Array, index: int, key: String) -> String:
	if index >= records.size():
		return "<no such record>"
	return str((records[index] as Dictionary).get(key, "<no such column>"))


## A GDScript string literal for arbitrary text.
static func _quote(text: String) -> String:
	return "\"%s\"" % text.c_escape()


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		return true
	print("  [FAIL] files_band_and_engine_table_test: %s (got %s, expected %s)" % [label, str(actual), str(expected)])
	return false
