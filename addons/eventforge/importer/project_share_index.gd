# Godot EventSheets - the ONE project-wide answer to "who else uses this file".
#
# A resource is SHARED. One `.tres` material worn by twelve goblins is one object at run time, so a
# row turning a dial on one of them turns it on all twelve; one environment `.tres` held by four
# rooms follows the player between them. Both facts are worth saying on the head of a sheet, and
# neither can be answered without looking at every scene in the project.
#
# WHICH IS THE EXPENSIVE PART, and the reason this exists rather than each asker walking the scenes
# itself. Three rules, and they are the whole design:
#
#   ONE SCAN. Every scene is read once and everything it holds is filed at that moment - not once per
#   question, which is what a per-resource cache quietly turns into on the fourth question.
#   NEVER ON THE OPEN. The first build is TIME-SLICED: `advance()` reads as many scenes as fit in a
#   few milliseconds and hands the frame back, so opening a sheet in a thousand-scene project never
#   waits for it. A band asking before the scan finishes is told exactly that, and says "counting…"
#   rather than stalling - and is TOLD WHEN IT IS OVER, because a band's words are worked out while
#   its rows are built and a scan finishing is not a row build. Without that the first sheet of a
#   session says "counting…" until something unrelated rebuilds it, which for a sheet nobody touches
#   is never.
#   DROPPED WHEN THE FILES CHANGE. The editor's own filesystem signal clears it; the next question
#   starts a fresh scan. A session-lifetime answer is right while the editor runs and wrong the
#   moment somebody saves a scene.
#
# `build_now()` is the synchronous door, for headless callers and tests - anything with no frames to
# spread the work across, and for the one shipped asker whose contract has always been to block on
# its first question.
#
# PURE + STATIC: paths in, plain values out. No dock, no canvas, no editor.
@tool
class_name EventSheetProjectShareIndex
extends RefCounted

## How long one slice of the first build may take. Small enough that a frame carrying one is
## indistinguishable from a frame that is not, which is the only budget worth having here: the scan
## finishes a few frames later either way, and nobody is waiting on it.
const SLICE_BUDGET_MSEC: int = 4

## The node member a shader material is worn on, kept beside the walk that reads it.
const MATERIAL_KEY: String = "material_path"

## THE OTHER THREE PLACES A MATERIAL IS WORN, and the reason the scan reads them itself rather than
## asking the effects walk. That walk answers one question - `material`, the CanvasItem member every
## 2D effect row spells - and deliberately stops there. A MESH wears its material somewhere else
## entirely: on `material_override` for the whole mesh, or on `surface_material_override/N` for one
## surface slot of it. Without those two, "who else wears this material" answered nothing at all for
## a 3D scene, however many meshes were sharing one `.tres`.
##
## And `next_pass` is the third: a material that hands the drawing on to another one makes its wearer
## a wearer of that one too, which is what makes the question answerable for a layer laid over a
## surface. It is a property of the MATERIAL rather than of the node, so it is followed through the
## material reader's own chain walk instead of read off a node header.
const MESH_OVERRIDE_KEY: String = "material_override"
const SURFACE_OVERRIDE_PREFIX: String = "surface_material_override/"

## How the scene file spells a pointer at a file. A `SubResource(...)` is a material the scene keeps
## inside itself, which by definition nobody else is wearing, so it is not filed as shared.
const EXT_RESOURCE_HEAD: String = "ExtResource("

## resource path -> the scenes holding it, in path order. Every ext_resource of every scene, so one
## scan answers the material question and the environment one and whatever the next one is.
static var _holders: Dictionary = {}

## material resource path -> the nodes wearing it, each {"scene_path", "path", "name"}. The count a
## head band shows: a material worn twice in one scene is shared with one other node, which counting
## scenes could never say.
static var _wearers: Dictionary = {}

## scene path -> the MESHES of that scene that wear a material file, each {"name", "path", "class",
## "materials"}. The wearer map above answers "who else wears this file"; this answers the other half
## of the same question - "what does this mesh wear" - which is what a row about a mesh's colour has
## to know before anything can be said about who else that colour moves.
static var _mesh_wearers: Dictionary = {}

