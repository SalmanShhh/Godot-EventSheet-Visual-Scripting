# EventForge module - the 3D page: moving, turning, placing, and the point at an angle
#
# The authoring half of the readings in the same words. Every template here is EXACTLY the spelling
# the opened-script reading recognises, which is what makes a line typed by hand and the same line
# dropped from the picker one row and one file:
#
#   Move In Direction        global_position += -basis.z * speed * delta   "Move forward at speed"
#   Rotate Clockwise         rotate_y(deg_to_rad(90.0 * delta))            "Rotate clockwise at 90°/s"
#   Rotate Toward Facing     basis = basis.slerp(facing, 5.0 * delta)      "Rotate toward facing at 5"
#   Set Position To Object   global_position = spawn.global_position       "Set position to spawn"
#   Align To The Slope       basis = Basis(Quaternion(Vector3.UP, n)) * basis
#   Is Within Angle Of Facing  forward.dot(to_target) > cos(deg_to_rad(45))
#   Point At Angle           Vector2.from_angle(deg_to_rad(a)) * d         "the point at angle a, distance d"
#
# The DIRECTION parameter is a dropdown of the six words an object's own axes point in, and what it
# writes is the basis expression - so the reader picks "forward" and the file says `-basis.z`.
#
# Module contract: see ace_factory.gd - ace_ids/templates are API (compatibility covenant); this file
# only changes where the descriptors are AUTHORED.
@tool
class_name EventForgeSpatialWordsACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

## The picker page these rows are filed on, and its three sections. Written as "page: section" so the
## picker files them the way it files an unscoped row, rather than in one flat list keyed on the node
## type they are scoped to.
const PAGE_MOVE := "3D: Move & Turn"
const PAGE_PLACE := "3D: Place"
const PAGE_SEE := "3D: See"

## The six directions an object's own axes point in, as the dropdown a direction parameter offers:
## the reader picks the WORD, and the file is written the basis expression it is. Kept in the same
## order the sheet says them in - the way you go first, then the way you came, then the sides.
const DIRECTION_OPTIONS: Array = [
	{"key": "-basis.z", "label": "forward"},
	{"key": "basis.z", "label": "backward"},
	{"key": "basis.x", "label": "right"},
	{"key": "-basis.x", "label": "left"},
	{"key": "basis.y", "label": "up"},
	{"key": "-basis.y", "label": "down"}
]


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []
	_append_move(descriptors)
	_append_place(descriptors)
	_append_see(descriptors)
	_append_polar(descriptors)
	return descriptors


