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

## The member one material hands the drawing on to. A node wearing an outline over a dissolve is two
## materials chained through this, drawn in the order the chain runs - and a chain in the WRONG order
## looks identical in the Inspector, which is why the head says it.
const NEXT_PASS_PROPERTY: String = "next_pass"

## How far a `next_pass` chain is followed. Godot allows one material to point at itself, and a file
## somebody hand-edited can loop; a bound is cheaper than remembering what has been seen, and no real
## chain is anywhere near this long.
const MAX_PASSES: int = 8

## How a material writes down a dial it has moved off the shader's own default.
const PARAMETER_PREFIX: String = "shader_parameter/"

## script path -> the wearing nodes of its scenes. Session-lifetime, shared by every asker.
static var _cache: Dictionary = {}

## "scene path|host node" -> the wearing nodes of that one scene. The host is part of the key because
## it is the node the `reference` spellings are written from, and nothing else about a scene depends
## on it. Keyed the same way the lighting reader keys its scenes, for the same reason.
static var _scenes: Dictionary = {}

## material resource path -> {"shader", "next_pass"}. A `.tres` is read once however many nodes wear
## it, and once for however many questions are asked about it.
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
	return str(wearer_of(script_path, reference).get("shader_path", ""))


## The wearing node one row is aimed at, or {} when the sheet cannot say which node that is. A BLANK
## "On node" means the node the sheet itself is on, which is what a blank means on every row of this
## vocabulary - so it is answered here rather than at each of the four places that ask.
static func wearer_of(script_path: String, reference: String) -> Dictionary:
	return wearers_of_script(script_path).get(reference_key_of(reference), {})


## One "On node" value reduced to the key the wearers map is filed under. The one place a blank
## receiver becomes `self`, so the dialog's field, the health checks and the lift's guard cannot
## disagree about which node an unanswered row is about.
static func reference_key_of(written: String) -> String:
	var trimmed: String = written.strip_edges()
	return EventSheetSceneLights.SELF_REFERENCE if trimmed.is_empty() \
		else EventSheetSceneLights.reference_key(trimmed)


## The DECLARATION behind one row's dial - the uniform its node's shader really publishes, with the
## type, the hints and the default that decide how it is edited. {} when any link of the chain is
## missing (no scene, no material, no shader, or a name the shader does not declare), which is the
## answer that leaves the ordinary value field in charge.
static func dial_declaration(script_path: String, reference: String, dial_name: String) -> Dictionary:
	var shader_path: String = shader_of(script_path, reference)
	return {} if shader_path.is_empty() else EventForgeShaderUniforms.find(shader_path, dial_name)


## Drops every cache. The editor calls this when the filesystem changes; tests call it between
## fixtures, exactly as the readers beside this one do.
static func clear_cache() -> void:
	_cache.clear()
	_scenes.clear()
	_shaders.clear()


## One wearing node, with the chain already followed: what it is called, where it is, how a row
## addresses it, the material text the file holds, the shader and dials at the end of it, the node's
## own properties as the scene file wrote them, and the dial values the material overrides.
##
## The last two are what tells a screen effect somebody has turned on from one that is switched on
## and doing nothing: the node says whether it is visible, and the material says whether any dial has
## been moved off what the shader declares.
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
		"dials": EventForgeShaderUniforms.for_shader(shader_path),
		"properties": node.get("properties", {}),
		"parameters": _overridden_dials(held, material_path, inside)
	}


## The dial values one material writes down, as `name -> the text the file holds`. A material FILE
## keeps them in its own `.tres`; one the scene keeps inside itself keeps them in the scene. Empty
## for a chain that cannot be followed, which reads as "nothing has been turned up".
static func _overridden_dials(held: String, material_path: String, inside: Dictionary) -> Dictionary:
	if held.begins_with("SubResource("):
		return _dial_overrides((inside.get(_resource_id(held), {}) as Dictionary).get("properties", {}))
	return _material_facts(material_path).get("parameters", {})


## The `shader_parameter/x = …` entries of a property table, under the bare dial names. One reading,
## used for a material inside a scene and for one in a file of its own.
static func _dial_overrides(properties: Dictionary) -> Dictionary:
	var overrides: Dictionary = {}
	for key: Variant in properties:
		var written: String = str(key)
		if written.begins_with(PARAMETER_PREFIX):
			overrides[written.trim_prefix(PARAMETER_PREFIX)] = str(properties[key])
	return overrides


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


## The DRAW ORDER of one material file: the shader it runs, then the shader of whatever it hands the
## drawing on to, and so on down the `next_pass` chain. One entry per pass, each
## {"material_path", "shader_path"}, in the order the passes are drawn.
##
## The head says it because the Inspector cannot: two materials chained the wrong way round look
## exactly like two chained the right way, and the only place the order is visible is the screen.
static func pass_chain(material_path: String) -> Array[Dictionary]:
	var passes: Array[Dictionary] = []
	var current: String = material_path.strip_edges()
	while not current.is_empty() and passes.size() < MAX_PASSES:
		var facts: Dictionary = _material_facts(current)
		passes.append({"material_path": current, "shader_path": str(facts["shader"])})
		var next_pass: String = str(facts["next_pass"])
		current = "" if next_pass == current else next_pass
	return passes


## The shader a material FILE runs, or "" when the chain cannot be followed to a `.gdshader`.
static func _shader_of_file(material_path: String) -> String:
	return str(_material_facts(material_path).get("shader", ""))


## What one material file says about itself: the shader it runs and the material it hands on to, read
## once per file. A `.tres` is written in the same text format a scene is, so the file table is read
## with the scene reader's own parser rather than a second one; a material saved in Godot's binary
## format has no lines to read and ends the chain.
static func _material_facts(material_path: String) -> Dictionary:
	if material_path.is_empty():
		return {"shader": "", "next_pass": ""}
	if _shaders.has(material_path):
		return _shaders[material_path]
	var facts: Dictionary = {"shader": "", "next_pass": "", "parameters": {}}
	var lines: PackedStringArray = FileAccess.get_file_as_string(material_path).split("\n")
	var files: Dictionary = EventSheetSceneConnections.resource_paths_in(lines)
	var written: Dictionary = {}
	for line: String in lines:
		for member: String in [SHADER_PROPERTY, NEXT_PASS_PROPERTY]:
			if line.begins_with(member + " = ExtResource("):
				var key: String = "shader" if member == SHADER_PROPERTY else NEXT_PASS_PROPERTY
				facts[key] = str(files.get(
					_resource_id(line.substr(line.find("=") + 1).strip_edges()), ""))
		if line.begins_with(PARAMETER_PREFIX):
			written[line.get_slice("=", 0).strip_edges()] = line.substr(line.find("=") + 1).strip_edges()
	facts["parameters"] = _dial_overrides(written)
	_shaders[material_path] = facts
	return facts


## The id inside an `ExtResource("2_mat")` / `SubResource("3_x")` reference - the quoted text and
## nothing else.
static func _resource_id(text: String) -> String:
	return text.get_slice("\"", 1)
