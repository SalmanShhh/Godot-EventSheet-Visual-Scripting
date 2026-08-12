# EventForge - Tables + the text/folder looping conditions (table_aces.gd).
#
# Two halves, both proven the same way: the EMITTED code is pinned (the template is a compatibility
# covenant, so the exact substrings a sheet compiles to are asserted through SheetCompiler), and the
# BEHAVIOUR is proven at runtime (the emitted expression is built into a real GDScript, reloaded and
# called, so the values a game would see are the values checked here).
#
# The traps a spreadsheet reader actually meets, each with its own case below: a quoted cell that
# contains the separator, a doubled "" inside such a cell, a quote that never PAIRS UP (an inches
# mark), CRLF and lone-CR line endings, a file with NO trailing newline, blank and duplicated column
# names, a row shorter than the header, and the failure paths - a missing file, a lookup that matches
# nothing, a folder that is not there.
#
# The looping half also pins the SEAM: ACEDescriptor.looping(iterator) -> adapter metadata ->
# ace_apply's pick filter -> the compiler's plain `for` loop.
@tool
class_name TableACEsTest
extends RefCounted

const MODULE_PATH := "res://addons/eventforge/registration/modules/table_aces.gd"
const PROBE_CSV := "user://table_aces_probe.csv"
const PROBE_ASSETS := "user://table_aces_probe_assets"

# The spreadsheet every parse case reads: CRLF endings, a quoted cell holding the separator, and NO
# trailing newline (three traps in one fixture, so a regression in any of them moves these values).
const ITEMS_CSV := "id,label,price\r\n1,\"sword, long\",10\r\n2,shield,5"


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _run_registration() and all_passed
	all_passed = _run_emission() and all_passed
	all_passed = _run_table_runtime() and all_passed
	all_passed = _run_reader_runtime() and all_passed
	all_passed = _run_looping_seam() and all_passed
	all_passed = _run_looping_runtime() and all_passed
	if all_passed:
		print("[PASS] table_aces_test: tables + the text/folder loops (emitted code pinned, values proven at runtime)")
	return all_passed


## The seven verbs register with the ids, categories and kinds the picker groups them by.
static func _run_registration() -> bool:
	var ok: bool = true
	var by_id: Dictionary = _by_id()
	for ace_id: String in ["TableFromFile", "TableFromText", "TableColumn", "TableRowWhere",
			"ForEachLineInText", "ForEachPartInText", "ForEachResourceInFolder"]:
		ok = _check("%s is registered" % ace_id, by_id.has(ace_id), true) and ok
	ok = _check("Table From File reads as a name", _display_name(by_id, "TableFromFile"), "Table From File") and ok
	ok = _check("Table From Text reads as a name", _display_name(by_id, "TableFromText"), "Table From Text") and ok
	ok = _check("Column Of Table reads as a name", _display_name(by_id, "TableColumn"), "Column Of Table") and ok
	ok = _check("Row Where reads as a name", _display_name(by_id, "TableRowWhere"), "Row Where") and ok
	ok = _check("For Each Line In Text reads as a name", _display_name(by_id, "ForEachLineInText"), "For Each Line In Text") and ok
	ok = _check("For Each Part In Text reads as a name", _display_name(by_id, "ForEachPartInText"), "For Each Part In Text") and ok
	ok = _check("For Each Resource In Folder reads as a name", _display_name(by_id, "ForEachResourceInFolder"), "For Each Resource In Folder") and ok
	ok = _check("the table verbs group under Files: Tables", _category(by_id, "TableFromFile"), "Files: Tables") and ok
	ok = _check("Row Where groups with them", _category(by_id, "TableRowWhere"), "Files: Tables") and ok
	ok = _check("the loops group under Loops", _category(by_id, "ForEachLineInText"), "Loops") and ok
	ok = _check("Table From File is an expression", int(by_id["TableFromFile"].ace_type), int(ACEDescriptor.ACEType.EXPRESSION)) and ok
	ok = _check("For Each Line In Text is a condition", int(by_id["ForEachLineInText"].ace_type), int(ACEDescriptor.ACEType.CONDITION)) and ok
	# The picker's section header needs an icon for every live category; "Files: Tables" is a
	# sub-category, so it inherits the Files entry rather than needing one of its own.
	ok = _check("Files: Tables inherits the Files icon", ACEPickerDialog.category_icon_name("Files: Tables"), "File") and ok
	# Defaults are what the row shows the moment it is dropped, so each must stand on its own.
	ok = _check("the path default is a literal", _param_default(by_id, "TableFromFile", "path"), "\"res://data/items.csv\"") and ok
	ok = _check("the separator default is a quoted comma", _param_default(by_id, "TableFromFile", "separator"), "\",\"") and ok
	ok = _check("the separator picker offers Comma first", str(_first_option_label(by_id, "TableFromFile", "separator")), "Comma") and ok
	ok = _check("the folder default is a literal", _param_default(by_id, "ForEachResourceInFolder", "folder"), "\"res://data/items\"") and ok
	return ok


