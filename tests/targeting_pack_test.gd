# Godot EventSheets - the Targeting pack (2D lock-on and aim assist).
#
# The pack holds one hostile at a time, cycles along the cone it searched, lets go when the target
# dies, walks out of reach, steps behind a wall or is released, and bends a stick direction toward
# whatever the aim is nearly on. Everything here drives the COMPILED pack directly and steps it by
# hand - a headless run has no main loop, so nothing in this file waits for a frame.
#
# Three of the pack's questions need a scene tree, and each is asked through one small function of
# its own precisely so a headless test can answer it: which nodes are in a group, whether a wall
# stands between two points, and where a world point lands on screen. The stub below is the shipped
# pack with those three answered from fields this file writes, so every value pinned underneath is
# the pack's own arithmetic over inputs a test can choose. The canvas-transform line the real screen
# seam holds is pinned separately, as text, because no viewport exists here to run it.
#
# The aim-assist radius is Engine meta - process-wide state on a serial CI run - so this file saves
# whatever was there, writes its own, and puts the original back before it returns.
@tool
class_name TargetingPackTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const PACK := "res://eventsheet_addons/targeting/targeting_behavior.gd"
const RADIUS_META := "aim_assist_radius"


static func run() -> bool:
	var had_radius: bool = Engine.has_meta(RADIUS_META)
	var old_radius: Variant = Engine.get_meta(RADIUS_META, 0.0)
	var all_passed: bool = true
	all_passed = _test_locking_the_nearest() and all_passed
	all_passed = _test_cycling_wraps() and all_passed
	all_passed = _test_how_a_lock_ends() and all_passed
	all_passed = _test_the_assist() and all_passed
	all_passed = _test_what_the_pack_ships() and all_passed
	if had_radius:
		Engine.set_meta(RADIUS_META, old_radius)
	else:
		Engine.remove_meta(RADIUS_META)
	return all_passed


## Lock On To Nearest: the cone gates who is even a candidate, the range gates it again, and the
## nearest of what is left is the one held. The cone is measured around the host's own rotation,
## which is the facing the Line Of Sight behaviour uses too.
static func _test_locking_the_nearest() -> bool:
	var all_passed: bool = true
	var stub: GDScript = _stub()
	if stub == null:
		return _check("the stubbed pack compiles", false, true)
	var lock: Node = stub.new()
	var host: Node2D = Node2D.new()
	lock.set("host", host)

	var ahead: Node2D = _at(Vector2(100.0, 0.0))
	var right_of_it: Node2D = _at(Vector2(50.0, 50.0))
	var behind: Node2D = _at(Vector2(-100.0, 0.0))
	var far_away: Node2D = _at(Vector2(600.0, 0.0))
	lock.set("members", [ahead, right_of_it, behind, far_away])

	var locked: Array = []
	lock.connect("target_locked", func(node: Node2D) -> void: locked.append(node))

	# A 60 degree cone reaches 30 degrees each side of the facing, so the node 45 degrees off is
	# not a candidate at all and the one dead ahead is the only thing left to hold.
	lock.lock_nearest(&"enemies", 60.0, 400.0)
	all_passed = _check("the node inside the cone is held", lock.locked_target() == ahead, true) and all_passed
	all_passed = _check("and the pack says it is locked on", lock.is_locked_on(), true) and all_passed
	all_passed = _check("the distance is the real one", lock.distance_to_target(), 100.0) and all_passed
	all_passed = _check("On Target Locked fired once", locked.size(), 1) and all_passed
	lock.lock_nearest(&"enemies", 60.0, 400.0)
	all_passed = _check("searching again for the same node announces nothing new",
		locked.size(), 1) and all_passed

	# Widen the cone and the node 45 degrees off becomes a candidate - and it is nearer, so the
	# lock moves to it. The one behind and the one out of reach are still nobody.
	lock.release_lock()
	lock.lock_nearest(&"enemies", 180.0, 400.0)
	all_passed = _check("a wider cone finds the nearer node off to one side",
		lock.locked_target() == right_of_it, true) and all_passed
	all_passed = _check("the ring holds exactly the candidates, in angle order",
		_names(lock.get("_ring"), [right_of_it, ahead, behind, far_away]), "1,0") and all_passed

	# A search that finds nothing leaves the lock alone: an enemy stepping out of the cone for one
	# frame must not drop a lock that the loss check is already watching for real reasons.
	lock.set("members", [])
	lock.lock_nearest(&"enemies", 180.0, 400.0)
	all_passed = _check("a search that finds nothing keeps the target it had",
		lock.locked_target() == right_of_it, true) and all_passed

	# Lock On To names its own node, whatever the cone says - the boss the cutscene points at.
	lock.set("members", [ahead, right_of_it, behind, far_away])
	lock.lock_on_to(behind)
	all_passed = _check("Lock On To holds the node it is handed, cone or no cone",
		lock.locked_target() == behind, true) and all_passed
	all_passed = _check("and it is the whole ring afterwards",
		(lock.get("_ring") as Array).size(), 1) and all_passed
	lock.lock_on_to(null)
	all_passed = _check("locking on to nothing is refused, not obeyed",
		lock.locked_target() == behind, true) and all_passed

	# Nothing held is not a distance of zero: INF is the answer that makes "is the target closer
	# than 200" plainly false instead of accidentally true.
	lock.release_lock()
	all_passed = _check("with nothing held the distance is infinite",
		lock.distance_to_target(), INF) and all_passed
	all_passed = _check("and the target reads as nothing", lock.locked_target() == null, true) and all_passed
	all_passed = _check("and its screen position is the origin",
		lock.locked_target_on_screen(), Vector2.ZERO) and all_passed

	# The screen seam, proved by routing: a held target's screen position is the answer the seam
	# gives for the target's world position, and nothing else.
	lock.lock_on_to(ahead)
	all_passed = _check("a held target reports the screen point of its own world position",
		lock.locked_target_on_screen(), Vector2(200.0, 0.0)) and all_passed

	for node: Node2D in [ahead, right_of_it, behind, far_away]:
		node.free()
	host.free()
	lock.free()
	return all_passed


