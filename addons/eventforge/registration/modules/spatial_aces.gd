# EventForge module - Spatial vocabulary (screen/world, random geometry, surfaces, grids, falloff).
#
# Five families of pure spatial maths the repo kept asking developers to hand-write:
#
#   1. SCREEN AND WORLD - the plugin could already put the mouse INTO the world and had no way to
#      put the world ONTO the screen, so every nameplate, damage number and off-screen arrow was a
#      hand-written canvas-transform line. World Point To Screen and its twins close the loop, plus
#      the 3D projection pair and the frustum wrap that is the missing sibling of the 2D
#      Wrap Inside The Screen in node_aces.
#   2. RANDOM GEOMETRY - randomness here was entirely scalar, so scatter was written as
#      "random angle + random radius", which bunches everything at the centre. Every shape verb
#      below is area-correct (the sqrt / cube-root weighting is baked in).
#   3. SURFACES - the repo hands out surface normals generously (Ray Result Normal, Wall Normal,
#      the Bullet pack's On Bullet Hit payload) and nothing consumed them. Bounce, slide,
#      depenetrate, face-along-motion, safe Look At, and lead-aim are the verbs that consume them.
#   4. GRID MATHS - cell coordinates only existed if you owned a TileMapLayer, because Local To Map
#      is its method. These make the grid a plain idea usable with no tilemap in sight, including a
#      looping condition so "once per cell in range" lands in the loop lane like every other loop.
#   5. FALLOFF - the blast COLLECTORS ship (Query Bodies In Circle, In Sphere) and every body then
#      took identical damage, because nothing said "less the further away".
#
# Everything compiles to plain, dependency-free GDScript. Expressions are single expressions and
# null-safe on their own (a missing 3D camera reads as a zero, never a crash). Templates that must
# NOT be retargeted to another node either lead with a statement keyword or open with a bracket, so
# the builtin "On node" pass leaves them alone - retargeting maths that reads this node's own
# position would silently answer for the wrong node.
#
#   6. THE 3D PAGE - moving, turning, placing and seeing, in the words a reader uses. Every template
#      in that family is EXACTLY the spelling the opened-script reading recognises, which is what
#      makes a line typed by hand and the same line dropped from the picker one row:
#
#        Move In Direction        global_position += -basis.z * speed * delta
#        Rotate Clockwise         rotate_y(deg_to_rad(90.0 * delta))
#        Rotate Toward Facing     basis = basis.slerp(facing, 5.0 * delta)
#        Set Position To Object   global_position = spawn.global_position
#        Align To The Slope       basis = Basis(Quaternion(Vector3.UP, n)) * basis
#        Is Within Angle Of Facing  forward.dot(to_target) > cos(deg_to_rad(45))
#        Point At Angle           Vector2.from_angle(deg_to_rad(a)) * d
#
#      Its DIRECTION parameter is a dropdown of the six words an object's own axes point in, and
#      what it writes is the basis expression - so the reader picks "forward" and the file says
#      `-basis.z`.
# Module contract: see ace_factory.gd - ace_ids/templates are API (compatibility covenant).
@tool
class_name EventForgeSpatialACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

const MATH := "Math & Random"
const MOVE := "Movement"
const LOOPS := "Loops"

## The canonical five-geometry dropdown, shared verbatim with Is Within Distance (choose metric)
## in node_aces so a player never meets two different spellings of "how is distance counted".
const CELL_METRIC_OPTIONS: Array = [
	{"key": "0", "label": "Straight line"},
	{"key": "1", "label": "Horizontal only"},
	{"key": "2", "label": "Vertical only"},
	{"key": "3", "label": "Grid steps"},
	{"key": "4", "label": "King moves"}
]

## The two shapes an "everything within N cells" set can take. Kept to two on purpose: these index
## a live branch, and an option the branch cannot answer crashes only when the row is reached.
const RADIUS_SHAPE_OPTIONS: Array = [
	{"key": "0", "label": "Grid steps (diamond)"},
	{"key": "1", "label": "King moves (square)"}
]

## The falloff profile dropdown. "Sharp (squared)" squares the NEARNESS reading, which eases in
## from the rim and holds strength near the centre; it is deliberately not named after the inverse
## square law, which is a different curve (and one that has no finite value at the centre at all).
## The falloff profile dropdown. The key IS the index into the inline array of the three profiles,
## the shipped Is Within Distance (choose metric) idiom - one plain expression, no helper function,
## no runtime library. A fourth "draw your own" profile is deliberately absent: feed this number
## into the shipped Sample Curve expression instead and a designer draws the blast in the Inspector.
const FALLOFF_SHAPE_OPTIONS: Array = [
	{"key": "0", "label": "Linear"},
	{"key": "1", "label": "Sharp (squared)"},
	{"key": "2", "label": "Smooth (ease out)"}
]

## Written out once because it appears three times inside the falloff array (single-pass
## substitution means an option value can never reference another parameter, so the distance
## reading is repeated rather than stored in a local an expression cannot declare).
const _NEARNESS := "clampf(1.0 - {center}.distance_to({point}) / maxf({radius}, 0.001), 0.0, 1.0)"

## The visible rectangle in WORLD space, spelled once. The canvas transform maps world to screen,
## so its inverse maps the screen rectangle back out into the world.
const _WORLD_RECT := "(get_viewport().get_canvas_transform().affine_inverse() * get_viewport().get_visible_rect())"

## The world point a fraction of the way along a curve. Repeated by the two cell-set builders.
const _CELL_STEPS := "maxi(absi({to_cell}.x - {from_cell}.x), absi({to_cell}.y - {from_cell}.y))"


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
	_append_screen_and_world(descriptors)
	_append_random_geometry(descriptors)
	_append_surfaces(descriptors)
	_append_grid(descriptors)
	_append_falloff(descriptors)
	_append_move(descriptors)
	_append_place(descriptors)
	_append_see(descriptors)
	_append_polar(descriptors)
	return descriptors


