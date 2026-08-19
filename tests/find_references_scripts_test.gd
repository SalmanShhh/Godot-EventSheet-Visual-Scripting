# Godot EventSheets - Find all references reaches the `.gd` sheets nobody has opened, and a
# cross-sheet result carries the line it has to land on.
#
# The gap this closes is quiet and expensive: `list_project_sheets()` only knows `.tres`, but `.gd`
# is the DEFAULT sheet format - so Find all references answered "3 sheets" for a project with thirty,
# and a project-wide rename built on it would have missed most of its uses.
@tool
class_name FindReferencesScriptsTest
extends RefCounted

const PROBE_DIR := "res://eventsheets_find_probe"


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _test_project_scripts_walk() and all_passed
	all_passed = _test_unopened_script_is_found() and all_passed
	all_passed = _test_source_lines_are_stamped() and all_passed
	return all_passed


## The cheap half: a walk of the project's own `.gd` files that never loads one, and never wanders
## into plugin code (this plugin's own thousands of scripts are not the reader's sheets).
static func _test_project_scripts_walk() -> bool:
	var passed: bool = true
	_write_probe("probe_player.gd", "extends Node\n\n\nfunc _ready() -> void:\n\tvar shield_charge: int = 3\n\tprint(shield_charge)\n")
	var scripts: PackedStringArray = EventSheetFindReferences.project_scripts()
	passed = _check("the walk finds a project script",
		scripts.has(PROBE_DIR.path_join("probe_player.gd")), true) and passed
	var wandered: bool = false
	for path: String in scripts:
		if path.begins_with("res://addons"):
			wandered = true
	passed = _check("the walk stays out of res://addons", wandered, false) and passed
	# Sorted, so two searches list the same files in the same order.
	var sorted_copy: PackedStringArray = scripts.duplicate()
	sorted_copy.sort()
	passed = _check("the walk is in a stable order", scripts, sorted_copy) and passed
	_clear_probes()
	return passed


## The whole point: a symbol used only in an unopened `.gd` is found, and one used nowhere is not.
static func _test_unopened_script_is_found() -> bool:
	var passed: bool = true
	_write_probe("probe_player.gd", "extends Node\n\n\nfunc _ready() -> void:\n\tvar shield_charge: int = 3\n\tprint(shield_charge)\n")
	var found: Array = EventSheetFindReferences.find_in_project("shield_charge")
	var probe_hits: int = 0
	for entry: Dictionary in found:
		if str(entry.get("sheet", "")) == PROBE_DIR.path_join("probe_player.gd"):
			probe_hits = int(entry.get("count", 0))
	passed = _check("a symbol in an unopened .gd is found", probe_hits > 0, true) and passed
	# Whole-symbol matching still holds across the new pass: `shield` must not match `shield_charge`.
	var partial: Array = EventSheetFindReferences.find_in_project("shield")
	var partial_hits: int = 0
	for entry: Dictionary in partial:
		if str(entry.get("sheet", "")) == PROBE_DIR.path_join("probe_player.gd"):
			partial_hits = int(entry.get("count", 0))
	passed = _check("a partial word is still not a reference", partial_hits, 0) and passed
	_clear_probes()
	return passed


## Every reference carries the line its row emits at, because the row resource itself cannot survive
## a jump into another sheet - opening one builds a brand new resource tree.
static func _test_source_lines_are_stamped() -> bool:
	var passed: bool = true
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnReady"
	var body: RawCodeRow = RawCodeRow.new()
	body.code = "var shield_charge: int = 3\nprint(shield_charge)"
	event.actions.append(body)
	sheet.events.append(event)
	var references: Array = EventSheetFindReferences.find_in_sheet(sheet, "shield_charge")
	passed = _check("the row is found before stamping", references.size(), 1) and passed
	passed = _check("and carries no line yet",
		int((references[0] as Dictionary).get("line", 0)), 0) and passed
	EventSheetFindReferences.stamp_source_lines(sheet, references)
	# The exact number is the compiler's business; what this pins is that a line was found AND that it
	# points at the row's own code rather than at line 1 (the `extends` header).
	var line: int = int((references[0] as Dictionary).get("line", 0))
	passed = _check("stamping gives the reference a line", line > 1, true) and passed
	var compiled: String = str(SheetCompiler.compile(sheet, "").get("output", ""))
	var lines: PackedStringArray = compiled.split("\n")
	passed = _check("and the line really holds the symbol",
		line <= lines.size() and lines[line - 1].contains("shield_charge"), true) and passed
	return passed


static func _write_probe(file_name: String, source: String) -> void:
	DirAccess.make_dir_recursive_absolute(PROBE_DIR)
	var file: FileAccess = FileAccess.open(PROBE_DIR.path_join(file_name), FileAccess.WRITE)
	if file != null:
		file.store_string(source)
		file.close()


static func _clear_probes() -> void:
	var dir: DirAccess = DirAccess.open(PROBE_DIR)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		DirAccess.remove_absolute(PROBE_DIR.path_join(file_name))
	DirAccess.remove_absolute(PROBE_DIR)


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual != expected:
		print("  [FAIL] %s (got %s, expected %s)" % [label, actual, expected])
		return false
	print("[PASS] find_references_scripts_test: %s" % label)
	return true
