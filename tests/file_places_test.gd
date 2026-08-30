# Godot EventSheets - the places a path names, the visible guard, and the two export traps.
#
# What it proves, in the order a reader meets it:
#   1. THE PLACE. Every path expression the file vocabulary can hold reads back as one of the four
#      places, and a path built at run time reads back as none of them rather than as a guess.
#   2. THE LEAD. Each place has the muted sentence that goes under the field, and an unreadable place
#      has no sentence at all - a lead that guessed would be worse than no lead.
#   3. THE VISIBLE GUARD. Read Text File (or a fallback) compiles to the file_exists ternary with the
#      fallback the row holds, and to the PLAIN read when the fallback is left blank. Both are run,
#      not just compared - a ternary that reads right and parses wrong is the whole point of running
#      the emitted code.
#   4. THE FOLDER PRELUDE. The write that makes its folder emits the make_dir_recursive line ABOVE
#      the write when the row says so and nothing at all when it says the folder is already there.
#   5. THE TWO DOCTOR CHECKS AND THE DOOR, each pinned on a bug fixture AND on a clean twin - a check
#      that fires is only half the answer; the half that matters on somebody's own project is that it
#      stays quiet on a correct one.
#   6. THE FIXES. Each one's receipt says what the value read as and what it reads as now, and the
#      rewrite really moves the value.
#   7. THE LIFT. The spellings a project already has - the plain read, the guarded ternary, the
#      open/get_as_text pair and the folder prelude - open as rows and save back BYTE-IDENTICALLY.
#
# Values are pinned, never counts: a count tells nobody which sentence moved.
@tool
class_name FilePlacesTest
extends RefCounted

const P := preload("res://addons/eventforge/registration/file_places.gd")

## Where the round-trip half writes. Under user:// because that is the only place a test may write,
## which is the lesson this whole file is about.
const TEST_DIR := "user://__fileplaces_test"


static func run() -> bool:
	var passed: bool = true
	passed = _test_places() and passed
	passed = _test_leads() and passed
	passed = _test_visible_guard() and passed
	passed = _test_folder_prelude() and passed
	passed = _test_doctor_checks() and passed
	passed = _test_fixes() and passed
	passed = _test_lifts() and passed
	return passed


# ── 1. The place a path names ────────────────────────────────────────────────────────────────


static func _test_places() -> bool:
	var passed: bool = true
	passed = _check("a user:// literal is the player's folder",
		P.place_of("\"user://save.dat\""), P.PLACE_USER) and passed
	passed = _check("a res:// literal is the game's own files",
		P.place_of("\"res://levels/one.tres\""), P.PLACE_RES) and passed
	passed = _check("a Windows drive letter is an absolute path",
		P.place_of("\"D:/games/save.dat\""), P.PLACE_ABSOLUTE) and passed
	passed = _check("a POSIX root is an absolute path",
		P.place_of("\"/var/tmp/save.dat\""), P.PLACE_ABSOLUTE) and passed
	# The honest silence: a path the sheet builds while the game runs has a place nobody can read off
	# the field, and reading one anyway is how a correct row gets a warning on it.
	passed = _check("a built path has no place to read",
		P.place_of("\"user://slot_%d.dat\" % slot"), P.PLACE_UNKNOWN) and passed
	passed = _check("a built path still LEADS somewhere",
		P.leading_place_of("\"user://slot_%d.dat\" % slot"), P.PLACE_USER) and passed
	passed = _check("a bare variable leads nowhere",
		P.leading_place_of("save_path"), P.PLACE_UNKNOWN) and passed
	# The rewrites the two fixes offer.
	passed = _check("res:// rewrites under user:// keeping everything below the scheme",
		P.under_user("res://saves/slot1.dat"), "user://saves/slot1.dat") and passed
	passed = _check("an absolute path keeps only its file name",
		P.under_user("D:/games/My Game/save.dat"), "user://save.dat") and passed
	passed = _check("an absolute path may also become a shipped file",
		P.under_res("D:/games/My Game/level.tres"), "res://level.tres") and passed
	passed = _check("a user:// path has nothing to rewrite", P.under_user("user://save.dat"), "") and passed
	passed = _check("the rewrite goes back in the quotes it came out of",
		P.requote("\"res://a.dat\"", "user://a.dat"), "\"user://a.dat\"") and passed
	# Which verbs write, and which parameter of each carries the path it writes to.
	passed = _check("Write Text File writes", P.writes("WriteTextFile"), true) and passed
	passed = _check("Read Text File does not write", P.writes("ReadTextFile"), false) and passed
	passed = _check("a copy writes to its destination and not to its source",
		P.write_params_of("CopyFile"), PackedStringArray(["to"])) and passed
	passed = _check("a copy has two paths in it",
		P.path_params_of("CopyFile"), PackedStringArray(["from", "to"])) and passed
	passed = _check("a path with folders in it is known by that",
		P.has_folders("\"user://runs/latest.txt\""), true) and passed
	passed = _check("a path at the root of user:// has no folders",
		P.has_folders("\"user://save.dat\""), false) and passed
	return passed


