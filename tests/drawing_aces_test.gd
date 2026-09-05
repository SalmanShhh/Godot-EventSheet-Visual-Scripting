# Godot EventSheets - the builtin Draw ACE module.
#
# Pins that drawing is now first-class, pickable vocabulary usable on ANY node (not only via the Drawing
# Canvas behavior): the module registers Draw Line/Circle/Ring/... and Canvas Texture, each compiling to a
# CanvasSurface.for_node({node}) call (the shared runtime, not a plugin class). Templates are API once
# shipped, so a couple are pinned verbatim. The suite's builtin-ACE compile test proves they parse.
#
# THE STYLED HALF IS PINNED THE SAME WAY. The rows that take neither a width nor a colour - the four
# that set the canvas's draw style, and the eleven shapes drawn in it - are a shelf, so they are pinned
# as a shelf: every id registers, every template is quoted character for character (a template is API
# the moment it ships), and one compiled sheet holding all fifteen is opened again to prove each row
# reads back as itself and the file re-emits byte for byte.
@tool
class_name DrawingACEsTest
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")

## The style shelf and the shapes drawn in it, each with the text it emits. The table IS the freeze:
## a renamed parameter or a moved argument fails here by name rather than in a game a year from now.
const STYLED_TEMPLATES: Dictionary = {
	"DrawSetStyle": "CanvasSurface.for_node({node}).set_draw_style({style})",
	"DrawPushStyle": "CanvasSurface.for_node({node}).push_draw_style({style})",
	"DrawPopStyle": "CanvasSurface.for_node({node}).pop_draw_style()",
	"DrawResetStyle": "CanvasSurface.for_node({node}).reset_draw_style()",
	"DrawArcShape": "CanvasSurface.for_node({node}).draw_arc_shape({x}, {y}, {radius}, {from_degrees}, {to_degrees})",
	"DrawPie": "CanvasSurface.for_node({node}).draw_pie({x}, {y}, {radius}, {from_degrees}, {to_degrees})",
	"DrawRoundedRect": "CanvasSurface.for_node({node}).draw_rounded_rect({x}, {y}, {width}, {height}, {corner_radius}, {filled})",
	"DrawRegularPolygon": "CanvasSurface.for_node({node}).draw_regular_polygon({x}, {y}, {radius}, {sides}, {angle_degrees}, {filled})",
	"DrawPolygonShape": "CanvasSurface.for_node({node}).draw_polygon_shape({points}, {filled})",
	"DrawPolylineShape": "CanvasSurface.for_node({node}).draw_polyline_shape({points}, {closed})",
	"DrawTextShape": "CanvasSurface.for_node({node}).draw_text({message}, {x}, {y}, {size})",
	"DrawTextureInRect": "CanvasSurface.for_node({node}).draw_texture_in_rect({texture}, {x}, {y}, {width}, {height})",
	"DrawGrid": "CanvasSurface.for_node({node}).draw_grid({x}, {y}, {width}, {height}, {cell_size})",
	"DrawCross": "CanvasSurface.for_node({node}).draw_cross({x}, {y}, {arm_length}, {angle_degrees})",
	"DrawArrow": "CanvasSurface.for_node({node}).draw_arrow({from_x}, {from_y}, {to_x}, {to_y}, {head_size})"
}

