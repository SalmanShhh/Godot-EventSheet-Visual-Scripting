# Godot EventSheets - the cards of a saved scene that point at a node or a file that is not there.
#
# A juice card keeps the way to a node as a path written from its player, and a file as the text of its
# uid. Move a node out of the scene, delete a sound, and the card goes on holding a path or an address
# that finds nothing: it does nothing when the game runs and says so only then. This finds it before.
#
# The evidence is the scene's own saved bytes, read without instancing anything: a packed scene answers
# the nodes it was saved with and what each of them holds, which is exactly what the Inspector shows. A
# path that leads into a scene instanced inside this one, or out of this one, cannot be judged from here
# and is left alone, so a finding is always about something the scene itself can prove.
#
# Pure and static, so every word is pinned headless. Loaded by path from the Doctor section, so the first
# open of the editor does not compile it.
@tool
extends RefCounted

## The one file that knows both shapes of the pack's node, so a node of a saved scene is recognised as a
## Juice Player without this file naming the pack's class.
const NAMES_PATH: String = "res://addons/eventsheet/editor/inspector/juice_player_names.gd"

## The property a player keeps its list in, and the keys a card names itself and its files with.
const STEPS_PROPERTY: String = "steps"
const LABEL_KEY: String = "label"
const WORD_KEY: String = "verb"
const FILE_KEYS: PackedStringArray = ["stream", "scene", "card_script"]

const KIND_NODE: String = "node"
const KIND_FILE: String = "file"


## Every card of a saved scene that points at a node the scene does not have, or at a file the project does
## not have. Each entry is {subject (the card's label), player, kind, key, target, message}. A scene that
## holds no Juice Player, or no card that points anywhere missing, answers an empty list.
static func missing_targets_in_scene(scene_path: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	if scene_path.strip_edges().is_empty() or not ResourceLoader.exists(scene_path):
		return found
	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		return found
	var state: SceneState = packed.get_state()
	# A scene that inherits another lists only what it adds, so a node it does not list proves nothing.
	var inherits: bool = state.get_base_scene_state() != null
	var nodes: Dictionary = {}
	var instanced: PackedStringArray = PackedStringArray()
	for node_index: int in range(state.get_node_count()):
		var path_text: String = _path_text(state.get_node_path(node_index))
		nodes[path_text] = true
		if state.get_node_instance(node_index) != null:
			instanced.append(path_text)
	for node_index: int in range(state.get_node_count()):
		var carried: Variant = null
		var is_player: bool = false
		for property_index: int in range(state.get_node_property_count(node_index)):
			var property: String = str(state.get_node_property_name(node_index, property_index))
			var value: Variant = state.get_node_property_value(node_index, property_index)
			if property == "script" and value is Script:
				is_player = bool(load(NAMES_PATH).is_player_script(value as Script))
			elif property == STEPS_PROPERTY and value is Array:
				carried = value
		if not is_player or not (carried is Array):
			continue
		var player_path: String = _path_text(state.get_node_path(node_index))
		var player_name: String = str(state.get_node_name(node_index))
		for entry: Variant in carried as Array:
			if entry is Dictionary:
				_check_card(entry as Dictionary, player_path, player_name, {} if inherits else nodes, instanced, found, inherits)
	return found


## The names of the Juice Players a saved scene holds, in scene order. Read the same way, without instancing.
static func players_in_scene(scene_path: String) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	if scene_path.strip_edges().is_empty() or not ResourceLoader.exists(scene_path):
		return names
	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		return names
	var state: SceneState = packed.get_state()
	for node_index: int in range(state.get_node_count()):
		for property_index: int in range(state.get_node_property_count(node_index)):
			if str(state.get_node_property_name(node_index, property_index)) != "script":
				continue
			var value: Variant = state.get_node_property_value(node_index, property_index)
			if value is Script and bool(load(NAMES_PATH).is_player_script(value as Script)):
				names.append(str(state.get_node_name(node_index)))
	return names


## What one card points at that is not there.
static func _check_card(card: Dictionary, player_path: String, player_name: String, nodes: Dictionary,
		instanced: PackedStringArray, found: Array[Dictionary], nodes_unknown: bool = false) -> void:
	var label: String = str(card.get(LABEL_KEY, "")).strip_edges()
	if label.is_empty():
		label = str(card.get(WORD_KEY, "")).strip_edges()
	for key: Variant in card:
		var value: Variant = card[key]
		if value is NodePath and not (value as NodePath).is_empty():
			var reached: String = _resolve(player_path, value as NodePath)
			if nodes_unknown or reached.is_empty() or nodes.has(reached) or _inside_instance(reached, instanced):
				continue
			found.append(_entry(label, player_name, KIND_NODE, str(key), str(value),
				"the card \"%s\" on %s points at %s, which is not in this scene. Pick the node again." % [label, player_name, str(value)]))
		elif FILE_KEYS.has(str(key)) and value is String and not str(value).strip_edges().is_empty():
			if not ResourceLoader.exists(str(value)):
				found.append(_entry(label, player_name, KIND_FILE, str(key), str(value),
					"the card \"%s\" on %s names a file that is not in the project (%s). Pick the file again." % [label, player_name, str(value)]))


static func _entry(label: String, player_name: String, kind: String, key: String, target: String, message: String) -> Dictionary:
	return {"subject": label, "player": player_name, "kind": kind, "key": key, "target": target, "message": message}


## A node's path from the scene's root as the text the scene keeps it under: "." for the root itself.
static func _path_text(path: NodePath) -> String:
	var text: String = str(path)
	return "." if text.is_empty() else text


## Where a path written from a player lands, as a path from the scene's root, or "" when it cannot be said:
## an absolute path, a path that leaves the scene, or a path with a property after it.
static func _resolve(player_path: String, written: NodePath) -> String:
	if written.is_absolute() or written.get_subname_count() > 0:
		return ""
	var names: PackedStringArray = PackedStringArray() if player_path == "." else player_path.split("/")
	for index: int in range(written.get_name_count()):
		var step: String = str(written.get_name(index))
		if step == "..":
			if names.is_empty():
				return ""
			names.remove_at(names.size() - 1)
		elif step != ".":
			names.append(step)
	return "." if names.is_empty() else "/".join(names)


## Whether a path goes through a scene instanced inside this one, whose own nodes this scene does not list.
static func _inside_instance(reached: String, instanced: PackedStringArray) -> bool:
	for prefix: String in instanced:
		if prefix != "." and reached.begins_with(prefix + "/"):
			return true
	return false
