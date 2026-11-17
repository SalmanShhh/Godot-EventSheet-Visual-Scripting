# Godot EventSheets - a Drawing Prefab holds arcs, pies, rounded rectangles and regular polygons.
#
# The four are new values of `kind`; every key keeps its meaning. An arc and a pie are a radius and two
# angles (p1, p2, p3), so switching one to the other keeps the picture; an arc's thickness is the
# optional `thickness` key, absent on every step saved before it existed. A rounded rectangle is placed
# from its corner like the Rectangle, a regular polygon is a radius, a number of sides and an angle.
# The card list, the stamp node, Draw Prefab and the Inspector picture all know the four words; what is
# pinned here is the data, the commands Draw Prefab queues (a canvas with no host keeps them in a list),
# the picture's pixels and that the picture and the pack's outline agree about what is inside a shape.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const TEST_NAME := "drawing_prefab_more_shapes_test"
const STEPS := "res://addons/eventsheet/editor/inspector/drawing_prefab_steps_property.gd"
const PICTURE := "res://addons/eventsheet/editor/inspector/drawing_prefab_preview.gd"
const TILE := "res://addons/eventsheet/editor/inspector/drawing_prefab_shape_tile.gd"
const RESOURCE := "res://eventsheet_addons/drawing_prefab_resource/drawing_prefab_resource.gd"
const SURFACE := "res://eventsheet_addons/canvas_surface/canvas_surface.gd"
const NEW_KINDS: Array[String] = ["arc", "pie", "rounded_rect", "regular_polygon"]


static func run() -> bool:
	var ok: bool = true
	ok = _card_pins() and ok
	ok = _stored_pins() and ok
	ok = _draw_prefab_pins() and ok
	ok = _picture_pins() and ok
	ok = _agreement_pins() and ok
	return ok


static func _editor() -> GDScript:
	return (load(STEPS) as GDScript).get_script_constant_map().get("ShapeStepsEditor") as GDScript


static func _step(kind: String, p1: float, p2: float, p3: float, extra: Dictionary = {}) -> Dictionary:
	var step: Dictionary = {"kind": kind, "x": 0.0, "y": 0.0, "p1": p1, "p2": p2, "p3": p3, "color": "#ffffff", "texture": ""}
	step.merge(extra, true)
	return step


static func _outline(step: Dictionary) -> PackedVector2Array:
	return (load(RESOURCE) as GDScript).call("shape_outline", step)


