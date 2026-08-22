# EventForge module - Facing: mirror and flip, on every host that can do it
#
# "Mirrored" is how a 2D character faces, and until now the sheet could only say it to a sprite. The
# same two words now reach every host, and each one emits the honest line for THAT host rather than a
# sprite line pointed somewhere it does not fit:
#
#   Sprite2D / AnimatedSprite2D / Sprite3D / TextureRect   flip_h = true          (the node has a flag)
#   any Node2D                                             scale.x = -1.0 if …    (the WHOLE object)
#   Node3D / Label3D                                       scale.x = -absf(…)     (flips the winding)
#   Node3D                                                 rotate_y(PI)           ("Turn around")
#   Control / SubViewportContainer                         pivot, then scale.x    (the pivot folded)
#   Camera2D                                               zoom.x negated         ("Mirror the view")
#   TileMapLayer                                           the cell's flip bit    ("Set tile flipped")
#   Path2D                                                 every point's x        ("Mirror path")
#
# The difference is not cosmetic: mirroring a SPRITE mirrors the picture and nothing else, while
# mirroring the object mirrors its children too - the hitbox, the muzzle point, the ray. That is why
# platformers write the scale line on a body node, and why the row that writes it says (whole object).
#
# Face Direction Of Movement and Face Object are the two idioms that line is nearly always written
# for, said once instead of copied; Keep Upright is the child that must NOT come along (a name plate,
# a health bar), re-negated so its text stays readable.
#
# Module contract: see ace_factory.gd - ace_ids/templates are API (compatibility covenant); this file
# only changes where the descriptors are AUTHORED.
@tool
class_name EventForgeFacingACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

## The picker page these rows are filed on. One page, because the question a reader arrives with is
## "how do I make this thing face the other way" and the answer differs only by which node they picked.
const PAGE := "Facing"

## The two parameter blurbs every host shares. Written once so the same question is asked in the same
## words on a sprite, a body, a camera and a tile - and so the translation carries one key, not twelve.
const MIRRORED_HELP := "Mirror it horizontally (facing left), or put it back the way it was."
const FLIPPED_HELP := "Turn it upside down, or put it back the right way up."

## The blank-target blurb the cross-node pass writes for every other node-scoped row. Repeated here
## verbatim for the one row that declares its own target (its template leads with `if`, so the pass
## skips it), which keeps the picker's wording identical either way.
const ON_NODE_HELP := "Act on another node instead of this one. Leave blank for this node, pick a node, or address one without a tree path - e.g. get_tree().get_first_node_in_group(\"player\")."


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []
	_flag_hosts(descriptors)
	_scale_hosts(descriptors)
	_idioms(descriptors)
	_other_hosts(descriptors)
	return descriptors


## The hosts that own a real flip flag. Four nodes, no common base class that has it, so each is its
## own row - which is exactly what makes the picker offer it only where the host can do it.
static func _flag_hosts(descriptors: Array[ACEDescriptor]) -> void:
	for host: String in ["Sprite2D", "Sprite3D", "TextureRect"]:
		descriptors.append(F.make_descriptor("Core", "SetMirrored" + host, "Set Mirrored",
			ACEDescriptor.ACEType.ACTION, "flip_h = {mirrored}", "",
			[F.make_param("mirrored", "String", "true", "Mirrored", MIRRORED_HELP, "", ["true", "false"])],
			PAGE, "Set mirrored {mirrored}", host)
			.described("Mirrors this node's picture left-to-right - the way a 2D character faces."))
	for host: String in ["Sprite3D", "TextureRect", "AnimatedSprite2D"]:
		descriptors.append(F.make_descriptor("Core", "SetFlipped" + host, "Set Flipped",
			ACEDescriptor.ACEType.ACTION, "flip_v = {flipped}", "",
			[F.make_param("flipped", "String", "true", "Flipped", FLIPPED_HELP, "", ["true", "false"])],
			PAGE, "Set flipped {flipped}", host)
			.described("Turns this node's picture upside down, or puts it back the right way up."))
	for host: String in ["Sprite2D", "AnimatedSprite2D", "Sprite3D", "TextureRect"]:
		descriptors.append(F.make_descriptor("Core", "IsMirrored" + host, "Is Mirrored",
			ACEDescriptor.ACEType.CONDITION, "flip_h", "", [], PAGE, "Is mirrored", host)
			.described("True while this node's picture is mirrored - which way the character is facing."))
		descriptors.append(F.make_descriptor("Core", "IsFlipped" + host, "Is Flipped",
			ACEDescriptor.ACEType.CONDITION, "flip_v", "", [], PAGE, "Is flipped", host)
			.described("True while this node's picture is upside down."))


