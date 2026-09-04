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
#   8. THE SENTENCE A READ READS BACK AS. A file read opened out of somebody's own script says
#      what the picked row says, guard and all - and a line that reads one file after asking about
#      another says nothing, because that one is the Doctor's finding and has to keep looking like
#      the mistake it is.
#
# Values are pinned, never counts: a count tells nobody which sentence moved.
@tool
class_name FilePlacesTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := preload("res://addons/eventforge/registration/file_places.gd")

## Where the round-trip half writes. Under user:// because that is the only place a test may write,
## which is the lesson this whole file is about.
const TEST_DIR := "user://__fileplaces_test"


static func run() -> bool:
	var passed: bool = true
	passed = _test_places() and passed
	passed = _test_tables_cover_the_vocabulary() and passed
	passed = _test_leads() and passed
	passed = _test_path_completion_is_fresh() and passed
	passed = _test_visible_guard() and passed
	passed = _test_folder_prelude() and passed
	passed = _test_doctor_checks() and passed
	passed = _test_fixes() and passed
	passed = _test_lifts() and passed
	passed = _test_reads_back() and passed
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


# ── 1b. The tables answer for the whole vocabulary, not for the half that was written first ──


## THE FIX TABLES MUST NOT DRIFT FROM THE VOCABULARY, which is exactly what they did: nine path
## fields shipped in the same pass that wrote both halves, and every one of them was invisible to
## both one-click fixes - including two WRITES, so a row aimed at res:// raised the export-trap
## warning and the chip beside it then answered that there was nothing to fix.
##
## Both halves are gated against the vocabulary itself rather than against a list:
##   - every `file_path`-hinted parameter of every registered verb is one `path_params_of` names,
##     because that answer is DERIVED from the hint;
##   - every verb whose emitted template makes a WRITE call and carries a path field is in
##     WRITE_SHAPED, which stays hand-kept because no hint can say whether a row reads or overwrites.
static func _test_tables_cover_the_vocabulary() -> bool:
	var passed: bool = true
	var unreachable: PackedStringArray = PackedStringArray()
	var unclassified: PackedStringArray = PackedStringArray()
	for descriptor: ACEDescriptor in ACERegistry.get_builtin_descriptors():
		var hinted: PackedStringArray = PackedStringArray()
		for entry: Variant in descriptor.params:
			var param: ACEParam = entry as ACEParam
			if param != null and str(param.hint) == P.PATH_HINT:
				hinted.append(str(param.id))
		if hinted.is_empty():
			continue
		var named: PackedStringArray = P.path_params_of(str(descriptor.ace_id),
			str(descriptor.provider_id))
		for param_id: String in hinted:
			if not named.has(param_id):
				unreachable.append("%s.%s" % [descriptor.ace_id, param_id])
		if EventSheetFileFacts.touch_of(str(descriptor.codegen_template)) in [
				EventSheetFileFacts.TOUCH_WRITTEN, EventSheetFileFacts.TOUCH_BOTH]:
			if P.write_params_of(str(descriptor.ace_id)).is_empty():
				unclassified.append(str(descriptor.ace_id))
	unreachable.sort()
	unclassified.sort()
	passed = _check("every path field of every verb is one the fixes can reach",
		unreachable, PackedStringArray()) and passed
	passed = _check("and every verb that writes one says which parameter it writes",
		unclassified, PackedStringArray()) and passed
	# The three the pass shipped without telling the tables about them.
	passed = _check("packing writes the archive it names",
		P.write_params_of("PackFolderIntoZip"), PackedStringArray(["archive"])) and passed
	passed = _check("unpacking writes the folder it lands in",
		P.write_params_of("UnpackZipIntoFolder"), PackedStringArray(["folder"])) and passed
	passed = _check("writing a table writes its file",
		P.write_params_of("WriteFileTable"), PackedStringArray(["path"])) and passed
	# Derived, so a verb this file has never named answers anyway.
	passed = _check("the loader's path is found by its hint alone",
		P.path_params_of("LoadImageFile"), PackedStringArray(["path"])) and passed
	passed = _check("and a verb no registry knows falls back to the written-down table",
		P.path_params_of("CopyFile", "NoSuchProvider"), PackedStringArray(["from", "to"])) and passed
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
	# THE STRIP IS THE THREE SENTENCES ABOVE, JOINED - never a fourth copy of them. The paragraph a
	# reader meets used to be written out again in the dialog's own hint table, where it drifted from
	# these and shipped untranslated in all eight bundled languages while these three were keyed.
	var paragraph: String = P.strip_paragraph()
	passed = _check("the strip leads with what the player's folder allows",
		paragraph.contains(P.lead_for(P.PLACE_USER)), true) and passed
	passed = _check("and says what the game's own files forbid",
		paragraph.contains(P.lead_for(P.PLACE_RES)), true) and passed
	passed = _check("and ends with where the player's folder really is",
		paragraph.contains(P.where_user_lives()), true) and passed
	passed = _check("the field's help strip IS that paragraph, not a copy of it",
		EventSheetParamFieldFactory.hint_paragraph(P.PATH_HINT), paragraph) and passed
	return passed


