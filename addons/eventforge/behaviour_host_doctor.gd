# Godot EventSheets - the Doctor's Behaviour hosts section.
#
# A behaviour is a child node that works on its PARENT. Put it under the wrong kind of node (a
# Platformer Movement under a Node2D) and nothing breaks loudly: the game runs, the behaviour logs one
# line at run time, and the character simply does not move. The scene file already says it all - which
# node a behaviour sits under and what type that node is - so this section reads every scene in the
# project as TEXT (no game run, no scene loaded) and says it before the game does.
#
# A behaviour is any script that declares `var host: <Type> = null` and binds it from `get_parent()`.
# The type it needs is read from the script itself, so a studio's own behaviours are audited exactly
# like the shipped ones, and the packs stay plain GDScript with no plugin dependency.
#
# Each finding carries the doors that fit it: "Move it under <nearest node of the right type>" where
# the scene has one, and "Show in scene". Nothing is written until a door is used, and the move edits
# the scene file as text, keeping every other byte.
@tool
class_name EventSheetBehaviourHostDoctor
extends EventSheetDoctorSection

## The id the section is registered under, and the id each finding is filed as. Frozen: the fix
## doors and the tests address a finding by its check id.
const CHECK_ID := "behaviour-host"


## Registers the section, replacing any previous registration - so a plugin reload, a second Doctor
## run and a test that registers it by hand all leave exactly one.
static func ensure_registered() -> void:
	EventSheetProjectDoctor.register_check(CHECK_ID, Callable(EventSheetBehaviourHostDoctor, "check"))


## The section itself, with the contract every registered check has: append findings, never write
## inside res://.
static func check(_sheet_paths: PackedStringArray, findings: Array[Dictionary]) -> void:
	var scenes: PackedStringArray = EventSheetProjectDoctor._list_files_with_extension("tscn")
	scenes.sort()
	var behaviours: Dictionary = {}
	for scene_path: String in scenes:
		var text: String = EventSheetProjectDoctor.source_of(scene_path)
		# One substring test decides whether a scene can hold a behaviour at all.
		if not text.contains("[ext_resource type=\"Script\""):
			continue
		findings.append_array(report_for_scene(scene_path, text, behaviours))


## The findings of one scene's text. `behaviours` caches what each script is (a behaviour and the
## host type it needs, or nothing) so a project reads each script once.
static func report_for_scene(scene_path: String, text: String, behaviours: Dictionary = {}) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	var scene: Dictionary = parse_scene(text)
	var nodes: Array = scene["nodes"] as Array
	var by_path: Dictionary = scene["by_path"] as Dictionary
	for node: Dictionary in nodes:
		var script_path: String = str((scene["scripts"] as Dictionary).get(str(node["script_id"]), ""))
		if script_path.is_empty() or str(node["parent"]) == "":
			continue
		var info: Dictionary = behaviour_info(script_path, behaviours)
		if info.is_empty():
			continue
		var host_type: String = str(info["host"])
		var label: String = str(info["label"])
		var actual: String = ""
		var acts_on: String = str(node["acts_on"])
		if not acts_on.is_empty():
			var target: Dictionary = by_path.get(resolve_path(str(node["path"]), acts_on), {}) as Dictionary
			actual = str(target.get("type", ""))
			if actual.is_empty() or fits(actual, host_type):
				continue
			findings.append(_found(scene_path, node, "%s acts on a %s; it needs %s." % [
				label, actual, EventSheetCompiler.host_phrase(host_type)], ""))
			continue
		var parent: Dictionary = by_path.get(str(node["parent"]), {}) as Dictionary
		actual = str(parent.get("type", ""))
		if actual.is_empty() or fits(actual, host_type):
			continue
		var nearest: String = nearest_host(nodes, node, host_type)
		findings.append(_found(scene_path, node, "%s is under a %s; it needs %s: put it under one, or set Acts on." % [
			label, actual, EventSheetCompiler.host_phrase(host_type)], nearest))
	return findings


## True when a node of type `actual` is a `host_type`. A type the engine does not know (a script's
## own class, an instanced scene) is never called wrong: without the evidence, silence.
static func fits(actual: String, host_type: String) -> bool:
	if host_type == "Node" or actual == host_type:
		return true
	if not ClassDB.class_exists(actual) or not ClassDB.class_exists(host_type):
		return true
	return ClassDB.is_parent_class(actual, host_type)


