# EventForge module - the world-space twins of the verbs that wrote the wrong place.
#
# Godot has two places a node can be put. `position` is measured from the node's PARENT, so the same
# number lands somewhere different under every parent. `global_position` is the place in the level,
# whoever the parent is. A handful of shipped verbs wrote `position` where the thing they work with is
# a place in the level (the screen's edges, the layout's edges, a destination another node stands at,
# a push worked out in the world's directions, a copy spawned at a world place). Under the scene root
# the two are the same number; under any moved, rotated or scaled parent the verb lands in the wrong
# spot.
#
# THE COMPATIBILITY RULE. A shipped ace_id, template and kind id never move, so nothing here edits one.
# Each verb that wrote the wrong space is DEPRECATED where it is declared (hidden from the picker, still
# compiling and reading byte for byte) and points at the twin below, which writes global_position. The
# locals that are right for their job (Set Position, Move By, Bob) are untouched: this module adds the
# world spelling beside them and says "world" on the row.
#
# WORDS. X / Y / Z is a place inside the parent; "world X" / "world Y" / "world Z" and "world position"
# is the place in the level. The same words the row grammar uses for a written `position.x` and
# `global_position.x`.
#
# The three Set World Position rows write `set_global_position(...)` rather than `global_position = ...`
# on purpose: the reverse lifter claims a hand-written line by its template, and `x.global_position = v`
# is already read by rows that look for it as a plain property write (the pin shapes, the spawn trio).
# A twin that claimed those lines would take the reading away from them.
#
# This module sorts late on purpose: the reverse lifter breaks a tie between two equally specific
# templates in registry order, so a twin here never takes a line away from an older verb that already
# claims it.
#
# Module contract: see ace_factory.gd - ace_ids/templates are API (compatibility covenant).
@tool
class_name EventForgeWorldPlaceACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")
const SPAWN := preload("res://addons/eventforge/registration/modules/spawn_aces.gd")

const CAT_PLACE: String = "General Actions"
const CAT_GET: String = "General Expressions"
const CAT_MOVEMENT: String = "Movement"
const CAT_MOVE_TO: String = "Move To"
const CAT_LAYOUT: String = "Scene Edges"
const CAT_SCENE: String = "Scene"
const CAT_UI: String = "UI"

## The axes a place has, per dimension.
const AXES_2D: PackedStringArray = ["x", "y"]
const AXES_3D: PackedStringArray = ["x", "y", "z"]


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []
	_append_set_world_position(descriptors)
	_append_get_place(descriptors)
	_append_move_twins(descriptors)
	_append_bound_twins(descriptors)
	_append_spawn_twins(descriptors)
	_append_control_place(descriptors)
	return descriptors


## Set World Position, 2D and 3D, and the 2D twin of Set Position To Another Object. The local Set
## Position rows stay as they are and read "Set position", relative to the parent.
static func _append_set_world_position(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.act("SetWorldPosition2D", "Set World Position", "set_global_position({pos})", CAT_PLACE, "Set world position to {pos}", "Places a 2D node at an exact place in the level, whoever its parent is. Set Position measures from the parent instead.", "Node2D").param("pos", "Vector2(0, 0)", "Position", "Target place in the level as a Vector2 expression.", "expression"))
	descriptors.append(F.act("SetWorldPosition3D", "Set World Position (3D)", "set_global_position({pos})", CAT_PLACE, "Set world position to {pos}", "Teleports a 3D node to an exact place in the level, whoever its parent is. Set Position (3D) measures from the parent instead.", "Node3D").param("pos", "Vector3(0, 0, 0)", "Position", "Target place in the level as a Vector3 expression.", "expression"))
	descriptors.append(F.act("SetPositionToObject2D", "Set Position To Another Object", "global_position = {other}.global_position", CAT_PLACE, "Set world position to [b]{other}[/b]", "Puts a 2D node exactly where another one is in the level - how a spawn point, a socket or a respawn marker is used.", "Node2D").param("other", "self", "Other", "The object to stand where - a spawn marker, a socket, another character.", "expression"))


