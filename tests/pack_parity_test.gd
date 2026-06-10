# Godot EventSheets — C3 capability parity for the behavior packs
# The packs match their C3 counterparts' surfaces: Sine waves/movements, Orbit ellipses,
# Bullet distance, Move To waypoint queues, Follow delayed mode, Drag axes, Car drift,
# Tile Movement simulate/grid helpers, LOS cone + between-positions. Functional checks
# run on real instantiated behaviors (no host needed for the pure parts).
@tool
extends RefCounted
class_name PackParityTest

static func run() -> bool:
	var all_passed: bool = true

	# Sine: wave shapes are real functions; movement/wave are Inspector combos.
	var sine_source: String = FileAccess.get_file_as_string("res://eventsheet_addons/sine/sine_behavior.gd")
	all_passed = _check("sine movement is a combo of the C3 set",
		sine_source.contains("@export_enum(\"horizontal\", \"vertical\", \"forwards-backwards\", \"size\", \"angle\", \"opacity\", \"value-only\") var movement"), true) and all_passed
	all_passed = _check("sine wave types are a combo",
		sine_source.contains("@export_enum(\"sine\", \"triangle\", \"sawtooth\", \"reverse-sawtooth\", \"square\") var wave"), true) and all_passed
	var sine = (load("res://eventsheet_addons/sine/sine_behavior.gd") as GDScript).new()
	sine.wave = "sine"
	all_passed = _check("sine wave peaks at quarter period", absf(float(sine._wave(0.25)) - 1.0) < 0.001, true) and all_passed
	sine.wave = "triangle"
	all_passed = _check("triangle wave peaks mid-cycle", absf(float(sine._wave(0.5)) - 1.0) < 0.001, true) and all_passed
	sine.wave = "square"
	all_passed = _check("square wave flips halves", float(sine._wave(0.25)) == 1.0 and float(sine._wave(0.75)) == -1.0, true) and all_passed
	sine.wave = "sawtooth"
	all_passed = _check("sawtooth ramps", absf(float(sine._wave(0.75)) - 0.5) < 0.001, true) and all_passed
	sine.free()

	# Orbit: ellipse + rotation matching surface.
	var orbit = (load("res://eventsheet_addons/orbit/orbit_behavior.gd") as GDScript).new()
	all_passed = _check("orbit supports ellipses + match rotation",
		"secondary_radius" in orbit and "match_rotation" in orbit and "total_rotation" in orbit, true) and all_passed
	orbit.free()

	# Bullet: distance travelled + enable toggle.
	var bullet = (load("res://eventsheet_addons/bullet/bullet_behavior.gd") as GDScript).new()
	all_passed = _check("bullet tracks distance and can be disabled",
		"distance_travelled" in bullet and "enabled_movement" in bullet, true) and all_passed
	bullet.free()

	# Move To: waypoint queue semantics.
	var mover = (load("res://eventsheet_addons/move_to/move_to_behavior.gd") as GDScript).new()
	mover.move_to_position(10.0, 0.0)
	mover.add_waypoint(20.0, 0.0)
	all_passed = _check("move-to queues waypoints", (mover.waypoints as Array).size(), 2) and all_passed
	mover.stop_moving()
	all_passed = _check("stop clears the queue", (mover.waypoints as Array).is_empty() and not bool(mover.moving), true) and all_passed
	mover.free()

	# Follow: delayed (history) mode exists alongside smooth.
	var follow_source: String = FileAccess.get_file_as_string("res://eventsheet_addons/follow/follow_behavior.gd")
	all_passed = _check("follow has smooth + delayed modes",
		follow_source.contains("@export_enum(\"smooth\", \"delayed\") var mode") and follow_source.contains("history.append"), true) and all_passed

	# Drag & Drop: axis locking combo.
	all_passed = _check("drag axes combo",
		FileAccess.get_file_as_string("res://eventsheet_addons/drag_drop/drag_drop_behavior.gd").contains("@export_enum(\"both\", \"horizontal\", \"vertical\") var axes"), true) and all_passed

	# Car: drift + turn-while-stopped.
	var car = (load("res://eventsheet_addons/car/car_behavior.gd") as GDScript).new()
	all_passed = _check("car supports drift + stationary steering",
		"drift_recover" in car and "turn_while_stopped" in car, true) and all_passed
	car.free()

	# Tile Movement: simulate control + grid-space helpers.
	var tiles = (load("res://eventsheet_addons/tile_movement/tile_movement_behavior.gd") as GDScript).new()
	tiles.tile_size = 64.0
	all_passed = _check("grid helpers convert both ways",
		tiles.to_grid(Vector2(128.0, 64.0)) == Vector2i(2, 1) and tiles.from_grid(Vector2i(2, 1)) == Vector2(128.0, 64.0), true) and all_passed
	tiles.simulate_step("left")
	all_passed = _check("simulate step queues a direction", float(tiles.pending_x), -1.0) and all_passed
	tiles.free()

	# LOS: cone of view + between-positions condition (host-less calls fail safe).
	var los = (load("res://eventsheet_addons/line_of_sight/line_of_sight_behavior.gd") as GDScript).new()
	all_passed = _check("LOS has a cone of view", "cone_of_view_degrees" in los, true) and all_passed
	all_passed = _check("LOS between-positions exists and fails safe without a host",
		los.has_los_between(Vector2.ZERO, Vector2.RIGHT), false) and all_passed
	los.free()

	return all_passed

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] pack_parity_test: %s" % label)
		return true
	print("[FAIL] pack_parity_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
