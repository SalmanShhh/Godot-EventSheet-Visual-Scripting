# Godot EventSheets - Platformer Pathfinding: hazards that move cover their whole travel.
#
# A hazard from a node normally covers where the node is now. With Hazards Cover Travel it covers every
# place the node has been, or the range given with Set Hazard Travel, so a route never goes through a
# lane a moving blade will sweep. A node that moves a different way each time is learned as it goes.
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
	for method_name: String in ["set_hazards_cover_travel", "set_hazard_travel", "hazard_area"]:
		ok = _check("method %s exists" % method_name, nav.has_method(method_name), true) and ok
	blade.free()
	nav.free()
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
