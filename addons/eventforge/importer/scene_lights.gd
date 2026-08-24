# Godot EventSheets - what the SCENE says about the lights a sheet can address (L1/L2/L7).
#
# A light row names a node, and the only place that says what kind of node it is - and therefore
# which property the row really writes - is the `.tscn`. So this is a reader, in the same shape as
# the replication reader beside it: the scene file is parsed through EventSheetSceneConnections (the
# project's one reader of scene text), nothing is ever copied into the sheet, and every fact is
# derived on every ask. A sheet no scene uses simply has no lights, and its rows fall back to the
# spellings a reader can verify for themselves.
#
# Three questions are answered here and nowhere else:
#   - WHICH LIGHTS a sheet can point at, for the picker's "Lights in this scene" shelf and for the
#     scene facts on the head;
#   - WHAT CLASS one node reference is, which is the gate the lift guard asks before it claims that
#     `$Torch.energy = 1.2` is a light row rather than somebody's own `energy` variable;
#   - WHICH NODES OF A CLASS a scene carries, which is how the two lighting nodes that are NOT
#     lights are found - the CanvasModulate a layer's darkness sits on, the WorldEnvironment the
#     atmosphere rows write through, and the occluders that decide whether a shadow is ever drawn.
#
# PURE + STATIC: a script path in, plain Dictionaries out. No dock, no canvas, no editor.
@tool
class_name EventSheetSceneLights
extends RefCounted

## The scene property each dimension keeps its "which layers do I light" answer in. Read as the raw
## text the file holds, because that is what a reader compares against an occluder's own mask.
const MASK_PROPERTY_2D: String = "range_item_cull_mask"
const MASK_PROPERTY_3D: String = "light_cull_mask"

## L4. The OTHER 2D mask, and the one shadows are actually decided by: Godot matches a light's
## `shadow_item_cull_mask` against a `LightOccluder2D.occluder_light_mask`, while the range mask
## above only says which items the light LIGHTS. Two questions, two properties, and confusing them
## is how "I turned shadows on and nothing happened" happens.
const SHADOW_MASK_PROPERTY_2D: String = "shadow_item_cull_mask"

## The property that says a light casts shadows, in both dimensions.
const SHADOW_PROPERTY: String = "shadow_enabled"

## L4. What blocks a 2D light, and the property holding which lights it blocks.
const OCCLUDER_CLASS: String = "LightOccluder2D"
const OCCLUDER_MASK_PROPERTY: String = "occluder_light_mask"

## The mask both sides fall back to when the scene file never wrote one - Godot's own default for
## every one of these four properties. A file only stores a property it changed, so an absent line
## means "1", never "nothing".
const DEFAULT_MASK: int = 1

## script path -> {"nodes": Array, "lights": Array, "classes": Dictionary}. Session-lifetime for the
## same reason the replication reader caches: the picker and the lift ask per row and per line, and a
## scene does not change under a running editor often enough to justify re-reading a project
## directory each time.
static var _cache: Dictionary = {}

## The node-path matcher, compiled once: the lift guard asks it of every candidate line of every
## opened file, and recompiling a pattern per line was the whole cost of the hand-written matchers.
static var _path_regex: RegEx = null


## Every light in every scene that runs this script, in scene order. One entry each:
##   {"name", "path", "class", "kind", "shadows", "masks", "shadow_masks", "reference",
##    "scene_path", "properties"}
## `kind` is the plain word for the class (point / directional / omni / spot), `reference` the
## spelling a row addresses it by (`$Torch`), `masks` the raw text of the range cull mask the file
## holds and `shadow_masks` the same for the shadow one - "" when the node never set one, which
## means the engine's default.
static func for_script(script_path: String) -> Array[Dictionary]:
	return _read(script_path)["lights"]


## L4/L6. EVERY node of those scenes in scene order, light or not, as
##   {"name", "path", "class", "reference", "scene_path", "properties"}
## `properties` is the raw text the scene file holds under the node's header, which is what a fact
## about one node is read from (an occluder's mask, the environment resource a WorldEnvironment
## points at). The lights above are these entries with the light facts worked out.
static func nodes_for_script(script_path: String) -> Array[Dictionary]:
	return _read(script_path)["nodes"]


