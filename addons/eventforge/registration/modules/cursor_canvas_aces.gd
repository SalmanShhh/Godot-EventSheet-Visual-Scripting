# EventForge module - what the cursor is aiming at, and how far things are ON THE CANVAS.
#
# Two small vocabularies that every 3D game and half of all 2D ones write by hand:
#
#   the cursor's ray  what is under the pointer, whether the pointer is over one particular object,
#                     and what happens when it is clicked - plus the aimed, mask-restricted version
#                     that answers where on the FLOOR a cursor points, what is there and how steep
#                     it is. All of them share ONE emitted helper function per file, so a project
#                     that asks for the point and the slope pays for the plumbing once.
#
#   canvas space      where something is on the canvas (camera zoom and canvas layers included -
#                     which plain position arithmetic gets wrong), how far apart two canvas points
#                     are IN PIXELS, and the pick that keeps whichever instance is nearest the
#                     crosshair on screen. Naming canvas distance apart from world distance is the
#                     whole point: an aim assist measured in world units ignores zoom.
#
# Module contract: see ace_factory.gd - ace_ids/templates are API (compatibility covenant); this
# file only changes where the descriptors are AUTHORED.
@tool
class_name EventForgeCursorCanvasACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

const MOUSE := "Mouse"
const CANVAS := "Canvas"
const PICKING := "Nodes: Picking"

## The one emitted helper every aimed-floor word calls. The compiler writes its definition into the
## file the first time any of them appears, so all three expressions share one function and a file
## never gains a near-duplicate of it.
const AIM_HELPER := "__eventsheets_aim_floor"

## The 2D twins' helpers: the point query that answers what the cursor is over on a 2D canvas, and
## the tile lookup that answers which cell it is over. Written into the file exactly once each, by
## the same rule the aimed-floor helper follows.
const POINT_HELPER := "__eventsheets_object_at_2d"
const TILE_HELPER := "__eventsheets_tile_under"

## The canvas point of the OS pointer, spelled the one way the readings recognise.
const MOUSE_POINT := "get_viewport().get_mouse_position()"

## Where the OS pointer is in the 2D world, which is the point a 2D query asks about.
const MOUSE_WORLD_POINT_2D := "get_global_mouse_position()"


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []
	_add_cursor_words(descriptors)
	_add_floor_words(descriptors)
	_add_flat_cursor_words(descriptors)
	_add_canvas_words(descriptors)
	return descriptors


## The layer mask an aimed ray may see, named by the project's own layer names.
static func _layer_param(default_value: String) -> ACEParam:
	return F.make_param("layer", "String", default_value, "Layers",
		"Which collision layers the ray may see, by the names this project gave them.",
		"physics_layer_3d")


## How far into the scene an aimed ray reaches, in metres.
static func _reach_param(default_value: String) -> ACEParam:
	return F.make_param("reach", "String", default_value, "Reach",
		"How far into the scene the ray reaches, in metres.", "expression")


## Whether the pointer is over one particular object, and the click that lands on it. Both write
## the same masked ray the aimed-floor words do, so a project only ever gains one helper.
static func _add_cursor_words(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.make_descriptor("Core", "CursorIsOverObject3D", "Cursor Is Over Object (3D)",
		ACEDescriptor.ACEType.CONDITION,
		"%s(%s, {layer}, {reach}).get(\"collider\", null) == {object}" % [AIM_HELPER, MOUSE_POINT],
		"", [F.make_param("object", "String", "self", "Object",
			"The object the cursor has to be over for this to be true.", "expression"),
			_layer_param("4294967295"), _reach_param("1000.0")],
		MOUSE, "cursor is over {object}")
		.described("True while the mouse is pointing at this object in the 3D world - hover highlights, tooltips and \"what am I about to click\" all start here. Needs an active Camera3D."))
	descriptors.append(F.make_descriptor("Core", "OnObjectClicked3D", "On Object Clicked (3D)",
		ACEDescriptor.ACEType.CONDITION,
		"(event is InputEventMouseButton and event.pressed and event.button_index == {button} and %s(event.position, {layer}, {reach}).get(\"collider\", null) == {object})" % AIM_HELPER,
		"", [F.make_param("object", "String", "self", "Object",
			"The object the click has to land on.", "expression"),
			F.make_param("button", "String", "MOUSE_BUTTON_LEFT", "Button", "Mouse button.", "",
				["MOUSE_BUTTON_LEFT", "MOUSE_BUTTON_RIGHT", "MOUSE_BUTTON_MIDDLE"]),
			_layer_param("4294967295"), _reach_param("1000.0")],
		MOUSE, "On {object} clicked")
		.described("Fires when a mouse button goes down over this object in the 3D world - click-to-select, click-to-attack, click-to-open. Lives in an input event, beside the other On ... pressed rows."))