# ── 1. Screen and world, both ways ────────────────────────────────────────────────────────────
# The canvas transform is the whole story in 2D: it maps world space to screen space, so one
# multiplication goes out and its inverse comes back. In 3D the camera owns the projection, and
# every 3D verb here guards a missing camera rather than faulting in a scene that has none yet.
static func _append_screen_and_world(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.make_descriptor("Core", "WorldPointToScreen", "World Point To Screen", ACEDescriptor.ACEType.EXPRESSION, "(get_viewport().get_canvas_transform() * {world_point})", "", [F.make_param("world_point", "Vector2", "Vector2.ZERO", "World Point", "A position in the game world.", "expression")], MATH, "screen position of [b]{world_point}[/b]")
		.described("Where a world point sits on screen right now, camera zoom and scroll included - pin a nameplate, a health bar or a damage number to something that moves. Put the answer on a node that lives on a CanvasLayer and it will track its target without lagging behind the camera.").featured())
	descriptors.append(F.make_descriptor("Core", "ScreenPointToWorld", "Screen Point To World", ACEDescriptor.ACEType.EXPRESSION, "(get_viewport().get_canvas_transform().affine_inverse() * {screen_point})", "", [F.make_param("screen_point", "Vector2", "Vector2.ZERO", "Screen Point", "A position in screen pixels, with 0,0 at the top-left of the view.", "expression")], MATH, "world position of screen point [b]{screen_point}[/b]")
		.described("The world position under a screen pixel - click-to-place, a gamepad cursor, a HUD marker dragged onto the map. The exact opposite of World Point To Screen, so the two round-trip."))
	descriptors.append(F.make_descriptor("Core", "ProjectToScreen3D", "Project To Screen (3D)", ACEDescriptor.ACEType.EXPRESSION, "(get_viewport().get_camera_3d().unproject_position({world_point}) if get_viewport().get_camera_3d() != null else Vector2.ZERO)", "", [F.make_param("world_point", "Vector3", "Vector3.ZERO", "World Point", "A position in the 3D world.", "expression")], MATH, "screen position of 3D point [b]{world_point}[/b]")
		.described("Where a 3D world point lands on screen - nameplates over 3D characters, damage numbers, objective pins drawn on a CanvasLayer. Reads as 0,0 while there is no active 3D camera, so it never faults during a scene change. Check Is Behind Camera (3D) first: a point behind you still projects to a number."))
	descriptors.append(F.make_descriptor("Core", "IsPointOnScreen", "Is Point On Screen", ACEDescriptor.ACEType.CONDITION, "get_viewport().get_visible_rect().grow({margin}).has_point(get_viewport().get_canvas_transform() * {world_point})", "", [F.make_param("world_point", "Vector2", "Vector2.ZERO", "World Point", "The world position being tested.", "expression"), F.make_param("margin", "float", "0.0", "Margin", "Pixels of slack outside the view that still count as on screen. Negative pulls the test inward.", "expression")], MATH, "[b]{world_point}[/b] is on screen (margin [b]{margin}[/b])")
		.described("True while a world point is inside the visible view - the honest gate for spawning, culling, showing an off-screen arrow, or holding a tutorial callout until its subject is actually visible.").featured())
	descriptors.append(F.make_descriptor("Core", "IsBehindCamera3D", "Is Behind Camera (3D)", ACEDescriptor.ACEType.CONDITION, "(get_viewport().get_camera_3d() == null or get_viewport().get_camera_3d().is_position_behind({world_point}))", "", [F.make_param("world_point", "Vector3", "Vector3.ZERO", "World Point", "The 3D position being tested.", "expression")], MATH, "[b]{world_point}[/b] is behind the camera")
		.described("True when a 3D point sits behind the camera plane, where its projected screen position is a mirrored lie. The guard every 3D waypoint marker needs before it draws. With no camera in the scene it reads true, so nothing is drawn into a view that does not exist."))
	descriptors.append(F.make_descriptor("Core", "ScreenEdgePositionFor", "Screen Edge Position For", ACEDescriptor.ACEType.EXPRESSION, "((get_viewport().get_canvas_transform() * {world_point}).clamp(Vector2({margin}, {margin}), get_viewport().get_visible_rect().size - Vector2({margin}, {margin})))", "", [F.make_param("world_point", "Vector2", "Vector2.ZERO", "World Point", "The thing being pointed at.", "expression"), F.make_param("margin", "float", "48.0", "Margin", "How far in from the edge the marker is parked.", "expression")], MATH, "screen edge position for [b]{world_point}[/b] (margin [b]{margin}[/b])")
		.described("A screen position that follows a target while it is visible and sticks to the edge of the view once it is not - the off-screen objective arrow, the radar blip, the \"your teammate is over there\" chevron. Pair it with Marker Angle Toward for the rotation."))
	descriptors.append(F.make_descriptor("Core", "MarkerAngleToward", "Marker Angle Toward", ACEDescriptor.ACEType.EXPRESSION, "rad_to_deg(((get_viewport().get_canvas_transform() * {world_point}) - get_viewport().get_visible_rect().size * 0.5).angle())", "", [F.make_param("world_point", "Vector2", "Vector2.ZERO", "World Point", "The thing being pointed at.", "expression")], MATH, "marker angle toward [b]{world_point}[/b]")
		.described("The rotation in degrees an on-screen arrow needs so it points from the middle of the view at a world thing - the other half of the off-screen marker, and it stays right while the camera zooms or rotates."))
	descriptors.append(F.make_descriptor("Core", "VisibleWorldRect", "Visible World Rect", ACEDescriptor.ACEType.EXPRESSION, _WORLD_RECT, "", [], MATH, "visible world rect")
		.described("The rectangle of the world the camera can currently see, in world coordinates - spawn just outside it, cull outside it, clamp a node inside it, or size a minimap to it. Follows the camera's zoom and position with nothing to keep in sync."))
	descriptors.append(F.make_descriptor("Core", "WrapInsideView3D", "Wrap Inside The View (3D)", ACEDescriptor.ACEType.ACTION, "var __view_cam_{uid}: Camera3D = get_viewport().get_camera_3d()\nif __view_cam_{uid} != null:\n\tvar __view_size_{uid}: Vector2 = get_viewport().get_visible_rect().size\n\tvar __view_at_{uid}: Vector2 = __view_cam_{uid}.unproject_position(global_position)\n\tif not Rect2(Vector2.ZERO, __view_size_{uid}).has_point(__view_at_{uid}):\n\t\tglobal_position = __view_cam_{uid}.project_position(Vector2(wrapf(__view_at_{uid}.x, 0.0, __view_size_{uid}.x), wrapf(__view_at_{uid}.y, 0.0, __view_size_{uid}.y)), __view_cam_{uid}.global_position.distance_to(global_position))", "", [], MOVE, "wrap inside the view", "Node3D")
		.described("The Asteroids rule in 3D: leave the right of the view and come back on the left, off the top and back at the bottom, at the same distance from the camera. The missing twin of the 2D Wrap Inside The Screen, for a wrap-around arena or an endless shoal. Does nothing while there is no 3D camera."))