## What a script is, as {label, host}: a behaviour is a script that declares `var host: <Type> = null`
## and binds it from its parent. {} for anything else. `label` is its class name in words
## ("PlatformerMovement" is "Platformer Movement").
static func behaviour_info(script_path: String, cache: Dictionary = {}) -> Dictionary:
	if cache.has(script_path):
		return cache[script_path] as Dictionary
	var info: Dictionary = {}
	var source: String = EventSheetProjectDoctor.source_of(script_path)
	if source.contains("host = get_parent() as ") or source.contains("host = acts_on if acts_on != null else get_parent() as "):
		var declared: RegExMatch = RegEx.create_from_string("(?m)^var host: ([A-Za-z_][A-Za-z0-9_]*) = null$").search(source)
		var named: RegExMatch = RegEx.create_from_string("(?m)^class_name ([A-Za-z_][A-Za-z0-9_]*)$").search(source)
		if declared != null:
			var class_label: String = named.get_string(1) if named != null else script_path.get_file().get_basename().to_pascal_case()
			info = {"host": declared.get_string(1), "label": EventSheetCompiler.spaced_class_name(class_label)}
	cache[script_path] = info
	return info


## A scene's text as nodes. Each is {name, type, parent, path, script_id, acts_on, line}: `parent` is
## the saved parent path ("." for the root's children, "" for the root itself) and `path` the node's
## own path from the root. `scripts` maps an ext_resource id to its script path and `by_path` finds a
## node by its path ("." is the root). A node with no `type` is an instanced scene.
static func parse_scene(text: String) -> Dictionary:
	var scripts: Dictionary = {}
	var nodes: Array[Dictionary] = []
	var by_path: Dictionary = {}
	var attribute: RegEx = RegEx.create_from_string("([a-z_]+)=\"([^\"]*)\"")
	var current: Dictionary = {}
	var lines: PackedStringArray = text.split("\n")
	for index: int in range(lines.size()):
		var line: String = lines[index].strip_edges()
		if line.begins_with("["):
			current = {}
			var attributes: Dictionary = {}
			for found: RegExMatch in attribute.search_all(line):
				attributes[found.get_string(1)] = found.get_string(2)
			if line.begins_with("[ext_resource") and str(attributes.get("type", "")) == "Script":
				scripts[str(attributes.get("id", ""))] = str(attributes.get("path", ""))
			elif line.begins_with("[node "):
				var node_name: String = str(attributes.get("name", ""))
				var parent: String = str(attributes.get("parent", ""))
				var own_path: String = "."
				if not parent.is_empty():
					own_path = node_name if parent == "." else "%s/%s" % [parent, node_name]
				current = {"name": node_name, "type": str(attributes.get("type", "")), "parent": parent,
					"path": own_path, "script_id": "", "acts_on": "", "line": index}
				nodes.append(current)
				by_path[own_path] = current
			continue
		if current.is_empty():
			continue
		if line.begins_with("script = ExtResource("):
			current["script_id"] = line.get_slice("\"", 1)
		elif line.begins_with("acts_on = NodePath("):
			current["acts_on"] = line.get_slice("\"", 1)
	return {"nodes": nodes, "scripts": scripts, "by_path": by_path}


## A node path as the scene saves it: the NodePath `relative` read from the node at `from_path`.
static func resolve_path(from_path: String, relative: String) -> String:
	var parts: PackedStringArray = [] if from_path == "." else from_path.split("/")
	for step: String in relative.split("/"):
		if step == "..":
			if parts.size() > 0:
				parts.remove_at(parts.size() - 1)
		elif step != "." and not step.is_empty():
			parts.append(step)
	return "." if parts.is_empty() else "/".join(parts)


## The path of the node a behaviour could move under: the closest one in the tree (siblings, then the
## ancestors and their children) whose type is `host_type`, or "". Never the behaviour or anything
## below it, and never a node whose type the scene does not say.
static func nearest_host(nodes: Array, behaviour: Dictionary, host_type: String) -> String:
	var own: String = str(behaviour["path"])
	var best: String = ""
	var best_distance: int = 1 << 30
	for candidate: Dictionary in nodes:
		var path: String = str(candidate["path"])
		var type_name: String = str(candidate["type"])
		if type_name.is_empty() or path == own or path.begins_with(own + "/"):
			continue
		if host_type == "Node" or not fits(type_name, host_type):
			continue
		var distance: int = tree_distance(own, path)
		if distance < best_distance or (distance == best_distance and path < best):
			best = path
			best_distance = distance
	return best


