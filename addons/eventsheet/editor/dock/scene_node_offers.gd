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


## The path a Scene-dock node drag carries ({type: "nodes", nodes: [NodePath...]}) for its first node,
## or "" for any other payload. Godot's Scene dock sends each dragged node as a path, never as a node.
static func dragged_path(data: Variant) -> String:
	if not (data is Dictionary):
		return ""
	var payload: Dictionary = data as Dictionary
	if str(payload.get("type", "")) != "nodes":
		return ""
	var nodes: Variant = payload.get("nodes", [])
	if not (nodes is Array) or (nodes as Array).is_empty() or (nodes as Array)[0] is Object:
		return ""
	return str((nodes as Array)[0])


## The node a Scene-dock path names inside `scene_root`, or null. The dock sends the path from the
## tree's root (`/root/.../Level/Player`); the part from the scene root down is what names the node.
static func node_for_dragged_path(scene_root: Node, node_path: String) -> Node:
	if scene_root == null or node_path.is_empty():
		return null
	var relative: String = node_path
	if scene_root.is_inside_tree() and node_path.begins_with(str(scene_root.get_path()) + "/"):
		relative = node_path.trim_prefix(str(scene_root.get_path()) + "/")
	elif node_path.begins_with("/"):
		var marker: String = "/%s/" % scene_root.name
		var at: int = node_path.find(marker)
		if at < 0:
			return scene_root if node_path.ends_with("/" + str(scene_root.name)) else null
		relative = node_path.substr(at + marker.length())
	return scene_root.get_node_or_null(NodePath(relative))


## The object label an Objects-list drag of the node would have carried: the label of the sheet's own
## census entry for that node, else the node's name (a node the sheet has not used yet is an object too,
## and the drop starts using it). With no scene to read the path against, the path's last name.
static func object_label_for_drag(data: Variant, scene_root: Node, sheet: EventSheetResource) -> String:
	var node_path: String = dragged_path(data)
	if node_path.is_empty():
		return ""
	var node: Node = node_for_dragged_path(scene_root, node_path)
	if node == null:
		return node_path.get_file() if scene_root == null else ""
	for entry: Dictionary in EventSheetViewportReadingRows.object_census(sheet):
		if find_node(scene_root, str(entry.get("label", "")), str(entry.get("path", ""))) == node:
			return str(entry.get("label", ""))
	return str(node.name)
