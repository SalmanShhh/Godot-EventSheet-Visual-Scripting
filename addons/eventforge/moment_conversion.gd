# Godot EventSheets - old moment files becoming Juice lists.
#
# An old moment file (a MomentResource) holds a list of steps with four keys each; a Juice list holds the same
# steps as full juice cards. A Juice Player plays either from its Moment File slot, and a four-key card is a valid
# card, so the cards go across exactly as they are: nothing is filled in and nothing is reworded, which is why an
# old file and its converted file play the same.
#
# THE CONVERSION IS IN PLACE. The loaded resource keeps its object, its path and its uid and only swaps its script,
# so every scene and script pointing at the file keeps working and now gets a Juice list. An untouched file is never
# rewritten; the swap happens on the first edit (one undo step with the edit) or when the Doctor's fix is used.
# A running game never converts anything.
#
# Loaded BY PATH from the doors that use it and given no class_name, so nothing that names it compiles it at boot.
@tool
extends RefCounted

## The old file's script and the list's script, by path: a project that never had the Juice pack has neither.
const MOMENT_PATH: String = "res://eventsheet_addons/moment_resource/moment_resource.gd"
const LIST_PATH: String = "res://eventsheet_addons/moment_resource/juice_list.gd"
## The text the first line of an old file's .tres carries, which is all the Doctor reads of a file to know it.
const HEADER_WORD: String = "script_class=\"MomentResource\""
## The name an old file kept, put on the converted file as resource metadata so it is not lost.
const NAME_META: String = "moment_name"
const UNDO_STEPS_PATH: String = "res://addons/eventforge/editor/undo_steps.gd"


## Whether a resource is an old moment file: its script is the moment script and it is not already a list.
static func is_old_moment(object: Variant) -> bool:
	if not (object is Resource):
		return false
	var script: Script = (object as Resource).get_script() as Script
	if script == null:
		return false
	return script.resource_path == MOMENT_PATH or script.get_global_name() == &"MomentResource"


## Whether this project has the list's script, which is what a conversion needs.
static func can_convert() -> bool:
	return ResourceLoader.exists(LIST_PATH) and load(LIST_PATH) is Script


## The cards of an old file as a Juice list holds them: deep copies, in order, typed the way the list's own are.
static func cards_of(cards: Variant) -> Array[Dictionary]:
	var copied: Array[Dictionary] = []
	if cards is Array:
		for card: Variant in (cards as Array):
			if card is Dictionary:
				copied.append((card as Dictionary).duplicate(true))
	return copied


## The name an old or converted file is known by: the one it held, else the one kept on it, else "".
static func name_of(file: Resource) -> String:
	if file == null:
		return ""
	var held: Variant = file.get(NAME_META)
	if held != null and not str(held).is_empty():
		return str(held)
	return str(file.get_meta(NAME_META, ""))


## One swap of an object between the two shapes, done and undone. The same object throughout, so a path, a uid and
## every holder of the resource are untouched.
class Swap extends RefCounted:
	var file: Resource = null
	var old_script: Script = null
	var old_steps: Array[Dictionary] = []
	var old_name: String = ""
	var new_script: Script = null
	var new_steps: Array[Dictionary] = []

	func apply() -> void:
		file.set_script(new_script)
		file.set("steps", new_steps.duplicate(true))
		if not old_name.is_empty():
			file.set_meta("moment_name", old_name)
		file.emit_changed()

	func revert() -> void:
		file.set_script(old_script)
		file.set("steps", old_steps.duplicate(true))
		if not old_name.is_empty():
			file.set("moment_name", old_name)
		if file.has_meta("moment_name"):
			file.remove_meta("moment_name")
		file.emit_changed()


## The swap that turns `file` into a Juice list holding `cards` (its own cards when none are given), or null when
## the object is not an old file or the project has no list script.
static func swap_for(file: Resource, cards: Variant = null) -> Swap:
	if not is_old_moment(file) or not can_convert():
		return null
	var swap: Swap = Swap.new()
	swap.file = file
	swap.old_script = file.get_script() as Script
	swap.old_steps = cards_of(file.get("steps"))
	swap.old_name = str(file.get("moment_name"))
	swap.new_script = load(LIST_PATH) as Script
	swap.new_steps = cards_of(cards if cards != null else file.get("steps"))
	return swap


## Converts one loaded old file in memory, no undo. True when it converted.
static func convert_in_place(file: Resource, cards: Variant = null) -> bool:
	var swap: Swap = swap_for(file, cards)
	if swap == null:
		return false
	swap.apply()
	return true


## The first edit of an old file: the edited cards land in a Juice list in ONE undo step, so Ctrl+Z gives the old
## file back with its old steps. `undo` is a plain UndoRedo a test hands in; in the editor Godot's own manager is
## used. False when nothing was converted (not an old file, or no list script), and the caller edits as usual.
static func edit_step(file: Resource, cards: Array, label: String, undo: Object = null) -> bool:
	var swap: Swap = swap_for(file, cards)
	if swap == null:
		return false
	_step(swap.apply, swap.revert, swap, label, undo)
	return true


