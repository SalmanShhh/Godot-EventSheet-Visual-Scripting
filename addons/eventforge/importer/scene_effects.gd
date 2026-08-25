# Godot EventSheets - what the SCENE says about the effects a sheet can turn.
#
# A dial row names a node and a dial on it. Which dials that node HAS is a chain of three files, and
# not one link of it is in the script: the `.tscn` says which material the node wears, the material
# says which shader it runs, and the shader declares the dials. So the chain is walked here, once,
# and every answer downstream - the picked vocabulary, the lift's guard, the health checks - comes
# from this one walk.
#
# THE CHAIN, and where it stops. A material is either a FILE the node points at (`ExtResource`) or a
# copy the scene keeps inside itself (`SubResource`), and both are followed. A shader written inline
# in the scene, or a material saved in Godot's binary format, ends the chain with no shader path -
# and a node whose chain ends early simply has no dials, which is exactly the case the free-string
# rows already shipped for. Nothing here ever guesses at a name.
#
# ONE PROPERTY: `material`, the CanvasItem member every shipped effect row spells. A 3D node wears
# its shader on `material_override` and would need rows that spell THAT, so it is left out rather
# than answered with a line that would not run.
#
# PURE + STATIC: a script path in, plain Dictionaries out. No dock, no canvas, no editor. Cached for
# the session like the readers beside it, because the picker asks per keystroke and the lift per line.
@tool
class_name EventSheetSceneEffects
extends RefCounted

## The node member a shader material is worn on, and the row every effect verb writes through.
const MATERIAL_PROPERTY: String = "material"

## The material member that names the shader, and the class a material has to be for a dial row to
## mean anything: a CanvasItemMaterial has no shader and therefore no dials.
const SHADER_PROPERTY: String = "shader"
const SHADER_MATERIAL_CLASS: String = "ShaderMaterial"

## script path -> the wearing nodes of its scenes. Session-lifetime, shared by every asker.
static var _cache: Dictionary = {}

## "scene path|host node" -> the wearing nodes of that one scene. The host is part of the key because
## it is the node the `reference` spellings are written from, and nothing else about a scene depends
## on it. Keyed the same way the lighting reader keys its scenes, for the same reason.
static var _scenes: Dictionary = {}

## material resource path -> the shader it runs. A `.tres` is read once however many nodes wear it.
static var _shaders: Dictionary = {}


## Every node of every scene that runs this script that WEARS A MATERIAL, in scene order. One entry
## each:
##   {"name", "path", "class", "reference", "scene_path", "material", "material_path",
##    "shader_path", "dials"}
## `material` is the raw text the scene file holds, `material_path` the `.tres` behind it ("" for a
## material the scene keeps inside itself), `shader_path` the `.gdshader` at the end of the chain
## ("" when the chain cannot be followed) and `dials` that shader's uniforms.
static func for_script(script_path: String) -> Array[Dictionary]:
	var path: String = script_path.strip_edges()
	if path.is_empty() or not path.begins_with("res://"):
		return [] as Array[Dictionary]
	if _cache.has(path):
		return _cache[path]
	var wearing: Array[Dictionary] = []
	var host: String = str(EventSheetSceneReplication.host_node(path).get("node_path", "."))
	for scene_path: String in EventSheetSceneReplication.scenes_using(path):
		wearing.append_array(for_scene(scene_path, host))
	_cache[path] = wearing
	return wearing


## The same question asked of ONE SCENE - what the health checks walk, since a scene whose rows point
## at a dial nobody declares is broken whether or not a sheet has been opened on it. `host_path` is
## the node the `reference` spellings are written from: the script's own node when a sheet asked, and
## the scene root when nothing did.
static func for_scene(scene_path: String, host_path: String = ".") -> Array[Dictionary]:
	var key: String = "%s|%s" % [scene_path, host_path]
	if _scenes.has(key):
		return _scenes[key]
	var wearing: Array[Dictionary] = []
	var lines: PackedStringArray = FileAccess.get_file_as_string(scene_path).split("\n")
	var files: Dictionary = EventSheetSceneConnections.resource_paths_in(lines)
	var inside: Dictionary = EventSheetSceneConnections.sub_resources_in(lines)
	for entry: Variant in EventSheetSceneConnections.nodes_of_scene(scene_path):
		var node: Dictionary = entry
		var held: String = str((node.get("properties", {}) as Dictionary).get(MATERIAL_PROPERTY, ""))
		if held.is_empty():
			continue
		wearing.append(_wearer(node, held, scene_path, host_path, files, inside))
	_scenes[key] = wearing
	return wearing


