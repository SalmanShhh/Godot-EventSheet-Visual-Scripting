# Godot EventSheets - the Doctor's Renamed Classes section.
#
# Nine plugin classes took the EventSheet prefix. A script of the reader's that still names an old one
# stops parsing, so the Doctor names each line with the replacement. This pins the rule by value over
# hand-made sources, then once over a real file the section reads through the project's own script
# walk, then over this repository, which must stay quiet.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const SECTION := preload("res://addons/eventforge/renamed_classes_doctor.gd")
const P := "renamed_classes_doctor_test"


static func run() -> bool:
	var found: Array = SECTION.hits(
		"extends Node\n\nfunc _run() -> void:\n\tvar sheet := GDScriptImporter.new().import_external_source(\"\")\n\tprint(SheetCompiler.compile(sheet, \"user://x.gd\"))\n",
		PackedStringArray())
	var ok: bool = SUPPORT.pins(P, [
		["both old names are found, each with its new name and its line",
			found.map(func(hit: Dictionary) -> String: return "%d %s -> %s" % [int(hit["line"]), hit["old"], hit["new"]]),
			["4 GDScriptImporter -> EventSheetGDScriptImporter", "5 SheetCompiler -> EventSheetCompiler"]],
		["a comment naming an old class is not a finding", SECTION.hits("extends Node\n# SheetCompiler was renamed\nvar a := 1 # VariableParser\n", PackedStringArray()).size(), 0],
		["a string naming an old class is not a finding", SECTION.hits("extends Node\nvar s := \"SheetCompiler\"\nvar t := 'ActionCodegen'\n", PackedStringArray()).size(), 0],
		["the new name is not a finding", SECTION.hits("extends Node\nvar c := EventSheetCompiler\nvar d := MySheetCompiler\n", PackedStringArray()).size(), 0],
		["a class of the project's own with that name is its own", SECTION.hits("extends Node\nvar c := SheetCompiler.new()\n", PackedStringArray(["SheetCompiler"])).size(), 0],
		["a file that declares the old name itself is its own", SECTION.hits("class_name TriggerResolver\nextends Node\nvar c := TriggerResolver.new()\n", PackedStringArray()).size(), 0],
		["a name inside a hash inside a string does not hide a real name after it", SECTION.hits("extends Node\nvar s := \"#\" + str(FunctionParser)\n", PackedStringArray()).size(), 1],
	])
	for old: String in SECTION.RENAMED:
		ok = SUPPORT.check(P, "%s is found and named as %s" % [old, SECTION.RENAMED[old]],
			(SECTION.hits("extends Node\nvar x = %s\n" % old, PackedStringArray())[0] as Dictionary)["new"], str(SECTION.RENAMED[old])) and ok
	# The section itself, through the files it reads.
	var path: String = SUPPORT.own_path("old_name_script.gd")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("extends Node\n\nfunc _ready() -> void:\n\tSheetCompiler.compile(null)\n")
	file.close()
	var findings: Array[Dictionary] = SECTION.report({path: FileAccess.get_file_as_string(path)}, PackedStringArray())
	ok = SUPPORT.pins(P, [
		["one finding for the line", findings.size(), 1],
		["it is a warning filed under the section's id", [findings[0]["severity"], findings[0]["check"]], ["warning", "renamed-classes"]],
		["it says the line, the old name and the new name in one short sentence", findings[0]["message"],
			"Line 4: rename SheetCompiler to EventSheetCompiler. Nothing else changed."],
		["it opens the file the finding is about", findings[0]["path"], path],
	]) and ok
	var live: Array[Dictionary] = []
	SECTION.check(PackedStringArray(), live)
	ok = SUPPORT.pins(P, [["this repository names no old class", live, []]]) and ok
	return ok
