# The canvas's draw style, and the two ways the shapes drawn in it reach the screen.
#
# Three claims are held to account here, and all three are about VALUES rather than about a canvas
# being on screen - the batching decision and the raster fallback are plain readings of the command
# queue, so they can be asked without a viewport, a tree or a frame.
#
#   THE STACK IS A STACK. Set replaces the style in force, Push keeps the old one underneath, Pop
#   brings it back, Reset drops the lot. Pinned by the thickness in force after each move, because a
#   stack that loses a level is a debug overlay that draws in the wrong weight three rows later.
#
#   ONE MULTIMESH PER KIND PER FRAME. Three arcs and two grids drawn in one style are TWO batches
#   holding three and two instances - one draw call each - and not five. That is the whole promise
#   the instanced path makes, and the count is what makes it true or false.
#
#   THE RASTER HALF DRAWS THE SAME SHAPES. With no batches taken, the same five commands become five
#   raster primitives, one per shape, so a project without the Vector Shapes pack (or a canvas in the
#   persistent mode that bakes its strokes once) draws every shape the rows asked for.
#
# The quad an instanced shape is drawn on is sized here and again in the batch shader, from the same
# four numbers. They must agree - a quad smaller than its shape clips it - so the reach is pinned by
# value for each kind as well.
@tool
class_name DrawStyleStackTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")

const P := "draw_style_stack_test"


static func run() -> bool:
	var ok: bool = true
	ok = _test_the_stack() and ok
	ok = _test_reading_a_style_file() and ok
	ok = _test_one_multimesh_per_kind() and ok
	ok = _test_a_batch_nobody_draws_is_given_back() and ok
	ok = _test_the_key_rides_the_command() and ok
	ok = _test_the_raster_fallback() and ok
	ok = _test_the_quad_reaches_the_shape() and ok
	return ok


## Set, Push, Pop and Reset, pinned by the thickness in force after each of them.
static func _test_the_stack() -> bool:
	var surface: CanvasSurface = CanvasSurface.new()
	var thin: ShapeStyle = ShapeStyle.new()
	thin.thickness = 1.0
	var thick: ShapeStyle = ShapeStyle.new()
	thick.thickness = 8.0
	var seen: Array = []
	seen.append(surface.current_style()["thickness"])
	surface.set_draw_style(thin)
	seen.append(surface.current_style()["thickness"])
	surface.push_draw_style(thick)
	seen.append(surface.current_style()["thickness"])
	surface.pop_draw_style()
	seen.append(surface.current_style()["thickness"])
	surface.push_draw_style(thick)
	surface.reset_draw_style()
	seen.append(surface.current_style()["thickness"])
	# An empty stack cannot be popped below its floor: a Pop with nothing pushed is the defaults.
	surface.pop_draw_style()
	seen.append(surface.current_style()["thickness"])
	var ok: bool = SUPPORT.pin_value(P, "the thickness in force after set, push, pop, reset",
		seen, [2.0, 1.0, 8.0, 1.0, 2.0, 2.0])
	surface.free()
	return ok


## A style file is read BY NAME, so a resource that carries some of the fields leaves the rest alone.
static func _test_reading_a_style_file() -> bool:
	var style: ShapeStyle = ShapeStyle.new()
	style.thickness = 6.0
	style.caps = "square"
	style.dashed = true
	style.dash_count = 20
	style.colour = Color.RED
	var fields: Dictionary = CanvasSurface.style_fields(style)
	var ok: bool = SUPPORT.pin_table(P, {
		"thickness": 6.0,
		"caps": "square",
		"dashed": true,
		"dash_count": 20,
		"colour": Color.RED,
		"colour_mode": "single",
		"filled": false
	}, func(key: String) -> Variant: return fields[key])
	# Nothing at all in the slot is the canvas's own defaults, not an empty style.
	return SUPPORT.pin_value(P, "an empty style slot is the defaults",
		CanvasSurface.style_fields(null), CanvasSurface.STYLE_DEFAULTS) and ok


## Three arcs and two grids in one style: two batches, three and two instances, in the order the
## frame first drew each kind.
static func _test_one_multimesh_per_kind() -> bool:
	var plan: Array = CanvasSurface.plan_batches(_a_frame())
	var kinds: Array = []
	var counts: Array = []
	for batch: Dictionary in plan:
		kinds.append(batch["kind"])
		counts.append((batch["instances"] as Array).size())
	var ok: bool = SUPPORT.pins(P, [
		["the frame's batches, in the order it drew them", kinds, ["arc", "grid"]],
		["the instances in each", counts, [3, 2]],
		["the kind number each batch hands the shader", [plan[0]["kind_id"], plan[1]["kind_id"]], [0, 4]]
	])
	# The same five shapes in TWO styles are four batches, because a style is shader uniforms and
	# two sets of them cannot ride one draw call.
	var two_styles: Array = _a_frame()
	for index: int in two_styles.size():
		if index % 2 == 0:
			var command: Dictionary = (two_styles[index] as Dictionary).duplicate()
			var style: Dictionary = (command["style"] as Dictionary).duplicate()
			style["thickness"] = 9.0
			command["style"] = style
			two_styles[index] = command
	var split: Array = []
	for batch: Dictionary in CanvasSurface.plan_batches(two_styles):
		split.append([batch["kind"], (batch["instances"] as Array).size()])
	return SUPPORT.pin_value(P, "two styles over the same five shapes",
		split, [["arc", 2], ["arc", 1], ["grid", 1], ["grid", 1]]) and ok


