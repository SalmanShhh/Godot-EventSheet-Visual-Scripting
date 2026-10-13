# Godot EventSheets - the Flock pack and its 3D twin (separation, alignment and cohesion over a
# group's members within a radius).
#
# Each rule is pinned ALONE first, as the one velocity a single step produces: switch the other two
# weights off, place one neighbour, step a tenth of a second, and the arithmetic has exactly one
# answer. That is what tells a designer what a weight of 1.5 actually does, and it is what breaks
# the day somebody "tidies" the steering into something that merely looks similar. Then the rules
# are run together over a dozen members for ten seconds, which is the promise the pack is for: they
# stay one flock and none of them sits on top of another.
#
# Everything drives the COMPILED pack and steps it by hand: a headless run has no main loop, so
# nothing in this file waits for a frame. The one question the pack needs a scene tree for - who is
# in a group - goes through one small function of its own, and the stub below answers it from a
# table this file writes.
@tool
class_name FlockPackTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const PACK := "res://eventsheet_addons/flock/flock_behavior.gd"
const PACK_3D := "res://eventsheet_addons/flock_3d/flock_3d_behavior.gd"
const STEP := 0.1


static func run() -> bool:
	var stub: GDScript = _stub(PACK)
	var stub_3d: GDScript = _stub(PACK_3D)
	var all_passed: bool = _check("the stubbed pack compiles", stub != null, true)
	all_passed = _check("the stubbed 3D pack compiles", stub_3d != null, true) and all_passed
	if stub == null or stub_3d == null:
		return false
	all_passed = _test_each_rule_alone(stub) and all_passed
	all_passed = _test_the_radii_and_the_avoid_group(stub) and all_passed
	all_passed = _test_the_limits(stub) and all_passed
	all_passed = _test_moving_and_facing(stub) and all_passed
	all_passed = _test_the_set_rows(stub) and all_passed
	all_passed = _test_a_flock_stays_together(stub) and all_passed
	all_passed = _test_the_3d_twin(stub_3d) and all_passed
	all_passed = _test_what_the_packs_ship() and all_passed
	all_passed = _test_the_familiar_names() and all_passed
	return all_passed


## Separation, alignment and cohesion, one at a time. With min speed at zero a member at rest stays
## at rest unless a rule moves it, so every velocity below is that rule's own push and nothing else.
static func _test_each_rule_alone(stub: GDScript) -> bool:
	var all_passed: bool = true
	var made: Array = []
	# Separation: a neighbour 10 px to the right, inside the 40 px "too close" circle. The member
	# wants to fly straight away from it at full speed (180), which is a change of 180 - inside the
	# max force of 360 - times the weight of 1.5, over a tenth of a second: 27 px/s to the left.
	var alone: Node = _member(stub, Vector2.ZERO, Vector2.ZERO, made)
	_member(stub, Vector2(10.0, 0.0), Vector2.ZERO, made)
	alone.set_flock_weights(1.5, 0.0, 0.0)
	_set_group(stub, &"flock", made)
	all_passed = _check("separation pushes straight away from a neighbour that is too close",
		_step(alone).round(), Vector2(-27.0, 0.0)) and all_passed
	_free(made)

	# Alignment: a neighbour 50 px off (outside the too-close circle) flying down at 100 px/s. The
	# member turns to fly the same way at full speed: 180 down, over a tenth of a second, 18 px/s.
	alone = _member(stub, Vector2.ZERO, Vector2.ZERO, made)
	_member(stub, Vector2(50.0, 0.0), Vector2(0.0, 100.0), made)
	alone.set_flock_weights(0.0, 1.0, 0.0)
	_set_group(stub, &"flock", made)
	all_passed = _check("alignment turns a member the way its neighbour is flying",
		_step(alone).round(), Vector2(0.0, 18.0)) and all_passed
	_free(made)

	# Cohesion: two neighbours at (100, -30) and (100, 30) have their middle at (100, 0), so the
	# member heads straight right for it, at full speed: 18 px/s after a tenth of a second.
	alone = _member(stub, Vector2.ZERO, Vector2.ZERO, made)
	_member(stub, Vector2(100.0, -30.0), Vector2.ZERO, made)
	_member(stub, Vector2(100.0, 30.0), Vector2.ZERO, made)
	alone.set_flock_weights(0.0, 0.0, 1.0)
	_set_group(stub, &"flock", made)
	all_passed = _check("cohesion draws a member toward the middle of its neighbours",
		_step(alone).round(), Vector2(18.0, 0.0)) and all_passed
	_free(made)

	# A neighbour that is the member's own host is not a neighbour: a member alone in its group
	# does nothing at all, whatever the weights say.
	alone = _member(stub, Vector2.ZERO, Vector2.ZERO, made)
	_set_group(stub, &"flock", made)
	all_passed = _check("a member alone in its group is not steered by itself",
		_step(alone), Vector2.ZERO) and all_passed
	_free(made)

	# Two members on exactly the same spot cannot push along the line between them - there is none -
	# so each leaves along an angle of its own, and they part instead of sticking.
	var first: Node = _member(stub, Vector2.ZERO, Vector2.ZERO, made)
	var second: Node = _member(stub, Vector2.ZERO, Vector2.ZERO, made)
	_set_group(stub, &"flock", made)
	first.set_flock_weights(1.0, 0.0, 0.0)
	second.set_flock_weights(1.0, 0.0, 0.0)
	var first_way: Vector2 = _step(first)
	var second_way: Vector2 = _step(second)
	all_passed = _check("two members on one spot both move", [
		first_way.is_zero_approx(), second_way.is_zero_approx()], [false, false]) and all_passed
	all_passed = _check("and they leave in different directions",
		first_way.normalized().is_equal_approx(second_way.normalized()), false) and all_passed
	_free(made)

	# Which two members share an angle must not hang on how many objects the process made before
	# them: 361 members on one spot are 361 different ways out, which no 360-step dial can give.
	var ways: Dictionary = {}
	for index: int in 361:
		var member: Node = stub.new()
		ways[member._away_from_the_same_spot()] = true
		member.free()
	all_passed = _check("361 members on one spot leave along 361 angles", ways.size(), 361) and all_passed
	return all_passed


