# EventForge - the inherited transform facts, said where the surprise would land.
#
# Transforms inherit, and that is where the weird lives. Three of them cost everybody an evening:
#
#   inside something scaled   a child of a parent scaled 2x moves twice as far as its own numbers say
#   mirrored by scale         a negative scale flips the collision shapes and the raycasts with the art
#   scaled unevenly and turned  a non-uniform scale on a rotating node shears it into a parallelogram
#
# None of the three is a line anybody wrote, so no amount of reading the sheet would ever find them,
# and all three are visible in the `.tscn` before the game is run once. So they are read here, and
# the head says them - but only when they BITE: a scene with nothing scaled grows no bands at all.
#
# NOTHING IS STORED and nothing is guessed. Every sentence is derived from the scene on every ask,
# so a `.gd` still round-trips byte for byte and a fact disappears the moment its cause does.
#
# AND IT NAMES A FEW AND COUNTS THE REST. A scene with fifty mirrored bodies has one problem, not
# fifty bands: three of a kind are named and the others counted in one line after them.
@tool
class_name EventSheetSceneTransformFacts
extends RefCounted

## The properties a scene writes a transform's parts under, and the classes the mirroring fact is
## about - the ones whose SHAPES flip with the art, which is the whole of that surprise.
const SCALE_PROPERTY: String = "scale"
const ROTATION_PROPERTY: String = "rotation"
const BODY_CLASSES: PackedStringArray = ["CollisionObject2D", "CollisionObject3D"]

## How far from 1 a scale has to be before it is worth saying anything about. A scene saved with
## `Vector2(1, 1.0000001)` is a scene nobody scaled.
const TOLERANCE: float = 0.001

## How many nodes of one kind the head names before it starts counting. A head is a place to LOOK,
## not an inventory: a scene with fifty mirrored bodies has one problem, not fifty bands, and a
## reader who has read three of them has understood the fourth.
const BANDS_SHOWN: int = 3


## The `transform` bands of the sheet's one attached scene: the facts that are about to bite, and
## nothing else. Empty for a scene with nothing scaled, which is most scenes.
static func bands(script_path: String) -> Array[Dictionary]:
	var built: Array[Dictionary] = []
	var scene_path: String = EventSheetSceneLightingFacts.attached_scene(script_path)
	if scene_path.is_empty():
		return built
	var nodes: Array = EventSheetSceneConnections.nodes_of_scene(scene_path)
	var inside: Dictionary = scaled_ancestor(nodes, script_path)
	if not inside.is_empty():
		built.append(_band(inside_reading(inside), inside["node"], scene_path, false))
	var mirrored: Array[Dictionary] = mirrored_bodies(nodes)
	for index: int in range(mini(mirrored.size(), BANDS_SHOWN)):
		built.append(_band(mirrored_warning(mirrored[index]), mirrored[index], scene_path, true))
	if mirrored.size() > BANDS_SHOWN:
		built.append(_band(EventSheetL10n.translate("%d more node(s) mirrored by a negative scale")
			% (mirrored.size() - BANDS_SHOWN), mirrored[BANDS_SHOWN], scene_path, true))
	var shearing: Array[Dictionary] = shearing_nodes(nodes)
	for index: int in range(mini(shearing.size(), BANDS_SHOWN)):
		built.append(_band(shear_warning(shearing[index]), shearing[index], scene_path, true))
	if shearing.size() > BANDS_SHOWN:
		built.append(_band(EventSheetL10n.translate("%d more node(s) scaled unevenly and turned")
			% (shearing.size() - BANDS_SHOWN), shearing[BANDS_SHOWN], scene_path, true))
	return built


## The scaled node this script's own node sits inside, as {"node", "ancestor", "scale"} - {} when
## there is none, which is the healthy answer. Only the NEAREST scaled ancestor is named: a reader
## needs the one whose numbers their own are multiplied by, not the whole chain.
static func scaled_ancestor(nodes: Array, script_path: String) -> Dictionary:
	var own: Dictionary = _node_running(nodes, script_path)
	if own.is_empty():
		return {}
	var parent_path: String = str(own.get("path", "")).get_base_dir()
	while not parent_path.is_empty() and parent_path != ".":
		var ancestor: Dictionary = _node_at(nodes, parent_path)
		if not ancestor.is_empty() and _is_scaled(_scale_of(ancestor)):
			return {"node": own, "ancestor": ancestor, "scale": _scale_of(ancestor)}
		parent_path = parent_path.get_base_dir()
	var root: Dictionary = _node_at(nodes, ".")
	if not root.is_empty() and str(root.get("path", "")) != str(own.get("path", "")) \
			and _is_scaled(_scale_of(root)):
		return {"node": own, "ancestor": root, "scale": _scale_of(root)}
	return {}


## The bodies of a scene mirrored by a negative scale. Physics and raycasts flip with the art, which
## is never what somebody turning a sprite round meant.
static func mirrored_bodies(nodes: Array) -> Array[Dictionary]:
	var mirrored: Array[Dictionary] = []
	for entry: Variant in nodes:
		var node: Dictionary = entry
		if not _is_a_body(str(node.get("type", ""))):
			continue
		var scale: PackedFloat32Array = _scale_of(node)
		for axis: float in scale:
			if axis < 0.0:
				mirrored.append(node)
				break
	return mirrored


