# Godot EventSheets - scripts opened as sheets on a worker thread, for the Project Doctor.
#
# Opening a script as a sheet runs the lift, which is hundreds of milliseconds on a big file and seconds
# on a very big one. Run inline inside an audit it holds one frame for all of that, however finely the
# audit is sliced around it. So the audit asks for the scripts it is about to read as sheets first, here:
# one worker opens them one after the other (the lifter keeps its working state in statics, so two lifts
# never run at once) while the main thread goes on drawing, and the audit then finds each one held.
#
# It is the same importer call `EventSheetProjectDoctor.sheet_of` makes, on the same thread-safety terms
# as the editor's own asynchronous open (EventSheetOpenJob): the registries the lift reads are built on
# the main thread first, and the sheets the worker builds are touched by nobody until it has stopped.
# A sheet the reader opens meanwhile takes priority - the lift in progress is told to stop, and the
# remaining scripts are asked again once the reader's open has finished.
#
# DELIBERATELY NO `class_name`, so loading it compiles nothing more: the Doctor reaches it by path.
@tool
extends RefCounted

const OPEN_JOB_PATH: String = "res://addons/eventforge/importer/open_job.gd"

## The job whose worker is running, so `stop_all` can end it: there is one at a time.
static var _running_job: RefCounted = null

var _thread: Thread = null
var _paths: PackedStringArray = PackedStringArray()
## path -> sheet, written only by the worker and read only after it has stopped.
var _sheets: Dictionary = {}
## How many of `_paths` the worker finished before it stopped.
var _done: int = 0
var _stop: bool = false
var _joined: bool = false
## "sheet": each script is opened as a sheet. "reading": each is read line by line by the Reading page's reader.
var _mode: String = "sheet"


## The scripts opened as sheets for `paths`, in turns: a coroutine (await it) that answers {path: sheet}
## for every path it finished. It stops promptly when `cancelled` says so, and gives back what it has.
static func open_all(paths: PackedStringArray, tree: SceneTree, cancelled: Callable, mode: String = "sheet") -> Dictionary:
	var open_job_class: GDScript = load(OPEN_JOB_PATH)
	var opened: Dictionary = {}
	var todo: PackedStringArray = paths
	while not todo.is_empty():
		if cancelled.is_valid() and bool(cancelled.call()):
			break
		# The reader's own open owns the lifter while it runs; this waits its turn.
		if open_job_class.lifting_now():
			await tree.process_frame
			continue
		await _warm_in_turns(tree)
		var job: RefCounted = load("res://addons/eventforge/doctor_sheet_prefetch.gd").new()
		if not job.begin(todo, open_job_class, mode):
			# No thread to be had: the caller's own synchronous opens are the fallback.
			break
		var asked_to_stop: bool = false
		while job.is_running():
			await tree.process_frame
			if not asked_to_stop and cancelled.is_valid() and bool(cancelled.call()):
				asked_to_stop = true
				job.request_stop()
		var finished: Dictionary = job.finish(open_job_class)
		opened.merge(finished["sheets"], true)
		todo = todo.slice(int(finished["done"]))
		if asked_to_stop:
			break
	return opened


## The registries a lift reads, built a piece at a time with a frame between: the first lift of a session builds
## them, which is a good part of a second in one go. They are the pieces `EventSheetOpenJob.warm_registries` builds,
## and that is asked last, so anything it builds that this does not is still built before the worker starts.
static var _warmed: bool = false


static func _warm_in_turns(tree: SceneTree) -> void:
	if _warmed:
		return
	_warmed = true
	var pieces: Array[Callable] = [
		func() -> void: ACERegistry.descriptor_count(),
		func() -> void: EventSheetACELifter._build_reverse_entries(),
		func() -> void: EventSheetACELifter.warm_matchers(),
		func() -> void: EventSheetBlockRegistry.all_kinds(),
		func() -> void: EventSheetActionCodegen._apply_template("{warm}", {"warm": ""}),
	]
	for piece: Callable in pieces:
		var started: int = Time.get_ticks_usec()
		piece.call()
		EventSheetProjectDoctor.note_main_work("warming a registry a lift reads", Time.get_ticks_usec() - started)
		await tree.process_frame