## The place read back: X / Y / Z inside the parent, "world X" / "world Y" / "world Z" in the level, and
## the whole level place. Place Of stays as the node-reading spelling of the same world place.
static func _append_get_place(descriptors: Array[ACEDescriptor]) -> void:
	for axis: String in AXES_2D:
		descriptors.append(F.expr("GetPosition%s2D" % axis.to_upper(), "Get %s" % axis.to_upper(), "position.%s" % axis, CAT_GET, axis.to_upper(), "Returns the %s of the node's place inside its parent, in pixels." % axis.to_upper(), "Node2D"))
		descriptors.append(F.expr("GetWorld%s2D" % axis.to_upper(), "Get World %s" % axis.to_upper(), "global_position.%s" % axis, CAT_GET, "world %s" % axis.to_upper(), "Returns the %s of the node's place in the level, whoever its parent is." % axis.to_upper(), "Node2D"))
	descriptors.append(F.expr("GetWorldPosition2D", "Get World Position", "global_position", CAT_GET, "world position", "Returns the node's place in the level as a Vector2, whoever its parent is.", "Node2D"))
	for axis: String in AXES_3D:
		descriptors.append(F.expr("GetPosition%s3D" % axis.to_upper(), "Get %s (3D)" % axis.to_upper(), "position.%s" % axis, CAT_GET, axis.to_upper(), "Returns the %s of the node's place inside its parent." % axis.to_upper(), "Node3D"))
		descriptors.append(F.expr("GetWorld%s3D" % axis.to_upper(), "Get World %s (3D)" % axis.to_upper(), "global_position.%s" % axis, CAT_GET, "world %s" % axis.to_upper(), "Returns the %s of the node's place in the level, whoever its parent is." % axis.to_upper(), "Node3D"))
	descriptors.append(F.expr("GetWorldPosition3D", "Get World Position (3D)", "global_position", CAT_GET, "world position", "Returns the node's place in the level as a Vector3, whoever its parent is.", "Node3D"))


## Gliding toward a point and applying pushes: both work in the level's directions, so both write the
## place in the level.
static func _append_move_twins(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.act("GlideTowardWorld", "Move Toward Position", "{host.}global_position = {host.}global_position.move_toward({destination}, {speed} * {delta_t})", CAT_MOVE_TO, "Move toward {destination} at {speed}", "Glides this frame's share of the way toward a place in the level, never overshooting it. The place is measured in the level, so a node under a moved parent still arrives at it.", "Node2D").param("destination", "Vector2.ZERO", "Destination", "The place in the level to glide toward.", "expression").param("speed", "200.0", "Speed", "Pixels per second.", "expression").param("delta_t", "delta", "Delta", "Frame time; defaults to `delta`.", "expression"))
	descriptors.append(F.act("ApplyPushesWorld", "Apply Pushes", "var __push_{uid}: Vector2 = get_meta(&\"__ef_push\", Vector2.ZERO)\nif __push_{uid}.length_squared() > 0.01:\n\tglobal_position += __push_{uid} * get_process_delta_time()\n\tset_meta(&\"__ef_push\", __push_{uid} * exp(-maxf({friction}, 0.0) * get_process_delta_time()))", CAT_MOVEMENT, "apply pushes ( friction {friction} )", "Knockback that decays honestly (the exp form, frame-rate independent) - one row under On Process. The push is worked out in the level's directions and added to the node's place in the level, so it is right under a rotated or scaled parent.", "Node2D").param("friction", "8.0", "Friction", "How fast the push dies away; bigger stops sooner.", "expression"))


## Wrapping and bounding against the screen and the layout. Both are rectangles in the level, so the
## node's place in the level is what is compared with them.
static func _append_bound_twins(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.act("WrapInsideScreenWorld", "Wrap Inside The Screen", "var __wrap_size_{uid}: Vector2 = get_viewport_rect().size\nglobal_position = Vector2(wrapf(global_position.x, 0.0, __wrap_size_{uid}.x), wrapf(global_position.y, 0.0, __wrap_size_{uid}.y))", CAT_MOVEMENT, "wrap inside the screen", "The Asteroids rule: leave the right edge and come back on the left, off the top and back at the bottom. Nothing ever escapes the screen. The node's place in the level is what wraps, so a node under a moved parent wraps at the screen's edges.", "Node2D"))
	descriptors.append(F.act("WrapAroundLayoutXWorld", "Wrap Around Scene Horizontally", "{host.}global_position.x = wrapf({host.}global_position.x, {low}, {high})", CAT_LAYOUT, "Wrap around scene horizontally", "Sends the object off one side of the scene and back in the other - the arcade wrap. The scene's edges are places in the level, so the node's place in the level is what wraps.", "Node2D").param("low", "0.0", "Left edge", "The left edge of the scene, in pixels.", "expression").param("high", "1152.0", "Right edge", "The right edge of the scene, in pixels.", "expression"))
	descriptors.append(F.act("WrapAroundLayoutYWorld", "Wrap Around Scene Vertically", "{host.}global_position.y = wrapf({host.}global_position.y, {low}, {high})", CAT_LAYOUT, "Wrap around scene vertically", "Sends the object off the top of the scene and back in at the bottom, or the other way round. The scene's edges are places in the level, so the node's place in the level is what wraps.", "Node2D").param("low", "0.0", "Top edge", "The top edge of the scene, in pixels.", "expression").param("high", "648.0", "Bottom edge", "The bottom edge of the scene, in pixels.", "expression"))
	descriptors.append(F.act("BoundToLayoutWorld", "Bound To Scene", "{host.}global_position = {host.}global_position.clamp({low}, {high})", CAT_LAYOUT, "Bound to scene (inside {low} - {high})", "Holds the object inside the scene's edges instead of letting it leave - the arcade fence. The scene's edges are places in the level, so the node's place in the level is what is held.", "Node2D").param("low", "Vector2.ZERO", "Top left", "The top-left corner of the level the object is kept inside.", "expression").param("high", "Vector2(1152, 648)", "Bottom right", "The bottom-right corner of the level the object is kept inside.", "expression"))