## function name -> the project scripts that call it, in path order. The answer to "who else calls
## this?", which a function's own head band says and a rename has to say before it changes anything.
##
## BY NAME, and the wording everywhere says so: a script calling `take_damage` on something is filed
## under `take_damage` whatever it was holding. Reading the types instead would need the whole
## project's type inference to be right, and being quietly wrong about who calls a function is worse
## than being plainly approximate about it - a rename listing one file too many costs a glance, and
## one too few costs a broken game.
static var _callers: Dictionary = {}

## The call pattern, built once for the whole scan (see _call_regex).
static var _calls_regex: RegEx = null

## The scenes to read, and how far down them the scan has got. A COPY of the project's scene list,
## never the list itself: `EventSheetSceneConnections.scene_paths()` hands back the static it caches,
## and reading scenes off it in place emptied the one index the whole plugin asks "which scenes are
## there" - after which nothing could find any scene at all. A cursor rather than taking the front
## off, so a thousand scenes cost one pass and not a thousand shuffles.
static var _pending: PackedStringArray = PackedStringArray()
static var _next: int = 0
static var _started: bool = false

## The scripts to read, and how far down THEM the scan has got. A second list rather than a longer
## first one, and read strictly after it, because the two halves answer different questions and one
## of them has a caller that blocks: "which scenes hold this file" must not wait on a pass over every
## script in the project to be able to answer.
static var _pending_scripts: PackedStringArray = PackedStringArray()
static var _next_script: int = 0

## file identity -> the names that file calls. The scan is dropped whole whenever the filesystem
## changes, and re-reading a thousand unchanged scripts on the strength of one saved file is most of
## what a rebuild would otherwise cost. Keyed by `path|mtime|size`, so an entry is either current or
## unreachable; it outlives `clear_cache` on purpose, which is what makes the rebuild cheap.
static var _calls_by_file: Dictionary = {}

## Whether a slice is already scheduled, so a hundred questions in one frame arm one pump and not a
## hundred.
static var _pumping: bool = false

## Who to tell when a scan finishes. The counts a head band shows are worked out while the ROWS are
## built, and a scan finishing is not a row build - so without this the first sheet of a session
## says "counting…" for as long as it stays open and nothing else touches it, which is the one
## promise the slicing makes and the one it was not keeping. Callables whose object has gone are
## dropped as they are found: a dock closed mid-scan is the ordinary case, not an error.
static var _when_counted: Array[Callable] = []


## Starts the scan if it has not started, and returns whether it has already finished. Cheap to call
## from anywhere, including from the question itself - which is where it IS called from, so nothing
## has to remember to start it.
static func request() -> bool:
	if not _started:
		_started = true
		# ONE scan, two halves: every scene, then every script. One module, one cache, one drop - and
		# the halves in that order because the scene answers have a caller that blocks on them.
		_pending = EventSheetSceneConnections.scene_paths().duplicate()
		_pending_scripts = EventSheetProjectDoctor.all_project_scripts()
		_next = 0
		_next_script = 0
		_holders.clear()
		_wearers.clear()
		_mesh_wearers.clear()
		_callers.clear()
	if is_ready():
		return true
	_arm()
	return false


## The same, for a reader that only needs the SCENE half - "who else holds this file", "who else
## wears this material". It answers as soon as the scenes are read rather than waiting on the pass
## over every script, which is a question those readers never asked.
static func request_scenes() -> bool:
	request()
	return scenes_ready()


## True when everything has been read and every answer below is final.
static func is_ready() -> bool:
	return scenes_ready() and _next_script >= _pending_scripts.size()


## True when the SCENE half is final - which is all "who else holds this file" needs.
static func scenes_ready() -> bool:
	return _started and _next >= _pending.size()


## Asks to be told when a scan finishes, so a band that said "counting…" can be built again with the
## count in it. Registering twice is one registration; a listener stays for the session and is asked
## again after each fresh scan, because the filesystem ping starts one.
static func when_counted(listener: Callable) -> void:
	if listener.is_valid() and not _when_counted.has(listener):
		_when_counted.append(listener)


static func stop_telling(listener: Callable) -> void:
	_when_counted.erase(listener)


