# EventForge module - bones: pointing one at something, asking where one is, and holding one in a
# pose the animation did not ask for.
#
# A rig is the one part of an animated character the event sheet could not reach. Everything else
# about an animation is a clip name or a blend value; a bone is an index inside a skeleton, and the
# three things a game actually does with one are:
#
#   POINT IT     the head that follows the lock-on, the gun arm that tracks the crosshair. In 3D that
#                is the engine's own LookAtModifier3D, a node under the skeleton whose four dials are
#                exactly bone, target, how long and how much - so the row SETS those dials rather
#                than doing the maths itself, and the modifier keeps doing it every frame after.
#   ASK WHERE    the muzzle flash that has to appear at the hand, the icon that floats over the head.
#                A bone's pose is in skeleton space, so the row multiplies it back out into the
#                world - which is the line everyone gets wrong the first time.
#   HOLD IT      the hit reaction that twists the spine for a moment over whatever is playing. An
#                override with a strength, so it mixes with the animation instead of fighting it.
#
# 2D AND 3D. In 3D a bone is an index in a Skeleton3D and a name resolves to one with `find_bone`;
# in 2D a bone IS a node - a Bone2D under the Skeleton2D - so the 2D rows are node-scoped on Bone2D
# and address it the way every other 2D row addresses a node. The words are the same in both.
#
# Compiles to plain Godot with zero plugin references.
@tool
class_name EventForgeSkeletonACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

const CAT := "Skeleton"


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []
	_pointing(descriptors)
	_reading(descriptors)
	_overrides(descriptors)
	return descriptors


## ── pointing a bone at something ────────────────────────────────────────────────────────────────
##
## The 3D row is four assignments on the engine's own modifier, and that is the whole point of it: a
## LookAtModifier3D already knows how to ease into a look, how to stop at the neck's limits and how
## to blend out again, and none of that is worth writing again in a template. The row says which bone,
## what to look at, how long the ease takes and how much of it to apply; the modifier does the rest,
## every frame, whether or not the sheet asks again.
##
## The 2D twin has no modifier to lean on, so it does the one line the modifier would have done: turn
## the bone toward the thing, a fraction of the way each frame, where the fraction is this frame's
## share of the seconds asked for. Left at a whole weight of 1 over a very short time it snaps; over
## half a second it eases, and it keeps easing as long as the row is asked.
static func _pointing(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.act("PointBoneAt3D", "Point Bone At", "{target.}bone_name = {bone}\n{target.}target_node = {target.}get_path_to({node})\n{target.}duration = {seconds}\n{target.}influence = {weight}", CAT, "point {bone} at {node}", "Aims one bone at a node and keeps aiming - the head that follows the target you locked, the turret that tracks the player. It sets up the engine's own look-at modifier, which then does the aiming every frame, easing in over the time you give it. The modifier node has to be under the skeleton already; this row is the sheet's hand on its dials.", "LookAtModifier3D").param("bone", "\"Head\"", "Bone", "The bone that turns, by the name the skeleton gives it.").param_typed("Node", "node", "self", "At", "The node to aim at.", "scene_node").param("seconds", "0.2", "Over", "How long the turn eases over, in seconds.", "expression").param("weight", "1.0", "Weight", "How much of the aim is applied: 0 for none of it, 1 for all of it.", "expression").param("target", "", "On node", "Set up another LookAtModifier3D instead of this one. Leave blank for this node.", "expression").featured())
	descriptors.append(F.act("PointBoneAt2D", "Point Bone At", "{target.}global_rotation = lerp_angle({target.}global_rotation, ({node}.global_position - {target.}global_position).angle(), clampf(delta / maxf({seconds}, 0.001), 0.0, 1.0) * {weight})", CAT, "point this bone at {node}", "Turns this bone toward a node, a frame's worth at a time - the head that follows the player, the arm that tracks the cursor. Asked every tick it eases over the seconds you give it; the weight is how much of the way it is allowed to get.", "Bone2D").param_typed("Node", "node", "self", "At", "The node to aim at.", "scene_node").param("seconds", "0.2", "Over", "How long the turn eases over, in seconds.", "expression").param("weight", "1.0", "Weight", "How much of the aim is applied: 0 for none of it, 1 for all of it.", "expression").param("target", "", "On node", "Turn another Bone2D instead of this one. Leave blank for this node.", "expression").featured())


