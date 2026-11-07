@tool
class_name CanvasItemDrawTest
extends RefCounted

# Godot's own drawing calls as actions under On Draw: the rows write the call Godot documents with
# Godot's argument names, a hand-written call with fewer arguments opens as the same row and saves
# back to the same bytes, the draw_* rows are offered only under an On Draw event, and Redraw (which
# works anywhere) is always offered.

const SUPPORT := preload("res://tests/support.gd")
const NAME := "canvas_item_draw_test"

## A script whose _draw holds one of each shape of call, from the fewest arguments to the most, with
## commas inside brackets and strings (one argument each), and whose _process asks for the next draw.
const SOURCE := """extends Panel


func _draw() -> void:
	draw_line(Vector2(0, 0), Vector2(64, 0), Color.RED)
	draw_line(a + b, c, Color.GREEN, 2.0, use_antialiasing)
	draw_rect(Rect2(margin + offset, Vector2(100, 50)), Color.PURPLE)
	draw_rect(Rect2(margin + offset, Vector2(100, 50)), Color.PURPLE, false, 2.0)
	draw_rect(Rect2(margin + offset, Vector2(100, 50)), Color.PURPLE, true, -1.0, use_antialiasing)
	draw_rect(Rect2(1, 2, 3, 4), Color.PURPLE, flag)
	draw_circle(Vector2(1, 2), 5, Color("ff0000"))
	draw_circle(Vector2(1, 2), 5, Color.ORANGE, false, 2.0, use_antialiasing)
	draw_arc(center, 60, 0, 0.25 * TAU, 32, Color.YELLOW, 2.0, use_antialiasing)
	draw_polyline(points, Color.SKY_BLUE, 2.0)
	draw_polygon(points, PackedColorArray([Color.RED, Color.BLUE]))
	draw_string(font, margin, \"a, b\", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color.YELLOW)
	draw_string(font, margin, \"a, b\")
	draw_texture(tex, Vector2(3, 4))
	draw_texture_rect(tex, Rect2(0, 0, 8, 8), false)
	draw_texture_rect_region(tex, Rect2(0, 0, 8, 8), Rect2(1, 1, 4, 4))
	draw_set_transform(margin + offset, deg_to_rad(22.5))
	draw_set_transform(Vector2())


func _process(_delta: float) -> void:
	queue_redraw()
	tab.queue_redraw()
	draw_line(a, b, Color.RED)
"""


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _the_rows_write_godots_calls() and all_passed
	all_passed = _a_hand_written_call_opens_as_the_same_row() and all_passed
	all_passed = _the_draw_calls_are_offered_only_under_on_draw() and all_passed
	all_passed = _a_later_optional_fills_the_blanks_before_it() and all_passed
	return all_passed


static func _descriptor(ace_id: String) -> ACEDescriptor:
	return ACERegistry.find_descriptor("Core", ace_id)


static func _param_ids(descriptor: ACEDescriptor) -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray()
	for param: ACEParam in descriptor.params:
		ids.append(param.id)
	return ids


