# Godot EventSheets - the Targeting 3D pack (lock-on and aim assist for a Node3D).
#
# The pack is the 2D one's twin word for word, and this file pins the two things only 3D has: the
# cone is measured around the CAMERA's forward rather than the host's own rotation, because a
# third-person game locks on to what is on screen; and Snap On Aim Down Sights turns the host onto
# the nearest target the aim is already nearly on. Everything else - the ring order, the four ways
# a lock ends, the assist reading the accessibility radius - is pinned here too, because a twin
# that quietly stopped agreeing with its pair is exactly the drift a designer would meet as a bug.
#
# Everything drives the COMPILED pack and steps it by hand: a headless run has no main loop, so
# nothing in this file waits for a frame.
#
# Four of the pack's questions need a scene tree, and each is asked through one small function of
# its own precisely so a headless test can answer it: which nodes are in a group, which camera the
# player looks through, whether a wall stands between two points, and where a world point lands on
# screen. The stub below is the shipped pack with the group, the walls and the screen seam answered
# from fields this file writes - the CAMERA seam is answered with a real Camera3D, so the facing
# the cone is measured around is the pack's own arithmetic over a camera a test can turn. The
# unproject line the real screen seam holds is pinned separately, as text, because no viewport
# exists here to run it.
#
# The aim-assist radius is Engine meta - process-wide state on a serial CI run - so this file saves
# whatever was there, writes its own, and puts the original back before it returns.
@tool
class_name Targeting3DPackTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const PACK := "res://eventsheet_addons/targeting_3d/targeting_3d_behavior.gd"
const RADIUS_META := "aim_assist_radius"


static func run() -> bool:
	var had_radius: bool = Engine.has_meta(RADIUS_META)
	var old_radius: Variant = Engine.get_meta(RADIUS_META, 0.0)
	var all_passed: bool = true
	all_passed = _test_locking_the_nearest() and all_passed
	all_passed = _test_the_cone_follows_the_camera() and all_passed
	all_passed = _test_cycling_wraps() and all_passed
	all_passed = _test_how_a_lock_ends() and all_passed
	all_passed = _test_a_named_lock_ignores_the_range() and all_passed
	all_passed = _test_the_assist() and all_passed
	all_passed = _test_snapping_on_aim_down_sights() and all_passed
	all_passed = _test_what_the_pack_ships() and all_passed
	if had_radius:
		Engine.set_meta(RADIUS_META, old_radius)
	else:
		Engine.remove_meta(RADIUS_META)
	return all_passed


## Lock On To Nearest: the cone gates who is even a candidate, the range gates it again, and the
## nearest of what is left is the one held.
static func _test_locking_the_nearest() -> bool:
	var all_passed: bool = true
	var stub: GDScript = _stub()
	if stub == null:
		return _check("the stubbed pack compiles", false, true)
	var lock: Node = stub.new()
	var host: Node3D = Node3D.new()
	var eye: Camera3D = Camera3D.new()
	lock.set("host", host)
	lock.set("eye", eye)

	# The camera looks down -Z, which is forward for every node Godot builds. Ahead is straight
	# down that axis, the second node is 45 degrees off to the right, one is behind, one is out.
	var ahead: Node3D = _at(Vector3(0.0, 0.0, -10.0))
	var right_of_it: Node3D = _at(Vector3(5.0, 0.0, -5.0))
	var behind: Node3D = _at(Vector3(0.0, 0.0, 10.0))
	var far_away: Node3D = _at(Vector3(0.0, 0.0, -60.0))
	lock.set("members", [ahead, right_of_it, behind, far_away])

	var locked: Array = []
	lock.connect("target_locked", func(node: Node3D) -> void: locked.append(node))

	# A 60 degree cone reaches 30 degrees each side of the forward, so the node 45 degrees off is
	# not a candidate at all and the one dead ahead is the only thing left to hold.
	lock.lock_nearest(&"enemies", 60.0, 40.0)
	all_passed = _check("the node inside the cone is held", lock.locked_target() == ahead, true) and all_passed
	all_passed = _check("and the pack says it is locked on", lock.is_locked_on(), true) and all_passed
	all_passed = _check("the distance is the real one", lock.distance_to_target(), 10.0) and all_passed
	all_passed = _check("On Target Locked fired once", locked.size(), 1) and all_passed
	lock.lock_nearest(&"enemies", 60.0, 40.0)
	all_passed = _check("searching again for the same node announces nothing new",
		locked.size(), 1) and all_passed

	# Widen the cone and the node 45 degrees off becomes a candidate - and it is nearer, so the
	# lock moves to it. The one behind and the one out of reach are still nobody.
	lock.release_lock()
	lock.lock_nearest(&"enemies", 180.0, 40.0)
	all_passed = _check("a wider cone finds the nearer node off to one side",
		lock.locked_target() == right_of_it, true) and all_passed
	all_passed = _check("the ring holds exactly the candidates, in angle order",
		_names(lock.get("_ring"), [right_of_it, ahead, behind, far_away]), "1,0") and all_passed

	# A search that finds nothing leaves the lock alone: an enemy stepping out of the cone for one
	# frame must not drop a lock that the loss check is already watching for real reasons.
	lock.set("members", [])
	lock.lock_nearest(&"enemies", 180.0, 40.0)
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
	# than 20 metres" plainly false instead of accidentally true.
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
		lock.locked_target_on_screen(), Vector2(0.0, -20.0)) and all_passed

	for node: Node3D in [ahead, right_of_it, behind, far_away]:
		node.free()
	eye.free()
	host.free()
	lock.free()
	return all_passed


