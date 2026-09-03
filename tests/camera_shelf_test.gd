# Godot EventSheets - the rest of the Camera2D and Camera3D shelf.
#
# Sixteen camera rows land beside the six Camera2D rows and the field-of-view rows that shipped
# first: the dead zone and its off switch, the snap, smooth turns, the view rectangle and the
# question asked of it from outside, the level-edge fit, both "which camera is live" readers, the
# timed look-at, the two projections, the clip range, and the two cursor-ray answers a camera gives
# about its OWN viewport.
#
# What this pins, and why each part is here:
#
#   1. THE AUTHORED FORM - identity, shelf and host straight off the two modules, so a row cannot
#      quietly change which class it belongs to or which page it appears on.
#   2. THE SHIPPED FORM - what the cross-node "On node" pass did to each template. A row whose
#      every line is a plain member operation gains the optional prefix and an "On node" field; a
#      template leading with a `var` or a bracket gains neither and is a self-verb. Both outcomes
#      are deliberate, and a template that changed sides would be a silent behaviour change, so
#      both are pinned.
#   3. THE EMITTED CODE - two real sheets compiled, one per dimension, with every line pinned and
#      the whole output parse-checked. `{uid}` is baked the way the dock bakes it at apply time.
#   4. THE LIFT - the same output opened back as a sheet. Every row that can be recognised comes
#      back as itself, and the whole file re-emits byte for byte either way, which is the lossless
#      contract measured rather than assumed.
#   5. THE ARITHMETIC, WITH VALUES - the view rectangle and the inside-the-view test are evaluated
#      as the exact text they emit, with the four engine reads (the camera's screen centre, its
#      viewport size, its zoom, the node's place) replaced by fixture values. A test cannot reach a
#      viewport, so the engine's own answers are the one thing stood in for; the arithmetic around
#      them is the shipped text, character for character.
#   6. FIT LIMITS TO AND TILED AREA, DRIVEN FOR REAL - the emitted script is attached to a Camera2D
#      and run against a TileMapLayer with two painted cells, and the four limits it writes are
#      pinned as numbers. Neither node needs a scene tree: the whole measurement is the layer's own
#      transform and its own used rect.
@tool
class_name CameraShelfTest
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")

## The nine rows of the 2D module and the seven of the 3D one, in the order they are authored.
const ROWS_2D: Array[String] = ["CameraDriftMargins", "CameraFollowTightly", "CameraSnapToTarget",
	"CameraSmoothTurns", "CameraViewRect", "IsInsideCameraView", "CameraFitLimits", "TiledArea",
	"CurrentCamera2D"]
const ROWS_3D: Array[String] = ["CameraLookAtOverSeconds", "CameraSwitchToPerspective",
	"CameraSwitchToOrthogonal", "CameraSetClipRange", "CurrentCamera3D", "CameraCursorOverSomething",
	"CameraPointUnderCursor"]

## The fixture the arithmetic pins stand the engine's four reads in for: a camera centred at
## (100, 50) in the world, showing a 640x360 viewport at 2x zoom. Two times zoom halves what is
## visible, so the view is 320x180 world units wide and its corner sits at (-60, -40).
const FIXTURE_CENTRE: String = "Vector2(100, 50)"
const FIXTURE_VIEWPORT: String = "Vector2(640, 360)"
const FIXTURE_ZOOM: String = "Vector2(2, 2)"

## The tile fixture: 16-pixel tiles with cells painted at (2, 3) and (5, 6). The painted block
## therefore runs from the top-left corner of (2, 3) to the bottom-right corner of (5, 6), which is
## (32, 48) to (96, 112) in world units - the four numbers the limits pins expect.
const TILE_SIZE: int = 16
const PAINTED_FROM: Vector2i = Vector2i(2, 3)
const PAINTED_TO: Vector2i = Vector2i(5, 6)


