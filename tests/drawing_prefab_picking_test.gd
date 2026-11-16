# Godot EventSheets - clicking a shape in the Drawing Prefab's picture: which shape is under a point, and the
# quietened picture that says which shapes are selected.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const TEST_NAME := "drawing_prefab_picking_test"
const MARKER_PATH := "res://demo/showcase/draw_lab/target_marker.tres"
const BACKGROUND: Color = Color(0.11, 0.12, 0.15, 1.0)
const SIZE: Vector2i = Vector2i(384, 200)


static func run() -> bool:
	var ok: bool = true
	ok = _hit_pins() and ok
	ok = _picture_pins() and ok
	ok = _panel_pins() and ok
	ok = _join_pins() and ok
	return ok


static func _marker_steps() -> Array:
	return ((load(MARKER_PATH) as Resource).get("steps") as Array).duplicate(true)


## The picture pixel where a prefab-local point is drawn, asked of the rasterizer's own layout.
static func _hit(steps: Array, local: Vector2) -> int:
	var preview: GDScript = load("res://addons/eventsheet/editor/inspector/drawing_prefab_preview.gd")
	var pixel: Vector2 = preview.call("pixel_from_local", steps, SIZE, local)
	var back: Vector2 = preview.call("local_from_pixel", steps, SIZE, pixel)
	var tolerance: float = 1.5 / float(preview.call("view_scale", steps, SIZE))
	return int(preview.call("hit_step", steps, back, tolerance))


static func _hit_pins() -> bool:
	var steps: Array = _marker_steps()
	var rows: Array = []
	var preview: GDScript = load("res://addons/eventsheet/editor/inspector/drawing_prefab_preview.gd")
	# Eight steps: two rings, two lines, four dots. A point on each one that no later step covers.
	var points: Array = [Vector2(32.5, 32.5), Vector2(12.7, 12.7), Vector2(-30.0, 0.0), Vector2(0.0, 30.0)]
	for index: int in range(4):
		rows.append(["the point on step %d returns step %d" % [index, index], _hit(steps, points[index]), index])
	for index: int in range(4, 8):
		var dot: Dictionary = steps[index]
		rows.append(["the dot at step %d returns step %d" % [index, index], _hit(steps, Vector2(float(dot["x"]), float(dot["y"]))), index])
	rows.append(["where the lines cross, the line drawn last (on top) is the one taken", _hit(steps, Vector2(0.0, 0.0)), 3])
	rows.append(["empty space returns nothing", _hit(steps, Vector2(25.0, -25.0)), -1])
	rows.append(["far outside the drawing returns nothing", _hit(steps, Vector2(400.0, 400.0)), -1])
	var overlap: Array = [
		{"kind": "circle", "x": 0.0, "y": 0.0, "p1": 20.0, "color": "#ff0000"},
		{"kind": "rect", "x": -10.0, "y": -10.0, "p1": 20.0, "p2": 20.0, "color": "#00ff00"}]
	rows.append(["a rectangle drawn after a disc is taken where they overlap", _hit(overlap, Vector2(0.0, 0.0)), 1])
	rows.append(["and the disc alone where the rectangle is not", _hit(overlap, Vector2(-15.0, -10.0)), 0])
	var cone: Array = [{"kind": "cone", "x": 0.0, "y": 0.0, "p1": 0.0, "p2": 60.0, "p3": 40.0, "color": "#ffffff"}]
	rows.append(["a point inside a cone's wedge", _hit(cone, Vector2(20.0, 0.0)), 0])
	rows.append(["a point on the far side of its apex", _hit(cone, Vector2(-20.0, 0.0)), -1])
	rows.append(["a stamp with no texture draws nothing and cannot be picked", _hit([{"kind": "stamp", "x": 0.0, "y": 0.0, "p1": 1.0, "p2": 0.0, "texture": ""}], Vector2(0.0, 0.0)), -1])
	rows.append(["the stamp that has a texture is picked inside its box", _hit([{"kind": "stamp", "x": 0.0, "y": 0.0, "p1": 1.0, "p2": 0.0, "color": "#ffffff", "texture": "res://eventsheet_addons/drawing_prefab_stamp/icon.svg"}], Vector2(0.0, 0.0)), 0])
	rows.append(["no steps, nothing to pick", int(preview.call("hit_step", [], Vector2.ZERO, 1.0)), -1])
	return SUPPORT.pins(TEST_NAME, rows)