## Reads scenes until the budget is spent, and answers whether that finished the scan. The editor
## calls this a slice at a time; a caller with no frames to give calls `build_now()` instead.
static func advance(budget_msec: int = SLICE_BUDGET_MSEC) -> bool:
	var deadline: int = Time.get_ticks_msec() + maxi(budget_msec, 1)
	if not _advance_scenes(deadline):
		return false
	while _next_script < _pending_scripts.size() and Time.get_ticks_msec() < deadline:
		_read_script(_pending_scripts[_next_script])
		_next_script += 1
	if _next_script < _pending_scripts.size():
		return false
	_sort_holders()
	return true


## The scene half of one slice, and whether that finished it. Its own function because the scene
## answers have a caller that blocks on them and must not be carried on into the script half.
static func _advance_scenes(deadline: int) -> bool:
	while _next < _pending.size() and Time.get_ticks_msec() < deadline:
		_read_scene(_pending[_next])
		_next += 1
	return _next >= _pending.size()


## The whole scan, now. What a headless run, a health check and a test use, and what the one shipped
## asker that has always blocked on its first question goes on using - the answer is the same either
## way, and only the waiting differs.
static func build_now() -> void:
	request()
	while not advance(1000):
		pass


## The SCENE half, now - what "who else holds this file" blocks on. The script half is left to the
## slices, because a question about scenes should not pay for a pass over every script in the
## project: on this repository that is a second of waiting for an answer that was already there.
static func build_scenes_now() -> void:
	request()
	while not _advance_scenes(Time.get_ticks_msec() + 1000):
		pass
	_sort_holders()


## Every scene holding one resource file, in path order. Empty while the scan is still running, which
## is why `is_ready()` is asked beside it rather than an empty answer being read as "nobody".
static func holders_of(resource_path: String) -> PackedStringArray:
	return _holders.get(resource_path, PackedStringArray())


## Every node of the project wearing one material file, in scan order, each {"scene_path", "path",
## "name"}. The head band's count, and the health check's list of who else a dial would move.
static func wearers_of(material_path: String) -> Array[Dictionary]:
	return _wearers.get(material_path, [] as Array[Dictionary])


## Every scene holding one resource file EXCEPT the asker's own, which is what "shared with" means
## everywhere it is said.
static func other_holders(resource_path: String, own_scene: String) -> PackedStringArray:
	var others: PackedStringArray = PackedStringArray()
	for scene_path: String in holders_of(resource_path):
		if scene_path != own_scene:
			others.append(scene_path)
	return others


## Every node wearing one material EXCEPT one, addressed as "scene path|node path" - the same
## spelling a head band's gestures use, so a band can leave itself out of its own count.
static func other_wearers(material_path: String, own_reference: String) -> Array[Dictionary]:
	var others: Array[Dictionary] = []
	for wearer: Dictionary in wearers_of(material_path):
		if "%s|%s" % [str(wearer["scene_path"]), str(wearer["path"])] != own_reference:
			others.append(wearer)
	return others


## Every project script that calls a function of this name, in path order, leaving out `own_script` -
## which is nearly always the file the question is being asked about, and "this file calls it" is not
## news. Empty while the scan is still running, which is why `is_ready()` is asked beside it rather
## than an empty answer being read as "nobody".
static func callers_of(function_name: String, own_script: String = "") -> PackedStringArray:
	var callers: PackedStringArray = PackedStringArray()
	if function_name.strip_edges().is_empty():
		return callers
	for script_path: String in _callers.get(function_name, PackedStringArray()):
		if script_path != own_script:
			callers.append(script_path)
	return callers


## Drops the scan, so the next question starts a fresh one. The editor calls this when the filesystem
## changes; tests call it between fixtures, for the same reason every reader beside this one does.
static func clear_cache() -> void:
	_holders.clear()
	_wearers.clear()
	_mesh_wearers.clear()
	_callers.clear()
	_pending = PackedStringArray()
	_pending_scripts = PackedStringArray()
	_next = 0
	_next_script = 0
	_started = false