static func run() -> bool:
	var all_passed: bool = true
	var authored: Dictionary = {}
	for descriptor in EventForgeCamera2DACEs.get_descriptors():
		authored[descriptor.ace_id] = descriptor
	for descriptor in EventForgeCamera3DACEs.get_descriptors():
		authored[descriptor.ace_id] = descriptor
	var shipped: Dictionary = {}
	for descriptor in EventForgeBuiltinACEs.get_descriptors():
		shipped[descriptor.ace_id] = descriptor

	all_passed = _pin_authored(authored) and all_passed
	all_passed = _pin_shipped(shipped) and all_passed
	all_passed = _pin_emitted_2d(shipped) and all_passed
	all_passed = _pin_emitted_3d(shipped) and all_passed
	all_passed = _pin_arithmetic(shipped) and all_passed
	all_passed = _pin_fit_limits(shipped) and all_passed
	all_passed = _pin_mixed_receivers() and all_passed
	return all_passed


## THE RECEIVERS OF A RUN HAVE TO AGREE. Every camera run is a handful of member operations, and a
## member operation may be written with a node in front of it or without one. A run whose lines
## address DIFFERENT nodes is not one row about one camera, and claiming it as one would put the
## whole run on the first node the moment somebody edited a field. The bytes never move either way,
## which is exactly why this needs a pin of its own: nothing else in the suite can see it.
##
## Each case below is a real spelling somebody would write, opened as a sheet and asked what the
## first row is. A run that DOES agree still reads as its row - so a guard that refused everything
## would fail here too - and the mixed ones fall back to the readings the single lines already had.
static func _pin_mixed_receivers() -> bool:
	var rows: Array = []
	for case: Array in [
		["a clip range on one node", "$Cam.near = 0.1\n$Cam.far = 2000.0", "CameraSetClipRange"],
		["a clip range on no node", "near = 0.1\nfar = 2000.0", "CameraSetClipRange"],
		["a clip range split over two nodes", "$Other.near = 0.1\n$Cam.far = 2000.0", ""],
		["a clip range whose second line names nobody", "$Other.near = 0.1\nfar = 2000.0", ""],
		["a projection split over two nodes",
			"$Cam.projection = Camera3D.PROJECTION_PERSPECTIVE\n$Other.fov = 70.0", ""],
		["smooth turns split over two nodes",
			"$Cam.rotation_smoothing_enabled = true\n$Other.rotation_smoothing_speed = 4.0", ""],
		["a dead zone whose last line names nobody",
			"$Cam.drag_horizontal_enabled = true\n$Cam.drag_vertical_enabled = true\n"
			+ "$Cam.drag_left_margin = 0.25\n$Cam.drag_right_margin = 0.25\n"
			+ "$Cam.drag_top_margin = 0.15\ndrag_bottom_margin = 0.15", ""],
	]:
		var claim: Dictionary = EventForgeCameraLift.match_run(str(case[1]).split("\n"), 0, 0)
		rows.append(["%s reads as %s" % [str(case[0]),
			str(case[2]) if not str(case[2]).is_empty() else "no run at all"],
			str(claim.get("ace_id", "")), str(case[2])])
	return SUPPORT.pins("camera_shelf_test", rows)


