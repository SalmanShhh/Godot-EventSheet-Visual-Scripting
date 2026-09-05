# The runtime sentences a placed shape says, and the rule that every one of them parks.
#
# Most of a shape's fields are properties, and a Tween Property or a Set Property row already drives
# any of them. The handful pinned here are the things a designer SAYS rather than writes: tether this
# line between two nodes, fill this ring to a fraction, point at a spot a fraction along the outline,
# fit this box round that node, show this for a second. Each is one row, and each is pinned by the
# value it leaves behind rather than by whether it ran.
#
# THE TICK IS THE OTHER HALF OF THE CLAIM. A shape that follows two nodes, or the cursor, or a
# countdown, is doing work every frame - so the last pin here is that a shape with nothing left to
# follow stops processing entirely. The frames are hand-stepped: a test in this suite has no scene
# tree and no main loop, so `_process` is called directly with the delta the frame would have had.
@tool
class_name ShapeSentencesTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")

const P := "shape_sentences_test"


static func run() -> bool:
	var ok: bool = true
	ok = _test_a_tether_follows_both_ends() and ok
	ok = _test_filling_a_ring() and ok
	ok = _test_a_point_along_the_shape() and ok
	ok = _test_fitting_round_a_node() and ok
	ok = _test_showing_for_a_while() and ok
	ok = _test_everything_parks() and ok
	return ok


## Tether Between puts the line's start on one node and its end on the other, and moves it again the
## frame either of them moves - and does nothing at all on the frames neither did.
static func _test_a_tether_follows_both_ends() -> bool:
	var line: ShapeLine2D = ShapeLine2D.new()
	var player: Node2D = Node2D.new()
	var pet: Node2D = Node2D.new()
	player.position = Vector2(100.0, 50.0)
	pet.position = Vector2(160.0, 50.0)
	line.tether_between(player, pet)
	var placed: Array = [line.position, line.end_point]
	pet.position = Vector2(160.0, 130.0)
	line._process(0.016)
	var moved: Array = [line.position, line.end_point]
	line.untether()
	pet.position = Vector2(400.0, 400.0)
	line._process(0.016)
	var ok: bool = SUPPORT.pins(P, [
		["the tether's two ends when it is tied", placed, [Vector2(100.0, 50.0), Vector2(60.0, 0.0)]],
		["and after the far end moved", moved, [Vector2(100.0, 50.0), Vector2(60.0, 80.0)]],
		["and is no longer tethered once it is let go", line.shape_is_tethered(), false],
		["and stays where it was left once untethered", line.end_point, Vector2(60.0, 80.0)]
	])
	line.free()
	player.free()
	pet.free()
	return ok


## Fill Ring To sweeps the arc to a fraction of the way round, from wherever it starts.
static func _test_filling_a_ring() -> bool:
	var ring: ShapeDisc2D = ShapeDisc2D.new()
	ring.start_angle = 0.0
	var seen: Array = []
	for fraction: float in [0.0, 0.25, 1.0]:
		ring.fill_ring_to(fraction)
		seen.append(ring.end_angle)
	var full: bool = ring.ring_is_full()
	ring.fill_ring_to(0.5)
	var half: bool = ring.ring_is_full()
	var ok: bool = SUPPORT.pins(P, [
		["the arc a fill of none, a quarter and the whole leaves", seen, [0.0, 90.0, 360.0]],
		["a filled ring is full", full, true],
		["and a half one is not", half, false]
	])
	ring.free()
	return ok


## Point Along Shape At walks the outline by length: nothing at 0, the middle at a half, the far end
## at 1, in the shape's own coordinates.
static func _test_a_point_along_the_shape() -> bool:
	var line: ShapeLine2D = ShapeLine2D.new()
	line.end_point = Vector2(100.0, 0.0)
	var ok: bool = SUPPORT.pin_table(P, {
		"0.0": Vector2(0.0, 0.0),
		"0.25": Vector2(25.0, 0.0),
		"1.0": Vector2(100.0, 0.0)
	}, func(key: String) -> Variant: return line.point_along_shape_at(float(key)))
	line.free()
	return ok


## Fit Around sizes a rect to what a node covers, plus a margin, and centres it on it.
static func _test_fitting_round_a_node() -> bool:
	var box: ShapeRect2D = ShapeRect2D.new()
	var unit: Sprite2D = Sprite2D.new()
	var art: PlaceholderTexture2D = PlaceholderTexture2D.new()
	art.size = Vector2(40.0, 20.0)
	unit.texture = art
	unit.position = Vector2(200.0, 300.0)
	box.fit_around(unit, 4.0)
	var ok: bool = SUPPORT.pins(P, [
		["what the node covers, in world coordinates", VectorShape2D.node_bounds(unit),
			Rect2(Vector2(180.0, 290.0), Vector2(40.0, 20.0))],
		["the box a fit with a margin of four leaves", box.size, Vector2(48.0, 28.0)],
		["centred on the node", box.position, Vector2(200.0, 300.0)]
	])
	# A node with nothing to measure leaves the shape exactly as it was, rather than collapsing it.
	var empty: Node2D = Node2D.new()
	box.fit_around(empty, 4.0)
	ok = SUPPORT.pin_value(P, "a node with nothing to measure leaves the shape alone",
		box.size, Vector2(48.0, 28.0)) and ok
	box.free()
	unit.free()
	empty.free()
	return ok


## Show For shows the shape and hides it again when the seconds have gone by, one hand-stepped frame
## at a time.
static func _test_showing_for_a_while() -> bool:
	var mark: ShapeDisc2D = ShapeDisc2D.new()
	mark.visible = false
	mark.show_shape_for(0.3)
	var shown: bool = mark.visible
	for frame: int in 2:
		mark._process(0.1)
	var still: bool = mark.visible
	mark._process(0.1)
	var gone: bool = mark.visible
	var ok: bool = SUPPORT.pins(P, [
		["the shape is shown the moment the row runs", shown, true],
		["still there two tenths in", still, true],
		["and hidden when the three are up", gone, false],
		["with nothing left to tick", mark.is_processing(), false]
	])
	mark.free()
	return ok


## Nothing here keeps a tick it does not need: a shape that has stopped scrolling, stopped following
## and stopped counting down stops processing on the very next frame.
static func _test_everything_parks() -> bool:
	var line: ShapeLine2D = ShapeLine2D.new()
	var anchor: Node2D = Node2D.new()
	var end: Node2D = Node2D.new()
	line.scroll_dashes(2.0)
	line.tether_between(anchor, end)
	line.follow_cursor(32.0)
	line.show_shape_for(0.1)
	var busy: bool = line.is_processing()
	line.scroll_dashes(0.0)
	line.untether()
	line.stop_following()
	line._process(0.2)
	var parked: bool = line.is_processing()
	var ok: bool = SUPPORT.pins(P, [
		["a shape with work to do is processing", busy, true],
		["and one with none has parked", parked, false]
	])
	line.free()
	anchor.free()
	end.free()
	return ok
