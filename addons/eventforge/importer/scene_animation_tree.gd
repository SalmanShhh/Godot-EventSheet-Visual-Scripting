# EventForge - what an AnimationTree in a scene really holds: its states, its blend spaces, and how
# many dimensions each of those spaces has.
#
# A blend tree is driven by writing values into magic strings - `parameters/Locomotion/blend_position`,
# `parameters/playback` - and a magic string is where the silent failures live. `travel(&"Swng")`
# walks nowhere and says nothing; a Vector2 written into a one-dimensional space is accepted by
# `set()` and blends by its x alone. Neither reports anything at run time, so the answer has to come
# from the tree itself, before the game runs.
#
# READ AS TEXT, like every other scene fact in this plugin. A `.tscn` writes its AnimationTree's root
# as a sub-resource or points at a `.tres`, and both spell their structure in plain lines:
#
#     [sub_resource type="AnimationNodeStateMachine" id="…"]
#     states/Idle/node = SubResource("AnimationNodeAnimation_…")
#     states/Run/node = SubResource("AnimationNodeAnimation_…")
#
#     [resource]                              # an AnimationNodeBlendTree saved as its own file
#     nodes/Locomotion/node = SubResource("AnimationNodeBlendSpace1D_…")
#     nodes/Aim/node = SubResource("AnimationNodeBlend2_…")
#
# So a state is a `states/<name>/node` line, a blend-tree child is a `nodes/<name>/node` line, and
# WHAT each child is comes from the type of the sub-resource it points at. Nothing is instanced, no
# animation is loaded, and a project with no AnimationTree in it pays one class test per node.
#
# NOTHING IS STORED. Every answer is derived from the scene on every ask (held per file stamp for the
# session), so a `.gd` still round-trips byte for byte.
@tool
class_name EventSheetSceneAnimationTree
extends RefCounted

## The node class this reader is about, and the property holding the resource that describes it.
const TREE_CLASS: String = "AnimationTree"
const ROOT_PROPERTY: String = "tree_root"

## The two line shapes a tree resource writes its children under, and the suffix both end in.
const STATE_PREFIX: String = "states/"
const NODE_PREFIX: String = "nodes/"
const CHILD_SUFFIX: String = "/node"

## What a blend node's class says about the field beside it. A SPACE takes a blend position and has a
## number of dimensions; a LAYER takes one amount between two animations. Anything else in a tree is
## neither and is simply not offered.
const SPACE_DIMENSIONS: Dictionary = {
	"AnimationNodeBlendSpace1D": 1,
	"AnimationNodeBlendSpace2D": 2,
}
const LAYER_CLASSES: PackedStringArray = ["AnimationNodeBlend2", "AnimationNodeAdd2",
	"AnimationNodeBlend3", "AnimationNodeAdd3"]

## scene path stamp -> the trees of that scene. Held for the session because the picker, the
## autocomplete and the Doctor ask the same question of the same file.
static var _cache: Dictionary = {}


## The AnimationTrees of the ONE scene this script is attached to, in scene order. Empty when no
## single scene runs the script - a behaviour worn by five levels has no one scene to read.
static func for_script(script_path: String) -> Array[Dictionary]:
	var scene_path: String = EventSheetSceneLightingFacts.attached_scene(script_path)
	return [] as Array[Dictionary] if scene_path.is_empty() else for_scene(scene_path)


## Every AnimationTree of one scene, each as
##   {"name", "path", "scene_path", "reference", "states", "spaces"}
## where `states` is a PackedStringArray of every state name anywhere in the tree and `spaces` an
## Array of {"name", "class", "dimensions"} - `dimensions` being 1 or 2 for a blend space and 0 for a
## layer, which has an amount rather than a position.
##
## A SPACE'S NAME IS ITS PATH INSIDE THE TREE, because that is what the rows write. Godot names a
## parameter after where the node sits: a blend space at the top of the tree is
## `parameters/Locomotion/blend_position`, and one inside a state machine called Machine is
## `parameters/Machine/Aiming/blend_position`. A reader that flattened the tree into bare names would
## offer "Aiming" to a field that writes `parameters/Aiming/blend_position` - a path the tree does not
## have, accepted in silence by `set()` and doing nothing for ever. So a nested space is offered under
## its path, and the row that drops that into its own string is right without changing.
static func for_scene(scene_path: String) -> Array[Dictionary]:
	var stamp: String = EventForgeFileStamp.of(scene_path)
	if _cache.has(stamp):
		return _cache[stamp]
	var trees: Array[Dictionary] = _read_scene(scene_path)
	_cache[stamp] = trees
	return trees