## Identity, shelf and host, off the modules themselves - before the registry's cross-node pass has
## touched anything.
static func _pin_authored(authored: Dictionary) -> bool:
	var rows: Array = []
	for ace_id: String in ROWS_2D + ROWS_3D:
		rows.append(["%s is authored" % ace_id, authored.has(ace_id), true])
	var passed: bool = SUPPORT.pins("camera_shelf_test", rows)
	var kinds: Dictionary = {
		"CameraDriftMargins": ACEDescriptor.ACEType.ACTION,
		"CameraFollowTightly": ACEDescriptor.ACEType.ACTION,
		"CameraSnapToTarget": ACEDescriptor.ACEType.ACTION,
		"CameraSmoothTurns": ACEDescriptor.ACEType.ACTION,
		"CameraViewRect": ACEDescriptor.ACEType.EXPRESSION,
		"IsInsideCameraView": ACEDescriptor.ACEType.CONDITION,
		"CameraFitLimits": ACEDescriptor.ACEType.ACTION,
		"TiledArea": ACEDescriptor.ACEType.EXPRESSION,
		"CurrentCamera2D": ACEDescriptor.ACEType.EXPRESSION,
		"CameraLookAtOverSeconds": ACEDescriptor.ACEType.ACTION,
		"CameraSwitchToPerspective": ACEDescriptor.ACEType.ACTION,
		"CameraSwitchToOrthogonal": ACEDescriptor.ACEType.ACTION,
		"CameraSetClipRange": ACEDescriptor.ACEType.ACTION,
		"CurrentCamera3D": ACEDescriptor.ACEType.EXPRESSION,
		"CameraCursorOverSomething": ACEDescriptor.ACEType.CONDITION,
		"CameraPointUnderCursor": ACEDescriptor.ACEType.EXPRESSION
	}
	var hosts: Dictionary = {
		"CameraDriftMargins": "Camera2D",
		"CameraFollowTightly": "Camera2D",
		"CameraSnapToTarget": "Camera2D",
		"CameraSmoothTurns": "Camera2D",
		"CameraViewRect": "Camera2D",
		"IsInsideCameraView": "Node2D",
		"CameraFitLimits": "Camera2D",
		"TiledArea": "",
		"CurrentCamera2D": "",
		"CameraLookAtOverSeconds": "Camera3D",
		"CameraSwitchToPerspective": "Camera3D",
		"CameraSwitchToOrthogonal": "Camera3D",
		"CameraSetClipRange": "Camera3D",
		"CurrentCamera3D": "",
		"CameraCursorOverSomething": "Camera3D",
		"CameraPointUnderCursor": "Camera3D"
	}
	var names: Dictionary = {
		"CameraDriftMargins": "Let The Target Drift",
		"CameraFollowTightly": "Follow Tightly",
		"CameraSnapToTarget": "Snap To Target Now",
		"CameraSmoothTurns": "Smooth Turns",
		"CameraViewRect": "View Rectangle",
		"IsInsideCameraView": "Is Inside Camera View",
		"CameraFitLimits": "Fit Limits To",
		"TiledArea": "Tiled Area",
		"CurrentCamera2D": "Current Camera",
		"CameraLookAtOverSeconds": "Look At Over Seconds",
		"CameraSwitchToPerspective": "Switch To Perspective",
		"CameraSwitchToOrthogonal": "Switch To Orthogonal",
		"CameraSetClipRange": "Set Clip Range",
		"CurrentCamera3D": "Current Camera (3D)",
		"CameraCursorOverSomething": "Something Is Under The Cursor",
		"CameraPointUnderCursor": "Point Under The Cursor"
	}
	var detail: Array = []
	for ace_id: String in names:
		if not authored.has(ace_id):
			continue
		var descriptor: ACEDescriptor = authored[ace_id]
		detail.append(["%s is named for the picker" % ace_id, str(descriptor.display_name), str(names[ace_id])])
		detail.append(["%s is the right kind of row" % ace_id, descriptor.ace_type, kinds[ace_id]])
		detail.append(["%s belongs to its host" % ace_id, str(descriptor.node_type), str(hosts[ace_id])])
		detail.append(["%s sits on the Camera shelf" % ace_id, str(descriptor.category), "Camera"])
		detail.append(["%s says what it does" % ace_id, str(descriptor.description).is_empty(), false])
	return SUPPORT.pins("camera_shelf_test", detail) and passed


