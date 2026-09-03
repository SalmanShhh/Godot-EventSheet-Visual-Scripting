# EventForge module - the rest of the Camera3D shelf (aim, projection, clip range, the cursor ray).
#
# Three Camera3D rows shipped first (make current, set the field of view, and the field-of-view
# toolkit beside it), which between them say "look through this one" and "how wide". What they leave
# out is the rest of what a 3D camera is asked to do in a game: turn to look at something over time
# rather than instantly, swap between a perspective shot and a flat one, decide how near and how far
# it can see, and answer the two questions every point-and-click, build-menu and strategy game asks
# fifty times a second - is the cursor over anything, and where in the world is it pointing.
#
# WHY LOOK AT OVER SECONDS IS ITS OWN VERB, BESIDE THE SHIPPED LOOK AT. The shipped Look At turns a
# Node3D to face a point THIS FRAME, and that is the right row for a turret. A camera that snaps is a
# cut; a camera that turns is a shot. The two are different verbs, so this is a different row rather
# than a duration parameter bolted onto a frozen one.
#
# AND WHY IT TWEENS A BASIS RATHER THAN AN ANGLE. Interpolating euler angles between two orientations
# is the classic way to make a camera roll sideways on its way to a target, and it gets worse the
# closer the look direction is to straight up. Basis.slerp walks the shortest rotation between the
# two orientations instead, which is the turn a person means. The whole of it is four plain lines in
# the emitted script - a from, a to, and a tween of the weight between them - so it stays readable,
# stays editable, and needs nothing from this plugin at runtime. The guard in front of it is the same
# one the safe-up Look At carries: a target sitting exactly where the camera is has no direction to
# face, and asking for one is an engine error rather than a shrug.
#
# THE CURSOR RAY, AND WHAT IS ALREADY HERE. The raycast vocabulary already answers the cursor
# question from THE ACTIVE camera: Mouse Ray Hits Something, Mouse Ray Collider and Mouse Ray Point
# cast from whichever camera is live, and Cast Ray From Mouse Into stores a whole hit for repeated
# reading. The two rows here are the same question asked BY A CAMERA, of ITS OWN viewport, with the
# collision layers to test named on the row - which is what a split-screen game, an editor viewport
# or a picture-in-picture minimap needs, because "the active camera" is not the camera the click
# happened in. There is no side channel handing a hit down to the rows underneath: the answers are
# expressions, so a row that wants the object under the cursor asks Mouse Ray Collider for it and a
# row that wants several facts about one hit uses Cast Ray From Mouse Into. That is deliberate - a
# hidden "last hit" would be wrong the moment two cameras, or two clicks in one frame, existed.
#
# POINT UNDER THE CURSOR ANSWERS EVEN WHEN NOTHING IS HIT, and answers with the far end of the ray
# rather than with zero. A build ghost, a move-order marker and a camera pan all want somewhere to
# be; the origin of the world is never that somewhere, and a marker that teleports to it is a bug
# that looks like a physics problem. The far point is where the player is pointing, which is what
# was asked.
#
# Module contract: see ace_factory.gd - ace_ids/templates are API (compatibility covenant); this file
# only changes where the descriptors are AUTHORED.
@tool
class_name EventForgeCamera3DACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

## The shelf these rows join: the same one the shipped Camera2D rows and the field-of-view rows sit
## on, so a camera page is one page rather than three.
const CAT: String = "Camera"

## The ray under the cursor, in this camera's OWN viewport, as the two ends a physics query takes.
## Written once and spliced into both cursor rows because they are the same ray asked two ways, and a
## reader comparing them should be able to see that they cannot drift apart.
const CURSOR_RAY_FROM: String = "project_ray_origin(get_viewport().get_mouse_position())"
const CURSOR_RAY_TO: String = "project_ray_origin(get_viewport().get_mouse_position()) + project_ray_normal(get_viewport().get_mouse_position()) * {reach}"