## The neighbour radius decides who counts at all, and the avoid group is fled on top of the three
## rules, harder the closer it comes.
static func _test_the_radii_and_the_avoid_group(stub: GDScript) -> bool:
	var all_passed: bool = true
	var made: Array = []
	# 130 px is past the 120 px neighbour radius, so that neighbour is nobody.
	var alone: Node = _member(stub, Vector2.ZERO, Vector2.ZERO, made)
	_member(stub, Vector2(130.0, 0.0), Vector2(0.0, 100.0), made)
	_set_group(stub, &"flock", made)
	all_passed = _check("a member past the neighbour radius is ignored",
		_step(alone), Vector2.ZERO) and all_passed
	alone.set_flock_radii(140.0, 40.0)
	all_passed = _check("widening the radius brings it in",
		_step(alone).is_zero_approx(), false) and all_passed
	_free(made)

	# A threat 80 px to the right, inside the 160 px avoid radius, is fled at full speed: 180 to the
	# left times the avoid weight of 3, over a tenth of a second.
	alone = _member(stub, Vector2.ZERO, Vector2.ZERO, made)
	var threat: Node2D = Node2D.new()
	threat.position = Vector2(80.0, 0.0)
	_set_group(stub, &"flock", made)
	_set_group(stub, &"hawks", [threat])
	all_passed = _check("with no avoid group nothing is fled", _step(alone), Vector2.ZERO) and all_passed
	alone.set_avoid_group(&"hawks", 160.0, 3.0)
	all_passed = _check("the avoid group is fled, at its own weight",
		_step(alone).round(), Vector2(-54.0, 0.0)) and all_passed
	alone.set_avoid_group(&"hawks", 60.0, 3.0)
	all_passed = _check("a threat outside the avoid radius is not fled",
		_step(alone), Vector2.ZERO) and all_passed
	threat.free()
	_free(made)
	return all_passed


## Max force caps how much one rule may change the velocity per second; the two speeds clamp the
## result, and the Set row refuses to let them cross.
static func _test_the_limits(stub: GDScript) -> bool:
	var all_passed: bool = true
	var made: Array = []
	var alone: Node = _member(stub, Vector2.ZERO, Vector2.ZERO, made)
	_member(stub, Vector2(10.0, 0.0), Vector2.ZERO, made)
	_set_group(stub, &"flock", made)
	alone.set_flock_weights(1.0, 0.0, 0.0)
	alone.set_max_force(100.0)
	all_passed = _check("max force caps the push",
		_step(alone).round(), Vector2(-10.0, 0.0)) and all_passed

	alone.set("flock_velocity", Vector2(500.0, 0.0))
	alone.set_flock_weights(0.0, 0.0, 0.0)
	all_passed = _check("nothing flies faster than the max speed",
		_step(alone).round(), Vector2(180.0, 0.0)) and all_passed
	alone.set_flock_speeds(60.0, 180.0)
	alone.set("flock_velocity", Vector2(0.0, 5.0))
	all_passed = _check("and nothing that is moving flies slower than the min speed",
		_step(alone).round(), Vector2(0.0, 60.0)) and all_passed
	alone.set_flock_speeds(50.0, 20.0)
	all_passed = _check("a max speed below the min speed is raised to it",
		[alone.get("min_speed"), alone.get("max_speed")], [50.0, 50.0]) and all_passed
	alone.set_flock_speeds(-5.0, 10.0)
	all_passed = _check("a negative min speed is read as standing still",
		alone.get("min_speed"), 0.0) and all_passed
	_free(made)
	return all_passed