## The safe spawn that lands where it was told, and a spawn of a scene file into the level. A copy that
## is not in the tree yet has no global place, so the place is booked to be set right after the copy is
## added: both calls wait for the same idle moment and run in the order they were booked.
static func _append_spawn_twins(descriptors: Array[ACEDescriptor]) -> void:
	var safely: String = "var {name} = {scene}.instantiate()\n{parent}.call_deferred(\"add_child\", {name})\n{name}.call_deferred(\"set_global_position\", {at})"
	descriptors.append(F.act("SpawnNewCopyDeferredWorld", "Spawn A Copy Safely", safely, SPAWN.CATEGORY, "Spawn a copy of [b]{scene}[/b] as [b]{name}[/b] at {at}, under [i]{parent}[/i], added on the next idle moment", "The same spawn as Spawn A Copy, added on the next idle moment instead of right now. Use it inside a collision or body handler: a 2D physics body or area added there makes Godot print an error while the physics server is busy (the node is still added and works), and this row waits for it to finish so nothing is printed. The place is a place in the level, set right after the copy is added, so it lands there whoever the parent is.", "Node2D").param_built(SPAWN._scene_param()).param_built(SPAWN._name_param()).param_built(SPAWN._at_param()).param_built(SPAWN._parent_param()))
	descriptors.append(F.act("SpawnNewCopyDeferredWorld3D", "Spawn A Copy Safely (3D)", safely, SPAWN.CATEGORY, "Spawn a copy of [b]{scene}[/b] as [b]{name}[/b] at {at}, under [i]{parent}[/i], added on the next idle moment", "The same 3D spawn as Spawn A Copy (3D), added on the next idle moment instead of right now. Use it inside a collision or body handler: a 2D physics body or area added there makes Godot print an error while the physics server is busy (the node is still added and works), and this row waits for it to finish so nothing is printed. The place is a place in the level, set right after the copy is added, so it lands there whoever the parent is.", "Node3D").param_built(SPAWN._scene_param()).param_built(SPAWN._name_param()).param_built(SPAWN._at_param_3d()).param_built(SPAWN._parent_param()))
	descriptors.append(F.act("SpawnSceneInWorld", "Spawn Scene In The World", "var __spawn_{uid} = load({path}).instantiate()\nget_tree().current_scene.add_child(__spawn_{uid})\n__spawn_{uid}.global_position = {position}", CAT_SCENE, "Spawn {path} in the level at {position}", "Loads a scene and drops a copy into the current scene at a place in the level. Spawn Scene At adds the copy under this node and measures its place from this node instead.").param("path", "\"res://enemy.tscn\"", "Scene", "Scene file to instance.", "scene_path").param("position", "Vector2(0, 0)", "Position", "Place in the level to spawn at.", "expression"))


## A UI Control's place and size. A Control sits inside a parent box: its position is measured from that
## box's top-left corner, and its anchors and offsets (or a container) can move it again after the
## write. Set Anchors Preset ships beside these in ui_aces.gd. Set Control Size writes `set_size(...)`
## rather than `size = ...` on purpose: the reverse lifter claims a line by its template, and `size = value`
## belongs to every node that has a size (a viewport, a mesh, a camera), none of which is a Control.
static func _append_control_place(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.act("SetControlPosition", "Set Control Position", "position = {pos}", CAT_UI, "Set position to {pos}", "Places a control inside its parent box, measured from the box's top-left corner. A container or an anchors preset can move it again afterwards.", "Control").param("pos", "Vector2(0, 0)", "Position", "Where inside the parent box, from its top-left corner.", "expression"))
	descriptors.append(F.act("SetControlWorldPosition", "Set Control World Position", "set_global_position({pos})", CAT_UI, "Set world position to {pos}", "Places a control at an exact place on the screen's canvas, whatever box it sits in.", "Control").param("pos", "Vector2(0, 0)", "Position", "Where on the canvas, from the top-left corner of the screen.", "expression"))
	descriptors.append(F.act("SetControlSize", "Set Control Size", "set_size({size})", CAT_UI, "Set size to {size}", "Sets how big a control is, in pixels. A container, or anchors that stretch it, can override the size afterwards.", "Control").param("size", "Vector2(100, 100)", "Size", "Width and height in pixels.", "expression"))