## ── where a bone is ─────────────────────────────────────────────────────────────────────────────
##
## The 3D answer is the line that catches everybody: `get_bone_global_pose` is global to the
## SKELETON, not to the world, so a muzzle flash placed at it appears wherever the skeleton's own
## origin happens to be. The row multiplies it back out by the skeleton's transform, which is what
## makes the number mean what its name says.
##
## The 2D answer needs no such correction - a Bone2D is a Node2D and knows where it is - and the row
## exists for the SENTENCE rather than for the arithmetic: an event that spawns a shell at the hand
## should say "at the hand", not "at that node over there".
static func _reading(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.expr("BonePosition3D", "Bone Position", "({target.}global_transform * {target.}get_bone_global_pose({target.}find_bone({bone}))).origin", CAT, "position of {bone}", "Where one bone is in the world right now - the hand a weapon hangs off, the head a name tag floats over. The skeleton answers in its own space, so this reads it back out into the world's; a raw bone pose put straight onto a node lands in the wrong place.", "Skeleton3D").param("bone", "\"Head\"", "Bone", "The bone to ask about, by the name the skeleton gives it.").param("target", "", "On node", "Ask another Skeleton3D instead of this one. Leave blank for this node.", "expression").featured())
	descriptors.append(F.expr("BonePosition2D", "Bone Position", "{target.}global_position", CAT, "position of this bone", "Where this bone is in the world right now - the hand a shell drops from, the head a name tag floats over.", "Bone2D").param("target", "", "On node", "Ask another Bone2D instead of this one. Leave blank for this node.", "expression"))


## ── holding a bone somewhere the animation did not put it ───────────────────────────────────────
##
## An override is not a pose: it is a pose AND a strength, mixed over whatever the animation is
## already doing. That is what makes it the shape a hit reaction wants - the spine twists a little
## while the run keeps running - and it is why the row asks for the strength rather than assuming it.
## Setting the strength back to 0 hands the bone back to the animation.
static func _overrides(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.act("SetBonePoseOverride", "Set Bone Pose Override", "{target.}set_bone_global_pose_override({target.}find_bone({bone}), {pose}, {amount}, true)", CAT, "hold {bone} at {pose}", "Holds one bone in a pose of your own over whatever the animation is playing - the spine that twists on a hit, the head that stays level on a slope. The amount is how much of your pose wins: 1 for all of it, 0 to give the bone back to the animation.", "Skeleton3D").param("bone", "\"Head\"", "Bone", "The bone to hold, by the name the skeleton gives it.").param_typed("Transform3D", "pose", "Transform3D.IDENTITY", "Pose", "The pose to hold it in, in the world's own space.", "expression").param("amount", "1.0", "Amount", "How much of your pose wins over the animation: 1 for all of it, 0 for none.", "expression").param("target", "", "On node", "Hold a bone of another Skeleton3D instead. Leave blank for this node.", "expression"))
	descriptors.append(F.act("SetBonePoseOverride2D", "Set Bone Pose Override", "{target.}set_bone_local_pose_override({bone}, {pose}, {amount}, true)", CAT, "hold bone {bone} at {pose}", "Holds one bone in a pose of your own over whatever the animation is playing - the arm that stays out while the walk keeps walking. The amount is how much of your pose wins: 1 for all of it, 0 to give the bone back to the animation.", "Skeleton2D").param("bone", "0", "Bone", "Which bone of this skeleton, counted from 0 in the order the Bone2D nodes are under it.", "expression").param_typed("Transform2D", "pose", "Transform2D.IDENTITY", "Pose", "The pose to hold it in, relative to its parent bone.", "expression").param("amount", "1.0", "Amount", "How much of your pose wins over the animation: 1 for all of it, 0 for none.", "expression").param("target", "", "On node", "Hold a bone of another Skeleton2D instead. Leave blank for this node.", "expression"))


static func section_descriptions() -> Dictionary:
	return {CAT: "Bones: point one at a node and keep it pointed, ask where one is in the world, and hold one in a pose of your own over whatever the animation is playing. 3D rows work through the skeleton and the engine's look-at modifier; the 2D twins are node-scoped on Bone2D, because in 2D a bone is a node."}