# ── 2. A random point in a shape ──────────────────────────────────────────────────────────────
# Every one of these is AREA-correct. The obvious spelling - a random angle and a random radius -
# bunches points at the centre, because the outer rings of a circle hold more area than the inner
# ones; sqrt(randf()) in 2D and cbrt in 3D undo that, and this is where that knowledge lives so
# nobody has to remember it at three in the morning.
static func _append_random_geometry(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.make_descriptor("Core", "RandomPointInCircle", "Random Point In Circle", ACEDescriptor.ACEType.EXPRESSION, "({center} + Vector2.RIGHT.rotated(randf() * TAU) * (sqrt(randf()) * {radius}))", "", [F.make_param("center", "Vector2", "Vector2.ZERO", "Center", "Middle of the circle.", "expression"), F.make_param("radius", "float", "100.0", "Radius", "In pixels.", "expression")], MATH, "random point within [b]{radius}[/b] of [b]{center}[/b]")
		.described("An evenly spread random point inside a circle - the sqrt weighting is done for you, so scatter does not bunch up in the middle the way the obvious version does.").featured())
	descriptors.append(F.make_descriptor("Core", "RandomPointOnCircle", "Random Point On Circle", ACEDescriptor.ACEType.EXPRESSION, "({center} + Vector2.RIGHT.rotated(randf() * TAU) * {radius})", "", [F.make_param("center", "Vector2", "Vector2.ZERO", "Center", "Middle of the circle.", "expression"), F.make_param("radius", "float", "300.0", "Radius", "In pixels.", "expression")], MATH, "random point on a circle of [b]{radius}[/b] around [b]{center}[/b]")
		.described("A random point exactly ON the rim of a circle, never inside it - a spawn ring around the player, orbiting decor, a radial menu slot, the starting point of a homing shot."))
	descriptors.append(F.make_descriptor("Core", "RandomPointInRing", "Random Point In Ring", ACEDescriptor.ACEType.EXPRESSION, "({center} + Vector2.RIGHT.rotated(randf() * TAU) * sqrt(lerpf({inner_radius} * {inner_radius}, {outer_radius} * {outer_radius}, randf())))", "", [F.make_param("center", "Vector2", "Vector2.ZERO", "Center", "Middle of the ring.", "expression"), F.make_param("inner_radius", "float", "500.0", "Inner Radius", "Nothing spawns closer than this.", "expression"), F.make_param("outer_radius", "float", "800.0", "Outer Radius", "Nothing spawns further than this.", "expression")], MATH, "random point between [b]{inner_radius}[/b] and [b]{outer_radius}[/b] of [b]{center}[/b]")
		.described("A random point in the doughnut between two radii - the off-screen spawner that never drops an enemy in the player's lap, and never so far away it never arrives. Evenly spread across the whole band, not crowded against the inner edge.").featured())
	descriptors.append(F.make_descriptor("Core", "RandomPointInRectangle", "Random Point In Rectangle", ACEDescriptor.ACEType.EXPRESSION, "({top_left} + Vector2(randf() * {size}.x, randf() * {size}.y))", "", [F.make_param("top_left", "Vector2", "Vector2.ZERO", "Top Left", "Corner the rectangle starts at.", "expression"), F.make_param("size", "Vector2", "Vector2(400, 240)", "Size", "Width and height in pixels.", "expression")], MATH, "random point in the rect at [b]{top_left}[/b] sized [b]{size}[/b]")
		.described("A random point inside an axis-aligned rectangle - loot scatter across a room, prop placement, confetti over a banner, a patrol target inside a zone. Feed it Visible World Rect's position and size to scatter across whatever the camera can see."))
	descriptors.append(F.make_descriptor("Core", "RandomPointInCone", "Random Point In Cone", ACEDescriptor.ACEType.EXPRESSION, "({center} + Vector2.RIGHT.rotated(deg_to_rad({facing_degrees}) + randf_range(-deg_to_rad({spread_degrees}) * 0.5, deg_to_rad({spread_degrees}) * 0.5)) * (sqrt(randf()) * {radius}))", "", [F.make_param("center", "Vector2", "Vector2.ZERO", "Tip", "Where the wedge starts.", "expression"), F.make_param("facing_degrees", "float", "0.0", "Facing", "Direction the wedge points, in degrees.", "expression"), F.make_param("spread_degrees", "float", "30.0", "Spread", "Total width of the cone in degrees, half either side of facing.", "expression"), F.make_param("radius", "float", "200.0", "Reach", "How far the wedge extends.", "expression")], MATH, "random point in a [b]{spread_degrees}[/b] cone facing [b]{facing_degrees}[/b] from [b]{center}[/b]")
		.described("A random point inside a wedge - shotgun spread, cone attacks, directional scatter, a spray of sparks away from a wall. Facing and spread are in degrees, so the row reads the way you think about it."))
	descriptors.append(F.make_descriptor("Core", "RandomPointAround", "Random Point Around", ACEDescriptor.ACEType.EXPRESSION, "({node}.global_position + Vector2.RIGHT.rotated(randf() * TAU) * sqrt(lerpf({min_radius} * {min_radius}, {max_radius} * {max_radius}, randf())))", "", [F.make_param("node", "String", "get_parent()", "Around", "Node the point is scattered around.", "expression"), F.make_param("min_radius", "float", "0.0", "Nearest", "Nothing lands closer than this.", "expression"), F.make_param("max_radius", "float", "24.0", "Furthest", "Nothing lands further than this.", "expression")], MATH, "random point [b]{min_radius}[/b] to [b]{max_radius}[/b] around [i]{node}[/i]")
		.described("Random scatter around a node that is already in the scene - blood splats around a hit, footprints around a stomp, sparkles around a pickup, a wander target around home. Pick the node instead of typing its position, and the scatter follows it as it moves."))
	descriptors.append(F.make_descriptor("Core", "RandomDirection2D", "Random Direction (2D)", ACEDescriptor.ACEType.EXPRESSION, "Vector2.RIGHT.rotated(randf() * TAU)", "", [], MATH, "random direction")
		.described("A random unit direction in 2D - multiply it by a speed for a random shove, by a distance for a random offset. Always exactly one unit long, so the strength stays where you set it."))
	descriptors.append(F.make_descriptor("Core", "RandomDirection3D", "Random Direction (3D)", ACEDescriptor.ACEType.EXPRESSION, "Vector3.UP.rotated(Vector3.RIGHT, acos(randf_range(-1.0, 1.0))).rotated(Vector3.UP, randf() * TAU)", "", [], MATH, "random direction (3D)")
		.described("A random unit direction in 3D, evenly spread over the whole sphere. The naive three-random-numbers version crowds the corners of a cube; this one does not, so debris and shrapnel fly out honestly."))
	descriptors.append(F.make_descriptor("Core", "RandomPointInSphere", "Random Point In Sphere", ACEDescriptor.ACEType.EXPRESSION, "({center} + Vector3.UP.rotated(Vector3.RIGHT, acos(randf_range(-1.0, 1.0))).rotated(Vector3.UP, randf() * TAU) * (pow(randf(), 1.0 / 3.0) * {radius}))", "", [F.make_param("center", "Vector3", "Vector3.ZERO", "Center", "Middle of the sphere.", "expression"), F.make_param("radius", "float", "5.0", "Radius", "In metres.", "expression")], MATH, "random point within [b]{radius}[/b] of [b]{center}[/b] (3D)")
		.described("An evenly spread random point inside a 3D sphere - spawn clouds, debris fields, flocking targets. The cube-root weighting keeps the middle from filling up first."))
	descriptors.append(F.make_descriptor("Core", "RandomPointInBox", "Random Point In Box", ACEDescriptor.ACEType.EXPRESSION, "({center} + Vector3(randf_range(-1.0, 1.0) * {size}.x, randf_range(-1.0, 1.0) * {size}.y, randf_range(-1.0, 1.0) * {size}.z) * 0.5)", "", [F.make_param("center", "Vector3", "Vector3.ZERO", "Center", "Middle of the box.", "expression"), F.make_param("size", "Vector3", "Vector3(10, 4, 10)", "Size", "Full width, height and depth.", "expression")], MATH, "random point in a [b]{size}[/b] box at [b]{center}[/b]")
		.described("A random point inside an axis-aligned 3D box - scatter trees over a chunk, spawn enemies in a room volume, place ambient audio emitters. Size is the FULL box, measured around the centre."))
	descriptors.append(F.make_descriptor("Core", "RandomPointOnScreenEdge", "Random Point On Screen Edge", ACEDescriptor.ACEType.EXPRESSION, "(%s.position + %s.size * [Vector2(randf(), 0.0), Vector2(randf(), 1.0), Vector2(0.0, randf()), Vector2(1.0, randf())][randi() %% 4])" % [_WORLD_RECT, _WORLD_RECT], "", [], MATH, "random point on the screen edge")
		.described("A random WORLD position on the border of what the camera can see - the wave spawner that comes in from a random side, ambient wildlife entering the frame, a meteor starting its run. Grow it with Visible World Rect if you want them to appear from just outside."))
	descriptors.append(F.make_descriptor("Core", "JitterValue", "Jitter", ACEDescriptor.ACEType.EXPRESSION, "({value} + {amount} * randf_range(-1.0, 1.0))", "", [F.make_param("value", "String", "0.0", "Value", "The number, vector or color being nudged.", "expression"), F.make_param("amount", "String", "1.0", "By", "The most it can move, as the SAME kind of value - a number for a number, a Vector2 for a position, a Color for a tint.", "expression")], MATH, "[b]{value}[/b] jittered by [b]{amount}[/b]")
		.described("Nudges a value by a random amount up to the size you give - pitch variation on a sound, a pixel or two of scatter on a decal, a shade of variation on a tint. Works on numbers, vectors and colors as long as the amount is the same kind of value."))