## Those of them that ARE one class, subclasses included - the scene's CanvasModulate, its
## WorldEnvironment, its occluders. Empty for a class no scene of this script carries, which is what
## makes a fact about a missing node absent rather than wrong.
static func nodes_of_class(script_path: String, class_text: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	if not ClassDB.class_exists(class_text):
		return found
	for node: Dictionary in nodes_for_script(script_path):
		var node_class: String = str(node["class"])
		if ClassDB.class_exists(node_class) and ClassDB.is_parent_class(node_class, class_text):
			found.append(node)
	return found


## Every node of those scenes as `reference -> class`, under each spelling a row can name it by: the
## bare name, the path, and the `$` and `%` forms of both. EVERY node, not only the lights - knowing
## that `$Door` is a StaticBody2D is what lets the lift refuse a line rather than guess about it.
static func classes_for_script(script_path: String) -> Dictionary:
	return _read(script_path)["classes"]


## The class one node reference names, or "" when this script's scenes have no such node. `text` is
## a node reference as rows spell them: `$Torch`, `%Torch`, `get_node("Torch")`, `Room/Torch`, or the
## bare name. Never a guess: a name the scenes do not carry is "" and the caller must degrade.
static func class_of_reference(script_path: String, text: String) -> String:
	var wanted: String = reference_key(text)
	if wanted.is_empty():
		return ""
	return str(classes_for_script(script_path).get(wanted, ""))


## One node reference reduced to the key the map above is built under: sigils off, a `get_node()`
## call unwrapped, quotes dropped. "" for anything that is not a plain node reference (an
## expression, a call chain, a subscript) - which is exactly the text no light row may claim.
static func reference_key(text: String) -> String:
	var trimmed: String = text.strip_edges()
	if trimmed.begins_with("get_node(") and trimmed.ends_with(")"):
		trimmed = trimmed.substr(9, trimmed.length() - 10).strip_edges()
	elif trimmed.begins_with("$") or trimmed.begins_with("%"):
		trimmed = trimmed.substr(1)
	if trimmed.length() >= 2 and trimmed.begins_with("\"") and trimmed.ends_with("\""):
		trimmed = trimmed.substr(1, trimmed.length() - 2)
	return trimmed if _node_path_regex().search(trimmed) != null else ""


## Drops the cache. The editor calls this when the filesystem changes; tests call it between
## fixtures.
static func clear_cache() -> void:
	_cache.clear()


## A plain node path and nothing else: one or more identifiers separated by slashes.
static func _node_path_regex() -> RegEx:
	if _path_regex == null:
		_path_regex = RegEx.create_from_string("^[A-Za-z_][A-Za-z0-9_]*(?:/[A-Za-z_][A-Za-z0-9_]*)*$")
	return _path_regex


## Every answer for one script, read once. A path that is not a res:// script has none of them.
static func _read(script_path: String) -> Dictionary:
	var path: String = script_path.strip_edges()
	if path.is_empty() or not path.begins_with("res://"):
		return {"nodes": [] as Array[Dictionary], "lights": [] as Array[Dictionary], "classes": {}}
	if _cache.has(path):
		return _cache[path]
	var nodes: Array[Dictionary] = []
	var lights: Array[Dictionary] = []
	var classes: Dictionary = {}
	var host: String = str(EventSheetSceneReplication.host_node(path).get("node_path", "."))
	for scene_path: String in EventSheetSceneReplication.scenes_using(path):
		for entry: Variant in EventSheetSceneConnections.nodes_of_scene(scene_path):
			var node: Dictionary = entry
			var node_class: String = str(node.get("type", ""))
			if node_class.is_empty():
				continue
			var found: Dictionary = _node_entry(node, node_class,
				_reference_of(str(node.get("path", "")), host), scene_path)
			nodes.append(found)
			_note_spellings(classes, str(node.get("name", "")), str(node.get("path", "")), node_class)
			if EventForgeLightWords.is_light_class(node_class):
				lights.append(_light_facts(found))
	var answer: Dictionary = {"nodes": nodes, "lights": lights, "classes": classes}
	_cache[path] = answer
	return answer


## One node of a scene, whatever it is: what it is called, where it is, what class it is, the
## spelling a row addresses it by, and the raw property text the file holds for it.
static func _node_entry(node: Dictionary, node_class: String, reference: String, scene_path: String) -> Dictionary:
	return {
		"name": str(node.get("name", "")),
		"path": str(node.get("path", "")),
		"class": node_class,
		"reference": reference,
		"scene_path": scene_path,
		"properties": node.get("properties", {})
	}


## The same entry with the LIGHT facts worked out - the plain kind word, whether it casts shadows,
## and the two masks that decide what it reaches and what can block it.
static func _light_facts(node: Dictionary) -> Dictionary:
	var node_class: String = str(node["class"])
	var properties: Dictionary = node["properties"]
	var in_3d: bool = ClassDB.is_parent_class(node_class, EventForgeLightWords.ROOT_3D)
	var found: Dictionary = node.duplicate()
	found["kind"] = EventForgeLightWords.kind_word(node_class)
	found["shadows"] = str(properties.get(SHADOW_PROPERTY, "false")).strip_edges() == "true"
	found["masks"] = str(properties.get(MASK_PROPERTY_3D if in_3d else MASK_PROPERTY_2D, "")).strip_edges()
	found["shadow_masks"] = "" if in_3d else str(properties.get(SHADOW_MASK_PROPERTY_2D, "")).strip_edges()
	return found


## The bits a mask property holds, with the engine's own default standing in for a property the
## scene file never wrote. Two masks OVERLAP when they share a bit, which is the whole of Godot's
## "does this occluder block that light" rule.
static func mask_bits(mask_text: String) -> int:
	var text: String = mask_text.strip_edges()
	return DEFAULT_MASK if text.is_empty() or not text.is_valid_int() else text.to_int()


## True when two masks share a layer - what Godot asks of a light's shadow mask and an occluder's
## own mask before it draws a shadow at all.
static func masks_overlap(one: String, other: String) -> bool:
	return (mask_bits(one) & mask_bits(other)) != 0


## Every spelling one node answers to, pointed at its class: the bare name, the scene path, and both
## sigil forms of each. A row may write any of them and mean the same node.
static func _note_spellings(classes: Dictionary, node_name: String, node_path: String, node_class: String) -> void:
	for spelling: String in [node_name, node_path]:
		if not spelling.is_empty():
			classes[spelling] = node_class


## How a row addresses one node from the script's own node: `$Torch` for a child, `self` for the
## node the script is on. A node OUTSIDE the script's own branch keeps its scene path, which is what
## the file holds and what the reader can check.
static func _reference_of(node_path: String, host_path: String) -> String:
	if node_path == host_path or node_path == ".":
		return "self"
	var below: String = "%s/" % host_path
	if host_path != "." and node_path.begins_with(below):
		return "$%s" % node_path.substr(below.length())
	return "$%s" % node_path