## What a sheet actually compiles to. The expression lands in a Set Variable row exactly as the
## mockup writes it, and the whole emitted line is asserted - a template is frozen once shipped.
static func _run_emission() -> bool:
	var ok: bool = true
	var emitted: String = _emitted("TableFromFile", {"path": "\"res://data/items.csv\"", "separator": "\",\""})
	ok = _check("the file read is null-safe (\"\" when the file is missing)",
		emitted.contains("FileAccess.get_file_as_string(\"res://data/items.csv\")"), true) and ok
	ok = _check("line endings are normalised before the split",
		emitted.contains(".replace(\"\\r\\n\", \"\\n\").replace(\"\\r\", \"\\n\").split(\"\\n\", false)"), true) and ok
	ok = _check("the separator reaches the cell split", emitted.contains(").split(\",\")).map("), true) and ok
	ok = _check("the separator also reaches the inside-quotes protection",
		emitted.contains("__part.replace(\",\", \"\\u001f\")"), true) and ok
	ok = _check("a line whose quotes do not pair up skips the protection pass entirely",
		emitted.contains("if __line.count(\"\\\"\") % 2 == 0 else __line"), true) and ok
	ok = _check("records are built without overwriting a repeated column", emitted.contains(".merged({"), true) and ok
	ok = _check("no unsubstituted placeholder survives", emitted.contains("{separator}"), false) and ok
	ok = _check("the emitted expression is one line", emitted.split("\n").size(), 1) and ok

	# Through the real compiler, in the row the mockup shows: Set variable items to Table From File(...).
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	var row: EventRow = EventRow.new()
	row.trigger_provider_id = "Core"
	row.trigger_id = "OnReady"
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "SetVar"
	action.params = {"var_name": "items", "value": emitted}
	row.actions.append(action)
	sheet.events.append(row)
	var output: String = str(SheetCompiler.compile(sheet, "user://table_aces_compile_probe.gd").get("output", ""))
	ok = _check("the whole expression compiles into the assignment verbatim",
		output.contains("items = " + emitted), true) and ok
	if FileAccess.file_exists("user://table_aces_compile_probe.gd"):
		DirAccess.remove_absolute("user://table_aces_compile_probe.gd")

	# The short templates are pinned whole - these two ARE the covenant.
	ok = _check("For Each Line In Text emits the normalised split",
		_emitted("ForEachLineInText", {"text": "blob"}),
		"blob.replace(\"\\r\\n\", \"\\n\").replace(\"\\r\", \"\\n\").split(\"\\n\", false)") and ok
	ok = _check("Column Of Table emits a plain map",
		_emitted("TableColumn", {"table": "items", "column": "\"price\""}),
		"items.map(func(__record): return __record.get(\"price\", \"\"))") and ok
	# A looping condition can be evaluated every frame, so a missing folder must not print an engine
	# error per frame: the walk asks whether the folder is there before listing it.
	ok = _check("the folder walk checks the folder exists before listing it",
		_emitted("ForEachResourceInFolder", {"folder": "\"res://data/items\""}).contains(
			"DirAccess.get_files_at(\"res://data/items\") if DirAccess.dir_exists_absolute(\"res://data/items\") else PackedStringArray()"), true) and ok
	return ok