## One physics step moves a plain Node2D host along its velocity and turns it to face its flight;
## with flocking off it does neither.
static func _test_moving_and_facing(stub: GDScript) -> bool:
	var all_passed: bool = true
	var made: Array = []
	var alone: Node = _member(stub, Vector2(10.0, 20.0), Vector2(0.0, 100.0), made)
	_set_group(stub, &"flock", made)
	alone.set_flock_speeds(0.0, 180.0)
	alone._physics_process(0.5)
	var host: Node2D = alone.get("host")
	all_passed = _check("a step moves the host along its velocity",
		host.position.round(), Vector2(10.0, 70.0)) and all_passed
	all_passed = _check("and turns it to face the way it flies",
		snappedf(host.rotation, 0.001), snappedf(PI / 2.0, 0.001)) and all_passed
	alone.set_flocking_enabled(false)
	alone._physics_process(0.5)
	all_passed = _check("with flocking off the host stays where it was",
		host.position.round(), Vector2(10.0, 70.0)) and all_passed
	alone.set("face_heading", false)
	alone.set_flocking_enabled(true)
	alone.set("flock_velocity", Vector2(100.0, 0.0))
	alone._physics_process(0.5)
	all_passed = _check("with Face Heading off the host moves without turning",
		[host.position.round(), snappedf(host.rotation, 0.001)],
		[Vector2(60.0, 70.0), snappedf(PI / 2.0, 0.001)]) and all_passed
	_free(made)
	return all_passed


## The Set rows write what their names say, and Set Flock Group moves the host between groups in
## one step, so it is never in both.
static func _test_the_set_rows(stub: GDScript) -> bool:
	var all_passed: bool = true
	var made: Array = []
	var alone: Node = _member(stub, Vector2.ZERO, Vector2.ZERO, made)
	var host: Node2D = alone.get("host")
	host.add_to_group(&"flock")
	alone.set_flock_weights(2.0, 0.5, 0.25)
	alone.set_max_force(-3.0)
	alone.set_flock_radii(90.0, 30.0)
	alone.set_avoid_group(&"cats", 70.0, 4.0)
	alone.set_flock_group(&"starlings")
	all_passed = SUPPORT.pins("flock_pack_test", [
		["Set Flock Weights writes the three weights",
			[alone.get("separation_weight"), alone.get("alignment_weight"), alone.get("cohesion_weight")],
			[2.0, 0.5, 0.25]],
		["Set Max Force refuses a negative force", alone.get("max_force"), 0.0],
		["Set Flock Radii writes both radii",
			[alone.get("neighbour_radius"), alone.get("separation_radius")], [90.0, 30.0]],
		["Set Avoid Group writes the group, the radius and the weight",
			[alone.get("avoid_group"), alone.get("avoid_radius"), alone.get("avoid_weight")],
			[&"cats", 70.0, 4.0]],
		["Set Flock Group names the new group", alone.get("flock_group"), &"starlings"],
		["and the host leaves the old flock and joins the new one",
			[host.is_in_group(&"flock"), host.is_in_group(&"starlings")], [false, true]],
	]) and all_passed
	alone.set_flock_group(&"")
	all_passed = _check("an empty flock group leaves the host in no flock",
		host.is_in_group(&"starlings"), false) and all_passed
	_free(made)
	return all_passed