static func _picture_pins() -> bool:
	var preview: GDScript = load("res://addons/eventsheet/editor/inspector/drawing_prefab_preview.gd")
	var steps: Array = _marker_steps()
	var plain: PackedByteArray = (preview.call("rasterize", steps, SIZE, BACKGROUND) as Image).get_data()
	var nothing_quiet: PackedByteArray = (preview.call("rasterize", steps, SIZE, BACKGROUND, []) as Image).get_data()
	var one: PackedByteArray = (preview.call("rasterize", steps, SIZE, BACKGROUND, [4]) as Image).get_data()
	var all: PackedByteArray = (preview.call("rasterize", steps, SIZE, BACKGROUND, [0, 1, 2, 3, 4, 5, 6, 7]) as Image).get_data()
	var image: Image = preview.call("rasterize", steps, SIZE, BACKGROUND, [4]) as Image
	var plain_image: Image = preview.call("rasterize", steps, SIZE, BACKGROUND) as Image
	# The chosen dot keeps its full colour; the ring is quietened toward the ground.
	var dot: Dictionary = steps[4]
	var at: Vector2 = preview.call("pixel_from_local", steps, SIZE, Vector2(float(dot["x"]), float(dot["y"])))
	var ring_at: Vector2 = preview.call("pixel_from_local", steps, SIZE, Vector2(32.5, 32.5))
	var kept: bool = image.get_pixelv(Vector2i(at)) == plain_image.get_pixelv(Vector2i(at))
	var quiet_ring: Color = image.get_pixelv(Vector2i(ring_at))
	var full_ring: Color = plain_image.get_pixelv(Vector2i(ring_at))
	return SUPPORT.pins(TEST_NAME, [
		["an empty quiet list draws the same bytes as no list at all", nothing_quiet == plain, true],
		["a list that names every step quietens nothing", all == plain, true],
		["a list that names one step changes the picture", one != plain, true],
		["the chosen shape keeps its full colour", kept, true],
		["another shape is drawn nearer the background than it was", _apart(quiet_ring) < _apart(full_ring), true],
	])


static func _panel_pins() -> bool:
	var panel_class: GDScript = load("res://addons/eventsheet/editor/inspector/preview_panel.gd")
	# The point of the picture a click at a point of the control lands on, with the picture centred and kept in proportion.
	var wide: Vector2 = panel_class.call("raster_point", Vector2(768.0, 200.0), Vector2(384.0, 200.0), Vector2(384.0, 100.0))
	var tall: Vector2 = panel_class.call("raster_point", Vector2(384.0, 400.0), Vector2(384.0, 200.0), Vector2(0.0, 100.0))
	var outside: Vector2 = panel_class.call("raster_point", Vector2(768.0, 200.0), Vector2(384.0, 200.0), Vector2(10.0, 100.0))
	return SUPPORT.pins(TEST_NAME, [
		["a click in the middle of a wide control is the middle of the picture", wide, Vector2(192.0, 100.0)],
		["a control taller than the picture shows it in the middle band", tall, Vector2(0.0, 0.0)],
		["a click in the bars beside the picture is outside it", outside.x < 0.0, true],
	])


static func _apart(colour: Color) -> float:
	return absf(colour.r - BACKGROUND.r) + absf(colour.g - BACKGROUND.g) + absf(colour.b - BACKGROUND.b)


class _Holder:
	extends RefCounted

	var steps: Array = []


## The click and the selection, joined: a click on a shape selects its card (a stray entry in the list does not shift
## the numbering), Ctrl adds, empty space clears, and a selection names the shapes the picture keeps at full strength.
static func _join_pins() -> bool:
	var preview: GDScript = load("res://addons/eventsheet/editor/inspector/drawing_prefab_preview.gd")
	var holder: _Holder = _Holder.new()
	holder.steps = _marker_steps()
	holder.steps.insert(1, "not a shape")
	var cards: EventSheetCardListDrawer = EventSheetCardListDrawer.new({"kind_key": "kind", "schema_dict": {"kinds": [
		{"kind": "circle", "label": "Circle", "fields": [], "defaults": {}}, {"kind": "ring", "label": "Ring", "fields": [], "defaults": {}},
		{"kind": "line", "label": "Line", "fields": [], "defaults": {}}]}})
	cards.set_value(holder.steps)
	var picking: RefCounted = load("res://addons/eventsheet/editor/inspector/drawing_prefab_picking.gd").new(holder)
	picking.call("attach_cards", cards)
	var dot_two: Dictionary = holder.steps[6]
	var dot_pixel: Vector2 = preview.call("pixel_from_local", holder.steps, SIZE, Vector2(float(dot_two["x"]), float(dot_two["y"])))
	picking.call("_on_picture_pressed", dot_pixel, false, false)
	var picked: Array = cards.selected_cards()
	var chosen: Array = picking.call("chosen_steps")
	var other: Dictionary = holder.steps[7]
	picking.call("_on_picture_pressed", preview.call("pixel_from_local", holder.steps, SIZE, Vector2(float(other["x"]), float(other["y"]))), false, true)
	var added: Array = cards.selected_cards()
	picking.call("_on_picture_pressed", Vector2(2.0, 2.0), false, false)
	var cleared: Array = cards.selected_cards()
	var chosen_after: Array = picking.call("chosen_steps")
	cards.select_card(0, "click")
	var from_list: Array = picking.call("chosen_steps")
	cards.free()
	return SUPPORT.pins(TEST_NAME, [
		["a click on the sixth shape selects the sixth card, though a stray entry sits in the list", picked, [5]],
		["and the picture keeps that step at full strength", chosen, [6]],
		["Ctrl+click adds the next", added, [5, 6]],
		["a click on empty space clears the selection", cleared, []],
		["and the whole picture comes back", chosen_after, []],
		["a card selected in the list names its step in the picture", from_list, [0]],
	])