## The parse itself, at runtime: every trap the header comment promises, with real values.
static func _run_table_runtime() -> bool:
	var ok: bool = true

	var items: Variant = _table_from_text(ITEMS_CSV)
	ok = _check("a CRLF file with no trailing newline yields one record per row", _size(items), 2) and ok
	ok = _check("a quoted cell keeps the separator inside it", _field(items, 0, "label"), "sword, long") and ok
	ok = _check("the column names become the keys", _field(items, 0, "price"), "10") and ok
	ok = _check("the last row survives the missing newline", _field(items, 1, "label"), "shield") and ok
	ok = _check("record keys keep the header order", _keys(items, 0), ["id", "label", "price"] as Array) and ok

	# A trailing newline changes nothing: same rows either way.
	ok = _check("a trailing newline adds no phantom row", _size(_table_from_text(ITEMS_CSV + "\r\n")), 2) and ok
	# Blank lines in the middle are dropped rather than becoming empty records.
	ok = _check("a blank line in the middle is skipped", _size(_table_from_text("a,b\n1,2\n\n3,4\n")), 2) and ok

	# Failure path: nothing to read at all.
	ok = _check("empty text is no rows, not a crash", _size(_table_from_text("")), 0) and ok
	ok = _check("a header with no rows under it is no rows", _size(_table_from_text("id,label\n")), 0) and ok

	# A doubled "" inside a quoted cell is ONE literal quote character.
	var quoted: Variant = _table_from_text("quote\n\"he said \"\"hi\"\"\"")
	ok = _check("a doubled quote inside a quoted cell is one quote", _field(quoted, 0, "quote"), "he said \"hi\"") and ok

	# A messy header: a BLANK name is skipped, a REPEATED one keeps the first column, and a row
	# shorter than the header fills the rest with empty text instead of vanishing.
	var messy: Variant = _table_from_text("id,,id,extra\n1,x,2\n")
	ok = _check("a messy header still yields the row", _size(messy), 1) and ok
	ok = _check("a blank column name is skipped", _keys(messy, 0), ["id", "extra"] as Array) and ok
	ok = _check("a repeated column name keeps the FIRST column", _field(messy, 0, "id"), "1") and ok
	ok = _check("a short row fills the missing column with empty text", _field(messy, 0, "extra"), "") and ok
	# Header names are trimmed, so a spreadsheet's stray spaces do not become part of the key.
	ok = _check("header names are trimmed", _field(_table_from_text(" id , label \n1,a"), 0, "label"), "a") and ok

	# A semicolon export parses the same way, quoted cells included.
	var semi: Variant = _table_from_text("id;label\n1;\"a;b\"", "\";\"")
	ok = _check("a semicolon export parses too", _field(semi, 0, "label"), "a;b") and ok

	# UNPAIRED quotes: an inches mark, or a hand-typed row somebody never closed. The quote-aware
	# fold has no closing quote to flip on, so it used to protect every separator after the stray
	# character and the line silently LOST a column - no error, no dropped row, just a wrong price
	# turning up later. A line whose quotes do not pair up is now split plainly, keeping the stray
	# quote as the literal character it obviously is.
	var stray: Variant = _table_from_text("id,label,price\n1,12\" pipe,50")
	ok = _check("an unpaired quote does not eat the next separator", _field(stray, 0, "price"), "50") and ok
	ok = _check("and the stray quote survives as a literal character", _field(stray, 0, "label"), "12\" pipe") and ok
	ok = _check("the row still has every column", _keys(stray, 0), ["id", "label", "price"] as Array) and ok
	# A stray quote at the END of a line is the same shape and must not swallow the last cell.
	ok = _check("a trailing stray quote keeps its cell",
		_field(_table_from_text("id,label\n1,ok\""), 0, "label"), "ok\"") and ok
	# The escape still works on an unpaired line, because "" is swapped out before the count is taken.
	ok = _check("a doubled quote still reads as one on an otherwise unbalanced line",
		_field(_table_from_text("id,label\n1,6\"\" pipe\""), 0, "label"), "6\" pipe\"") and ok
	# And the balanced case is untouched: the whole point is that only the odd count changes branch.
	ok = _check("a properly quoted cell still protects its separator",
		_field(_table_from_text("id,label\n1,\"a,b\""), 0, "label"), "a,b") and ok

	# Table From File over a real file on disk, then the failure path: a file that is not there.
	var file: FileAccess = FileAccess.open(PROBE_CSV, FileAccess.WRITE)
	file.store_string(ITEMS_CSV)
	file.close()
	var from_file: Variant = _eval(_emitted("TableFromFile", {"path": _quote(PROBE_CSV), "separator": "\",\""}))
	ok = _check("Table From File reads the file on disk", _size(from_file), 2) and ok
	ok = _check("Table From File keeps a quoted separator", _field(from_file, 0, "label"), "sword, long") and ok
	var missing: Variant = _eval(_emitted("TableFromFile", {"path": "\"user://table_aces_does_not_exist.csv\"", "separator": "\",\""}))
	ok = _check("a missing file is no rows, not an error", _size(missing), 0) and ok
	DirAccess.remove_absolute(PROBE_CSV)
	return ok


