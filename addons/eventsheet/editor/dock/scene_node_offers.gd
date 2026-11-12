@tool
extends RefCounted

# What Godot itself already knows about a node decides which event a canvas drop offers. Nothing is
# stored by the plugin: a node in the Godot group `secret` is a secret, a node in the group `water`
# is water, and a node whose script exports a `needs_key` variable is a locked door. The groups are
# set in the Node dock (Groups tab) and the variable in the Inspector, so the scene file is the one
# place the answer lives. An object the open scene does not hold gets no offer, exactly like a node
# that is in none of these groups.

const SECRET_GROUP := "secret"
const WATER_GROUP := "water"
const DOOR_VARIABLE := "needs_key"


## The node an object label names inside `scene_root`, or null. `reference` is the path the census
## recorded for the object (`$Door`, `%Door`, `Rooms/Door`), tried before the bare label.
static func find_node(scene_root: Node, object_label: String, reference: String = "") -> Node:
	if scene_root == null:
		return null
	for candidate: String in [reference, object_label]:
		var path: String = candidate.strip_edges().trim_prefix("$").trim_prefix("%")
		if path.is_empty():
			continue
		var found: Node = scene_root.get_node_or_null(NodePath(path))
		if found == null:
			found = scene_root.find_child(path.get_file(), true, false)
		if found != null:
			return found
	return null


## True when the node is in the Godot group `secret`.
static func is_secret(node: Node) -> bool:
	return node != null and node.is_in_group(SECRET_GROUP)


## True when the node is in the Godot group `water`.
static func is_water(node: Node) -> bool:
	return node != null and node.is_in_group(WATER_GROUP)


## True when the node's script declares an exported `needs_key` variable.
static func is_locked_door(node: Node) -> bool:
	if node == null:
		return false
	var script: Script = node.get_script() as Script
	if script == null:
		return false
	for property: Dictionary in script.get_script_property_list():
		if str(property.get("name", "")) == DOOR_VARIABLE \
				and (int(property.get("usage", 0)) & PROPERTY_USAGE_EDITOR) != 0:
			return true
	return false


## The offer an object's drop makes, as "secret", "door", "water" or "" - in that order of
## precedence, the order the drop has always tried them in.
static func offer_for(node: Node) -> String:
	if is_secret(node):
		return "secret"
	if is_locked_door(node):
		return "door"
	if is_water(node):
		return "water"
	return ""


## The offer for an object label in the scene open in the editor, "" when no scene is open or the
## label names no node in it.
static func offer_in_open_scene(object_label: String, reference: String = "") -> String:
	if not Engine.is_editor_hint() or not Engine.has_singleton("EditorInterface"):
		return ""
	return offer_for(find_node(EditorInterface.get_edited_scene_root(), object_label, reference))