## Drops the read, so the next ask reads the scenes again. Called between fixtures by the tests and
## by the editor's filesystem ping, exactly as the readers beside this one are.
static func clear_cache() -> void:
	_cache.clear()


## Every state name these trees declare, deduplicated, in tree order. What a state field lists and
## what a "does this state exist" question is asked against.
static func state_names(trees: Array[Dictionary]) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for tree: Dictionary in trees:
		for state_name: String in (tree.get("states", PackedStringArray()) as PackedStringArray):
			if not names.has(state_name):
				names.append(state_name)
	return names


## Every blend SPACE name - the nodes that take a blend position - deduplicated, in tree order.
static func space_names(trees: Array[Dictionary]) -> PackedStringArray:
	return _named_where(trees, true)


## Every blend LAYER name - the nodes that take one amount between two animations.
static func layer_names(trees: Array[Dictionary]) -> PackedStringArray:
	return _named_where(trees, false)


## How many dimensions a named blend space has: 1, 2, or 0 when no tree of this scene declares it.
## The answer the "a vector into a one-dimensional space" finding is asked for.
static func dimensions_of(trees: Array[Dictionary], space_name: String) -> int:
	var wanted: String = unquoted(space_name)
	for tree: Dictionary in trees:
		for entry: Variant in (tree.get("spaces", []) as Array):
			var space: Dictionary = entry
			if str(space.get("name", "")) == wanted:
				return int(space.get("dimensions", 0))
	return 0


## The state names these rows travel to that no tree of the scene declares - the silent failure this
## reading exists for, said before the game runs. A value that is not a plain quoted name is a name
## built while the game runs and is never checked.
static func missing_states(trees: Array[Dictionary], used: PackedStringArray) -> PackedStringArray:
	var declared: PackedStringArray = state_names(trees)
	var missing: PackedStringArray = PackedStringArray()
	for value: String in used:
		var bare: String = unquoted(value)
		if bare.is_empty() or not is_a_plain_name(value) or missing.has(bare):
			continue
		if not declared.has(bare):
			missing.append(bare)
	return missing


## How alike two names have to be before one is offered in place of the other. Lower than the bar the
## animation names are held to, and for a reason that is arithmetic rather than taste: likeness is
## counted in letter PAIRS, and a state name is short. "Swng" and "Swing" share two pairs out of
## seven - a plainly right offer that scores 0.57 - where a missing letter in a long animation name
## barely moves the number at all. Below this a name is left alone rather than guessed at.
const NEAREST_ENOUGH: float = 0.5


## The nearest declared state to one that is not declared, for the re-pick offer. Empty when nothing
## is near enough to be worth offering - a wrong suggestion is worse than none.
static func nearest(trees: Array[Dictionary], state_name: String) -> String:
	var wanted: String = unquoted(state_name)
	var best: String = ""
	var best_score: float = 0.0
	for candidate: String in state_names(trees):
		var score: float = wanted.similarity(candidate)
		if score > best_score:
			best_score = score
			best = candidate
	return best if best_score >= NEAREST_ENOUGH else ""


## The name a row wrote, without the quotes or the `&` a StringName carries - the form every question
## here is asked in, so `&"Idle"`, `"Idle"` and `Idle` are one name.
static func unquoted(value: String) -> String:
	var text: String = value.strip_edges().trim_prefix("&")
	if text.length() >= 2 and text.begins_with("\"") and text.ends_with("\""):
		return text.substr(1, text.length() - 2)
	return text


