@tool
extends RefCounted

## The scenes whose ROOT carries a script, found by reading the head of every `.tscn` under a folder.
## Touches nothing but what it returns, so it can run on a worker thread: the row builder asks it for the
## index of root objects (which scene a script drives, and what that object is called), and the idle read
## of the scene indexes (scene_index_prep.gd) runs it off the main thread the same way.


## Every scene under `directory_path` and the script its root carries, {script path: [{scene_path,
## root_name}, ...]}, each list in the order the walk meets its scenes.
static func sweep_scenes_under(directory_path: String) -> Dictionary:
	var found: Dictionary = {}
	sweep_scenes(directory_path, found)
	return found


static func sweep_scenes(directory_path: String, found: Dictionary) -> void:
	var directory: DirAccess = DirAccess.open(directory_path)
	if directory == null:
		return
	# Name order, always - the listing arrives in filesystem order (near-alphabetical on NTFS, hash
	# order on ext4), and when two scenes root the same script the FIRST one recorded names the
	# object, so an unsorted walk labels the same script differently on different platforms.
	var subdirectories: PackedStringArray = PackedStringArray()
	var scene_names: PackedStringArray = PackedStringArray()
	directory.list_dir_begin()
	var entry: String = directory.get_next()
	while not entry.is_empty():
		if not entry.begins_with("."):
			if directory.current_is_dir():
				subdirectories.append(entry)
			elif entry.get_extension().to_lower() == "tscn":
				scene_names.append(entry)
		entry = directory.get_next()
	directory.list_dir_end()
	subdirectories.sort()
	scene_names.sort()
	for scene_name: String in scene_names:
		record_scene_root_script(directory_path.path_join(scene_name), found)
	for subdirectory: String in subdirectories:
		sweep_scenes(directory_path.path_join(subdirectory), found)


## Records `script path -> {scene_path, root_name}` for one scene, when its ROOT node carries a
## script. Only the root counts: a script on a child says nothing about what the scene IS.
static func record_scene_root_script(scene_path: String, found: Dictionary) -> void:
	var handle: FileAccess = FileAccess.open(scene_path, FileAccess.READ)
	if handle == null:
		return
	var script_ids: Dictionary = {}
	var root_name: String = ""
	var in_root: bool = false
	while not handle.eof_reached():
		var line: String = handle.get_line()
		if line.begins_with("[ext_resource "):
			if line.contains("type=\"Script\""):
				script_ids[quoted_attribute(line, "id")] = quoted_attribute(line, "path")
			continue
		if line.begins_with("[node "):
			if not root_name.is_empty():
				break  # past the root; a child's script is not this scene's identity
			root_name = quoted_attribute(line, "name")
			in_root = true
			continue
		if not in_root or not line.begins_with("script = ExtResource("):
			continue
		var id_start: int = line.find("\"")
		var id_end: int = line.rfind("\"")
		if id_start < 0 or id_end <= id_start:
			break
		var script_id: String = line.substr(id_start + 1, id_end - id_start - 1)
		var script_path: String = str(script_ids.get(script_id, ""))
		if not script_path.is_empty():
			var users: Array = found.get(script_path, [])
			users.append({"scene_path": scene_path, "root_name": root_name})
			found[script_path] = users
		break
	handle.close()


## The value of a `key="value"` attribute inside one .tscn / .tres header line, "" when absent. The key is
## preceded by a space, so `id="` never matches inside `uid="`: the editor writes both on an ext_resource
## line, the uid first, and the shorter key used to read the uid as the id - which left every scene the
## editor had saved without a script to name its root object after.
static func quoted_attribute(line: String, key: String) -> String:
	var marker: String = " %s=\"" % key
	var start: int = line.find(marker)
	if start < 0:
		return ""
	start += marker.length()
	var end: int = line.find("\"", start)
	return line.substr(start, end - start) if end > start else ""
