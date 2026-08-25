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
#   rather than stalling.
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

## resource path -> the scenes holding it, in path order. Every ext_resource of every scene, so one
## scan answers the material question and the environment one and whatever the next one is.
static var _holders: Dictionary = {}

## material resource path -> the nodes wearing it, each {"scene_path", "path", "name"}. The count a
## head band shows: a material worn twice in one scene is shared with one other node, which counting
## scenes could never say.
static var _wearers: Dictionary = {}

## The scenes to read, and how far down them the scan has got. A COPY of the project's scene list,
## never the list itself: `EventSheetSceneConnections.scene_paths()` hands back the static it caches,
## and reading scenes off it in place emptied the one index the whole plugin asks "which scenes are
## there" - after which nothing could find any scene at all. A cursor rather than taking the front
## off, so a thousand scenes cost one pass and not a thousand shuffles.
static var _pending: PackedStringArray = PackedStringArray()
static var _next: int = 0
static var _started: bool = false

## Whether a slice is already scheduled, so a hundred questions in one frame arm one pump and not a
## hundred.
static var _pumping: bool = false


## Starts the scan if it has not started, and returns whether it has already finished. Cheap to call
## from anywhere, including from the question itself - which is where it IS called from, so nothing
## has to remember to start it.
static func request() -> bool:
	if not _started:
		_started = true
		_pending = EventSheetSceneConnections.scene_paths().duplicate()
		_next = 0
		_holders.clear()
		_wearers.clear()
	if is_ready():
		return true
	_arm()
	return false


## True when every scene has been read and the counts below are final.
static func is_ready() -> bool:
	return _started and _next >= _pending.size()


## Reads scenes until the budget is spent, and answers whether that finished the scan. The editor
## calls this a slice at a time; a caller with no frames to give calls `build_now()` instead.
static func advance(budget_msec: int = SLICE_BUDGET_MSEC) -> bool:
	var deadline: int = Time.get_ticks_msec() + maxi(budget_msec, 1)
	while _next < _pending.size() and Time.get_ticks_msec() < deadline:
		_read_scene(_pending[_next])
		_next += 1
	if _next < _pending.size():
		return false
	_sort_holders()
	return true


## The whole scan, now. What a headless run, a health check and a test use, and what the one shipped
## asker that has always blocked on its first question goes on using - the answer is the same either
## way, and only the waiting differs.
static func build_now() -> void:
	request()
	while not advance(1000):
		pass


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


## Drops the scan, so the next question starts a fresh one. The editor calls this when the filesystem
## changes; tests call it between fixtures, for the same reason every reader beside this one does.
static func clear_cache() -> void:
	_holders.clear()
	_wearers.clear()
	_pending = PackedStringArray()
	_next = 0
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
		var material_path: String = str(node.get(MATERIAL_KEY, ""))
		if material_path.is_empty():
			continue
		if not _wearers.has(material_path):
			_wearers[material_path] = [] as Array[Dictionary]
		(_wearers[material_path] as Array[Dictionary]).append({
			"scene_path": scene_path, "path": str(node.get("path", "")),
			"name": str(node.get("name", ""))})


## Path order, once, at the end of the scan - so two runs of it answer in the same order however the
## filesystem happened to hand the scenes over.
static func _sort_holders() -> void:
	for resource_path: Variant in _holders.keys():
		var holders: PackedStringArray = _holders[resource_path]
		holders.sort()
		_holders[resource_path] = holders


## Schedules the next slice on the editor's own idle frame. Deferred rather than timed: it costs no
## node, no timer and nothing at plugin boot.
##
## ONLY IN THE EDITOR, which is the only place there are frames to spread work over. A headless run -
## a test, the Doctor's command line, a build - fills the index through `build_now()` instead, and
## gets the same answer with none of the timing: a scan that finished half way through a suite
## because an idle frame happened to arrive is a suite that passes differently on a slower machine.
static func _arm() -> void:
	if _pumping or not Engine.is_editor_hint():
		return
	_pumping = true
	Callable(EventSheetProjectShareIndex, "_pump").call_deferred()


static func _pump() -> void:
	_pumping = false
	if not advance():
		_arm()
