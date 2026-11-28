# Godot EventSheets - Platformer Pathfinding: hazards that move cover their whole travel, and crushers.
#
# A hazard from a node normally covers where the node is now. With Hazards Cover Travel it covers every
# place the node has been, or the range given with Set Hazard Travel. A crusher is a moving hazard that
# is a danger (not a wall) and that an agent waits out; the waiting itself needs a body that stands on
# a floor in a running scene, so the runtime harness proves it - here the area it sweeps, the guess of
# where it will be and the bookkeeping are pinned.
@tool
class_name PlatformerPathfindingHazardTravelTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const PACK := "res://eventsheet_addons/platformer_pathfinding/platformer_pathfinding_behavior.gd"

## A sliding blade: 20 wide, 10 tall, centred on its node.
const BLADE := Vector2(20.0, 10.0)


static func run() -> bool:
	var ok: bool = true
	var script: GDScript = load(PACK)
	ok = _check("pack loads", script != null, true) and ok
	if script == null:
		return ok
	ok = _default_covers_where_it_is(script) and ok
	ok = _option_covers_travel(script) and ok
	ok = _given_travel(script) and ok
	ok = _crushers(script) and ok
	return ok


static func _default_covers_where_it_is(script: GDScript) -> bool:
	var ok: bool = true
	var nav: Node = script.new()
	ok = _check("Hazards Cover Travel ships off", nav.get("hazards_cover_travel"), false) and ok
	var blade: Node2D = _blade(Vector2(100.0, 140.0))
	nav.add_hazard_from_node(blade, true)
	var id: int = nav.last_hazard_id()
	blade.position = Vector2(300.0, 140.0)
	nav._prune_tracked_hazards()
	ok = _check("by default the hazard is where the node is now", nav.hazard_area(id), Rect2(290.0, 135.0, 20.0, 10.0)) and ok
	ok = _check("so the place it left is clear", nav.hazard_at(100.0, 140.0), 0) and ok
	ok = _check("a hazard that does not exist has an empty area", nav.hazard_area(9999), Rect2()) and ok
	blade.free()
	nav.free()
	return ok


static func _option_covers_travel(script: GDScript) -> bool:
	var ok: bool = true
	var nav: Node = script.new()
	nav.set_hazards_cover_travel(true)
	var blade: Node2D = _blade(Vector2(100.0, 140.0))
	nav.add_hazard_from_node(blade, true)
	var id: int = nav.last_hazard_id()
	for x in [140.0, 220.0, 300.0, 200.0]:
		blade.position = Vector2(x, 140.0)
		nav._prune_tracked_hazards()
	ok = _check("with the option the hazard covers every place the node has been", nav.hazard_area(id), Rect2(90.0, 135.0, 220.0, 10.0)) and ok
	ok = _check("a point it has passed over is deadly", nav.hazard_at(150.0, 140.0), 2) and ok
	ok = _check("the far end is deadly", nav.hazard_at(305.0, 140.0), 2) and ok
	ok = _check("beyond its range is clear", nav.hazard_at(330.0, 140.0), 0) and ok
	ok = _check("it still counts as one hazard", nav.hazard_count(), 1) and ok
	ok = _check("and as a node-following hazard", nav.tracked_hazard_count(), 1) and ok
	# A route link under the swept range is judged against the whole range.
	ok = _check("a link through the swept range is deadly", nav._segment_hazard(Vector2i(4, 4), Vector2i(5, 4)), 2) and ok
	# A circle that follows a node covers its travel too.
	var saw: Node2D = Node2D.new()
	saw.position = Vector2(500.0, 140.0)
	nav.add_tracked_hazard(saw, 12.0, false)
	var saw_id: int = nav.last_hazard_id()
	for x in [540.0, 620.0]:
		saw.position = Vector2(x, 140.0)
		nav._prune_tracked_hazards()
	ok = _check("a circle from a node covers the box its travel makes", nav.hazard_area(saw_id), Rect2(488.0, 128.0, 144.0, 24.0)) and ok
	ok = _check("a point along its route is a danger", nav.hazard_at(560.0, 140.0), 1) and ok
	ok = _check("a point off its route is clear", nav.hazard_at(560.0, 200.0), 0) and ok
	saw.free()
	blade.free()
	nav.free()
	return ok


