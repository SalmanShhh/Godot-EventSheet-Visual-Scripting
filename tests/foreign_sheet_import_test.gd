@tool
class_name ForeignSheetImportTest
extends RefCounted

# Importing an event sheet exported from another event-sheet editor.
#
# The fixture beside this file is hand-authored in the public export format: a tree of event blocks
# tagged by eventType, with conditions and actions carrying objectClass / id / parameters. It is
# deliberately mixed - rows the vocabulary knows, a behaviour row a shipped pack covers instead, a
# row nothing here spells, a script block, a group, a comment, a variable, an include and a
# function - so the counts below are the honesty contract, not a smoke test.

const FIXTURE: String = "res://tests/fixtures/foreign_event_sheet.json"

const OBJECT_MAP: Dictionary = {
	"Player": {"kind": "Sprite", "node": "$Player"},
	"Enemy": {"kind": "Sprite", "node": "$Enemy"},
	"ScoreLabel": {"kind": "Text", "node": "$ScoreLabel"},
}


static func run() -> bool:
	var all_passed: bool = true
	var read: Dictionary = EventSheetForeignImporter.read_sheet_file(FIXTURE)
	all_passed = _check("the exported sheet is read", read["ok"], true) and all_passed
	var json: Dictionary = read["sheet"] as Dictionary
	all_passed = _check("the objects the sheet mentions", str(EventSheetForeignImporter.object_names(json)),
		"[\"Enemy\", \"Player\", \"ScoreLabel\"]") and all_passed

	var imported: Dictionary = EventSheetForeignImporter.import_sheet(json, OBJECT_MAP)
	var sheet: EventSheetResource = imported["sheet"] as EventSheetResource
	var report: Dictionary = imported["report"] as Dictionary
	all_passed = _check("the report is exact", EventSheetForeignImporter.report_summary(report),
		"14 of 17 rows mapped (82%)") and all_passed
	all_passed = _check("every row that could not be mapped is named", _labels(report["unmapped"] as Array),
		"Player (Platform) ▸ is-on-floor | Enemy ▸ set-blend-mode | script block") and all_passed
	all_passed = _check("a behaviour a shipped pack covers says so", str((report["unmapped"] as Array)[0]["reason"]),
		"The shipped Platformer Movement behaviour covers this - attach it (Add behavior…) and add the row from its own words.") and all_passed
	all_passed = _check("the include is a note, not a silence", str((report["notes"] as Array)[0]),
		"This sheet included \"Shared\". Import that sheet too, then add it under Sheet > Manage Includes.") and all_passed
	all_passed = _check("nothing translatable was flagged", (report["flagged"] as Array).size(), 0) and all_passed

	var compiled: Dictionary = SheetCompiler.compile(sheet, "", true)
	all_passed = _check("the imported sheet compiles", compiled["success"], true) and all_passed
	var output: String = str(compiled["output"])
	all_passed = _check("the variable the rows name is declared", output.contains("var score: float = 0.0"), true) and all_passed
	all_passed = _check("a key name becomes the key constant",
		output.contains("event.physical_keycode == KEY_SPACE"), true) and all_passed
	all_passed = _check("an object property becomes the node property",
		output.contains("$Player.position = Vector2($Player.position.x, 200)"), true) and all_passed
	all_passed = _check("an expression name becomes the call behind it",
		output.contains("$ScoreLabel.text = str(\"%03d\" % score)"), true) and all_passed
	all_passed = _check("random becomes the call it means", output.contains("score += randf_range(1, 6)"), true) and all_passed
	all_passed = _check("Else reads as else", output.contains("\telse:"), true) and all_passed
	all_passed = _check("the function reads with its own name", output.contains("func reset_score(start: float) -> void:"), true) and all_passed
	all_passed = _check("an unmapped row keeps its original words",
		output.contains("# %s Player (Platform) ▸ is-on-floor" % EventSheetForeignImporter.UNMAPPED_MARKER), true) and all_passed
	all_passed = _check("a row nobody can spell does not run",
		output.contains("set-blend-mode\n"), false) and all_passed

	all_passed = _roundtrip(sheet) and all_passed
	all_passed = _wizard() and all_passed
	all_passed = _vocabulary_is_real() and all_passed
	all_passed = _expressions() and all_passed
	return all_passed