## The wearing nodes of a script's scenes under the KEYS a row's own spelling reduces to - the bare
## name, the scene path, and `self` for the node the script is on. The map the lift's guard asks: a
## `$Sprite.material.set_shader_parameter(…)` line is only a dial row when this map has `Sprite` in
## it and its shader declares the dial. Reduce a spelling with `EventSheetSceneLights.reference_key`,
## which is the one place `$`, `%` and `get_node("…")` are taken off.
static func wearers_of_script(script_path: String) -> Dictionary:
	var wearers: Dictionary = {}
	for node: Dictionary in for_script(script_path):
		for spelling: String in [str(node["name"]), str(node["path"])]:
			if not spelling.is_empty():
				wearers[spelling] = node
		if str(node["reference"]) == EventSheetSceneLights.SELF_REFERENCE:
			wearers[EventSheetSceneLights.SELF_REFERENCE] = node
	return wearers


## The shader one node reference runs, or "" when the sheet cannot say. The chain in one call, for
## the guard and for the picker's entry per dial.
static func shader_of(script_path: String, reference: String) -> String:
	var found: Dictionary = wearers_of_script(script_path).get(
		EventSheetSceneLights.reference_key(reference), {})
	return str(found.get("shader_path", ""))


## Drops every cache. The editor calls this when the filesystem changes; tests call it between
## fixtures, exactly as the readers beside this one do.
static func clear_cache() -> void:
	_cache.clear()
	_scenes.clear()
	_shaders.clear()


## One wearing node, with the chain already followed: what it is called, where it is, how a row
## addresses it, the material text the file holds, and the shader and dials at the end of it.
static func _wearer(node: Dictionary, held: String, scene_path: String, host_path: String,
		files: Dictionary, inside: Dictionary) -> Dictionary:
	var material_path: String = str(files.get(_resource_id(held), "")) \
		if held.begins_with("ExtResource(") else ""
	var shader_path: String = _shader_of_material(held, material_path, files, inside)
	return {
		"name": str(node.get("name", "")),
		"path": str(node.get("path", "")),
		"class": str(node.get("type", "")),
		"reference": EventSheetSceneLights.reference_of(str(node.get("path", "")), host_path),
		"scene_path": scene_path,
		"material": held,
		"material_path": material_path,
		"shader_path": shader_path,
		"dials": EventForgeShaderUniforms.for_shader(shader_path)
	}


## The shader behind one material, whichever of the two shapes it is: a resource the scene keeps
## inside itself names its shader through the scene's own file table, and a `.tres` on disk through
## its own. "" for a chain that cannot be followed to a `.gdshader`, which is the honest answer and
## the one that leaves the free-string rows in charge.
static func _shader_of_material(held: String, material_path: String, files: Dictionary,
		inside: Dictionary) -> String:
	if held.begins_with("SubResource("):
		var resource: Dictionary = inside.get(_resource_id(held), {})
		if str(resource.get("type", "")) != SHADER_MATERIAL_CLASS:
			return ""
		var names: String = str((resource.get("properties", {}) as Dictionary).get(SHADER_PROPERTY, ""))
		return str(files.get(_resource_id(names), "")) if names.begins_with("ExtResource(") else ""
	return _shader_of_file(material_path)


## The shader a material FILE runs, read once per file. A `.tres` is written in the same text format
## a scene is, so the file table is read with the scene reader's own parser rather than a second one;
## a material saved in Godot's binary format has no lines to read and ends the chain.
static func _shader_of_file(material_path: String) -> String:
	if material_path.is_empty():
		return ""
	if _shaders.has(material_path):
		return _shaders[material_path]
	var found: String = ""
	var lines: PackedStringArray = FileAccess.get_file_as_string(material_path).split("\n")
	var files: Dictionary = EventSheetSceneConnections.resource_paths_in(lines)
	for line: String in lines:
		if not line.begins_with(SHADER_PROPERTY + " = ExtResource("):
			continue
		found = str(files.get(_resource_id(line.substr(line.find("=") + 1).strip_edges()), ""))
		break
	_shaders[material_path] = found
	return found


## The id inside an `ExtResource("2_mat")` / `SubResource("3_x")` reference - the quoted text and
## nothing else.
static func _resource_id(text: String) -> String:
	return text.get_slice("\"", 1)
