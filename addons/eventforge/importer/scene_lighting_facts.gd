# EventForge - what the attached SCENE says about this sheet's lighting, said in sentences.
#
# Lighting fails invisibly. The node is there, the row runs, and the screen does not change - because
# the light casts shadows that nothing blocks, or because the environment being written at run time
# is a `.tres` three other scenes also load. Both are facts of the `.tscn`, both are readable before
# the game runs, and neither is anywhere in the script. So they are read here and shown on the head.
#
# THREE FACTS, one band each (see EventSheetHeadBands):
#   lit by      - one per light: its name, the plain word for its kind, and whether it casts shadows;
#   shadows     - how many occluders can actually block those shadows, and the warning when none can;
#   environment - which environment resource the scene's WorldEnvironment holds, and how many OTHER
#                 scenes hold the same file (which is what makes a run-time write follow the player).
#
# The same questions, asked of a scene rather than of a sheet, are what the Doctor's Lighting section
# is made of (EventSheetLightingFindings) - which is why everything below takes a SCENE path once the
# head has resolved the one scene its sheet is about. Three more facts are here for that section
# alone: which lights have no texture to cast, which reach what is drawn on the layer, and which
# CanvasModulate really darkens one.
#
# NOTHING IS STORED. Every sentence is derived from the scene on every ask, so a `.gd` still
# round-trips byte for byte and a project with no scenes grows no bands at all. The project-wide
# "who else uses this file" scan is the one expensive question here, so its answer is cached for the
# session exactly as the readers beside this one cache theirs.
#
# PURE + STATIC: a script path in, plain Dictionaries out. No dock, no canvas, no editor.
@tool
class_name EventSheetSceneLightingFacts
extends RefCounted

## The node the environment band is about, and the property it holds the environment in.
const ENVIRONMENT_CLASS: String = "WorldEnvironment"
const ENVIRONMENT_PROPERTY: String = "environment"

## The node the darkness rows are about - the one that tints a whole 2D layer at once - and the
## property it keeps the darkness in.
const DARKNESS_CLASS: String = "CanvasModulate"
const DARKNESS_PROPERTY: String = "color"

## What a 2D point light casts through. A light with none of it lights nothing at all, which is
## the first of the Doctor's five findings.
const TEXTURE_PROPERTY: String = "texture"

## environment resource path -> the other scenes holding it, sorted. The project scan behind it
## reads every `.tscn` once, which is why the answer is kept: the head asks on every open, and a
## project's scenes do not change under a running editor.
static var _sharers: Dictionary = {}


## THE scene this script is attached to, or "" when there is not exactly one. Every band below is a
## fact a reader can go and look at, and a script that several scenes run has no single scene to
## look at: a behaviour worn by five levels would otherwise wear five levels' lights on its head,
## none of which is about the sheet in front of them. The picker and the lift still consider EVERY
## scene, because the question there is "could this row mean that node", not "what is this sheet's
## scene", and answering it too narrowly would refuse a line somebody really wrote.
static func attached_scene(script_path: String) -> String:
	var scenes: PackedStringArray = EventSheetSceneReplication.scenes_using(script_path)
	return scenes[0] if scenes.size() == 1 else ""


## The `lit by` bands: one per light of the attached scene, in scene order. Each is one light, so a
## reader can click the one they mean and land on it in the scene.
static func lit_by(script_path: String) -> Array[Dictionary]:
	var bands: Array[Dictionary] = []
	if attached_scene(script_path).is_empty():
		return bands
	for light: Dictionary in EventSheetSceneLights.for_script(script_path):
		bands.append({
			"value": light_reading(light),
			"echo": light_echo(light),
			"reference": _reference(light),
			"warning": false
		})
	return bands


## One light in the words the head shows: what it is called, the plain word for what kind it is, and
## whether it casts shadows - the three facts that decide whether a row aimed at it will be visible.
static func light_reading(light: Dictionary) -> String:
	var words: PackedStringArray = PackedStringArray([str(light.get("name", "")),
		str(light.get("kind", ""))])
	if bool(light.get("shadows", false)):
		words.append(EventSheetL10n.translate("casts shadows"))
	return " · ".join(words)