## Where on the floor a cursor points, what is there, and how steep it is - for the OS pointer
## and for any crosshair object, which is what makes gamepad and touch cursors first-class.
static func _add_floor_words(descriptors: Array[ACEDescriptor]) -> void:
	var answers: Array[Array] = [
		["Point", "position", "Vector3.ZERO", "floor point",
			"The world point on the floor the cursor is aiming at - where to drop a build ghost, a move-order marker or a decal."],
		["Object", "collider", "null", "floor object",
			"The floor object the cursor is aiming at, or nothing when the cursor is off the floor."],
		["Slope", "normal", "Vector3.UP", "floor slope",
			"Which way the floor faces under the cursor - hand it to Align To The Ground's Slope, or ask Slope Steeper Than whether it is buildable."]
	]
	for answer: Array in answers:
		descriptors.append(F.make_descriptor("Core", "MouseFloor%s" % str(answer[0]),
			"Mouse %s" % str(answer[3]).capitalize(), ACEDescriptor.ACEType.EXPRESSION,
			"%s(%s, {layer}, {reach}).get(\"%s\", %s)" % [AIM_HELPER, MOUSE_POINT, str(answer[1]), str(answer[2])],
			"", [_layer_param("1"), _reach_param("500.0")], MOUSE, "mouse %s" % str(answer[3]))
			.described(str(answer[4])))
		descriptors.append(F.make_descriptor("Core", "AimedFloor%s" % str(answer[0]),
			"Aimed %s" % str(answer[3]).capitalize(), ACEDescriptor.ACEType.EXPRESSION,
			"%s({target}.get_global_transform_with_canvas().origin, {layer}, {reach}).get(\"%s\", %s)" % [AIM_HELPER, str(answer[1]), str(answer[2])],
			"", [F.make_param("target", "String", "self", "Cursor object",
				"The crosshair or virtual cursor to aim through. Its position ON THE CANVAS is what aims the ray, so a gamepad or touch cursor works exactly like the pointer.",
				"expression"), _layer_param("1"), _reach_param("500.0")],
			CANVAS, "aimed %s through {target}" % str(answer[3]), "Node2D")
			.described("%s Aimed through a crosshair object rather than the OS pointer." % str(answer[4])))
	descriptors.append(F.make_descriptor("Core", "SlopeSteeperThan", "Slope Steeper Than",
		ACEDescriptor.ACEType.CONDITION,
		"rad_to_deg({normal}.angle_to(Vector3.UP)) > {degrees}", "",
		[F.make_param("normal", "String", "Vector3.UP", "Slope",
			"Which way the ground faces - the floor slope expressions answer exactly this.", "expression"),
		F.make_param("degrees", "String", "30.0", "Degrees",
			"How far from flat counts as too steep.", "angle")],
		CANVAS, "slope steeper than {degrees}°")
		.described("True when the ground faces further than this from straight up - the buildable test a placement preview tints itself with."))


## The 2D twins. The same aiming question asked of a flat game: what is under the cursor, and
## which tile is under it. A 2D canvas has no camera ray to cast, so the object question is a POINT
## query and the tile question is a map lookup - but both share the one-helper discipline the 3D
## words use, so a project that asks both gains one small function for each rather than the query
## plumbing inline on every row.
static func _add_flat_cursor_words(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.make_descriptor("Core", "ObjectUnderCursor2D", "Object Under Cursor (2D)",
		ACEDescriptor.ACEType.EXPRESSION,
		"%s(%s, {layer}).get(\"collider\", null)" % [POINT_HELPER, MOUSE_WORLD_POINT_2D], "",
		[F.make_param("layer", "String", "1", "Layers",
			"Which collision layers the query may see, by the names this project gave them.",
			"physics_layer_2d")],
		MOUSE, "the object under the cursor")
		.described("Which 2D body or area the mouse is over, or nothing when it is over empty space - click-to-select, hover highlights and \"what am I about to pick up\". Asked as a point query, so overlapping shapes answer with the one on top."))
	descriptors.append(F.make_descriptor("Core", "TileUnderCursor", "Tile Under Cursor",
		ACEDescriptor.ACEType.EXPRESSION, "%s({tilemap})" % TILE_HELPER, "",
		[F.make_param("tilemap", "String", "self", "Tilemap",
			"The tilemap layer the cell is looked up in. Its own transform is what turns the pointer into a cell, so a scrolled or zoomed map answers correctly.",
			"expression")],
		MOUSE, "the tile under the cursor")
		.described("Which cell of a tilemap layer the mouse is over, as map coordinates - the number Set Tile At, Erase Tile At and Cell Is Empty all take. Tile painting, build grids and \"which square did I click\" start here."))