# ── 2. The muted lead ────────────────────────────────────────────────────────────────────────


static func _test_leads() -> bool:
	var passed: bool = true
	passed = _check("the user:// lead",
		P.lead_for(P.PLACE_USER),
		"user:// - the player's folder: writable, one per player, survives updates.") and passed
	passed = _check("the res:// lead",
		P.lead_for(P.PLACE_RES),
		"res:// - the game's own files: READ-ONLY once exported.") and passed
	passed = _check("the absolute-path lead",
		P.lead_for(P.PLACE_ABSOLUTE),
		"an absolute path: this folder exists on one computer and nowhere else.") and passed
	passed = _check("a place nobody can read has no lead", P.lead_for(P.PLACE_UNKNOWN), "") and passed
	passed = _check("the lead under a written field reads the field",
		P.lead_for_path("\"res://save.dat\""),
		"res:// - the game's own files: READ-ONLY once exported.") and passed
	passed = _check("the strip says where user:// really is on Windows",
		P.where_user_lives().contains("%APPDATA%"), true) and passed
	passed = _check("the strip says where user:// really is on macOS",
		P.where_user_lives().contains("~/Library/Application Support/Godot"), true) and passed
	passed = _check("the strip says where user:// really is on Linux",
		P.where_user_lives().contains("~/.local/share/godot"), true) and passed
	return passed


# ── 3. The visible guard ─────────────────────────────────────────────────────────────────────


static func _test_visible_guard() -> bool:
	var passed: bool = true
	var by_id: Dictionary = _descriptors()
	passed = _check("the guarded read ships beside the frozen one",
		by_id.has("ReadTextFileOr"), true) and passed
	passed = _check("the frozen read is untouched",
		str(by_id["ReadTextFile"].codegen_template),
		"FileAccess.get_file_as_string({path})") and passed
	# The one spelling of the guard, and the two shapes it collapses to.
	passed = _check("a named fallback emits the file_exists ternary",
		P.guarded_read("\"user://save.dat\"", "\"none\""),
		"FileAccess.get_file_as_string(\"user://save.dat\") if FileAccess.file_exists(\"user://save.dat\") else \"none\"") and passed
	passed = _check("no fallback emits the plain read",
		P.guarded_read("\"user://save.dat\"", ""),
		"FileAccess.get_file_as_string(\"user://save.dat\")") and passed
	# The same two shapes THROUGH THE TEMPLATE, which is what the compiler really reads.
	var template: String = str(by_id["ReadTextFileOr"].codegen_template)
	passed = _check("the template collapses to the ternary when a fallback is held",
		_emit(template, {"path": "\"user://save.dat\"", "fallback": "\"none\""}),
		P.guarded_read("\"user://save.dat\"", "\"none\"")) and passed
	passed = _check("the template collapses to the plain read when the fallback is blank",
		_emit(template, {"path": "\"user://save.dat\"", "fallback": ""}),
		P.guarded_read("\"user://save.dat\"", "")) and passed
	# And it RUNS: an emitted ternary that reads right and parses wrong is exactly the failure this
	# whole vocabulary exists to end.
	var read_back: Variant = _run_expression(_emit(template,
		{"path": "\"%s/nothing.txt\"" % TEST_DIR, "fallback": "\"the fallback\""}))
	passed = _check("the guarded read really answers the fallback for a missing file",
		read_back, "the fallback") and passed
	return passed


# ── 4. The folder prelude ────────────────────────────────────────────────────────────────────


