# EventForge module - the rest of the Camera2D shelf (drift, snap, turns, the view, the limits).
#
# Six Camera2D rows shipped first: make current, zoom, offset, scroll limits, smoothing on or off,
# and scroll toward. They cover pointing a camera somewhere. What they leave out is everything a
# platformer camera actually asks for the day after: a dead zone the player may wander inside before
# the camera moves at all, the "stop drifting and glue yourself to me" switch beside it, the way to
# put the camera on its target THIS frame without watching it ease across the level from wherever a
# scene change left it, turning smoothly instead of snapping, and the two questions a camera gets
# asked from elsewhere in the sheet - what am I looking at, and is that thing inside it.
#
# WHY DRIFT IS TWO PERCENTAGES AND NOT FOUR MARGINS. Godot spells the dead zone as four independent
# margins plus two enable flags, which is six fields to fill in to say one thing. Almost nobody wants
# an asymmetric one: the dead zone people mean is "this much slack sideways, this much slack up and
# down", so the row asks for those two numbers and writes all six lines. The four margins are still
# there in the emitted code, as four plain assignments, so a game that really does want a lopsided
# box edits the line rather than fighting the row. The starting numbers are Godot's own defaults,
# asked of ClassDB rather than guessed, so a dropped row opens exactly where the Inspector opens.
#
# WHY SNAP IS ITS OWN ROW. `reset_smoothing()` is the one camera call that is impossible to guess
# from the property list: it does not turn smoothing off, it teleports the smoothed position to where
# it is heading. That is the fix for the shot that pans across the whole level on the first frame
# after a respawn, and it is one word.
#
# THE TWO QUESTIONS. View Rectangle answers "what is this camera showing", in WORLD units, which is
# the frame every off-screen cull, minimap box and spawn-outside-the-view line is measured against.
# It is deliberately one expression on the camera itself. Is Inside Camera View is the same rectangle
# asked from the other end - a node, a camera, and a margin - so a sheet on an enemy can ask the
# question without being a camera. It is NOT the shipped Is On Screen, which asks the engine's own
# visibility notifier about the node's whole drawn shape; this one is a point test against a
# rectangle you can also read, print and grow. Both are honest, and they answer different questions.
#
# FIT LIMITS TO AND TILED AREA ARE TWO ROWS, not one row with a branch in it. A level's extent is
# known two ways - the tiles somebody painted, or a rectangle somebody chose - and the difference
# between them is a VALUE, so it is an expression. Fit Limits To then does one thing in four plain
# assignments a reader can check, and Tiled Area answers for a minimap, an off-screen spawn and a
# cull just as well as it answers for the limits. Both corners of the tiled answer go out through
# to_global rather than being added to the layer's position, for the same reason the spawn
# placements do; camera limits are axis-aligned numbers, so a rotated layer has no answer to give
# here and this does not pretend otherwise.
#
# Module contract: see ace_factory.gd - ace_ids/templates are API (compatibility covenant); this file
# only changes where the descriptors are AUTHORED.
@tool
class_name EventForgeCamera2DACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

