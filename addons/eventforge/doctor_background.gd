# Godot EventSheets - the Project Doctor's plain disk work, done on worker threads.
#
# An audit of a big project starts with two things that are nothing but waiting on the disk: listing
# every folder of the project, and reading the text of every script and scene. Run on the main thread
# they hold a frame for as long as the disk takes, which on ten thousand files is seconds. Neither
# touches the scene tree, a resource or an editor object, so both run here on threads of their own
# (`DirAccess` and `FileAccess` handles are made fresh on each thread), while the main thread keeps
# drawing and waits on them a frame at a time.
#
# Only plain strings and arrays cross back. The threads are plain `Thread`s rather than pool tasks, so a
# pool with a single worker (or one the editor is busy with) can never leave the audit waiting for a
# slot, and each is joined before the answer is handed on, so nothing outlives the audit.
#
# DELIBERATELY NO `class_name`, so loading it compiles nothing more: the Doctor reaches it by path.
@tool
extends RefCounted

const ProjectListing := preload("res://addons/eventforge/project_listing.gd")

## What a `.tres` header says about being a sheet.
const SHEET_YES: int = 1
const SHEET_NO: int = 0
## A header that cannot say (a resource with a script of some other class): the main thread loads it.
const SHEET_UNSURE: int = -1

## The jobs with a worker still running, so whoever must end the audit now (the editor quitting, a synchronous
## audit asked for while the window's is under way) can stop and join every one of them: `stop_all`.
static var _live: Array = []

var _threads: Array[Thread] = []
var _stop: bool = false
var _listing: Array = []
var _verdicts: Dictionary = {}
var _slices: Array = []
var _work_result: Variant = null


## The project's folders and files, and which `.tres` files are event sheets, made on a worker.
## A coroutine (await it); answers {"listing": Array, "verdicts": {path: SHEET_*}} or {} when `cancelled`.
static func list_project(tree: SceneTree, cancelled: Callable) -> Dictionary:
	var job: RefCounted = load("res://addons/eventforge/doctor_background.gd").new()
	if not job.start_listing():
		# No thread to be had: the caller lists the project itself, as it always did.
		return {}
	while job.is_running():
		await tree.process_frame
		if cancelled.is_valid() and bool(cancelled.call()):
			job.stop()
	return job.finish_listing()


## The text of every one of `paths`, read on a few workers. A coroutine; answers {path: text} for the files
## it read (all of them unless `cancelled` stopped it early).
static func read_texts(paths: PackedStringArray, tree: SceneTree, cancelled: Callable) -> Dictionary:
	var job: RefCounted = load("res://addons/eventforge/doctor_background.gd").new()
	if paths.is_empty() or not job.start_reading(paths):
		return {}
	while job.is_running():
		await tree.process_frame
		if cancelled.is_valid() and bool(cancelled.call()):
			job.stop()
	return job.finish_reading()


## `work` (a Callable answering a value, touching only plain data) run on a worker while the frames go on: a coroutine
## (await it). The answer is what `work` returned.
static func run_work(work: Callable, tree: SceneTree) -> Variant:
	var job: RefCounted = load("res://addons/eventforge/doctor_background.gd").new()
	var thread: Thread = Thread.new()
	if thread.start(job._do_work.bind(work), Thread.PRIORITY_LOW) != OK:
		return work.call()
	job._threads.append(thread)
	_live.append(job)
	while job.is_running():
		await tree.process_frame
	job._join()
	return job._work_result


func _do_work(work: Callable) -> void:
	_work_result = work.call()


func start_listing() -> bool:
	var thread: Thread = Thread.new()
	if thread.start(_list, Thread.PRIORITY_LOW) != OK:
		return false
	_threads.append(thread)
	_live.append(self)
	return true


func start_reading(paths: PackedStringArray) -> bool:
	var workers: int = clampi(OS.get_processor_count() - 1, 1, 4)
	var per_worker: int = int(ceil(float(paths.size()) / float(workers)))
	for index: int in range(workers):
		var slice: PackedStringArray = paths.slice(index * per_worker, mini((index + 1) * per_worker, paths.size()))
		if slice.is_empty():
			continue
		var held: Dictionary = {"paths": slice, "texts": PackedStringArray()}
		_slices.append(held)
		var thread: Thread = Thread.new()
		if thread.start(_read.bind(held), Thread.PRIORITY_LOW) != OK:
			# The slice no thread took is read by the caller as it always was (a file not held is read when asked).
			_slices.erase(held)
			continue
		_threads.append(thread)
	if not _threads.is_empty():
		_live.append(self)
	return not _threads.is_empty()


func is_running() -> bool:
	for thread: Thread in _threads:
		if thread.is_alive():
			return true
	return false


func stop() -> void:
	_stop = true


func finish_listing() -> Dictionary:
	_join()
	if _stop:
		return {}
	return {"listing": _listing, "verdicts": _verdicts}


func finish_reading() -> Dictionary:
	_join()
	var texts: Dictionary = {}
	for held: Dictionary in _slices:
		var paths: PackedStringArray = held["paths"]
		var read: PackedStringArray = held["texts"]
		# A slice stopped part way holds fewer texts than paths; the ones it holds are the first ones.
		for index: int in range(read.size()):
			texts[paths[index]] = read[index]
	return texts


func _join() -> void:
	for thread: Thread in _threads:
		thread.wait_to_finish()
	_threads.clear()
	_live.erase(self)


## Stops every worker of every job and waits for each to finish: a listing or a read leaves at its next file, and
## a piece of work handed in finishes the piece it is in (a slice of about sixty milliseconds). Called on the main
## thread, by whoever must have no worker left running - the editor quitting, or a synchronous audit that is about
## to use the state the workers read. A job joined here answers what it had, and its waiting coroutine finds it done.
static func stop_all() -> void:
	for job: Variant in _live.duplicate():
		(job as RefCounted).call("stop")
		(job as RefCounted).call("_join")


func _list() -> void:
	_listing = ProjectListing.list_everything()
	for entry: Variant in _listing:
		if _stop:
			return
		var directory_path: String = (entry as Array)[0]
		# The same folders `EventSheetProjectFind.list_project_sheets` steps over: any named `addons`.
		if ProjectListing.inside_skipped(directory_path, ["addons"]):
			continue
		for file_name: String in ((entry as Array)[1] as PackedStringArray):
			if file_name.ends_with(".tres"):
				var full_path: String = directory_path.path_join(file_name)
				_verdicts[full_path] = _verdict_of(full_path)


## What the first line of a `.tres` says about whether the file is an event sheet: the header names the
## script class of its resource, so reading the line is the answer `load()` would give, without loading.
static func _verdict_of(path: String) -> int:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return SHEET_UNSURE
	var header: String = file.get_line()
	if not header.begins_with("[gd_resource"):
		return SHEET_UNSURE
	if header.contains("script_class=\"EventSheetResource\""):
		return SHEET_YES
	# Only a plain `Resource` with a script attached can be a sheet; any other type is not one.
	if not header.contains("type=\"Resource\""):
		return SHEET_NO
	return SHEET_UNSURE


func _read(held: Dictionary) -> void:
	var paths: PackedStringArray = held["paths"]
	var texts: PackedStringArray = PackedStringArray()
	for path: String in paths:
		if _stop:
			break
		texts.append(FileAccess.get_file_as_string(path))
	held["texts"] = texts
