# Godot EventSheets - the three classic Godot mistakes a row makes without a word.
#
# Each one is something Godot's own manual warns about and a newcomer meets as "the row does nothing"
# or "the body shakes", with no message to say why:
#
#   a Control in a Container   a row that sets the position of a Control whose parent is a Container.
#                              The Container places its children itself and moves this one back the
#                              next time it arranges them.
#   a Tween on a physics body  a Tween on the position or scale of a RigidBody. The physics engine moves
#                              the body every physics frame and fights the Tween.
#   a behaviour that fights    a behaviour (it moves its parent) placed under a RigidBody. It writes the
#   a physics body             body's position or scale every frame while the engine moves it too.
#
# EVIDENCE, NOT SUSPICION. Each one is judged against the scene that runs the sheet's script: the node
# the row is about and the node above it must be known to Godot, with no instanced scene in the way. A
# sheet no scene runs, a node held in a variable and a class the scene cannot name earn nothing. Only a
# RigidBody is called a fight: a CharacterBody or an AnimatableBody is moved by code on purpose.
#
# THE QUIET SHEET LAW. Nothing renders in the sheet. A finding puts its row into the quiet amber state
# and the words live in the help strip, with Godot's own names for what to use instead.
#
# PURE + STATIC, like the mistake checks it joins, and loaded by path from them so the first open of the
# editor does not compile it.
@tool
class_name EventSheetClassicFindings
extends RefCounted

## The properties a Tween or a write may not touch on a rigid body.
const FIGHTING_PROPERTIES: PackedStringArray = ["position", "global_position", "scale"]

static var _write_regex: RegEx = null
static var _tween_regex: RegEx = null
static var _behaviour_regex: RegEx = null


