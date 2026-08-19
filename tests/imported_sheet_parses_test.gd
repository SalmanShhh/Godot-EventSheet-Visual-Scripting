@tool
class_name ImportedSheetParsesTest
extends RefCounted

# An imported sheet has to WRITE A FILE THAT LOADS. Compiling without errors is not the same claim:
# the compiler assembles text, and text can assemble cleanly and still be refused by the parser.
# Every case below is one that used to assemble cleanly and then fail to load, so each one hands the
# emitted source to GDScript itself and asks.
#
# They are built the way an export arrives - a tree of blocks tagged by eventType - rather than as
# hand-made rows, so the whole path from the other editor's words to a loadable file is under test.


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _comparisons() and all_passed
	all_passed = _missing_parameter() and all_passed
	all_passed = _unspellable_rows_still_parse() and all_passed
	all_passed = _two_elses() and all_passed
	all_passed = _orphan_else_is_said_out_loud() and all_passed
	all_passed = _a_list_that_is_not_a_list() and all_passed
	all_passed = _values_only_the_other_editor_knows() and all_passed
	return all_passed


## Two ways a value used to arrive looking translated when it was not: a call the expression table
## knows the NAME of but met at an arity it does not, and a mouse button nobody can name.
static func _values_only_the_other_editor_knows() -> bool:
	var passed: bool = true
	var four: Dictionary = EventSheetForeignACEMap.translate_expression("angle(1, 2, 3, 4)")
	passed = _check("a call at an arity nothing here spells is flagged", four["translated"], false) and passed
	passed = _check("and it is kept exactly as written", str(four["text"]), "angle(1, 2, 3, 4)") and passed
	passed = _check("the arity the table does know is still rewritten",
		str(EventSheetForeignACEMap.translate_expression("random(1, 6)")["text"]), "randf_range(1, 6)") and passed
	var button: Dictionary = EventSheetForeignACEMap.translate_button("3")
	passed = _check("a mouse button nobody can name is not handed a key constant", str(button["text"]), "3") and passed
	passed = _check("and it is flagged", button["translated"], false) and passed
	passed = _check("a letter key is still its own key", str(EventSheetForeignACEMap.translate_key("g")["text"]), "KEY_G") and passed
	return passed


## The other editor spells equality `=` and inequality `<>`, and writes the comparison as its place
## in the drop-down as often as its symbol. Left as written, `=` is an ASSIGNMENT and the file does
## not load.
static func _comparisons() -> bool:
	var passed: bool = true
	passed = _check("a lone = is equality", str(EventSheetForeignACEMap.translate_comparison("=")["text"]), "==") and passed
	passed = _check("<> is inequality", str(EventSheetForeignACEMap.translate_comparison("<>")["text"]), "!=") and passed
	passed = _check("the drop-down's fifth place is >=", str(EventSheetForeignACEMap.translate_comparison("5")["text"]), ">=") and passed
	passed = _check("a comparison nobody can name is refused",
		EventSheetForeignACEMap.translate_comparison("approximately")["translated"], false) and passed

	var emitted: String = _emit([
		_variable("Score", "10"),
		_block([_condition("System", "compare-variable", {"Variable": "Score", "Comparison": "=", "Value": "10"})],
			[_action("Browser", "log", {"Message": "\"equal\""})]),
	])
	passed = _check("the emitted comparison is an equality test", emitted.contains("if score == 10:"), true) and passed
	passed = _check("the file a = wrote loads", _parses(emitted), true) and passed

	var refused: Dictionary = _import([
		_block([_condition("System", "compare-variable", {"Variable": "Score", "Comparison": "approximately", "Value": "10"})],
			[_action("Browser", "log", {"Message": "\"nope\""})]),
	])
	passed = _check("a comparison nobody can name switches the row off, with a reason",
		_reasons(refused), "No comparison here is spelled \"approximately\".") and passed
	return passed


## A mapping fills a row's slots from named parameters in the export. When the export carries no
## such parameter the slot used to be filled with nothing at all, which wrote `Vector2(, )`.
static func _missing_parameter() -> bool:
	var passed: bool = true
	var objects: Dictionary = {"Player": {"kind": "Sprite", "node": "$Player"}}
	var imported: Dictionary = _import([_block([], [_action("Player", "set-position", {})])], objects)
	passed = _check("a row whose slot the export did not carry is switched off",
		_reasons(imported), "The export carried no \"X\" for this row.") and passed
	var emitted: String = str(SheetCompiler.compile(imported["sheet"] as EventSheetResource, "", true)["output"])
	passed = _check("nothing half-written reaches the file", emitted.contains("Vector2(, )"), false) and passed
	passed = _check("the file loads", _parses(emitted), true) and passed

	var filled: Dictionary = _import([_block([], [_action("Player", "set-position", {"X": "10", "Y": "20"})])], objects)
	var filled_text: String = str(SheetCompiler.compile(filled["sheet"] as EventSheetResource, "", true)["output"])
	passed = _check("a row whose slots the export DID carry is written in full",
		filled_text.contains("$Player.position = Vector2(10, 20)"), true) and passed
	return passed