# ── 2b. The list of a folder the game writes to ──────────────────────────────────────────────


## A PATH FIELD COMPLETES AGAINST user://, WHICH THE GAME REWRITES WHILE YOU WORK. The list was
## filed with the project-scoped ones, which are dropped when res:// changes - and nothing in the
## editor watches user://, so the list kept answering with the folder as it was at the first ask for
## the rest of the session, while its own comment said it read the folder as it stands right now.
## It is dropped when a field STARTS completing instead: once per dialog, never once per keystroke.
static func _test_path_completion_is_fresh() -> bool:
	var passed: bool = true
	EventSheetCompletions.clear_cache()
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	var written_later: String = "%s/written_by_a_test_run.txt" % TEST_DIR
	DirAccess.remove_absolute(written_later)
	var asked: String = "\"%s" % written_later
	passed = _check("a file nobody has written yet is not offered",
		_completes(asked), false) and passed
	var handle: FileAccess = FileAccess.open(written_later, FileAccess.WRITE)
	if handle != null:
		handle.store_string("the run wrote this")
		handle.close()
	passed = _check("the list held for the session does not know about it yet",
		_completes(asked), false) and passed
	EventSheetCompletions.forget_live_folders()
	passed = _check("and the next field to start completing is offered the file that is there now",
		_completes(asked), true) and passed
	DirAccess.remove_absolute(written_later)
	# Cold state out, cold state in: the serial run shares one process with every other test.
	EventSheetCompletions.clear_cache()
	return passed