## Column Of Table and Row Where over a parsed table, including the "nothing matched" answer.
static func _run_reader_runtime() -> bool:
	var ok: bool = true
	var table_source: String = _emitted("TableFromText", {"text": _quote(ITEMS_CSV), "separator": "\",\""})

	var column: Variant = _eval(_emitted("TableColumn", {"table": table_source, "column": "\"price\""}))
	ok = _check("a column comes back in row order", column, ["10", "5"] as Array) and ok
	var absent: Variant = _eval(_emitted("TableColumn", {"table": table_source, "column": "\"nope\""}))
	ok = _check("a column nobody has is empty text, not null", absent, ["", ""] as Array) and ok

	var found: Variant = _eval(_emitted("TableRowWhere", {"table": table_source, "column": "\"id\"", "value": "\"2\""}))
	ok = _check("Row Where finds the record", str((found as Dictionary).get("label", "")), "shield") and ok
	var by_number: Variant = _eval(_emitted("TableRowWhere", {"table": table_source, "column": "\"price\"", "value": "5"}))
	ok = _check("Row Where compares as text, so 5 matches \"5\"", str((by_number as Dictionary).get("id", "")), "2") and ok
	var first_wins: Variant = _eval(_emitted("TableRowWhere", {"table": _quote_table("k,v\n1,a\n1,b"), "column": "\"k\"", "value": "\"1\""}))
	ok = _check("Row Where returns the FIRST match", str((first_wins as Dictionary).get("v", "")), "a") and ok
	var nothing: Variant = _eval(_emitted("TableRowWhere", {"table": table_source, "column": "\"id\"", "value": "\"99\""}))
	ok = _check("no match is an empty record", (nothing as Dictionary).size(), 0) and ok
	return ok