static func _card_pins() -> bool:
	var editor: GDScript = _editor()
	var kinds: Array = editor.get_script_constant_map().get("KINDS", [])
	var rows: Array = []
	for kind: String in NEW_KINDS:
		rows.append(["the list offers %s" % kind, kinds.has(kind), true])
		var fresh: Dictionary = editor.call("defaults_for", kind)
		rows.append(["a new %s draws something" % kind, editor.call("finding_of", fresh.merged({"kind": kind})), ""])
		rows.append(["a new %s has fields" % kind, (editor.call("fields_for", kind) as Array).size() > 5, true])
	var names: Dictionary = {"arc": "Arc", "pie": "Pie", "rounded_rect": "Rounded rectangle", "regular_polygon": "Polygon"}
	for kind: String in names:
		rows.append(["%s is called %s" % [kind, names[kind]], editor.call("kind_label", kind), names[kind]])
	rows.append_array([
		["the six old kinds keep their places", kinds.slice(0, 6), ["circle", "ring", "rect", "line", "cone", "stamp"]],
		["ten shapes in all", kinds.size(), 10],
		["a new arc", editor.call("defaults_for", "arc"), {"x": 0.0, "y": 0.0, "p1": 16.0, "p2": -90.0, "p3": 180.0, "color": "#ffffff", "texture": "", "thickness": 3.0, "scale_mode": "uniform"}],
		["a new regular polygon", editor.call("defaults_for", "regular_polygon"), {"x": 0.0, "y": 0.0, "p1": 16.0, "p2": 6.0, "p3": -90.0, "color": "#ffffff", "texture": ""}],
		["a new circle is as it was", editor.call("defaults_for", "circle"), {"x": 0.0, "y": 0.0, "p1": 12.0, "p2": 0.0, "p3": 0.0, "color": "#ffffff", "texture": ""}],
		["an arc's summary", editor.call("summary_of", _step("arc", 16.0, -90.0, 180.0)), "radius 16, 270°"],
		["a pie's summary", editor.call("summary_of", _step("pie", 16.0, -90.0, 90.0)), "radius 16, 180°"],
		["a rounded rectangle's summary", editor.call("summary_of", _step("rounded_rect", 32.0, 20.0, 6.0)), "32 x 20"],
		["a regular polygon's summary", editor.call("summary_of", _step("regular_polygon", 16.0, 6.0, -90.0)), "6 sides, radius 16"],
		["an arc with no radius", editor.call("finding_of", _step("arc", 0.0, 0.0, 90.0)), "Radius is 0, so this arc draws nothing."],
		["a pie with no radius", editor.call("finding_of", _step("pie", 0.0, 0.0, 90.0)), "Radius is 0, so this pie draws nothing."],
		["an arc that opens nowhere", editor.call("finding_of", _step("arc", 16.0, 30.0, 30.0)), "The start and the end are the same angle, so this arc draws nothing."],
		["a pie that opens nowhere", editor.call("finding_of", _step("pie", 16.0, 30.0, 30.0)), "The start and the end are the same angle, so this pie draws nothing."],
		["a rounded rectangle with no width", editor.call("finding_of", _step("rounded_rect", 0.0, 20.0, 6.0)), "Width is 0, so this rounded rectangle draws nothing."],
		["a rounded rectangle with no height", editor.call("finding_of", _step("rounded_rect", 20.0, 0.0, 6.0)), "Height is 0, so this rounded rectangle draws nothing."],
		["corners larger than half the short side are said", editor.call("finding_of", _step("rounded_rect", 32.0, 20.0, 12.0)), "The corners are larger than half the shorter side, so they are drawn at half of it."],
		["a polygon with no radius", editor.call("finding_of", _step("regular_polygon", 0.0, 6.0, 0.0)), "Radius is 0, so this polygon draws nothing."],
		["a polygon with two sides", editor.call("finding_of", _step("regular_polygon", 16.0, 2.0, 0.0)), "A polygon needs at least 3 sides, so this one is drawn with 3."],
		["a polygon with fifty sides", editor.call("finding_of", _step("regular_polygon", 16.0, 50.0, 0.0)), "A polygon is drawn with 32 sides at most, so this one is drawn with 32."],
		["an unknown word is still kept and said", editor.call("has_finding", _step("blob", 1.0, 1.0, 1.0)), true],
	])
	var scale_row: bool = false
	for field: Variant in editor.call("fields_for", "arc"):
		if str((field as Dictionary).get("key", "")) == "scale_mode":
			scale_row = true
	rows.append(["an arc has the scale rule a line has", scale_row, true])
	rows.append(["a pie has no scale rule", (editor.call("fields_for", "pie") as Array).any(func(field: Dictionary) -> bool: return str(field.get("key", "")) == "scale_mode"), false])
	return SUPPORT.pins(TEST_NAME, rows)


static func _stored_pins() -> bool:
	var source: String = FileAccess.get_file_as_string(RESOURCE)
	var resource: GDScript = load(RESOURCE) as GDScript
	var dressed: Array = resource.call("compile_steps", [_step("arc", 16.0, -90.0, 180.0, {"thickness": 5.0}), _step("arc", 16.0, -90.0, 180.0)])
	return SUPPORT.pins(TEST_NAME, [
		["the table offers the four words after the six", source.contains("kind=enum(circle|ring|rect|line|cone|stamp|arc|pie|rounded_rect|regular_polygon)"), true],
		["an arc's thickness is carried", float((dressed[0] as Dictionary).get("thickness", -1.0)), 5.0],
		["an arc saved without one draws 2 px", float((dressed[1] as Dictionary).get("thickness", -1.0)), 2.0],
		["a hexagon has six corners at its radius", _corner_reach(_outline(_step("regular_polygon", 16.0, 6.0, -90.0))), [6, 16.0]],
		["a hexagon's first corner points up", _outline(_step("regular_polygon", 16.0, 6.0, -90.0))[0].snapped(Vector2(0.01, 0.01)), Vector2(0.0, -16.0)],
		["sides are held to 3", (_outline(_step("regular_polygon", 16.0, 1.0, 0.0)) as PackedVector2Array).size(), 3],
		["and to 32", (_outline(_step("regular_polygon", 16.0, 99.0, 0.0)) as PackedVector2Array).size(), 32],
		["a polygon with no radius is nothing", (_outline(_step("regular_polygon", 0.0, 6.0, 0.0)) as PackedVector2Array).size(), 0],
		["an arc with no sweep is nothing", (_outline(_step("arc", 16.0, 30.0, 30.0)) as PackedVector2Array).size(), 0],
		["an arc runs from its start to its end", _ends(_outline(_step("arc", 16.0, 0.0, 90.0))), [Vector2(16.0, 0.0), Vector2(0.0, 16.0)]],
		["an end below the start sweeps back", _ends(_outline(_step("arc", 16.0, 0.0, -90.0))), [Vector2(16.0, 0.0), Vector2(0.0, -16.0)]],
		["a pie starts at its centre", (_outline(_step("pie", 16.0, 0.0, 90.0)) as PackedVector2Array)[0], Vector2.ZERO],
		["a rounded rectangle is placed right and down from its offset", _low(_outline(_step("rounded_rect", 32.0, 20.0, 6.0, {"x": 10.0, "y": 5.0}))), Vector2(10.0, 5.0)],
		["a rounded rectangle with a corner of 0 is four points", (_outline(_step("rounded_rect", 32.0, 20.0, 0.0)) as PackedVector2Array).size(), 4],
		["a corner is held to half the short side", _low(_outline(_step("rounded_rect", 32.0, 20.0, 99.0))), Vector2.ZERO],
	])