## True when a value is a plain quoted name rather than an expression - the only kind of value a list
## of declared names can honestly be checked against. A bare identifier counts too, because the blend
## rows write their space straight into a path string rather than as a literal of their own.
static func is_a_plain_name(value: String) -> bool:
	var text: String = value.strip_edges().trim_prefix("&")
	if text.length() >= 2 and text.begins_with("\"") and text.ends_with("\""):
		return not text.substr(1, text.length() - 2).contains("\"")
	return text.is_valid_identifier()


# ── the read ────────────────────────────────────────────────────────────────────────────


## Either the spaces or the layers of every tree, deduplicated, in tree order. One walk with one
## question asked of each entry, so the two lists can never be gathered differently.
static func _named_where(trees: Array[Dictionary], want_space: bool) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for tree: Dictionary in trees:
		for entry: Variant in (tree.get("spaces", []) as Array):
			var space: Dictionary = entry
			var is_space: bool = int(space.get("dimensions", 0)) > 0
			var space_name: String = str(space.get("name", ""))
			if is_space == want_space and not space_name.is_empty() and not names.has(space_name):
				names.append(space_name)
	return names


## The walk itself: the scene's AnimationTree nodes, and for each of them the resource its
## `tree_root` points at, followed as far as it goes.
static func _read_scene(scene_path: String) -> Array[Dictionary]:
	var trees: Array[Dictionary] = []
	var nodes: Array = EventSheetSceneConnections.nodes_of_scene(scene_path)
	if nodes.is_empty():
		return trees
	var holders: Array = []
	for entry: Variant in nodes:
		var node: Dictionary = entry
		if str(node.get("type", "")) == TREE_CLASS:
			holders.append(node)
	if holders.is_empty():
		return trees
	var subs: Dictionary = EventSheetSceneConnections.sub_resources_of_scene(scene_path)
	var externals: Dictionary = EventSheetSceneConnections.resource_paths_of_scene(scene_path)
	for entry: Variant in holders:
		var node: Dictionary = entry
		var states: PackedStringArray = PackedStringArray()
		var spaces: Array[Dictionary] = []
		_walk_written(str((node.get("properties", {}) as Dictionary).get(ROOT_PROPERTY, "")),
			subs, externals, states, spaces, 0, "")
		trees.append({
			"name": str(node.get("name", "")),
			"path": str(node.get("path", "")),
			"scene_path": scene_path,
			"reference": "%s|%s" % [scene_path, str(node.get("path", ""))],
			"states": states,
			"spaces": spaces,
		})
	return trees


## How deep a tree is followed. A blend tree inside a state inside a blend tree is ordinary; a
## thousand of them is a file nobody wrote by hand, and a bound is what keeps a malformed one from
## costing the editor a frame.
const MAX_DEPTH: int = 8


## One WRITTEN value - `SubResource("…")` or `ExtResource("…")` - resolved to the resource it names
## and walked. Everything else (a blank, a built-in default) is nothing to follow.
static func _walk_written(written: String, subs: Dictionary, externals: Dictionary,
		states: PackedStringArray, spaces: Array[Dictionary], depth: int, prefix: String) -> void:
	if depth > MAX_DEPTH or written.is_empty():
		return
	var reference: String = _reference_id(written, "SubResource")
	if not reference.is_empty():
		var resource: Dictionary = subs.get(reference, {})
		if not resource.is_empty():
			_walk_resource(resource.get("properties", {}), subs, externals, states, spaces, depth, prefix)
		return
	var external: String = _reference_id(written, "ExtResource")
	if external.is_empty():
		return
	var path: String = str(externals.get(external, ""))
	if path.is_empty() or not FileAccess.file_exists(path):
		return
	var file_subs: Dictionary = _resources_of_file(path)
	var file_externals: Dictionary = EventSheetSceneConnections.resource_paths_of_scene(path)
	var main: Dictionary = file_subs.get("", {})
	if main.is_empty():
		return
	_walk_resource(main.get("properties", {}), file_subs, file_externals, states, spaces, depth + 1, prefix)