## The light's own lines of the scene file. Only the lines the file really holds: Godot writes a
## property it never changed, so an echo naming one would claim a line nobody can find.
static func light_echo(light: Dictionary) -> String:
	var written: PackedStringArray = PackedStringArray(["%s: %s \"%s\"" % [
		str(light.get("scene_path", "")).get_file(), str(light.get("class", "")),
		str(light.get("name", ""))]])
	for property: String in [EventSheetSceneLights.SHADOW_PROPERTY,
			EventSheetSceneLights.SHADOW_MASK_PROPERTY_2D]:
		var held: String = str((light.get("properties", {}) as Dictionary).get(property, "")).strip_edges()
		if not held.is_empty():
			written.append("%s = %s" % [property, held])
	return ", ".join(written)


## The `shadows` band, or an empty list when the question does not arise - no 2D light of the scene
## casts shadows, so there is nothing for an occluder to block. A 3D light needs no occluder at all,
## which is why only the 2D lights ask this.
static func shadow_bands(script_path: String) -> Array[Dictionary]:
	var scene_path: String = attached_scene(script_path)
	if scene_path.is_empty():
		return []
	var casting: Array[Dictionary] = shadow_casting_lights(scene_path)
	if casting.is_empty():
		return []
	var blocked: Array[Dictionary] = matching_occluders(scene_path, casting)
	var unblocked: PackedStringArray = lights_without_occluders(scene_path, casting)
	# The band's control selects the light the band is ABOUT, which when there is a warning is the
	# light the warning names rather than the scene's first shadow-caster: in a scene where one
	# torch's shadows are blocked and another's are not, clicking through has to land on the one that
	# is not, or it sends the reader to the node that is fine.
	return [{
		"value": shadows_reading(blocked.size(), unblocked),
		"echo": shadows_echo(scene_path, blocked.size()),
		"reference": _reference(casting[0] if unblocked.is_empty() else _light_named(casting, unblocked[0])),
		"warning": not unblocked.is_empty()
	}]


## One light of a set by name, falling back to the first - which is what a set with nothing wrong in
## it has to point at, since every light in it is as good an answer as the next.
static func _light_named(lights: Array[Dictionary], name_text: String) -> Dictionary:
	for light: Dictionary in lights:
		if str(light.get("name", "")) == name_text:
			return light
	return lights[0]


## The 2D lights of one scene that cast shadows - the only ones an occluder is about. Asked by the
## SCENE from here down: the head resolves its sheet's one scene first, and the Doctor walks every
## scene the project has, so the rule below is written once and both of them run it.
static func shadow_casting_lights(scene_path: String) -> Array[Dictionary]:
	var casting: Array[Dictionary] = []
	for light: Dictionary in EventSheetSceneLights.for_scene(scene_path):
		if bool(light.get("shadows", false)) and is_2d(light):
			casting.append(light)
	return casting


## Every occluder of the scene whose own mask shares a layer with at least one shadow-casting light -
## Godot's own rule for whether a shadow is ever drawn.
static func matching_occluders(scene_path: String, casting: Array[Dictionary]) -> Array[Dictionary]:
	var blocking: Array[Dictionary] = []
	for occluder: Dictionary in EventSheetSceneLights.nodes_of_scene_class(
			scene_path, EventSheetSceneLights.OCCLUDER_CLASS):
		if not _blocked_lights(occluder, casting).is_empty():
			blocking.append(occluder)
	return blocking


## The shadow-casting lights nothing in the scene can block, by name. Empty is the healthy answer,
## and a name in it is the whole of the warning below.
static func lights_without_occluders(scene_path: String, casting: Array[Dictionary]) -> PackedStringArray:
	var occluders: Array[Dictionary] = EventSheetSceneLights.nodes_of_scene_class(
		scene_path, EventSheetSceneLights.OCCLUDER_CLASS)
	var stranded: PackedStringArray = PackedStringArray()
	for light: Dictionary in casting:
		var blocked: bool = false
		for occluder: Dictionary in occluders:
			blocked = blocked or _blocked_lights(occluder, [light]).size() > 0
		if not blocked:
			stranded.append(str(light.get("name", "")))
	return stranded


## The 2D lights of a scene with NO texture on them, by name. A PointLight2D lights the shape of
## its texture and nothing else, so one without a texture is a node that is switched on, costs a
## draw, and shows nothing - the quietest way a lit scene can be dark. Only asked of the classes that
## HAVE a texture: a DirectionalLight2D has none and needs none.
static func textureless_lights(scene_path: String) -> PackedStringArray:
	var dark: PackedStringArray = PackedStringArray()
	for light: Dictionary in EventSheetSceneLights.for_scene(scene_path):
		if not EventForgeLightWords.has_property(str(light.get("class", "")), TEXTURE_PROPERTY):
			continue
		if str((light.get("properties", {}) as Dictionary).get(TEXTURE_PROPERTY, "")).strip_edges().is_empty():
			dark.append(str(light.get("name", "")))
	return dark