## True when a path field offers something beginning with this text.
static func _completes(typed: String) -> bool:
	for entry: Dictionary in EventSheetCompletions.for_field(null,
			EventSheetCompletions.FIELD_PATH, typed):
		if str(entry.get("text", "")).begins_with(typed):
			return true
	return false


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
	# THE GUARDED FORM WEARS ITS OWN BRACKETS. A read answers inside a parameter slot, so a bare
	# `a if b else c` spliced between two operators would bind them into its branches - a wrong
	# answer rather than a parse error, which is why it is pinned here character for character.
	passed = _check("a named fallback emits the file_exists ternary, in brackets",
		P.guarded_read("\"user://save.dat\"", "\"none\""),
		"(FileAccess.get_file_as_string(\"user://save.dat\") if FileAccess.file_exists(\"user://save.dat\") else \"none\")") and passed
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
	# AND IT ANSWERS INSIDE SOMEBODY ELSE'S SENTENCE. An expression is dropped into a parameter slot,
	# and Compare Values is `{a} {op} {b}` - so an unbracketed ternary would bind the comparison into
	# its own branches and the row would quietly BE the file's text instead of a comparison. The file
	# here EXISTS, which is the case where the two spellings answer differently.
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	var present: FileAccess = FileAccess.open("%s/present.txt" % TEST_DIR, FileAccess.WRITE)
	if present != null:
		present.store_string("here")
		present.close()
	var compared: Variant = _run_expression("%s == \"here\"" % _emit(template,
		{"path": "\"%s/present.txt\"" % TEST_DIR, "fallback": "\"the fallback\""}))
	passed = _check("and a guarded read dropped into a comparison IS a comparison",
		compared, true) and passed
	DirAccess.remove_absolute("%s/present.txt" % TEST_DIR)
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
		"DirAccess.make_dir_recursive_absolute((\"user://runs/latest.txt\").get_base_dir())") and passed
	passed = _check("the prelude is exactly what the one reading of it writes",
		made.split("\n")[0], P.make_folder_prelude("\"user://runs/latest.txt\"")) and passed
	passed = _check("the write itself follows it unchanged", made.split("\n")[1],
		"var __file_w1 = FileAccess.open(\"user://runs/latest.txt\", FileAccess.WRITE)") and passed
	# A PATH SLOT HOLDS AN EXPRESSION, and `.get_base_dir()` binds to the last operand of one. A path
	# written as the ordinary join - a folder, a slot the player chose, an extension - asked the
	# `".txt"` where its folder was, which is nowhere, so the write went into a folder nobody made.
	var built: String = _emit(template, {"path": "\"user://runs/\" + slot + \".txt\"",
		"text": "\"hi\"", "folder": "make its folder first"})
	passed = _check("a path built out of pieces is asked as a whole where its folder is",
		built.split("\n")[0],
		"DirAccess.make_dir_recursive_absolute((\"user://runs/\" + slot + \".txt\").get_base_dir())") and passed
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
const BUG_RES_ARCHIVE := "func _ready() -> void:\n\tvar packer := ZIPPacker.new()\n\tif packer.open(\"res://runs.zip\") == OK:\n\t\tpacker.close()\n"
const CLEAN_RES_ARCHIVE := "func _ready() -> void:\n\tvar packer := ZIPPacker.new()\n\tif packer.open(\"user://runs.zip\") == OK:\n\t\tpacker.close()\n"
const CLEAN_RES_UNPACK := "func _ready() -> void:\n\tvar reader := ZIPReader.new()\n\tif reader.open(\"res://runs.zip\") == OK:\n\t\treader.close()\n"
# A FOLDER HANDLE WRITES THROUGH THE PLACE IT WAS OPENED AT. The place is on the `open` line and the
# write is on another - or chained onto the same one - and the check read neither, so a res:// write
# spelled this way earned nothing while the literal sat right there in the file.
const BUG_RES_DIR_CHAINED := "func _ready() -> void:
	DirAccess.open(\"res://\").make_dir(\"levels\")
"
const BUG_RES_DIR_NAMED := "func _ready() -> void:
	var folder := DirAccess.open(\"res://saves\")
	folder.make_dir(\"runs\")
"
const CLEAN_RES_DIR_LISTED := "func _ready() -> void:
	var folder := DirAccess.open(\"res://levels\")
	print(folder.get_files())
"
const CLEAN_USER_DIR_WRITTEN := "func _ready() -> void:
	var folder := DirAccess.open(\"user://saves\")
	folder.make_dir(\"runs\")
"
# A NAME IS A WHOLE NAME. `data` is not the handle called `d`, so a res:// folder merely LISTED
# through it is not the write that the user:// handle beside it makes.
const CLEAN_TWO_DIR_HANDLES := "func _ready() -> void:
	var d := DirAccess.open(\"user://a\")
	d.make_dir(\"x\")
	var data := DirAccess.open(\"res://levels\")
	print(data.get_files())
"
const CLEAN_COMMENTED := "func _ready() -> void:\n\tprint(FileAccess.get_file_as_string(\"user://save.dat\"))  # was \"C:/temp/x.txt\"\n"
const BUG_COMMENTED := "func _ready() -> void:\n\tprint(FileAccess.get_file_as_string(\"C:/temp/x.txt\"))  # the old place\n"
const BUG_ESCAPED := "func _ready() -> void:\n\tprint(FileAccess.get_file_as_string(\"a \\\" b\" + \"/c/d.txt\"))\n"
const BUG_UNGUARDED := "func _ready() -> void:\n\tvar text = FileAccess.get_file_as_string(\"user://save.dat\")\n"
const BUG_WRONG_GUARD := "func _ready() -> void:\n\tvar text = FileAccess.get_file_as_string(\"user://save.dat\") if FileAccess.file_exists(\"user://settings.json\") else \"\"\n"
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
	# AN ARCHIVE IS A WRITE TOO. The files band already reads a packing row as written, so a check
	# that could not see one would be a second reading of the same row - and the archive is the one
	# file a project is most likely to aim at res:// by habit.
	var packed: Array[Dictionary] = EventSheetFilesDoctor.res_write_findings(
		{"res://trap.gd": BUG_RES_ARCHIVE})
	passed = _check("an archive written to res:// is the same warning", _severities(packed),
		PackedStringArray(["warning"])) and passed
	passed = _check("naming the line that opens the packer", str(packed[0]["subject"]),
		"if packer.open(\"res://runs.zip\") == OK:") and passed
	passed = _check("the same archive under user:// is silent",
		EventSheetFilesDoctor.res_write_findings({"res://ok.gd": CLEAN_RES_ARCHIVE}).size(), 0) and passed
	# A READER'S `open` is the identical call and must stay silent: reading an archive out of res://
	# is what res:// is for.
	passed = _check("and reading an archive out of res:// is silent",
		EventSheetFilesDoctor.res_write_findings({"res://ok.gd": CLEAN_RES_UNPACK}).size(), 0) and passed

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
	# A CHECK READS WHAT THE CALL WAS HANDED, not every quoted string on the line. A comment about a
	# path the code no longer uses is a note somebody left themselves, and a warning on it is a
	# warning nobody can act on: there is nothing on that line to fix.
	passed = _check("a path in a trailing comment is not a path the code reaches",
		EventSheetFilesDoctor.absolute_path_findings({"res://ok.gd": CLEAN_COMMENTED}).size(),
		0) and passed
	passed = _check("but the same path in the call is still reported",
		EventSheetFilesDoctor.absolute_path_findings({"res://trap.gd": BUG_COMMENTED}).size(),
		1) and passed
	# An escaped quote does not close a literal. A scan that thinks it does pairs every quote after it
	# with the wrong partner, and reads the rest of the line inside out - here that hid the path
	# entirely.
	passed = _check("a string holding an escaped quote is read as one string",
		EventSheetFilesDoctor.absolute_path_findings({"res://trap.gd": BUG_ESCAPED}).size(),
		1) and passed

	# THE PLACE IS READ OFF THE PATH WRITTEN IN THE LINE, which is what the finding promises - and a
	# folder handle writes through a path written in a line just as plainly as FileAccess does.
	passed = _check("a res:// folder opened and written on one line is the export trap",
		EventSheetFilesDoctor.res_write_lines(BUG_RES_DIR_CHAINED),
		PackedStringArray(["DirAccess.open(\"res://\").make_dir(\"levels\")"])) and passed
	passed = _check("and so is one opened under a name this file then writes through",
		EventSheetFilesDoctor.res_write_lines(BUG_RES_DIR_NAMED),
		PackedStringArray(["var folder := DirAccess.open(\"res://saves\")"])) and passed
	# OPENING A FOLDER IS A READ. Listing the game's own files is exactly what res:// is for, so a
	# handle nothing writes through is not the trap and must not be reported as one.
	passed = _check("a res:// folder that is only listed is nobody's business",
		EventSheetFilesDoctor.res_write_lines(CLEAN_RES_DIR_LISTED),
		PackedStringArray()) and passed
	passed = _check("and a written folder under user:// is the right thing to do",
		EventSheetFilesDoctor.res_write_lines(CLEAN_USER_DIR_WRITTEN),
		PackedStringArray()) and passed
	passed = _check("and one handle's name is not another's that begins with the same letters",
		EventSheetFilesDoctor.res_write_lines(CLEAN_TWO_DIR_HANDLES),
		PackedStringArray()) and passed

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
	# A GUARD IS A GUARD OVER THE PATH IT NAMES. A line asking about one file and reading another is
	# the unguarded read it looks like, and the check used to fall silent on the word file_exists
	# wherever it appeared.
	passed = _check("a guard naming a different file guards nothing",
		EventSheetFilesDoctor.unguarded_read_findings({"res://trap.gd": BUG_WRONG_GUARD}).size(),
		1) and passed
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
	# THE VERBS THE PASS SHIPPED AFTER THE TABLE WAS WRITTEN. A Write Table To File aimed at res://
	# raised the warning and the chip beside it then answered that there was nothing to fix, because
	# the fix table had never heard of the verb.
	var late: EventSheetResource = _sheet_with([
		_action("WriteFileTable", {"path": "\"res://scores.csv\"", "table": "rows"}),
		_action("PackFolderIntoZip", {"folder": "\"user://runs\"", "archive": "\"res://runs.zip\""}),
		_action("UnpackZipIntoFolder", {"archive": "\"user://mods.zip\"", "folder": "\"res://mods\""}),
	])
	passed = _check("the receipt names all three of the late writes",
		EventSheetFilesDoctor.res_write_receipt(late),
		[{"before": "\"res://scores.csv\"", "after": "\"user://scores.csv\""},
			{"before": "\"res://runs.zip\"", "after": "\"user://runs.zip\""},
			{"before": "\"res://mods\"", "after": "\"user://mods\""}]) and passed
	passed = _check("and the fix moves all three", EventSheetFilesDoctor.rewrite_res_writes(late),
		3) and passed
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


# ── 8. The sentence a read reads back as ─────────────────────────────────────────────────────


## Both halves of one shape: the line the verb WRITES is taken apart by the same file that writes it,
## and the sentence a reader sees is the SHIPPED verb's own display text rather than a second wording
## kept beside it. So a read picked from the list and a read typed by hand say one thing.
static func _test_reads_back() -> bool:
	var passed: bool = true
	passed = _check("a plain read is taken apart as a read with no fallback",
		P.read_parts("FileAccess.get_file_as_string(\"user://save.dat\")"),
		{"path": "\"user://save.dat\"", "fallback": ""}) and passed
	passed = _check("the guarded line the verb writes is taken apart as path and fallback",
		P.read_parts(P.guarded_read("\"user://save.dat\"", "\"{}\"")),
		{"path": "\"user://save.dat\"", "fallback": "\"{}\""}) and passed
	passed = _check("and so is the same guard written by hand, without the brackets",
		P.read_parts("FileAccess.get_file_as_string(\"user://save.dat\") if "
			+ "FileAccess.file_exists(\"user://save.dat\") else \"{}\""),
		{"path": "\"user://save.dat\"", "fallback": "\"{}\""}) and passed
	passed = _check("a line that asks about a DIFFERENT file is not a guarded read",
		P.read_parts("FileAccess.get_file_as_string(\"user://save.dat\") if "
			+ "FileAccess.file_exists(\"user://settings.json\") else \"\""), {}) and passed
	passed = _check("nor is a ternary that reads no file at all",
		P.read_parts("a if b else c"), {}) and passed
	passed = _check("a read with a fallback of nothing is not a read with a fallback",
		P.read_parts("FileAccess.get_file_as_string(\"user://save.dat\") if "
			+ "FileAccess.file_exists(\"user://save.dat\") else "), {}) and passed
	passed = _check("the plain read reads back as the verb that writes it",
		EventSheetSentence.expression_text("FileAccess.get_file_as_string(\"user://save.dat\")", {}),
		"text of file \"user://save.dat\"") and passed
	passed = _check("the guarded read reads back with the fallback it wrote",
		EventSheetSentence.expression_text(P.guarded_read("\"user://save.dat\"", "\"{}\""), {}),
		"text of file \"user://save.dat\", or \"{}\"") and passed
	passed = _check("the mis-guarded read keeps the code it is, so the finding stays visible",
		EventSheetSentence.expression_text("FileAccess.get_file_as_string(\"user://save.dat\") if "
			+ "FileAccess.file_exists(\"user://settings.json\") else \"\"", {}),
		"FileAccess.get_file_as_string(\"user://save.dat\") if "
			+ "FileAccess.file_exists(\"user://settings.json\") else \"\"") and passed
	# The words come from the descriptors, so a display text edited tomorrow moves both at once.
	var by_id: Dictionary = _descriptors()
	passed = _check("the plain sentence is the shipped verb's own display text",
		str(by_id["ReadTextFile"].get_display_text()), "text of file {path}") and passed
	passed = _check("and the guarded one is the guarded verb's",
		str(by_id["ReadTextFileOr"].get_display_text()),
		"text of file {path}, or {fallback}") and passed
	return passed


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
	return SUPPORT.check("file_places_test", label, actual, expected)