static func _ends(points: PackedVector2Array) -> Array:
	if points.is_empty():
		return []
	return [points[0].snapped(Vector2(0.01, 0.01)), points[points.size() - 1].snapped(Vector2(0.01, 0.01))]


static func _low(points: PackedVector2Array) -> Variant:
	var low: Vector2 = Vector2.INF
	for point: Vector2 in points:
		low = low.min(point)
	return low.snapped(Vector2(0.01, 0.01))


static func _corner_reach(points: PackedVector2Array) -> Array:
	var reach: float = 0.0
	for point: Vector2 in points:
		reach = maxf(reach, snappedf(point.length(), 0.001))
	return [points.size(), reach]


static func _commands(step: Dictionary, scale_by: float) -> Array:
	var prefab: Resource = (load(RESOURCE) as GDScript).new()
	prefab.set("steps", [step])
	var surface: Object = (load(SURFACE) as GDScript).new()
	surface.call("prefab", prefab, 0.0, 0.0, scale_by, 0.0)
	var queued: Array = (surface.get("_commands") as Array).duplicate(true)
	surface.free()
	return queued


static func _draw_prefab_pins() -> bool:
	var rows: Array = []
	var expected: Dictionary = {"arc": "polyline", "pie": "polygon", "rounded_rect": "polygon", "regular_polygon": "polygon"}
	var steps: Dictionary = {
		"arc": _step("arc", 16.0, -90.0, 180.0, {"thickness": 3.0}),
		"pie": _step("pie", 16.0, -90.0, 90.0),
		"rounded_rect": _step("rounded_rect", 32.0, 20.0, 6.0),
		"regular_polygon": _step("regular_polygon", 16.0, 6.0, -90.0),
	}
	for kind: String in NEW_KINDS:
		var queued: Array = _commands(steps[kind], 2.0)
		var first: Dictionary = queued[0] if not queued.is_empty() else {}
		rows.append(["Draw Prefab draws a %s" % kind, str(first.get("kind", "")), expected[kind]])
	var arc: Array = _commands(steps["arc"], 2.0)
	var fixed: Array = _commands(_step("arc", 16.0, -90.0, 180.0, {"thickness": 3.0, "scale_mode": "fixed"}), 2.0)
	var plain: Array = _commands(_step("arc", 16.0, -90.0, 180.0), 1.0)
	var corner: Array = _commands(steps["rounded_rect"], 1.0)
	rows.append_array([
		["an arc's stroke grows with the prefab", float((arc[0] as Dictionary).get("width", 0.0)) if not arc.is_empty() else 0.0, 6.0],
		["unless it holds its width", float((fixed[0] as Dictionary).get("width", 0.0)) if not fixed.is_empty() else 0.0, 3.0],
		["an arc saved with no thickness is 2 px", float((plain[0] as Dictionary).get("width", 0.0)) if not plain.is_empty() else 0.0, 2.0],
		["a rounded rectangle sits right and down from its offset", _min_corner(corner), Vector2.ZERO],
		["a shape that draws nothing queues nothing", _commands(_step("pie", 0.0, 0.0, 90.0), 1.0).size(), 0],
		["a word no pack knows draws nothing and says nothing", _commands(_step("no_such_shape", 4.0, 4.0, 4.0), 1.0).size(), 0],
	])
	return SUPPORT.pins(TEST_NAME, rows)