## Cycle Target steps along the ring the last search built, left to right by angle, and wraps.
## The order is the reason cycling is predictable: it is the angle from the facing, not whatever
## order the tree happened to list the group in.
static func _test_cycling_wraps() -> bool:
	var all_passed: bool = true
	var stub: GDScript = _stub()
	if stub == null:
		return _check("the stubbed pack compiles", false, true)
	var lock: Node = stub.new()
	var host: Node2D = Node2D.new()
	lock.set("host", host)

	# Three candidates at three angles from the facing: one to the left, one dead ahead, one to
	# the right. On screen the y axis points down, so the negative-y node is the left-hand one.
	var left: Node2D = _at(Vector2(60.0, -60.0))
	var middle: Node2D = _at(Vector2(100.0, 0.0))
	var right_side: Node2D = _at(Vector2(50.0, 50.0))
	lock.set("members", [middle, right_side, left])

	lock.lock_nearest(&"enemies", 180.0, 400.0)
	all_passed = _check("the ring is ordered left to right by angle",
		_names(lock.get("_ring"), [left, middle, right_side]), "0,1,2") and all_passed
	all_passed = _check("the nearest of the three is the one held",
		lock.locked_target() == right_side, true) and all_passed
	lock.cycle_target()
	all_passed = _check("cycling off the rightmost wraps to the leftmost",
		lock.locked_target() == left, true) and all_passed
	lock.cycle_target()
	all_passed = _check("then to the middle", lock.locked_target() == middle, true) and all_passed
	lock.cycle_target()
	all_passed = _check("then round to the right again", lock.locked_target() == right_side, true) and all_passed

	# Cycling with nothing held takes the leftmost, because find() answers -1 and the entry after
	# -1 is the first one.
	lock.release_lock()
	lock.cycle_target()
	all_passed = _check("cycling with nothing held takes the leftmost",
		lock.locked_target() == left, true) and all_passed

	# A candidate that died since the search is dropped before the step, so cycling never lands
	# on a corpse.
	middle.free()
	lock.cycle_target()
	all_passed = _check("a dead candidate is stepped over, not onto",
		lock.locked_target() == right_side, true) and all_passed
	all_passed = _check("and the dead one is gone from the ring for good",
		(lock.get("_ring") as Array).size(), 2) and all_passed

	left.free()
	right_side.free()
	host.free()
	lock.free()
	return all_passed