## The hosts with no flag, where mirroring is the object's own X scale. The whole object turns, which
## is the point: its children - the hitbox, the muzzle, the ray - turn with it.
static func _scale_hosts(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.make_descriptor("Core", "SetMirroredObject", "Set Mirrored (whole object)",
		ACEDescriptor.ACEType.ACTION, "scale.x = -1.0 if {mirrored} else 1.0", "",
		[F.make_param("mirrored", "String", "true", "Mirrored", MIRRORED_HELP, "", ["true", "false"])],
		PAGE, "Set mirrored {mirrored} (whole object)", "Node2D")
		.described("Mirrors this object AND everything under it - the picture, the hitbox, the muzzle point and the ray all face the same way.").featured())
	descriptors.append(F.make_descriptor("Core", "IsMirroredObject", "Is Mirrored",
		ACEDescriptor.ACEType.CONDITION, "scale.x < 0.0", "", [], PAGE, "Is mirrored", "Node2D")
		.described("True while this object is mirrored, read off its own X scale."))
	descriptors.append(F.make_descriptor("Core", "SetMirroredSpatial", "Set Mirrored",
		ACEDescriptor.ACEType.ACTION, "scale.x = -absf(scale.x) if {mirrored} else absf(scale.x)", "",
		[F.make_param("mirrored", "String", "true", "Mirrored", MIRRORED_HELP, "", ["true", "false"])],
		PAGE, "Set mirrored {mirrored}", "Node3D")
		.described("Mirrors a 3D object along X. Worth knowing: a negative scale flips the mesh's winding, so lighting and backface culling see it inside out - Turn Around is usually what you want instead."))
	descriptors.append(F.make_descriptor("Core", "SetMirroredLabel3D", "Set Mirrored",
		ACEDescriptor.ACEType.ACTION, "scale.x = -absf(scale.x) if {mirrored} else absf(scale.x)", "",
		[F.make_param("mirrored", "String", "true", "Mirrored", MIRRORED_HELP, "", ["true", "false"])],
		PAGE, "Set mirrored {mirrored}", "Label3D")
		.described("Mirrors a 3D label along X - readable backwards, which is the point when it is a decal or a sign seen from behind."))
	descriptors.append(F.make_descriptor("Core", "IsMirroredSpatial", "Is Mirrored",
		ACEDescriptor.ACEType.CONDITION, "scale.x < 0.0", "", [], PAGE, "Is mirrored", "Node3D")
		.described("True while this 3D object is mirrored along X."))
	descriptors.append(F.make_descriptor("Core", "TurnAround", "Turn Around",
		ACEDescriptor.ACEType.ACTION, "rotate_y(PI)", "", [], PAGE, "Turn around", "Node3D")
		.described("Turns a 3D object to face the other way - half a turn about its up axis. The honest 3D answer to mirroring: nothing is inside out afterwards.").featured())


## The two lines the scale row is nearly always written for, and the child that must not come along.
static func _idioms(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.make_descriptor("Core", "FaceDirectionOfMovement", "Face Direction Of Movement",
		ACEDescriptor.ACEType.ACTION,
		"if {velocity}.x != 0.0:\n\t{target.}scale.x = -1.0 if {velocity}.x < 0.0 else 1.0", "",
		[F.make_param("velocity", "String", "velocity", "Velocity", "The value holding how fast this object is moving.", "expression"),
		F.make_param("target", "String", "", "On node", ON_NODE_HELP, "expression")],
		PAGE, "Face direction of movement", "CharacterBody2D")
		.described("Faces the way this object is moving, and leaves it facing that way when it stops - the one line every platformer writes by hand.").featured())
	descriptors.append(F.make_descriptor("Core", "FaceObject", "Face Object",
		ACEDescriptor.ACEType.ACTION,
		"scale.x = -1.0 if {object}.global_position.x < global_position.x else 1.0", "",
		[F.make_param("object", "String", "self", "Object", "The object to turn toward.", "expression")],
		PAGE, "Face {object}", "Node2D")
		.described("Turns this object to face another one - an enemy looking at the player, a shopkeeper looking at whoever walked in."))
	descriptors.append(F.make_descriptor("Core", "KeepUpright", "Keep Upright",
		ACEDescriptor.ACEType.ACTION, "{target}.scale.x = signf(scale.x)", "",
		[F.make_param("target", "String", "$Label", "Child", "The child that must stay readable - a name plate, a health bar, a damage number.", "expression")],
		PAGE, "Keep {target} upright", "Node2D")
		.described("Re-negates a child's X scale so it does NOT come along when this object mirrors - what keeps a name plate readable instead of writing it backwards."))