## THE 3D DIFFERENCE: the cone is centred on where the CAMERA is looking, not on how the host is
## turned. Turning the camera therefore changes who can be locked while the host stands still, and
## turning the host changes nothing - which is what a third-person game means by "on screen".
## With no camera to ask, the cone falls back to the host's own forward axis, which is a turret.
static func _test_the_cone_follows_the_camera() -> bool:
	var all_passed: bool = true
	var stub: GDScript = _stub()
	if stub == null:
		return _check("the stubbed pack compiles", false, true)
	var lock: Node = stub.new()
	var host: Node3D = Node3D.new()
	var eye: Camera3D = Camera3D.new()
	lock.set("host", host)
	lock.set("eye", eye)

	# One node down -Z (in front of an unturned camera) and one down +X (in front of a camera
	# turned a quarter turn to the right). A narrow cone can only ever hold one of them.
	var down_forward: Node3D = _at(Vector3(0.0, 0.0, -10.0))
	var down_the_x_axis: Node3D = _at(Vector3(10.0, 0.0, 0.0))
	lock.set("members", [down_forward, down_the_x_axis])

	lock.lock_nearest(&"enemies", 40.0, 40.0)
	all_passed = _check("an unturned camera holds what is down its own forward",
		lock.locked_target() == down_forward, true) and all_passed

	# Turn the HOST a quarter turn and nothing moves: the host's rotation is not the cone.
	host.rotate_y(-PI * 0.5)
	lock.release_lock()
	lock.lock_nearest(&"enemies", 40.0, 40.0)
	all_passed = _check("turning the host does not move the cone",
		lock.locked_target() == down_forward, true) and all_passed

	# Turn the CAMERA the same quarter turn and the other node is the one in view.
	host.rotation = Vector3.ZERO
	eye.rotate_y(-PI * 0.5)
	lock.release_lock()
	lock.lock_nearest(&"enemies", 40.0, 40.0)
	all_passed = _check("turning the camera moves the cone with it",
		lock.locked_target() == down_the_x_axis, true) and all_passed

	# With no camera in the scene the host's own forward is the cone, which is what a turret has.
	lock.set("eye", null)
	host.rotate_y(-PI * 0.5)
	lock.release_lock()
	lock.lock_nearest(&"enemies", 40.0, 40.0)
	all_passed = _check("with no camera the host's own forward is the cone",
		lock.locked_target() == down_the_x_axis, true) and all_passed

	down_forward.free()
	down_the_x_axis.free()
	eye.free()
	host.free()
	lock.free()
	return all_passed