## The four ways a lock ends, and the one word each of them says. They all leave through the same
## door, so one On Target Lost row cleans the reticle up after every one of them.
static func _test_how_a_lock_ends() -> bool:
	var all_passed: bool = true
	for ending: Array in [["died", 0], ["out_of_range", 1], ["blocked", 2], ["released", 3]]:
		var why: String = str(ending[0])
		var stub: GDScript = _stub()
		if stub == null:
			return _check("the stubbed pack compiles", false, true)
		var lock: Node = stub.new()
		var host: Node2D = Node2D.new()
		lock.set("host", host)
		var target: Node2D = _at(Vector2(100.0, 0.0))
		lock.set("members", [target])
		var lost: Array = []
		lock.connect("target_lost", func(reason: StringName) -> void: lost.append(String(reason)))
		lock.lock_nearest(&"enemies", 360.0, 400.0)
		all_passed = _check("[%s] the target is held to begin with" % why,
			lock.is_locked_on(), true) and all_passed
		all_passed = _check("[%s] and the loss check is running" % why,
			lock.is_processing(), true) and all_passed
		match ending[1]:
			0:
				target.free()
				lock._process(0.016)
			1:
				target.global_position = Vector2(900.0, 0.0)
				lock._process(0.016)
			2:
				lock.set("require_line_of_sight", true)
				lock.set("clear_view", false)
				lock._process(0.016)
			_:
				lock.release_lock()
		all_passed = _check("[%s] the lock ended for that reason" % why,
			",".join(PackedStringArray(lost)), why) and all_passed
		all_passed = _check("[%s] nothing is held afterwards" % why,
			lock.is_locked_on(), false) and all_passed
		all_passed = _check("[%s] and the per-frame check parked itself" % why,
			lock.is_processing(), false) and all_passed
		lock._process(0.016)
		all_passed = _check("[%s] a tick after the ending says nothing more" % why,
			lost.size(), 1) and all_passed
		if ending[1] != 0:
			target.free()
		host.free()
		lock.free()
	return all_passed


## Assisted Aim and Magnetism, against the shipped accessibility setting. Both read Engine's
## "aim_assist_radius" meta - the one Set Aim Assist Radius writes - so a zero radius is the off
## switch the options screen already has, without either row knowing what an options screen is.
static func _test_the_assist() -> bool:
	var all_passed: bool = true
	var stub: GDScript = _stub()
	if stub == null:
		return _check("the stubbed pack compiles", false, true)
	var lock: Node = stub.new()
	var host: Node2D = Node2D.new()
	lock.set("host", host)
	# 100 px along the aim and 20 px across it: well inside a 50 px radius, so the aim bends.
	var near_the_aim: Node2D = _at(Vector2(100.0, 20.0))
	lock.set("members", [near_the_aim])
	var toward: Vector2 = Vector2(100.0, 20.0).normalized()

	Engine.set_meta(RADIUS_META, 50.0)
	all_passed = _check("a strength of 0 is the direction it was handed",
		lock.assisted_aim(Vector2.RIGHT, 0.0), Vector2.RIGHT) and all_passed
	all_passed = _check("a strength of 1 points straight at the target",
		lock.assisted_aim(Vector2.RIGHT, 1.0).distance_to(toward) < 0.0001, true) and all_passed
	all_passed = _check("and half a strength bends half the angle",
		absf(lock.assisted_aim(Vector2.RIGHT, 0.5).angle() - toward.angle() * 0.5) < 0.0001,
		true) and all_passed
	all_passed = _check("the length handed in is the length handed back",
		absf(lock.assisted_aim(Vector2(3.0, 0.0), 1.0).length() - 3.0) < 0.0001, true) and all_passed
	all_passed = _check("a strength past 1 is still just dead on",
		lock.assisted_aim(Vector2.RIGHT, 4.0).distance_to(toward) < 0.0001, true) and all_passed
	all_passed = _check("nothing to aim at is the direction it was handed",
		lock.assisted_aim(Vector2.UP, 1.0), Vector2.UP) and all_passed
	all_passed = _check("and a zero direction stays a zero direction",
		lock.assisted_aim(Vector2.ZERO, 1.0), Vector2.ZERO) and all_passed

	# The radius is measured ACROSS the aim - how far from dead centre a target still counts,
	# which is what the shipped setting's own words say.
	Engine.set_meta(RADIUS_META, 10.0)
	all_passed = _check("a target further off the ray than the radius gets no help",
		lock.assisted_aim(Vector2.RIGHT, 1.0), Vector2.RIGHT) and all_passed

	# Magnetism drags the turn while the aim is crossing a target, and leaves it alone otherwise.
	Engine.set_meta(RADIUS_META, 50.0)
	all_passed = _check("a turn across a target is slowed by the behaviour's own factor",
		lock.magnetism(180.0), 90.0) and all_passed
	lock.set("magnetism_slowdown", 0.25)
	all_passed = _check("and the factor is the one on the node", lock.magnetism(180.0), 45.0) and all_passed
	lock.set("members", [])
	all_passed = _check("with nothing under the aim the turn rate is untouched",
		lock.magnetism(180.0), 180.0) and all_passed

	# THE OFF SWITCH: a radius of zero, which is what the accessibility setting ships as.
	lock.set("members", [near_the_aim])
	Engine.set_meta(RADIUS_META, 0.0)
	all_passed = _check("a zero radius hands the aim straight back",
		lock.assisted_aim(Vector2.RIGHT, 1.0), Vector2.RIGHT) and all_passed
	all_passed = _check("and leaves the turn rate alone", lock.magnetism(180.0), 180.0) and all_passed
	Engine.remove_meta(RADIUS_META)
	all_passed = _check("a setting nobody ever wrote is the same as a zero one",
		lock.assisted_aim(Vector2.RIGHT, 1.0), Vector2.RIGHT) and all_passed

	near_the_aim.free()
	host.free()
	lock.free()
	return all_passed