## What the registry's cross-node pass did to each template. A plain member operation earns the
## optional `{target.}` prefix and an "On node" field; a template leading with `var` or a bracket
## earns neither, and is a self-verb by construction.
static func _pin_shipped(shipped: Dictionary) -> bool:
	var rows: Array = [
		["Let The Target Drift writes six lines under the optional prefix",
			str((shipped["CameraDriftMargins"] as ACEDescriptor).codegen_template),
			"{target.}drag_horizontal_enabled = true\n{target.}drag_vertical_enabled = true\n{target.}drag_left_margin = {across}\n{target.}drag_right_margin = {across}\n{target.}drag_top_margin = {down}\n{target.}drag_bottom_margin = {down}"],
		["Let The Target Drift asks two numbers and then the node", _param_ids(shipped["CameraDriftMargins"]), "across,down,target"],
		["Let The Target Drift opens on Godot's own margin", _default_of(shipped["CameraDriftMargins"], "across"), "0.2"],
		["Follow Tightly turns both drags off",
			str((shipped["CameraFollowTightly"] as ACEDescriptor).codegen_template),
			"{target.}drag_horizontal_enabled = false\n{target.}drag_vertical_enabled = false"],
		["Snap To Target Now is the one call that means it",
			str((shipped["CameraSnapToTarget"] as ACEDescriptor).codegen_template), "{target.}reset_smoothing()"],
		["Smooth Turns sets the flag and the speed",
			str((shipped["CameraSmoothTurns"] as ACEDescriptor).codegen_template),
			"{target.}rotation_smoothing_enabled = {enabled}\n{target.}rotation_smoothing_speed = {speed}"],
		["Smooth Turns opens on Godot's own speed", _default_of(shipped["CameraSmoothTurns"], "speed"), "5.0"],
		["View Rectangle is one bracketed expression and takes no node",
			str((shipped["CameraViewRect"] as ACEDescriptor).codegen_template),
			"(Rect2(get_screen_center_position() - get_viewport_rect().size / zoom * 0.5, get_viewport_rect().size / zoom))"],
		["View Rectangle gains no On node field", _param_ids(shipped["CameraViewRect"]), ""],
		["Is Inside Camera View guards the missing camera first",
			str((shipped["IsInsideCameraView"] as ACEDescriptor).codegen_template),
			"({camera} != null and Rect2({camera}.get_screen_center_position() - {camera}.get_viewport_rect().size / {camera}.zoom * 0.5, {camera}.get_viewport_rect().size / {camera}.zoom).grow({margin}).has_point({node}.global_position))"],
		["Is Inside Camera View asks node, camera, margin", _param_ids(shipped["IsInsideCameraView"]), "node,camera,margin"],
		["Is Inside Camera View defaults to whichever camera is live",
			_default_of(shipped["IsInsideCameraView"], "camera"), "get_viewport().get_camera_2d()"],
		["Fit Limits To writes the four limits off one rectangle",
			str((shipped["CameraFitLimits"] as ACEDescriptor).codegen_template),
			"{target.}limit_left = int({area}.position.x)\n{target.}limit_top = int({area}.position.y)\n{target.}limit_right = int({area}.end.x)\n{target.}limit_bottom = int({area}.end.y)"],
		["Fit Limits To asks for the area and then the node", _param_ids(shipped["CameraFitLimits"]), "area,target"],
		["Tiled Area measures both corners in world units",
			str((shipped["TiledArea"] as ACEDescriptor).codegen_template),
			"Rect2({layer}.to_global({layer}.map_to_local({layer}.get_used_rect().position) - Vector2({layer}.tile_set.tile_size) * 0.5), {layer}.to_global({layer}.map_to_local({layer}.get_used_rect().end - Vector2i.ONE) + Vector2({layer}.tile_set.tile_size) * 0.5) - {layer}.to_global({layer}.map_to_local({layer}.get_used_rect().position) - Vector2({layer}.tile_set.tile_size) * 0.5))"],
		["Tiled Area asks only which layer", _param_ids(shipped["TiledArea"]), "layer"],
		["Current Camera reads the live 2D camera",
			str((shipped["CurrentCamera2D"] as ACEDescriptor).codegen_template), "get_viewport().get_camera_2d()"],
		["Look At Over Seconds walks the shortest rotation",
			str((shipped["CameraLookAtOverSeconds"] as ACEDescriptor).codegen_template).contains("__from_{uid}.slerp(__to_{uid}, __weight_{uid})"), true],
		["Look At Over Seconds refuses a target it is standing on",
			str((shipped["CameraLookAtOverSeconds"] as ACEDescriptor).codegen_template).contains("if __aim_{uid}.length_squared() > 0.000001:"), true],
		["Look At Over Seconds asks what to face and for how long", _param_ids(shipped["CameraLookAtOverSeconds"]), "at,seconds"],
		["Switch To Perspective names the projection and the angle",
			str((shipped["CameraSwitchToPerspective"] as ACEDescriptor).codegen_template),
			"{target.}projection = Camera3D.PROJECTION_PERSPECTIVE\n{target.}fov = {degrees}"],
		["Switch To Orthogonal names the projection and the height",
			str((shipped["CameraSwitchToOrthogonal"] as ACEDescriptor).codegen_template),
			"{target.}projection = Camera3D.PROJECTION_ORTHOGONAL\n{target.}size = {size}"],
		["Set Clip Range writes both ends",
			str((shipped["CameraSetClipRange"] as ACEDescriptor).codegen_template),
			"{target.}near = {near}\n{target.}far = {far}"],
		["Set Clip Range opens on Godot's own near plane", _default_of(shipped["CameraSetClipRange"], "near"), "0.05"],
		["Set Clip Range opens on Godot's own far plane", _default_of(shipped["CameraSetClipRange"], "far"), "4000.0"],
		["Current Camera (3D) reads the live 3D camera",
			str((shipped["CurrentCamera3D"] as ACEDescriptor).codegen_template), "get_viewport().get_camera_3d()"],
		["Something Is Under The Cursor asks this camera's own viewport",
			str((shipped["CameraCursorOverSomething"] as ACEDescriptor).codegen_template),
			"(not get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(project_ray_origin(get_viewport().get_mouse_position()), project_ray_origin(get_viewport().get_mouse_position()) + project_ray_normal(get_viewport().get_mouse_position()) * {reach}, {layers})).is_empty())"],
		["Something Is Under The Cursor asks reach and layers", _param_ids(shipped["CameraCursorOverSomething"]), "reach,layers"],
		["Point Under The Cursor falls back to the far end of the ray",
			str((shipped["CameraPointUnderCursor"] as ACEDescriptor).codegen_template).contains(".get(\"position\", project_ray_origin(get_viewport().get_mouse_position()) + project_ray_normal(get_viewport().get_mouse_position()) * {reach}))"), true],
		["Point Under The Cursor gains no On node field", _param_ids(shipped["CameraPointUnderCursor"]), "reach,layers"]
	]
	return SUPPORT.pins("camera_shelf_test", rows)