## The whole query, ready to be asked of the world: the ray above, the reach and the layers off the
## row. `intersect_ray` hands back an empty Dictionary when it finds nothing, which is what both rows
## below read their answer out of.
const CURSOR_QUERY: String = "get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(" + CURSOR_RAY_FROM + ", " + CURSOR_RAY_TO + ", {layers}))"


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	# ── Turning to face something, as a shot rather than a cut ─────────────────────────
	# A `var` leads this template, so it is never handed the optional cross-node prefix - it is a
	# self-verb, and the camera it turns is the one the sheet is on.
	descriptors.append(F.act("CameraLookAtOverSeconds", "Look At Over Seconds", "var __aim_{uid}: Vector3 = {at}.global_position - global_position\nif __aim_{uid}.length_squared() > 0.000001:\n\tvar __from_{uid}: Basis = global_basis\n\tvar __to_{uid}: Basis = Basis.looking_at(__aim_{uid}, Vector3.UP)\n\tcreate_tween().tween_method(func(__weight_{uid}: float) -> void: global_basis = __from_{uid}.slerp(__to_{uid}, __weight_{uid}), 0.0, 1.0, maxf({seconds}, 0.001))", CAT, "Look at [i]{at}[/i] over {seconds}s", "Turns the camera to face a node over time instead of snapping to it - the difference between a cut and a shot. It walks the shortest rotation between where the camera is looking and where it should look, so it never rolls sideways on the way and never tips over when the target is nearly overhead. A target sitting exactly where the camera is has no direction to face, so the row does nothing at all rather than erroring.", "Camera3D").param("at", "$Player", "Look At", "The node to turn towards.", "scene_node").param_typed("float", "seconds", "0.6", "Over", "How long the turn takes.", "expression").featured())

	# ── Which kind of shot this is ─────────────────────────────────────────────────────
	# Two rows rather than one with a mode, because the second field is a different question in each:
	# a perspective camera is described by an angle and a flat one by a width, and a single row would
	# have to show both and mean one.
	descriptors.append(F.act("CameraSwitchToPerspective", "Switch To Perspective", "projection = Camera3D.PROJECTION_PERSPECTIVE\nfov = {degrees}", CAT, "Switch to perspective at {degrees}", "Puts the camera into the ordinary shot, where things further away look smaller, and sets how wide it sees. This is the projection a first- or third-person game uses.", "Camera3D").param_typed("float", "degrees", "75.0", "Field Of View", "How wide the camera sees, in degrees. Lower zooms in.", "expression"))
	descriptors.append(F.act("CameraSwitchToOrthogonal", "Switch To Orthogonal", "projection = Camera3D.PROJECTION_ORTHOGONAL\nsize = {size}", CAT, "Switch to orthogonal at {size}", "Puts the camera into the flat shot, where distance does not shrink anything - the projection an isometric strategy game, a builder's blueprint view or a 2.5D platformer wants. The size is how many world units tall the view is, so a smaller number zooms in.", "Camera3D").param_typed("float", "size", "10.0", "Height", "How many world units tall the view is. Smaller zooms in.", "expression"))
	descriptors.append(F.act("CameraSetClipRange", "Set Clip Range", "near = {near}\nfar = {far}", CAT, "Set clip range {near} to {far}", "Sets how close and how far the camera can see. Nothing nearer than the near value or further than the far value is drawn at all. Push the far value out for a long view, and keep the near value as large as the game allows - a very small near value is the usual cause of surfaces flickering against each other in the distance.", "Camera3D").param_typed("float", "near", F.default_literal("Camera3D", "near"), "Near", "The closest distance the camera draws, in metres.", "expression").param_typed("float", "far", F.default_literal("Camera3D", "far"), "Far", "The furthest distance the camera draws, in metres.", "expression"))

	# ── The camera the player is looking through ───────────────────────────────────────
	# Host-free on purpose: any sheet may ask which camera is live, and a row scoped to Camera3D
	# could only be asked by the camera itself, which already knows.
	descriptors.append(F.expr("CurrentCamera3D", "Current Camera (3D)", "get_viewport().get_camera_3d()", CAT, "the current camera (3D)", "The Camera3D the player is looking through right now, or nothing when there is none. The twin of Current Camera, for the dimension where the active camera changes on every cutscene and every vehicle you climb into."))

	# ── The cursor ray, asked by THIS camera of ITS OWN viewport ───────────────────────
	# Both lead with a bracket, so neither is handed the optional cross-node prefix: every call in
	# them is already this camera's, and a prefix would only reach the first of them.
	descriptors.append(F.cond("CameraCursorOverSomething", "Something Is Under The Cursor", "(not " + CURSOR_QUERY + ".is_empty())", CAT, "something is under the cursor within {reach}", "True when the cursor is pointing at something solid, asked by THIS camera of its own viewport - which is the question a split-screen game or a picture-in-picture view has to ask, because the active camera is not the camera the pointer is in. Name the collision layers to keep scenery, triggers or the player's own body out of the answer. For the object itself use Mouse Ray Collider, and for several facts about one hit use Cast Ray From Mouse Into.", "Camera3D").param_typed("float", "reach", "1000.0", "Reach", "How far into the scene to look, in metres.", "expression").param("layers", "4294967295", "Layers", "Collision layers to test against. Each layer is a bit, so layers 1 and 3 are 1 + 4 = 5; the default sees every layer.", "expression").featured())
	descriptors.append(F.expr("CameraPointUnderCursor", "Point Under The Cursor", "(" + CURSOR_QUERY + ".get(\"position\", " + CURSOR_RAY_TO + "))", CAT, "the point under the cursor within {reach}", "Where in the world the cursor is pointing: the surface it lands on, or the far end of the ray when it lands on nothing. It answers with somewhere the player is actually pointing rather than with the origin of the world, which is what a build ghost, a move-order marker or a camera pan needs - a marker that teleports to zero looks like a physics bug and is not one.", "Camera3D").param_typed("float", "reach", "1000.0", "Reach", "How far into the scene to look, in metres.", "expression").param("layers", "4294967295", "Layers", "Collision layers to test against. Each layer is a bit, so layers 1 and 3 are 1 + 4 = 5; the default sees every layer.", "expression"))

	return descriptors