## The shelf these rows join: the same one the shipped Camera2D rows and the field-of-view rows sit
## on, so a camera page is one page rather than three.
const CAT: String = "Camera"


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []
	var drag_margin: String = F.default_literal("Camera2D", "drag_left_margin")

	# ── The dead zone, and the switch that turns it off ────────────────────────────────
	descriptors.append(F.act("CameraDriftMargins", "Let The Target Drift", "drag_horizontal_enabled = true\ndrag_vertical_enabled = true\ndrag_left_margin = {across}\ndrag_right_margin = {across}\ndrag_top_margin = {down}\ndrag_bottom_margin = {down}", CAT, "Let the target drift {across} across, {down} down", "Gives the camera a dead zone: the thing it follows may wander this far from the middle before the camera moves at all. The numbers are fractions of the view, so 0.2 is a fifth of the screen, and the same slack is used on both sides. This is what stops a platformer camera twitching under every small jump.", "Camera2D").param_typed("float", "across", drag_margin, "Across", "How far the target may drift left or right before the camera follows, as a fraction of the view.", "expression").param_typed("float", "down", drag_margin, "Down", "How far the target may drift up or down before the camera follows, as a fraction of the view.", "expression").featured())
	descriptors.append(F.act("CameraFollowTightly", "Follow Tightly", "drag_horizontal_enabled = false\ndrag_vertical_enabled = false", CAT, "Follow tightly", "Turns the dead zone off, so the camera keeps its target exactly in the middle. The other half of Let The Target Drift - reach for it when a boss arrives, when a cutscene starts, or any time the shot has to be exact.", "Camera2D"))
	descriptors.append(F.act("CameraSnapToTarget", "Snap To Target Now", "reset_smoothing()", CAT, "Snap to the target now", "Puts the camera where it is heading, this frame, instead of easing there. The fix for the long pan across the level on the first frame after a respawn or a scene change: smoothing stays on, it just stops owing you a journey.", "Camera2D").featured())
	descriptors.append(F.act("CameraSmoothTurns", "Smooth Turns", "rotation_smoothing_enabled = {enabled}\nrotation_smoothing_speed = {speed}", CAT, "Smooth turns {enabled} at {speed}", "Eases the camera's ROTATION the way Set Smoothing eases its position, so a camera that follows a tilting ship or a rotating gravity field turns instead of snapping. Higher speeds catch up sooner.", "Camera2D").param_choice("enabled", "true", "Smooth Turns", "true / false.", ["true", "false"]).param_typed("float", "speed", F.default_literal("Camera2D", "rotation_smoothing_speed"), "Speed", "How quickly the camera catches up with the angle it is turning to.", "expression"))

	# ── What the camera is showing, from both ends ─────────────────────────────────────
	# The same rectangle written twice, from the camera's own members and from a named camera's.
	# Both are wrapped in brackets on purpose: an expression that leads with a bracket is never handed
	# the optional cross-node prefix, which would otherwise try to read Rect2 off another node.
	descriptors.append(F.expr("CameraViewRect", "View Rectangle", "(Rect2(get_screen_center_position() - get_viewport_rect().size / zoom * 0.5, get_viewport_rect().size / zoom))", CAT, "the view rectangle", "What this camera is showing right now, as a rectangle in world units - zoom included. The frame to measure an off-screen cull, a minimap box or a spawn-just-outside-the-view against, and a value you can print while you work out why something is not where you expected.", "Camera2D").featured())
	descriptors.append(F.cond("IsInsideCameraView", "Is Inside Camera View", "({camera} != null and Rect2({camera}.get_screen_center_position() - {camera}.get_viewport_rect().size / {camera}.zoom * 0.5, {camera}.get_viewport_rect().size / {camera}.zoom).grow({margin}).has_point({node}.global_position))", CAT, "[i]{node}[/i] is inside the view of [i]{camera}[/i]","True when a node's own position sits inside what a camera is showing, with an optional margin so something can count as visible slightly before or after it really is. Reads false when there is no camera, so a scene change cannot fault it. This is the rectangle test - the shipped Is On Screen asks the engine's visibility notifier about the node's whole drawn shape instead, which is the better question for a large sprite.", "Node2D").param("node", "self", "Node", "The node to ask about.", "scene_node").param("camera", "get_viewport().get_camera_2d()", "Camera", "The camera whose view is being asked about. The default is whichever camera is looking at the scene right now.", "expression").param_typed("float", "margin", "0.0", "Margin", "How far outside the view still counts as inside, in world units. Negative shrinks the test area.", "expression"))

	# ── The level's edges ──────────────────────────────────────────────────────────────
	# Four plain assignments and no local at all, so the emitted lines say what they do and read back
	# as this row when somebody writes them by hand. The measuring is the OTHER row's job: a level's
	# extent is a rectangle, and where that rectangle comes from is a value, not a branch inside a
	# verb. That is also why the tile layer is an expression - it answers for a minimap, an
	# off-screen spawn and a cull just as well as it answers for the limits.
	descriptors.append(F.act("CameraFitLimits", "Fit Limits To", "limit_left = int({area}.position.x)\nlimit_top = int({area}.position.y)\nlimit_right = int({area}.end.x)\nlimit_bottom = int({area}.end.y)", CAT, "Fit limits to {area}", "Sets the four scroll limits from a rectangle, so the camera stops at the edges of the level instead of showing the void beyond them. Fill it with Tiled Area to fit the tiles somebody painted, or with a rectangle you chose. The limits are whole pixels, which is what Godot stores them as.", "Camera2D").param_suggesting("area", "Rect2(0, 0, 1920, 1080)", "Area", "The level's extent as a rectangle in world units. Tiled Area gives you the one the painted tiles make.", ["Rect2(0, 0, 1920, 1080)", "tiled_area", "get_viewport_rect()"], "expression").featured())
	# The tile layer measured in world units. It is one expression rather than a branch inside the row
	# above because a rectangle is a value: the same answer feeds a minimap, an off-screen spawn or a
	# cull, and each of them can check it on its own. Camera limits are AXIS-ALIGNED numbers, so a
	# rotated layer has no answer to give here and the row does not pretend otherwise; a scaled or
	# moved layer does, which is why both corners go out through to_global rather than being added to
	# the layer's position.
	descriptors.append(F.expr("TiledArea", "Tiled Area", "Rect2({layer}.to_global({layer}.map_to_local({layer}.get_used_rect().position) - Vector2({layer}.tile_set.tile_size) * 0.5), {layer}.to_global({layer}.map_to_local({layer}.get_used_rect().end - Vector2i.ONE) + Vector2({layer}.tile_set.tile_size) * 0.5) - {layer}.to_global({layer}.map_to_local({layer}.get_used_rect().position) - Vector2({layer}.tile_set.tile_size) * 0.5))", CAT, "the tiled area of [i]{layer}[/i]", "The rectangle the painted tiles cover, in world units - the level's own edges, measured rather than typed in. Feed it to Fit Limits To and the camera stops where the level does, however much the level grows. An unpainted layer measures nothing, so the answer is an empty rectangle rather than a wrong one.").param("layer", "$TileMapLayer", "Layer", "The TileMapLayer the level is painted on.", "scene_node").featured())

	# ── The camera the player is looking through ───────────────────────────────────────
	# Host-free on purpose: any sheet may ask which camera is live, and a row scoped to Camera2D
	# could only be asked by the camera itself, which already knows.
	descriptors.append(F.expr("CurrentCamera2D", "Current Camera", "get_viewport().get_camera_2d()", CAT, "the current camera", "The Camera2D the player is looking through right now, or nothing when there is none. Feed it to Is Inside Camera View, read its zoom, or shake whichever camera happens to be live without naming it by tree path."))

	return descriptors