# ── 3. Bounce, slide and aim (the verbs that CONSUME a normal) ────────────────────────────────
# Every hit trigger and every cast in this plugin hands back a surface normal, and until now
# nothing took one. These are the three lines a developer writes next, always from memory and
# usually wrong the first time: reflect it, slide along it, push out of it. The two Look At
# variants are a crash fix, not a nicety: Godot's own look_at faults when the target is directly
# overhead, because the direction and the up vector are then parallel.
static func _append_surfaces(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.make_descriptor("Core", "BounceOffSurface", "Bounce Off Surface", ACEDescriptor.ACEType.EXPRESSION, "({velocity}.bounce({normal}.normalized()) * {bounciness})", "", [F.make_param("velocity", "Vector2", "Vector2(300, 0)", "Velocity", "How the thing was moving when it hit.", "expression"), F.make_param("normal", "Vector2", "Vector2.UP", "Surface Normal", "The normal any hit trigger or raycast hands you.", "expression"), F.make_param("bounciness", "float", "1.0", "Bounciness", "1 keeps all the speed, 0.6 is a rubber ball, 0 is a dead stop.", "expression")], MOVE, "[b]{velocity}[/b] bounced off [b]{normal}[/b]")
		.described("The velocity a moving thing has AFTER hitting a surface - feed it the normal any hit trigger or raycast hands you. Ricochets, pinball, breakout, deflect shields.").featured())
	descriptors.append(F.make_descriptor("Core", "SlideAlongSurface", "Slide Along Surface", ACEDescriptor.ACEType.EXPRESSION, "({velocity}.slide({normal}.normalized()))", "", [F.make_param("velocity", "Vector2", "Vector2(300, 0)", "Velocity", "How the thing was moving when it met the surface.", "expression"), F.make_param("normal", "Vector2", "Vector2.UP", "Surface Normal", "The normal any hit trigger or raycast hands you.", "expression")], MOVE, "[b]{velocity}[/b] slid along [b]{normal}[/b]")
		.described("The velocity left over once the part pushing INTO a surface is removed - a wall slide that keeps you moving along the wall instead of sticking to it, slope movement, a dash that grazes a corner rather than stopping dead."))
	descriptors.append(F.make_descriptor("Core", "AngleReflected", "Angle Reflected", ACEDescriptor.ACEType.EXPRESSION, "rad_to_deg(Vector2.RIGHT.rotated(deg_to_rad({degrees})).bounce({normal}.normalized()).angle())", "", [F.make_param("degrees", "float", "0.0", "Angle", "The heading it was travelling on, in degrees.", "expression"), F.make_param("normal", "Vector2", "Vector2.UP", "Surface Normal", "The normal the hit reported.", "expression")], MOVE, "[b]{degrees}[/b] reflected off [b]{normal}[/b]")
		.described("The heading in degrees a thing travels on after bouncing off a surface - the answer to feed straight back into Set Angle Of Motion when a bullet should ricochet instead of dying."))
	descriptors.append(F.make_descriptor("Core", "PushOutOfSurface", "Push Out Of Surface", ACEDescriptor.ACEType.EXPRESSION, "({point} + {normal}.normalized() * {distance})", "", [F.make_param("point", "Vector2", "Vector2.ZERO", "Hit Point", "Where the hit happened.", "expression"), F.make_param("normal", "Vector2", "Vector2.UP", "Surface Normal", "The normal the hit reported.", "expression"), F.make_param("distance", "float", "2.0", "Clearance", "Pixels of daylight to leave between the thing and the surface.", "expression")], MOVE, "[b]{point}[/b] pushed [b]{distance}[/b] out of [b]{normal}[/b]")
		.described("A position just clear of a surface instead of exactly on it - park a ricocheting bullet, a decal or a spawned effect here. Landing exactly on a surface is how a thing ends up stuck inside it on the next frame, because a ray that starts inside a shape does not report it."))
	descriptors.append(F.make_descriptor("Core", "FaceAlongVelocity", "Face Along Velocity", ACEDescriptor.ACEType.ACTION, "if {velocity}.length_squared() > 0.0001:\n\trotation = {velocity}.angle()", "", [F.make_param("velocity", "Vector2", "Vector2.RIGHT", "Velocity", "How this node is moving - Get Velocity on a body, or the direction you are driving it with.", "expression")], MOVE, "face along [b]{velocity}[/b]", "Node2D")
		.described("Turns this node to point the way it is travelling, and leaves it alone while it is standing still so a stopped thing never snaps back to facing right. Arrows, fish, cars, thrown knives, a camera that leads the motion."))
	descriptors.append(F.make_descriptor("Core", "LookAtSafeUp", "Look At (safe up)", ACEDescriptor.ACEType.ACTION, "var __look_to_{uid}: Vector3 = {target} - global_position\nif __look_to_{uid}.length_squared() > 0.000001:\n\tlook_at({target}, Vector3.UP if absf(__look_to_{uid}.normalized().y) < 0.999 else Vector3.FORWARD)", "", [F.make_param("target", "Vector3", "Vector3.ZERO", "Look At", "The world position to face.", "expression")], MOVE, "look at [b]{target}[/b] (safe up)", "Node3D")
		.described("Turns a 3D node to face a point WITHOUT the crash the plain Look At has: when the target is directly overhead or underfoot, the usual up vector points the same way as the look direction and Godot cannot build a rotation from that. This one swaps the up vector at the last moment, and does nothing at all when the target is where the node already is.").featured())
	descriptors.append(F.make_descriptor("Core", "LookAtFlat", "Look At (flat)", ACEDescriptor.ACEType.ACTION, "var __flat_{uid}: Vector3 = Vector3({target}.x, global_position.y, {target}.z)\nif __flat_{uid}.distance_squared_to(global_position) > 0.000001:\n\tlook_at(__flat_{uid}, Vector3.UP)", "", [F.make_param("target", "Vector3", "Vector3.ZERO", "Look At", "The world position to face.", "expression")], MOVE, "look at [b]{target}[/b] (flat)", "Node3D")
		.described("Turns a 3D node to face a point but only around the up axis, so a character looks at the player without tipping over to stare at their feet. The rotation every humanoid, turret base and standing NPC actually wants."))
	descriptors.append(F.make_descriptor("Core", "AimAtMovingTarget", "Aim At Moving Target", ACEDescriptor.ACEType.EXPRESSION, "({target_position} + {target_velocity} * ({target_position}.distance_to({shooter_position}) / maxf({projectile_speed}, 0.001)) if {projectile_speed} > {target_velocity}.length() else {target_position})", "", [F.make_param("shooter_position", "Vector2", "Vector2.ZERO", "Shooting From", "Where the shot starts.", "expression"), F.make_param("target_position", "Vector2", "Vector2(200, 0)", "Target At", "Where the target is right now.", "expression"), F.make_param("target_velocity", "Vector2", "Vector2.ZERO", "Target Moving At", "How the target is moving, in pixels per second.", "expression"), F.make_param("projectile_speed", "float", "600.0", "Shot Speed", "How fast your shot travels, in pixels per second.", "expression")], MOVE, "aim at [b]{target_position}[/b] moving [b]{target_velocity}[/b]")
		.described("Where to aim so a shot MEETS a moving target instead of trailing it - the interception point every turret and archer needs. When the target is faster than the shot no lead exists, and it falls back to the target's current spot rather than pointing somewhere absurd.").featured())
	descriptors.append(F.make_descriptor("Core", "LaunchAngleForArc", "Launch Angle For Arc", ACEDescriptor.ACEType.EXPRESSION, "(rad_to_deg(atan2({speed} * {speed} - sqrt(maxf({speed} * {speed} * {speed} * {speed} - {gravity} * ({gravity} * {distance} * {distance} + 2.0 * {height} * {speed} * {speed}), 0.0)), {gravity} * {distance})) if {distance} != 0.0 and {gravity} != 0.0 else 45.0)", "", [F.make_param("distance", "float", "300.0", "Distance", "How far away the target is, along the ground.", "expression"), F.make_param("height", "float", "0.0", "Height Difference", "How much higher the target is than the launcher; negative is downhill.", "expression"), F.make_param("speed", "float", "600.0", "Launch Speed", "How fast the thing leaves the launcher.", "expression"), F.make_param("gravity", "float", "980.0", "Gravity", "Pull downward, in the same units as the speed.", "expression")], MOVE, "launch angle to reach [b]{distance}[/b] away, [b]{height}[/b] up")
		.described("The angle in degrees to fire something so it ARCS onto a target - grenades, mortars, catapults, a coin tossed into a counter. Picks the flatter of the two possible arcs, and reads as 45 degrees when the shot cannot reach at all, so a row never produces a number that is not a number."))
	descriptors.append(F.make_descriptor("Core", "TimeToReach", "Time To Reach", ACEDescriptor.ACEType.EXPRESSION, "({from_position}.distance_to({to_position}) / maxf({speed}, 0.001))", "", [F.make_param("from_position", "Vector2", "Vector2.ZERO", "From", "Where it starts.", "expression"), F.make_param("to_position", "Vector2", "Vector2(200, 0)", "To", "Where it is going.", "expression"), F.make_param("speed", "float", "300.0", "Speed", "Pixels per second.", "expression")], MOVE, "time for [b]{speed}[/b] to cross [b]{from_position}[/b] to [b]{to_position}[/b]")
		.described("How many seconds something moving at a steady speed needs to cover a distance - time a warning before the missile lands, size a tween to match a walk, decide whether the interceptor can get there first."))


