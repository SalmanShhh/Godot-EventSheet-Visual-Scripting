# Godot EventSheets - what a RED run says about itself.
#
# Three pieces answer for a failing suite, and each one used to be a manual step somebody repeated:
#
#   1. THE CRASH TRAIL. A test that takes the process down prints no `[FAIL]` line - the log simply
#      stops. tests/run_tests.gd writes a start line before each test and a finish line after it, so
#      the last start with no finish IS the test that crashed. That reading is pinned here.
#   2. THE BLAME. tools/pick_tests.gd maps a changed file to the tests it could have broken; asked
#      backwards, it maps a failing test to the files you changed that reach it.
#   3. THE ASSERTIONS. tools/test_report.gd reads the shard logs and files each `[FAIL]` line under
#      the test that printed it, including the indented ones a nested reporter writes.
#
# Every case is a table of input to expected answer, run through the shared pin helper - which is
# also what this file is the worked example of.
@tool
class_name RedRunReportTest
extends RefCounted

## The shared pin helper: a table of input to expected, and one failure line for all of them.
const Pins := preload("res://tests/pin_table.gd")

## The report tool, loaded by path (it is a SceneTree script, so it is never instanced here - only
## its pure statics are asked).
const Report := preload("res://tools/test_report.gd")

const Picker := preload("res://tools/pick_tests.gd")

## The evidence a refused byte gate leaves on disk.
const Repro := preload("res://tests/repro_bundle.gd")

## Crash trails, and the test each one accuses. A trail is strictly alternating, so the rule is
## short - which is exactly why it is worth pinning: a rule this short is easy to get backwards.
const TRAILS: Dictionary = {
	"START a_test.gd\nDONE a_test.gd\nSTART b_test.gd\nDONE b_test.gd\n": "",
	"START a_test.gd\nDONE a_test.gd\nSTART b_test.gd\n": "b_test",
	"START a_test.gd\n": "a_test",
	"": "",
	"START a_test.gd\nDONE a_test.gd\n": "",
	# A finish line carries the test's milliseconds (the launcher's slowest-ten footer reads them off
	# this same trail), and the crash reading must go on ignoring whatever follows the name.
	"START a_test.gd\nDONE a_test.gd 12\nSTART b_test.gd\n": "b_test",
}

## Log lines, and the test the report files each under. The indented shape is the one that matters:
## a nested reporter writes `  [FAIL] ...`, and an anchor at the start of the line reports a clean
## run on a failing suite. The last line is a failure printed ON PURPOSE, by the helper's own proof
## below: it must be claimed by nobody, or a green run reports failures and the verdict line stops
## being believed.
const LOG_LINES: Dictionary = {
	"[FAIL] light_words_test: the sentence is one word - expected \"on\", got \"true\"":
		"light_words_test",
	"  [FAIL] nested_test: something - expected 1, got 2": "nested_test",
	"[PASS] light_words_test: not a failure at all": "",
	"nothing to do with a test": "",
	"[FAIL] deliberate_probe_not_a_failure: \"b\" - expected 2, got 9": "",
}


static func run() -> bool:
	var ok: bool = true
	ok = _test_the_crash_trail_names_the_test_that_never_finished() and ok
	ok = _test_the_log_reader_files_every_failure_under_its_test() and ok
	ok = _test_the_blame_is_the_pick_mapping_asked_backwards() and ok
	ok = _test_the_pin_helper_reports_the_way_it_promises() and ok
	ok = _test_a_refused_byte_gate_leaves_its_evidence() and ok
	return ok