## A real Camera2D sheet: every 2D verb in one per-frame event, behind the inside-the-view question.
## The emitted lines are pinned exactly, the output is parse-checked, and the whole file is opened
## back as a sheet to prove the lift and the byte round trip.
static func _pin_emitted_2d(shipped: Dictionary) -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Camera2D"
	var row: EventRow = EventRow.new()
	row.trigger_provider_id = "Core"
	row.trigger_id = "OnProcess"
	row.conditions.append(_condition(shipped, "IsInsideCameraView",
		{"node": "self", "camera": "get_viewport().get_camera_2d()", "margin": "0.0"}, ""))
	row.actions.append(_action(shipped, "CameraDriftMargins", {"across": "0.25", "down": "0.15", "target": ""}, ""))
	row.actions.append(_action(shipped, "CameraFollowTightly", {"target": ""}, ""))
	row.actions.append(_action(shipped, "CameraSnapToTarget", {"target": ""}, ""))
	row.actions.append(_action(shipped, "CameraSmoothTurns", {"enabled": "true", "speed": "4.0", "target": ""}, ""))
	row.actions.append(_action(shipped, "CameraFitLimits", {"area": _tiled_area(shipped, "$TileMapLayer"), "target": ""}, ""))
	sheet.events.append(row)
	var output: String = SUPPORT.compile_output(sheet, "user://camera_shelf_2d.gd")
	var rows: Array = [
		["the inside-the-view question emits as one guarded term",
			output.contains("if (get_viewport().get_camera_2d() != null and Rect2(get_viewport().get_camera_2d().get_screen_center_position() - get_viewport().get_camera_2d().get_viewport_rect().size / get_viewport().get_camera_2d().zoom * 0.5, get_viewport().get_camera_2d().get_viewport_rect().size / get_viewport().get_camera_2d().zoom).grow(0.0).has_point(self.global_position)):"), true],
		["the drift writes all six camera lines with a blank target dropped",
			output.contains("\t\tdrag_horizontal_enabled = true\n\t\tdrag_vertical_enabled = true\n\t\tdrag_left_margin = 0.25\n\t\tdrag_right_margin = 0.25\n\t\tdrag_top_margin = 0.15\n\t\tdrag_bottom_margin = 0.15"), true],
		["following tightly writes both drags off",
			output.contains("\t\tdrag_horizontal_enabled = false\n\t\tdrag_vertical_enabled = false"), true],
		["the snap emits the one call", output.contains("\t\treset_smoothing()"), true],
		["smooth turns emits the flag and the speed",
			output.contains("\t\trotation_smoothing_enabled = true\n\t\trotation_smoothing_speed = 4.0"), true],
		["the fit takes the tiled rectangle whole",
			output.contains("\t\tlimit_left = int(Rect2($TileMapLayer.to_global($TileMapLayer.map_to_local($TileMapLayer.get_used_rect().position) - Vector2($TileMapLayer.tile_set.tile_size) * 0.5)"), true],
		["the fit writes all four limits", output.contains(".end.y)"), true],
		["no {uid} token survives into the emitted script", output.contains("{uid}"), false],
		["the compiled 2D sheet is valid GDScript", _parses(output), true]
	]
	var passed: bool = SUPPORT.pins("camera_shelf_test", rows)
	return _pin_lift("2D", output, "user://camera_shelf_2d_roundtrip.gd",
		["CameraDriftMargins", "CameraFollowTightly", "CameraSnapToTarget", "CameraSmoothTurns", "CameraFitLimits"],
		["IsInsideCameraView"]) and passed