## What the pack ships as text: the two triggers, the row sentences, and the canvas-transform line
## the screen seam holds - which no headless run can execute, so it is read rather than run.
static func _test_what_the_pack_ships() -> bool:
	var all_passed: bool = true
	var shipped: String = FileAccess.get_file_as_string(PACK)
	all_passed = _check("the pack reads off disk", shipped.is_empty(), false) and all_passed
	for line: String in [
		"## @ace_name(\"On Target Locked\")",
		"## @ace_name(\"On Target Lost\")",
		"signal target_locked(target: Node2D)",
		"signal target_lost(why: StringName)",
		"host.get_viewport().get_canvas_transform() * world_point",
		"Engine.get_meta(\"aim_assist_radius\", 0.0)",
	]:
		all_passed = _check("the pack ships %s" % line, shipped.contains(line), true) and all_passed
	for sentence: String in [
		"lock on to the nearest [b]{group}[/b] in a [b]{cone_degrees}[/b]° cone, [b]{max_range}[/b] out",
		"cycle to the next target",
		"release the lock",
	]:
		all_passed = _check("the pack ships the row sentence %s" % sentence,
			shipped.contains("## @ace_display_template(\"%s\")" % sentence), true) and all_passed
	return all_passed


## The shipped pack with its three tree questions answered from fields, so this file can choose
## the group, the walls and the camera. Everything else is the pack's own bytes.
static func _stub() -> GDScript:
	var script: GDScript = GDScript.new()
	script.source_code = "\n".join(PackedStringArray([
		"extends \"%s\"" % PACK,
		"",
		"",
		"var members: Array = []",
		"var clear_view: bool = true",
		"",
		"",
		"func _group_members(_group: StringName) -> Array:",
		"\tvar living: Array = []",
		"\tfor node: Node in members:",
		"\t\tif is_instance_valid(node):",
		"\t\t\tliving.append(node)",
		"\treturn living",
		"",
		"",
		"func _view_is_clear(_from_point: Vector2, _to_point: Vector2) -> bool:",
		"\treturn clear_view if require_line_of_sight else true",
		"",
		"",
		"func _screen_point(world_point: Vector2) -> Vector2:",
		"\treturn world_point * 2.0",
		"",
	]))
	return script if script.reload() == OK else null


## A bare Node2D parked at a world position - one candidate for the group.
static func _at(where: Vector2) -> Node2D:
	var node: Node2D = Node2D.new()
	node.global_position = where
	return node


## A ring read back as the INDEXES of the nodes it holds, in the roster's own order. Pinning the
## indexes rather than the size says which nodes are in it and in what order, which is the whole
## point of the ring.
static func _names(ring: Variant, roster: Array) -> String:
	var found: PackedStringArray = PackedStringArray()
	for node: Variant in (ring as Array):
		found.append(str(roster.find(node)))
	return ",".join(found)


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("targeting_pack_test", label, actual, expected)