## Cycle Target steps along the ring the last search built, left to right by angle about the
## world's up axis, and wraps. The order is the reason cycling is predictable: it is the angle
## from the camera's forward, not whatever order the tree happened to list the group in.
static func _test_cycling_wraps() -> bool:
	var all_passed: bool = true
	var stub: GDScript = _stub()
	if stub == null:
		return _check("the stubbed pack compiles", false, true)
	var lock: Node = stub.new()
	var host: Node3D = Node3D.new()
	var eye: Camera3D = Camera3D.new()
	lock.set("host", host)
	lock.set("eye", eye)

	# Three candidates at three angles from the forward: one to the left, one dead ahead, one to
	# the right. Looking down -Z with +Y up, the -X side is the left-hand one.
	var left: Node3D = _at(Vector3(-6.0, 0.0, -6.0))
	var middle: Node3D = _at(Vector3(0.0, 0.0, -10.0))
	var right_side: Node3D = _at(Vector3(5.0, 0.0, -5.0))
	lock.set("members", [middle, right_side, left])

	lock.lock_nearest(&"enemies", 180.0, 40.0)
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
	eye.free()
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
		var host: Node3D = Node3D.new()
		var eye: Camera3D = Camera3D.new()
		lock.set("host", host)
		lock.set("eye", eye)
		var target: Node3D = _at(Vector3(0.0, 0.0, -10.0))
		lock.set("members", [target])
		var lost: Array = []
		lock.connect("target_lost", func(reason: StringName) -> void: lost.append(String(reason)))
		lock.lock_nearest(&"enemies", 360.0, 40.0)
		all_passed = _check("[%s] the target is held to begin with" % why,
			lock.is_locked_on(), true) and all_passed
		all_passed = _check("[%s] and the loss check is running" % why,
			lock.is_processing(), true) and all_passed
		match ending[1]:
			0:
				target.free()
				lock._process(0.016)
			1:
				target.position = Vector3(0.0, 0.0, -90.0)
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
		eye.free()
		host.free()
		lock.free()
	return all_passed


