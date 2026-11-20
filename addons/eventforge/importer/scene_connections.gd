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
## The re-read of that index being made off the main thread, whether another was asked for while it ran,
## and the call the dock hangs on to hear that the one that arrived says something the old one did not.
static var _index_refresh: RefCounted = null
static var _index_refresh_again: bool = false
## Set when a move is followed while a re-read is under way: what that read brings is from before the move.
static var _index_refresh_outdated: bool = false
static var index_changed: Callable = Callable()
## The helpers that read the project off the main thread and follow a move; loaded by path, so the first
## open of the editor does not compile them.
const SWEEP_PATH := "res://addons/eventforge/importer/background_sweep.gd"
const FOLLOW_PATH := "res://addons/eventforge/importer/scene_index_follow.gd"
## The first read of both scene indexes, made in the editor's idle time (see that file). Loaded by path, and
## only ever asked once something has loaded it.
const PREP_PATH := "res://addons/eventforge/importer/scene_index_prep.gd"

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
	if _defer_to_idle_read():
		return
	var prepared: Variant = _take_prepared()
	if prepared is Dictionary:
		_adopt_prepared(prepared)
		return
	_scenes_by_script = index_scenes(scene_paths())
	_scenes_by_script_built = true


## Set around the one stretch of work (a sheet's rows being built) that would rather be told "not yet" than wait
## for the project's first read. While it is set and the first read of the scenes is not here, a question about
## the project's scenes is answered with nothing, the answer is not kept by anyone, and the dock is told
## through `index_changed` when the read lands (see `take_withheld`). Set through `set_withhold_answers`.
static var _withhold: bool = false
## Whether an answer was withheld since the last `take_withheld`, and how many have been in all (a caller that
## keeps what it worked out compares the count before and after, and keeps nothing when it moved).
static var _withheld_pending: bool = false
static var withheld_count: int = 0


## Sets `_withhold` on behalf of another script. A static variable assigned from outside its own script marks that
## script as edited, and Godot's scene save then rewrites every edited script; a write made here does not.
static func set_withhold_answers(value: bool) -> void:
	_withhold = value


## Whether answers are being withheld right now (an inner stretch puts back what it found, not "off").
static func is_withholding() -> bool:
	return _withhold


## Whether an answer was withheld since this was last asked, and forgets it.
static func take_withheld() -> bool:
	var pending: bool = _withheld_pending
	_withheld_pending = false
	return pending


## Records that a question was answered with nothing because the read of the scenes is not here yet.
static func note_withheld() -> void:
	_withheld_pending = true
	withheld_count += 1


## Whether this question is to be answered with nothing for now, and the read of the project begun (or kept
## going) on its own thread so the answer arrives. False when the question may wait, or the read is here.
static func _defer_to_idle_read() -> bool:
	if not _withhold or not (Engine.is_editor_hint() and Engine.get_main_loop() is SceneTree):
		return false
	var prep: GDScript = load(PREP_PATH)
	if not prep.running():
		if prep.pending():
			return false
		if not prep.start():
			return false
	note_withheld()
	prep.tell_when_ready(_on_idle_read_ready)
	return true


## The idle read ended: its answer is taken, and the dock is told so the rows built without it are built again.
static func _on_idle_read_ready() -> void:
	var prep: GDScript = load(PREP_PATH)
	var prepared: Variant = prep.take_connections(false)
	if prepared is Dictionary:
		_adopt_prepared(prepared)
		_cache.clear()
	elif prep.start():
		prep.tell_when_ready(_on_idle_read_ready)
		return
	if index_changed.is_valid():
		index_changed.call()


## Whether the index of which scenes load which script is held (built here, or taken from the idle read).
static func index_built() -> bool:
	return _scenes_by_script_built


## The idle read of the project, when it has been started and nothing has changed since: its scene list and index.
## A read that is still under way is waited for rather than made twice. Null when there is none to give.
static func _take_prepared() -> Variant:
	if not ResourceLoader.has_cached(PREP_PATH):
		return null
	return load(PREP_PATH).take_connections()


## Makes what the idle read brought the scene list and the index. The list is left alone when one was already
## walked (the walk is the same either way), and the index is only marked built here, once it is whole.
static func _adopt_prepared(prepared: Dictionary) -> void:
	if not _scene_paths_scanned:
		_scene_paths = prepared["paths"]
		_scene_paths_scanned = true
	_scenes_by_script = prepared["index"]
	_scenes_by_script_built = true


