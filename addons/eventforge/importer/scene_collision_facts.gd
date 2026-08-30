# EventForge - who sees whom, read out of the scene rather than guessed from the rows.
#
# Collision is the one part of a Godot game whose whole truth lives outside the script. A sheet says
# "On body entered", and whether that trigger can EVER fire is decided by two 32-bit numbers written
# in the `.tscn`: the layer the object sits on, and the mask of layers it watches. Both default to 1,
# both are edited in the Inspector with unlabelled tick boxes, and neither is visible from the row
# that depends on them. So the commonest collision bug in every project is not a wrong row - it is a
# right row that nothing can reach.
#
# This is the reader for those facts:
#
#   sees        - the layer NAMES this object's mask covers, so "collision_mask = 6" reads as
#                 "Enemies, Walls".
#   seen by     - the layer names of the objects elsewhere in the project whose masks cover one of
#                 THIS object's layers. Derived, not stored: a layer nobody watches is a layer
#                 nothing can touch, and that is the fact worth saying out loud.
#   monitoring  - said only for an Area, because it is the Area's own switch and the one that turns
#                 a correct trigger off without changing a line.
#
# Everything comes off `EventSheetSceneConnections.nodes_of_scene`, the project's ONE parse of scene
# text, and the layer names come off `EventForgePhysicsLayers`, the project's ONE reader of the layer
# name list. Nothing here parses a `.tscn` for itself and nothing here reads Project Settings for
# itself, which is what keeps the head band, the sheet's amber state and the Doctor's Collisions
# section saying exactly the same thing about the same node.
#
# NOTHING IS STORED IN THE SHEET. Every sentence is derived on every ask, so a `.gd` still
# round-trips byte for byte and a project with no scenes grows no bands at all. The two questions
# that have to be asked of EVERY scene - the project's layer census and the members of a group - are
# cached for the session, exactly as the readers beside this one cache theirs.
#
# PURE + STATIC, apart from the two editor writes at the foot: a scene path in, plain Dictionaries
# out, no dock, no canvas, no editor.
@tool
class_name EventSheetSceneCollisionFacts
extends RefCounted

## The two numbers, and the Area switch, as the `.tscn` spells them. Godot writes a property only
## when it is not the default, so an absent line means the default - which is why the defaults are
## named here rather than left as bare 1s in three different reads.
const LAYER_PROPERTY := "collision_layer"
const MASK_PROPERTY := "collision_mask"
const MONITORING_PROPERTY := "monitoring"
const DEFAULT_LAYER_BITS := 1
const DEFAULT_MASK_BITS := 1
const DEFAULT_MONITORING := true

## What a shape node is called, in both dimensions. A collision object with none of these under it
## has no extent at all: Godot itself says so in the Scene dock, and nothing else in the editor says
## it to the sheet that depends on the node.
const SHAPE_CLASSES: PackedStringArray = [
	"CollisionShape2D", "CollisionShape3D", "CollisionPolygon2D", "CollisionPolygon3D",
]

## The property a 2D shape carries when it only blocks from one side, and the rotation that turns
## that side over. One-way collision is 2D only in Godot, which is why no 3D twin is named here.
const ONE_WAY_PROPERTY := "one_way_collision"
const ROTATION_PROPERTY := "rotation"

## Half a turn, in radians. A shape rotated further than a quarter turn from upright has its
## blocking side pointing downwards, which is the whole of the facing question - a platform that
## lets bodies through from above and stops them from below.
const QUARTER_TURN := 0.7853981633974483

## The engine's own class every collision object descends from, per dimension. Asked of ClassDB so a
## node type nobody listed here is still recognised, and matched on the name's tail when the class is
## not registered (a scene written by a newer engine, a type this build does not carry).
const COLLISION_ROOT_2D := "CollisionObject2D"
const COLLISION_ROOT_3D := "CollisionObject3D"

