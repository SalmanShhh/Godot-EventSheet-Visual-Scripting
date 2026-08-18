# EventForge - signals wired in the SCENE FILE, recovered for the lifter (M42).
#
# Most real Godot projects connect signals in the editor rather than in code. The editor writes the
# wiring into the .tscn, not into the script:
#
#   [node name="Button" type="Button" parent="."]
#   [connection signal="pressed" from="Button" to="." method="_on_button_pressed"]
#
# The script itself then holds nothing but a bare `func _on_button_pressed() -> void:`, so before this
# the handler opened as an anonymous helper - the single most common way a beginner's project reads as
# a wall of unrelated functions. This module reads those connection lines back, so the lifter can treat
# such a handler exactly like one connected in `_ready`: a trigger event named after the node that
# emits ("Button ▸ On pressed").
#
# THE SCENE IS NEVER TOUCHED, AND NOTHING IS EMITTED FOR IT. A connect line belongs to the .tscn; the
# script must re-emit byte-for-byte with no connect added, which is why every connection recovered here
# is marked `scene` and the compiler skips connection emission for it.
#
# Only the scene(s) whose ROOT node carries the script are read (a script on a child says nothing about
# what the scene is), and only connections whose `to` addresses that root - a connection to some other
# node is that other node's script's business.
@tool
class_name EventSheetSceneConnections
extends RefCounted

## script path -> {handler_name: {handler, signal, source, source_class, line, scene, scene_path}}.
## Session-lifetime: scenes do not change under a running editor often enough to justify re-reading a
## whole project directory on every open, and a stale entry costs at most one handler's reading.
static var _cache: Dictionary = {}

## Every .tscn under res://, scanned once. Building it costs one directory walk; answering from it
## costs a dictionary lookup, which matters because the lifter asks per opened file.
static var _scene_paths: PackedStringArray = PackedStringArray()
static var _scene_paths_scanned: bool = false


## The scene-wired signal handlers of one script, keyed by handler function name. Empty for a script no
## scene root uses, and for a project with no scenes at all.
static func for_script(script_path: String) -> Dictionary:
	var path: String = script_path.strip_edges()
	if path.is_empty() or not path.begins_with("res://"):
		return {}
	if _cache.has(path):
		return _cache[path]
	var found: Dictionary = {}
	for scene_path: String in _all_scene_paths():
		var text: String = FileAccess.get_file_as_string(scene_path)
		if text.is_empty() or not text.contains(path):
			continue
		found.merge(_connections_of(scene_path, text, path), true)
	_cache[path] = found
	return found


## Drops the cache. The editor calls this when the filesystem changes; tests call it between fixtures.
static func clear_cache() -> void:
	_cache.clear()
	_scene_paths = PackedStringArray()
	_scene_paths_scanned = false


## The connections of ONE scene whose root uses `script_path`, or {} when the root uses another script.
static func _connections_of(scene_path: String, text: String, script_path: String) -> Dictionary:
	var lines: PackedStringArray = text.split("\n")
	# Pass 1: the ext_resource ids that point at this script, every node's class by name, and the root.
	var script_ids: Dictionary = {}
	var node_classes: Dictionary = {}
	var root_name: String = ""
	var root_uses_script: bool = false
	for line: String in lines:
		if line.begins_with("[ext_resource "):
			if _attribute(line, "path") == script_path:
				script_ids[_attribute(line, "id")] = true
			continue
		if not line.begins_with("[node "):
			continue
		var node_name: String = _attribute(line, "name")
		if node_name.is_empty():
			continue
		node_classes[node_name] = _attribute(line, "type")
		if root_name.is_empty() and not line.contains("parent="):
			root_name = node_name
	if root_name.is_empty() or script_ids.is_empty():
		return {}
	# Pass 2: the root's own `script = ExtResource("id")` line, which sits under its [node] header.
	var in_root: bool = false
	for line: String in lines:
		if line.begins_with("[node "):
			in_root = _attribute(line, "name") == root_name and not line.contains("parent=")
			continue
		if in_root and line.begins_with("script = ExtResource("):
			var id: String = line.get_slice("\"", 1)
			if script_ids.has(id):
				root_uses_script = true
			break
	if not root_uses_script:
		return {}
	# Pass 3: the connections addressed to that root.
	var connections: Dictionary = {}
	for line: String in lines:
		if not line.begins_with("[connection "):
			continue
		var to_path: String = _attribute(line, "to")
		# `.` is the scene root; the editor also writes the root's own name for a self-connection, and a
		# NodePath ending at the root reads the same. Anything else is another node's handler.
		if not (to_path == "." or to_path == root_name or to_path.get_file() == root_name):
			continue
		var handler: String = _attribute(line, "method")
		var signal_name: String = _attribute(line, "signal")
		if handler.is_empty() or signal_name.is_empty():
			continue
		# `from="."` is the root emitting its own signal - it has no separate source object to name.
		var source: String = _attribute(line, "from")
		if source == "." or source == root_name:
			source = ""
		connections[handler] = {
			"handler": handler,
			"signal": signal_name,
			"source": source,
			"source_class": str(node_classes.get(source, "")) if not source.is_empty() else "",
			# No connect line exists in the script, and none may be emitted into it.
			"line": "",
			"scene": true,
			"scene_path": scene_path,
		}
	return connections


## `key="value"` out of a .tscn header line, "" when the key is absent.
static func _attribute(line: String, key: String) -> String:
	var marker: String = "%s=\"" % key
	var start: int = line.find(marker)
	if start < 0:
		return ""
	start += marker.length()
	var end: int = line.find("\"", start)
	return line.substr(start, end - start) if end > start else ""


## Every .tscn in the project, found once per session.
static func _all_scene_paths() -> PackedStringArray:
	if _scene_paths_scanned:
		return _scene_paths
	_scene_paths_scanned = true
	_collect_scene_paths("res://")
	return _scene_paths


static func _collect_scene_paths(directory_path: String) -> void:
	var directory: DirAccess = DirAccess.open(directory_path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry: String = directory.get_next()
	while not entry.is_empty():
		if entry.begins_with("."):
			entry = directory.get_next()
			continue
		var full_path: String = directory_path.path_join(entry)
		if directory.current_is_dir():
			_collect_scene_paths(full_path)
		elif entry.get_extension() == "tscn":
			_scene_paths.append(full_path)
		entry = directory.get_next()
	directory.list_dir_end()