## LOCK ON TO KEEPS WHAT IT IS POINTED AT. The row's promise is "whatever the cone and the range
## say" - the boss a cutscene points at is routinely farther off than the lock range - and a reach
## of lock_range dropped it as out_of_range one frame after On Target Locked. What still ends it is
## everything that is not a distance: the target dying, and a wall coming between.
static func _test_a_named_lock_ignores_the_range() -> bool:
	var all_passed: bool = true
	var stub: GDScript = _stub()
	if stub == null:
		return _check("the stubbed pack compiles", false, true)
	var lock: Node = stub.new()
	var host: Node3D = Node3D.new()
	lock.set("host", host)
	lock.set("lock_range", 40.0)
	var far_away: Node3D = _at(Vector3(0.0, 0.0, -500.0))
	lock.set("members", [far_away])
	var lost: Array = []
	lock.connect("target_lost", func(reason: StringName) -> void: lost.append(String(reason)))
	lock.lock_on_to(far_away)
	all_passed = _check("a named lock holds a node past the lock range",
		lock.is_locked_on(), true) and all_passed
	lock._process(0.016)
	all_passed = _check("and the next frame does not take it away",
		lock.is_locked_on(), true) and all_passed
	all_passed = _check("nothing was lost", ",".join(PackedStringArray(lost)), "") and all_passed
	lock.set("require_line_of_sight", true)
	lock.set("clear_view", false)
	lock._process(0.016)
	all_passed = _check("a wall still ends it",
		",".join(PackedStringArray(lost)), "blocked") and all_passed
	far_away.free()
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
	var host: Node3D = Node3D.new()
	var eye: Camera3D = Camera3D.new()
	lock.set("host", host)
	lock.set("eye", eye)
	# 10 metres along the aim and 2 across it: well inside a 50 metre radius, so the aim bends.
	var near_the_aim: Node3D = _at(Vector3(2.0, 0.0, -10.0))
	lock.set("members", [near_the_aim])
	var toward: Vector3 = Vector3(2.0, 0.0, -10.0).normalized()
	var forward: Vector3 = Vector3(0.0, 0.0, -1.0)

	Engine.set_meta(RADIUS_META, 50.0)
	all_passed = _check("a strength of 0 is the direction it was handed",
		lock.assisted_aim(forward, 0.0), forward) and all_passed
	all_passed = _check("a strength of 1 points straight at the target",
		lock.assisted_aim(forward, 1.0).distance_to(toward) < 0.0001, true) and all_passed
	all_passed = _check("and half a strength bends half the angle",
		absf(forward.angle_to(lock.assisted_aim(forward, 0.5)) - forward.angle_to(toward) * 0.5) < 0.0001,
		true) and all_passed
	all_passed = _check("the length handed in is the length handed back",
		absf(lock.assisted_aim(forward * 3.0, 1.0).length() - 3.0) < 0.0001, true) and all_passed
	all_passed = _check("a strength past 1 is still just dead on",
		lock.assisted_aim(forward, 4.0).distance_to(toward) < 0.0001, true) and all_passed
	all_passed = _check("nothing to aim at is the direction it was handed",
		lock.assisted_aim(Vector3.UP, 1.0), Vector3.UP) and all_passed
	all_passed = _check("and a zero direction stays a zero direction",
		lock.assisted_aim(Vector3.ZERO, 1.0), Vector3.ZERO) and all_passed

	# The radius is measured ACROSS the aim - how far from dead centre a target still counts,
	# which is what the shipped setting's own words say.
	Engine.set_meta(RADIUS_META, 1.0)
	all_passed = _check("a target further off the ray than the radius gets no help",
		lock.assisted_aim(forward, 1.0), forward) and all_passed

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
		lock.assisted_aim(forward, 1.0), forward) and all_passed
	all_passed = _check("and leaves the turn rate alone", lock.magnetism(180.0), 180.0) and all_passed
	Engine.remove_meta(RADIUS_META)
	all_passed = _check("a setting nobody ever wrote is the same as a zero one",
		lock.assisted_aim(forward, 1.0), forward) and all_passed

	near_the_aim.free()
	eye.free()
	host.free()
	lock.free()
	return all_passed


## THE OTHER 3D DIFFERENCE: Snap On Aim Down Sights turns the host onto the target the aim is
## already nearly on, and refuses a turn wider than the row allows - so raising the sights settles
## the view instead of yanking it somewhere the player was not looking.
static func _test_snapping_on_aim_down_sights() -> bool:
	var all_passed: bool = true
	var stub: GDScript = _stub()
	if stub == null:
		return _check("the stubbed pack compiles", false, true)
	var lock: Node = stub.new()
	var host: Node3D = Node3D.new()
	var eye: Camera3D = Camera3D.new()
	lock.set("host", host)
	lock.set("eye", eye)
	# 10 metres out and 2 across: a shade over 11 degrees off the camera's forward.
	var target: Node3D = _at(Vector3(2.0, 0.0, -10.0))
	lock.set("members", [target])
	var toward: Vector3 = Vector3(2.0, 0.0, -10.0).normalized()
	Engine.set_meta(RADIUS_META, 50.0)

	# A turn narrower than the row allows is taken, and the host ends up looking at the target.
	lock.snap_on_aim_down_sights(20.0)
	all_passed = _check("a near-enough target is snapped onto",
		(-host.transform.basis.z).distance_to(toward) < 0.0001, true) and all_passed

	# A turn wider than the row allows is refused outright: the host does not move at all.
	host.transform = Transform3D.IDENTITY
	lock.snap_on_aim_down_sights(5.0)
	all_passed = _check("a turn wider than the row allows is refused",
		host.transform.basis.is_equal_approx(Basis.IDENTITY), true) and all_passed

	# With nothing near the aim there is nothing to snap onto.
	lock.set("members", [])
	lock.snap_on_aim_down_sights(20.0)
	all_passed = _check("with nothing near the aim the host stands still",
		host.transform.basis.is_equal_approx(Basis.IDENTITY), true) and all_passed

	# Straight overhead is the one direction the world's up axis cannot describe a turn toward, so
	# the snap declines rather than building one out of a reference that has collapsed.
	var straight_up: Camera3D = Camera3D.new()
	straight_up.rotate_x(PI * 0.5)
	lock.set("eye", straight_up)
	target.position = Vector3(0.0, 10.0, 0.0)
	lock.snap_on_aim_down_sights(20.0)
	all_passed = _check("a target straight overhead is declined, not turned onto badly",
		host.transform.basis.is_equal_approx(Basis.IDENTITY), true) and all_passed
	straight_up.free()
	lock.set("eye", eye)
	target.position = Vector3(2.0, 0.0, -10.0)

	# THE OFF SWITCH again: a zero radius means no target is ever near enough, so the snap that a
	# controller player relies on is the same one an options screen can turn off.
	lock.set("members", [target])
	Engine.set_meta(RADIUS_META, 0.0)
	lock.snap_on_aim_down_sights(20.0)
	all_passed = _check("a zero assist radius turns the snap off too",
		host.transform.basis.is_equal_approx(Basis.IDENTITY), true) and all_passed
	Engine.remove_meta(RADIUS_META)

	target.free()
	eye.free()
	host.free()
	lock.free()
	return all_passed