## A BATCH IS KEYED BY ITS STYLE'S OWN VALUES, so a colour being tweened onto Set Draw Style, or a
## Push Draw Style handed a fresh resource each tick, is a new key every frame. Nothing about that is
## wrong - two styles genuinely cannot ride one draw call - but a canvas that only ever ADDED a node
## per key would gain one node a frame for the whole life of the game.
##
## The rule that stops it is a plain reading of two dictionaries, which is why it can be pinned here:
## a batch this draw did not draw counts one more idle draw, and past BATCH_IDLE_DRAWS its node goes
## back on the shelf to be handed out to the next key. The pin is which keys retire, by name, in
## sorted order - a count would not say which one was let go.
static func _test_a_batch_nobody_draws_is_given_back() -> bool:
	var idle: Dictionary = {"arc|thin": 0, "arc|fading": CanvasSurface.BATCH_IDLE_DRAWS, "grid|gone": CanvasSurface.BATCH_IDLE_DRAWS + 1, "arc|older": CanvasSurface.BATCH_IDLE_DRAWS + 9}
	return SUPPORT.pins(P, [
		["a batch this draw drew is never retired, however long it had been idle",
			CanvasSurface.batches_to_retire(idle, {"arc|older": true}), PackedStringArray(["grid|gone"])],
		["a batch has to sit out more than the idle allowance before it goes",
			CanvasSurface.batches_to_retire(idle, {}), PackedStringArray(["arc|older", "grid|gone"])],
		["a draw that drew everything retires nothing",
			CanvasSurface.batches_to_retire(idle, {"arc|thin": true, "arc|fading": true, "grid|gone": true, "arc|older": true}), PackedStringArray()],
		["the allowance is small enough that a style nobody uses does not linger",
			CanvasSurface.BATCH_IDLE_DRAWS <= 4, true],
	])


## The key a shape belongs under is worked out ONCE, as the shape is queued, and rides the command:
## the plan and the raster fallback each used to spell it out again, and a key is a sort of the
## style's field names and a join per field. A command that carries one is planned under it; a
## command written by hand (a test, or anything reading a queue it did not build) still gets the key
## the style says it should have.
static func _test_the_key_rides_the_command() -> bool:
	var carried: Array = [{
		"kind": "arc", "styled": true, "at": Vector2.ZERO, "angle": 0.0,
		"numbers": Vector4(16.0, 0.0, 0.0, TAU), "style": CanvasSurface.STYLE_DEFAULTS,
		"batch_key": "a key the shape was queued under"
	}]
	var planned: Array = CanvasSurface.plan_batches(carried)
	var spelled: Array = CanvasSurface.plan_batches([{
		"kind": "arc", "styled": true, "at": Vector2.ZERO, "angle": 0.0,
		"numbers": Vector4(16.0, 0.0, 0.0, TAU), "style": CanvasSurface.STYLE_DEFAULTS
	}])
	return SUPPORT.pins(P, [
		["a queued shape is planned under the key it was queued with",
			str(planned[0]["key"]) if not planned.is_empty() else "no batch", "a key the shape was queued under"],
		["a command with no key is still planned under the one its style makes",
			str(spelled[0]["key"]) if not spelled.is_empty() else "no batch",
			CanvasSurface.batch_key("arc", CanvasSurface.STYLE_DEFAULTS)],
		["and the raster half skips a taken batch by the key the command carries",
			CanvasSurface.plan_raster(carried, {"a key the shape was queued under": true}).size(), 0],
	])


## With no batch taken, every styled shape is drawn the raster way - the same five shapes, as the
## five primitives that draw them.
static func _test_the_raster_fallback() -> bool:
	var raster: Array = CanvasSurface.plan_raster(_a_frame(), {})
	var drawn: Array = []
	for command: Dictionary in raster:
		drawn.append(command["kind"])
	var ok: bool = SUPPORT.pins(P, [
		["the raster half draws one primitive per shape", raster.size(), 5],
		["and draws them as", drawn, ["arc", "arc", "arc", "multiline", "multiline"]]
	])
	# A frame whose batches were taken leaves the raster half nothing of those kinds to draw, and
	# still draws everything else that was queued.
	var mixed: Array = _a_frame()
	mixed.append({"kind": "circle", "at": Vector2.ZERO, "radius": 8.0, "color": Color.WHITE})
	var taken: Dictionary = {}
	for batch: Dictionary in CanvasSurface.plan_batches(mixed):
		taken[str(batch["key"])] = true
	var left: Array = []
	for command: Dictionary in CanvasSurface.plan_raster(mixed, taken):
		left.append(command["kind"])
	ok = SUPPORT.pin_value(P, "what is left for the raster half once the batches are taken",
		left, ["circle"]) and ok
	# Every one of the eleven shapes has a raster primitive: a row with no fallback would draw
	# nothing at all on a project without the shapes pack, silently.
	var every: Array = []
	for command: Dictionary in _one_of_each():
		every.append(CanvasSurface.raster_shape(command)["kind"])
	return SUPPORT.pin_value(P, "the primitive each of the eleven shapes falls back to", every,
		["arc", "polygon", "polyline", "polyline", "multiline", "multiline", "multiline",
		"polygon", "polyline", "text", "texture_rect"]) and ok