## What the idle read holds is from before a change: it is dropped, and read again when the editor is quiet.
static func _forget_prepared() -> void:
	if ResourceLoader.has_cached(PREP_PATH):
		load(PREP_PATH).invalidate()


## Which scenes of `paths` load each script, {script path: [scene paths, in the order given]}. Touches
## nothing but what it returns, so it can run on a worker thread.
static func index_scenes(paths: PackedStringArray) -> Dictionary:
	var index: Dictionary = {}
	for scene_path: String in paths:
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
	return index


## Follows a file or folder move in what is held, and reads no file: the answers worked out for the old
## paths are dropped (the next question works them out again, from the few scenes that name the script),
## and the list of scenes and the index of them keep their entries under the new names.
static func note_path_moved(old_path: String, new_path: String, is_folder: bool) -> void:
	_forget_prepared()
	_index_refresh_outdated = _index_refresh != null
	_cache.clear()
	# Only a scene's own move (or a folder's) changes where scenes are; a script's never does.
	if _scene_paths_scanned and (is_folder or old_path.get_extension().to_lower() == "tscn"):
		_scene_paths = load(FOLLOW_PATH).scene_paths_after_move(_scene_paths, old_path, new_path, is_folder)
	if _scenes_by_script_built:
		_scenes_by_script = load(FOLLOW_PATH).scenes_after_move(_scenes_by_script, old_path, new_path, is_folder)


## The editor's filesystem changed. Everything that is only an answer worked out from files is dropped,
## as `clear_cache` does, but the index of which scenes load which script - the part that costs a read of
## every scene - keeps answering while a worker thread reads it again, and `index_changed` is called if
## what arrives differs. Where no worker can be used (a headless run) this is `clear_cache`.
static func files_changed() -> void:
	_forget_prepared()
	if not _scenes_by_script_built or not (Engine.is_editor_hint() and Engine.get_main_loop() is SceneTree):
		clear_cache()
		return
	# The list of scenes keeps answering too, from what it held: a question that came while the re-read is on its
	# thread would otherwise walk the whole project on the main thread to build the list the re-read is building.
	var held_paths: PackedStringArray = _scene_paths
	var held_scanned: bool = _scene_paths_scanned
	_drop_derived()
	_scene_paths = held_paths
	_scene_paths_scanned = held_scanned
	start_index_refresh()


## Starts reading the index on a worker thread. Asked again while one is running, it is read once more
## when the first arrives (the first may have begun before the change that prompted the second).
static func start_index_refresh() -> void:
	if _index_refresh != null:
		_index_refresh_again = true
		return
	_index_refresh = load(SWEEP_PATH).new(func() -> Array:
		var paths: PackedStringArray = PackedStringArray()
		_walk_scene_paths("res://", paths)
		paths.sort()
		return [paths, index_scenes(paths)])
	_poll_index_refresh()


## Whether a re-read is under way.
static func index_refresh_running() -> bool:
	return _index_refresh != null


## Waits for the re-read to arrive and takes it. A no-op when none is running. What the frame loop does the
## moment the worker is done; a run with no frame loop (the test runner) calls it directly.
static func finish_index_refresh() -> void:
	_finish_index_refresh(true)


static func _poll_index_refresh() -> void:
	if _index_refresh == null:
		return
	if _index_refresh.is_done():
		_finish_index_refresh(true)
		return
	var loop: SceneTree = Engine.get_main_loop() as SceneTree
	if loop != null:
		loop.process_frame.connect(_poll_index_refresh, CONNECT_ONE_SHOT)


static func _finish_index_refresh(adopt: bool) -> void:
	var refresh: RefCounted = _index_refresh
	if refresh == null:
		return
	_index_refresh = null
	var arrived: Array = refresh.finish()
	var outdated: bool = _index_refresh_outdated
	_index_refresh_outdated = false
	if not adopt:
		return
	# A read that began before a move names the files as they were: what followed the move is kept, and the
	# change the editor reports when its files settle is what is read next.
	var changed: bool = false
	if not outdated:
		changed = not _scenes_by_script_built or not load(FOLLOW_PATH).scenes_match(_scenes_by_script, arrived[1])
		_scenes_by_script = arrived[1]
		_scenes_by_script_built = true
		# The re-read's list is the list: the one kept while it ran may name a scene that has gone or miss a new one.
		if _scene_paths != arrived[0] or not _scene_paths_scanned:
			changed = true
		_scene_paths = arrived[0]
		_scene_paths_scanned = true
	if changed:
		# What was worked out from the list that was just replaced is worked out again.
		_cache.clear()
	if _index_refresh_again:
		_index_refresh_again = false
		start_index_refresh()
	if changed and index_changed.is_valid():
		index_changed.call()