## How many names a band or a finding spells before it starts counting - the band scale law. Three is
## what fits beside the two other halves of the collisions band without wrapping it.
const NAMES_SHOWN := 3

## Godot's own limit, borrowed rather than restated: a mask is 32 bits and a layer is one of them.
const FIRST_LAYER := EventForgePhysicsLayers.FIRST_LAYER
const LAST_LAYER := EventForgePhysicsLayers.LAST_LAYER

## dimension -> {layer number: [{"scene_path", "path", "name", "type"}]}. The project's layer census,
## kept for the session because it reads every scene the project has and is asked by every bare
## trigger of every sheet anybody opens.
static var _census: Dictionary = {}

## "dimension|group" -> the layer bits the members of that group sit on. Same reason, same lifetime.
static var _group_bits: Dictionary = {}

## script path -> its collidable nodes in the one scene that runs it.
static var _for_script: Dictionary = {}


## Drops everything held here. The editor calls it when the filesystem changes; tests call it between
## fixtures, which is what keeps one fixture's project out of the next one's answers.
static func clear_cache() -> void:
	_census.clear()
	_group_bits.clear()
	_for_script.clear()


# -- Reading one scene ---------------------------------------------------------------------------


## Every collision object of one scene, in the order the file writes them. Each entry answers for
## itself: what it sits on, what it watches, whether it is switched on, what it is in, and whether it
## has any extent at all.
static func collidables_of_scene(scene_path: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	if scene_path.strip_edges().is_empty():
		return found
	var nodes: Array = EventSheetSceneConnections.nodes_of_scene(scene_path)
	for entry: Variant in nodes:
		var node: Dictionary = resolved(entry)
		if not is_collision_class(str(node.get("type", ""))):
			continue
		found.append(_collidable(scene_path, node, nodes))
	return found


## How far an instance chain is followed. A scene of scenes of scenes is ordinary; a scene that
## somehow points at itself is not, and a walk with no floor under it would never come back.
const INSTANCE_DEPTH: int = 8


## One node with the file it was INSTANCED from folded into it - the type it really is, the
## properties it did not override, the groups it was born in, the script it carries.
##
## This is the commonest layout a Godot project has: a level made of scenes. The `[node]` header of
## an instance site carries no `type=` at all, so a reader that goes by `type` alone sees nothing
## there - the enemy sitting in the level is invisible, the layer census misses it, and a gate whose
## mask is right is told that nothing it watches exists. An ordinary node comes back untouched, so
## every reader below asks this once and stops thinking about it.
##
## The instance SITE wins over the file it points at, because that is what Godot does when it loads
## the scene: an overridden `collision_layer` in the level is the layer this copy sits on. Groups are
## the exception and are the union of both, since a scene adds groups to an instance rather than
## replacing the ones the instance was born with.
static func resolved(node: Dictionary, depth: int = 0) -> Dictionary:
	var instance_path: String = str(node.get("instance_path", ""))
	if instance_path.is_empty() or not str(node.get("type", "")).strip_edges().is_empty():
		return node
	if depth >= INSTANCE_DEPTH:
		return node
	var base: Dictionary = _root_of_scene(instance_path, depth + 1)
	if base.is_empty():
		return node
	var merged: Dictionary = node.duplicate()
	merged["type"] = str(base.get("type", ""))
	var properties: Dictionary = (base.get("properties", {}) as Dictionary).duplicate()
	properties.merge(node.get("properties", {}) as Dictionary, true)
	merged["properties"] = properties
	var groups: PackedStringArray = PackedStringArray(base.get("groups", PackedStringArray()))
	for group_name: String in PackedStringArray(node.get("groups", PackedStringArray())):
		if not groups.has(group_name):
			groups.append(group_name)
	merged["groups"] = groups
	if str(node.get("script_path", "")).is_empty():
		merged["script_path"] = str(base.get("script_path", ""))
	return merged


## The ROOT node of one scene, itself resolved - because a scene's own root can be an instance of
## another scene, which is how an inherited scene is written.
static func _root_of_scene(scene_path: String, depth: int) -> Dictionary:
	for entry: Variant in EventSheetSceneConnections.nodes_of_scene(scene_path):
		var node: Dictionary = entry
		if str(node.get("path", "")) == ".":
			return resolved(node, depth)
	return {}


## True when a scene's node type is a collision object. ClassDB answers where it can, and the name's
## own tail answers where it cannot - a type this build does not carry is still plainly an Area2D or
## a StaticBody3D to anybody reading the file.
static func is_collision_class(node_type: String) -> bool:
	var text: String = node_type.strip_edges()
	if text.is_empty():
		return false
	if ClassDB.class_exists(text):
		return ClassDB.is_parent_class(text, COLLISION_ROOT_2D) \
			or ClassDB.is_parent_class(text, COLLISION_ROOT_3D)
	return text.ends_with("Area2D") or text.ends_with("Area3D") \
		or text.ends_with("Body2D") or text.ends_with("Body3D")


## True when a node type is an Area - the class that carries `monitoring`, and the only class a touch
## trigger can hang off.
static func is_area_class(node_type: String) -> bool:
	var text: String = node_type.strip_edges()
	if ClassDB.class_exists(text):
		return ClassDB.is_parent_class(text, "Area2D") or ClassDB.is_parent_class(text, "Area3D")
	return text.ends_with("Area2D") or text.ends_with("Area3D")


## Which list of layer names a node's numbers read from. The node's own class decides it, through the
## one reader that owns that question, because 2D and 3D spell the properties identically.
static func dimension_of(node_type: String) -> String:
	return EventForgePhysicsLayers.dimension_for_class(node_type)


## One collidable, with the shape children of the same scene already resolved onto it.
static func _collidable(scene_path: String, node: Dictionary, nodes: Array) -> Dictionary:
	var properties: Dictionary = node.get("properties", {})
	var node_path: String = str(node.get("path", "."))
	var node_type: String = str(node.get("type", ""))
	var shapes: Array[Dictionary] = _shapes_under(node_path, nodes)
	# An instanced node's shapes are written in the file it came from, not in the one that placed it -
	# so a level made of scenes would otherwise read as a level of collision objects with no extent at
	# all, and every one of them would earn the no-shape finding. The site's own extra children (a
	# level can add a shape to a copy) come first, because that is the order the file writes them.
	shapes.append_array(_instanced_shapes(str(node.get("instance_path", "")), 0))
	return {
		"scene_path": scene_path,
		"name": str(node.get("name", "")),
		"path": node_path,
		"type": node_type,
		"dimension": dimension_of(node_type),
		"is_area": is_area_class(node_type),
		"layer_bits": _int_property(properties, LAYER_PROPERTY, DEFAULT_LAYER_BITS),
		"mask_bits": _int_property(properties, MASK_PROPERTY, DEFAULT_MASK_BITS),
		"monitoring": _bool_property(properties, MONITORING_PROPERTY, DEFAULT_MONITORING),
		"groups": PackedStringArray(node.get("groups", PackedStringArray())),
		"has_shape": not shapes.is_empty(),
		"one_way": _one_way_shapes(shapes),
	}


## The shape children of one node, in file order. A shape is a child of the collision object it gives
## its extent to, so the test is on the node path rather than on a walk: `Platform/Shape` belongs to
## `Platform`, and `Platform/Sprite/Shape` belongs to nothing that collides.
static func _shapes_under(node_path: String, nodes: Array) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var prefix: String = "" if node_path == "." else node_path + "/"
	for entry: Variant in nodes:
		var child: Dictionary = entry
		if not SHAPE_CLASSES.has(str(child.get("type", ""))):
			continue
		var child_path: String = str(child.get("path", ""))
		if node_path == ".":
			# A root's shapes are its direct children, which the file writes with no slash in them.
			if child_path.contains("/"):
				continue
		elif not child_path.begins_with(prefix) or child_path.substr(prefix.length()).contains("/"):
			continue
		found.append(child)
	return found


## The shapes an INSTANCED node brings with it: the ones written under the root of the scene it came
## from, and the ones that scene's own root brought with it in turn. "" for an ordinary node, which
## is where almost every call ends.
static func _instanced_shapes(instance_path: String, depth: int) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	if instance_path.is_empty() or depth >= INSTANCE_DEPTH:
		return found
	var nodes: Array = EventSheetSceneConnections.nodes_of_scene(instance_path)
	found.append_array(_shapes_under(".", nodes))
	var root: Dictionary = {}
	for entry: Variant in nodes:
		var node: Dictionary = entry
		if str(node.get("path", "")) == ".":
			root = node
			break
	return found + _instanced_shapes(str(root.get("instance_path", "")), depth + 1)


## The one-way shapes of a set, each with the way it faces. `faces_down` is the shape turned further
## than a quarter turn from upright: its blocking side points at the floor, so bodies fall through it
## from above and are stopped from below, which is the wrong way round for a platform.
static func _one_way_shapes(shapes: Array[Dictionary]) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for shape: Dictionary in shapes:
		var properties: Dictionary = shape.get("properties", {})
		if not _bool_property(properties, ONE_WAY_PROPERTY, false):
			continue
		var turned: float = absf(str(properties.get(ROTATION_PROPERTY, "0")).to_float())
		found.append({
			"name": str(shape.get("name", "")),
			"path": str(shape.get("path", "")),
			"faces_down": turned > QUARTER_TURN,
		})
	return found


static func _int_property(properties: Dictionary, key: String, fallback: int) -> int:
	var written: String = str(properties.get(key, "")).strip_edges()
	return written.to_int() if written.is_valid_int() else fallback


static func _bool_property(properties: Dictionary, key: String, fallback: bool) -> bool:
	var written: String = str(properties.get(key, "")).strip_edges()
	if written == "true":
		return true
	if written == "false":
		return false
	return fallback


# -- Reading one sheet's node --------------------------------------------------------------------


## The collidable nodes ONE script sits on, in the single scene that runs it. Empty when the script
## has no one scene (a behaviour worn by five levels has no single set of numbers to show), and empty
## when the node it sits on does not collide - which is most sheets, and the reason a project that
## never touches physics grows nothing from this file at all.
static func for_script(script_path: String) -> Array[Dictionary]:
	var path: String = script_path.strip_edges()
	if path.is_empty():
		return []
	if _for_script.has(path):
		return _for_script[path]
	var found: Array[Dictionary] = []
	var scene_path: String = EventSheetSceneLightingFacts.attached_scene(path)
	if not scene_path.is_empty():
		for node: Variant in EventSheetSceneConnections.nodes_of_scene(scene_path):
			var entry: Dictionary = resolved(node)
			if str(entry.get("script_path", "")) != path or not is_collision_class(str(entry.get("type", ""))):
				continue
			found.append(_collidable(scene_path, entry,
				EventSheetSceneConnections.nodes_of_scene(scene_path)))
	_for_script[path] = found
	return found


# -- Reading the whole project -------------------------------------------------------------------


## THE CORPUS. Every question below is asked of a LIST of scenes, and an empty list means the
## project's own - which is what the editor always passes and what makes the answers cacheable. A
## caller handing its own list gets an uncached, pure answer over exactly those files, which is how a
## test pins a sentence about three fixtures without the rest of the repository joining in.
static func corpus(scenes: PackedStringArray) -> PackedStringArray:
	return EventSheetSceneConnections.scene_paths() if scenes.is_empty() else scenes


## The layer census for one dimension: layer number -> the collidables sitting on it, in scene order.
## What a bare trigger is measured against ("this mask watches nothing that exists"), and what
## "seen by" is derived from.
static func census(dimension: String, scenes: PackedStringArray = PackedStringArray()) -> Dictionary:
	if scenes.is_empty() and _census.has(dimension):
		return _census[dimension]
	var by_layer: Dictionary = {}
	for scene_path: String in corpus(scenes):
		for collidable: Dictionary in collidables_of_scene(scene_path):
			if str(collidable.get("dimension", "")) != dimension:
				continue
			for layer_number: int in layer_numbers(int(collidable.get("layer_bits", 0))):
				if not by_layer.has(layer_number):
					by_layer[layer_number] = []
				(by_layer[layer_number] as Array).append(collidable)
	if scenes.is_empty():
		_census[dimension] = by_layer
	return by_layer


## Every layer of this dimension that anything at all sits on, as a mask. The weaker of the two
## comparisons a dead-trigger finding makes, and the honest one for a trigger that names no group:
## a mask covering none of these bits can be reached by nothing in the corpus.
static func occupied_bits(dimension: String, scenes: PackedStringArray = PackedStringArray()) -> int:
	var bits: int = 0
	for layer_number: Variant in census(dimension, scenes).keys():
		bits |= bit_of(int(layer_number))
	return bits


## A group as the scene file spells it, out of the way a ROW spells it. A row's parameter carries
## GDScript - `"enemies"`, `&"enemies"` - and a scene's header carries the bare word, so the two are
## brought together here rather than in each of the three places that compare them. The ONE
## normalisation, which is also what a sentence naming the group has to say.
static func group_word(group_name: String) -> String:
	return group_name.strip_edges().trim_prefix("&").trim_prefix("\"").trim_suffix("\"").strip_edges()


## The layers the members of one GROUP sit on, as a mask. This is what makes a group-filtered
## trigger answerable: "On body entered, if the body is in enemies" is about the layers the enemies
## of this project are really on, whatever the sheet believes.
static func group_bits(group_name: String, dimension: String,
		scenes: PackedStringArray = PackedStringArray()) -> int:
	var wanted: String = group_word(group_name)
	if wanted.is_empty():
		return 0
	var key: String = "%s|%s" % [dimension, wanted]
	if scenes.is_empty() and _group_bits.has(key):
		return int(_group_bits[key])
	var bits: int = 0
	for scene_path: String in corpus(scenes):
		for collidable: Dictionary in collidables_of_scene(scene_path):
			if str(collidable.get("dimension", "")) != dimension:
				continue
			if not PackedStringArray(collidable.get("groups", PackedStringArray())).has(wanted):
				continue
			bits |= int(collidable.get("layer_bits", 0))
	if scenes.is_empty():
		_group_bits[key] = bits
	return bits


## The layers of everything whose MASK covers one of these layers - "who can see me", as a mask of
## the watchers' own layers. A body on a layer nothing watches is a body nothing can touch, and this
## is the number that says so.
static func watchers_of(layer_bits: int, dimension: String,
		scenes: PackedStringArray = PackedStringArray()) -> int:
	var bits: int = 0
	for scene_path: String in corpus(scenes):
		for collidable: Dictionary in collidables_of_scene(scene_path):
			if str(collidable.get("dimension", "")) != dimension:
				continue
			if int(collidable.get("mask_bits", 0)) & layer_bits == 0:
				continue
			bits |= int(collidable.get("layer_bits", 0))
	return bits


# -- Bits, and the words for them ----------------------------------------------------------------


## The bit one layer number is - Godot numbers layers from 1 and stores them from bit 0, which is
## the off-by-one every hand-written mask check in every project gets wrong once.
static func bit_of(layer_number: int) -> int:
	if not EventForgePhysicsLayers.is_layer_number(layer_number):
		return 0
	return 1 << (layer_number - 1)


## The layer numbers a mask holds, lowest first.
static func layer_numbers(bits: int) -> PackedInt32Array:
	var numbers: PackedInt32Array = PackedInt32Array()
	for layer_number: int in range(FIRST_LAYER, LAST_LAYER + 1):
		if bits & bit_of(layer_number) != 0:
			numbers.append(layer_number)
	return numbers


## A mask as the words a band says: the layer names it covers, the band scale law applied - what fits
## is named, the rest is counted. "nothing" for a mask with no bits at all, which is a real and
## reportable state rather than an empty phrase.
static func words_for_bits(bits: int, dimension: String, shown: int = NAMES_SHOWN) -> String:
	var numbers: PackedInt32Array = layer_numbers(bits)
	if numbers.is_empty():
		return EventSheetL10n.translate("nothing")
	var named: PackedStringArray = PackedStringArray()
	for index: int in numbers.size():
		if index >= shown:
			break
		named.append(EventForgePhysicsLayers.words_for(numbers[index], dimension))
	var listed: String = ", ".join(named)
	var rest: int = numbers.size() - named.size()
	return listed if rest <= 0 else EventSheetL10n.translate("%s and %d more") % [listed, rest]


## The same list with nothing left out - what a finding names, because a finding that counted its
## layers would be asking the reader to go and find out which ones.
static func all_words_for_bits(bits: int, dimension: String) -> String:
	return words_for_bits(bits, dimension, LAST_LAYER)


# -- The head band ------------------------------------------------------------------------------


## The `collisions` bands for one sheet: one per collidable node its script sits on. The reading is
## the three facts in one sentence, the echo is the lines of the scene file they came from, and the
## reference is the node itself so the band's control can open the scene on it.
static func bands(script_path: String, scenes: PackedStringArray = PackedStringArray()) -> Array[Dictionary]:
	var built: Array[Dictionary] = []
	for collidable: Dictionary in for_script(script_path):
		built.append({
			"value": reading(collidable, scenes),
			"echo": echo(collidable),
			"reference": "%s|%s" % [str(collidable.get("scene_path", "")), str(collidable.get("path", ""))],
			# The band wears the problem's colour for the one state that is always a problem: an
			# Area switched off watches nothing at all, whatever its mask says.
			"warning": bool(collidable.get("is_area", false)) and not bool(collidable.get("monitoring", true)),
		})
	return built


## One collidable in the words the head shows - "sees Enemies, Walls · seen by Player · monitoring
## on". The third half is said only for an Area, because `monitoring` is the Area's own switch and a
## band never says a property the node does not have.
static func reading(collidable: Dictionary,
		scenes: PackedStringArray = PackedStringArray()) -> String:
	var dimension: String = str(collidable.get("dimension", EventForgePhysicsLayers.DIMENSION_2D))
	var parts: PackedStringArray = PackedStringArray([
		EventSheetL10n.translate("sees %s") % words_for_bits(int(collidable.get("mask_bits", 0)), dimension),
		EventSheetL10n.translate("seen by %s") % words_for_bits(
			watchers_of(int(collidable.get("layer_bits", 0)), dimension, scenes), dimension),
	])
	if bool(collidable.get("is_area", false)):
		parts.append(EventSheetL10n.translate("monitoring on") if bool(collidable.get("monitoring", true))
			else EventSheetL10n.translate("monitoring off"))
	return " · ".join(parts)


## The node's own lines of the scene file. Only the lines the file really holds: Godot writes a
## property it never changed, so an echo naming one would claim a line nobody can find - which is why
## a node on the default layer watching the default mask echoes its header and nothing else.
static func echo(collidable: Dictionary) -> String:
	var written: PackedStringArray = PackedStringArray(["%s: %s \"%s\"" % [
		str(collidable.get("scene_path", "")).get_file(), str(collidable.get("type", "")),
		str(collidable.get("name", ""))]])
	var layer_bits: int = int(collidable.get("layer_bits", DEFAULT_LAYER_BITS))
	var mask_bits: int = int(collidable.get("mask_bits", DEFAULT_MASK_BITS))
	if layer_bits != DEFAULT_LAYER_BITS:
		written.append("%s = %d" % [LAYER_PROPERTY, layer_bits])
	if mask_bits != DEFAULT_MASK_BITS:
		written.append("%s = %d" % [MASK_PROPERTY, mask_bits])
	if bool(collidable.get("is_area", false)) and not bool(collidable.get("monitoring", true)):
		written.append("%s = false" % MONITORING_PROPERTY)
	return ", ".join(written)


# -- Writing, through the editor -----------------------------------------------------------------


## Turns one layer of a node's MASK on, and says what the number read as before and reads as now.
## The write goes through the SCENE: the node is found in the open scene and the property is set
## through the editor's own undo manager, so Ctrl+Z takes it back and the Inspector shows it
## immediately. Returns `{"ok", "reason", "before", "after"}`.
##
## Refused outside the editor, and refused when the scene is not the one being edited: writing into a
## file nobody is looking at is how two editors of the same fact end up disagreeing.
static func let_it_see(scene_path: String, node_path: String, layer_number: int) -> Dictionary:
	var bit: int = bit_of(layer_number)
	if bit == 0:
		return _refused(EventSheetL10n.translate("Godot has collision layers 1 to 32."))
	return _write_property(scene_path, node_path, MASK_PROPERTY,
		func(current: Variant) -> Variant: return int(current) | bit,
		EventSheetL10n.translate("Watch collision layer %d") % layer_number)


## Turns an Area's `monitoring` back on, with the same receipt and the same undo.
static func turn_monitoring_on(scene_path: String, node_path: String) -> Dictionary:
	return _write_property(scene_path, node_path, MONITORING_PROPERTY,
		func(_current: Variant) -> Variant: return true,
		EventSheetL10n.translate("Switch monitoring on"))


## The one write both doors go through. `change` takes the property's current value and answers with
## the one to set, so the receipt is the pair either side of it rather than a sentence composed twice.
static func _write_property(scene_path: String, node_path: String, property: String,
		change: Callable, action_name: String) -> Dictionary:
	if not Engine.is_editor_hint():
		return _refused(EventSheetL10n.translate("The scene is only editable inside the editor."))
	var root: Node = EditorInterface.get_edited_scene_root()
	if root == null or root.scene_file_path != scene_path:
		return _refused(EventSheetL10n.translate("Open %s to change what it collides with.")
			% scene_path.get_file())
	var node: Node = root if node_path == "." else root.get_node_or_null(NodePath(node_path))
	if node == null:
		return _refused(EventSheetL10n.translate("%s is not in the open scene any more.") % node_path)
	var before: Variant = node.get(property)
	var after: Variant = change.call(before)
	if before == after:
		return {"ok": true, "reason": "", "before": _written(property, before),
			"after": _written(property, after)}
	var undo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	if undo == null:
		node.set(property, after)
	else:
		undo.create_action(action_name)
		undo.add_do_property(node, property, after)
		undo.add_undo_property(node, property, before)
		undo.commit_action()
	EditorInterface.mark_scene_as_unsaved()
	clear_cache()
	return {"ok": true, "reason": "", "before": _written(property, before),
		"after": _written(property, after)}


## One side of a receipt, as the scene file writes that property - so the two halves a reader is
## shown are two lines they could go and find, not a summary of them.
static func _written(property: String, value: Variant) -> String:
	if value is bool:
		return "%s = %s" % [property, "true" if bool(value) else "false"]
	return "%s = %d" % [property, int(value)]


## The receipt one write leaves: the line as it was, and the line as it now is. Not translated, and
## deliberately - both sides are lines of a scene file and the arrow between them is punctuation.
static func receipt(result: Dictionary) -> String:
	return "%s -> %s" % [str(result.get("before", "")), str(result.get("after", ""))]


static func _refused(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason, "before": "", "after": ""}