## Starts the worker over `paths`. False when no thread could be started.
func begin(paths: PackedStringArray, open_job_class: GDScript, mode: String = "sheet") -> bool:
	_mode = mode
	_paths = paths
	_sheets = {}
	_done = 0
	_stop = false
	_joined = false
	if EventSheetACELifter.lift_lock == null:
		EventSheetACELifter.lift_lock = Mutex.new()
	# Built here on the main thread, so the worker only ever reads them.
	var warmed: int = Time.get_ticks_usec()
	open_job_class.warm_registries()
	EventSheetProjectDoctor.note_main_work("warming the registries a lift reads", Time.get_ticks_usec() - warmed)
	EventSheetACELifter.reset_progress()
	_thread = Thread.new()
	if _thread.start(_run, Thread.PRIORITY_LOW) != OK:
		_thread = null
		return false
	open_job_class.preempt_background = ask_to_stop
	open_job_class.background_running = is_running
	_running_job = self
	return true


func _run() -> void:
	_lift_all()
	# A stop asked of this worker is cleared here, as the worker ends, so no lift of the editor's own that starts in
	# the gap before the main thread joins is cut short by it.
	if _stop:
		EventSheetACELifter.cancel_requested = false


func _lift_all() -> void:
	for index: int in range(_paths.size()):
		if _stop:
			return
		var answer: Variant = null
		if _mode == "reading":
			answer = EventSheetLiftReading.read(FileAccess.get_file_as_string(_paths[index]), _paths[index])
		else:
			answer = EventSheetGDScriptImporter.new().import_external(_paths[index])
		if _stop:
			# A lift cut short is the raw sheet: not an answer, and not counted as a call that was.
			if _mode != "reading":
				EventSheetGDScriptImporter.external_imports -= 1
			return
		_sheets[_paths[index]] = answer
		_done = index + 1


func is_running() -> bool:
	return _thread != null and not _joined and _thread.is_alive()


## Asks the worker to stop at the next function of the lift in hand.
func request_stop() -> void:
	_stop = true
	EventSheetACELifter.cancel_requested = true


## The reader is opening a sheet: asks the worker to stop at the next function of the lift in hand and goes on, without
## waiting. The reader's open begins its own worker once this one has left (see `EventSheetOpenJob.start`), so the click
## that opens a sheet is not held for as long as a very large function takes to finish.
func ask_to_stop() -> void:
	if _thread != null and not _joined:
		request_stop()


## Stops the worker and joins it now, for whoever must have it gone before going on.
func preempt() -> void:
	if _thread == null or _joined:
		return
	request_stop()
	_thread.wait_to_finish()
	_joined = true
	if _running_job == self:
		_running_job = null
	EventSheetACELifter.cancel_requested = false
	EventSheetACELifter.progress_phase = ""


## Stops the running worker, if there is one, and waits for it: for whoever must have no worker left (the editor
## quitting, a synchronous audit about to use what the worker reads). Its waiting coroutine finds it joined.
static func stop_all() -> void:
	if _running_job != null:
		_running_job.call("preempt")


## Joins the worker and answers {"sheets": {path: sheet}, "done": how many paths were finished}.
func finish(open_job_class: GDScript) -> Dictionary:
	if _thread != null and not _joined:
		_thread.wait_to_finish()
		_joined = true
	_thread = null
	if _running_job == self:
		_running_job = null
	if open_job_class.preempt_background == ask_to_stop:
		open_job_class.preempt_background = Callable()
		open_job_class.background_running = Callable()
	EventSheetACELifter.cancel_requested = false
	EventSheetACELifter.progress_phase = ""
	return {"sheets": _sheets, "done": _done}
