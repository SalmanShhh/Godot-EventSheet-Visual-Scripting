# EventForge - signals wired in the SCENE FILE, recovered for the lifter.
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

## `path|mtime|size` -> the node list of that scene file. THE parse cache of this plugin: the lights
## reader, the material reader, the replication reader, the scene view and the connection read all
## walk the same node list, and every one of them used to re-read and re-parse the file for itself -
## a 2,000-node scene costs about 12 ms a walk, so five readers meeting it cold cost five times that
## for one answer. Each of them still caches what it DERIVED; this is the parse underneath them all.
static var _nodes_cache: Dictionary = {}

## script path -> the scenes that load it, built in one pass over the project's scenes. What makes
## "which scenes wire signals to this script" a lookup instead of a read of every scene in the
## project, which is what it was for every script anybody opened.
static var _scenes_by_script: Dictionary = {}
static var _scenes_by_script_built: bool = false

## The ONE scene a read is about, while a whole scene is being opened as a sheet. Inside a scene
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
	for scene_path: String in scenes_using_script(path):
		found.merge(_connections_of(scene_path, FileAccess.get_file_as_string(scene_path), path), true)
	_cache[key] = found
	return found


## Which scenes load one script, from an index built once. This used to be a read of EVERY scene in
## the project per script asked about, which made a whole-project sweep quadratic: a thousand scripts
## meeting three hundred scenes is three hundred thousand file reads for a question the scenes could
## answer between them in one pass. Opening a small file measured 104 ms of it, and nothing about the
## file explained why.
##
## The index is exact rather than approximate: a connection can only reach a script through the
## scene's `[ext_resource]` table, which is what the read below matches on anyway, so a scene that
## merely mentions the path in a string was already going to answer nothing.
static func scenes_using_script(script_path: String) -> PackedStringArray:
	if not _scenes_by_script_built:
		_build_scene_script_index()
	return _scenes_by_script.get(script_path, PackedStringArray())


## One pass over the project's scenes, filling "which scenes load this script" for all of them. Only
## this function may mark the index built, and it does so once it is - a half-filled index marked
## ready answers "no scene uses this" for every script the pass had not reached yet.
static func _build_scene_script_index() -> void:
	var index: Dictionary = {}
	for scene_path: String in scene_paths():
		var text: String = FileAccess.get_file_as_string(scene_path)
		if text.is_empty():
			continue
		for referenced: Variant in resource_paths_in(text.split("\n")).values():
			var referenced_path: String = str(referenced)
			if not referenced_path.ends_with(".gd"):
				continue
			var users: PackedStringArray = index.get(referenced_path, PackedStringArray())
			if not users.has(scene_path):
				users.append(scene_path)
			index[referenced_path] = users
	_scenes_by_script = index
	_scenes_by_script_built = true


## Drops the cache. The editor calls this when the filesystem changes; tests call it between fixtures.
## The parsed node lists and their stamps go too: a caller clearing this reader has just changed
## scene files, and a held stamp would hand the old parse back.
static func clear_cache() -> void:
	_cache.clear()
	_nodes_cache.clear()
	_scene_paths = PackedStringArray()
	_scene_paths_scanned = false
	_scenes_by_script = {}
	_scenes_by_script_built = false
	EventForgeFileStamp.forget_all()


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


## Every node of one scene, in the order the scene file writes them (which is tree order), as
## [{name, path, type, script_path, groups, properties}]. The scene view is built from this, and so
## is the scoped connection read below - both need to know which node carries which script.
##
## `properties` is every `key = value` line under the node's header, values kept as the raw text the
## file holds (`NodePath("..")`, `PackedStringArray("res://a.tscn")`, `0.05`). A reader that wants a
## scene fact - which node a synchronizer keeps in step, which scenes a spawner can make - reads it
## from here instead of walking the file a second time.
##
## `groups` is the node's persistent groups, off the same header line. It rides here rather than in a
## reader of its own because "which nodes are in this group" is asked across the whole project (a
## group-filtered trigger has to know what its group is made of), and a second walk of every scene
## for one header attribute would be a second parse of the file this cache exists to pay for once.
##
## HELD, and handed back by reference. Every caller reads it and none of them writes to it, so one
## parse serves them all for as long as the file is unchanged; treat what comes back as read-only.
static func nodes_of_scene(scene_path: String) -> Array:
	var stamp: String = EventForgeFileStamp.of(scene_path)
	if _nodes_cache.has(stamp):
		return _nodes_cache[stamp]
	var parsed: Array = _parse_nodes_of_scene(scene_path)
	_nodes_cache[stamp] = parsed
	return parsed


## The walk itself, off the file's own lines. Separated from the question above so the cache has
## exactly one thing to hold and this stays the only place that reads a scene's node headers.
static func _parse_nodes_of_scene(scene_path: String) -> Array:
	var nodes: Array = []
	var text: String = FileAccess.get_file_as_string(scene_path)
	if text.is_empty():
		return nodes
	var lines: PackedStringArray = folded(text.split("\n"))
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
				"instance_path": instance_path_in(line, resource_paths),
				"script_path": "",
				"groups": string_array_attribute(line, "groups"),
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


## The connections ONE scene wires to ONE script, wherever in the scene that script sits. Same
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


## The FILES one scene points at, as `ext_resource id -> res:// path`. A node property holding
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


## The resources a scene keeps INSIDE itself, as `id -> {"type", "properties"}`. A node property
## holding `SubResource("2_mat")` points at one of these rather than at a file, which is what happens
## the moment somebody makes a material in the Inspector instead of saving one - so a reader that
## only followed `ExtResource` would say a node wears nothing while the scene plainly shows it does.
## Same shape and same rule as the node walk above: values are the raw text the file holds.
static func sub_resources_of_scene(scene_path: String) -> Dictionary:
	return sub_resources_in(folded(FileAccess.get_file_as_string(scene_path).split("\n")))