## The seam: .looping(iterator) -> adapter metadata -> ace_apply's pick filter -> a plain for loop.
static func _run_looping_seam() -> bool:
	var ok: bool = true
	var by_id: Dictionary = _by_id()
	ok = _check("a looping condition declares itself", bool(by_id["ForEachLineInText"].is_looping), true) and ok
	ok = _check("it names its iterator", str(by_id["ForEachLineInText"].looping_iterator), "line") and ok
	ok = _check("For Each Part names its own", str(by_id["ForEachPartInText"].looping_iterator), "part") and ok
	ok = _check("For Each Resource names its own", str(by_id["ForEachResourceInFolder"].looping_iterator), "entry") and ok
	ok = _check("a plain expression is not looping", bool(by_id["TableFromFile"].is_looping), false) and ok
	# An iterator that could not be a variable name falls back to "item", like the annotation route.
	var probe: ACEDescriptor = ACEDescriptor.new()
	ok = _check("a nonsense iterator falls back to item", str(probe.looping("not an identifier").looping_iterator), "item") and ok

	# The adapter carries both keys into the definition metadata ace_apply reads.
	var definition: ACEDefinition = EventSheetACEAdapter.from_eventforge_descriptor(by_id["ForEachLineInText"])
	ok = _check("the definition metadata says looping", bool(definition.metadata.get("looping", false)), true) and ok
	ok = _check("the definition metadata carries the iterator", str(definition.metadata.get("looping_iterator", "")), "line") and ok
	ok = _check("a non-looping definition says so",
		bool(EventSheetACEAdapter.from_eventforge_descriptor(by_id["TableFromFile"]).metadata.get("looping", false)), false) and ok
	ok = _check("it stays a condition in the picker", int(definition.ace_type), int(ACEDefinition.ACEType.CONDITION)) and ok

	# Applying it builds the loop's collection expression with the row's params baked in.
	var apply_script: Script = load("res://addons/eventsheet/editor/dock/ace_apply.gd")
	var collection: String = apply_script.call("build_looping_collection", definition, {"text": "blob"})
	ok = _check("the applied collection is the baked template", collection,
		"blob.replace(\"\\r\\n\", \"\\n\").replace(\"\\r\", \"\\n\").split(\"\\n\", false)") and ok

	# And that pick filter compiles to a plain for loop with the iterator's name.
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	var row: EventRow = EventRow.new()
	row.trigger_provider_id = "Core"
	row.trigger_id = "OnReady"
	var pick: PickFilter = PickFilter.new()
	pick.collection_kind = PickFilter.CollectionKind.EXPRESSION
	pick.collection_value = collection
	pick.iterator_name = str(definition.metadata.get("looping_iterator", "item"))
	row.pick_filters.append(pick)
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "Print"
	action.codegen_template = "print(line)"
	row.actions.append(action)
	sheet.events.append(row)
	var output: String = str(SheetCompiler.compile(sheet, "user://table_aces_loop_probe.gd").get("output", ""))
	ok = _check("the looping condition compiles as a for over the collection",
		output.contains("for line in " + collection + ":"), true) and ok
	ok = _check("the event's action runs inside that loop", output.contains("\t\tprint(line)"), true) and ok
	if FileAccess.file_exists("user://table_aces_loop_probe.gd"):
		DirAccess.remove_absolute("user://table_aces_loop_probe.gd")
	ok = _run_looping_apply_routes(definition) and ok
	return ok


## EVERY route that can put a picked condition on a row has to notice a looping one, not just the
## append route. A looping condition's template returns a COLLECTION, so landing it in `conditions`
## compiles it into the `if` and the sheet stops parsing ("Identifier \"line\" not declared") - while
## the row still LOOKS right in the viewport, which is what makes it worth a test rather than a read.
## These are the first BUILTIN looping conditions, so the standard picker reaches these routes in
## every project; before this they were only reachable through a pack that declared @ace_looping.
static func _run_looping_apply_routes(definition: ACEDefinition) -> bool:
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	var row: EventRow = EventRow.new()
	row.trigger_provider_id = "Core"
	row.trigger_id = "OnReady"
	var placeholder: ACECondition = ACECondition.new()
	placeholder.provider_id = "Core"
	placeholder.ace_id = "CompareValues"
	placeholder.codegen_template = "1 == 1"
	row.conditions.append(placeholder)
	sheet.events.append(row)
	dock.setup(sheet)

	# Clicking an existing condition cell and picking For Each Line In Text out of the picker.
	dock._ace_apply._apply_ace_definition(definition, {"text": "blob"}, {
		"mode": "replace_condition", "selected_resource": row, "ace_index": 0})
	var ok: bool = _check("replacing a condition with a looping one leaves no condition behind",
		row.conditions.size(), 0)
	ok = _check("it lands in the loop lane instead", row.pick_filters.size(), 1) and ok
	if row.pick_filters.size() == 1:
		ok = _check("carrying the collection expression",
			str((row.pick_filters[0] as PickFilter).collection_value),
			"blob.replace(\"\\r\\n\", \"\\n\").replace(\"\\r\", \"\\n\").split(\"\\n\", false)") and ok
		ok = _check("and the iterator the verb names",
			str((row.pick_filters[0] as PickFilter).iterator_name), "line") and ok

	# The whole point: what that row compiles to has to PARSE. A collection in the if-term does not.
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "Print"
	action.codegen_template = "print(line)"
	row.actions.append(action)
	var compiled_output: String = str(SheetCompiler.compile(sheet, "user://table_aces_route_probe.gd").get("output", ""))
	var compiled: GDScript = GDScript.new()
	compiled.source_code = compiled_output.replace("blob", "\"a\\nb\"")
	ok = _check("and the sheet it produces really parses", compiled.reload(true), OK) and ok
	if FileAccess.file_exists("user://table_aces_route_probe.gd"):
		DirAccess.remove_absolute("user://table_aces_route_probe.gd")

	# The batch route sweeps the CONDITIONS lane, where a looping condition never lives - so there is
	# nothing to update, and building one there would write the same unparseable row.
	var batch_row: EventRow = EventRow.new()
	batch_row.trigger_provider_id = "Core"
	batch_row.trigger_id = "OnReady"
	var plain: ACECondition = ACECondition.new()
	plain.provider_id = "Core"
	plain.ace_id = "ForEachLineInText"
	plain.codegen_template = "1 == 1"
	batch_row.conditions.append(plain)
	sheet.events.append(batch_row)
	dock._ace_apply._apply_ace_definition(definition, {"text": "blob"}, {
		"mode": "batch_edit_params", "selected_resource": batch_row, "batch_kind": "condition",
		"batch_targets": [{"event": batch_row, "index": 0}]})
	ok = _check("a batch edit never puts a looping condition in the if-lane",
		str((batch_row.conditions[0] as ACECondition).codegen_template), "1 == 1") and ok
	ok = _check("and adds no loop behind the author's back", batch_row.pick_filters.size(), 0) and ok
	dock.free()
	return ok


