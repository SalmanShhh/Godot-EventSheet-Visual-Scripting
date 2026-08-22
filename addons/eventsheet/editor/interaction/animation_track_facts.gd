# Godot EventSheets - Y3: WHAT THE ANIMATIONS CALL.
#
# Half of game feel is the animation telling the game when: the hit lands on frame 3, the footstep
# plays on frame 6, the sword leaves the hand at 0.4 s. Godot's own answer to that is the METHOD
# TRACK - a key on an animation that calls a function on the animated node by name. It is a real
# contract between two files, and it is invisible from the script's side: the function sits there
# looking like a helper nobody calls, and renaming it breaks the animation silently.
#
# This reads the other half. A `.tscn` or a `.tres` holding an Animation is plain text, and the
# method a key calls is written in it, so the names an animation calls can be read the same way the
# scene reader reads a scene: as text, without instancing anything.
#
# Two things ask:
#   the reading  - a function an animation calls is not a helper, it is an EVENT, and reads as one
#   the Doctor   - a track naming a function no script defines is the silent-nothing bug
#
# Nothing here edits a file, and nothing it answers may change what is emitted.
@tool
class_name EventSheetAnimationTrackFacts
extends RefCounted

## How many files one scan will read. A project with more animation-bearing files than this is
## unusual, and a reading that quietly took a second to open a sheet would be a worse bug than the
## last few tracks going unnamed.
const SCAN_LIMIT: int = 600

## The extensions an Animation can live in: inside a scene, or as a resource of its own.
const SCANNED_EXTENSIONS: PackedStringArray = ["tscn", "tres"]

## The mark a method track's key writes the called function under. Godot writes the name as a
## StringName (`&"..."`) in a scene and as a plain string in some hand-edited files, so both spellings
## are read.
const METHOD_MARK: String = "\"method\":"

## method name -> {animation: String, file: String}. Filled by the one scan, kept for the session:
## animations do not change while a sheet is open, and re-reading every scene on every row rebuild
## would make opening a script cost what opening the whole project costs.
static var _by_method: Dictionary = {}
static var _scanned: bool = false


## Every function this project's animations call, as {method name: {animation, file}}. The scan runs
## once and is cheap to ask again; `forget()` is the only way back to a cold read.
static func by_method() -> Dictionary:
	if _scanned:
		return _by_method
	_scanned = true
	_by_method = {}
	var read: int = 0
	for path: String in _files_that_could_hold_animations():
		if read >= SCAN_LIMIT:
			break
		read += 1
		for track: Dictionary in tracks_in(FileAccess.get_file_as_string(path)):
			var method: String = str(track.get("method", ""))
			if method.is_empty() or _by_method.has(method):
				continue
			_by_method[method] = {"animation": str(track.get("animation", "")), "file": path}
	return _by_method


## Drops the scan, so the next ask reads the files again. Called when the project's files change.
static func forget() -> void:
	_scanned = false
	_by_method = {}


## The method tracks one file's TEXT holds, as [{animation, method}]. An Animation is a resource
## block - `[sub_resource type="Animation" …]` inside a scene, `[resource]` in a file whose header
## says the resource IS an Animation - and the clip's name is the `resource_name` in that block. A
## method key writes the function it calls into the block's `tracks/N/keys`, and that is the whole
## tell: no other track type writes a `"method":` at all.
static func tracks_in(text: String) -> Array:
	var found: Array = []
	if text.is_empty() or not text.contains(METHOD_MARK):
		return found
	var whole_file_is_animation: bool = text.contains("[gd_resource type=\"Animation\"")
	var inside: bool = false
	var animation: String = ""
	for line: String in text.split("\n"):
		if line.begins_with("["):
			inside = line.begins_with("[sub_resource type=\"Animation\"") \
				or (whole_file_is_animation and line.begins_with("[resource]"))
			animation = ""
			continue
		if not inside:
			continue
		if line.begins_with("resource_name = "):
			animation = _quoted_value(line)
			continue
		if not line.contains(METHOD_MARK):
			continue
		for method: String in _methods_named_in(line):
			found.append({"animation": animation, "method": method})
	return found


## Every function a keys line names. One line can carry a whole track's keys, so several calls can
## sit on it, and each is recorded: three footstep keys on one track are three chances to name the
## function - and exactly one function.
static func _methods_named_in(line: String) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	var cursor: int = line.find(METHOD_MARK)
	while cursor >= 0:
		var rest: String = line.substr(cursor + METHOD_MARK.length()).strip_edges()
		rest = rest.trim_prefix("&")
		if rest.begins_with("\""):
			var closing: int = rest.find("\"", 1)
			if closing > 1:
				var named: String = rest.substr(1, closing - 1)
				if not named.is_empty() and not names.has(named):
					names.append(named)
		cursor = line.find(METHOD_MARK, cursor + METHOD_MARK.length())
	return names


## `resource_name = "punch"` -> "punch", "" when the line carries no quoted value.
static func _quoted_value(line: String) -> String:
	var opening: int = line.find("\"")
	if opening < 0:
		return ""
	var closing: int = line.find("\"", opening + 1)
	return line.substr(opening + 1, closing - opening - 1) if closing > opening else ""


## Y3. The plain words behind a called function's name: `_on_hit_frame` -> "hit frame". The handler
## spelling is the convention Godot's own signal handlers use, and the words are what the row says,
## so an author who types the event's name into the picker and an author who names the track by hand
## end up looking at the same row.
static func event_words(method_name: String) -> String:
	var bare: String = method_name.strip_edges().lstrip("_")
	if bare.begins_with("on_"):
		bare = bare.substr(3)
	return bare.replace("_", " ").strip_edges()


## Every file that could hold an Animation, newest layout first. Scenes and resources only: a script
## cannot hold one, and walking the whole project asking every file would cost what this exists to
## avoid.
static func _files_that_could_hold_animations() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var pending: PackedStringArray = PackedStringArray(["res://"])
	while not pending.is_empty():
		var directory_path: String = pending[0]
		pending.remove_at(0)
		var directory: DirAccess = DirAccess.open(directory_path)
		if directory == null:
			continue
		directory.list_dir_begin()
		var entry: String = directory.get_next()
		while not entry.is_empty():
			if entry.begins_with("."):
				entry = directory.get_next()
				continue
			var full: String = directory_path.path_join(entry)
			if directory.current_is_dir():
				# The plugin's own folders hold no game animations, and the import cache holds
				# thousands of files that are nobody's scene.
				if not (entry == "addons" or entry == ".godot"):
					pending.append(full)
			elif SCANNED_EXTENSIONS.has(entry.get_extension().to_lower()):
				found.append(full)
			entry = directory.get_next()
		directory.list_dir_end()
	return found