## One recorded do/undo pair on the editor's manager (or the plain one handed in); with neither, just done.
static func _step(do_call: Callable, undo_call: Callable, keep: Object, label: String, undo: Object) -> void:
	var manager: Object = load(UNDO_STEPS_PATH).manager_for(undo)
	if manager == null:
		do_call.call()
		return
	manager.call("create_action", label)
	if manager is UndoRedo:
		manager.call("add_do_method", do_call)
		manager.call("add_undo_method", undo_call)
		manager.call("commit_action", false)
		do_call.call()
	else:
		manager.call("add_do_method", keep, do_call.get_method())
		manager.call("add_undo_method", keep, undo_call.get_method())
		manager.call("add_do_reference", keep)
		manager.call("commit_action")


# ── Files on disk: the Doctor's "all at once" and the FileSystem entry ──────────────────────────────────


## Whether a .tres on disk is an old moment file, read from its first line only.
static func is_old_moment_file(path: String) -> bool:
	if path.get_extension().to_lower() != "tres" or not FileAccess.file_exists(path):
		return false
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	return file.get_line().contains(HEADER_WORD)


## Saves a resource to its own path and makes sure the file still carries the uid it had. Godot's saver keeps a
## file's uid when the editor's scan knows it; this is the guarantee for when it does not.
static func save_keeping_uid(file: Resource, path: String) -> int:
	var uid_text: String = uid_text_of(path)
	var saved: int = ResourceSaver.save(file, path)
	if saved == OK and not uid_text.is_empty() and uid_text_of(path) != uid_text:
		_put_uid_back(path, uid_text)
	return saved


## Writes a uid into the header line of a saved .tres that lost it, leaving every other byte alone.
static func _put_uid_back(path: String, uid_text: String) -> void:
	var text: String = FileAccess.get_file_as_string(path)
	var end: int = text.find("]")
	if end < 0 or text.substr(0, end).contains("uid=\""):
		return
	var handle: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if handle == null:
		return
	handle.store_string(text.substr(0, end) + " uid=\"%s\"" % uid_text + text.substr(end))
	handle.close()


## The uid a .tres carries in its first line, as text, or "".
static func uid_text_of(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ) if FileAccess.file_exists(path) else null
	if file == null:
		return ""
	var line: String = file.get_line()
	var at: int = line.find("uid=\"")
	if at < 0:
		return ""
	return line.substr(at + 5, line.find("\"", at + 5) - at - 5)


## The old moment files among these paths, a folder meaning the files under it. Sorted, no repeats.
static func old_files_among(paths: PackedStringArray) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for path: String in paths:
		for candidate: String in _files_under(path):
			if not found.has(candidate) and is_old_moment_file(candidate):
				found.append(candidate)
	found.sort()
	return found


static func _files_under(path: String) -> PackedStringArray:
	if DirAccess.dir_exists_absolute(path):
		var listed: PackedStringArray = PackedStringArray()
		var directory: DirAccess = DirAccess.open(path)
		if directory == null:
			return listed
		for file_name: String in directory.get_files():
			listed.append(path.path_join(file_name))
		for folder: String in directory.get_directories():
			if not folder.begins_with("."):
				listed.append_array(_files_under(path.path_join(folder)))
		return listed
	return PackedStringArray([path])


## Many files at once, made so one undo step can hold the lot: applying converts and saves each file; reverting
## writes every file's original bytes back and puts the loaded copies back as they were.
class Bulk extends RefCounted:
	var paths: PackedStringArray = PackedStringArray()
	var originals: Dictionary = {}
	## How many files the last apply converted.
	var done: int = 0

	func apply() -> void:
		done = 0
		var conversion: GDScript = load("res://addons/eventforge/moment_conversion.gd")
		for path: String in paths:
			# A redo finds the file already converted on disk; the bytes kept from the first apply say it was one.
			if not originals.has(path) and not conversion.is_old_moment_file(path):
				continue
			if not originals.has(path):
				originals[path] = FileAccess.get_file_as_bytes(path)
			var file: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE)
			if file == null:
				continue
			var swap: RefCounted = conversion.swap_for(file)
			if swap == null:
				continue
			swap.apply()
			if conversion.save_keeping_uid(file, path) == OK:
				done += 1
		_tell_editor()

	func revert() -> void:
		for path: String in originals:
			var handle: FileAccess = FileAccess.open(path, FileAccess.WRITE)
			if handle != null:
				handle.store_buffer(originals[path] as PackedByteArray)
				handle.close()
			ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)
		_tell_editor()

	func _tell_editor() -> void:
		if not (Engine.is_editor_hint() and Engine.has_singleton("EditorInterface")):
			return
		var filesystem: Object = (Engine.get_singleton("EditorInterface") as Object).call("get_resource_filesystem")
		if filesystem == null:
			return
		for path: String in paths:
			filesystem.call("update_file", path)


## Turns every old file among `paths` into a Juice list as ONE undo step. Returns how many were converted.
static func convert_files(paths: PackedStringArray, label: String, undo: Object = null) -> int:
	if not can_convert():
		return 0
	var bulk: Bulk = Bulk.new()
	bulk.paths = old_files_among(paths)
	if bulk.paths.is_empty():
		return 0
	_step(bulk.apply, bulk.revert, bulk, label, undo)
	return bulk.done