## The ids, templates and parameter names are API the moment they ship; this is the table that says so.
static func _the_rows_write_godots_calls() -> bool:
	var rows: Array = []
	var shipped: Dictionary = {
		"CanvasItemDrawLine": "draw_line({from}, {to}, {color}{, width}{, antialiased})",
		"CanvasItemDrawRect": "draw_rect({rect}, {color}{, filled}{, width}{, antialiased})",
		"CanvasItemDrawRectOutline": "draw_rect({rect}, {color}, false{, width}{, antialiased})",
		"CanvasItemDrawCircle": "draw_circle({position}, {radius}, {color}{, filled}{, width}{, antialiased})",
		"CanvasItemDrawCircleOutline": "draw_circle({position}, {radius}, {color}, false{, width}{, antialiased})",
		"CanvasItemDrawArc": "draw_arc({center}, {radius}, {start_angle}, {end_angle}, {point_count}, {color}{, width}{, antialiased})",
		"CanvasItemDrawPolyline": "draw_polyline({points}, {color}{, width}{, antialiased})",
		"CanvasItemDrawPolygon": "draw_polygon({points}, {colors}{, uvs}{, texture})",
		"CanvasItemDrawString": "draw_string({font}, {pos}, {text}{, alignment}{, width}{, font_size}{, modulate})",
		"CanvasItemDrawTexture": "draw_texture({texture}, {position}{, modulate})",
		"CanvasItemDrawTextureRect": "draw_texture_rect({texture}, {rect}, {tile}{, modulate}{, transpose})",
		"CanvasItemDrawTextureRectRegion": "draw_texture_rect_region({texture}, {rect}, {src_rect}{, modulate}{, transpose}{, clip_uv})",
		"CanvasItemDrawSetTransform": "draw_set_transform({position}{, rotation}{, scale})",
	}
	for ace_id: String in shipped:
		var descriptor: ACEDescriptor = _descriptor(ace_id)
		rows.append(["%s template" % ace_id, descriptor.codegen_template if descriptor != null else "(missing)", shipped[ace_id]])
		rows.append(["%s is an action on a CanvasItem" % ace_id,
			[descriptor.ace_type == ACEDescriptor.ACEType.ACTION, descriptor.node_type] if descriptor != null else [],
			[true, "CanvasItem"]])
		rows.append(["%s draws on the node itself, with no On node field" % ace_id,
			_param_ids(descriptor).has("target") if descriptor != null else true, false])
	var redraw: ACEDescriptor = _descriptor("CanvasItemQueueRedraw")
	rows.append(["Redraw template", redraw.codegen_template if redraw != null else "(missing)", "{target.}queue_redraw()"])
	rows.append(["Redraw can be pointed at another node", _param_ids(redraw) if redraw != null else [], PackedStringArray(["target"])])
	rows.append(["the line's argument names are Godot's", _param_ids(_descriptor("CanvasItemDrawLine")),
		PackedStringArray(["from", "to", "color", "width", "antialiased"])])
	rows.append(["the text row keeps draw_string's argument names", _param_ids(_descriptor("CanvasItemDrawString")),
		PackedStringArray(["font", "pos", "text", "alignment", "width", "font_size", "modulate"])])
	rows.append(["the older canvas rows are untouched",
		_descriptor("DrawRect").codegen_template,
		"CanvasSurface.for_node({node}).rect({x}, {y}, {width}, {height}, {color})"])
	return SUPPORT.pins(NAME + ": rows", rows)