## What the pack ships as text: the two triggers, the row sentences, and the two camera lines no
## headless run can execute - the forward the cone is measured around and the projection the
## reticle reads - so they are read rather than run.
static func _test_what_the_pack_ships() -> bool:
	var all_passed: bool = true
	var shipped: String = FileAccess.get_file_as_string(PACK)
	all_passed = _check("the pack reads off disk", shipped.is_empty(), false) and all_passed
	for line: String in [
		"## @ace_name(\"On Target Locked\")",
		"## @ace_name(\"On Target Lost\")",
		"signal target_locked(target: Node3D)",
		"signal target_lost(why: StringName)",
		"return host.get_viewport().get_camera_3d()",
		"return node.global_transform if node.is_inside_tree() else node.transform",
		"return -_place_of(camera).basis.z",
		"return camera.unproject_position(world_point)",
		"Engine.get_meta(\"aim_assist_radius\", 0.0)",
	]:
		all_passed = _check("the pack ships %s" % line, shipped.contains(line), true) and all_passed
	for sentence: String in [
		"lock on to the nearest [b]{group}[/b] in a [b]{cone_degrees}[/b]° cone, [b]{max_range}[/b] out",
		"cycle to the next target",
		"release the lock",
		"snap onto a target within [b]{max_degrees}[/b]°",
	]:
		all_passed = _check("the pack ships the row sentence %s" % sentence,
			shipped.contains("## @ace_display_template(\"%s\")" % sentence), true) and all_passed
	return all_passed


## The shipped pack with its tree questions answered from fields, so this file can choose the
## group, the camera, the walls and the screen. Everything else is the pack's own bytes - the
## facing the cone is measured around included, because the camera seam hands back a real
## Camera3D and the pack reads the forward off it itself.
static func _stub() -> GDScript:
	var script: GDScript = GDScript.new()
	script.source_code = "\n".join(PackedStringArray([
		"extends \"%s\"" % PACK,
		"",
		"",
		"var members: Array = []",
		"var eye: Camera3D = null",
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
		"func _camera() -> Camera3D:",
		"\treturn eye",
		"",
		"",
		"func _view_is_clear(_from_point: Vector3, _to_point: Vector3) -> bool:",
		"\treturn clear_view if require_line_of_sight else true",
		"",
		"",
		"func _screen_point(world_point: Vector3) -> Vector2:",
		"\treturn Vector2(world_point.x, world_point.z) * 2.0",
		"",
	]))
	return script if script.reload() == OK else null


## A bare Node3D parked at a position - one candidate for the group. Its own position rather
## than its global one, because a node outside a tree has no global transform to write: the pack
## reads a node's placement through one seam that knows this, and this is the other side of it.
static func _at(where: Vector3) -> Node3D:
	var node: Node3D = Node3D.new()
	node.position = where
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
	return SUPPORT.check("targeting_3d_pack_test", label, actual, expected)