## Every classic mistake this sheet makes. `rows` and `walk` are the mistake walk's, `scene` its scene
## facts, `script_path` the file the sheet lives in.
static func findings(rows: Array[Dictionary], walk: Dictionary, scene: Dictionary, script_path: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	if not bool(scene.get("known", false)) or script_path.is_empty():
		return found
	var placements: Array[Dictionary] = _placements(scene, script_path)
	if placements.is_empty():
		return found
	var is_behaviour: bool = bool(walk.get("behavior", false))
	var seen_behaviour: bool = false
	for context: Dictionary in rows:
		if str(context.get("lane", "")) != "action":
			continue
		var line: String = EventSheetMistakeFindings.strip_comments(str(context.get("line", "")))
		if line.contains("position") or line.contains("scale"):
			_in_a_container(context, line, placements, is_behaviour, found)
			_tween_on_a_body(context, line, placements, is_behaviour, found)
			if is_behaviour and not seen_behaviour and _host_write(line) != "":
				seen_behaviour = _behaviour_on_a_body(context, line, placements, found)
	return found


## Every node of every scene that runs this script: {"nodes": the scene's nodes by path, "path": where
## the script sits, "node": its entry, "scene": the file}.
static func _placements(scene: Dictionary, script_path: String) -> Array[Dictionary]:
	var placements: Array[Dictionary] = []
	for scene_path: Variant in scene.get("scenes", []):
		var nodes: Dictionary = {}
		var listed: Array = EventSheetSceneConnections.nodes_of_scene(str(scene_path))
		for entry: Variant in listed:
			nodes[str((entry as Dictionary).get("path", ""))] = entry
		for entry: Variant in listed:
			if str((entry as Dictionary).get("script_path", "")) == script_path:
				placements.append({"nodes": nodes, "path": str((entry as Dictionary).get("path", "")),
					"node": entry, "scene": str(scene_path)})
	return placements


## The path of the node a reference names, seen from the node the script sits on, or "" when it is not
## a plain node reference (a variable, a call).
static func _resolve(reference: String, placement: Dictionary) -> String:
	var host: String = str(placement["path"])
	var nodes: Dictionary = placement["nodes"]
	if reference.is_empty() or reference == "self":
		return host
	if reference.begins_with("%"):
		for path: Variant in nodes.keys():
			var node: Dictionary = nodes[path]
			if str(node.get("name", "")) == reference.substr(1) and bool(node.get("unique", false)):
				return str(path)
		return ""
	if not reference.begins_with("$"):
		return ""
	var relative: String = reference.substr(1).trim_prefix("\"").trim_suffix("\"")
	if relative.is_empty() or relative.contains("..") or relative.contains("\"") or relative.contains("("):
		return ""
	return relative if host == "." else "%s/%s" % [host, relative]


## The Godot class of the node at a path, or "" when an instanced scene or a script's own type is in the
## way (the scene file cannot say what is inside).
static func _class_of(path: String, placement: Dictionary) -> String:
	var node: Dictionary = (placement["nodes"] as Dictionary).get(path, {})
	if node.is_empty() or not str(node.get("instance_path", "")).is_empty():
		return ""
	var node_class: String = str(node.get("type", ""))
	return node_class if ClassDB.class_exists(node_class) else ""


## The node above a path, as its path ("" for the scene's root, which has no parent the file can see).
static func _parent_of(path: String) -> String:
	if path == ".":
		return ""
	var base: String = path.get_base_dir()
	return "." if base.is_empty() else base


static func _name_of(path: String, placement: Dictionary) -> String:
	return str(((placement["nodes"] as Dictionary).get(path, {}) as Dictionary).get("name", path))


# -- 1. A Control in a Container ---------------------------------------------------------------------------


static func _in_a_container(context: Dictionary, line: String, placements: Array[Dictionary],
		is_behaviour: bool, found: Array[Dictionary]) -> void:
	if _write_regex == null:
		_write_regex = RegEx.create_from_string("(?m)^\\s*(?:(?<target>self|\\$\"[^\"]+\"|\\$[A-Za-z0-9_/]+|%[A-Za-z0-9_]+)\\.)?(?:global_)?position(?:\\.[xy])?\\s*[-+*/]?=(?!=)")
	for hit: RegExMatch in _write_regex.search_all(line):
		var target: String = hit.get_string("target")
		if is_behaviour and (target.is_empty() or target == "self"):
			continue
		var culprit: String = ""
		var container: String = ""
		for placement: Dictionary in placements:
			var path: String = _resolve(target, placement)
			var node_class: String = _class_of(path, placement) if path != "" else ""
			var above: String = _class_of(_parent_of(path), placement) if node_class != "" else ""
			if node_class == "" or above == "" or not ClassDB.is_parent_class(node_class, "Control") \
					or not _is_arranging_container(above):
				culprit = ""
				break
			if culprit.is_empty():
				culprit = _name_of(path, placement)
				container = above
		if culprit.is_empty():
			continue
		found.append(_finding(EventSheetMistakeFindings.KIND_CONTROL_IN_CONTAINER, context, culprit,
			EventSheetL10n.translate("%s sits inside a %s, and a Container places its children itself: the next time it arranges them it moves this Control back, so this row seems to do nothing. To place it yourself, put the Control under a plain Control node instead; to change where it ends up inside the Container, change the Container's own settings or this Control's size flags and custom minimum size.") % [
				culprit, container]))
		return


## True for a Container that arranges its children. The base Container class arranges nothing on its own.
static func _is_arranging_container(node_class: String) -> bool:
	return node_class != "Container" and ClassDB.is_parent_class(node_class, "Container")


# -- 2. A Tween on a physics body --------------------------------------------------------------------------


static func _tween_on_a_body(context: Dictionary, line: String, placements: Array[Dictionary],
		is_behaviour: bool, found: Array[Dictionary]) -> void:
	if not line.contains("tween_property("):
		return
	if _tween_regex == null:
		_tween_regex = RegEx.create_from_string("tween_property\\(\\s*(?<target>self|\\$\"[^\"]+\"|\\$[A-Za-z0-9_/]+|%[A-Za-z0-9_]+)\\s*,\\s*(?:NodePath\\(\\s*)?[&^]?\"(?<property>[A-Za-z_]+)(?::[A-Za-z_]+)?\"")
	for hit: RegExMatch in _tween_regex.search_all(line):
		var property: String = hit.get_string("property")
		var target: String = hit.get_string("target")
		if not FIGHTING_PROPERTIES.has(property) or (is_behaviour and target == "self"):
			continue
		var body_class: String = ""
		var body_name: String = ""
		for placement: Dictionary in placements:
			var path: String = _resolve(target, placement)
			var node_class: String = _class_of(path, placement) if path != "" else ""
			if node_class == "" or not _is_rigid_body(node_class):
				body_class = ""
				break
			if body_class.is_empty():
				body_class = node_class
				body_name = _name_of(path, placement)
		if body_class.is_empty():
			continue
		var impulse: String = EventSheetL10n.translate("Apply Central Impulse (3D)") if body_class.ends_with("3D") \
			else EventSheetL10n.translate("Apply Central Impulse")
		found.append(_finding(EventSheetMistakeFindings.KIND_TWEEN_ON_BODY, context, body_name,
			EventSheetL10n.translate("%s is a %s, which the physics engine moves every physics frame, so a Tween on its %s fights the engine: the body jitters, snaps back or is pushed through walls. Tween a child node instead (a Sprite2D, say), move the body with %s, or turn on Freeze on the body first so code may move it.") % [
				body_name, body_class, property, impulse]))
		return


static func _is_rigid_body(node_class: String) -> bool:
	return ClassDB.is_parent_class(node_class, "RigidBody2D") or ClassDB.is_parent_class(node_class, "RigidBody3D")


# -- 3. A behaviour that fights a physics body -------------------------------------------------------------


## The property of its host a line writes ("position", "global_position" or "scale"), or "".
static func _host_write(line: String) -> String:
	if _behaviour_regex == null:
		_behaviour_regex = RegEx.create_from_string("\\bhost\\.(?<property>position|global_position|scale)(?:\\.[xyz])?\\s*[-+*/]?=(?!=)")
	var hit: RegExMatch = _behaviour_regex.search(line)
	return hit.get_string("property") if hit != null else ""


static func _behaviour_on_a_body(context: Dictionary, line: String, placements: Array[Dictionary],
		found: Array[Dictionary]) -> bool:
	var property: String = _host_write(line)
	for placement: Dictionary in placements:
		var node: Dictionary = placement["node"]
		# A behaviour told to act on another node is not judged by what it sits under.
		if (node.get("properties", {}) as Dictionary).has("acts_on"):
			continue
		var parent: String = _parent_of(str(placement["path"]))
		var parent_class: String = _class_of(parent, placement) if parent != "" else ""
		if parent_class == "" or not _is_rigid_body(parent_class):
			continue
		var impulse: String = EventSheetL10n.translate("Apply Central Impulse (3D)") if parent_class.ends_with("3D") \
			else EventSheetL10n.translate("Apply Central Impulse")
		found.append(_finding(EventSheetMistakeFindings.KIND_BEHAVIOUR_ON_BODY, context, _name_of(parent, placement),
			EventSheetL10n.translate("This behaviour sits under %s, a %s, and it writes its parent's %s every frame while the physics engine moves that body too, so the two fight: the body jitters, snaps back or is pushed through walls. Put the behaviour on a node that is not a physics body (the Sprite2D inside it, or a plain Node2D), or move the body with %s instead.") % [
				_name_of(parent, placement), parent_class, property, impulse]))
		return true
	return false


# -- The shape every family speaks ------------------------------------------------------------------------


static func _finding(kind: String, context: Dictionary, subject: String, sentence: String) -> Dictionary:
	return EventSheetMistakeFindings._finding(kind, "warning", context["event"] as EventRow, subject, sentence,
		"", "", context, {})