static func _test_folder_prelude() -> bool:
	var passed: bool = true
	var by_id: Dictionary = _descriptors()
	var template: String = str(by_id["WriteTextFileInFolder"].codegen_template).replace("{uid}", "w1")
	var made: String = _emit(template, {"path": "\"user://runs/latest.txt\"", "text": "\"hi\"",
		"folder": "make its folder first"})
	passed = _check("the prelude is the make_dir_recursive line, above the write",
		made.split("\n")[0],
		"DirAccess.make_dir_recursive_absolute(\"user://runs/latest.txt\".get_base_dir())") and passed
	passed = _check("the prelude is exactly what the one reading of it writes",
		made.split("\n")[0], P.make_folder_prelude("\"user://runs/latest.txt\"")) and passed
	passed = _check("the write itself follows it unchanged", made.split("\n")[1],
		"var __file_w1 = FileAccess.open(\"user://runs/latest.txt\", FileAccess.WRITE)") and passed
	var assumed: String = _emit(template, {"path": "\"user://runs/latest.txt\"", "text": "\"hi\"",
		"folder": "its folder is already there"})
	passed = _check("the other choice emits no prelude at all", assumed.split("\n")[0],
		"var __file_w1 = FileAccess.open(\"user://runs/latest.txt\", FileAccess.WRITE)") and passed
	# The door onto the player's own folder.
	passed = _check("the folder door globalizes the path before handing it to the desktop",
		str(by_id["OpenUserDataFolder"].codegen_template),
		"OS.shell_open(ProjectSettings.globalize_path({path}))") and passed
	return passed


# ── 5. The two checks, and the door ──────────────────────────────────────────────────────────


## A project with the bug in it, and its clean twin. The twin is the same file with the one thing
## fixed, so a check that fires on both is reading something else.
const BUG_RES_WRITE := "func _ready() -> void:\n\tvar file = FileAccess.open(\"res://save.dat\", FileAccess.WRITE)\n\tfile.store_string(\"x\")\n"
const CLEAN_RES_WRITE := "func _ready() -> void:\n\tvar file = FileAccess.open(\"user://save.dat\", FileAccess.WRITE)\n\tfile.store_string(\"x\")\n"
const CLEAN_RES_READ := "func _ready() -> void:\n\tvar file = FileAccess.open(\"res://level.dat\", FileAccess.READ)\n\tprint(file.get_as_text())\n"
const BUG_ABSOLUTE := "func _ready() -> void:\n\tprint(FileAccess.get_file_as_string(\"D:/games/save.dat\"))\n"
const CLEAN_ABSOLUTE := "func _ready() -> void:\n\tprint(FileAccess.get_file_as_string(\"user://save.dat\"))\n"
const BUG_UNGUARDED := "func _ready() -> void:\n\tvar text = FileAccess.get_file_as_string(\"user://save.dat\")\n"
const CLEAN_GUARDED := "func _ready() -> void:\n\tvar text = FileAccess.get_file_as_string(\"user://save.dat\") if FileAccess.file_exists(\"user://save.dat\") else \"\"\n"