## What the three loops actually walk, at runtime.
static func _run_looping_runtime() -> bool:
	var ok: bool = true

	var lines: Array = _as_array(_eval(_emitted("ForEachLineInText", {"text": _quote("a\r\nb\n\nc\n")})))
	ok = _check("lines are split, blanks dropped and carriage returns gone", lines, ["a", "b", "c"] as Array) and ok
	ok = _check("empty text walks nothing", _as_array(_eval(_emitted("ForEachLineInText", {"text": "\"\""}))).size(), 0) and ok

	var parts: Array = _as_array(_eval(_emitted("ForEachPartInText", {"text": _quote(" a; b ;;c "), "separator": "\";\""})))
	ok = _check("parts are trimmed and blanks skipped", parts, ["a", "b", "c"] as Array) and ok
	ok = _check("text with no separator in it is one part", _as_array(_eval(_emitted("ForEachPartInText", {"text": "\"solo\"", "separator": "\",\""}))), ["solo"] as Array) and ok
	ok = _check("empty text is no parts", _as_array(_eval(_emitted("ForEachPartInText", {"text": "\"\"", "separator": "\",\""}))).size(), 0) and ok

	# A folder of data assets, with a stray non-resource file in it that must be ignored.
	DirAccess.make_dir_recursive_absolute(PROBE_ASSETS)
	var asset: Resource = Resource.new()
	asset.resource_name = "probe_entry"
	ResourceSaver.save(asset, PROBE_ASSETS + "/entry.tres")
	var stray: FileAccess = FileAccess.open(PROBE_ASSETS + "/notes.txt", FileAccess.WRITE)
	stray.store_string("not a resource")
	stray.close()
	var entries: Array = _as_array(_eval(_emitted("ForEachResourceInFolder", {"folder": _quote(PROBE_ASSETS)})))
	ok = _check("only the data assets are walked", entries.size(), 1) and ok
	ok = _check("and they arrive already loaded, not as paths",
		str((entries[0] as Resource).resource_name) if entries.size() == 1 else "<nothing loaded>", "probe_entry") and ok
	var no_folder: Array = _as_array(_eval(_emitted("ForEachResourceInFolder", {"folder": "\"user://table_aces_no_such_folder\""})))
	ok = _check("a folder that is not there walks nothing", no_folder.size(), 0) and ok
	DirAccess.remove_absolute(PROBE_ASSETS + "/entry.tres")
	DirAccess.remove_absolute(PROBE_ASSETS + "/notes.txt")
	DirAccess.remove_absolute(PROBE_ASSETS)
	return ok