## Steps between two nodes through their closest common ancestor.
static func tree_distance(left: String, right: String) -> int:
	var left_parts: PackedStringArray = [] if left == "." else left.split("/")
	var right_parts: PackedStringArray = [] if right == "." else right.split("/")
	var shared: int = 0
	while shared < left_parts.size() and shared < right_parts.size() and left_parts[shared] == right_parts[shared]:
		shared += 1
	return (left_parts.size() - shared) + (right_parts.size() - shared)


static func _found(scene_path: String, node: Dictionary, sentence: String, nearest: String) -> Dictionary:
	var found: Dictionary = _finding("warning", CHECK_ID, scene_path,
		"%s (%s, node %s)" % [sentence, scene_path.get_file(), str(node["path"])], str(node["name"]))
	found["node"] = str(node["path"])
	found["kind"] = CHECK_ID
	if not nearest.is_empty():
		found["to_path"] = nearest
		found["to"] = nearest.get_file() if nearest != "." else "the scene's root"
	return found


## The door "Move it under <node>": rewrites the scene's text so the behaviour at `node_path` hangs
## under `new_parent_path`, keeping every other byte. Refuses, saying why, when the behaviour has
## children of its own, when the new parent already has a node by that name, or when the scene does
## not hold either node. Signal connections naming the behaviour follow it to its new path.
static func move_under(scene_path: String, node_path: String, new_parent_path: String) -> Dictionary:
	var text: String = FileAccess.get_file_as_string(scene_path)
	var scene: Dictionary = parse_scene(text)
	var by_path: Dictionary = scene["by_path"] as Dictionary
	if not by_path.has(node_path) or not by_path.has(new_parent_path):
		return {"ok": false, "message": "The scene no longer has both nodes - re-run the check."}
	var node: Dictionary = by_path[node_path] as Dictionary
	var new_path: String = str(node["name"]) if new_parent_path == "." else "%s/%s" % [new_parent_path, str(node["name"])]
	if by_path.has(new_path):
		return {"ok": false, "message": "%s already has a node named %s." % [new_parent_path, str(node["name"])]}
	for other: Dictionary in scene["nodes"] as Array:
		if str(other["parent"]) == node_path or str(other["parent"]).begins_with(node_path + "/"):
			return {"ok": false, "message": "%s has nodes of its own under it - move it in the Scene dock instead." % str(node["name"])}
	var lines: PackedStringArray = text.split("\n")
	var start: int = int(node["line"])
	var end: int = start + 1
	while end < lines.size() and not lines[end].begins_with("["):
		end += 1
	var block: PackedStringArray = lines.slice(start, end)
	var parent_attribute: String = " parent=\"%s\"" % str(node["parent"])
	block[0] = block[0].replace(parent_attribute, " parent=\"%s\"" % new_parent_path)
	# The block leaves its place and lands right under the new parent's own header block: a scene
	# file lists a parent before its children, so the new parent must come first.
	var remaining: PackedStringArray = lines.slice(0, start)
	remaining.append_array(lines.slice(end))
	var parent_start: int = int((by_path[new_parent_path] as Dictionary)["line"])
	if parent_start > start:
		parent_start -= end - start
	var parent_end: int = parent_start + 1
	while parent_end < remaining.size() and not remaining[parent_end].begins_with("["):
		parent_end += 1
	var moved: PackedStringArray = remaining.slice(0, parent_end)
	moved.append_array(block)
	moved.append_array(remaining.slice(parent_end))
	var rewritten: String = "\n".join(moved)
	rewritten = rewritten.replace("from=\"%s\"" % node_path, "from=\"%s\"" % new_path)
	rewritten = rewritten.replace(" to=\"%s\"" % node_path, " to=\"%s\"" % new_path)
	var handle: FileAccess = FileAccess.open(scene_path, FileAccess.WRITE)
	if handle == null:
		return {"ok": false, "message": "Could not write %s." % scene_path}
	handle.store_string(rewritten)
	handle.close()
	return {"ok": true, "message": "Moved %s under %s." % [str(node["name"]), new_parent_path]}