## X1. Moving and turning: one of six directions at a speed, the three turns in degrees a second, and
## turning toward a facing rather than snapping to it.
static func _append_move(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.make_descriptor("Core", "MoveInDirection3D", "Move In Direction",
		ACEDescriptor.ACEType.ACTION,
		"global_position += {direction} * {speed} * {delta_t}", "",
		[F.make_param("direction", "String", "-basis.z", "Direction",
			"Which of its own six directions to move along.", "", DIRECTION_OPTIONS),
		F.make_param("speed", "String", "6.0", "Speed", "Units a second.", "expression"),
		F.make_param("delta_t", "String", "delta", "Delta", "Frame time; defaults to `delta`.",
			"expression")],
		PAGE_MOVE, "Move [b]{direction}[/b] at [i]{speed}[/i]", "Node3D")
		.described("Moves a 3D node along one of its own directions - forward, back, right, left, up or down - at a speed a second."))
	# The minus is the whole point of this row: a POSITIVE `rotate_y` turns an object to its own left,
	# which is counter-clockwise seen from above, so a row that says clockwise has to write the turn
	# the other way round or its words would be a lie. It sits outside `deg_to_rad` so a reader who
	# types a negative amount gets `-deg_to_rad(-30.0 * delta)` rather than `--30.0`.
	descriptors.append(F.make_descriptor("Core", "RotateClockwise3D", "Rotate Clockwise",
		ACEDescriptor.ACEType.ACTION,
		"rotate_y(-deg_to_rad({degrees_per_second} * {delta_t}))", "",
		[F.make_param("degrees_per_second", "String", "90.0", "Degrees per second",
			"Degrees a second, turning clockwise seen from above; a negative number turns the other way.",
			"expression"),
		F.make_param("delta_t", "String", "delta", "Delta", "Frame time; defaults to `delta`.",
			"expression")],
		PAGE_MOVE, "Rotate [b]clockwise[/b] at [i]{degrees_per_second}[/i]°/s", "Node3D")
		.described("Turns a 3D node about its up axis - the yaw a character or a turret turns with."))
	descriptors.append(F.make_descriptor("Core", "RotatePitch3D", "Rotate Up Or Down",
		ACEDescriptor.ACEType.ACTION,
		"rotate_x(deg_to_rad({degrees_per_second} * {delta_t}))", "",
		[F.make_param("degrees_per_second", "String", "45.0", "Degrees per second",
			"Degrees a second; a negative number tilts the other way.", "expression"),
		F.make_param("delta_t", "String", "delta", "Delta", "Frame time; defaults to `delta`.",
			"expression")],
		PAGE_MOVE, "Rotate [b]up[/b] at [i]{degrees_per_second}[/i]°/s", "Node3D")
		.described("Tilts a 3D node's nose up or down - the pitch a plane or a camera arm moves with."))
	descriptors.append(F.make_descriptor("Core", "Roll3D", "Roll",
		ACEDescriptor.ACEType.ACTION,
		"rotate_z(deg_to_rad({degrees_per_second} * {delta_t}))", "",
		[F.make_param("degrees_per_second", "String", "45.0", "Degrees per second",
			"Degrees a second; a negative number rolls the other way.", "expression"),
		F.make_param("delta_t", "String", "delta", "Delta", "Frame time; defaults to `delta`.",
			"expression")],
		PAGE_MOVE, "Roll [b]left[/b] at [i]{degrees_per_second}[/i]°/s", "Node3D")
		.described("Rolls a 3D node about the way it faces - the bank a plane or a ship leans with."))
	descriptors.append(F.make_descriptor("Core", "RotateToward3DFacing", "Rotate Toward Facing",
		ACEDescriptor.ACEType.ACTION,
		"basis = basis.slerp({facing}, {rate} * {delta_t})", "",
		[F.make_param("facing", "String", "Basis.IDENTITY", "Facing",
			"The facing to turn toward - Facing Along a direction gives you one.", "expression"),
		F.make_param("rate", "String", "5.0", "Rate",
			"How fast it closes the gap, per second. Bigger turns harder.", "expression"),
		F.make_param("delta_t", "String", "delta", "Delta", "Frame time; defaults to `delta`.",
			"expression")],
		PAGE_MOVE, "Rotate toward [i]{facing}[/i] at [i]{rate}[/i]", "Node3D")
		.described("Turns a 3D node smoothly toward a facing instead of snapping to it - the way a turret leads its target."))
	# Not scoped to a node on purpose: it reads a DIRECTION and gives a facing back, touching no
	# object at all, and a node-scoped expression would be handed a `<node>.` prefix that cannot
	# parse in front of `Basis.looking_at`.
	descriptors.append(F.make_descriptor("Core", "FacingAlong3D", "Facing Along",
		ACEDescriptor.ACEType.EXPRESSION,
		"Basis.looking_at({direction})", "",
		[F.make_param("direction", "String", "Vector3.FORWARD", "Direction",
			"The direction to face along.", "expression")],
		PAGE_MOVE, "facing along {direction}")
		.described("The facing that looks along a direction - what Rotate Toward Facing turns toward."))