# ── 4. Grid maths without a TileMap ───────────────────────────────────────────────────────────
# Cell coordinates are a plain idea: divide by the cell size and take the floor. The only reason
# they were locked behind a TileMapLayer is that Local To Map is its method. Build grids, inventory
# grids, puzzle boards, chunk keys and tower placement all reason in cells with no tilemap in
# sight. Cell Distance reuses the five-geometry dropdown verbatim from Is Within Distance, and
# For Each Cell In Radius is a real looping condition, so it lands in the loop lane with frame
# spreading and round-trip behaving exactly like the built-in For Each.
static func _append_grid(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.make_descriptor("Core", "CellOfPoint", "Cell Of Point", ACEDescriptor.ACEType.EXPRESSION, "Vector2i(floori({point}.x / maxf({cell_size}, 0.001)), floori({point}.y / maxf({cell_size}, 0.001)))", "", [F.make_param("point", "Vector2", "Vector2.ZERO", "Point", "A world position.", "expression"), F.make_param("cell_size", "float", "64.0", "Cell Size", "Pixels across one cell. Type Tiles(1) to read your project's own tile size instead.", "expression")], MATH, "cell of [b]{point}[/b] on a [b]{cell_size}[/b] grid")
		.described("Which grid cell a world position falls in - no TileMapLayer needed, so build grids, inventory slots and chunk keys all speak the same language. Negative positions land in negative cells, which is what a grid that extends left and up actually wants.").featured())
	descriptors.append(F.make_descriptor("Core", "CenterOfCell", "Center Of Cell", ACEDescriptor.ACEType.EXPRESSION, "(Vector2({cell}) * {cell_size} + Vector2({cell_size}, {cell_size}) * 0.5)", "", [F.make_param("cell", "Vector2i", "Vector2i(0, 0)", "Cell", "The grid cell.", "expression"), F.make_param("cell_size", "float", "64.0", "Cell Size", "Pixels across one cell.", "expression")], MATH, "center of cell [b]{cell}[/b] on a [b]{cell_size}[/b] grid")
		.described("The world position at the middle of a grid cell - where the placement ghost sits, where the tower is built, where the piece lands. The exact partner of Cell Of Point, so the pair round-trips.").featured())
	descriptors.append(F.make_descriptor("Core", "SnapPointToGrid", "Snap Point To Grid", ACEDescriptor.ACEType.EXPRESSION, "{point}.snapped(Vector2({cell_size}, {cell_size}))", "", [F.make_param("point", "Vector2", "Vector2.ZERO", "Point", "The loose world position.", "expression"), F.make_param("cell_size", "float", "64.0", "Cell Size", "Pixels across one cell.", "expression")], MATH, "[b]{point}[/b] snapped to a [b]{cell_size}[/b] grid")
		.described("The nearest grid intersection to a loose position - a dragged card falling into its slot, a level editor brush, a UI element clicking onto a column. Rounds to the nearest, so a thing dropped just past halfway moves forward rather than back."))
	descriptors.append(F.make_descriptor("Core", "SnapPointToGrid3D", "Snap Point To Grid (3D)", ACEDescriptor.ACEType.EXPRESSION, "{point}.snapped(Vector3({cell_size}, {cell_size}, {cell_size}))", "", [F.make_param("point", "Vector3", "Vector3.ZERO", "Point", "The loose world position.", "expression"), F.make_param("cell_size", "float", "1.0", "Cell Size", "Metres across one cell.", "expression")], MATH, "[b]{point}[/b] snapped to a [b]{cell_size}[/b] grid (3D)")
		.described("The nearest point on a 3D grid - voxel placement, modular level pieces clicking together, a build cursor that lines up with the floor tiles."))
	descriptors.append(F.make_descriptor("Core", "CellDistance", "Cell Distance", ACEDescriptor.ACEType.EXPRESSION, "([Vector2({from_cell}).distance_to(Vector2({to_cell})), float(absi({from_cell}.x - {to_cell}.x)), float(absi({from_cell}.y - {to_cell}.y)), float(absi({from_cell}.x - {to_cell}.x) + absi({from_cell}.y - {to_cell}.y)), float(maxi(absi({from_cell}.x - {to_cell}.x), absi({from_cell}.y - {to_cell}.y)))][{metric}])", "", [F.make_param("from_cell", "Vector2i", "Vector2i(0, 0)", "From Cell", "One cell.", "expression"), F.make_param("to_cell", "Vector2i", "Vector2i(3, 4)", "To Cell", "The other cell.", "expression"), F.make_param("metric", "String", "3", "Measured As", "How the distance is counted - a roguelike wants Grid steps, a chess board wants King moves.", "", CELL_METRIC_OPTIONS)], MATH, "distance from cell [b]{from_cell}[/b] to [b]{to_cell}[/b], measured as [b]{metric}[/b]")
		.described("How far apart two grid cells are, with the same geometry dropdown the rest of the plugin uses: straight line, horizontal or vertical only, grid steps (Manhattan) or king moves (Chebyshev). One expression that fits a roguelike, a strategy game and a puzzle board alike."))
	descriptors.append(F.make_descriptor("Core", "NeighboursOfCell", "Neighbours Of Cell", ACEDescriptor.ACEType.EXPRESSION, "([[{cell} + Vector2i(1, 0), {cell} + Vector2i(-1, 0), {cell} + Vector2i(0, 1), {cell} + Vector2i(0, -1)], [{cell} + Vector2i(1, 0), {cell} + Vector2i(-1, 0), {cell} + Vector2i(0, 1), {cell} + Vector2i(0, -1), {cell} + Vector2i(1, 1), {cell} + Vector2i(1, -1), {cell} + Vector2i(-1, 1), {cell} + Vector2i(-1, -1)], [{cell} + Vector2i(1, 0), {cell} + Vector2i(-1, 0), {cell} + Vector2i(0, 1), {cell} + Vector2i(0, -1), {cell} + Vector2i(1, -1), {cell} + Vector2i(-1, 1)]][{shape}])", "", [F.make_param("cell", "Vector2i", "Vector2i(0, 0)", "Cell", "The cell whose neighbours you want.", "expression"), F.make_param("shape", "String", "0", "Shape", "How cells touch on this board.", "", [{"key": "0", "label": "4 sides"}, {"key": "1", "label": "8 including diagonals"}, {"key": "2", "label": "6 hex (axial)"}])], MATH, "neighbours of cell [b]{cell}[/b] ([b]{shape}[/b])")
		.described("The cells touching a cell, as a list - flood fill, path search, \"is anything next to me\", spreading fire, match-three clearing. Choose four sides, eight including diagonals, or the six neighbours of an axial hex board."))
	descriptors.append(F.make_descriptor("Core", "CellsInLine", "Cells In Line", ACEDescriptor.ACEType.EXPRESSION, "range(%s + 1).map(func(__step: int) -> Vector2i: return Vector2i(roundi(lerpf({from_cell}.x, {to_cell}.x, float(__step) / maxf(float(%s), 1.0))), roundi(lerpf({from_cell}.y, {to_cell}.y, float(__step) / maxf(float(%s), 1.0)))))" % [_CELL_STEPS, _CELL_STEPS, _CELL_STEPS], "", [F.make_param("from_cell", "Vector2i", "Vector2i(0, 0)", "From Cell", "Where the line starts.", "expression"), F.make_param("to_cell", "Vector2i", "Vector2i(4, 2)", "To Cell", "Where the line ends.", "expression")], MATH, "cells in the line from [b]{from_cell}[/b] to [b]{to_cell}[/b]")
		.described("Every cell a straight line passes through, in order from one cell to the other - a laser beam's path, tile-based line of sight, a corridor carved between two rooms, a ruler for a ranged attack. Both ends are included."))
	descriptors.append(F.make_descriptor("Core", "CellsInRadius", "Cells In Radius", ACEDescriptor.ACEType.EXPRESSION, _cells_in_radius_template(), "", _cells_in_radius_params(), MATH, "cells within [b]{radius}[/b] of [b]{center}[/b] ([b]{shape}[/b])")
		.described("Every cell within a step radius of a centre cell, as a list - a blast footprint, a range preview, a fog reveal, the tiles a tower covers. Choose the diamond (counting grid steps) or the square (counting king moves)."))
	descriptors.append(F.make_descriptor("Core", "CellsInRectangle", "Cells In Rectangle", ACEDescriptor.ACEType.EXPRESSION, "range({top_left}.y, {top_left}.y + maxi({size}.y, 0)).reduce(func(__rows: Array, __y: int) -> Array: return __rows + range({top_left}.x, {top_left}.x + maxi({size}.x, 0)).map(func(__x: int) -> Vector2i: return Vector2i(__x, __y)), [])", "", [F.make_param("top_left", "Vector2i", "Vector2i(0, 0)", "Top Left Cell", "Corner the block starts at.", "expression"), F.make_param("size", "Vector2i", "Vector2i(3, 3)", "Size In Cells", "How many cells across and down.", "expression")], MATH, "cells in the [b]{size}[/b] block at [b]{top_left}[/b]")
		.described("Every cell in a rectangular block, row by row - stamping a room, laying out an inventory grid, placing a multi-cell building, clearing a region of fog. An empty or negative size walks nothing rather than looping backwards."))
	descriptors.append(F.make_descriptor("Core", "IsCellInBounds", "Is Cell In Bounds", ACEDescriptor.ACEType.CONDITION, "({cell}.x >= 0 and {cell}.y >= 0 and {cell}.x < {size}.x and {cell}.y < {size}.y)", "", [F.make_param("cell", "Vector2i", "Vector2i(0, 0)", "Cell", "The cell being tested.", "expression"), F.make_param("size", "Vector2i", "Vector2i(20, 12)", "Board Size", "How many cells the board is across and down.", "expression")], MATH, "cell [b]{cell}[/b] is inside a [b]{size}[/b] board")
		.described("True while a cell is on the board - the guard before every placement, every move and every array lookup keyed by cell. Counting starts at 0,0 in the top-left, so a 20 by 12 board's last cell is 19,11.").featured())
	descriptors.append(F.make_descriptor("Core", "ForEachCellInRadius", "For Each Cell In Radius", ACEDescriptor.ACEType.CONDITION, _cells_in_radius_template(), "", _cells_in_radius_params(), LOOPS, "for each cell within [b]{radius}[/b] of [b]{center}[/b]")
		.described("Runs this event's actions once per cell within a step radius of a centre cell - range previews, blast footprints, fog reveal, area-of-effect highlights. Read the current one as `cell`.").looping("cell").featured())