static func _test_doctor_checks() -> bool:
	var passed: bool = true
	var trap: Array[Dictionary] = EventSheetFilesDoctor.res_write_findings(
		{"res://trap.gd": BUG_RES_WRITE})
	passed = _check("the export trap is one warning", _severities(trap),
		PackedStringArray(["warning"])) and passed
	passed = _check("filed under the export-trap check", _checks(trap),
		PackedStringArray([EventSheetFilesDoctor.CHECK_RES_WRITE])) and passed
	passed = _check("it names the line", str(trap[0]["subject"]),
		"var file = FileAccess.open(\"res://save.dat\", FileAccess.WRITE)") and passed
	passed = _check("it says why the editor never mentioned it",
		str(trap[0]["message"]).contains("fails in every exported build"), true) and passed
	passed = _check("the same write under user:// is silent",
		EventSheetFilesDoctor.res_write_findings({"res://ok.gd": CLEAN_RES_WRITE}).size(), 0) and passed
	# The half that matters most: READING res:// is what res:// is for, and a check that warned about
	# it would be a check people switch off.
	passed = _check("a READ of res:// is silent",
		EventSheetFilesDoctor.res_write_findings({"res://ok.gd": CLEAN_RES_READ}).size(), 0) and passed

	var absolute: Array[Dictionary] = EventSheetFilesDoctor.absolute_path_findings(
		{"res://trap.gd": BUG_ABSOLUTE})
	passed = _check("an absolute path is one warning", _severities(absolute),
		PackedStringArray(["warning"])) and passed
	passed = _check("filed under the absolute-path check", _checks(absolute),
		PackedStringArray([EventSheetFilesDoctor.CHECK_ABSOLUTE_PATH])) and passed
	passed = _check("it says whose computer the folder is on",
		str(absolute[0]["message"]).contains("names a folder on one computer"), true) and passed
	passed = _check("the same read under user:// is silent",
		EventSheetFilesDoctor.absolute_path_findings({"res://ok.gd": CLEAN_ABSOLUTE}).size(), 0) and passed

	var unguarded: Array[Dictionary] = EventSheetFilesDoctor.unguarded_read_findings(
		{"res://trap.gd": BUG_UNGUARDED})
	passed = _check("an unguarded read is a NOTE, never a warning", _severities(unguarded),
		PackedStringArray(["info"])) and passed
	passed = _check("filed under the unguarded-read check", _checks(unguarded),
		PackedStringArray([EventSheetFilesDoctor.CHECK_UNGUARDED_READ])) and passed
	passed = _check("it offers the respelling by name",
		str(unguarded[0]["message"]).contains("Read Text File (or a fallback)"), true) and passed
	passed = _check("the guarded spelling is silent - including the one the fix writes",
		EventSheetFilesDoctor.unguarded_read_findings({"res://ok.gd": CLEAN_GUARDED}).size(), 0) and passed
	# Every one of the three offers exactly one chip, and it is the one that answers it.
	for pair: Array in [[EventSheetFilesDoctor.CHECK_RES_WRITE, "write_under_user"],
			[EventSheetFilesDoctor.CHECK_ABSOLUTE_PATH, "path_under_user"],
			[EventSheetFilesDoctor.CHECK_UNGUARDED_READ, "respell_guarded_read"]]:
		var offered: Array = EventSheetQuickFixes.fixes_for({"check": str(pair[0])})
		passed = _check("%s offers one chip" % str(pair[0]), offered.size(), 1) and passed
		if offered.size() == 1:
			passed = _check("%s offers %s" % [str(pair[0]), str(pair[1])],
				str((offered[0] as Dictionary).get("id", "")), str(pair[1])) and passed
	return passed


# ── 6. The fixes, and their receipts ─────────────────────────────────────────────────────────


static func _test_fixes() -> bool:
	var passed: bool = true
	var sheet: EventSheetResource = _sheet_with([
		_action("WriteTextFile", {"path": "\"res://save.dat\"", "text": "\"x\""}),
		_action("ReadTextFile", {"path": "\"D:/games/save.dat\""}),
		_action("SetVariable", {"value": "FileAccess.get_file_as_string(\"user://save.dat\")"}),
	])
	passed = _check("the export-trap receipt names one value",
		EventSheetFilesDoctor.res_write_receipt(sheet),
		[{"before": "\"res://save.dat\"", "after": "\"user://save.dat\""}]) and passed
	passed = _check("the absolute-path receipt names one value",
		EventSheetFilesDoctor.absolute_path_receipt(sheet),
		[{"before": "\"D:/games/save.dat\"", "after": "\"user://save.dat\""}]) and passed
	passed = _check("the respelling receipt shows the guard it will write",
		EventSheetFilesDoctor.guarded_read_receipt(sheet),
		[{"before": "FileAccess.get_file_as_string(\"user://save.dat\")",
			"after": P.guarded_read("\"user://save.dat\"", "\"\"")}]) and passed
	passed = _check("the export-trap fix moves one value",
		EventSheetFilesDoctor.rewrite_res_writes(sheet), 1) and passed
	passed = _check("the absolute-path fix moves one value",
		EventSheetFilesDoctor.rewrite_absolute_paths(sheet), 1) and passed
	passed = _check("the respelling moves one value",
		EventSheetFilesDoctor.respell_guarded_reads(sheet), 1) and passed
	var row: EventRow = sheet.events[0]
	passed = _check("the write now aims at the player's folder",
		str(((row.actions[0] as ACEAction).params as Dictionary)["path"]), "\"user://save.dat\"") and passed
	passed = _check("the read is no longer on one computer",
		str(((row.actions[1] as ACEAction).params as Dictionary)["path"]), "\"user://save.dat\"") and passed
	passed = _check("the read now says what it uses when the file is missing",
		str(((row.actions[2] as ACEAction).params as Dictionary)["value"]),
		P.guarded_read("\"user://save.dat\"", "\"\"")) and passed
	# Run twice and nothing moves: a fix whose output still matches its own finding would rewrite the
	# same row every time somebody pressed the chip.
	passed = _check("the export-trap fix has nothing left to do",
		EventSheetFilesDoctor.rewrite_res_writes(sheet), 0) and passed
	passed = _check("the respelling has nothing left to do",
		EventSheetFilesDoctor.respell_guarded_reads(sheet), 0) and passed
	# A read of res:// is correct, so the export-trap fix must never touch one.
	var reader: EventSheetResource = _sheet_with([_action("ReadTextFile", {"path": "\"res://level.dat\""})])
	passed = _check("the export-trap fix leaves a res:// READ alone",
		EventSheetFilesDoctor.res_write_receipt(reader), []) and passed
	return passed