static func _given_travel(script: GDScript) -> bool:
	var ok: bool = true
	var nav: Node = script.new()
	var blade: Node2D = _blade(Vector2(100.0, 140.0))
	nav.add_hazard_from_node(blade, true)
	var id: int = nav.last_hazard_id()
	nav.set_hazard_travel(blade, 100.0, 140.0, 400.0, 140.0)
	ok = _check("a given travel covers the range from the start", nav.hazard_area(id), Rect2(90.0, 135.0, 320.0, 10.0)) and ok
	blade.position = Vector2(250.0, 140.0)
	nav._prune_tracked_hazards()
	ok = _check("and stays what was given while the node moves", nav.hazard_area(id), Rect2(90.0, 135.0, 320.0, 10.0)) and ok
	ok = _check("the middle of the range is deadly", nav.hazard_at(350.0, 140.0), 2) and ok
	var untouched: Node2D = _blade(Vector2(0.0, 0.0))
	nav.set_hazard_travel(untouched, 0.0, 0.0, 10.0, 0.0)
	ok = _check("a node with no hazard gets none", nav.hazard_count(), 1) and ok
	untouched.free()
	blade.free()
	nav.free()
	return ok


static func _crushers(script: GDScript) -> bool:
	var ok: bool = true
	var nav: Node = script.new()
	var press: Node2D = _blade(Vector2(200.0, 100.0))
	nav.add_crusher_from_node(press)
	var id: int = nav.last_hazard_id()
	ok = _check("a crusher is a hazard", nav.hazard_count(), 1) and ok
	ok = _check("and is counted as a crusher", nav.crusher_count(), 1) and ok
	ok = _check("it is a danger, not a wall (routes may pay to cross it)", nav.hazard_at(200.0, 100.0), 1) and ok
	ok = _check("it follows a node, like the other node hazards", nav.tracked_hazard_count(), 1) and ok
	nav.add_crusher_from_node(press)
	ok = _check("asking again does not stack a copy", nav.hazard_count(), 1) and ok
	# The area it sweeps is what it has moved through.
	for y in [140.0, 180.0, 120.0]:
		press.position = Vector2(200.0, y)
		nav._prune_tracked_hazards()
	ok = _check("the crusher's area is the whole lane it travels", nav.hazard_area(id), Rect2(190.0, 95.0, 20.0, 90.0)) and ok
	ok = _check("a point in the lane it has left is still a danger", nav.hazard_at(200.0, 105.0), 1) and ok
	ok = _check("it is not in the way when it is not waiting", nav.is_waiting_for_crusher(), false) and ok
	# Where it will be: heading, speed and the two ends of its travel.
	var hazard: RefCounted = nav.get("_hazards")[0]
	hazard.set("end_a", Vector2(200.0, 100.0))
	hazard.set("end_b", Vector2(200.0, 196.0))
	hazard.set("last_origin", Vector2(200.0, 100.0))
	hazard.set("live", Rect2(190.0, 95.0, 20.0, 10.0))
	hazard.set("top_speed", 96.0)
	hazard.set("velocity", Vector2(0.0, 96.0))
	ok = _check("now it is where it is", nav._crusher_bounds_at(hazard, 0.0), Rect2(190.0, 95.0, 20.0, 10.0)) and ok
	ok = _check("half a second on it is half way down", nav._crusher_bounds_at(hazard, 0.5), Rect2(190.0, 143.0, 20.0, 10.0)) and ok
	ok = _check("a second on it has reached the bottom", nav._crusher_bounds_at(hazard, 1.0), Rect2(190.0, 191.0, 20.0, 10.0)) and ok
	ok = _check("and a second and a half on it is coming back up", nav._crusher_bounds_at(hazard, 1.5), Rect2(190.0, 143.0, 20.0, 10.0)) and ok
	hazard.set("velocity", Vector2.ZERO)
	ok = _check("standing at the top it is guessed to set off down", nav._crusher_bounds_at(hazard, 0.5), Rect2(190.0, 143.0, 20.0, 10.0)) and ok
	hazard.set("last_origin", Vector2(200.0, 196.0))
	hazard.set("live", Rect2(190.0, 191.0, 20.0, 10.0))
	ok = _check("standing at the bottom it is guessed to set off up", nav._crusher_bounds_at(hazard, 0.5), Rect2(190.0, 143.0, 20.0, 10.0)) and ok
	# A trail that shows a whole cycle is replayed, slow stretches at the ends included.
	var cycling: Node = script.new()
	var weaver: Node2D = _blade(Vector2(200.0, 100.0))
	cycling.add_crusher_from_node(weaver)
	var swinger: RefCounted = cycling.get("_hazards")[0]
	var samples: PackedVector2Array = PackedVector2Array()
	for tick in range(320):
		samples.append(Vector2(200.0, 472.0 + 72.0 * sin(2.6 * float(tick) / 60.0)))
	swinger.set("trail", samples)
	swinger.set("end_a", Vector2(200.0, 400.0))
	swinger.set("end_b", Vector2(200.0, 544.0))
	swinger.set("live", Rect2(190.0, samples[319].y - 5.0, 20.0, 10.0))
	swinger.set("last_origin", samples[319])
	var cycle: int = int(cycling.call("_crusher_cycle", swinger))
	ok = _check("the cycle is found from the trail (2.4 s is 145 ticks)", absi(cycle - 145) <= 2, true) and ok
	var expected_y: float = 472.0 + 72.0 * sin(2.6 * (319.0 + 30.0) / 60.0)
	var predicted: Rect2 = cycling.call("_crusher_bounds_at", swinger, 0.5)
	ok = _check("half a second on, the replay puts the crusher where its cycle does", absf(predicted.position.y + 5.0 - expected_y) < 4.0, true) and ok
	var short: PackedVector2Array = samples.slice(0, 20)
	swinger.set("trail", short)
	swinger.set("cycle_frame", -1)
	ok = _check("a trail too short to show a cycle replays nothing", int(cycling.call("_crusher_cycle", swinger)), 0) and ok
	weaver.free()
	cycling.free()
	# Removing the node's hazard removes the crusher.
	nav.remove_hazard_from_node(press)
	ok = _check("removing the node's hazard removes the crusher", nav.crusher_count(), 0) and ok
	# A hazard already added from the node becomes the crusher and keeps its flag.
	nav.add_hazard_from_node(press, true)
	nav.add_crusher_from_node(press)
	ok = _check("a node hazard that becomes a crusher is still one hazard", nav.hazard_count(), 1) and ok
	ok = _check("and keeps its deadly flag", nav.hazard_at(200.0, 120.0), 2) and ok
	ok = _check("it counts as a crusher now", nav.crusher_count(), 1) and ok
	press.free()
	nav.free()
	for method_name: String in ["set_hazards_cover_travel", "set_hazard_travel", "add_crusher_from_node", "is_waiting_for_crusher", "crusher_count", "hazard_area"]:
		var probe: Node = script.new()
		ok = _check("method %s exists" % method_name, probe.has_method(method_name), true) and ok
		probe.free()
	return ok


## A node with a body that has one rectangular shape of BLADE size, centred on the node.
static func _blade(at: Vector2) -> Node2D:
	var root: Node2D = Node2D.new()
	var body: StaticBody2D = StaticBody2D.new()
	var shape_node: CollisionShape2D = CollisionShape2D.new()
	var rectangle: RectangleShape2D = RectangleShape2D.new()
	rectangle.size = BLADE
	shape_node.shape = rectangle
	body.add_child(shape_node)
	root.add_child(body)
	root.position = at
	return root


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("platformer_pathfinding_hazard_travel_test", label, actual, expected)