## What each styled row is filled with for the compiled sheet below. Every value is one a picker
## would leave behind, so the emitted line is the line a real sheet writes.
const STYLED_PARAMS: Dictionary = {
	"DrawSetStyle": {"node": "self", "style": "null"},
	"DrawPushStyle": {"node": "self", "style": "null"},
	"DrawPopStyle": {"node": "self"},
	"DrawResetStyle": {"node": "self"},
	"DrawArcShape": {"node": "self", "x": "0.0", "y": "0.0", "radius": "48.0", "from_degrees": "0.0", "to_degrees": "90.0"},
	"DrawPie": {"node": "self", "x": "0.0", "y": "0.0", "radius": "48.0", "from_degrees": "0.0", "to_degrees": "90.0"},
	"DrawRoundedRect": {"node": "self", "x": "0.0", "y": "0.0", "width": "64.0", "height": "48.0", "corner_radius": "8.0", "filled": "false"},
	"DrawRegularPolygon": {"node": "self", "x": "0.0", "y": "0.0", "radius": "48.0", "sides": "6", "angle_degrees": "0.0", "filled": "false"},
	"DrawPolygonShape": {"node": "self", "points": "[]", "filled": "true"},
	"DrawPolylineShape": {"node": "self", "points": "[]", "closed": "false"},
	"DrawTextShape": {"node": "self", "message": "\"ready\"", "x": "0.0", "y": "0.0", "size": "16.0"},
	"DrawTextureInRect": {"node": "self", "texture": "null", "x": "0.0", "y": "0.0", "width": "64.0", "height": "64.0"},
	"DrawGrid": {"node": "self", "x": "0.0", "y": "0.0", "width": "256.0", "height": "256.0", "cell_size": "32.0"},
	"DrawCross": {"node": "self", "x": "0.0", "y": "0.0", "arm_length": "12.0", "angle_degrees": "0.0"},
	"DrawArrow": {"node": "self", "from_x": "0.0", "from_y": "0.0", "to_x": "64.0", "to_y": "0.0", "head_size": "12.0"}
}


static func run() -> bool:
	var all_passed: bool = true

	var descs: Array[ACEDescriptor] = EventForgeDrawingACEs.get_descriptors()
	var by_id: Dictionary = {}
	for d: ACEDescriptor in descs:
		by_id[str(d.ace_id)] = d

	all_passed = _check("the drawing module ships a full vocabulary", descs.size() >= 15, true) and all_passed
	all_passed = _check("Draw Circle registers", by_id.has("DrawCircle"), true) and all_passed
	all_passed = _check("Canvas Texture, Start Ribbon, Draw Prefab register",
		by_id.has("DrawCanvasTexture") and by_id.has("DrawStartRibbon") and by_id.has("DrawPrefabAce"), true) and all_passed

	# Frozen templates: each verb draws onto the shared runtime, on the picked node, not a plugin class.
	all_passed = _check("Draw Circle compiles onto CanvasSurface.for_node({node})",
		str((by_id.get("DrawCircle") as ACEDescriptor).codegen_template) if by_id.has("DrawCircle") else "MISSING",
		"CanvasSurface.for_node({node}).circle({x}, {y}, {radius}, {color})") and all_passed
	all_passed = _check("Canvas Texture is an expression on the node's surface",
		str((by_id.get("DrawCanvasTexture") as ACEDescriptor).codegen_template) if by_id.has("DrawCanvasTexture") else "MISSING",
		"CanvasSurface.for_node({node}).texture()") and all_passed

	# Dashed shapes: new ace_ids + frozen templates (additive - the shared dash primitive on the runtime).
	all_passed = _check("dashed verbs register", by_id.has("DrawDashedLine") and by_id.has("DrawDashedRing") and by_id.has("DrawDashedRect"), true) and all_passed
	all_passed = _check("Draw Dashed Line template is frozen", str((by_id.get("DrawDashedLine") as ACEDescriptor).codegen_template) if by_id.has("DrawDashedLine") else "MISSING", "CanvasSurface.for_node({node}).dashed_line({from_x}, {from_y}, {to_x}, {to_y}, {dash_length}, {gap_length}, {width}, {color})") and all_passed
	all_passed = _check("Draw Dashed Rect template is frozen", str((by_id.get("DrawDashedRect") as ACEDescriptor).codegen_template) if by_id.has("DrawDashedRect") else "MISSING", "CanvasSurface.for_node({node}).dashed_rect({x}, {y}, {width}, {height}, {dash_length}, {gap_length}, {line_width}, {color})") and all_passed

	all_passed = _pin_the_styled_shelf(by_id) and all_passed
	all_passed = _pin_the_styled_round_trip(by_id) and all_passed

	# No emitted template names a plugin class (the runtime lives in eventsheet_addons, not the editor).
	var clean: bool = true
	for d: ACEDescriptor in descs:
		if str(d.codegen_template).contains("EventForge") or str(d.codegen_template).contains("EventSheet"):
			clean = false
	all_passed = _check("no Draw ACE references an editor plugin class", clean, true) and all_passed

	return all_passed