## A real Camera3D sheet, the same way: the timed look-at, both projections and the clip range,
## behind the cursor question.
static func _pin_emitted_3d(shipped: Dictionary) -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Camera3D"
	var row: EventRow = EventRow.new()
	row.trigger_provider_id = "Core"
	row.trigger_id = "OnProcess"
	row.conditions.append(_condition(shipped, "CameraCursorOverSomething", {"reach": "1000.0", "layers": "4294967295"}, ""))
	row.actions.append(_action(shipped, "CameraLookAtOverSeconds", {"at": "$Player", "seconds": "0.6"}, "l1"))
	row.actions.append(_action(shipped, "CameraSwitchToPerspective", {"degrees": "70.0", "target": ""}, ""))
	row.actions.append(_action(shipped, "CameraSwitchToOrthogonal", {"size": "12.0", "target": ""}, ""))
	row.actions.append(_action(shipped, "CameraSetClipRange", {"near": "0.1", "far": "2000.0", "target": ""}, ""))
	sheet.events.append(row)
	var output: String = SUPPORT.compile_output(sheet, "user://camera_shelf_3d.gd")
	var rows: Array = [
		["the cursor question emits this camera's own ray",
			output.contains("if (not get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(project_ray_origin(get_viewport().get_mouse_position()), project_ray_origin(get_viewport().get_mouse_position()) + project_ray_normal(get_viewport().get_mouse_position()) * 1000.0, 4294967295)).is_empty()):"), true],
		["the timed look-at bakes its aim local", output.contains("\t\tvar __aim_l1: Vector3 = $Player.global_position - global_position"), true],
		["the timed look-at tweens between two orientations",
			output.contains("create_tween().tween_method(func(__weight_l1: float) -> void: global_basis = __from_l1.slerp(__to_l1, __weight_l1), 0.0, 1.0, maxf(0.6, 0.001))"), true],
		["switching to perspective emits the projection and the angle",
			output.contains("\t\tprojection = Camera3D.PROJECTION_PERSPECTIVE\n\t\tfov = 70.0"), true],
		["switching to orthogonal emits the projection and the height",
			output.contains("\t\tprojection = Camera3D.PROJECTION_ORTHOGONAL\n\t\tsize = 12.0"), true],
		["the clip range emits both ends", output.contains("\t\tnear = 0.1\n\t\tfar = 2000.0"), true],
		["no {uid} token survives into the emitted script", output.contains("{uid}"), false],
		["the compiled 3D sheet is valid GDScript", _parses(output), true]
	]
	var passed: bool = SUPPORT.pins("camera_shelf_test", rows)
	return _pin_lift("3D", output, "user://camera_shelf_3d_roundtrip.gd",
		["CameraLookAtOverSeconds", "CameraSwitchToPerspective", "CameraSwitchToOrthogonal", "CameraSetClipRange"],
		["CameraCursorOverSomething"]) and passed