## The lifted action's id and parameters for each line of SOURCE's _draw, and the whole file's round trip.
static func _a_hand_written_call_opens_as_the_same_row() -> bool:
	var sheet: EventSheetResource = SUPPORT.reopen(SOURCE, true, "")
	var drawing: EventRow = _event_with_trigger(sheet, "OnDraw")
	var seen: Array = []
	if drawing != null:
		for action: Resource in drawing.actions:
			seen.append([str(action.get("ace_id")), _params_of(action)])
	var rows: Array = [
		["the draw event is found", drawing != null, true],
		["every call of _draw is a row", seen.size(), 18],
	]
	if seen.size() == 18:
		var expected: Array = [
			["CanvasItemDrawLine", {"from": "Vector2(0, 0)", "to": "Vector2(64, 0)", "color": "Color.RED"}],
			["CanvasItemDrawLine", {"from": "a + b", "to": "c", "color": "Color.GREEN", "width": "2.0", "antialiased": "use_antialiasing"}],
			["CanvasItemDrawRect", {"rect": "Rect2(margin + offset, Vector2(100, 50))", "color": "Color.PURPLE"}],
			["CanvasItemDrawRectOutline", {"rect": "Rect2(margin + offset, Vector2(100, 50))", "color": "Color.PURPLE", "width": "2.0"}],
			["CanvasItemDrawRect", {"rect": "Rect2(margin + offset, Vector2(100, 50))", "color": "Color.PURPLE", "filled": "true", "width": "-1.0", "antialiased": "use_antialiasing"}],
			["CallFunction", {"function_name": "draw_rect", "args": "Rect2(1, 2, 3, 4), Color.PURPLE, flag"}],
			["CanvasItemDrawCircle", {"position": "Vector2(1, 2)", "radius": "5", "color": "Color(\"ff0000\")"}],
			["CanvasItemDrawCircleOutline", {"position": "Vector2(1, 2)", "radius": "5", "color": "Color.ORANGE", "width": "2.0", "antialiased": "use_antialiasing"}],
			["CanvasItemDrawArc", {"center": "center", "radius": "60", "start_angle": "0", "end_angle": "0.25 * TAU", "point_count": "32", "color": "Color.YELLOW", "width": "2.0", "antialiased": "use_antialiasing"}],
			["CanvasItemDrawPolyline", {"points": "points", "color": "Color.SKY_BLUE", "width": "2.0"}],
			["CanvasItemDrawPolygon", {"points": "points", "colors": "PackedColorArray([Color.RED, Color.BLUE])"}],
			["CanvasItemDrawString", {"font": "font", "pos": "margin", "text": "\"a, b\"", "alignment": "HORIZONTAL_ALIGNMENT_LEFT", "width": "-1", "font_size": "FONT_SIZE", "modulate": "Color.YELLOW"}],
			["CanvasItemDrawString", {"font": "font", "pos": "margin", "text": "\"a, b\""}],
			["CanvasItemDrawTexture", {"texture": "tex", "position": "Vector2(3, 4)"}],
			["CanvasItemDrawTextureRect", {"texture": "tex", "rect": "Rect2(0, 0, 8, 8)", "tile": "false"}],
			["CanvasItemDrawTextureRectRegion", {"texture": "tex", "rect": "Rect2(0, 0, 8, 8)", "src_rect": "Rect2(1, 1, 4, 4)"}],
			["CanvasItemDrawSetTransform", {"position": "margin + offset", "rotation": "deg_to_rad(22.5)"}],
			["CanvasItemDrawSetTransform", {"position": "Vector2()"}],
		]
		for index: int in range(expected.size()):
			rows.append(["line %d of _draw reads as %s" % [index + 1, expected[index][0]], seen[index], expected[index]])
	var process: EventRow = _event_with_trigger(sheet, "OnProcess")
	var redraws: Array = []
	if process != null:
		for action: Resource in process.actions:
			redraws.append([str(action.get("ace_id")), _params_of(action)])
	rows.append(["Redraw, bare and on another node, outside _draw", redraws.slice(0, 2),
		[["CanvasItemQueueRedraw", {}], ["CanvasItemQueueRedraw", {"target": "tab"}]]])
	rows.append(["a draw call outside _draw is still just that row (the picker refuses it, the file keeps it)",
		str(process.actions[2].get("ace_id")) if process != null and process.actions.size() > 2 else "", "CanvasItemDrawLine"])
	rows.append(["the file saves back to the same bytes",
		SUPPORT.reemit(SOURCE, "user://canvas_item_draw_probe.gd") == SOURCE, true])
	return SUPPORT.pins(NAME + ": lift", rows)


static func _event_with_trigger(sheet: EventSheetResource, trigger_id: String) -> EventRow:
	if sheet == null:
		return null
	for entry: Variant in sheet.events:
		if entry is EventRow and (entry as EventRow).trigger_id == trigger_id:
			return entry as EventRow
	return null


static func _params_of(action: Resource) -> Dictionary:
	var params: Dictionary = action.get("params")
	return params if not params.is_empty() else action.get("parameters")


static func _marked(ace_id: String) -> ACEDefinition:
	var definition: ACEDefinition = ACEDefinition.new()
	definition.provider_id = "Core"
	definition.id = ace_id
	return definition