## One resolved resource: the children it names, each filed under what its own class makes it.
static func _walk_resource(written: Dictionary, subs: Dictionary, externals: Dictionary,
		states: PackedStringArray, spaces: Array[Dictionary], depth: int, prefix: String) -> void:
	for key: Variant in written.keys():
		var line_key: String = str(key)
		if not line_key.ends_with(CHILD_SUFFIX):
			continue
		var child_name: String = ""
		if line_key.begins_with(STATE_PREFIX):
			child_name = line_key.substr(STATE_PREFIX.length(),
				line_key.length() - STATE_PREFIX.length() - CHILD_SUFFIX.length())
			if not child_name.is_empty() and not states.has(child_name):
				states.append(child_name)
		elif line_key.begins_with(NODE_PREFIX):
			child_name = line_key.substr(NODE_PREFIX.length(),
				line_key.length() - NODE_PREFIX.length() - CHILD_SUFFIX.length())
		if child_name.is_empty():
			continue
		# A STATE IS TRAVELLED TO BY NAME and a space is written to by PATH, so the two are gathered
		# differently on purpose: `travel(&"Idle")` names the state inside its own machine, while
		# `parameters/Machine/Aiming/blend_position` names the whole way down to the space.
		var child_written: String = str(written[key])
		_note_blend_node(prefix + child_name, _class_written(child_written, subs, externals), spaces)
		_walk_written(child_written, subs, externals, states, spaces, depth + 1, prefix + child_name + "/")


## Files the walk has already opened, keyed by stamp: a rig that points four trees at one `.tres`
## reads it once.
static var _file_cache: Dictionary = {}


## The resources one `.tres` holds, as the scene reader's shape - every `[sub_resource]` by its id,
## plus the file's own `[resource]` under the empty id, which is the one the scene points at.
static func _resources_of_file(path: String) -> Dictionary:
	var stamp: String = EventForgeFileStamp.of(path)
	if _file_cache.has(stamp):
		return _file_cache[stamp]
	var lines: PackedStringArray = EventSheetSceneConnections.folded(
		FileAccess.get_file_as_string(path).split("\n"))
	var resources: Dictionary = EventSheetSceneConnections.sub_resources_in(lines)
	var main_type: String = ""
	var main_properties: Dictionary = {}
	var in_main: bool = false
	for line: String in lines:
		if line.begins_with("[gd_resource "):
			main_type = EventSheetSceneConnections.attribute(line, "type")
			continue
		if line.begins_with("[resource]"):
			in_main = true
			continue
		if line.begins_with("["):
			in_main = false
			continue
		if not in_main:
			continue
		var split: int = line.find(" = ")
		if split > 0:
			main_properties[line.substr(0, split)] = line.substr(split + 3)
	resources[""] = {"type": main_type, "properties": main_properties}
	_file_cache[stamp] = resources
	return resources


## The class a written reference points at, or "" when it points at nothing this reader can see. A
## sub-resource says its own type; an external file says it in its `[gd_resource]` header.
static func _class_written(written: String, subs: Dictionary, externals: Dictionary) -> String:
	var reference: String = _reference_id(written, "SubResource")
	if not reference.is_empty():
		return str((subs.get(reference, {}) as Dictionary).get("type", ""))
	var external: String = _reference_id(written, "ExtResource")
	if external.is_empty():
		return ""
	var path: String = str(externals.get(external, ""))
	if path.is_empty() or not FileAccess.file_exists(path):
		return ""
	return str((_resources_of_file(path).get("", {}) as Dictionary).get("type", ""))


## One child of a blend tree, filed under what its class makes it: a space with a number of
## dimensions, a layer with an amount, or nothing at all.
static func _note_blend_node(child_name: String, class_text: String,
		spaces: Array[Dictionary]) -> void:
	var dimensions: int = int(SPACE_DIMENSIONS.get(class_text, 0))
	if dimensions == 0 and not LAYER_CLASSES.has(class_text):
		return
	for entry: Variant in spaces:
		if str((entry as Dictionary).get("name", "")) == child_name:
			return
	spaces.append({"name": child_name, "class": class_text, "dimensions": dimensions})


## The id inside `SubResource("…")` / `ExtResource("…")`, or "" when the value is not one of those.
static func _reference_id(written: String, keyword: String) -> String:
	var opening: String = "%s(\"" % keyword
	var start: int = written.find(opening)
	if start < 0:
		return ""
	start += opening.length()
	var end: int = written.find("\"", start)
	return written.substr(start, end - start) if end > start else ""
