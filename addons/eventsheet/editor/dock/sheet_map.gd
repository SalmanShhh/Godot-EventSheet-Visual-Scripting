# Godot EventSheets - the sheet map's DATA (U17)
#
# "What talks to what" is a question an intermediate user asks weekly, and the project answers it one
# hit at a time: Find all references answers about one name, the listener notes answer about one
# signal, the Includes bar answers about one sheet. Nothing shows the SHAPE.
#
# So: one derived graph. Nodes are the sheets, scenes and globals a project has; edges are the four
# ways one reaches another - it CALLS a global's function, it SIGNALS (someone emits, someone else
# listens), it INCLUDES another script (extends / preload), or it CHANGES LAYOUT to a scene.
#
# DERIVED, NEVER STORED: nothing here is written into the project. The only thing remembered is
# where the reader dragged a node to, and that lives in editor metadata like every other reading
# position. Everything is static and pure over the files it reads, so the suite pins a whole graph
# against a fixture project without an editor.
@tool
class_name EventSheetSheetMap
extends RefCounted

## The kinds a node can be. Frozen: the tests pin them and the panel has one colour per kind.
const NODE_SHEET := "sheet"
const NODE_SCENE := "scene"
const NODE_GLOBAL := "global"

## The kinds an edge can be, in the words the map labels them with.
const EDGE_CALLS := "calls"
const EDGE_SIGNALS := "signals"
const EDGE_INCLUDES := "includes"
const EDGE_LAYOUT := "layout"

## Folders whose contents are the plugin or the test corpus, not the user's project.
const SKIPPED_DIRS: PackedStringArray = ["res://addons", "res://.godot", "res://tests"]

## Beyond this the picture stops being a picture. The map keeps the first nodes it finds and says
## how many it left out, rather than drawing a wall nobody can read.
const MAX_NODES := 120


## The whole graph: {nodes: Array[{id, label, kind}], edges: Array[{from, to, kind, label}],
## skipped: int}. `id` is the resource path, which is what a click opens; `label` is the file the
## way a reader writes it. Sorted throughout, so the same project draws the same map every time.
static func graph(root: String = "res://") -> Dictionary:
	var scripts: PackedStringArray = _scripts_under(root)
	var nodes: Dictionary = {}
	var edges: Array[Dictionary] = []
	for path: String in scripts:
		_add_node(nodes, path, NODE_SHEET)
	# A global joins the map when it is INSIDE the root being mapped; one that only something
	# outside it calls joins below, on the edge that calls it, so a map of one folder is a map of
	# that folder.
	for autoload_name: String in _autoload_names():
		var autoload_path: String = _autoload_path(autoload_name)
		if not autoload_path.is_empty() and autoload_path.begins_with(root):
			_add_node(nodes, autoload_path, NODE_GLOBAL, autoload_name)
	for path: String in scripts:
		_read_script(path, nodes, edges)
	_append_signal_edges(scripts, nodes, edges)
	var listed: Array = nodes.keys()
	listed.sort()
	var skipped: int = maxi(listed.size() - MAX_NODES, 0)
	if skipped > 0:
		listed.resize(MAX_NODES)
	var kept: Dictionary = {}
	var node_rows: Array[Dictionary] = []
	for id: String in listed:
		kept[id] = true
		node_rows.append(nodes[id])
	var edge_rows: Array[Dictionary] = []
	var seen: Dictionary = {}
	for edge: Dictionary in edges:
		if not kept.has(str(edge["from"])) or not kept.has(str(edge["to"])):
			continue
		var key: String = "%s|%s|%s|%s" % [edge["from"], edge["to"], edge["kind"], edge["label"]]
		if seen.has(key):
			continue
		seen[key] = true
		edge_rows.append(edge)
	edge_rows.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return "%s%s%s" % [left["from"], left["to"], left["label"]] \
			< "%s%s%s" % [right["from"], right["to"], right["label"]])
	return {"nodes": node_rows, "edges": edge_rows, "skipped": skipped}


## The map's one-line summary, in the sheet's own words - what the panel writes under the picture.
static func summary(found: Dictionary) -> String:
	var nodes: Array = found.get("nodes", []) as Array
	var edges: Array = found.get("edges", []) as Array
	var skipped: int = int(found.get("skipped", 0))
	var line: String = "%d sheet%s, %d connection%s" % [nodes.size(), "" if nodes.size() == 1 else "s",
		edges.size(), "" if edges.size() == 1 else "s"]
	if skipped > 0:
		line += " (%d more not drawn)" % skipped
	return line


# ── Reading one script ────────────────────────────────────────────────────────────────────────