## The draw calls are hidden where Godot refuses them and offered under On Draw; Redraw and every
## other row are never asked where they are going.
static func _the_draw_calls_are_offered_only_under_on_draw() -> bool:
	var sheet: EventSheetResource = SUPPORT.reopen(SOURCE, true, "")
	var drawing: EventRow = _event_with_trigger(sheet, "OnDraw")
	var process: EventRow = _event_with_trigger(sheet, "OnProcess")
	var inside: Dictionary = {EventSheetPickerGates.IN_DRAW_CONTEXT: true}
	var outside: Dictionary = {EventSheetPickerGates.IN_DRAW_CONTEXT: false}
	var line: ACEDefinition = _marked("CanvasItemDrawLine")
	var redraw: ACEDefinition = _marked("CanvasItemQueueRedraw")
	var other: ACEDefinition = _marked("SetVar")
	var classes: GDScript = load("res://addons/eventsheet/editor/dock/class_kinds.gd")
	var rows: Array = [
		["a draw call outside On Draw is hidden, under it and unasked is not",
			[EventSheetPickerGates.hidden_reason(line, outside), EventSheetPickerGates.hidden_reason(line, inside), EventSheetPickerGates.hidden_reason(line)],
			[EventSheetPickerGates.HIDDEN_OUTSIDE_DRAW, "", ""]],
		["Redraw works anywhere", EventSheetPickerGates.hidden_reason(redraw, outside), ""],
		["no other row is asked", EventSheetPickerGates.hidden_reason(other, outside), ""],
		["a row under On Draw is inside it", classes.draw_offered(sheet, drawing.actions[0]), true],
		["the On Draw event itself is inside it", classes.draw_offered(sheet, drawing), true],
		["a row under Every Frame is not", classes.draw_offered(sheet, process.actions[0]), false],
		["nothing selected is not", classes.draw_offered(sheet, null), false],
	]
	var registry: EventSheetACERegistry = EventSheetACERegistry.new()
	registry.refresh_from_sources([], true)
	var listed: Array = []
	for definition: ACEDefinition in registry.get_all_definitions():
		if EventSheetPickerGates.is_draw_call(definition):
			listed.append(definition.id)
	rows.append(["thirteen draw calls are marked, Redraw is not", [listed.size(), listed.has("CanvasItemQueueRedraw")], [13, false]])
	return SUPPORT.pins(NAME + ": picker", rows)


## The window writes a valid call: giving a later optional argument fills the blank ones before it
## with the values Godot's own call would have taken, and a short call still writes the short call.
static func _a_later_optional_fills_the_blanks_before_it() -> bool:
	var registry: EventSheetACERegistry = EventSheetACERegistry.new()
	registry.refresh_from_sources([], true)
	var line: ACEDefinition = null
	var rect: ACEDefinition = null
	for definition: ACEDefinition in registry.get_all_definitions():
		if definition.id == "CanvasItemDrawLine":
			line = definition
		elif definition.id == "CanvasItemDrawRect":
			rect = definition
	if line == null or rect == null:
		return SUPPORT.check(NAME, "the draw rows are registered", false, true)
	var base: Dictionary = {"from": "a", "to": "b", "color": "c", "width": "", "antialiased": ""}
	var rect_base: Dictionary = {"rect": "r", "color": "c", "filled": "", "width": "", "antialiased": ""}
	var rows: Array = [
		["a short call stays short", ACEParamsDialog.row_code_line(line, base), "draw_line(a, b, c)"],
		["a width alone stays without a gap", ACEParamsDialog.row_code_line(line, base.merged({"width": "2.0"}, true)), "draw_line(a, b, c, 2.0)"],
		["antialiased alone fills the width before it", ACEParamsDialog.row_code_line(line, base.merged({"antialiased": "true"}, true)), "draw_line(a, b, c, -1.0, true)"],
		["the last of three fills the two before it", ACEParamsDialog.row_code_line(rect, rect_base.merged({"antialiased": "true"}, true)), "draw_rect(r, c, true, -1.0, true)"],
		["a width alone fills only filled", ACEParamsDialog.row_code_line(rect, rect_base.merged({"width": "2.0"}, true)), "draw_rect(r, c, true, 2.0)"],
		["the values handed back hold the filled defaults", ACEParamsDialog.with_chain_defaults(line, base.merged({"antialiased": "true"}, true)).get("width"), "-1.0"],
		["a value the author gave is never replaced", ACEParamsDialog.row_code_line(line, base.merged({"width": "3.0", "antialiased": "true"}, true)), "draw_line(a, b, c, 3.0, true)"],
	]
	return SUPPORT.pins(NAME + ": chain defaults", rows)