## Drops the cache. The editor calls `files_changed` when the filesystem changes; tests call this between
## fixtures. The parsed node lists and their stamps go too: a caller clearing this reader has just changed
## scene files, and a held stamp would hand the old parse back. A re-read of the index that is still
## running is ended with it, since what it brings would answer for the files from before.
static func clear_cache() -> void:
	_forget_prepared()
	_drop_derived()
	_scenes_by_script = {}
	_scenes_by_script_built = false
	_index_refresh_again = false
	_finish_index_refresh(false)


## Everything `clear_cache` drops except the index of which scenes load which script.
static func _drop_derived() -> void:
	_cache.clear()
	_nodes_cache.clear()
	_scene_paths = PackedStringArray()
	_scene_paths_scanned = false
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
				# The scene-unique mark - `%HealthBar` - which an older editor wrote as a BARE flag on the
				# node's own header and the current one writes as a property line under it (read below,
				# with the other properties). Read here because this is the project's one reader of scene
				# text, and because every family that wants to know whether a node has a name of its own
				# asks the same question.
				"unique": flag_attribute(line, "unique_name_in_owner"),
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
		# The mark as the editor writes it today: a property line under the node's header. The bare flag
		# on the header (read above) is how older scenes spell it, and both are the same mark.
		if key == "unique_name_in_owner" and value == "true":
			current["unique"] = true
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
	# The key is preceded by a space, so `id="` never matches inside `uid="` (a scene the editor saved
	# writes both on an ext_resource line, and the shorter key used to read the uid as the id).
	var marker: String = " %s=\"" % key
	var start: int = line.find(marker)
	if start < 0:
		return ""
	start += marker.length()
	var end: int = line.find("\"", start)
	return line.substr(start, end - start) if end > start else ""


## `key=true` out of a .tscn header line - the BARE spelling the editor uses for a node's own flags,
## with no quotes around the value. `unique_name_in_owner` is written this way, so the quoted reader
## above walks straight past it. Public for the same reason `attribute` is: this module is the
## project's ONE reader of scene text.
static func flag_attribute(line: String, key: String) -> bool:
	return line.contains("%s=true" % key)


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
	var prepared: Variant = _take_prepared()
	if prepared is Dictionary:
		_scene_paths = prepared["paths"]
		_scene_paths_scanned = true
		if not _scenes_by_script_built:
			_scenes_by_script = prepared["index"]
			_scenes_by_script_built = true
		return _scene_paths
	_scene_paths_scanned = true
	_walk_scene_paths("res://", _scene_paths)
	# Path order, always. The directory walk hands files back in whatever order the filesystem
	# keeps them - close to alphabetical on NTFS, hash order on ext4 - and every list derived
	# from this one (a scan, a "worn by" sentence, a band's count) would inherit that difference
	# across machines. Sorted once here, every consumer answers the same on every platform.
	_scene_paths.sort()
	return _scene_paths


static func _walk_scene_paths(directory_path: String, into: PackedStringArray) -> void:
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
			_walk_scene_paths(full_path, into)
		elif entry.get_extension() == "tscn":
			into.append(full_path)
		entry = directory.get_next()
	directory.list_dir_end()


## Sets `index_changed` on behalf of another script. A static variable assigned from outside its own script marks that script as
## edited, and Godot's scene save then rewrites every edited script (a reload each, seconds in all); a write made here does not.
static func set_index_changed(value: Callable) -> void:
	index_changed = value


## Sets `scene_scope` on behalf of another script. A static variable assigned from outside its own script marks that script as
## edited, and Godot's scene save then rewrites every edited script (a reload each, seconds in all); a write made here does not.
static func set_scene_scope(value: String) -> void:
	scene_scope = value
