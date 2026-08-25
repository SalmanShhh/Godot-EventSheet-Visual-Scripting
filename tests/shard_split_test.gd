# Godot EventSheets - the SPLIT the parallel runner shards the suite by.
#
# `tools/run_tests_parallel.ps1` starts n Godot processes, each running one shard, then a serial tail.
# The split that decides which file each process runs is `EventForgeTestRunner._shard_of` - pure, and
# until now pinned by nothing at all. An off-by-one in it, a malformed shard string, or a change to
# the tail predicate would silently drop test files from EVERY process while the launcher still
# printed `All tests passed.` - the false green the whole suite exists to prevent.
#
# So this asserts the invariant the split's own doc comment claims: every file lands in exactly one
# of the n shards or the tail, never in two and never in none. And it asserts what the tail is FOR:
# a test that declares a timing budget stays out of the shards, whatever its file is called.
@tool
class_name ShardSplitTest
extends RefCounted

## A stand-in file list: enough names to shard, in the order the runner hands them over.
const SAMPLE_FILES: PackedStringArray = [
	"a_test.gd", "b_test.gd", "c_test.gd", "d_test.gd", "e_test.gd",
	"f_test.gd", "g_test.gd", "clean_removal_test.gd",
]

## The stand-in list's timing tests - what `timing_files()` answers for the real ones.
const SAMPLE_SERIAL: PackedStringArray = ["c_test.gd"]

## Stand-in recorded times, in milliseconds: two long tests that sort next to each other, three
## short ones, and one file with no record at all.
const SAMPLE_DURATIONS: Dictionary = {
	"a_test.gd": 20000, "b_test.gd": 20000, "d_test.gd": 2000, "e_test.gd": 2000, "f_test.gd": 2000,
}

## The shared pin helper - a table of input to expected, and one failure line for all of them.
const Pins := preload("res://tests/pin_table.gd")


static func run() -> bool:
	var ok: bool = true
	ok = _test_every_file_lands_in_exactly_one_place() and ok
	ok = _test_the_tail_is_the_shared_state_and_the_timing_tests() and ok
	ok = _test_a_malformed_shard_string_still_runs_everything_once() and ok
	ok = _test_a_timing_budget_is_found_in_the_file_not_in_its_name() and ok
	ok = _test_recorded_times_pack_the_shards_instead_of_dealing_them() and ok
	return ok


## What the recorded durations are FOR. A wall clock is decided by the SLOWEST shard, so dealing
## files out alphabetically loses whenever the slow ones happen to sort together - here the two
## twenty-second tests are `a` and `b`, which the round-robin puts on two different shards only by
## luck of their position. Packing longest-first onto the emptiest shard is what makes the two
## halves the same size, and the same invariant still holds: every file exactly once.
static func _test_recorded_times_pack_the_shards_instead_of_dealing_them() -> bool:
	var ok: bool = true
	var first: PackedStringArray = _split_timed("0/2")
	var second: PackedStringArray = _split_timed("1/2")
	ok = Pins.check_value("shard_split_test", "the long pair is split, one each",
		[first.has("a_test.gd"), second.has("b_test.gd")], [true, true]) and ok
	ok = Pins.check_value("shard_split_test", "the two shards carry the same weight",
		[_weight(first), _weight(second)], [24000, 24000]) and ok
	ok = Pins.check_value("shard_split_test", "and every parallel-safe file still runs exactly once",
		_sorted(_joined(first, second)),
		PackedStringArray(["a_test.gd", "b_test.gd", "d_test.gd", "e_test.gd", "f_test.gd",
			"g_test.gd"])) and ok
	ok = Pins.check_value("shard_split_test", "a file nobody has timed counts as the median, not as free",
		_split_timed("0/1").has("g_test.gd"), true) and ok
	ok = Pins.check_value("shard_split_test", "the tail is unchanged by any of it",
		_split_timed("tail"), PackedStringArray(["c_test.gd", "clean_removal_test.gd"])) and ok
	return ok


