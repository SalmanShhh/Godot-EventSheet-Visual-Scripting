# Pack builder - follow_path (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## Follow Path: the curved sibling of the Move To pack. Move To gives a straight-line waypoint
## queue; this walks a drawn Path2D at a real speed, arc-length paced, with once / loop / ping-pong
## and an optional rotate-to-face. Arrival is the SIGNAL (On Path Finished), never a per-frame poll -
## Is At Path End stays for the different question, "is it parked at the end right now". The pack
## also ships an editor gizmo, so the route and its ends are drawn in the 2D viewport on selection.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node2D"
	sheet.custom_class_name = "PathFollowBehavior"
	sheet.class_description = "Walks the host Node2D along a drawn Path2D at a real speed - patrol routes, conveyors, camera dollies and tower-defence lanes. Once, Loop or Ping-pong, with optional rotate-to-face, and On Path Finished when a one-shot run reaches the end."
	sheet.addon_category = "Path"
	sheet.addon_tags = PackedStringArray(["movement", "path", "curve"])
	var about: CommentRow = CommentRow.new()
	about.text = "Follow Path behavior: walks the host along a drawn Path2D at a real speed (arc-length paced, so a tight corner does not speed it up). Follow Path starts a run, On Path Finished fires when a Once run reaches the end, and Is At Path End answers the other question - is it parked there right now. This pack is an event sheet - extend it by editing it."
	sheet.events.append(about)

	var block: RawCodeRow = RawCodeRow.new()
	block.code = "\n".join(PackedStringArray([
		"# --- Designer knobs (tune in the Inspector) ---",
		"## The drawn route. Follow Path can hand over a different one at runtime; this is the",
		"## starting route, and the one the editor gizmo draws.",
		"@export var route: Path2D = null",
		"## Pixels per second along the curve. Arc-length paced, so corners do not speed it up.",
		"@export var travel_speed: float = 120.0",
		"## What happens at the end: stop (and fire On Path Finished), start over, or walk back.",
		"@export_enum(\"once\", \"loop\", \"pingpong\") var loop_mode: String = \"once\"",
		"## When on, the host turns to face the direction it is travelling along the curve.",
		"@export var rotate_to_face: bool = false",
		"## Start walking the route as soon as the scene runs, with no Follow Path row needed.",
		"@export var auto_start: bool = false",
		"",
		"# --- Internal state ---",
		"# How far along the curve the host is, in PIXELS of arc length (not a 0..1 fraction):",
		"# pacing by baked length is what keeps a tight corner from being crossed faster than a",
		"# straight. _travel_direction is +1 walking forward, -1 on the way back in ping-pong.",
		"var _distance: float = 0.0",
		"var _travel_direction: int = 1",
		"var _following: bool = false",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Path Finished\")",
		"## @ace_description(\"Fires the moment a Once run reaches the end of its route - the arrival branch. Loop and Ping-pong never end, so they never fire it.\")",
		"signal path_finished",
		"",
		"func _ready() -> void:",
		"\tif auto_start and route != null:",
		"\t\tfollow_path(route, travel_speed, loop_mode)",
		"\t# A host that is not walking a route has nothing to work out each frame, so a pack left",
		"\t# waiting for a Follow Path row costs nothing until that row runs.",
		"\tset_process(_following)",
		"",
		"## Puts the host where _distance says, and turns it if rotate_to_face is on. Positions come",
		"## out of the curve in the PATH's own space, so they are converted through the path node.",
		"## @ace_hidden",
		"func _apply_path_position() -> void:",
		"\tif host == null or route == null or route.curve == null:",
		"\t\treturn",
		"\tvar sample: Transform2D = route.curve.sample_baked_with_rotation(clampf(_distance, 0.0, route.curve.get_baked_length()))",
		"\thost.global_position = route.to_global(sample.origin)",
		"\tif rotate_to_face:",
		"\t\tvar facing: Vector2 = sample.x if _travel_direction >= 0 else -sample.x",
		"\t\thost.global_rotation = route.global_rotation + facing.angle()",
		"",
		"## @ace_action",
		"## @ace_name(\"Follow Path\")",
		"## @ace_description(\"Sends the host travelling along a drawn Path2D at a real speed - patrol routes, conveyor lanes, camera dollies, tower-defence lanes. Ping-pong walks it back and forth forever; Once fires On Path Finished at the end.\")",
		"## @ace_param_hint(path node)",
		"## @ace_param_options(mode once=Once, loop=Loop, pingpong=Ping-pong)",
		# The mode is a WORD picked off the dropdown above, and a dropdown key is inserted into the
		# call verbatim - so the quotes belong in the TEMPLATE, never in the key (a quoted key does
		# not survive the annotation round trip). Without them a row picking Loop asked
		# `follow_path(path, 120.0, loop)`, an undefined identifier, and the game did not parse.
		# The signature's own `"once"` reaches the picker as a QUOTED string, which matches none of
		# the three keys, so the dropdown opens on its first item - `once`, bare, exactly the word
		# the signature meant. The starting value is the dropdown's, never the quoted literal.
		"## @ace_codegen_template(\"$PathFollowBehavior.follow_path({path}, {speed}, \"{mode}\")\")",
		"func follow_path(path: Path2D, speed: float = 120.0, mode: String = \"once\") -> void:",
		"\tif path == null or path.curve == null or path.curve.get_baked_length() <= 0.0:",
		"\t\treturn",
		"\troute = path",
		"\ttravel_speed = speed",
		"\tloop_mode = mode",
		"\t_distance = 0.0",
		"\t_travel_direction = 1",
		"\t_following = true",
		"\t# There is a route to walk again, so the per-frame pacing is worth paying for.",
		"\tset_process(true)",
		"\t_apply_path_position()",
		"",
		"## @ace_action",
		"## @ace_name(\"Stop Following Path\")",
		"## @ace_description(\"Halts the run where it stands, WITHOUT firing On Path Finished - a stunned patroller, a conveyor switched off, a dolly interrupted by the player. Follow Path starts it again from the top.\")",
		"func stop_following_path() -> void:",
		"\t_following = false",
		"\t# A halted run costs nothing per frame; Follow Path turns processing back on.",
		"\tset_process(false)",
		"",
		"## @ace_condition",
		"## @ace_name(\"Is Following Path\")",
		"## @ace_description(\"True while the host is actually travelling - the gate for a walk animation, a conveyor's hum, or a Stop row that should only fire once.\")",
		"func is_following_path() -> bool:",
		"\treturn _following",
		"",
		"## @ace_condition",
		"## @ace_name(\"Is At Path End\")",
		"## @ace_description(\"True while the host is parked at the far end of its route right now. This is the STATE question, asked whenever a row is reached; for the moment of arrival use the On Path Finished trigger instead - it fires once, for free, with no per-frame checking.\")",
		"func is_at_path_end() -> bool:",
		"\tif route == null or route.curve == null:",
		"\t\treturn false",
		"\treturn _distance >= route.curve.get_baked_length() - 0.5",
		"",
		"## @ace_expression",
		"## @ace_name(\"Progress Along Path\")",
		"## @ace_description(\"How far along its route the host has come, from 0 at the start to 1 at the end - a racer's lap bar, a delivery tracker, a boss phase keyed to how far the sweep has gone.\")",
		"func progress_along_path() -> float:",
		"\tif route == null or route.curve == null or route.curve.get_baked_length() <= 0.0:",
		"\t\treturn 0.0",
		"\treturn clampf(_distance / route.curve.get_baked_length(), 0.0, 1.0)",
		"",
		"## @ace_expression",
		"## @ace_name(\"Point On Path At\")",
		"## @ace_description(\"The world point a fraction of the way along a path (0 is the start, 1 is the end) - drive a camera dolly, a progress marker, or a preview ghost without moving anything.\")",
		"## @ace_param_hint(path node)",
		"func point_on_path_at(path: Path2D, progress: float = 0.5) -> Vector2:",
		"\tif path == null or path.curve == null:",
		"\t\treturn Vector2.ZERO",
		"\treturn path.to_global(path.curve.sample_baked(clampf(progress, 0.0, 1.0) * path.curve.get_baked_length()))",
		"",
		"## @ace_expression",
		"## @ace_name(\"Direction Along Path At\")",
		"## @ace_description(\"Which way the path is heading a fraction of the way along it, as a direction one unit long - point a camera down the track, aim a spawned thing along the lane, or rotate a marker to match the curve.\")",
		"## @ace_param_hint(path node)",
		"func direction_along_path_at(path: Path2D, progress: float = 0.5) -> Vector2:",
		"\tif path == null or path.curve == null:",
		"\t\treturn Vector2.RIGHT",
		"\tvar sample: Transform2D = path.curve.sample_baked_with_rotation(clampf(progress, 0.0, 1.0) * path.curve.get_baked_length())",
		"\treturn (Vector2.RIGHT.rotated(path.global_rotation + sample.x.angle())).normalized()",
		"",
		"## @ace_expression",
		"## @ace_name(\"Path Length\")",
		"## @ace_description(\"How long a route is in pixels, measured along the curve rather than corner to corner - divide by a speed to know how many seconds the trip takes, or space things evenly along it.\")",
		"## @ace_param_hint(path node)",
		"func path_length(path: Path2D) -> float:",
		"\tif path == null or path.curve == null:",
		"\t\treturn 0.0",
		"\treturn path.curve.get_baked_length()",
		"",
		"## @ace_expression",
		"## @ace_name(\"Nearest Point On Path\")",
		"## @ace_description(\"The point on a route closest to a world position - snap a dragged tower onto the lane, work out where a stray unit rejoins its patrol, or find the spot on the track a racer left.\")",
		"## @ace_param_hint(path node)",
		"func nearest_point_on_path(path: Path2D, point: Vector2) -> Vector2:",
		"\tif path == null or path.curve == null:",
		"\t\treturn point",
		"\treturn path.to_global(path.curve.get_closest_point(path.to_local(point)))",
		"",
		"static func editor_gizmo_draw(params: Dictionary, host: Node2D, canvas: CanvasItem) -> void:",
		"\t# Editor-gizmo contract (select the host or this behavior in the editor): draws the route",
		"\t# in the 2D viewport, with a green dot at the start and an orange one at the end, so a",
		"\t# patrol reads at a glance and a route drawn backwards is obvious before you press play.",
		"\tvar drawn_route: Path2D = params.get(\"route\", null) as Path2D",
		"\tif drawn_route == null or drawn_route.curve == null or drawn_route.curve.get_point_count() < 2:",
		"\t\treturn",
		"\tvar baked: PackedVector2Array = drawn_route.curve.get_baked_points()",
		"\tif baked.size() < 2:",
		"\t\treturn",
		"\tvar points: PackedVector2Array = PackedVector2Array()",
		"\tfor point: Vector2 in baked:",
		"\t\tpoints.append(drawn_route.to_global(point))",
		"\t# The points are world-space; the canvas rides the host, so draw through the inverse.",
		"\tcanvas.draw_set_transform_matrix(host.get_global_transform().affine_inverse())",
		"\tcanvas.draw_polyline(points, Color(0.36, 0.78, 1.0, 0.9), 2.0)",
		"\tcanvas.draw_circle(points[0], 4.0, Color(0.45, 1.0, 0.6, 0.9))",
		"\tcanvas.draw_circle(points[points.size() - 1], 4.0, Color(1.0, 0.55, 0.35, 0.9))"
	]))
	sheet.events.append(block)

	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnProcess"
	var tick_body: RawCodeRow = RawCodeRow.new()
	tick_body.code = "\n".join(PackedStringArray([
		"if not _following or host == null or route == null or route.curve == null:",
		"\treturn",
		"var length: float = route.curve.get_baked_length()",
		"if length <= 0.0:",
		"\treturn",
		"_distance += travel_speed * delta * float(_travel_direction)",
		"if _distance >= length:",
		"\tif loop_mode == \"loop\":",
		"\t\t_distance = fmod(_distance, length)",
		"\telif loop_mode == \"pingpong\":",
		"\t\t# Reflect the overshoot rather than clamping it, so a fast mover keeps its pace",
		"\t\t# through the turn instead of pausing for a frame at the end.",
		"\t\t_distance = maxf(length - (_distance - length), 0.0)",
		"\t\t_travel_direction = -1",
		"\telse:",
		"\t\t_distance = length",
		"\t\t_following = false",
		"\t\t_apply_path_position()",
		"\t\t# The end of a Once run is a stop. Processing goes off BEFORE the trigger fires, so a",
		"\t\t# row that answers On Path Finished with another Follow Path turns it straight back on.",
		"\t\tset_process(false)",
		"\t\tpath_finished.emit()",
		"\t\treturn",
		"elif _distance <= 0.0 and _travel_direction < 0:",
		"\t_distance = minf(-_distance, length)",
		"\t_travel_direction = 1",
		"_apply_path_position()"
	]))
	tick.actions.append(tick_body)
	sheet.events.append(tick)

	return Lib.save_pack(sheet, "res://eventsheet_addons/follow_path/path_follow_behavior")