## The reach of each kind, which is the size of the quad it is instanced onto. The batch shader
## works the same number out of the same four numbers.
static func _test_the_quad_reaches_the_shape() -> bool:
	var style: Dictionary = CanvasSurface.STYLE_DEFAULTS.duplicate()
	style["thickness"] = 4.0
	# thickness 4 is a margin of 2 + 1 antialias + 2 = 5 px past whatever the shape reaches.
	return SUPPORT.pin_table(P, {
		"arc": 37.0,
		"pie": 37.0,
		"rounded_rect": 45.0,
		"regular_polygon": 37.0,
		"grid": 45.0,
		"cross": 37.0,
		"arrow": 37.0
	}, func(kind: String) -> Variant:
		return CanvasSurface.batch_extent(kind, Vector4(32.0, 40.0, 8.0, 0.0), style))


## Five styled shapes as the canvas queues them: three arcs, then two grids, all in one style.
static func _a_frame() -> Array:
	var style: Dictionary = CanvasSurface.STYLE_DEFAULTS.duplicate()
	var frame: Array = []
	for index: int in 3:
		frame.append({"kind": "arc", "styled": true, "at": Vector2(float(index) * 40.0, 0.0),
			"angle": 0.0, "numbers": Vector4(24.0, 0.0, 0.0, PI), "style": style})
	for index: int in 2:
		frame.append({"kind": "grid", "styled": true, "at": Vector2(0.0, float(index) * 80.0),
			"angle": 0.0, "numbers": Vector4(64.0, 64.0, 16.0, 0.0), "style": style})
	return frame


## One command of every styled kind the canvas can queue, in the order the pack declares them.
static func _one_of_each() -> Array:
	var style: Dictionary = CanvasSurface.STYLE_DEFAULTS.duplicate()
	var filled: Dictionary = style.duplicate()
	filled["filled"] = true
	var path: PackedVector2Array = PackedVector2Array([Vector2.ZERO, Vector2(10.0, 0.0), Vector2(10.0, 10.0)])
	return [
		{"kind": "arc", "styled": true, "at": Vector2.ZERO, "angle": 0.0, "numbers": Vector4(20.0, 0.0, 0.0, PI), "style": style},
		{"kind": "pie", "styled": true, "at": Vector2.ZERO, "angle": 0.0, "numbers": Vector4(20.0, 0.0, 0.0, PI), "style": style},
		{"kind": "rounded_rect", "styled": true, "at": Vector2.ZERO, "angle": 0.0, "numbers": Vector4(20.0, 10.0, 4.0, 0.0), "style": style},
		{"kind": "regular_polygon", "styled": true, "at": Vector2.ZERO, "angle": 0.0, "numbers": Vector4(20.0, 6.0, 0.0, 0.0), "style": style},
		{"kind": "grid", "styled": true, "at": Vector2.ZERO, "angle": 0.0, "numbers": Vector4(40.0, 40.0, 8.0, 0.0), "style": style},
		{"kind": "cross", "styled": true, "at": Vector2.ZERO, "angle": 0.0, "numbers": Vector4(10.0, 0.0, 0.0, 0.0), "style": style},
		{"kind": "arrow", "styled": true, "at": Vector2.ZERO, "angle": 0.0, "numbers": Vector4(20.0, 6.0, 6.0, 0.0), "style": style},
		{"kind": "polygon", "styled": true, "at": Vector2.ZERO, "angle": 0.0, "numbers": Vector4.ZERO, "style": filled, "points": path},
		{"kind": "polyline", "styled": true, "at": Vector2.ZERO, "angle": 0.0, "numbers": Vector4.ZERO, "style": style, "points": path},
		{"kind": "text", "styled": true, "at": Vector2.ZERO, "angle": 0.0, "numbers": Vector4(16.0, 0.0, 0.0, 0.0), "style": style, "message": "ready"},
		{"kind": "texture", "styled": true, "at": Vector2.ZERO, "angle": 0.0, "numbers": Vector4(16.0, 16.0, 0.0, 0.0), "style": style, "texture": PlaceholderTexture2D.new()}
	]
