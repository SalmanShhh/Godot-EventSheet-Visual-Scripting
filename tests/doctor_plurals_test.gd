# Godot EventSheets - the Doctor's sentences read as sentences, whatever the count.
#
# A finding that says "2 script(s) read" reads like a template a person was handed. The sentences of the
# Check the project window say a count in words that need no plural ("scripts read: 2"), or write the one
# form and the many form as two rows of the translation files. This pins that no Doctor sentence carries
# the "(s)" form again, that the sentences that do take two forms take them at one and at many, and that a
# finding is remembered by what it is about and not by its words, so rewording a sentence marks nothing new.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "doctor_plurals_test"
const CORPUS: PackedStringArray = [
	"res://demo/showcase/boomer_level/boomer_level.gd",
	"res://demo/showcase/skate_park/skate_park.gd",
	"res://demo/showcase/draw_lab/draw_lab.gd",
]
## Files whose sentences are what the Doctor window shows: the sections, the findings they call, and the receipts
## a fix on a finding writes. The command-line lines (`verify:`, the doctor verdict) are not among them on purpose.
const SENTENCE_FILES: PackedStringArray = [
	"res://addons/eventsheet/editor/interaction/compiler_findings.gd",
	"res://addons/eventsheet/editor/interaction/mistake_findings.gd",
	"res://addons/eventsheet/editor/interaction/state_facts.gd",
	"res://addons/eventsheet/editor/quick_fixes.gd",
	"res://addons/eventforge/conflict_guard.gd",
	"res://addons/eventforge/shared_sheets.gd",
]


static func run() -> bool:
	var rows: Array = []
	var sweep: PackedStringArray = _plural_marks_in(_doctor_files())
	rows.append(["no Doctor sentence carries the (s) form", sweep, PackedStringArray()])
	rows.append(["and the sweep looked at the Doctor's own files", _doctor_files().size() > 30, true])

	# The sentences that take two forms take both.
	rows.append(["one compiler warning is said in the singular", EventSheetCompileFindings.summary(["unused variable"]), "1 compiler warning - the first: unused variable"])
	rows.append(["and two in the plural", EventSheetCompileFindings.summary(["unused variable", "shadowed name"]), "2 compiler warnings - the first: unused variable"])
	rows.append(["merge markers on one line say which line", load("res://addons/eventforge/conflict_guard.gd").doctor_message("a.gd", PackedInt32Array([3])), "a.gd still holds merge conflict markers, on line 3. It will not parse, and it opens read-only until the merge is finished."])
	rows.append(["and on several say which lines", load("res://addons/eventforge/conflict_guard.gd").doctor_message("a.gd", PackedInt32Array([3, 9, 12])), "a.gd still holds merge conflict markers, on lines 3, 9 and 12. It will not parse, and it opens read-only until the merge is finished."])
	var one: Array[Dictionary] = [{"kind": "wrong_node", "message": "x is not a node"}]
	var many: Array[Dictionary] = [{"kind": "wrong_node", "message": "x is not a node"}, {"kind": "wrong_node", "message": "y is not a node"}]
	rows.append(["one mistake is said in the singular", EventSheetMistakeFindings.summary(one), "1 mistake the game would only meet when it runs - the first: x is not a node"])
	rows.append(["and several in the plural", EventSheetMistakeFindings.summary(many), "2 mistakes the game would only meet when it runs - the first: x is not a node"])

	# A sentence says the same count at one and at many, in the words that need no plural.
	var one_plain: Array[Dictionary] = EventSheetShipItDoctor.debug_row_findings({"res://a.gd": "extends Node\nfunc _ready() -> void:\n\tprint(\"x\")\n"})
	rows.append(["one plain script that prints is counted as one", str(one_plain[0].get("message", "")).begins_with("Plain scripts that write to the console where an exported release build still runs it: 1,"), true])
	var two_plain: Array[Dictionary] = EventSheetShipItDoctor.debug_row_findings({
		"res://a.gd": "extends Node\nfunc _ready() -> void:\n\tprint(\"x\")\n",
		"res://b.gd": "extends Node\nfunc _ready() -> void:\n\tprint(\"y\")\n"})
	rows.append(["and two as two", str(two_plain[0].get("message", "")).begins_with("Plain scripts that write to the console where an exported release build still runs it: 2,"), true])

	# What a finding is remembered by does not include its words.
	var audited: Array = []
	audited.append_array(EventSheetMistakeChecksDoctor.report(CORPUS))
	audited.append_array(EventSheetPerformanceDoctor.report(CORPUS))
	audited.append_array(EventSheetCollisionsDoctor.report(CORPUS))
	audited.append_array(EventSheetRenameDoctor.report(PackedStringArray(CORPUS)))
	var seen: PackedStringArray = EventSheetDoctorInbox.identities_of(EventSheetDoctorInbox.triage(audited, PackedStringArray()))
	var reworded: Array = []
	for finding: Variant in audited:
		var copy: Dictionary = (finding as Dictionary).duplicate()
		copy["message"] = "reworded: " + str(copy.get("message", ""))
		reworded.append(copy)
	var again: Array[Dictionary] = EventSheetDoctorInbox.triage(reworded, seen)
	var new_count: int = 0
	for entry: Dictionary in again:
		if bool(entry.get("is_new", false)):
			new_count += 1
	rows.append(["there were findings to compare", audited.size() > 0, true])
	rows.append(["a reworded audit marks nothing new", new_count, 0])
	return SUPPORT.pins(P, rows)


## Every Doctor-owned script: the sections, the helpers that make their findings, and the shared sentence files.
static func _doctor_files() -> PackedStringArray:
	var files: PackedStringArray = SENTENCE_FILES.duplicate()
	for file_name: String in DirAccess.get_files_at("res://addons/eventforge"):
		if file_name.get_extension() == "gd" and (file_name.contains("doctor") or file_name.begins_with("doctor_")):
			files.append("res://addons/eventforge/" + file_name)
	return files


## `file:line` of every code line (a comment is not shown to anybody) that holds the "(s)" form.
static func _plural_marks_in(files: PackedStringArray) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for path: String in files:
		var number: int = 0
		for line: String in FileAccess.get_file_as_string(path).split("\n"):
			number += 1
			if line.strip_edges().begins_with("#"):
				continue
			if line.contains("(s)") and not line.contains("# the verify line"):
				found.append("%s:%d" % [path.get_file(), number])
	return found
