# Godot EventSheets - which Juice Player plays a Juice list that is opened on its own (editor-only, loaded by path).
#
# A Juice list is a file, and a file has nothing to play on. Opened from the FileSystem dock it is shown with
# no player under it, so the editor looks in the scene being edited for the Juice Players whose Moment File
# slot holds this very file, and plays the list on one of them. With one such player it is simply the host;
# with several, the Inspector offers a small "Play on" choice (remembered for the session only, never in the
# file or the scene); with none, the Inspector says how to get one.
#
# Everything that walks a scene takes the root it walks, so the suite pins the answers on a tree it built.
# The few functions that ask the live editor (the open scene, what the Inspector shows, what is selected) are
# the thin ones at the bottom.
#
# NOTHING HERE IS SAVED. The remembered choice is a static dictionary that dies with the editor session.
#
# No class_name on purpose: Create Node lists every named class, and an editor-only helper has no business there.
@tool
extends RefCounted

## The file that says which scripts are a Juice Player. By path, like the other editor-only files.
const NAMES_PATH: String = "res://addons/eventsheet/editor/inspector/juice_player_names.gd"

## How long a walk of the open scene is trusted for. A card list asks once per node field, and a scene of
## thousands of nodes should not be walked for each one.
const TRUST_MSEC: int = 400

## The player the designer chose to play each file on, for this session: file key -> the player's path from the
## scene root, as text. Never written anywhere.
static var _chosen: Dictionary = {}

## The last walk of the open scene: {list, root, at, users}.
static var _walked: Dictionary = {}


## The Juice Players under `root` (the root included) whose Moment File slot holds `list`, in tree order.
static func players_in(root: Node, list: Object) -> Array[Node]:
	var found: Array[Node] = []
	if root == null or list == null:
		return found
	var names: GDScript = load(NAMES_PATH)
	var pending: Array[Node] = [root]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if holds(node, list, names):
			found.append(node)
		# Pushed last-first so the walk comes out in the order the Scene dock shows the nodes.
		var children: Array[Node] = node.get_children()
		for index: int in range(children.size() - 1, -1, -1):
			pending.append(children[index])
	return found


## Whether one node is a Juice Player holding `list` in its Moment File slot.
static func holds(node: Node, list: Object, names: GDScript = null) -> bool:
	if node == null or node.get_script() == null:
		return false
	if node.get("moment_file") != list:
		return false
	return bool((names if names != null else load(NAMES_PATH)).call("is_player", node))


## Which of `users` plays `list`, with nothing but the answer's inputs: a selected holder wins while the list is
## shown inside that player's slot (`on_its_own` false), else the remembered choice, else the first in tree order.
static func pick_host(list: Object, users: Array, selected: Array, on_its_own: bool, root: Node) -> Node:
	if list == null:
		return null
	if not on_its_own:
		for node: Variant in selected:
			if node is Node and holds(node as Node, list):
				return node as Node
	if users.is_empty():
		return null
	var remembered: String = str(_chosen.get(key_of(list), ""))
	if not remembered.is_empty():
		for user: Variant in users:
			if label_of(root, user as Node) == remembered:
				return user as Node
	return users[0] as Node


## The words that name a player in the "Play on" choice and in a note: its path from the scene root, or its own
## name when it is the root.
static func label_of(root: Node, node: Node) -> String:
	if node == null:
		return ""
	if root == null or node == root or not root.is_ancestor_of(node):
		return str(node.name)
	return str(root.get_path_to(node))


## What a file is remembered by: its path, or its instance for a list that has not been saved yet.
static func key_of(list: Object) -> String:
	var path: String = str((list as Resource).resource_path) if list is Resource else ""
	return path if not path.is_empty() else str(list.get_instance_id())


## Remembers which player to play `list` on, for this session.
static func remember(list: Object, root: Node, node: Node) -> void:
	if list != null and node != null:
		_chosen[key_of(list)] = label_of(root, node)


## Forgets what the last walk of the open scene found, so the next question walks it again.
static func forget_walk() -> void:
	_walked = {}


## Forgets what the last walk found and what was chosen. For the suite, and for a new editor session.
static func forget() -> void:
	_chosen = {}
	_walked = {}


## The sentence under a node field of a shared list when the path it holds finds no node from a DIFFERENT player
## that holds the same file, or an empty text when every one finds it. Names each such player. A note only: the
## path is never rewritten.
static func unresolved_note(users: Array, host: Node, root: Node, stored: Variant) -> String:
	var path: NodePath = stored if stored is NodePath else NodePath(str(stored))
	if path.is_empty():
		return ""
	var lost: PackedStringArray = PackedStringArray()
	for user: Variant in users:
		var player: Node = user as Node
		if player == null or player == host or not is_instance_valid(player):
			continue
		if player.get_node_or_null(path) == null:
			lost.append(label_of(root, player))
	if lost.is_empty():
		return ""
	if lost.size() == 1:
		return EventSheetL10n.translate("%s also plays this file and does not find this node from where it stands.") % lost[0]
	return EventSheetL10n.translate("%s also play this file and do not find this node from where they stand.") % ", ".join(lost)


# ── The live editor ─────────────────────────────────────────────────────────────────────────────


## The root of the scene being edited, or null (also outside the editor).
static func scene_root() -> Node:
	return EditorInterface.get_edited_scene_root() if Engine.is_editor_hint() else null


## Whether the Inspector shows `list` itself, as opposed to showing it inside a player's slot.
static func on_its_own(list: Object) -> bool:
	if not Engine.is_editor_hint() or EditorInterface.get_inspector() == null:
		return false
	return EditorInterface.get_inspector().get_edited_object() == list


## Every Juice Player of the open scene that holds `list`, in tree order. The walk is trusted for a moment so a
## card list full of node fields asks the scene once.
static func users_of(list: Object) -> Array[Node]:
	var root: Node = scene_root()
	var now: int = Time.get_ticks_msec()
	if _walked.get("list") == list and _walked.get("root") == root and now - int(_walked.get("at", 0)) < TRUST_MSEC \
			and not (_walked.get("users") as Array).any(func(node: Variant) -> bool: return not is_instance_valid(node)):
		return _walked.get("users") as Array[Node]
	var users: Array[Node] = players_in(root, list)
	_walked = {"list": list, "root": root, "at": now, "users": users}
	return users


## The player a list is played on right now, or null.
static func find_host(list: Object) -> Node:
	if not (list is Resource) or not Engine.is_editor_hint():
		return null
	return pick_host(list, users_of(list), EditorInterface.get_selection().get_selected_nodes(), on_its_own(list), scene_root())


## The players that could host `list` when the choice is the designer's: more than one, and only while the list
## is opened on its own. Otherwise empty.
static func choices_for(list: Object) -> Array[Node]:
	var none: Array[Node] = []
	if not (list is Resource) or not on_its_own(list):
		return none
	var users: Array[Node] = users_of(list)
	return users if users.size() > 1 else none