## The 2D lights of a scene whose RANGE mask reaches what is drawn on the layer. Godot matches a
## light's `range_item_cull_mask` against each item's own `light_mask`, and an item that never set one
## is on layer 1 - so a light whose range mask misses layer 1 lights nothing anybody put in the scene
## by hand. This is the RANGE question, not the shadow one: two masks, two rules, and confusing them
## is how "the light is right there and the room is black" happens.
static func lights_reaching_the_layer(scene_path: String) -> PackedStringArray:
	var reaching: PackedStringArray = PackedStringArray()
	for light: Dictionary in EventSheetSceneLights.for_scene(scene_path):
		if is_2d(light) and EventSheetSceneLights.mask_bits(str(light.get("masks", ""))) \
				& EventSheetSceneLights.DEFAULT_MASK != 0:
			reaching.append(str(light.get("name", "")))
	return reaching


## The CanvasModulate nodes of a scene that really DARKEN it, each as {"name", "percent"}. A
## CanvasModulate holding white multiplies everything by one and changes nothing, so it is not a
## darkness at all; the percentage is the row's own reading of the colour, so the Doctor and the row
## say the same number about the same node.
static func darkening_nodes(scene_path: String) -> Array[Dictionary]:
	var darkening: Array[Dictionary] = []
	for node: Dictionary in EventSheetSceneLights.nodes_of_scene_class(scene_path, DARKNESS_CLASS):
		var written: String = str((node.get("properties", {}) as Dictionary).get(DARKNESS_PROPERTY, ""))
		var percent: String = EventForgeValueLens.darkness_percent(written)
		if percent == written or percent == "0%":
			continue
		darkening.append({"name": str(node.get("name", "")), "percent": percent,
			"path": str(node.get("path", "")), "scene_path": scene_path})
	return darkening


## What the band says. The healthy reading is a count; the unhealthy one is the sentence the Doctor
## raises about the same fact, so a reader meets the same words wherever they meet the problem.
static func shadows_reading(blocking: int, unblocked: PackedStringArray) -> String:
	if not unblocked.is_empty():
		return shadows_warning(unblocked)
	return EventSheetL10n.translate("%d occluder blocks the light on this layer") % blocking \
		if blocking == 1 else EventSheetL10n.translate("%d occluders block the light on this layer") % blocking


## THE warning, in one place: the band shows it, and the Doctor check raises it. A light that casts
## shadows nothing can block spends the draw cost and shows nothing for it.
static func shadows_warning(unblocked: PackedStringArray) -> String:
	return EventSheetL10n.translate("%s casts shadows and no occluder's mask matches - shadows never appear") \
		% ", ".join(unblocked)


## The occluders' own lines of the scene file, and the two properties that decided the answer: how
## many the scene holds at all, and how many of those can really block these shadows. BOTH numbers,
## because "there is nothing to block them" and "the ones there are sit on another layer" are
## different problems with different fixes, and the echo is where a reader tells them apart.
static func shadows_echo(scene_path: String, blocking: int) -> String:
	var occluders: Array[Dictionary] = EventSheetSceneLights.nodes_of_scene_class(
		scene_path, EventSheetSceneLights.OCCLUDER_CLASS)
	var scene_file: String = scene_path.get_file()
	return "%s: %s x %d, %d whose %s matches %s" % [scene_file,
		EventSheetSceneLights.OCCLUDER_CLASS, occluders.size(), blocking,
		EventSheetSceneLights.OCCLUDER_MASK_PROPERTY, EventSheetSceneLights.SHADOW_MASK_PROPERTY_2D]


## The `environment` band, or an empty list when the scene has no WorldEnvironment - in which case
## the sheet's environment rows do nothing, which is the Doctor's business rather than the head's.
static func environment_bands(script_path: String) -> Array[Dictionary]:
	var bands: Array[Dictionary] = []
	if attached_scene(script_path).is_empty():
		return bands
	for holder: Dictionary in EventSheetSceneLights.nodes_of_class(script_path, ENVIRONMENT_CLASS):
		var resource_path: String = environment_resource(holder)
		var others: PackedStringArray = scenes_sharing(resource_path, str(holder.get("scene_path", "")))
		bands.append({
			"value": environment_reading(resource_path, others),
			"echo": environment_echo(holder, resource_path, others),
			"reference": _reference(holder),
			"warning": false
		})
	return bands