## The lift half, for one compiled sheet: the rows named come back as themselves when the file is
## opened again, and the file re-emits byte for byte whatever the lift claimed. A row nothing claims
## stays honest GDScript, which the byte pin is what actually guarantees.
static func _pin_lift(label: String, source: String, verify_path: String, action_ids: Array[String], condition_ids: Array[String]) -> bool:
	var reopened: EventSheetResource = SUPPORT.reopen(source)
	var lifted_actions: Array[String] = []
	var lifted_conditions: Array[String] = []
	for item: Variant in reopened.events:
		if not (item is EventRow):
			continue
		for entry: Variant in (item as EventRow).actions:
			if entry is ACEAction:
				lifted_actions.append(str((entry as ACEAction).ace_id))
		for entry: Variant in (item as EventRow).conditions:
			if entry is ACECondition:
				lifted_conditions.append(str((entry as ACECondition).ace_id))
	var rows: Array = []
	for ace_id: String in action_ids:
		rows.append(["%s: a hand-written %s reads back as itself" % [label, ace_id], lifted_actions.has(ace_id), true])
	for ace_id: String in condition_ids:
		rows.append(["%s: a hand-written %s reads back as itself" % [label, ace_id], lifted_conditions.has(ace_id), true])
	rows.append(["%s: the reopened sheet re-emits byte for byte" % label, SUPPORT.reemit(source, verify_path) == source, true])
	return SUPPORT.pins("camera_shelf_test", rows)


## The two rectangle rows evaluated as the exact text they emit, with the engine's four reads stood
## in for. A test has no viewport to ask, so the camera's screen centre, its viewport size, its zoom
## and the node's place are fixture values; everything between them is the shipped template.
static func _pin_arithmetic(shipped: Dictionary) -> bool:
	var view: String = str((shipped["CameraViewRect"] as ACEDescriptor).codegen_template) \
		.replace("get_screen_center_position()", FIXTURE_CENTRE) \
		.replace("get_viewport_rect().size", FIXTURE_VIEWPORT) \
		.replace("zoom", FIXTURE_ZOOM)
	var rows: Array = [
		["the view rectangle is the world the camera shows", _evaluate(view), Rect2(-60.0, -40.0, 320.0, 180.0)]
	]
	var inside: String = str((shipped["IsInsideCameraView"] as ACEDescriptor).codegen_template) \
		.replace("{camera}.get_screen_center_position()", FIXTURE_CENTRE) \
		.replace("{camera}.get_viewport_rect().size", FIXTURE_VIEWPORT) \
		.replace("{camera}.zoom", FIXTURE_ZOOM) \
		.replace("{camera} != null", "true")
	rows.append(["a point in the middle of the view is inside it",
		_evaluate(inside.replace("{node}.global_position", "Vector2(100, 50)").replace("{margin}", "0.0")), true])
	rows.append(["a point past the right edge is outside it",
		_evaluate(inside.replace("{node}.global_position", "Vector2(261, 50)").replace("{margin}", "0.0")), false])
	rows.append(["that same point is inside once the test is grown to reach it",
		_evaluate(inside.replace("{node}.global_position", "Vector2(261, 50)").replace("{margin}", "8.0")), true])
	rows.append(["a point just inside the top edge is inside it",
		_evaluate(inside.replace("{node}.global_position", "Vector2(100, -39)").replace("{margin}", "0.0")), true])
	rows.append(["a shrunk test drops a point near the edge",
		_evaluate(inside.replace("{node}.global_position", "Vector2(100, -39)").replace("{margin}", "-4.0")), false])
	return SUPPORT.pins("camera_shelf_test", rows)


## Fit Limits To, run for real: the emitted script on a Camera2D, a TileMapLayer with two painted
## cells, and the four limits pinned as numbers. Neither node is in a scene tree, and neither needs
## to be - the whole measurement is the layer's own transform and its own used rect.
static func _pin_fit_limits(shipped: Dictionary) -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Camera2D"
	var row: EventRow = EventRow.new()
	row.trigger_provider_id = "Core"
	row.trigger_id = "OnProcess"
	row.actions.append(_action(shipped, "CameraFitLimits", {"area": _tiled_area(shipped, "$TileMapLayer"), "target": ""}, ""))
	sheet.events.append(row)
	var output: String = SUPPORT.compile_output(sheet, "user://camera_shelf_fit.gd")
	var script: GDScript = GDScript.new()
	script.source_code = output
	var loaded: int = script.reload(true)
	# `$TileMapLayer` is get_node("TileMapLayer"), which answers for a node's OWN children whether or
	# not anything here is in a scene tree - so the layer goes under the camera and the emitted code
	# reaches it exactly as it would in a real scene.
	var camera: Camera2D = Camera2D.new()
	camera.add_child(_painted_layer(true))
	var answers: Array = []
	if loaded == OK:
		camera.set_script(script)
		camera.call("_process", 0.0)
		answers = [camera.limit_left, camera.limit_top, camera.limit_right, camera.limit_bottom]
	var rows: Array = [
		["the emitted fit script loads", loaded, OK],
		["the limits land on the painted tiles", answers, [32, 48, 96, 112]]
	]
	# A layer nobody has painted covers nothing, so the rectangle it measures is empty and the limits
	# it writes are the four zeros that says - never a wrong rectangle, and never the far side of one.
	var empty_camera: Camera2D = Camera2D.new()
	empty_camera.add_child(_painted_layer(false))
	var unpainted: Array = []
	if loaded == OK:
		empty_camera.set_script(script)
		empty_camera.call("_process", 0.0)
		unpainted = [empty_camera.limit_left, empty_camera.limit_top, empty_camera.limit_right, empty_camera.limit_bottom]
	rows.append(["an unpainted layer measures an empty rectangle", unpainted, [0, 0, 0, 0]])
	var passed: bool = SUPPORT.pins("camera_shelf_test", rows)
	camera.free()
	empty_camera.free()
	return passed