## An event every one of whose rows was unspellable keeps their original words as comments - and a
## body of nothing but comments is not a body at all as far as the parser is concerned.
static func _unspellable_rows_still_parse() -> bool:
	var passed: bool = true
	var emitted: String = _emit([_block([], [{"type": "script", "script": "runtime.globalVars.score += 1;"}])])
	passed = _check("the original words survive", emitted.contains("globalVars"), true) and passed
	passed = _check("a body of nothing but comments still loads", _parses(emitted), true) and passed
	passed = _check("the body says it does nothing", emitted.contains("\tpass"), true) and passed
	return passed


## Two Else rows one after the other used to write `else:` twice under the same `if`.
static func _two_elses() -> bool:
	var passed: bool = true
	var emitted: String = _emit([
		_variable("Score", "1"),
		_block([_condition("System", "compare-variable", {"Variable": "Score", "Comparison": "=", "Value": "1"})],
			[_action("Browser", "log", {"Message": "\"first\""})]),
		_else([_action("Browser", "log", {"Message": "\"second\""})]),
		_else([_action("Browser", "log", {"Message": "\"third\""})]),
	])
	passed = _check("the chain has exactly one else", emitted.count("else:"), 1) and passed
	passed = _check("no row was lost", emitted.contains("\"third\""), true) and passed
	passed = _check("two Elses in a row still load", _parses(emitted), true) and passed
	return passed


## An Else with no event in front of it has no "otherwise" to be, so its actions end up running
## every time. That is a change of meaning and belongs in the report, not in the running game.
static func _orphan_else_is_said_out_loud() -> bool:
	var imported: Dictionary = _import([_else([_action("Browser", "log", {"Message": "\"orphan\""})])])
	var notes: Array = (imported["report"] as Dictionary)["notes"] as Array
	return _check("an Else with nothing before it is called out", str(notes[0]) if not notes.is_empty() else "",
		"An Else here had no event before it to stand under, so its actions now run every time. Give it a condition of its own, or move it under the event it belongs to.")


## A hand-edited export whose `events` is not a list is refused at the door rather than half-read.
static func _a_list_that_is_not_a_list() -> bool:
	var path: String = "user://foreign_events_not_a_list_%d.json" % OS.get_process_id()
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{\"name\": \"Odd\", \"events\": \"nope\"}")
	file.close()
	var read: Dictionary = EventSheetForeignImporter.read_sheet_file(path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return _check("a sheet whose events are not a list is refused", str(read["error"]),
		"That file is not an exported event sheet.")


# --- the little export builders ---------------------------------------------------------------


static func _import(events: Array, objects: Dictionary = {}) -> Dictionary:
	return EventSheetForeignImporter.import_sheet({"name": "Fixture", "events": events}, objects)


static func _emit(events: Array, objects: Dictionary = {}) -> String:
	return str(SheetCompiler.compile(_import(events, objects)["sheet"] as EventSheetResource, "", true)["output"])


static func _block(conditions: Array, actions: Array) -> Dictionary:
	return {"eventType": "block", "conditions": conditions, "actions": actions, "children": []}


static func _else(actions: Array) -> Dictionary:
	return {"eventType": "block", "isElse": true, "conditions": [], "actions": actions, "children": []}


static func _condition(object_class: String, row_id: String, parameters: Dictionary) -> Dictionary:
	return {"objectClass": object_class, "id": row_id, "parameters": parameters}


static func _action(object_class: String, row_id: String, parameters: Dictionary) -> Dictionary:
	return {"objectClass": object_class, "id": row_id, "parameters": parameters}


static func _variable(name: String, initial: String) -> Dictionary:
	return {"eventType": "variable", "name": name, "type": "number", "initialValue": initial}


static func _reasons(imported: Dictionary) -> String:
	var out: PackedStringArray = PackedStringArray()
	for entry: Dictionary in (imported["report"] as Dictionary)["unmapped"] as Array:
		out.append(str(entry["reason"]))
	return " | ".join(out)


## The one question this whole file exists to ask: does GDScript itself accept what was written?
static func _parses(source: String) -> bool:
	var script: GDScript = GDScript.new()
	script.source_code = source
	return script.reload() == OK


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] imported_sheet_parses_test: %s" % label)
		return true
	print("[FAIL] imported_sheet_parses_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