## Everything else that can mirror: the UI, the view, one tile, and a path.
static func _other_hosts(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.make_descriptor("Core", "SetMirroredControl", "Set Mirrored",
		ACEDescriptor.ACEType.ACTION,
		"{target.}pivot_offset.x = {target.}size.x * 0.5\n{target.}scale.x = -1.0 if {mirrored} else 1.0", "",
		[F.make_param("mirrored", "String", "true", "Mirrored", MIRRORED_HELP, "", ["true", "false"]),
		F.make_param("target", "String", "", "On node", ON_NODE_HELP, "expression")],
		PAGE, "Set mirrored {mirrored}", "Control")
		.described("Mirrors a UI element in place. The pivot is moved to its middle first, which is the half everyone forgets - without it the panel mirrors AND jumps sideways."))
	descriptors.append(F.make_descriptor("Core", "IsMirroredControl", "Is Mirrored",
		ACEDescriptor.ACEType.CONDITION, "scale.x < 0.0", "", [], PAGE, "Is mirrored", "Control")
		.described("True while this UI element is mirrored."))
	descriptors.append(F.make_descriptor("Core", "MirrorTheView", "Mirror The View",
		ACEDescriptor.ACEType.ACTION, "zoom.x = -absf(zoom.x) if {mirrored} else absf(zoom.x)", "",
		[F.make_param("mirrored", "String", "true", "Mirrored", MIRRORED_HELP, "", ["true", "false"])],
		PAGE, "Mirror the view {mirrored}", "Camera2D")
		.described("Mirrors everything this camera sees - a mirror world, a reflection, a level played backwards."))
	descriptors.append(F.make_descriptor("Core", "MirrorViewportView", "Mirror The View",
		ACEDescriptor.ACEType.ACTION,
		"{target.}pivot_offset.x = {target.}size.x * 0.5\n{target.}scale.x = -1.0 if {mirrored} else 1.0", "",
		[F.make_param("mirrored", "String", "true", "Mirrored", MIRRORED_HELP, "", ["true", "false"]),
		F.make_param("target", "String", "", "On node", ON_NODE_HELP, "expression")],
		PAGE, "Mirror the view {mirrored}", "SubViewportContainer")
		.described("Mirrors what a sub-viewport shows - the rear-view mirror, the security monitor, the reflection in the water."))
	descriptors.append(F.make_descriptor("Core", "SetTileFlipped", "Set Tile Flipped",
		ACEDescriptor.ACEType.ACTION,
		"{target.}set_cell({coords}, {target.}get_cell_source_id({coords}), {target.}get_cell_atlas_coords({coords}), TileSetAtlasSource.TRANSFORM_FLIP_H if {mirrored} else 0)", "",
		[F.make_param("coords", "String", "Vector2i(0, 0)", "Cell", "Cell coordinates (Vector2i).", "expression"),
		F.make_param("mirrored", "String", "true", "Mirrored", MIRRORED_HELP, "", ["true", "false"]),
		F.make_param("target", "String", "", "On node", ON_NODE_HELP, "expression")],
		PAGE, "Set tile at {coords} flipped {mirrored}", "TileMapLayer")
		.described("Mirrors the tile already sitting at a cell, keeping its tileset and its tile - how one wall art asset covers both sides of a corridor."))
	descriptors.append(F.make_descriptor("Core", "MirrorPath", "Mirror Path",
		ACEDescriptor.ACEType.ACTION,
		"for __point_{uid}: int in curve.point_count:\n\tcurve.set_point_position(__point_{uid}, Vector2(-curve.get_point_position(__point_{uid}).x, curve.get_point_position(__point_{uid}).y))", "",
		[], PAGE, "Mirror path", "Path2D")
		.described("Mirrors every point of this path about x = 0 - the second half of a symmetric level, or a patrol route reused facing the other way."))



## The picker's blurb for the page these rows are filed on.
static func section_descriptions() -> Dictionary:
	return {
		PAGE: "Which way something faces. Mirror or flip a sprite, a whole object with its hitbox and its ray, a 3D model, a UI panel, the camera's view, one tile, or a path - each host in its own honest terms."
	}