## The environment resource one WorldEnvironment holds, as a res:// path - "" when the scene keeps
## the environment INSIDE itself (a sub-resource), which is the case no other scene can share.
static func environment_resource(holder: Dictionary) -> String:
	var held: String = str((holder.get("properties", {}) as Dictionary).get(ENVIRONMENT_PROPERTY, ""))
	if not held.begins_with("ExtResource("):
		return ""
	return str(EventSheetSceneConnections.resource_paths_of_scene(
		str(holder.get("scene_path", ""))).get(held.get_slice("\"", 1), ""))


## What the band says: the file the environment lives in, and how many OTHER scenes load the same
## one - because a row that writes a shared environment at run time writes it for all of them.
static func environment_reading(resource_path: String, others: PackedStringArray) -> String:
	if resource_path.is_empty():
		return EventSheetL10n.translate("kept inside this scene - nothing else can see the change")
	if others.is_empty():
		return "%s · %s" % [resource_path.get_file(),
			EventSheetL10n.translate("used by this scene only")]
	return "%s · %s" % [resource_path.get_file(),
		EventSheetL10n.translate("shared with %d other scene") % others.size() if others.size() == 1 \
			else EventSheetL10n.translate("shared with %d other scenes") % others.size()]


## The holder's own line of the scene file, with the other scenes named after it - the loud half of
## the fact, so a reader can go and look at the scenes that would follow the change.
static func environment_echo(holder: Dictionary, resource_path: String, others: PackedStringArray) -> String:
	var written: String = "%s: %s \"%s\", %s = %s" % [
		str(holder.get("scene_path", "")).get_file(), ENVIRONMENT_CLASS, str(holder.get("name", "")),
		ENVIRONMENT_PROPERTY,
		"SubResource" if resource_path.is_empty() else "\"%s\"" % resource_path]
	if others.is_empty():
		return written
	var names: PackedStringArray = PackedStringArray()
	for scene_path: String in others:
		names.append(scene_path.get_file())
	return "%s · %s %s" % [written, EventSheetL10n.translate("also in"), ", ".join(names)]


## Every OTHER scene of the project loading one resource file, sorted. Cached for the session: this
## is a read of every `.tscn` there is, asked once per open and answered from a table after that.
static func scenes_sharing(resource_path: String, own_scene: String) -> PackedStringArray:
	if resource_path.is_empty():
		return PackedStringArray()
	if not _sharers.has(resource_path):
		var holders: PackedStringArray = PackedStringArray()
		for scene_path: String in EventSheetSceneConnections.scene_paths():
			for held: Variant in EventSheetSceneConnections.resource_paths_of_scene(scene_path).values():
				if str(held) == resource_path:
					holders.append(scene_path)
					break
		holders.sort()
		_sharers[resource_path] = holders
	var others: PackedStringArray = PackedStringArray()
	for scene_path: String in _sharers[resource_path] as PackedStringArray:
		if scene_path != own_scene:
			others.append(scene_path)
	return others


## Drops the project scan, so the next ask reads the scenes again. Called between fixtures by the
## tests, for the same reason the readers beside this one expose one: a session-lifetime answer is
## right while the editor runs and wrong the moment a suite swaps the project under it.
static func clear_cache() -> void:
	_sharers.clear()


## The scene and node a band is about, in the "scene|node" spelling the head's gestures read.
static func _reference(node: Dictionary) -> String:
	return "%s|%s" % [str(node.get("scene_path", "")), str(node.get("path", ""))]


## Which of these lights one occluder can block: the ones whose shadow mask shares a layer with the
## occluder's own. Both sides fall back to the engine's default when the file wrote neither.
static func _blocked_lights(occluder: Dictionary, casting: Array) -> PackedStringArray:
	var mask: String = str((occluder.get("properties", {}) as Dictionary).get(
		EventSheetSceneLights.OCCLUDER_MASK_PROPERTY, ""))
	var blocked: PackedStringArray = PackedStringArray()
	for entry: Variant in casting:
		var light: Dictionary = entry
		if EventSheetSceneLights.masks_overlap(mask, str(light.get("shadow_masks", ""))):
			blocked.append(str(light.get("name", "")))
	return blocked


## True for a light of the 2D dimension - the only one occluders, textures and a darkened layer are
## about. A 3D light needs no occluder to cast a shadow and no texture to shine.
static func is_2d(light: Dictionary) -> bool:
	var node_class: String = str(light.get("class", ""))
	return ClassDB.class_exists(node_class) \
		and ClassDB.is_parent_class(node_class, EventForgeLightWords.ROOT_2D)
