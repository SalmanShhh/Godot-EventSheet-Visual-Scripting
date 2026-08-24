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

## P4. The ONE scene a read is about, while a whole scene is being opened as a sheet. Inside a scene
## view the question is a different one: not "what does this script's own scene say about it" but
## "what does THIS scene wire to this script", and the script may sit on any node rather than only on
## the root. Empty the rest of the time, which is every ordinary open - so a script opened on its own
## gets exactly the answer it always got.
static var scene_scope: String = ""


## The scene-wired signal handlers of one script, keyed by handler function name. Empty for a script no
## scene root uses, and for a project with no scenes at all.
static func for_script(script_path: String) -> Dictionary:
	var path: String = script_path.strip_edges()
	if path.is_empty() or not path.begins_with("res://"):
		return {}
	var key: String = "%s|%s" % [scene_scope, path]
	if _cache.has(key):
		return _cache[key]
	if not scene_scope.is_empty():
		var scoped: Dictionary = _connections_in_scene(scene_scope, path)
		_cache[key] = scoped
		return scoped
	var found: Dictionary = {}
	for scene_path: String in scene_paths():
		var text: String = FileAccess.get_file_as_string(scene_path)
		if text.is_empty() or not text.contains(path):
			continue
		found.merge(_connections_of(scene_path, text, path), true)
	_cache[key] = found
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
			if attribute(line, "path") == script_path:
				script_ids[attribute(line, "id")] = true
			continue
		if not line.begins_with("[node "):
			continue
		var node_name: String = attribute(line, "name")
		if node_name.is_empty():
			continue
		node_classes[node_name] = attribute(line, "type")
		if root_name.is_empty() and not line.contains("parent="):
			root_name = node_name
	if root_name.is_empty() or script_ids.is_empty():
		return {}
	# Pass 2: the root's own `script = ExtResource("id")` line, which sits under its [node] header.
	var in_root: bool = false
	for line: String in lines:
		if line.begins_with("[node "):
			in_root = attribute(line, "name") == root_name and not line.contains("parent=")
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
		var to_path: String = attribute(line, "to")
		# `.` is the scene root; the editor also writes the root's own name for a self-connection, and a
		# NodePath ending at the root reads the same. Anything else is another node's handler.
		if not (to_path == "." or to_path == root_name or to_path.get_file() == root_name):
			continue
		var handler: String = attribute(line, "method")
		var signal_name: String = attribute(line, "signal")
		if handler.is_empty() or signal_name.is_empty():
			continue
		# `from="."` is the root emitting its own signal - it has no separate source object to name.
		var source: String = attribute(line, "from")
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


## P4. Every node of one scene, in the order the scene file writes them (which is tree order), as
## [{name, path, type, script_path, properties}]. The scene view is built from this, and so is the
## scoped connection read below - both need to know which node carries which script.
##
## `properties` is every `key = value` line under the node's header, values kept as the raw text the
## file holds (`NodePath("..")`, `PackedStringArray("res://a.tscn")`, `0.05`). A reader that wants a
## scene fact - which node a synchronizer keeps in step, which scenes a spawner can make - reads it
## from here instead of walking the file a second time.
static func nodes_of_scene(scene_path: String) -> Array:
	var nodes: Array = []
	var text: String = FileAccess.get_file_as_string(scene_path)
	if text.is_empty():
		return nodes
	var lines: PackedStringArray = text.split("\n")
	# Off the lines already in hand, never off the file again: this is the project's hottest scene
	# read (the scene view, the object facts, every lighting fact), and re-opening the file for its
	# `[ext_resource]` table doubled the I/O of every one of them.
	var resource_paths: Dictionary = resource_paths_in(lines)
	var current: Dictionary = {}
	for line: String in lines:
		if line.begins_with("[node "):
			var node_name: String = attribute(line, "name")
			if node_name.is_empty():
				current = {}
				continue
			var parent: String = attribute(line, "parent")
			var node_path: String = "."
			if not parent.is_empty():
				node_path = node_name if parent == "." else "%s/%s" % [parent, node_name]
			current = {
				"name": node_name,
				"path": node_path,
				"type": attribute(line, "type"),
				"script_path": "",
				"properties": {}
			}
			nodes.append(current)
			continue
		if line.begins_with("["):
			# Any other section ends the node's block: the lines under a `[sub_resource]` or a
			# `[connection]` belong to it, never to the node that happened to be written above.
			current = {}
			continue
		if current.is_empty():
			continue
		var assignment: int = line.find(" = ")
		if assignment <= 0:
			continue
		var key: String = line.substr(0, assignment).strip_edges()
		var value: String = line.substr(assignment + 3).strip_edges()
		(current["properties"] as Dictionary)[key] = value
		if key == "script" and value.begins_with("ExtResource("):
			current["script_path"] = str(resource_paths.get(value.get_slice("\"", 1), ""))
	return nodes