## One scene filed: every resource file it loads, and every node of it that wears a material. Both
## come from the readers that already answer those questions and cache their own parses, so the scan
## warms them rather than being a second parser of the same files.
static func _read_scene(scene_path: String) -> void:
	for held: Variant in EventSheetSceneConnections.resource_paths_of_scene(scene_path).values():
		var resource_path: String = str(held)
		if not _holders.has(resource_path):
			_holders[resource_path] = PackedStringArray()
		var holders: PackedStringArray = _holders[resource_path]
		if not holders.has(scene_path):
			holders.append(scene_path)
			_holders[resource_path] = holders
	for node: Dictionary in EventSheetSceneEffects.for_scene(scene_path):
		_file_wearer(str(node.get(MATERIAL_KEY, "")), scene_path, str(node.get("path", "")),
			str(node.get("name", "")))
	_read_mesh_wearers(scene_path)


## The MESHES of one scene that wear a material file, filed both ways at once: under the material,
## so "who else wears this" answers for a 3D scene, and under the scene, so "what does this mesh
## wear" answers for a row about one mesh's colour. Both halves come off the same node headers the
## parse cache already holds, so the second question costs no second read of the file.
static func _read_mesh_wearers(scene_path: String) -> void:
	var files: Dictionary = EventSheetSceneConnections.resource_paths_of_scene(scene_path)
	if files.is_empty():
		return
	var found: Array[Dictionary] = []
	for entry: Variant in EventSheetSceneConnections.nodes_of_scene(scene_path):
		var node: Dictionary = entry
		var worn: PackedStringArray = PackedStringArray()
		for key: Variant in (node.get("properties", {}) as Dictionary):
			var member: String = str(key)
			if member != MESH_OVERRIDE_KEY and not member.begins_with(SURFACE_OVERRIDE_PREFIX):
				continue
			var material_path: String = _file_behind(
				str((node.get("properties", {}) as Dictionary)[key]), files)
			if material_path.is_empty() or worn.has(material_path):
				continue
			worn.append(material_path)
			_file_wearer(material_path, scene_path, str(node.get("path", "")),
				str(node.get("name", "")))
		if worn.is_empty():
			continue
		found.append({"name": str(node.get("name", "")), "path": str(node.get("path", "")),
			"class": str(node.get("type", "")), "materials": worn})
	if not found.is_empty():
		_mesh_wearers[scene_path] = found


## One node filed as a wearer of one material, and of every material that one hands the drawing on
## to. The chain matters because a layer laid over a surface is a second material the same node is
## wearing - a row that changes it changes it for every other node down the same chain, and a count
## that stopped at the first material would say nobody else was there.
static func _file_wearer(material_path: String, scene_path: String, node_path: String,
		node_name: String) -> void:
	if material_path.strip_edges().is_empty():
		return
	var chain: Array[Dictionary] = EventSheetSceneEffects.pass_chain(material_path)
	var worn: PackedStringArray = PackedStringArray()
	for pass_entry: Dictionary in chain:
		var passed: String = str(pass_entry.get(MATERIAL_KEY, ""))
		if not passed.is_empty() and not worn.has(passed):
			worn.append(passed)
	if worn.is_empty():
		worn.append(material_path)
	for held: String in worn:
		if not _wearers.has(held):
			_wearers[held] = [] as Array[Dictionary]
		(_wearers[held] as Array[Dictionary]).append({
			"scene_path": scene_path, "path": node_path, "name": node_name})


## The `res://` file behind a node property, or "" when the property points at a resource the scene
## keeps inside itself (which nobody else can be wearing) or at nothing at all.
static func _file_behind(held: String, files: Dictionary) -> String:
	var text: String = held.strip_edges()
	if not text.begins_with(EXT_RESOURCE_HEAD):
		return ""
	return str(files.get(text.get_slice("\"", 1), ""))


## Every mesh of one scene that wears a material file, in scene order. Empty for a scene with no
## meshes in it, and while the scan is still running - which is why `scenes_ready()` is asked beside
## it rather than an empty answer being read as "this scene has none".
static func mesh_wearers_in(scene_path: String) -> Array[Dictionary]:
	return _mesh_wearers.get(scene_path, [] as Array[Dictionary])


