# EventForge - asynchronous "open a .gd as a sheet" job.
#
# Opening a .gd runs two passes: a fast raw line pass (rows + verbatim code blocks) and the ACE
# lift, which reverse-matches every function against the descriptor templates and then recompiles
# the whole sheet to byte-verify it. The lift is the expensive half - seconds on a large file - and
# run inline it froze the editor solid with no repaint, which reads as a crash.
#
# So the lift runs on a WORKER THREAD and the caller polls. `await` was not an option: any GDScript
# function containing `await` becomes a coroutine, and every existing caller of attempt_lift would
# become a parse error.
#
# THREAD SAFETY, in three parts:
#   1. SheetCompiler holds a mutex over compile() and emit_function_block_text() - the lift's
#      byte-verify recompiles from this thread while compile-on-save/Project Doctor may compile
#      from the main one, and they share per-compile scratch statics plus a scratch output file.
#   2. warm_registries() forces every lazily-built static the import path reads (the ACE descriptor
#      cache, the reverse-template index, the block-kind registry, the codegen template regex) to
#      be built on the MAIN thread first, so the worker only ever READS them.
#   3. The sheet the worker builds is touched by nobody else until the job reports done.
#
# ONE JOB AT A TIME: the lifter's progress/cancel state is process-wide statics, so a second start()
# is refused while one is running.
@tool
class_name EventSheetOpenJob
extends RefCounted

var _thread: Thread = null
var _path: String = ""
var _source_lines: int = 0
var _sheet: EventSheetResource = null
var _started_msec: int = 0
var _finished_msec: int = 0
var _canceled: bool = false


## Builds every lazily-initialised static the import path reads, on the calling (main) thread.
## Cheap once warm; the first call pays the one-time descriptor/registry build. Called by start(),
## and safe to call earlier (plugin boot deliberately does NOT - it would undo the lazy-boot win).
static func warm_registries() -> void:
	ACERegistry.get_all_descriptors()
	EventSheetACELifter._build_reverse_entries()
	EventSheetBlockRegistry.all_kinds()
	# The codegen template regex, compiled lazily on first substitution: the verify compile would
	# otherwise build it on the worker thread.
	ActionCodegen._apply_template("{warm}", {"warm": ""})


## Starts the import. Returns false when the file is missing or a job is already running.
func start(path: String) -> bool:
	if _thread != null:
		return false
	if not FileAccess.file_exists(path):
		return false
	_path = path
	_sheet = null
	_canceled = false
	_finished_msec = 0
	var source: String = FileAccess.get_file_as_string(path)
	_source_lines = source.split("\n").size()
	warm_registries()
	EventSheetACELifter.reset_progress()
	EventSheetACELifter.progress_phase = "reading"
	_started_msec = Time.get_ticks_msec()
	_thread = Thread.new()
	if _thread.start(_run) != OK:
		# No thread available (a platform without threading): fall back to the synchronous open so
		# the file still opens - slowly, but it opens.
		_thread = null
		_run()
		_finished_msec = Time.get_ticks_msec()
		return true
	return true


## The worker body. Runs the raw import first, then the lift, so the phase the strip shows matches
## what is actually happening.
func _run() -> void:
	var importer: GDScriptImporter = GDScriptImporter.new()
	var raw_sheet: EventSheetResource = importer.import_external(_path, false)
	if raw_sheet == null:
		_sheet = null
		return
	if not EventSheetACELifter.cancel_requested:
		EventSheetACELifter.progress_phase = "lifting"
		EventSheetACELifter.attempt_lift(raw_sheet, FileAccess.get_file_as_string(_path))
	if not EventSheetACELifter.cancel_requested:
		# Whether the engine can actually parse this file, asked of the engine itself. It costs a few
		# hundred milliseconds because it runs a second Godot, which is exactly why it belongs here on
		# the worker rather than anywhere near the paint path - and why the answer is cached per file.
		EventSheetACELifter.progress_phase = "checking"
		EventSheetParseErrors.store_on_sheet(raw_sheet, EventSheetParseErrors.check_file(_path))
	_sheet = raw_sheet


## Whether the worker has stopped. False while it runs; true once there is a result to collect
## (including the no-thread fallback, which finished inside start()).
func is_done() -> bool:
	if _thread == null:
		return _finished_msec > 0
	return _thread.is_started() and not _thread.is_alive()


## Asks the lift to stop at its next function. The job still runs to completion - it just returns
## the RAW sheet, the same state a file that cannot lift at all ends in.
func cancel() -> void:
	_canceled = true
	EventSheetACELifter.cancel_requested = true


func was_canceled() -> bool:
	return _canceled


## Joins the worker and returns the imported sheet (null when the file could not be read). Must be
## called once is_done(); calling it earlier blocks until the worker stops.
func finish() -> EventSheetResource:
	if _thread != null:
		_thread.wait_to_finish()
		_thread = null
		_finished_msec = Time.get_ticks_msec()
	EventSheetACELifter.progress_phase = ""
	EventSheetACELifter.cancel_requested = false
	return _sheet


## Display state for the progress strip. Read every frame from the main thread; the counters are
## written by the worker without a lock (see EventSheetACELifter) and are display-only.
func progress() -> Dictionary:
	var now: int = _finished_msec if _finished_msec > 0 else Time.get_ticks_msec()
	return {
		"path": _path,
		"phase": EventSheetACELifter.progress_phase,
		"lines": _source_lines,
		"functions_total": EventSheetACELifter.progress_functions_total,
		"functions_done": EventSheetACELifter.progress_functions_done,
		"elapsed_seconds": float(now - _started_msec) / 1000.0,
		"canceled": _canceled
	}


## 0.0-1.0 for the bar. Falls back to an elapsed-time creep while the function count is still
## unknown (the reading pass), so the bar never sits dead at zero.
func progress_ratio() -> float:
	var total: int = EventSheetACELifter.progress_functions_total
	if total <= 0:
		return minf(float(Time.get_ticks_msec() - _started_msec) / 4000.0, 0.9)
	return clampf(float(EventSheetACELifter.progress_functions_done) / float(total), 0.0, 1.0)


## The one-line human status under the title: what pass is running, and how far in.
func status_text() -> String:
	var state: Dictionary = progress()
	var phase: String = str(state["phase"])
	var detail: String = "reading %d lines" % int(state["lines"])
	if phase == "lifting" and int(state["functions_total"]) > 0:
		detail = "lifting functions %d of %d" % [int(state["functions_done"]), int(state["functions_total"])]
	elif phase == "verifying":
		detail = "checking the code still matches"
	elif phase == "checking":
		detail = "checking the script compiles"
	elif phase == "done":
		detail = "finishing up"
	return "%s · %.1f s" % [detail, float(state["elapsed_seconds"])]