## X5. Placing things in the world: on another object, and tilted onto the ground's slope.
static func _append_place(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.make_descriptor("Core", "SetPositionToObject3D",
		"Set Position To Another Object", ACEDescriptor.ACEType.ACTION,
		"global_position = {other}.global_position", "",
		[F.make_param("other", "String", "self", "Other",
			"The object to stand where - a spawn marker, a socket, another character.",
			"expression")],
		PAGE_PLACE, "Set position to [b]{other}[/b]", "Node3D")
		.described("Puts a 3D node exactly where another one is - how a spawn point, a socket or a respawn marker is used."))
	# X5. The snap-to-floor run, written exactly as the reading recognises it - the ray straight down
	# from where the object is, the cast, the is-empty guard and the hit taken back. Four lines,
	# because that is what Godot needs; one row, because that is what it means.
	descriptors.append(F.make_descriptor("Core", "PlaceOnGround3D",
		"Place On The Ground", ACEDescriptor.ACEType.ACTION,
		"var __drop_query_{uid} := PhysicsRayQueryParameters3D.create("
		+ "global_position, global_position + Vector3.DOWN * {reach})\n"
		+ "var __drop_hit_{uid} := get_world_3d().direct_space_state.intersect_ray(__drop_query_{uid})\n"
		+ "if not __drop_hit_{uid}.is_empty():\n"
		+ "\tglobal_position = __drop_hit_{uid}.position", "",
		[F.make_param("reach", "String", "100.0", "Reach",
			"How far down to look for ground, in units. Nothing moves when there is none within reach.",
			"expression")],
		PAGE_PLACE, "Place on the [b]ground[/b] [i]reach {reach}[/i]", "Node3D")
		.described("Drops a 3D node straight down onto whatever is under it - the snap-to-floor every spawn, item drop and building placement ends with. Leaves it where it is when nothing is within reach."))
	descriptors.append(F.make_descriptor("Core", "AlignToGroundSlope3D",
		"Align To The Ground's Slope", ACEDescriptor.ACEType.ACTION,
		"basis = Basis(Quaternion(Vector3.UP, {normal})) * basis", "",
		[F.make_param("normal", "String", "Vector3.UP", "Ground normal",
			"The way the surface faces - a ray hit gives you one as its `normal`.", "expression")],
		PAGE_PLACE, "Align to the ground's [b]slope[/b]", "Node3D")
		.described("Tilts a 3D node so its up points the way the ground does - the line that makes a dropped crate sit flat on a hill."))


## X3. The facing questions: how far off facing something is, and which side of an object it is on.
static func _append_see(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.make_descriptor("Core", "IsWithinAngleOfFacing3D",
		"Is Within Angle Of Facing", ACEDescriptor.ACEType.CONDITION,
		"{forward}.dot({direction}) > cos(deg_to_rad({angle}))", "",
		[F.make_param("forward", "String", "-basis.z", "Facing",
			"The way this object faces. Its own forward, unless you say otherwise.", "expression"),
		F.make_param("direction", "String", "Vector3.FORWARD", "Toward",
			"The direction to the thing being looked for - Direction To gives you one.",
			"expression"),
		F.make_param("angle", "String", "45.0", "Within",
			"Half the width of the cone, in degrees. 45 is a 90-degree field of view.",
			"expression")],
		PAGE_SEE, "Is within [b]{angle}[/b]° of facing [i]{direction}[/i]", "Node3D")
		.described("Asks whether something is inside the cone this object is looking down - a vision cone, a backstab check, an aim assist."))
	descriptors.append(F.make_descriptor("Core", "IsBehindObject3D", "Is Behind",
		ACEDescriptor.ACEType.CONDITION, "to_local({point}).z > 0.0", "",
		[F.make_param("point", "String", "Vector3.ZERO", "Point",
			"The place being asked about.", "expression")],
		PAGE_SEE, "[i]{point}[/i] is [b]behind[/b] it", "Node3D")
		.described("Asks whether a place is behind this object - the backstab half of a facing test."))
	descriptors.append(F.make_descriptor("Core", "IsInFrontOfObject3D", "Is In Front Of",
		ACEDescriptor.ACEType.CONDITION, "to_local({point}).z < 0.0", "",
		[F.make_param("point", "String", "Vector3.ZERO", "Point",
			"The place being asked about.", "expression")],
		PAGE_SEE, "[i]{point}[/i] is [b]in front of[/b] it", "Node3D")
		.described("Asks whether a place is in front of this object, whichever way it happens to be turned."))
	descriptors.append(F.make_descriptor("Core", "IsToTheRightOfObject3D", "Is To The Right Of",
		ACEDescriptor.ACEType.CONDITION, "to_local({point}).x > 0.0", "",
		[F.make_param("point", "String", "Vector3.ZERO", "Point",
			"The place being asked about.", "expression")],
		PAGE_SEE, "[i]{point}[/i] is [b]to the right of[/b] it", "Node3D")
		.described("Asks whether a place is off this object's right side - which way to lean, dodge or steer."))
	descriptors.append(F.make_descriptor("Core", "IsToTheLeftOfObject3D", "Is To The Left Of",
		ACEDescriptor.ACEType.CONDITION, "to_local({point}).x < 0.0", "",
		[F.make_param("point", "String", "Vector3.ZERO", "Point",
			"The place being asked about.", "expression")],
		PAGE_SEE, "[i]{point}[/i] is [b]to the left of[/b] it", "Node3D")
		.described("Asks whether a place is off this object's left side - the twin of Is To The Right Of."))