## Every styled row registers, and emits the text the table above quotes. Sorted, so the walk reads
## the same on every machine and a missing id is named rather than counted.
static func _pin_the_styled_shelf(by_id: Dictionary) -> bool:
	var ids: Array = STYLED_TEMPLATES.keys()
	ids.sort()
	var rows: Array = []
	for ace_id: String in ids:
		rows.append(["%s registers" % ace_id, by_id.has(ace_id), true])
		rows.append(["%s emits its frozen template" % ace_id,
			str((by_id[ace_id] as ACEDescriptor).codegen_template) if by_id.has(ace_id) else "MISSING",
			str(STYLED_TEMPLATES[ace_id])])
	return SUPPORT.pins("drawing_aces_test", rows)


## One sheet holding all fifteen styled rows: it compiles to plain calls on the shared runtime, and
## opening that file again reads every row back as the row that wrote it, byte for byte.
##
## The byte pin is the load-bearing half. A lift that claims a line it cannot reproduce is the one
## way this vocabulary could corrupt somebody's file, so the proof is the file itself rather than a
## count of what was claimed.
static func _pin_the_styled_round_trip(by_id: Dictionary) -> bool:
	var ids: Array = STYLED_TEMPLATES.keys()
	ids.sort()
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	var row: EventRow = EventRow.new()
	row.trigger_provider_id = "Core"
	row.trigger_id = "OnProcess"
	for ace_id: String in ids:
		if not by_id.has(ace_id):
			return SUPPORT.check("drawing_aces_test", "every styled row is registered before the round trip", ace_id, "registered")
		var action: ACEAction = ACEAction.new()
		action.provider_id = "Core"
		action.ace_id = ace_id
		action.params = STYLED_PARAMS[ace_id]
		row.actions.append(action)
	sheet.events.append(row)
	var output: String = SUPPORT.compile_output(sheet, "user://drawing_aces_styled.gd")
	var lifted: Array[String] = []
	for item: Variant in SUPPORT.reopen(output).events:
		if not (item is EventRow):
			continue
		for entry: Variant in (item as EventRow).actions:
			if entry is ACEAction:
				lifted.append(str((entry as ACEAction).ace_id))
	var rows: Array = [
		["every styled row draws on the shared runtime", output.count("CanvasSurface.for_node(self)."), ids.size()],
		["no {uid} token survives into the emitted script", output.contains("{uid}"), false],
	]
	for ace_id: String in ids:
		rows.append(["a hand-written %s reads back as itself" % ace_id, lifted.has(ace_id), true])
	rows.append(["the reopened styled sheet re-emits byte for byte",
		SUPPORT.reemit(output, "user://drawing_aces_styled_roundtrip.gd") == output, true])
	var passed: bool = SUPPORT.pins("drawing_aces_test", rows)
	_cleanup()
	return passed


## The scripts the compile and the round trip wrote. On CI the whole suite runs serially in one
## process, so what one test leaves in the user folder is state the next one sees.
static func _cleanup() -> void:
	for written: String in ["user://drawing_aces_styled.gd", "user://drawing_aces_styled_roundtrip.gd"]:
		if FileAccess.file_exists(written):
			DirAccess.remove_absolute(written)


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("drawing_aces_test", label, actual, expected)