# ── 7. What a project already wrote ──────────────────────────────────────────────────────────


## The spellings a project has in it before this plugin arrives. Each one opens as a sheet and saves
## back BYTE-IDENTICALLY - which is the contract, whether the lifter recognised the line as a row or
## kept it verbatim.
static func _test_lifts() -> bool:
	var passed: bool = true
	var sources: Dictionary = {
		"the plain read": "extends Node\n\n\nfunc _ready() -> void:\n\tvar text = FileAccess.get_file_as_string(\"user://save.dat\")\n\tprint(text)\n",
		"the open/get_as_text pair": "extends Node\n\n\nfunc _ready() -> void:\n\tvar file = FileAccess.open(\"user://save.dat\", FileAccess.READ)\n\tvar text = file.get_as_text()\n\tprint(text)\n",
		"the guarded read, with the fallback it wrote": "extends Node\n\n\nfunc _ready() -> void:\n\tvar text = FileAccess.get_file_as_string(\"user://save.dat\") if FileAccess.file_exists(\"user://save.dat\") else \"{}\"\n\tprint(text)\n",
		"the folder prelude above its write": "extends Node\n\n\nfunc _ready() -> void:\n\tDirAccess.make_dir_recursive_absolute(\"user://runs/latest.txt\".get_base_dir())\n\tvar file = FileAccess.open(\"user://runs/latest.txt\", FileAccess.WRITE)\n\tif file:\n\t\tfile.store_string(\"x\")\n\t\tfile.close()\n",
	}
	for label: String in _sorted(sources):
		passed = _check("round trip: %s" % label, _round_trip(str(sources[label])),
			str(sources[label])) and passed
	return passed


## One source, opened as a sheet and written back out. The bytes, so a lift that "worked" and
## reformatted somebody's file still fails here.
static func _round_trip(source: String) -> String:
	var path: String = "%s/round_trip.gd" % TEST_DIR
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	var handle: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if handle == null:
		return ""
	handle.store_string(source)
	handle.close()
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(path)
	var written: String = "" if sheet == null else str(SheetCompiler.compile(sheet, path).get("output", ""))
	DirAccess.remove_absolute(path)
	return written


# ── Shared ───────────────────────────────────────────────────────────────────────────────────


static func _descriptors() -> Dictionary:
	var by_id: Dictionary = {}
	for descriptor: ACEDescriptor in EventForgeBuiltinACEs.get_descriptors():
		by_id[descriptor.ace_id] = descriptor
	return by_id


## One template emitted with one row's values, through the compiler's own reading of it - never
## through a second implementation here.
static func _emit(template: String, params: Dictionary) -> String:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "probe"
	action.codegen_template = template
	action.params = params
	return ActionCodegen.generate_action(action)


## What one emitted expression really answers, by running it. The guard is a ternary in a file, and a
## ternary that reads right and parses wrong is exactly what a string comparison cannot catch.
static func _run_expression(expression: String) -> Variant:
	var script: GDScript = GDScript.new()
	script.source_code = "extends RefCounted\n\n\nfunc answer() -> Variant:\n\treturn %s\n" % expression
	if script.reload() != OK:
		return "<did not parse>"
	return script.new().answer()


static func _action(ace_id: String, params: Dictionary) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	action.params = params
	return action


static func _sheet_with(actions: Array) -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnReady"
	for action: Variant in actions:
		event.actions.append(action)
	sheet.events.append(event)
	return sheet


static func _severities(findings: Array[Dictionary]) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for finding: Dictionary in findings:
		out.append(str(finding.get("severity", "")))
	return out


static func _checks(findings: Array[Dictionary]) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for finding: Dictionary in findings:
		out.append(str(finding.get("check", "")))
	return out


## Keys in sorted order, so the round-trip half reads identically on every platform the suite runs on.
static func _sorted(source: Dictionary) -> PackedStringArray:
	var keys: PackedStringArray = PackedStringArray()
	for key: Variant in source.keys():
		keys.append(str(key))
	keys.sort()
	return keys


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] file_places_test: %s" % label)
		return true
	print("[FAIL] file_places_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
