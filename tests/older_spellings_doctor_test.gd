# Godot EventSheets - the Doctor's quiet note for a script that still writes older spellings.
#
# One note per script, two short sentences, a note and never a warning, found by a text scan that opens
# nothing. It names only what has the whole shape (a two-hash line that reads the same with one hash, a
# guard around a plain float that already clears its floor), and it stays quiet on every file the plugin
# ships and on every script written the way the editor writes today.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const SCRIPT_TEST := preload("res://tests/tidy_script_test.gd")
const DOCTOR := preload("res://addons/eventforge/older_spellings_doctor.gd")
const P := "older_spellings_doctor_test"


static func run() -> bool:
	var ok: bool = true
	ok = _test_what_the_scan_counts(ok)
	ok = _test_the_finding(ok)
	ok = _test_what_the_scan_leaves_alone(ok)
	ok = _test_the_note_leads_to_a_tidy_that_has_something_to_do(ok)
	ok = _test_what_the_plugin_ships_is_quiet(ok)
	return ok


static func _test_what_the_scan_counts(ok: bool) -> bool:
	ok = SUPPORT.check(P, "a two-hash script counts each annotation line", DOCTOR.older_lines(SCRIPT_TEST.TWO_HASH), 8) and ok
	ok = SUPPORT.check(P, "a guard that wraps a plain float counts once", DOCTOR.older_lines(SCRIPT_TEST.OLD_FORM), 1) and ok
	ok = SUPPORT.check(P, "both shapes in one script add up", DOCTOR.older_lines("## @ace_version(1.0.0)\n" + SCRIPT_TEST.OLD_FORM), 2) and ok
	return ok


static func _test_the_finding(ok: bool) -> bool:
	var finding: Dictionary = DOCTOR.report("res://scripts/player.gd", 3)
	ok = SUPPORT.check(P, "it is a note, never a warning", str(finding["severity"]), "info") and ok
	ok = SUPPORT.check(P, "it names the file it is about", [str(finding["path"]), str(finding["check"])], ["res://scripts/player.gd", "older-spellings"]) and ok
	ok = SUPPORT.check(P, "two short sentences, with the count", str(finding["message"]),
		"3 lines are written in an older spelling. Sheet > Tidy This Script lists them before changing anything.") and ok
	ok = SUPPORT.check(P, "and one line says it in the singular", str(DOCTOR.report("res://a.gd", 1)["message"]),
		"1 line is written in an older spelling. Sheet > Tidy This Script lists it before changing anything.") and ok
	ok = SUPPORT.check(P, "the chip on it is the Tidy door",
		EventSheetQuickFixes.fixes_for(finding).map(func(fix: Dictionary) -> String: return str(fix["id"])), ["tidy_script"]) and ok
	return ok


static func _test_what_the_scan_leaves_alone(ok: bool) -> bool:
	ok = SUPPORT.check(P, "a script written the way the editor writes today is quiet", DOCTOR.older_lines(SCRIPT_TEST.TIDIED), 0) and ok
	ok = SUPPORT.check(P, "and so is a one-hash script", DOCTOR.older_lines(SCRIPT_TEST.ONE_HASH), 0) and ok
	var quiet: Dictionary = {
		"a guard around a name": "if t >= maxf(wave_gap, 0.001):",
		"a guard around a whole number": "if t >= maxf(2, 0.001):",
		"a value below its floor": "if t >= maxf(0.0005, 0.001):",
		"a floor with nothing guarded": "var gap: float = maxf(2.0, 0.001)",
		"a comment that names a word": "# @ace_hidden is what the old version used",
		"a two-hash comment that is not a word": "## @ace_nonsense(1)",
		"a line that only mentions the spelling": "print(\"## @ace_name\")",
	}
	for label: String in quiet:
		ok = SUPPORT.check(P, "%s is not counted" % label, DOCTOR.older_lines("extends Node\n\nfunc _process(t: float) -> void:\n\t%s\n\t\tpass\n" % str(quiet[label])), 0) and ok
	return ok


## The note and the window it points at must agree: a script the note names is one Tidy has lines for.
static func _test_the_note_leads_to_a_tidy_that_has_something_to_do(ok: bool) -> bool:
	var tidy: GDScript = load("res://addons/eventsheet/editor/dock/tidy_script.gd")
	for source: String in [SCRIPT_TEST.TWO_HASH, SCRIPT_TEST.OLD_FORM]:
		var path: String = SUPPORT.own_path("older_spellings_probe.gd")
		var sheet: EventSheetResource = SUPPORT.reopen(source, true, path)
		sheet.external_source_path = path
		ok = SUPPORT.check(P, "a script the note names has lines to tidy (%d chars)" % source.length(),
			(tidy.call("plan", sheet)["changes"] as Array).is_empty(), false) and ok
	return ok


## Every script the plugin ships or teaches from is written the way the editor writes today: no note for the
## packs and the scripts beside them, the showcases, or the template a new provider starts from.
static func _test_what_the_plugin_ships_is_quiet(ok: bool) -> bool:
	var named: PackedStringArray = PackedStringArray()
	for folder: String in ["res://eventsheet_addons", "res://demo", "res://script_templates"]:
		_collect_older(folder, named)
	ok = SUPPORT.check(P, "no shipped pack, showcase or template has a line in an older spelling", named, PackedStringArray()) and ok
	return ok


static func _collect_older(folder: String, named: PackedStringArray) -> void:
	for entry: String in DirAccess.get_files_at(folder):
		if entry.ends_with(".gd") and DOCTOR.older_lines(FileAccess.get_file_as_string(folder.path_join(entry))) > 0:
			named.append(folder.path_join(entry))
	for sub: String in DirAccess.get_directories_at(folder):
		_collect_older(folder.path_join(sub), named)
