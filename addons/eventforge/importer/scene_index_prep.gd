@tool
extends RefCounted

## The first read of the project's two scene indexes, done in the editor's idle time instead of inside the
## first sheet a person opens.
##
## Both indexes (which scenes load a script, and which script each scene's root carries) are answers about
## EVERY scene in the project, and the first question about either one read every scene on the main thread:
## 1.1 seconds at ten thousand files, inside the frame the sheet was opened in. The plugin starts this soon
## after the editor's first scan, one thread reads everything once, and the first question that needs either
## index takes the answer: already here (the usual case), or waited for rather than read a second time.
##
## Nothing is ever answered from it that a read at that moment would not have answered. A file changed, moved
## or removed while it is held (or being read) drops it - the next question reads the project as it always
## did - and the plugin starts it again when the editor is quiet. What it holds is exactly what the two
## synchronous builds return: the same walk, the same order, the same text reads.
##
## It is only the FIRST read of each index: once a reader has asked for one (and so holds it, kept current
## by its own follow-the-change reads from then on) nothing is read for it again.
##
## The read runs on a thread of its own and reads files only; it shares nothing with the main thread until
## `finish()` hands the answer over.

const SWEEP := preload("res://addons/eventforge/importer/background_sweep.gd")
const SCENE_ROOTS := preload("res://addons/eventforge/importer/scene_root_sweep.gd")
const CONNECTIONS := preload("res://addons/eventforge/importer/scene_connections.gd")
const ROW_BUILDER_PATH := "res://addons/eventsheet/editor/interaction/viewport_row_builder.gd"

## The read being made, and whether something changed since it began (what it brings is then from before).
static var _job: RefCounted = null
static var _outdated: bool = false
## What a finished read holds and nothing has taken yet: the scene list, the scripts-to-scenes index and the
## scene roots index. Each part is taken once.
static var _paths: Variant = null
static var _connections: Variant = null
static var _roots: Variant = null
## Whether anybody still needs a first read of each index: a reader asking for one ends the need.
static var _wants_connections: bool = true
static var _wants_roots: bool = true
## How many reads were started, so a test can tell.
static var reads_started: int = 0
## Who is to be told when the read ends, and whether the frame poll that tells them is connected.
static var _askers: Array[Callable] = []
static var _polling: bool = false


## Starts the read on a worker thread, for the indexes nobody has asked for yet. A no-op
## while one is running, or finished and unclaimed - except that a finished read a change made stale is let
## go first. Returns whether a read was started.
static func start() -> bool:
	if _job != null:
		if not (_outdated and _job.is_done()):
			return false
		_arrive()
	if _connections != null or _roots != null:
		return false
	# An index a reader already built for itself needs no first read (the reader that is not loaded holds none).
	_wants_connections = _wants_connections and not CONNECTIONS.index_built()
	if ResourceLoader.has_cached(ROW_BUILDER_PATH) and load(ROW_BUILDER_PATH).scene_roots_index_built():
		_wants_roots = false
	if not (_wants_connections or _wants_roots):
		return false
	_outdated = false
	reads_started += 1
	var wants_connections: bool = _wants_connections
	var wants_roots: bool = _wants_roots
	_job = SWEEP.new(func() -> Array:
		var paths: PackedStringArray = PackedStringArray()
		var connections: Dictionary = {}
		if wants_connections:
			CONNECTIONS._walk_scene_paths("res://", paths)
			paths.sort()
			connections = CONNECTIONS.index_scenes(paths)
		var roots: Dictionary = SCENE_ROOTS.sweep_scenes_under("res://") if wants_roots else {}
		return [paths, connections if wants_connections else null, roots if wants_roots else null], true)
	return true


## Whether a read is under way or has finished and is waiting to be taken.
static func pending() -> bool:
	return _job != null or _connections != null or _roots != null


## Whether the thread is still reading.
static func running() -> bool:
	return _job != null and not _job.is_done()


## Something the read could have missed changed. A read under way is thrown away when it arrives, a
## finished one is dropped now. Cheap enough to call on every change.
static func invalidate() -> void:
	if _job != null:
		_outdated = true
	_paths = null
	_connections = null
	_roots = null


## The scenes-to-scripts half, {paths, index}, or null when there is none to give. Asking ends the need for a
## first read of it: the caller holds the index from here on, whatever this had to give. Waits for a read that
## is under way (a second one would read every scene again for the same answer) unless `wait` is false, when it
## gives nothing and the caller asks again through `tell_when_ready`. Gives nothing for a read a change has made
## stale.
static func take_connections(wait: bool = true) -> Variant:
	if not wait and running():
		return null
	_wants_connections = false
	if _job != null and _outdated:
		return null
	_arrive()
	if _connections == null:
		return null
	var answer: Dictionary = {"paths": _paths, "index": _connections}
	_paths = null
	_connections = null
	return answer


## The scene-roots half, {script path: [{scene_path, root_name}, ...]}, or null when there is none to give.
static func take_roots(wait: bool = true) -> Variant:
	if not wait and running():
		return null
	_wants_roots = false
	if _job != null and _outdated:
		return null
	_arrive()
	var answer: Variant = _roots
	_roots = null
	return answer


## Asks to be called once the read under way has ended (or at once, a frame later, when none is): the way a
## question that may not wait is told its answer has arrived. A caller asked twice is called once.
static func tell_when_ready(callback: Callable) -> void:
	if not _askers.has(callback):
		_askers.append(callback)
	_poll_for_askers()


static func _poll_for_askers() -> void:
	if _polling or _askers.is_empty():
		return
	var loop: SceneTree = Engine.get_main_loop() as SceneTree
	if loop == null:
		return
	_polling = true
	loop.process_frame.connect(_on_frame_for_askers, CONNECT_ONE_SHOT)


static func _on_frame_for_askers() -> void:
	_polling = false
	if running():
		_poll_for_askers()
		return
	var askers: Array[Callable] = _askers.duplicate()
	_askers.clear()
	for asker: Callable in askers:
		if asker.is_valid():
			asker.call()


## Takes the read when it is done (or is waited for) and keeps it, unless something changed meanwhile.
static func _arrive() -> void:
	if _job == null:
		return
	var job: RefCounted = _job
	_job = null
	var arrived: Array = job.finish()
	if _outdated:
		_outdated = false
		return
	_paths = arrived[0]
	_connections = arrived[1]
	_roots = arrived[2]


## Lets go of everything, joining the thread, and forgets what has been asked for. What the plugin does as it
## unloads, so a quit while the read is under way ends with the thread joined rather than left behind.
static func stop() -> void:
	if _job != null:
		_job.finish()
		_job = null
	_outdated = false
	_paths = null
	_connections = null
	_roots = null
	_wants_connections = true
	_wants_roots = true
	_askers.clear()
