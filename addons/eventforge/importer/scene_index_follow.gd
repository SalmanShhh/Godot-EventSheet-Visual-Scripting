@tool
extends RefCounted

## How the project's two scene indexes follow a file or folder that was moved, and how two of them are
## compared. The indexes themselves live where they are asked (the row builder's index of which scene a
## script is the root of, and the scene reader's index of which scenes load a script); this is the part
## that works on one without touching the other, kept in its own file so the editor's first open does not
## compile it - the moves that need it load it by path.
##
## A move changes where a file is, never what is in it: a moved script is the same key under its new name,
## a moved scene the same entry under its new path. The scenes that name a moved script are rewritten by the
## editor, and the re-read that follows its filesystem change confirms the spelling.

const MOVED_PATH := preload("res://addons/eventforge/importer/moved_path.gd")


## The root index, {script path: [{scene_path, root_name}, ...]} with each list in the order a sweep meets
## its scenes, as it would read after the move, taken from `held` without reading a file. The entries that
## now share a script are put back in the sweep's order. `held` itself when the move touches nothing in it.
static func rows_after_move(held: Dictionary, old_path: String, new_path: String, is_folder: bool) -> Dictionary:
	var touched: Array = []
	for script_path: Variant in held:
		if MOVED_PATH.is_moved(str(script_path), old_path, is_folder):
			touched.append(script_path)
			continue
		for entry: Dictionary in (held[script_path] as Array):
			if MOVED_PATH.is_moved(str(entry.get("scene_path", "")), old_path, is_folder):
				touched.append(script_path)
				break
	if touched.is_empty():
		return held
	var moved: Dictionary = held.duplicate()
	for script_path: Variant in touched:
		moved.erase(script_path)
	var reordered: Dictionary = {}
	for script_path: Variant in touched:
		var script_to: String = MOVED_PATH.mapped(str(script_path), old_path, new_path, is_folder)
		var entries: Array = []
		for entry: Dictionary in (held[script_path] as Array):
			entries.append({"scene_path": MOVED_PATH.mapped(str(entry.get("scene_path", "")), old_path, new_path, is_folder),
					"root_name": entry.get("root_name", "")})
		if moved.has(script_to):
			# Another script's entries now share this name: both lists are met by the sweep in one order.
			entries.append_array(moved[script_to] as Array)
		moved[script_to] = entries
		reordered[script_to] = true
	for script_path: Variant in reordered:
		(moved[script_path] as Array).sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
			return is_swept_before(str(first["scene_path"]), str(second["scene_path"])))
	return moved


## Whether the sweep meets scene `first` before scene `second`: inside one folder the scenes come first, by
## name, then each sub-folder in name order, walked whole before the next.
static func is_swept_before(first: String, second: String) -> bool:
	var first_parts: PackedStringArray = first.trim_prefix("res://").split("/")
	var second_parts: PackedStringArray = second.trim_prefix("res://").split("/")
	for at: int in range(mini(first_parts.size(), second_parts.size())):
		if first_parts[at] == second_parts[at]:
			continue
		var first_is_scene: bool = at == first_parts.size() - 1
		var second_is_scene: bool = at == second_parts.size() - 1
		if first_is_scene != second_is_scene:
			return first_is_scene
		return first_parts[at] < second_parts[at]
	return first_parts.size() < second_parts.size()


## Whether two root indexes give the same answers: the same scripts, and for each the same scenes in the same
## order under the same object names.
static func rows_match(left: Dictionary, right: Dictionary) -> bool:
	if left.size() != right.size():
		return false
	for script_path: Variant in left:
		if not right.has(script_path):
			return false
		var mine: Array = left[script_path]
		var theirs: Array = right[script_path]
		if mine.size() != theirs.size():
			return false
		for at: int in range(mine.size()):
			if str(mine[at].get("scene_path", "")) != str(theirs[at].get("scene_path", "")) \
					or str(mine[at].get("root_name", "")) != str(theirs[at].get("root_name", "")):
				return false
	return true


## The scenes-by-script index, {script path: [scene paths in path order]}, as it would read after the move,
## taken from `held` without reading a file. `held` itself when the move touches nothing in it.
static func scenes_after_move(held: Dictionary, old_path: String, new_path: String, is_folder: bool) -> Dictionary:
	var touched: Array = []
	for script_path: Variant in held:
		if MOVED_PATH.is_moved(str(script_path), old_path, is_folder):
			touched.append(script_path)
			continue
		for scene_path: String in (held[script_path] as PackedStringArray):
			if MOVED_PATH.is_moved(scene_path, old_path, is_folder):
				touched.append(script_path)
				break
	if touched.is_empty():
		return held
	var moved: Dictionary = held.duplicate()
	for script_path: Variant in touched:
		moved.erase(script_path)
	for script_path: Variant in touched:
		var script_to: String = MOVED_PATH.mapped(str(script_path), old_path, new_path, is_folder)
		var scenes: PackedStringArray = PackedStringArray()
		for scene_path: String in (held[script_path] as PackedStringArray):
			scenes.append(MOVED_PATH.mapped(scene_path, old_path, new_path, is_folder))
		if moved.has(script_to):
			# Another script's scenes now share this name: one list, each scene once.
			for scene_path: String in (moved[script_to] as PackedStringArray):
				if not scenes.has(scene_path):
					scenes.append(scene_path)
		scenes.sort()
		moved[script_to] = scenes
	return moved


## Whether two scenes-by-script indexes give the same answers.
static func scenes_match(left: Dictionary, right: Dictionary) -> bool:
	if left.size() != right.size():
		return false
	for script_path: Variant in left:
		if not right.has(script_path) or (left[script_path] as PackedStringArray) != (right[script_path] as PackedStringArray):
			return false
	return true


## The list of every scene in the project, kept in path order, as it reads after the move.
static func scene_paths_after_move(paths: PackedStringArray, old_path: String, new_path: String, is_folder: bool) -> PackedStringArray:
	var moved: PackedStringArray = PackedStringArray()
	for scene_path: String in paths:
		moved.append(MOVED_PATH.mapped(scene_path, old_path, new_path, is_folder))
	moved.sort()
	return moved