## Every descriptor this module ships, by ace_id, read from the LIVE registry (so a module that
## failed to auto-discover fails here rather than passing against a direct load).
static func _by_id() -> Dictionary:
	var by_id: Dictionary = {}
	for descriptor: ACEDescriptor in EventForgeBuiltinACEs.get_descriptors():
		by_id[descriptor.ace_id] = descriptor
	return by_id


## The emitted code for one ACE with its row's params substituted - the real compiler path.
static func _emitted(ace_id: String, params: Dictionary) -> String:
	var by_id: Dictionary = _by_id()
	if not by_id.has(ace_id):
		return ""
	return ActionCodegen._apply_template(str(by_id[ace_id].codegen_template), params)


## Runs an emitted expression for real: builds it into a GDScript, reloads it, and returns what it
## evaluates to. This is what "the behaviour is proven" means here - the pinned text is also run.
static func _eval(expression: String) -> Variant:
	var script: GDScript = GDScript.new()
	script.source_code = "@tool\nextends RefCounted\n\n\nstatic func probe() -> Variant:\n\treturn %s\n" % expression
	if script.reload() != OK:
		print("  [FAIL] table_aces_test: an emitted expression did not compile: %s" % expression)
		return null
	return script.call("probe")


## The parsed table for a blob of spreadsheet text, through the shipped Table From Text template.
static func _table_from_text(text: String, separator: String = "\",\"") -> Variant:
	return _eval(_emitted("TableFromText", {"text": _quote(text), "separator": separator}))


## The Table From Text expression for a blob, as source to nest inside another expression.
static func _quote_table(text: String) -> String:
	return _emitted("TableFromText", {"text": _quote(text), "separator": "\",\""})


## A GDScript string literal for arbitrary text (c_escape covers the quotes, backslashes and the
## \r / \n this test deliberately feeds in).
static func _quote(text: String) -> String:
	return "\"%s\"" % text.c_escape()


static func _size(table: Variant) -> int:
	return (table as Array).size() if table is Array else -1


## Any collection an emitted expression can return (Array or a packed one) as a plain Array, and
## anything else - a compile failure that returned null above all - as an empty one, so a broken
## expression FAILS a check instead of crashing the run out from under the verdict line.
static func _as_array(value: Variant) -> Array:
	if value is Array:
		return value as Array
	if value is PackedStringArray:
		return Array(value as PackedStringArray)
	return []


static func _field(table: Variant, index: int, key: String) -> String:
	if not (table is Array) or index >= (table as Array).size():
		return "<no such row>"
	return str(((table as Array)[index] as Dictionary).get(key, "<no such column>"))


static func _keys(table: Variant, index: int) -> Array:
	if not (table is Array) or index >= (table as Array).size():
		return []
	return ((table as Array)[index] as Dictionary).keys()


static func _display_name(by_id: Dictionary, ace_id: String) -> String:
	return str(by_id[ace_id].display_name) if by_id.has(ace_id) else ""


static func _category(by_id: Dictionary, ace_id: String) -> String:
	return str(by_id[ace_id].category) if by_id.has(ace_id) else ""


static func _param_default(by_id: Dictionary, ace_id: String, param_id: String) -> String:
	if not by_id.has(ace_id):
		return ""
	for param: ACEParam in by_id[ace_id].params:
		if param.id == param_id:
			return str(param.default_value)
	return ""


static func _first_option_label(by_id: Dictionary, ace_id: String, param_id: String) -> String:
	if not by_id.has(ace_id):
		return ""
	for param: ACEParam in by_id[ace_id].params:
		if param.id == param_id and not param.options.is_empty():
			return str((param.options[0] as Dictionary).get("label", ""))
	return ""


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		return true
	print("  [FAIL] table_aces_test: %s (got %s, expected %s)" % [label, str(actual), str(expected)])
	return false