## The nodes scaled unevenly AND turned - the parallelogram nobody can name. Both halves are needed:
## an uneven scale on its own is fine, and a rotation on its own is fine.
static func shearing_nodes(nodes: Array) -> Array[Dictionary]:
	var shearing: Array[Dictionary] = []
	for entry: Variant in nodes:
		var node: Dictionary = entry
		var scale: PackedFloat32Array = _scale_of(node)
		if scale.size() < 2 or is_zero_approx(_rotation_of(node)):
			continue
		if not is_equal_approx(scale[0], scale[1]):
			shearing.append(node)
	return shearing


## What the "inside something scaled" band says: the two nodes, the scale between them, and what
## that does to the numbers a row writes. The example is the reader's own arithmetic, done for them.
static func inside_reading(inside: Dictionary) -> String:
	var scale: PackedFloat32Array = inside["scale"]
	var factor: float = scale[0] if scale.size() > 0 else 1.0
	return EventSheetL10n.translate("%s is inside %s (scaled %s) - its own 10 is the world's %s") % [
		str((inside["node"] as Dictionary).get("name", "")),
		str((inside["ancestor"] as Dictionary).get("name", "")),
		_number(factor), _number(factor * 10.0)]


## THE mirroring warning, in one place, with the fix named: the engine's own answer to turning a
## sprite round is the sprite's flip switch, which leaves the shapes where they are.
static func mirrored_warning(node: Dictionary) -> String:
	return EventSheetL10n.translate("%s is mirrored by a negative scale - its shapes and raycasts flip with the art; flip the sprite instead") \
		% str(node.get("name", ""))


## THE shear warning: the two facts that make it, and what to scale instead.
static func shear_warning(node: Dictionary) -> String:
	var scale: PackedFloat32Array = _scale_of(node)
	return EventSheetL10n.translate("%s is scaled (%s, %s) and turned - it will shear; scale the art, not the collider") % [
		str(node.get("name", "")), _number(scale[0]), _number(scale[1])]


## The node's own line of the scene file, and the two properties the fact was read from.
static func band_echo(node: Dictionary, scene_path: String) -> String:
	var written: PackedStringArray = PackedStringArray(["%s: %s \"%s\"" % [scene_path.get_file(),
		str(node.get("type", "")), str(node.get("name", ""))]])
	for property: String in [SCALE_PROPERTY, ROTATION_PROPERTY]:
		var held: String = str((node.get("properties", {}) as Dictionary).get(property, "")).strip_edges()
		if not held.is_empty():
			written.append("%s = %s" % [property, held])
	return ", ".join(written)


# ── the pieces ──────────────────────────────────────────────────────────────────


static func _band(words: String, node: Dictionary, scene_path: String, warning: bool) -> Dictionary:
	return {"value": words, "echo": band_echo(node, scene_path),
		"reference": "%s|%s" % [scene_path, str(node.get("path", ""))], "warning": warning}


## The node of a scene that runs one script, {} when none does.
static func _node_running(nodes: Array, script_path: String) -> Dictionary:
	for entry: Variant in nodes:
		if str((entry as Dictionary).get("script_path", "")) == script_path:
			return entry
	return {}


static func _node_at(nodes: Array, node_path: String) -> Dictionary:
	for entry: Variant in nodes:
		if str((entry as Dictionary).get("path", "")) == node_path:
			return entry
	return {}


## A node's scale as its numbers, empty when the file never wrote one - which means the engine's
## default, which is not scaled at all.
static func _scale_of(node: Dictionary) -> PackedFloat32Array:
	return _numbers_in(str((node.get("properties", {}) as Dictionary).get(SCALE_PROPERTY, "")))


static func _rotation_of(node: Dictionary) -> float:
	return str((node.get("properties", {}) as Dictionary).get(ROTATION_PROPERTY, "0")).to_float()


## The numbers inside a written vector - `Vector2(2, 1)` -> [2, 1]. Empty for anything that is not
## one, so an expression nobody can evaluate simply says nothing rather than reading as zero.
static func _numbers_in(written: String) -> PackedFloat32Array:
	var numbers: PackedFloat32Array = PackedFloat32Array()
	var opening: int = written.find("(")
	if opening < 0 or not written.ends_with(")"):
		return numbers
	for part: String in written.substr(opening + 1, written.length() - opening - 2).split(","):
		var text: String = part.strip_edges()
		if not text.is_valid_float():
			return PackedFloat32Array()
		numbers.append(text.to_float())
	return numbers


## True when a scale is really a scale - far enough from 1 on any axis to change a number.
static func _is_scaled(scale: PackedFloat32Array) -> bool:
	for axis: float in scale:
		if absf(axis - 1.0) > TOLERANCE:
			return true
	return false


static func _is_a_body(node_class: String) -> bool:
	if node_class.is_empty() or not ClassDB.class_exists(node_class):
		return false
	for body_class: String in BODY_CLASSES:
		if ClassDB.is_parent_class(node_class, body_class):
			return true
	return false


## A number said the way a person says it: 2 rather than 2.0, 1.5 rather than 1.50.
static func _number(value: float) -> String:
	return String.num(value, 2).trim_suffix("0").trim_suffix("0").trim_suffix(".")