## THE PROMISE: a dozen members started in a tight block, all facing different ways, flown with the
## shipped defaults for ten seconds, end as one flock - every member within reach of the middle -
## and no two closer than a sprite's width. Started closer than the too-close radius, so separation
## has to do real work to get there.
static func _test_a_flock_stays_together(stub: GDScript) -> bool:
	var all_passed: bool = true
	var made: Array = []
	for index: int in 12:
		var at: Vector2 = Vector2(float(index % 4) * 18.0, float(index / 4) * 18.0)
		var heading: Vector2 = Vector2.RIGHT.rotated(float(index) * 0.7) * 60.0
		var member: Node = _member(stub, at, heading, made)
		member.set_flock_speeds(60.0, 180.0)
	_set_group(stub, &"flock", made)
	for frame: int in 600:
		for member: Node in made:
			member._physics_process(1.0 / 60.0)
	var places: Array[Vector2] = []
	var middle: Vector2 = Vector2.ZERO
	for member: Node in made:
		var place: Vector2 = (member.get("host") as Node2D).position
		places.append(place)
		middle += place / float(made.size())
	var closest: float = INF
	var farthest: float = 0.0
	for a: int in places.size():
		farthest = maxf(farthest, places[a].distance_to(middle))
		for b: int in range(a + 1, places.size()):
			closest = minf(closest, places[a].distance_to(places[b]))
	all_passed = _check("after ten seconds every member is within 120 px of the flock's middle",
		farthest < 120.0, true) and all_passed
	all_passed = _check("and no two members are closer than 20 px", closest > 20.0, true) and all_passed
	_free(made)
	return all_passed


## The 3D twin answers the same arithmetic in metres, looks along its flight instead of rotating in
## the plane, and moves a host that is outside the scene tree by its own position.
static func _test_the_3d_twin(stub: GDScript) -> bool:
	var all_passed: bool = true
	var made: Array = []
	# Separation in metres: a neighbour 0.5 m along +X, inside the 1.2 m too-close sphere. Full speed
	# (6) away, inside the max force of 12, times 1.5, over a tenth of a second: 0.9 m/s along -X.
	var alone: Node = _member_3d(stub, Vector3.ZERO, Vector3.ZERO, made)
	_member_3d(stub, Vector3(0.5, 0.0, 0.0), Vector3.ZERO, made)
	alone.set_flock_weights(1.5, 0.0, 0.0)
	_set_group(stub, &"flock", made)
	all_passed = _check("3D separation pushes straight away, in metres",
		(_step(alone) as Vector3).snapped(Vector3(0.01, 0.01, 0.01)), Vector3(-0.9, 0.0, 0.0)) and all_passed
	_free(made)

	alone = _member_3d(stub, Vector3.ZERO, Vector3(0.0, 0.0, 4.0), made)
	_set_group(stub, &"flock", made)
	alone._physics_process(0.5)
	var host: Node3D = alone.get("host")
	all_passed = _check("a 3D step moves a host outside the tree by its own position",
		host.position.snapped(Vector3(0.01, 0.01, 0.01)), Vector3(0.0, 0.0, 2.0)) and all_passed
	all_passed = _check("and turns it to look along its flight (forward is -Z)",
		(-host.basis.z).snapped(Vector3(0.01, 0.01, 0.01)), Vector3(0.0, 0.0, 1.0)) and all_passed
	alone.set("flock_velocity", Vector3(0.0, 4.0, 0.0))
	alone._physics_process(0.5)
	all_passed = _check("flying straight up keeps the facing it had",
		(-host.basis.z).snapped(Vector3(0.01, 0.01, 0.01)), Vector3(0.0, 0.0, 1.0)) and all_passed
	_free(made)
	return all_passed


## The packs ship the verbs and the sentences the guide promises, under the frozen spellings a sheet
## writes into its own file the moment a row is dropped.
static func _test_what_the_packs_ship() -> bool:
	var all_passed: bool = true
	for pair: Array in [[PACK, "FlockBehavior", "px/s"], [PACK_3D, "Flock3DBehavior", "m/s"]]:
		var shipped: String = FileAccess.get_file_as_string(str(pair[0]))
		var owner: String = str(pair[1])
		all_passed = _check("%s reads off disk" % owner, shipped.is_empty(), false) and all_passed
		for line: String in [
			"## @ace_codegen_template(\"$%s.set_flock_weights({separation}, {alignment}, {cohesion})\")" % owner,
			"## @ace_codegen_template(\"$%s.set_flock_speeds({minimum}, {maximum})\")" % owner,
			"## @ace_codegen_template(\"$%s.set_max_force({force})\")" % owner,
			"## @ace_codegen_template(\"$%s.set_flock_radii({neighbours}, {too_close})\")" % owner,
			"## @ace_codegen_template(\"$%s.set_avoid_group({group}, {radius}, {weight})\")" % owner,
			"## @ace_codegen_template(\"$%s.set_flock_group({group})\")" % owner,
			"## @ace_codegen_template(\"$%s.set_flocking_enabled({enabled})\")" % owner,
			"## @ace_display_template(\"flock with separation [b]{separation}[/b], alignment [b]{alignment}[/b], cohesion [b]{cohesion}[/b]\")",
			"## @ace_display_template(\"fly between [b]{minimum}[/b] and [b]{maximum}[/b] %s\")" % str(pair[2]),
			"## @ace_display_template(\"steer with at most [b]{force}[/b] force\")",
			"## @ace_display_template(\"see neighbours within [b]{neighbours}[/b], keep [b]{too_close}[/b] apart\")",
			"## @ace_display_template(\"flee [b]{group}[/b] within [b]{radius}[/b], weight [b]{weight}[/b]\")",
			"## @ace_display_template(\"fly with the [b]{group}[/b] flock\")",
			"## @ace_display_template(\"Set flocking to [b]{enabled}[/b]\")",
		]:
			all_passed = _check("%s ships %s" % [owner, line], shipped.contains(line), true) and all_passed
	return all_passed