## The file's lines with every value the writer WRAPPED joined back onto its own line. A scene keeps
## a long value over several lines - a SpriteFrames `animations = [{ … }, { … }]`, an Animation's
## `markers = [{ … }]`, a dictionary of metadata - and a reader walking raw lines sees the assignment
## end at `[{` and the rest as orphan text. Joining them here means every reader below gets whole
## values and none of them grows a second parser to cope. Brackets are counted outside quotes only,
## so a path or a name holding one cannot unbalance the count.
static func folded(lines: PackedStringArray) -> PackedStringArray:
	var joined: PackedStringArray = PackedStringArray()
	var pending: String = ""
	var depth: int = 0
	for line: String in lines:
		if depth > 0:
			pending += line.strip_edges()
			depth += _bracket_depth(line)
			if depth <= 0:
				joined.append(pending)
				pending = ""
				depth = 0
			continue
		var opened: int = _bracket_depth(line) if line.find(" = ") > 0 else 0
		if opened <= 0:
			joined.append(line)
			continue
		pending = line.strip_edges()
		depth = opened
	if not pending.is_empty():
		joined.append(pending)
	return joined


## How far one line opens or closes the brackets it holds, ignoring anything inside a quoted string.
##
## The quote-aware walk below is per-CHARACTER, and this runs on every line of every scene in the
## project - which is the hottest read there is. So it is only reached when the line's brackets do
## not already balance by a native count, which almost every line's do: a balanced line cannot be a
## continuation whatever its quotes hold, and the count is six native calls against a GDScript loop
## over every character of the file.
static func _bracket_depth(line: String) -> int:
	if line.count("[") + line.count("{") + line.count("(") \
			== line.count("]") + line.count("}") + line.count(")"):
		return 0
	var depth: int = 0
	var quoted: bool = false
	for index: int in line.length():
		var character: String = line[index]
		if character == "\"" and (index == 0 or line[index - 1] != "\\"):
			quoted = not quoted
		elif quoted:
			continue
		elif character == "[" or character == "{" or character == "(":
			depth += 1
		elif character == "]" or character == "}" or character == ")":
			depth -= 1
	return depth


## The same table off lines a caller already holds.
static func sub_resources_in(lines: PackedStringArray) -> Dictionary:
	var resources: Dictionary = {}
	var current: Dictionary = {}
	for line: String in lines:
		if line.begins_with("[sub_resource "):
			current = {"type": attribute(line, "type"), "properties": {}}
			resources[attribute(line, "id")] = current
			continue
		if line.begins_with("["):
			# Any other section ends this block, exactly as it ends a node's: the lines under the
			# next header belong to it, never to the resource written above.
			current = {}
			continue
		var assignment: int = line.find(" = ")
		if current.is_empty() or assignment <= 0:
			continue
		(current["properties"] as Dictionary)[line.substr(0, assignment).strip_edges()] = \
			line.substr(assignment + 3).strip_edges()
	return resources


## The scene an INSTANCE node header points at, as its `res://` path, and "" for an ordinary node.
## A scene made of other scenes writes its children as
## `[node name="Enemy" parent="." instance=ExtResource("1_enemy")]` - with NO `type=` on the line at
## all, because the type, the groups and every property the instance did not override live in the
## file it points at. So a reader that only looks at `type` is blind to the commonest scene layout
## there is, and this is the thread back to where the rest of the node is written. `resource_paths`
## is the caller's own `ext_resource` table, so no second read of the file is needed.
static func instance_path_in(line: String, resource_paths: Dictionary) -> String:
	var marker: String = "instance=ExtResource(\""
	var start: int = line.find(marker)
	if start < 0:
		return ""
	start += marker.length()
	var end: int = line.find("\"", start)
	return str(resource_paths.get(line.substr(start, end - start), "")) if end > start else ""


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


## `key=["a", "b"]` out of a .tscn header line - how the editor writes persistent groups. The older
## `key=PackedStringArray("a", "b")` spelling reads the same, so a scene saved by an earlier Godot
## still answers. Empty when the key is absent or holds nothing. Public for the same reason
## `attribute` is: this module is the project's ONE reader of scene text.
static func string_array_attribute(line: String, key: String) -> PackedStringArray:
	var marker: String = "%s=" % key
	var start: int = line.find(marker)
	if start < 0:
		return PackedStringArray()
	var bracket: int = line.find("[", start)
	var parenthesis: int = line.find("(", start)
	var opening: int = bracket if (bracket >= 0 and (parenthesis < 0 or bracket < parenthesis)) else parenthesis
	if opening < 0:
		return PackedStringArray()
	var closing: int = line.find("]" if opening == bracket else ")", opening)
	if closing < opening:
		return PackedStringArray()
	var values: PackedStringArray = PackedStringArray()
	for piece: String in line.substr(opening + 1, closing - opening - 1).split(","):
		var bare: String = piece.strip_edges().trim_prefix("\"").trim_suffix("\"")
		if not bare.is_empty():
			values.append(bare)
	return values


## Every .tscn in the project, found once per session - the input set for any question that has to
## be asked of every scene ("which one runs this script", "which spawner lists this scene").
static func scene_paths() -> PackedStringArray:
	if _scene_paths_scanned:
		return _scene_paths
	_scene_paths_scanned = true
	_collect_scene_paths("res://")
	# Path order, always. The directory walk hands files back in whatever order the filesystem
	# keeps them - close to alphabetical on NTFS, hash order on ext4 - and every list derived
	# from this one (a scan, a "worn by" sentence, a band's count) would inherit that difference
	# across machines. Sorted once here, every consumer answers the same on every platform.
	_scene_paths.sort()
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