## Every name ONE script calls, filed under that name. A declaration is not a call - `func hurt(` and
## `signal hurt(` are where the name lives, not where it is used - so the two are the only shapes
## taken back out; a name inside a comment or a string is left in, because sorting those out would
## cost a parse and the answer is a list to glance at, never a list anything acts on by itself.
static func _read_script(script_path: String) -> void:
	for name: String in _names_called_by(script_path):
		if not _callers.has(name):
			_callers[name] = PackedStringArray()
		var callers: PackedStringArray = _callers[name]
		if not callers.has(script_path):
			callers.append(script_path)
			_callers[name] = callers


## The names one file calls, read once per version of that file. The scan is dropped whenever
## anything in the project changes, so without this a saved file cost a fresh read of every other
## script in the project as well.
static func _names_called_by(script_path: String) -> PackedStringArray:
	var stamp: String = EventForgeFileStamp.of(script_path)
	if _calls_by_file.has(stamp):
		return _calls_by_file[stamp]
	var names: PackedStringArray = PackedStringArray()
	for called: RegExMatch in _call_regex().search_all(FileAccess.get_file_as_string(script_path)):
		var name: String = called.get_string(1)
		if not names.has(name):
			names.append(name)
	_calls_by_file[stamp] = names
	return names


## Compiled once and shared: this runs over every script of the project, and building the same
## pattern a thousand times is the whole cost of the pass.
static func _call_regex() -> RegEx:
	if _calls_regex == null:
		_calls_regex = RegEx.create_from_string("(?<!func )(?<!signal )\\b([A-Za-z_][A-Za-z0-9_]*)[ \\t]*\\(")
	return _calls_regex


## Path order, once, at the end of the scan - so two runs of it answer in the same order however the
## filesystem happened to hand the files over.
static func _sort_holders() -> void:
	for resource_path: Variant in _holders.keys():
		var holders: PackedStringArray = _holders[resource_path]
		holders.sort()
		_holders[resource_path] = holders
	for function_name: Variant in _callers.keys():
		var callers: PackedStringArray = _callers[function_name]
		callers.sort()
		_callers[function_name] = callers


## Schedules the next slice on the editor's own next frame. It costs no node, no timer and nothing
## at plugin boot.
##
## ONLY IN THE EDITOR, which is the only place there are frames to spread work over. A headless run -
## a test, the Doctor's command line, a build - fills the index through `build_now()` instead, and
## gets the same answer with none of the timing: a scan that finished half way through a suite
## because an idle frame happened to arrive is a suite that passes differently on a slower machine.
static func _arm() -> void:
	if _pumping:
		return
	_pumping = _schedule_slice()


## Puts the next slice on the NEXT FRAME, and answers whether it got there.
##
## THE FRAME SIGNAL RATHER THAN A DEFERRED CALL. A deferred call is flushed at the end of the frame
## that posted it, and that flush is re-entrant - it goes on consuming whatever was pushed while it
## was running - so a slice that re-armed with one was run inside the same flush, and the whole scan
## finished in a single frame rather than a few milliseconds of each. Which is exactly the stall the
## budget above exists to prevent. A connection made while a signal is being emitted is not part of
## that emission, so this is one slice per frame and no more.
##
## No main loop (a `--script` run, a test) means no frames to spread anything over, and false back
## to the caller so a later question tries again rather than waiting on a slice nobody scheduled.
static func _schedule_slice() -> bool:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or not Engine.is_editor_hint():
		return false
	tree.process_frame.connect(Callable(EventSheetProjectShareIndex, "_pump"), CONNECT_ONE_SHOT)
	return true


static func _pump() -> void:
	_pumping = false
	if not advance():
		_arm()
		return
	# A slice scheduled before the cache was dropped arrives at a scan that no longer exists, and
	# has finished nothing. `is_ready()` is the one place that knows the difference.
	if is_ready():
		_tell_the_askers()


## Tells everyone still listening that the counts are final, dropping the ones whose object has gone
## on the way past. Only the sliced path says it: `build_now()` hands its own caller the finished
## index as it returns, so there is nobody left to tell.
static func _tell_the_askers() -> void:
	var live: Array[Callable] = []
	for listener: Callable in _when_counted:
		if not listener.is_valid():
			continue
		live.append(listener)
		listener.call()
	_when_counted = live