## The written .gd re-opens as a sheet and re-emits byte-identically: what the wizard saved is what
## the editor will keep saving.
static func _roundtrip(sheet: EventSheetResource) -> bool:
	var path: String = "user://foreign_import_roundtrip_%d.gd" % OS.get_process_id()
	var first: Dictionary = SheetCompiler.compile(sheet, path, true)
	if not bool(first["success"]):
		return _check("the imported sheet writes a .gd", str(first["errors"]), "[]")
	var reopened: EventSheetResource = GDScriptImporter.new().import_external(path)
	if reopened == null:
		return _check("the written .gd re-opens as a sheet", "null", "a sheet")
	var again: Dictionary = SheetCompiler.compile(reopened, "", true)
	var written: String = FileAccess.get_file_as_string(path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return _check("the written .gd re-opens and re-emits byte-identically", str(again["output"]) == written, true)


## The wizard walked with no window: pick a file, read the object table it built, look at the
## report. What the reader sees before saving is the same import the tests above pinned.
static func _wizard() -> bool:
	var passed: bool = true
	var host: Control = Control.new()
	var wizard: EventSheetImportSheetWizard = EventSheetImportSheetWizard.new()
	wizard.init(host)
	wizard.open()
	passed = _check("the wizard reads the exported sheet", wizard.load_source(FIXTURE), "") and passed
	passed = _check("the wizard lists the sheet's objects", str(wizard.object_map().keys()),
		"[\"Enemy\", \"Player\", \"ScoreLabel\"]") and passed
	passed = _check("the wizard's report leads with the count",
		wizard.report_text().begins_with("[b]14 of 17 rows mapped (82%)[/b]"), true) and passed
	passed = _check("the wizard names what it could not spell",
		wizard.report_text().contains("Switched off: [b]Enemy ▸ set-blend-mode[/b]"), true) and passed
	passed = _check("a file that is not an exported sheet is refused",
		wizard.load_source("res://tests/fixtures/nothing_here.json"), "That file does not exist.") and passed
	host.free()
	return passed


## Every ace_id and every parameter id the map names is one the registry really ships. A renamed
## parameter fails here rather than in somebody's imported project.
static func _vocabulary_is_real() -> bool:
	var passed: bool = true
	var checked: int = 0
	for key: String in EventSheetForeignACEMap.ROWS:
		var entry: Dictionary = EventSheetForeignACEMap.ROWS[key] as Dictionary
		var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", str(entry["ace"]))
		if descriptor == null:
			passed = _check("%s names a shipped row" % key, "missing", str(entry["ace"])) and passed
			continue
		var known: Dictionary = {}
		for param: ACEParam in descriptor.params:
			known[param.id] = true
		for param_id: String in (entry.get("params", {}) as Dictionary):
			if not known.has(param_id):
				passed = _check("%s fills a parameter %s has" % [key, entry["ace"]], param_id, str(known.keys())) and passed
		checked += 1
	for entry_key: String in EventSheetForeignACEMap.ROWS:
		if str((EventSheetForeignACEMap.ROWS[entry_key] as Dictionary).get("trigger", "")).is_empty():
			continue
		var trigger_id: String = str((EventSheetForeignACEMap.ROWS[entry_key] as Dictionary)["trigger"])
		if ACERegistry.find_descriptor("Core", trigger_id) == null:
			passed = _check("%s opens a shipped trigger" % entry_key, "missing", trigger_id) and passed
	return _check("every mapped row names a shipped row", checked, EventSheetForeignACEMap.ROWS.size()) and passed


## The expression table is the exact inverse of the reading layer's: what a reader types on one
## side is what the compiler emits on the other.
static func _expressions() -> bool:
	var passed: bool = true
	passed = _check("random becomes randf_range", str(EventSheetForeignACEMap.translate_expression("random(1, 6)")["text"]), "randf_range(1, 6)") and passed
	passed = _check("choose becomes pick_random", str(EventSheetForeignACEMap.translate_expression("choose(1, 2, 3)")["text"]), "[1, 2, 3].pick_random()") and passed
	passed = _check("len becomes length", str(EventSheetForeignACEMap.translate_expression("len(word)")["text"]), "word.length()") and passed
	passed = _check("distance becomes distance_to", str(EventSheetForeignACEMap.translate_expression("distance(a, b)")["text"]), "a.position.distance_to(b.position)") and passed
	passed = _check("clamp is spelled the same in both", str(EventSheetForeignACEMap.translate_expression("clamp(x, 0, 1)")["text"]), "clamp(x, 0, 1)") and passed
	passed = _check("a shape only the other editor knows is not translated", EventSheetForeignACEMap.translate_expression("Sprite.BlendMode")["translated"], false) and passed
	passed = _check("a key nobody here can name is flagged", EventSheetForeignACEMap.translate_key("Rocket")["translated"], false) and passed
	passed = _check("a named key becomes its constant", str(EventSheetForeignACEMap.translate_key("Left arrow")["text"]), "KEY_LEFT") and passed
	return passed


static func _labels(entries: Array) -> String:
	var out: PackedStringArray = PackedStringArray()
	for entry: Dictionary in entries:
		out.append(str(entry["label"]))
	return " | ".join(out)


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] foreign_sheet_import_test: %s" % label)
		return true
	print("[FAIL] foreign_sheet_import_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