## The claim the split's doc comment makes: across shards 0..n-1 plus the tail, every file appears
## exactly once. Checked for several n, because the failure mode is an off-by-one at one width.
static func _test_every_file_lands_in_exactly_one_place() -> bool:
	var ok: bool = true
	for count: int in [1, 2, 3, 4, 8]:
		var seen: PackedStringArray = PackedStringArray()
		for index: int in range(count):
			seen.append_array(_split("%d/%d" % [index, count]))
		seen.append_array(_split("tail"))
		seen.sort()
		var expected: PackedStringArray = SAMPLE_FILES.duplicate()
		expected.sort()
		ok = _check("across %d shards and the tail, every file runs exactly once" % count,
			seen, expected) and ok
	return ok


## What the tail holds: the shared-state tests the runner defers, and the tests that MEASURE. Nothing
## else, so a shard is never handed a file it cannot run beside seven other processes.
static func _test_the_tail_is_the_shared_state_and_the_timing_tests() -> bool:
	var ok: bool = true
	ok = _check("the tail is the shared-state test and the timing one",
		_split("tail"), PackedStringArray(["c_test.gd", "clean_removal_test.gd"])) and ok
	ok = _check("and a shard is handed neither",
		_split("0/1"), PackedStringArray(["a_test.gd", "b_test.gd", "d_test.gd", "e_test.gd",
			"f_test.gd", "g_test.gd"])) and ok
	ok = _check("an unset shard is the whole suite, in one process, exactly as before",
		EventForgeTestRunner._shard_of(SAMPLE_FILES, "", SAMPLE_SERIAL), SAMPLE_FILES) and ok
	return ok


## A shard string nobody meant: "3/2" (a shard past the width) and "nonsense" (no width at all). The
## split must never answer with files it also gave another process, and never lose them all.
static func _test_a_malformed_shard_string_still_runs_everything_once() -> bool:
	var ok: bool = true
	ok = _check("a shard past the width runs nothing rather than repeating a shard",
		_split("3/2"), PackedStringArray()) and ok
	ok = _check("…and the two real shards still cover every parallel-safe file",
		_sorted(_joined(_split("0/2"), _split("1/2"))),
		PackedStringArray(["a_test.gd", "b_test.gd", "d_test.gd", "e_test.gd", "f_test.gd",
			"g_test.gd"])) and ok
	ok = _check("a shard string with no width is shard 0 of 1 - everything parallel-safe, once",
		_split("nonsense"), PackedStringArray(["a_test.gd", "b_test.gd", "d_test.gd", "e_test.gd",
			"f_test.gd", "g_test.gd"])) and ok
	return ok


## The rule the tail is chosen by is the test's OWN declaration, not its file name: doc_library_test
## carries a 12-second parse budget and is named nothing like a perf test, and it was running inside
## a shard beside seven other Godot processes for exactly that reason.
static func _test_a_timing_budget_is_found_in_the_file_not_in_its_name() -> bool:
	var ok: bool = true
	var timing: PackedStringArray = EventForgeTestRunner.timing_files(
		PackedStringArray(["doc_library_test.gd", "lift_perf_test.gd", "drawing_prefab_perf_test.gd",
			"variable_row_sentence_test.gd", "shard_split_test.gd"]))
	ok = _check("a declared budget puts a test in the tail whatever it is called",
		timing, PackedStringArray(["doc_library_test.gd", "lift_perf_test.gd",
			"drawing_prefab_perf_test.gd"])) and ok
	return ok


# ── helpers ───────────────────────────────────────────────────────────────────────────────────
static func _split(shard: String) -> PackedStringArray:
	return EventForgeTestRunner._shard_of(SAMPLE_FILES, shard, SAMPLE_SERIAL)


static func _split_timed(shard: String) -> PackedStringArray:
	return EventForgeTestRunner._shard_of(SAMPLE_FILES, shard, SAMPLE_SERIAL, SAMPLE_DURATIONS)


## What one shard costs, by the recorded times, with an untimed file counted as the median.
static func _weight(files: PackedStringArray) -> int:
	var total: int = 0
	for file: String in files:
		total += int(SAMPLE_DURATIONS.get(file, 2000))
	return total


static func _joined(first: PackedStringArray, second: PackedStringArray) -> PackedStringArray:
	var out: PackedStringArray = first.duplicate()
	out.append_array(second)
	return out


static func _sorted(files: PackedStringArray) -> PackedStringArray:
	var out: PackedStringArray = files.duplicate()
	out.sort()
	return out


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] shard_split_test: %s" % label)
		return true
	print("[FAIL] shard_split_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