## Canvas space: where something is on screen, how far apart two screen points are in PIXELS,
## and the pick that keeps whichever instance is nearest the crosshair.
static func _add_canvas_words(descriptors: Array[ACEDescriptor]) -> void:
	for axis: String in ["X", "Y"]:
		descriptors.append(F.make_descriptor("Core", "Canvas%s2D" % axis, "Canvas %s (2D)" % axis,
			ACEDescriptor.ACEType.EXPRESSION,
			"{target}.get_global_transform_with_canvas().origin.%s" % axis.to_lower(), "",
			[F.make_param("target", "String", "self", "Object",
				"The object being asked where it is on screen.", "expression")],
			CANVAS, "{target}'s canvas %s" % axis.to_lower(), "Node2D")
			.described("Where this object is ON THE CANVAS, in pixels. Camera zoom and canvas layers are already in the answer, which is exactly what plain position arithmetic gets wrong."))
		descriptors.append(F.make_descriptor("Core", "Canvas%s3D" % axis, "Canvas %s (3D)" % axis,
			ACEDescriptor.ACEType.EXPRESSION,
			"(get_viewport().get_camera_3d().unproject_position({target}.global_position).%s if get_viewport().get_camera_3d() != null else 0.0)" % axis.to_lower(),
			"", [F.make_param("target", "String", "self", "Object",
				"The 3D object being asked where it is on screen.", "expression")],
			CANVAS, "{target}'s canvas %s" % axis.to_lower(), "Node3D")
			.described("Where this 3D object lands ON THE CANVAS, in pixels - the number a health bar over its head, an off-screen arrow or an aim assist is positioned by."))
	descriptors.append(F.make_descriptor("Core", "CanvasCentre", "Canvas Centre",
		ACEDescriptor.ACEType.EXPRESSION, "(get_viewport().get_visible_rect().size / 2.0)", "", [],
		CANVAS, "the canvas centre")
		.described("The middle of what the player can see, in pixels - where a crosshair sits."))
	# There is deliberately no Canvas Distance verb: the shipped Distance Between (Core/VectorDistanceTo)
	# already writes the exact line - `{a}.distance_to({b})` - and a second ACE spelling it identically
	# would shadow it in the reverse-lifter, so every `distance_to` in every project would start
	# lifting as a canvas measurement. What the canvas needs is a NAME, not a second verb, and the
	# reading supplies it: between two points the file itself derived from a canvas conversion, the
	# row says "the canvas distance from A to B (pixels)".
	descriptors.append(F.make_descriptor("Core", "PickNearestToCanvasPoint",
		"Pick Nearest To Canvas Point", ACEDescriptor.ACEType.ACTION,
		"var {name} = null\nvar __best_{uid} = {radius}\nvar __cam_{uid} = get_viewport().get_camera_3d()\nfor __each_{uid} in {list}:\n\tif __cam_{uid} == null or __cam_{uid}.is_position_behind(__each_{uid}.global_position):\n\t\tcontinue\n\tvar __gap_{uid} = {from}.distance_to(__cam_{uid}.unproject_position(__each_{uid}.global_position))\n\tif __gap_{uid} < __best_{uid}:\n\t\t__best_{uid} = __gap_{uid}\n\t\t{name} = __each_{uid}",
		"", [F.make_param("name", "String", "best", "Picked name",
			"The name the one it picks goes by in the rows below. Nothing is picked when the list is empty or everything is off screen, so check the name exists first."),
		F.make_param("list", "String", "get_tree().get_nodes_in_group(\"enemies\")", "Out of",
			"The instances to pick from - usually a group, which is how a project spells \"every one of this kind\".",
			"expression"),
		F.make_param("from", "String", "(get_viewport().get_visible_rect().size / 2.0)", "Nearest to",
			"The canvas point distances are measured from, in pixels. The canvas centre is the crosshair.",
			"expression"),
		F.make_param("radius", "String", "48.0", "Within",
			"How far from that point, in PIXELS, still counts. Nothing beyond it is picked.",
			"expression")],
		PICKING, "pick nearest of [i]{list}[/i] to canvas point {from} -> [b]{name}[/b]")
		.described("Walks the instances and keeps whichever is closest to a point ON THE CANVAS - aim assist, snap-to-target crosshairs and \"whichever one I am nearly pointing at\". Measured in pixels, so camera zoom is honoured; anything behind the camera is skipped.").featured())
