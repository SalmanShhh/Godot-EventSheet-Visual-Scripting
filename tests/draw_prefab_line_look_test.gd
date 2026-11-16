# Godot EventSheets - Draw Prefab draws a line with the look its step carries.
#
# A line step may carry its ends (caps), a dash pattern and the rule for whether its thickness
# follows the prefab's scale. The stamp node and the Inspector picture always drew them; Draw Prefab
# on a Drawing Canvas drew every line plain, at a width that always followed the scale. These pins
# read the commands a canvas queues - a canvas with no host and outside the tree keeps them in a
# list, which is exactly what it draws from - so no frame has to be rendered to ask.
#
# A step that carries none of the look keys still queues the plain line command it always queued,
# so a prefab saved before the keys existed draws the same pixels in every game that uses it.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const TEST_NAME := "draw_prefab_line_look_test"


static func run() -> bool:
	var ok: bool = true
	ok = _plain_pins() and ok
	ok = _look_pins() and ok
	ok = _scale_rule_pins() and ok
	ok = _stroke_home_pins() and ok
	return ok


static func _prefab(steps: Array) -> DrawingPrefabResource:
	var prefab: DrawingPrefabResource = DrawingPrefabResource.new()
	prefab.steps = steps
	return prefab


static func _commands(steps: Array, scale_by: float) -> Array:
	var surface: CanvasSurface = CanvasSurface.new()
	surface.prefab(_prefab(steps), 0.0, 0.0, scale_by, 0.0)
	var queued: Array = surface._commands.duplicate(true)
	surface.free()
	return queued


static func _line(extra: Dictionary) -> Dictionary:
	var step: Dictionary = {"kind": "line", "x": -60.0, "y": 0.0, "p1": 60.0, "p2": 0.0, "p3": 4.0, "color": "#ffffff", "texture": ""}
	step.merge(extra, true)
	return step


static func _plain_pins() -> bool:
	var queued: Array = _commands([_line({})], 1.0)
	var first: Dictionary = queued[0] if not queued.is_empty() else {}
	return SUPPORT.pins(TEST_NAME, [
		["a plain line queues one command", queued.size(), 1],
		["the plain line command it always queued", str(first.get("kind", "")), "line"],
		["from its offset", first.get("a"), Vector2(-60.0, 0.0)],
		["to its End", first.get("b"), Vector2(60.0, 0.0)],
		["and carries only what it always carried, so it draws the same pixels",
			first.keys(), ["kind", "a", "b", "width", "color"]],
	])


static func _look_pins() -> bool:
	var dressed: Dictionary = _line({"caps": "round", "dashed": true, "dash_size": 5.0, "dash_spacing": 3.0, "dash_offset": 0.25, "dash_style": "angled"})
	var queued: Array = _commands([dressed], 2.0)
	var first: Dictionary = queued[0] if not queued.is_empty() else {}
	var look: Dictionary = first.get("look", {}) if first.get("look") is Dictionary else {}
	return SUPPORT.pins(TEST_NAME, [
		["a line with a look queues the look with it", str(first.get("kind", "")), "prefab_line"],
		["its ends", str(look.get("caps", "")), "round"],
		["its dashes", bool(look.get("dashed", false)), true],
		["a dash grows with the prefab, as it does on the stamp node", float(look.get("dash_size", 0.0)), 10.0],
		["and so does the gap", float(look.get("dash_spacing", 0.0)), 6.0],
		["the offset is a share of one dash and gap, so it does not scale", float(look.get("dash_offset", 0.0)), 0.25],
		["the dash style", str(look.get("dash_style", "")), "angled"],
	])


## "fixed" keeps a line as thick as it says however the prefab is scaled; "uniform" (and a step that
## says nothing) lets it grow with the prefab, which is what Draw Prefab has always done.
static func _scale_rule_pins() -> bool:
	var uniform: Array = _commands([_line({})], 3.0)
	var fixed: Array = _commands([_line({"scale_mode": "fixed"})], 3.0)
	return SUPPORT.pins(TEST_NAME, [
		["a line that says nothing grows with the prefab", float((uniform[0] as Dictionary).get("width", 0.0)), 12.0],
		["a fixed line keeps its own thickness", float((fixed[0] as Dictionary).get("width", 0.0)), 4.0],
	])


## The stroke code lives on the resource, so the canvas never has to name the stamp node (a project can
## have the canvas without the stamp pack); the stamp node's three names still answer and delegate.
static func _stroke_home_pins() -> bool:
	var resource_methods: PackedStringArray = PackedStringArray()
	for method: Dictionary in (load("res://eventsheet_addons/drawing_prefab_resource/drawing_prefab_resource.gd") as GDScript).get_script_method_list():
		resource_methods.append(str(method.get("name", "")))
	var stamp_methods: PackedStringArray = PackedStringArray()
	for method: Dictionary in (load("res://eventsheet_addons/drawing_prefab_stamp/drawing_prefab_stamp.gd") as GDScript).get_script_method_list():
		stamp_methods.append(str(method.get("name", "")))
	var canvas_source: String = FileAccess.get_file_as_string("res://eventsheet_addons/canvas_surface/canvas_surface.gd")
	var rows: Array = [["the canvas never names the stamp node", canvas_source.contains("DrawingPrefabStamp"), false]]
	for name: String in ["draw_stroke", "draw_capped", "draw_leaning_dash"]:
		rows.append(["the resource holds " + name, resource_methods.has(name), true])
		rows.append(["the stamp node still answers to " + name, stamp_methods.has(name), true])
	return SUPPORT.pins(TEST_NAME, rows)