## The edges one script starts: what it includes, which global it calls, and which layout it
## changes to. Line-by-line over the source, so nothing here needs the file to compile.
static func _read_script(path: String, nodes: Dictionary, edges: Array[Dictionary]) -> void:
	var source: String = _read(path)
	if source.is_empty():
		return
	var globals: Dictionary = {}
	for autoload_name: String in _autoload_names():
		var autoload_path: String = _autoload_path(autoload_name)
		if not autoload_path.is_empty() and autoload_path != path:
			globals[autoload_name] = autoload_path
	var path_pattern: RegEx = RegEx.create_from_string("\"(res://[^\"]+)\"")
	for raw_line: String in source.split("\n"):
		var line: String = raw_line.strip_edges()
		if line.begins_with("#"):
			continue
		for hit: RegExMatch in path_pattern.search_all(line):
			var target: String = hit.get_string(1)
			if target == path:
				continue
			var extension: String = target.get_extension().to_lower()
			if line.contains("change_scene_to_file") and extension == "tscn":
				_add_node(nodes, target, NODE_SCENE)
				edges.append(_edge(path, target, EDGE_LAYOUT, "Go to layout"))
			elif extension == "gd" and (line.begins_with("extends") or line.contains("preload(") or line.contains("load(")):
				_add_node(nodes, target, NODE_SHEET)
				edges.append(_edge(path, target, EDGE_INCLUDES, "includes"))
		for autoload_name: String in globals:
			if line.contains("%s." % autoload_name):
				_add_node(nodes, str(globals[autoload_name]), NODE_GLOBAL, autoload_name)
				edges.append(_edge(path, str(globals[autoload_name]), EDGE_CALLS,
					"calls %s" % autoload_name))


## The signal edges: everywhere a signal is RAISED, joined to everywhere it is LISTENED for. Both
## halves are read with the same two line readers the listener notes on a row use, so the map and
## the notes can never disagree about what counts as an emit or a connect - but the scan is the
## map's OWN, over the scripts it was asked about, so a map of one folder is a map of that folder.
static func _append_signal_edges(scripts: PackedStringArray, nodes: Dictionary,
		edges: Array[Dictionary]) -> void:
	var emitters: Dictionary = {}
	var listeners: Dictionary = {}
	for path: String in scripts:
		for raw_line: String in _read(path).split("\n"):
			var line: String = raw_line.strip_edges()
			if line.begins_with("#"):
				continue
			for name: String in EventSheetSignalFanout.emitted_signals_in(line):
				_record(emitters, name, path)
			for name: String in EventSheetSignalFanout.connected_signals_in(line):
				_record(listeners, name, path)
	var sorted_names: Array = emitters.keys()
	sorted_names.sort()
	for signal_name: String in sorted_names:
		if not listeners.has(signal_name):
			continue
		for from_path: String in (emitters[signal_name] as PackedStringArray):
			for to_path: String in (listeners[signal_name] as PackedStringArray):
				if to_path == from_path:
					continue
				_add_node(nodes, to_path, NODE_SHEET)
				edges.append(_edge(from_path, to_path, EDGE_SIGNALS, "signals On %s" % signal_name))


static func _record(into: Dictionary, signal_name: String, path: String) -> void:
	var paths: PackedStringArray = into.get(signal_name, PackedStringArray())
	if not paths.has(path):
		paths.append(path)
	into[signal_name] = paths


static func _edge(from_path: String, to_path: String, kind: String, label: String) -> Dictionary:
	return {"from": from_path, "to": to_path, "kind": kind, "label": label}


static func _add_node(nodes: Dictionary, path: String, kind: String, label: String = "") -> void:
	if path.strip_edges().is_empty():
		return
	if nodes.has(path) and label.is_empty():
		return
	nodes[path] = {
		"id": path,
		"label": label if not label.is_empty() else _label_of(path),
		"kind": kind
	}


## A file the way a reader writes it: "player.gd" becomes "Player", "main_menu.tscn" becomes
## "Main Menu (scene)". The same rule the Include bar names a sheet by.
static func _label_of(path: String) -> String:
	var base: String = path.get_file().get_basename().capitalize()
	return "%s (scene)" % base if path.get_extension().to_lower() == "tscn" else base


# ── The project ───────────────────────────────────────────────────────────────────────────────


## Every script under a root, minus the folders that are the plugin rather than the project. A root
## INSIDE one of those folders keeps it: asking for a map of that folder is asking on purpose, which
## is how a fixture project is pinned.
static func _scripts_under(root: String) -> PackedStringArray:
	var skipped: PackedStringArray = PackedStringArray()
	for candidate: String in SKIPPED_DIRS:
		if not root.begins_with(candidate):
			skipped.append(candidate)
	var found: PackedStringArray = PackedStringArray()
	_scan(root, skipped, found)
	found.sort()
	return found


static func _scan(directory_path: String, skipped_dirs: PackedStringArray, into: PackedStringArray) -> void:
	for skipped: String in skipped_dirs:
		if directory_path.begins_with(skipped):
			return
	var directory: DirAccess = DirAccess.open(directory_path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry: String = directory.get_next()
	while not entry.is_empty():
		if entry.begins_with("."):
			entry = directory.get_next()
			continue
		var full: String = directory_path.path_join(entry)
		if directory.current_is_dir():
			_scan(full, skipped_dirs, into)
		elif entry.get_extension().to_lower() == "gd":
			into.append(full)
		entry = directory.get_next()
	directory.list_dir_end()


## The project's globals, by the names the project settings give them.
static func _autoload_names() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for property: Dictionary in ProjectSettings.get_property_list():
		var name: String = str(property.get("name", ""))
		if name.begins_with("autoload/"):
			found.append(name.trim_prefix("autoload/"))
	found.sort()
	return found


## A global's script. A scene autoload answers with its scene, which is a node on the map too.
static func _autoload_path(autoload_name: String) -> String:
	var value: String = str(ProjectSettings.get_setting("autoload/%s" % autoload_name, ""))
	return value.trim_prefix("*").strip_edges()


static func _read(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var handle: FileAccess = FileAccess.open(path, FileAccess.READ)
	if handle == null:
		return ""
	var text: String = handle.get_as_text()
	handle.close()
	return text
