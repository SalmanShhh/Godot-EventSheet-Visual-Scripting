# EventForge — behaviour-building physics + input + typed-local vocabulary.
# Pins the codegen templates of the new Movement ACEs, that they
# host-target inside a behaviour (and stay bare on a normal sheet), plus the input-axis consumer
# and the typed local. Compiles each ACE through ActionCodegen, which is what the sheet compiler
# calls — so a wrong template or a missing param surfaces here before it reaches generated code.
@tool
extends RefCounted
class_name PhysicsAcesTest

static func run() -> bool:
	var ok: bool = true

	# Component velocity setters host-target inside a behaviour.
	ok = _emit("SetVelocityX", {"x": "200.0"}, "host", "host.velocity.x = 200.0") and ok
	ok = _emit("SetVelocityY", {"y": "-400.0"}, "host", "host.velocity.y = -400.0") and ok
	ok = _emit("AddVelocity", {"delta_v": "Vector2(0, 10)"}, "host", "host.velocity += Vector2(0, 10)") and ok
	# …and stay bare on a normal CharacterBody2D sheet (byte-stable).
	ok = _emit("SetVelocityX", {"x": "0.0"}, "", "velocity.x = 0.0") and ok

	# Gravity bakes the terminal-velocity clamp (one row replaces a 2-line RawCode idiom).
	ok = _emit("ApplyGravity", {"gravity": "980.0", "max_fall": "1000.0", "delta_t": "delta"}, "host",
		"host.velocity.y = minf(host.velocity.y + 980.0 * delta, 1000.0)") and ok
	ok = _emit("ApplyGravitySimple", {"gravity": "980.0", "delta_t": "delta"}, "host",
		"host.velocity.y += 980.0 * delta") and ok

	# Accelerate-toward (move_toward on a velocity component); target_speed must not collide with {target.}.
	ok = _emit("AccelerateVelocityX", {"target_speed": "ts", "rate": "1500.0", "delta_t": "delta"}, "host",
		"host.velocity.x = move_toward(host.velocity.x, ts, 1500.0 * delta)") and ok
	ok = _emit("AccelerateVelocityY", {"target_speed": "0.0", "rate": "1500.0", "delta_t": "delta"}, "host",
		"host.velocity.y = move_toward(host.velocity.y, 0.0, 1500.0 * delta)") and ok

	# Component reads.
	ok = _emit("GetVelocityX", {}, "host", "host.velocity.x") and ok
	ok = _emit("GetVelocityY", {}, "", "velocity.y") and ok

	# Input consumer emits a typed float local; typed local emits its declared type.
	ok = _emit("SetLocalFromAxis", {"name": "direction", "negative": "\"ui_left\"", "positive": "\"ui_right\""}, "",
		"var direction: float = Input.get_axis(&\"ui_left\", &\"ui_right\")") and ok
	ok = _emit("SetLocalVarTyped", {"name": "spd", "var_type": "float", "value": "move_speed"}, "",
		"var spd: float = move_speed") and ok

	return ok

# Compiles ace_id with params and the given host_default through the action codegen (template
# resolution is shared by actions and expressions), then checks the emitted line.
static func _emit(ace_id: String, params: Dictionary, host: String, expected: String) -> bool:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	action.enabled = true
	action.params = params
	return _check(ace_id, ActionCodegen.generate_action(action, "", host), expected)

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] physics_aces_test: %s" % label)
		return true
	print("[FAIL] physics_aces_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
