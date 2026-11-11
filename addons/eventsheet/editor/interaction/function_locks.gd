# Godot EventSheets - which function bodies of an opened .gd are locked, and where that is remembered.
#
# A function body in a script the user wrote is an ordinary event: it edits from the first click. Two
# things lock one. The user can lock a function by hand (right-click, Lock this function), and a file
# in a shipped behaviour pack folder is locked until the user says "Edit it anyway", because the next
# version of the pack replaces that file and the edits with it. Both choices belong to the PROJECT, not
# to the script: they live in the project's editor metadata keyed by the file's path, exactly where a
# folded region is kept, and never in the .gd, so the file's bytes and a teammate's copy are untouched.
@tool
extends RefCounted

const SHIPPED_PACKS := preload("res://addons/eventforge/shipped_pack_folders.gd")

## The editor-metadata section and key the choices are kept under (a dictionary of file path -> state).
const METADATA_SECTION := "eventsheets"
const METADATA_KEY := "function_locks"
## The folder a pack lives in, under the project: a shipped pack is a folder of this one named by the
## shipped list, whether the plugin put it there or the library copied it in.
const PACK_ROOT := "eventsheet_addons/"

## Where the choices are kept when there is no editor to keep them, and only while `use_memory` is on: a
## headless run keeps nothing between views (a lock set in one test must not leak into the next), and a
## test that wants to prove a choice survives a reopen turns this on around itself. A real editor never
## reads or writes either.
static var memory: Dictionary = {}
static var use_memory: bool = false


## True for a file in a shipped behaviour pack folder - `eventsheet_addons/<folder>/...` with the folder
## named by the shipped list. A script of the user's own in any other folder is never one, even when
## its folder happens to share a name with a pack.
static func is_shipped_pack_file(path: String) -> bool:
	var at: int = path.find(PACK_ROOT)
	if at < 0 or (at > 0 and path[at - 1] != "/"):
		return false
	var rest: String = path.substr(at + PACK_ROOT.length())
	var slash: int = rest.find("/")
	return slash > 0 and SHIPPED_PACKS.FOLDERS.has(rest.substr(0, slash))


## A fresh, empty state: functions locked by hand, functions unlocked one by one inside a pack file,
## and whether the whole pack file is unlocked.
static func empty_state() -> Dictionary:
	return {"locked": {}, "unlocked": {}, "file": false}


static func _in_editor() -> bool:
	return Engine.is_editor_hint() and Engine.has_singleton("EditorInterface")


## What was remembered for a file, as the shape empty_state() has.
static func load_state(file_key: String) -> Dictionary:
	var state: Dictionary = empty_state()
	if file_key.is_empty():
		return state
	var all_states: Dictionary
	if _in_editor():
		var settings: EditorSettings = EditorInterface.get_editor_settings()
		if settings == null:
			return state
		all_states = settings.get_project_metadata(METADATA_SECTION, METADATA_KEY, {})
	elif use_memory:
		all_states = memory
	else:
		return state
	var saved: Variant = all_states.get(file_key, {})
	if not (saved is Dictionary):
		return state
	for name: Variant in (saved as Dictionary).get("locked", []):
		(state["locked"] as Dictionary)[str(name)] = true
	for name: Variant in (saved as Dictionary).get("unlocked", []):
		(state["unlocked"] as Dictionary)[str(name)] = true
	state["file"] = bool((saved as Dictionary).get("file", false))
	return state


## Remembers a file's state. A file with nothing set stores nothing at all.
static func save_state(file_key: String, state: Dictionary) -> void:
	if file_key.is_empty():
		return
	var all_states: Dictionary
	var settings: EditorSettings = null
	if _in_editor():
		settings = EditorInterface.get_editor_settings()
		if settings == null:
			return
		all_states = settings.get_project_metadata(METADATA_SECTION, METADATA_KEY, {})
	elif use_memory:
		all_states = memory
	else:
		return
	var locked: Array = (state.get("locked", {}) as Dictionary).keys()
	var unlocked: Array = (state.get("unlocked", {}) as Dictionary).keys()
	locked.sort()
	unlocked.sort()
	if locked.is_empty() and unlocked.is_empty() and not bool(state.get("file", false)):
		all_states.erase(file_key)
	else:
		all_states[file_key] = {"locked": locked, "unlocked": unlocked, "file": bool(state.get("file", false))}
	if settings != null:
		settings.set_project_metadata(METADATA_SECTION, METADATA_KEY, all_states)