## P4. The connections ONE scene wires to ONE script, wherever in the scene that script sits. Same
## shape as the root-only read above, and the same rule about the file: the connect line lives in the
## .tscn, so nothing is claimed for emission and nothing is ever written back.
static func _connections_in_scene(scene_path: String, script_path: String) -> Dictionary:
	var connections: Dictionary = {}
	var nodes: Array = nodes_of_scene(scene_path)
	if nodes.is_empty():
		return connections
	var targets: Dictionary = {}
	var types: Dictionary = {}
	for entry: Variant in nodes:
		var node: Dictionary = entry
		types[str(node.get("path", ""))] = str(node.get("type", ""))
		if str(node.get("script_path", "")) == script_path:
			targets[str(node.get("path", ""))] = str(node.get("name", ""))
	if targets.is_empty():
		return connections
	for line: String in FileAccess.get_file_as_string(scene_path).split("\n"):
		if not line.begins_with("[connection "):
			continue
		var to_path: String = attribute(line, "to")
		if not targets.has(to_path):
			continue
		var handler: String = attribute(line, "method")
		var signal_name: String = attribute(line, "signal")
		if handler.is_empty() or signal_name.is_empty():
			continue
		var from_path: String = attribute(line, "from")
		# A node emitting its own signal has no separate source object to name.
		var source: String = "" if from_path == to_path or from_path == "." else from_path.get_file()
		connections[handler] = {
			"handler": handler,
			"signal": signal_name,
			"source": source,
			"source_class": str(types.get(from_path, "")) if not source.is_empty() else "",
			"line": "",
			"scene": true,
			"scene_path": scene_path,
		}
	return connections


## L6. The FILES one scene points at, as `ext_resource id -> res:// path`. A node property holding
## `ExtResource("1_env")` says nothing on its own; this is the table that turns it into the
## environment resource a reader can name, and the one place the answer is read from - which also
## makes "who else uses this .tres" a question about a table rather than a second parser.
static func resource_paths_of_scene(scene_path: String) -> Dictionary:
	return resource_paths_in(FileAccess.get_file_as_string(scene_path).split("\n"))


## The same table off lines a caller ALREADY holds - what the node walk above passes its own read, so
## one question about a scene stays one read of it.
static func resource_paths_in(lines: PackedStringArray) -> Dictionary:
	var paths: Dictionary = {}
	for line: String in lines:
		if line.begins_with("[ext_resource "):
			paths[attribute(line, "id")] = attribute(line, "path")
	return paths


## `key="value"` out of a .tscn header line, "" when the key is absent. Public because this module
## is the project's ONE reader of scene text: anything else that has to answer a question about a
## `.tscn` asks through here rather than growing a second parser beside it.
static func attribute(line: String, key: String) -> String:
	var marker: String = "%s=\"" % key
	var start: int = line.find(marker)
	if start < 0:
		return ""
	start += marker.length()
	var end: int = line.find("\"", start)
	return line.substr(start, end - start) if end > start else ""


## Every .tscn in the project, found once per session - the input set for any question that has to
## be asked of every scene ("which one runs this script", "which spawner lists this scene").
static func scene_paths() -> PackedStringArray:
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
