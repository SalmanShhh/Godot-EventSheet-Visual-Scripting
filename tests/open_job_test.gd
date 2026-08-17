# Godot EventSheets - opening a .gd as a sheet never freezes the editor.
#
# Measured before this landed: opening the FPS Controller pack blocked the editor 3.9 s, the Save
# System pack 7.2 s, and a 4,623-line dock helper 21.3 s, with no repaint at all - it looked like a
# crash. The ACE lift now runs on a worker thread (EventSheetOpenJob) while the editor paints the
# raw sheet and an "Opening…" strip.
#
# What this pins:
#   • the threaded open produces exactly the sheet the synchronous import produced (byte-identical
#     compile output) - moving the work must not change the answer,
#   • cancelling ("Show as code instead") gives back the RAW sheet: no lifted functions, and the
#     lossless round-trip still holds,
#   • the progress counters land on total == done, so the bar always finishes,
#   • the compiler's mutex serializes a worker compile against a main-thread one without
#     deadlocking - this test hangs forever if that lock is ever taken twice on one thread.
#
# NOTE ON THE HARNESS: run_tests.gd runs before the main loop exists, so there are no frames to
# poll on. Every job here is joined synchronously with finish() instead.
@tool
class_name OpenJobTest
extends RefCounted

const FPS_PACK: String = "res://eventsheet_addons/fps_controller/fps_controller_behavior.gd"
const FIXTURE_PATH: String = "user://open_job_fixture.gd"
## A small hand-written file with the shapes the lift cares about: a lifecycle handler, a helper
## function, a documented function, and a top-level variable.
const FIXTURE_SOURCE: String = """extends Node2D

var speed: float = 120.0


func _ready() -> void:
	position = Vector2(10, 20)
	set_process(true)


## Moves the sprite one step.
func step(amount: float) -> void:
	position.x += amount


func reset() -> void:
	position = Vector2.ZERO
"""


static func run() -> bool:
	var all_passed: bool = true
	var file: FileAccess = FileAccess.open(FIXTURE_PATH, FileAccess.WRITE)
	if file == null:
		print("[FAIL] open_job_test: could not write the fixture")
		return false
	file.store_string(FIXTURE_SOURCE)
	file.close()

	all_passed = _check_matches_synchronous(FPS_PACK) and all_passed
	all_passed = _check_matches_synchronous(FIXTURE_PATH) and all_passed
	all_passed = _check_progress_completes() and all_passed
	all_passed = _check_cancel_keeps_raw_sheet() and all_passed
	all_passed = _check_no_deadlock_under_concurrent_compiles() and all_passed
	return all_passed


## The threaded open must produce the same sheet the synchronous one does - compared by compile
## output, which is the only thing that has to be identical (row objects are fresh either way).
static func _check_matches_synchronous(path: String) -> bool:
	var all_passed: bool = true
	var label: String = path.get_file()
	var job: EventSheetOpenJob = EventSheetOpenJob.new()
	all_passed = _check("%s: the job starts" % label, job.start(path), true) and all_passed
	var threaded: EventSheetResource = job.finish()
	all_passed = _check("%s: the job produced a sheet" % label, threaded != null, true) and all_passed
	if threaded == null:
		return false
	var synchronous: EventSheetResource = GDScriptImporter.new().import_external(path)
	var threaded_output: String = str(SheetCompiler.compile(threaded, "user://open_job_threaded.gd").get("output", ""))
	var synchronous_output: String = str(SheetCompiler.compile(synchronous, "user://open_job_sync.gd").get("output", ""))
	all_passed = _check("%s: threaded open compiles byte-identically to the synchronous one" % label, threaded_output, synchronous_output) and all_passed
	all_passed = _check("%s: threaded open lifts the same function count" % label, threaded.functions.size(), synchronous.functions.size()) and all_passed
	all_passed = _check("%s: threaded open still round-trips to the source bytes" % label, threaded_output, FileAccess.get_file_as_string(path)) and all_passed
	return all_passed


## The bar must always finish: whatever the lift did, done equals total when the job returns.
static func _check_progress_completes() -> bool:
	var all_passed: bool = true
	var job: EventSheetOpenJob = EventSheetOpenJob.new()
	job.start(FPS_PACK)
	job.finish()
	var total: int = EventSheetACELifter.progress_functions_total
	var done: int = EventSheetACELifter.progress_functions_done
	all_passed = _check("the FPS pack counted its functions (38 candidates)", total > 0, true) and all_passed
	all_passed = _check("progress ends with every counted function accounted for", done, total) and all_passed
	return all_passed


## "Show as code instead": the lift abandons its work and the caller keeps the RAW sheet - no lifted
## functions at all, and the lossless round-trip intact, exactly like a file that cannot lift.
## Driven through attempt_lift directly rather than through a job, so the cancel lands at a known
## point instead of racing the worker.
static func _check_cancel_keeps_raw_sheet() -> bool:
	var all_passed: bool = true
	var source: String = FileAccess.get_file_as_string(FPS_PACK)
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(FPS_PACK, false)
	EventSheetACELifter.reset_progress()
	EventSheetACELifter.cancel_requested = true
	var lifted: bool = EventSheetACELifter.attempt_lift(sheet, source)
	EventSheetACELifter.cancel_requested = false
	all_passed = _check("a cancelled lift reports failure", lifted, false) and all_passed
	all_passed = _check("a cancelled lift leaves no lifted functions", sheet.functions.size(), 0) and all_passed
	var output: String = str(SheetCompiler.compile(sheet, "user://open_job_cancelled.gd").get("output", ""))
	all_passed = _check("a cancelled open still reproduces the source byte-for-byte", output, source) and all_passed
	return all_passed


## The compiler's mutex under real contention: the worker byte-verifies its lift while the main
## thread compiles the same kind of sheet in a loop. Both sides must finish and both must be right.
## A lock taken twice on one thread would hang here rather than fail, which is the loudest possible
## signal - and the loop also proves the worker's static scratch is never stomped mid-emission.
static func _check_no_deadlock_under_concurrent_compiles() -> bool:
	var all_passed: bool = true
	var fixture_source: String = FileAccess.get_file_as_string(FIXTURE_PATH)
	# An external sheet WITH anchored functions: the mid-file anchor pass calls
	# emit_function_block_text per candidate, so this compile path exercises both locked entries.
	var main_sheet: EventSheetResource = GDScriptImporter.new().import_external(FIXTURE_PATH)
	var job: EventSheetOpenJob = EventSheetOpenJob.new()
	job.start(FPS_PACK)
	var main_compiles: int = 0
	var main_stayed_correct: bool = true
	while not job.is_done():
		var output: String = str(SheetCompiler.compile(main_sheet, "user://open_job_contention.gd").get("output", ""))
		if output != fixture_source:
			main_stayed_correct = false
		main_compiles += 1
	var threaded: EventSheetResource = job.finish()
	all_passed = _check("the main thread kept compiling while the worker lifted", main_compiles > 0, true) and all_passed
	all_passed = _check("every concurrent main-thread compile stayed correct", main_stayed_correct, true) and all_passed
	var threaded_output: String = str(SheetCompiler.compile(threaded, "user://open_job_contention_worker.gd").get("output", ""))
	all_passed = _check("the worker's sheet is correct despite the contention", threaded_output, FileAccess.get_file_as_string(FPS_PACK)) and all_passed
	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] open_job_test: %s" % label)
		return true
	print("[FAIL] open_job_test: %s (got %s, expected %s)" % [label, str(actual), str(expected)])
	return false