## X31. Angle and distance, both ways: the point an angle and a distance name, a ring of things placed
## evenly around a circle, and the pair of locals that reads a place back as an angle and a distance.
static func _append_polar(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.make_descriptor("Core", "PointAtAngle", "Point At Angle",
		ACEDescriptor.ACEType.EXPRESSION,
		"Vector2.from_angle(deg_to_rad({angle})) * {distance}", "",
		[F.make_param("angle", "String", "0.0", "Angle", "The angle, in degrees.", "expression"),
		F.make_param("distance", "String", "100.0", "Distance", "How far out to go.", "expression")],
		"Math & Random", "the point at angle {angle}, distance {distance}")
		.described("The point an angle and a distance name. Add it to a centre for a place on a circle; grow the distance every tick and it draws a spiral."))
	descriptors.append(F.make_descriptor("Core", "CreateAroundCircle",
		"Create Evenly Around A Circle", ACEDescriptor.ACEType.ACTION,
		"for __ring_{uid} in {count}:\n"
		+ "\tvar __ring_angle_{uid} := TAU * float(__ring_{uid}) / float({count})\n"
		+ "\tvar __ring_node_{uid} = load({scene}).instantiate()\n"
		+ "\tadd_child(__ring_node_{uid})\n"
		+ "\t__ring_node_{uid}.position = {centre}"
		+ " + Vector2(cos(__ring_angle_{uid}), sin(__ring_angle_{uid})) * {radius}", "",
		[F.make_param("count", "String", "8", "How many", "How many to place.", "expression"),
		F.make_param("scene", "String", "\"res://bullet.tscn\"", "Scene",
			"The scene to place.", "scene_path"),
		F.make_param("centre", "String", "Vector2.ZERO", "Centre",
			"The middle of the circle.", "expression"),
		F.make_param("radius", "String", "120.0", "Radius",
			"How far out from the centre they sit.", "expression")],
		"Scene", "Create [b]{count}[/b] of {scene} evenly around a circle of [i]{radius}[/i]")
		.described("Places a number of copies evenly around a circle - the bullet-hell ring, the radial menu, the circle of pillars."))
	descriptors.append(F.make_descriptor("Core", "StoreAsAngleAndDistance",
		"Store As Angle And Distance", ACEDescriptor.ACEType.ACTION,
		"var {angle_name} := {from}.angle_to_point({to})\n"
		+ "var {distance_name} := {from}.distance_to({to})", "",
		[F.make_param("from", "String", "Vector2.ZERO", "From", "The place to measure from.",
			"expression"),
		F.make_param("to", "String", "Vector2(100, 0)", "To", "The place to measure to.",
			"expression"),
		F.make_param("angle_name", "String", "aim_angle", "Angle name",
			"What to call the angle.", "expression"),
		F.make_param("distance_name", "String", "aim_distance", "Distance name",
			"What to call the distance.", "expression")],
		"Math & Random",
		"Store [i]{from}[/i] to [i]{to}[/i] as [b]{angle_name}[/b] and [b]{distance_name}[/b]")
		.described("Reads a place back the other way - as the angle from one point to another and how far apart they are, both named in one drop."))