## The cell-set template, shared by the Cells In Radius EXPRESSION and the For Each Cell In Radius
## LOOPING CONDITION so the two can never drift into disagreeing about what "within 2" means.
## Built as a reduce over rows because an expression cannot declare a local to accumulate into.
static func _cells_in_radius_template() -> String:
	return "(range(-{radius}, {radius} + 1).reduce(func(__rows: Array, __dy: int) -> Array: return __rows + range(-{radius}, {radius} + 1).map(func(__dx: int) -> Vector2i: return {center} + Vector2i(__dx, __dy)), []) as Array).filter(func(__cell: Vector2i) -> bool: return {shape} == 1 or absi(__cell.x - {center}.x) + absi(__cell.y - {center}.y) <= {radius})"


## The parameters both cell-set verbs take. Rebuilt per call: descriptors own their ACEParam
## resources, and two descriptors sharing one param instance would share every later edit.
static func _cells_in_radius_params() -> Array[ACEParam]:
	return [
		F.make_param("center", "Vector2i", "Vector2i(0, 0)", "Center Cell", "The middle of the area.", "expression"),
		F.make_param("radius", "int", "2", "Radius In Cells", "How many steps out from the middle.", "expression"),
		F.make_param("shape", "String", "1", "Shape", "Whether the corners count.", "", RADIUS_SHAPE_OPTIONS)
	]