static func _min_corner(queued: Array) -> Vector2:
	if queued.is_empty():
		return Vector2.INF
	var low: Vector2 = Vector2.INF
	for point: Vector2 in ((queued[0] as Dictionary).get("points", PackedVector2Array()) as PackedVector2Array):
		low = low.min(point)
	return low.snapped(Vector2(0.01, 0.01))


static func _picture_pins() -> bool:
	var picture: GDScript = load(PICTURE) as GDScript
	var tile: GDScript = load(TILE) as GDScript
	var ground: Color = Color(0.11, 0.12, 0.15)
	var rows: Array = []
	var unknown: Image = tile.call("shape_image", "no_such_shape", Color.WHITE, 16, false)
	var seen: Array = [unknown.get_data()]
	for kind: String in ["circle", "ring", "rect", "line", "cone", "stamp"]:
		seen.append((tile.call("shape_image", kind, Color.WHITE, 16, false) as Image).get_data())
	for kind: String in NEW_KINDS:
		var step: Dictionary = (_editor().call("defaults_for", kind) as Dictionary).merged({"kind": kind})
		var image: Image = picture.call("rasterize", [step], Vector2i(64, 64), ground)
		rows.append(["the picture draws a %s" % kind, _inked(image, ground) > 0, true])
		var icon: Image = tile.call("shape_image", kind, Color.WHITE, 16, false)
		rows.append(["a %s has its own icon" % kind, seen.has(icon.get_data()), false])
		seen.append(icon.get_data())
	var arc_picture: Image = picture.call("rasterize", [_step("arc", 16.0, 0.0, 360.0, {"thickness": 2.0})], Vector2i(64, 64), ground)
	rows.append(["an arc is hollow in the middle", _near(arc_picture.get_pixel(32, 32), ground), true])
	var pie_picture: Image = picture.call("rasterize", [_step("pie", 16.0, 0.0, 360.0)], Vector2i(64, 64), ground)
	rows.append(["a pie is solid in the middle", _near(pie_picture.get_pixel(32, 32), ground), false])
	var half_arc: Image = picture.call("rasterize", [_step("arc", 16.0, 0.0, 180.0, {"thickness": 3.0})], Vector2i(64, 64), ground)
	rows.append(["an arc turned half way has ink on one side only", _inked_rows(half_arc, ground), true])
	return SUPPORT.pins(TEST_NAME, rows)


static func _near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) < 0.03


## The sweep 0 to 180 is the lower half on screen: ink below the middle and none above it.
static func _inked_rows(image: Image, ground: Color) -> bool:
	var above: int = 0
	var below: int = 0
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			if not _near(image.get_pixel(x, y), ground):
				if y < image.get_height() / 2 - 2:
					above += 1
				elif y > image.get_height() / 2 + 2:
					below += 1
	return above == 0 and below > 0


static func _inked(image: Image, ground: Color) -> int:
	var count: int = 0
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			if not _near(image.get_pixel(x, y), ground):
				count += 1
	return count


## The picture's own test of what a shape covers (the one a click uses) against the polygon the pack draws: a point
## well inside one is inside the other, and a point well outside is outside both.
static func _agreement_pins() -> bool:
	var picture: GDScript = load(PICTURE) as GDScript
	var rows: Array = []
	var steps: Dictionary = {
		"pie": _step("pie", 30.0, -90.0, 90.0),
		"rounded_rect": _step("rounded_rect", 50.0, 30.0, 10.0),
		"regular_polygon": _step("regular_polygon", 30.0, 7.0, -90.0),
	}
	for kind: String in steps:
		var step: Dictionary = steps[kind]
		var outline: PackedVector2Array = _outline(step)
		var disagreements: int = 0
		for gy: int in range(-40, 61):
			for gx: int in range(-40, 61):
				var point: Vector2 = Vector2(gx, gy)
				if _edge_distance(point, outline) < 1.5:
					continue
				var inside_pack: bool = Geometry2D.is_point_in_polygon(point, outline)
				var inside_picture: bool = int(picture.call("hit_step", [step], point, 0.0)) == 0
				if inside_pack != inside_picture:
					disagreements += 1
		rows.append(["the picture and the pack agree about a %s" % kind, disagreements, 0])
	return SUPPORT.pins(TEST_NAME, rows)


static func _edge_distance(point: Vector2, outline: PackedVector2Array) -> float:
	var best: float = INF
	for index: int in outline.size():
		var to: Vector2 = outline[(index + 1) % outline.size()]
		best = minf(best, point.distance_to(Geometry2D.get_closest_point_to_segment(point, outline[index], to)))
	return best
