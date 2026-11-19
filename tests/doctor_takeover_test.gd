# EventSheets - the Project Doctor's worker threads can be stopped, and the tables they share survive being shared.
#
# An audit in the editor runs pieces of itself on worker threads. Two things follow that the plain audit never met:
# something may need every worker gone at once (the editor quitting, a whole audit asked for while the window's is under
# way), and the tables the workers read - the texts held for the audit, the compiled patterns - are touched by more than
# one thread. This pins both: `stop_all` leaves no worker running, a text read by a worker is not written into the shared
# table by it, and many threads asking and filling the tables at once lose nothing.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "doctor_takeover_test"
const ProjectFiles := preload("res://addons/eventforge/project_files.gd")
const BACKGROUND := preload("res://addons/eventforge/doctor_background.gd")
const PREFETCH := preload("res://addons/eventforge/doctor_sheet_prefetch.gd")
const SAVE_KEY_SCAN := preload("res://addons/eventforge/save_key_scan.gd")

const THREADS: int = 4
const TURNS: int = 400


static func run() -> bool:
	var rows: Array = []
	rows.append_array(_stop_rows())
	rows.append_array(_table_rows())
	rows.append_array(_read_only_rows())
	rows.append_array(_open_while_lifting_rows())
	return SUPPORT.pins(P, rows)


## Every kind of worker the audit starts is gone after `stop_all`.
static func _stop_rows() -> Array:
	var reader: RefCounted = BACKGROUND.new()
	reader.start_reading(ProjectFiles.all_scripts())
	var lister: RefCounted = BACKGROUND.new()
	lister.start_listing()
	BACKGROUND.stop_all()
	var open_job_class: GDScript = load("res://addons/eventforge/importer/open_job.gd")
	var lifter: RefCounted = PREFETCH.new()
	var started: bool = lifter.begin(ProjectFiles.all_scripts().slice(0, 40), open_job_class)
	PREFETCH.stop_all()
	var rows: Array = [
		["a reader that was stopped is not running", reader.is_running(), false],
		["a lister that was stopped is not running", lister.is_running(), false],
		["the lifter started", started, true],
		["a lifter that was stopped is not running", lifter.is_running(), false],
		["no job is left in the list of running ones", BACKGROUND._live.size(), 0],
		["the lifter's cancel flag is clear after it was stopped", EventSheetACELifter.cancel_requested, false],
	]
	lifter.finish(open_job_class)
	return rows


## Threads filling and reading the shared tables at once lose no entry and corrupt nothing.
static func _table_rows() -> Array:
	EventSheetProjectDoctor._cache_clear()
	SAVE_KEY_SCAN._regex_cache.clear()
	EventSheetProjectDoctor._share_locks(true)
	var threads: Array[Thread] = []
	for number: int in range(THREADS):
		var thread: Thread = Thread.new()
		thread.start(_hammer.bind(number))
		threads.append(thread)
	_hammer(THREADS)
	for thread: Thread in threads:
		thread.wait_to_finish()
	var texts: int = EventSheetProjectDoctor._source_cache.size()
	var patterns: int = SAVE_KEY_SCAN._regex_cache.size()
	var sample: Variant = EventSheetProjectDoctor._cache_get("res://hammer/%d_%d" % [2, TURNS - 1])
	EventSheetProjectDoctor._share_locks(false)
	EventSheetProjectDoctor._cache_clear()
	SAVE_KEY_SCAN._regex_cache.clear()
	return [
		["every text put by every thread is in the table", texts, (THREADS + 1) * TURNS],
		["every pattern asked for by every thread is compiled once", patterns, TURNS],
		["a text put by a thread is the one read back", sample, "text 2 %d" % (TURNS - 1)],
		["the locks are let go of after the audit", EventSheetProjectDoctor._cache_lock == null and SAVE_KEY_SCAN.lock == null, true],
	]


static func _hammer(number: int) -> void:
	for turn: int in range(TURNS):
		EventSheetProjectDoctor._cache_put("res://hammer/%d_%d" % [number, turn], "text %d %d" % [number, turn])
		EventSheetProjectDoctor._cache_get("res://hammer/%d_%d" % [(number + 1) % (THREADS + 1), turn])
		SAVE_KEY_SCAN._cached_regex("pattern%d" % turn)


## A worker that reads a text for itself hands it back and does not put it in the table the main thread owns.
static func _read_only_rows() -> Array:
	var path: String = "res://project.godot"
	var was_running: bool = EventSheetProjectDoctor._run_in_progress
	EventSheetProjectDoctor._cache_clear()
	EventSheetProjectDoctor._run_in_progress = true
	var answers: Array = []
	var thread: Thread = Thread.new()
	thread.start(func() -> void: answers.append(EventSheetProjectDoctor.source_of(path)))
	thread.wait_to_finish()
	var held_after_worker: Variant = EventSheetProjectDoctor._cache_get(path)
	var here: String = EventSheetProjectDoctor.source_of(path)
	var held_after_main: Variant = EventSheetProjectDoctor._cache_get(path)
	EventSheetProjectDoctor._run_in_progress = was_running
	EventSheetProjectDoctor._cache_clear()
	return [
		["a worker reads the file's text", answers[0] == FileAccess.get_file_as_string(path), true],
		["the worker's text is not kept in the shared table", held_after_worker, null],
		["the main thread keeps what it reads during an audit", held_after_main, here],
	]


## Opening a sheet while the Doctor's worker is lifting does not wait for that worker: the open call returns at once
## with the job waiting, and the job's own worker begins when the Doctor's has left.
static func _open_while_lifting_rows() -> Array:
	var open_job_class: GDScript = load("res://addons/eventforge/importer/open_job.gd")
	var asked: Array = [0]
	var busy: Array = [true]
	open_job_class.preempt_background = func() -> void: asked[0] = int(asked[0]) + 1
	open_job_class.background_running = func() -> bool: return bool(busy[0])
	var job: RefCounted = open_job_class.new()
	var started: bool = job.start("res://tests/fixtures/handwritten_state_patrol.gd")
	var waiting: bool = bool(job.get("_deferred"))
	var done_while_busy: bool = job.is_done()
	var lifting_while_waiting: bool = bool(open_job_class.lifting_now())
	busy[0] = false
	var waited: int = 0
	while not job.is_done() and waited < 20000:
		OS.delay_msec(5)
		waited += 5
	var sheet: EventSheetResource = job.finish() as EventSheetResource
	open_job_class.preempt_background = Callable()
	open_job_class.background_running = Callable()
	var direct: EventSheetResource = EventSheetGDScriptImporter.new().import_external("res://tests/fixtures/handwritten_state_patrol.gd")
	return [
		["the open call returns true while the Doctor's worker is running", started, true],
		["the Doctor's worker was asked to stop", asked[0], 1],
		["the open waits for it, without a thread of its own yet", waiting, true],
		["and it is not done while that worker runs", done_while_busy, false],
		["the lifter counts as in use while the open waits", lifting_while_waiting, true],
		["the open comes to its end once the worker has left", sheet != null, true],
		["and it is the sheet a plain open gives", sheet.events.size() if sheet != null else -1, direct.events.size() if direct != null else -2],
	]