# ── 5. Falloff and radial force ───────────────────────────────────────────────────────────────
# Distance-weighted strength is the single most reused number in game code, and the repo could
# already COLLECT everything in a blast while giving every body identical damage. Falloff At
# Distance is one number from 1 at the centre to 0 at the edge, safe to multiply straight into
# damage, knockback, screen shake or volume - and reading the same number for all of them is what
# makes an explosion feel like one event instead of four unrelated ones.
static func _append_falloff(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.make_descriptor("Core", "FalloffAtDistance", "Falloff At Distance", ACEDescriptor.ACEType.EXPRESSION, "([%s, %s * %s, smoothstep(0.0, 1.0, %s)][{shape}])" % [_NEARNESS, _NEARNESS, _NEARNESS, _NEARNESS], "", [F.make_param("center", "Vector2", "Vector2.ZERO", "Center", "Where the effect comes from.", "expression"), F.make_param("point", "Vector2", "Vector2(100, 0)", "Point", "What is being affected.", "expression"), F.make_param("radius", "float", "200.0", "Radius", "Past this it reads 0.", "expression"), F.make_param("shape", "String", "2", "Profile", "How quickly the strength drops off with distance.", "", FALLOFF_SHAPE_OPTIONS)], MATH, "falloff from [b]{center}[/b] at [b]{point}[/b] within [b]{radius}[/b]")
		.described("How strong an effect is at a distance, from 1 at the centre to 0 at the edge - the one number that makes an explosion, a sound, a magnet or a screen shake care how close it was. Anything past the radius reads as 0, so it is safe to multiply straight into damage. For a hand-drawn profile, feed this number into Sample Curve.").featured())
	descriptors.append(F.make_descriptor("Core", "StrengthToward", "Strength Toward", ACEDescriptor.ACEType.EXPRESSION, "(clampf(1.0 - global_position.distance_to({node}.global_position) / maxf({radius}, 0.001), 0.0, 1.0))", "", [F.make_param("node", "String", "get_parent()", "Toward", "The node the strength is measured against.", "expression"), F.make_param("radius", "float", "600.0", "Radius", "Past this it reads 0.", "expression")], MATH, "strength toward [i]{node}[/i] within [b]{radius}[/b]", "Node2D")
		.described("Falloff between THIS node and another one, without spelling out either position - guard suspicion that builds faster the closer you are, a magnet that pulls harder up close, a sound that ducks as you approach. Reads 0 once the other node is out of range."))
	descriptors.append(F.make_descriptor("Core", "ApplyRadialImpulse", "Apply Radial Impulse", ACEDescriptor.ACEType.ACTION, "var __blast_{uid}: Vector2 = global_position - {center}\napply_impulse(__blast_{uid}.normalized() * {strength} * clampf(1.0 - __blast_{uid}.length() / maxf({radius}, 0.001), 0.0, 1.0))", "", [F.make_param("center", "Vector2", "Vector2.ZERO", "Blast Center", "Where the explosion went off.", "expression"), F.make_param("strength", "float", "900.0", "Strength", "The push at the very centre, in impulse units.", "expression"), F.make_param("radius", "float", "240.0", "Radius", "Past this the push is nothing.", "expression")], MOVE, "apply radial impulse [b]{strength}[/b] from [b]{center}[/b]", "RigidBody2D")
		.described("Throws this physics body away from a blast, weaker the further it was - barrels, crates, ragdolls and debris flung by an explosion. One row on the body; the blast only has to say where it happened."))
	descriptors.append(F.make_descriptor("Core", "PushGroupAwayFrom", "Push Group Away From", ACEDescriptor.ACEType.ACTION, "for __blast_{uid}: Node in get_tree().get_nodes_in_group({group}):\n\tif __blast_{uid} is Node2D and (__blast_{uid} as Node2D).global_position.distance_to({center}) <= maxf({radius}, 0.001):\n\t\t(__blast_{uid} as Node2D).global_position += ((__blast_{uid} as Node2D).global_position - {center}).normalized() * {strength} * clampf(1.0 - (__blast_{uid} as Node2D).global_position.distance_to({center}) / maxf({radius}, 0.001), 0.0, 1.0)", "", [F.make_param("group", "String", "\"enemies\"", "Group", "Group whose members get shoved.", "group_reference"), F.make_param("center", "Vector2", "global_position", "Away From", "Where the shove comes from.", "expression"), F.make_param("radius", "float", "240.0", "Radius", "Only members inside this are shoved.", "expression"), F.make_param("strength", "float", "60.0", "Strength", "Pixels the closest member is moved.", "expression")], MOVE, "push group [b]{group}[/b] away from [b]{center}[/b] within [b]{radius}[/b]", "Node2D")
		.described("Shoves every member of a group away from a point, hardest at the centre and not at all past the radius - the mirror of Pull Group Toward. A shockwave clearing a crowd, a repulsor field, a dash that parts the enemies it passes through."))
	descriptors.append(F.make_descriptor("Core", "IsWithinConeOf", "Is Within Cone Of", ACEDescriptor.ACEType.CONDITION, "({point}.distance_to({origin}) <= maxf({range_px}, 0.0) and absf(angle_difference(deg_to_rad({facing_degrees}), ({point} - {origin}).angle())) <= deg_to_rad({fov_degrees}) * 0.5)", "", [F.make_param("origin", "Vector2", "Vector2.ZERO", "Cone From", "Tip of the wedge - the guard, the spotlight, the blast.", "expression"), F.make_param("facing_degrees", "float", "0.0", "Facing", "Which way the wedge points, in degrees.", "expression"), F.make_param("point", "Vector2", "Vector2(100, 0)", "Point", "The position being tested.", "expression"), F.make_param("fov_degrees", "float", "70.0", "Cone Width", "Total width of the wedge in degrees.", "expression"), F.make_param("range_px", "float", "600.0", "Reach", "How far the wedge extends, in pixels.", "expression")], MATH, "[b]{point}[/b] is within a [b]{fov_degrees}[/b] cone of [b]{origin}[/b] facing [b]{facing_degrees}[/b]")
		.described("True while a point sits inside a facing wedge - guard vision, spotlight checks, melee arcs, directional blasts. The cheap test to put in front of an expensive raycast: if it is not in the cone, there is nothing to trace.").featured())


## Moving and turning: one of six directions at a speed, the three turns in degrees a second, and
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


## Placing things in the world: on another object, and tilted onto the ground's slope.
static func _append_place(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.make_descriptor("Core", "SetPositionToObject3D",
		"Set Position To Another Object", ACEDescriptor.ACEType.ACTION,
		"global_position = {other}.global_position", "",
		[F.make_param("other", "String", "self", "Other",
			"The object to stand where - a spawn marker, a socket, another character.",
			"expression")],
		PAGE_PLACE, "Set position to [b]{other}[/b]", "Node3D")
		.described("Puts a 3D node exactly where another one is - how a spawn point, a socket or a respawn marker is used."))
	# The snap-to-floor run, written exactly as the reading recognises it - the ray straight down
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


## The facing questions: how far off facing something is, and which side of an object it is on.
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


## Angle and distance, both ways: the point an angle and a distance name, a ring of things placed
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