## The Tiled Area expression as a value a field holds, with the layer filled in - which is how one
## row's answer reaches another row's field in a real sheet.
static func _tiled_area(shipped: Dictionary, layer: String) -> String:
	return str((shipped["TiledArea"] as ACEDescriptor).codegen_template).replace("{layer}", layer)


## A TileMapLayer with 16-pixel tiles, named the way the emitted `$TileMapLayer` reaches it, and with
## the two fixture cells painted when asked for - an unpainted one is the empty-level case.
static func _painted_layer(painted: bool) -> TileMapLayer:
	var tile_set: TileSet = TileSet.new()
	tile_set.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	var source: TileSetAtlasSource = TileSetAtlasSource.new()
	var texture: PlaceholderTexture2D = PlaceholderTexture2D.new()
	texture.size = Vector2(TILE_SIZE, TILE_SIZE)
	source.texture = texture
	source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	source.create_tile(Vector2i.ZERO)
	var source_id: int = tile_set.add_source(source)
	var layer: TileMapLayer = TileMapLayer.new()
	layer.name = "TileMapLayer"
	layer.tile_set = tile_set
	if painted:
		layer.set_cell(PAINTED_FROM, source_id, Vector2i.ZERO)
		layer.set_cell(PAINTED_TO, source_id, Vector2i.ZERO)
	return layer


## One expression text, evaluated. Returns the error text rather than null on a refusal, so a broken
## pin says which half of it broke instead of comparing two nothings.
static func _evaluate(text: String) -> Variant:
	var expression: Expression = Expression.new()
	if expression.parse(text) != OK:
		return "parse refused: " + expression.get_error_text()
	var value: Variant = expression.execute()
	return ("execute refused: " + expression.get_error_text()) if expression.has_execute_failed() else value


static func _param_ids(descriptor: ACEDescriptor) -> String:
	var ids: PackedStringArray = PackedStringArray()
	for parameter: ACEParam in descriptor.params:
		ids.append(str(parameter.id))
	return ",".join(ids)


static func _default_of(descriptor: ACEDescriptor, param_id: String) -> String:
	for parameter: ACEParam in descriptor.params:
		if str(parameter.id) == param_id:
			return str(parameter.default_value)
	return ""


static func _parses(source: String) -> bool:
	var script: GDScript = GDScript.new()
	script.source_code = source
	return script.reload(true) == OK


## An ACEAction on the SHIPPED template, baking {uid} into a per-row token exactly as the dock does
## at apply time. An empty uid leaves the registry template in charge (there is no {uid} to bake).
static func _action(shipped: Dictionary, ace_id: String, params: Dictionary, uid: String) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	action.params = params
	if not uid.is_empty():
		action.codegen_template = str((shipped[ace_id] as ACEDescriptor).codegen_template).replace("{uid}", uid)
	return action


## The condition twin of _action.
static func _condition(shipped: Dictionary, ace_id: String, params: Dictionary, uid: String) -> ACECondition:
	var condition: ACECondition = ACECondition.new()
	condition.provider_id = "Core"
	condition.ace_id = ace_id
	condition.params = params
	if not uid.is_empty():
		condition.codegen_template = str((shipped[ace_id] as ACEDescriptor).codegen_template).replace("{uid}", uid)
	return condition