## The diff a refused round-trip writes, and the bundle it writes it into. The diff is pinned by
## VALUE because it is the part a reader actually reads: the header names both sizes, the marker
## names the first line that differs, and the changed run is bracketed by the lines around it.
static func _test_a_refused_byte_gate_leaves_its_evidence() -> bool:
	var ok: bool = true
	ok = Pins.check_value("red_run_report_test", "matching bytes have no diff",
		Repro.diff("a\nb\n", "a\nb\n"), "no difference - the bytes match.\n") and ok
	ok = Pins.check_value("red_run_report_test", "one changed line, with its context",
		Repro.diff("one\ntwo\nthree\n", "one\nTWO\nthree\n"),
		"--- expected (3 lines)\n+++ actual   (3 lines)\n@@ first difference at line 2 @@\n"
		+ "  one\n- two\n+ TWO\n  three\n") and ok
	ok = Pins.check_value("red_run_report_test", "a line that was dropped shows as one side only",
		Repro.diff("one\ntwo\nthree\n", "one\nthree\n"),
		"--- expected (3 lines)\n+++ actual   (2 lines)\n@@ first difference at line 2 @@\n"
		+ "  one\n- two\n  three\n") and ok
	var report: String = Repro.dump("red_run_report_test", "res://a/probe.gd", "one\n", "two\n")
	ok = Pins.check_value("red_run_report_test", "and the bundle says where it put the evidence",
		report.begins_with("repro bundle: res://.godot/repro/red_run_report_test/a_probe.gd/"), true) and ok
	ok = Pins.check_value("red_run_report_test", "with the two sides in it",
		FileAccess.get_file_as_string("res://.godot/repro/red_run_report_test/a_probe.gd/actual.txt"),
		"two\n") and ok
	return ok


## The whole point of the trail: a crashed test is NAMED, where before it was invisible.
static func _test_the_crash_trail_names_the_test_that_never_finished() -> bool:
	return Pins.check("red_run_report_test", TRAILS, func(trail: String) -> Variant:
		return Report.unfinished_in(trail))


## One `[FAIL]` line, filed under the test that printed it. "" means the reader must not claim it.
static func _test_the_log_reader_files_every_failure_under_its_test() -> bool:
	return Pins.check("red_run_report_test", LOG_LINES, func(line: String) -> Variant:
		var failures: Dictionary = {}
		Report._collect_failures(line, failures)
		return "" if failures.is_empty() else str(failures.keys()[0]))


## The reverse mapping, against the same convention `pick` uses: a test's own file blames itself, the
## file it is named after blames it, and a file with nothing to do with it does not.
static func _test_the_blame_is_the_pick_mapping_asked_backwards() -> bool:
	var ok: bool = true
	var changed: PackedStringArray = PackedStringArray([
		"tests/shard_split_test.gd", "addons/eventforge/importer/lighting_lift.gd", "README.md"])
	ok = Pins.check_value("red_run_report_test", "a changed test file blames itself",
		Picker.blamed_files("shard_split_test", changed),
		PackedStringArray(["tests/shard_split_test.gd"])) and ok
	ok = Pins.check_value("red_run_report_test", "and the file a test is named after blames it",
		Picker.blamed_files("lighting_lift_test", changed),
		PackedStringArray(["addons/eventforge/importer/lighting_lift.gd"])) and ok
	ok = Pins.check_value("red_run_report_test", "a test nothing changed reaches is blamed on nothing",
		Picker.blamed_files("audio_aces_test", changed), PackedStringArray()) and ok
	ok = Pins.check_value("red_run_report_test", "the trailing .gd is accepted, since a trail carries one",
		Picker.blamed_files("shard_split_test.gd", changed),
		PackedStringArray(["tests/shard_split_test.gd"])) and ok
	return ok


## The helper's own promises: it compares VALUES, it walks the whole table rather than stopping at
## the first failure, and a typed array equals the plain one with the same strings in it.
static func _test_the_pin_helper_reports_the_way_it_promises() -> bool:
	var ok: bool = true
	ok = Pins.check_value("red_run_report_test", "a table where every pin holds passes",
		Pins.check("deliberate_probe_not_a_failure", {"a": 1, "b": 2},
			func(key: String) -> Variant: return 1 if key == "a" else 2), true) and ok
	# The two [FAIL] lines this prints are the helper failing ON PURPOSE, so they carry a name that
	# says so - a red-run report reads names out of the logs, and "probe" in one would be a lead
	# somebody follows.
	ok = Pins.check_value("red_run_report_test", "a table with two wrong pins fails, having walked both",
		Pins.check("deliberate_probe_not_a_failure", {"a": 1, "b": 2},
			func(_key: String) -> Variant: return 9), false) and ok
	ok = Pins.check_value("red_run_report_test", "a typed array equals the plain one beside it",
		Pins.check_value("deliberate_probe_not_a_failure", "same strings", PackedStringArray(["x"]), ["x"]), true) and ok
	return ok