## The words a reader who moved from another engine types for this: the action browser's own
## category name for it, and the name the technique goes by. Each finds the weights row, which is
## where a flock is tuned, and says the typed name back beside it; the two names for the whole
## technique find the other Set rows too.
static func _test_the_familiar_names() -> bool:
	var all_passed: bool = true
	for typed: String in ["Boids", "Flocking", "Separation Alignment Cohesion"]:
		var found: Dictionary = ACEPickerDialog.foreign_query_matches(typed)
		all_passed = _check("'%s' finds the flock weights row" % typed,
			found.get("method:set_flock_weights", ""), typed) and all_passed
	var named: Array = ACEPickerDialog.foreign_query_matches("Boids").keys()
	named.sort()
	all_passed = _check("'Boids' finds the four rows that tune a flock", named, [
		"method:set_avoid_group", "method:set_flock_radii", "method:set_flock_speeds",
		"method:set_flock_weights"]) and all_passed
	return all_passed


## One member: a host at a place, with the pack attached under it and flying at a velocity. The
## host is set by hand because a node outside the tree never runs _enter_tree. Min speed starts at
## zero so a member at rest stays at rest unless a rule moves it.
static func _member(stub: GDScript, at: Vector2, velocity: Vector2, made: Array) -> Node:
	var host: Node2D = Node2D.new()
	host.position = at
	var behaviour: Node = stub.new()
	host.add_child(behaviour)
	behaviour.set("host", host)
	behaviour.set("flock_velocity", velocity)
	behaviour.set("min_speed", 0.0)
	made.append(behaviour)
	return behaviour


static func _member_3d(stub: GDScript, at: Vector3, velocity: Vector3, made: Array) -> Node:
	var host: Node3D = Node3D.new()
	host.position = at
	var behaviour: Node = stub.new()
	host.add_child(behaviour)
	behaviour.set("host", host)
	behaviour.set("flock_velocity", velocity)
	behaviour.set("min_speed", 0.0)
	made.append(behaviour)
	return behaviour


## The velocity one tenth-of-a-second step would give, without moving anything.
static func _step(behaviour: Node) -> Variant:
	return behaviour.call("_next_velocity", STEP)


## Puts the hosts of these members (or these plain nodes) into a group, as the stub answers it.
static func _set_group(stub: GDScript, group: StringName, members: Array) -> void:
	var hosts: Array = []
	for member: Node in members:
		var host: Variant = member.get("host") if member.get_script() == stub else member
		hosts.append(host if host != null else member)
	stub.call("put_in_group", group, hosts)


static func _free(made: Array) -> void:
	for behaviour: Node in made:
		var host: Node = behaviour.get_parent()
		if host != null:
			host.free()
		else:
			behaviour.free()
	made.clear()


## The shipped pack with its one tree question answered from a table this file writes. Everything
## else is the pack's own bytes.
static func _stub(pack_path: String) -> GDScript:
	var script: GDScript = GDScript.new()
	script.source_code = "\n".join(PackedStringArray([
		"extends \"%s\"" % pack_path,
		"",
		"",
		"static var groups: Dictionary = {}",
		"",
		"",
		"static func put_in_group(group: StringName, members: Array) -> void:",
		"\tgroups[group] = members",
		"",
		"",
		"func _group_members(group: StringName) -> Array:",
		"\treturn groups.get(group, [])",
		"",
	]))
	if script.reload() != OK:
		return null
	return script


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("flock_pack_test", label, actual, expected)
