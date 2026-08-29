# Godot EventSheets - proof that a stopped behavior really stops processing, run where frames exist.
#
# The behavior packs disable their per-frame callback while idle, so a stopped behavior costs
# literally nothing. That claim cannot be checked from inside the suite: `run_tests.gd` runs in
# `_init`, before the main loop exists, so nothing there ever enters a scene tree or receives a
# frame. This probe is a real SceneTree in its own process - it builds a small crowd of behaviors,
# lets two frames pass so every `_ready` gate has run, and then reads `is_processing()` /
# `is_physics_processing()` directly. The MECHANISM is asserted, never wall-clock time, so the
# probe cannot flake under load.
#
#     $GODOT --headless --path . --script tests/idle_processing_probe.gd
#
# A helper, not a test - it declares no `run` and is not named `*_test.gd`, so the suite's
# discovery never picks it up. `idle_processing_smoke_test.gd` runs it as a subprocess and reads
# the one `idle_probe checks=N fails=N` line it prints; each failed check prints its own
# `idle_probe_fail <label>` line above it so a red run says which claim broke.
@tool
extends SceneTree

## The line the smoke test parses, kept to plain `key=value` pairs on purpose.
const RESULT_PREFIX: String = "idle_probe"

## How many instances of each idle-at-start behavior the crowd holds. Enough that a pack whose
## gate silently stopped firing shows up as a crowd of ticking nodes, small enough to build fast.
const CROWD_PER_PACK: int = 30

## The behaviors this probe samples, chosen to cover both callbacks and every wiring style the
## sweep used: verb-gated (`timer`, `move_to`), effect-lifetime (`flash`), attach-lifetime on the
## physics callback (`pin`), and exported gates that start active (`sine`, `rotate`,
## `light_flicker`). Loaded by path so this file compiles even if a pack is renamed - the load
## failure then fails the probe with the path in the message.
const IDLE_AT_START: Dictionary = {
	"res://eventsheet_addons/timer/timer_behavior.gd": "Node",
	"res://eventsheet_addons/flash/flash_behavior.gd": "Sprite2D",
	"res://eventsheet_addons/move_to/move_to_behavior.gd": "Node2D",
	"res://eventsheet_addons/pin/pin_behavior.gd": "Node2D",
}

var _checks: int = 0
var _fails: int = 0


func _init() -> void:
	# Deferred rather than awaited here: an `await` inside `_init` runs before the loop exists and
	# never resumes, so the probe would hang instead of answering.
	call_deferred("_run")


func _run() -> void:
	var crowd: Array[Node] = []
	for script_path: String in IDLE_AT_START:
		for _index in CROWD_PER_PACK:
			crowd.append(_spawn(script_path, str(IDLE_AT_START[script_path])))
	var sine: Node = _spawn("res://eventsheet_addons/sine/sine_behavior.gd", "Node2D")
	var rotate: Node = _spawn("res://eventsheet_addons/rotate/rotate_behavior.gd", "Node2D")
	var flicker: Node = _spawn("res://eventsheet_addons/light_flicker/light_flicker_behavior.gd", "PointLight2D")
	# Two frames, so every `_ready` gate and every self-parking first tick has had its turn.
	await process_frame
	await process_frame

	# The crowd: every idle-at-start instance must have its callback off. Both callbacks are read
	# because the crowd mixes process packs with a physics pack, and a behavior is only free when
	# the callback it registered is the one that is off.
	var still_ticking: int = 0
	for behavior: Node in crowd:
		if behavior.is_processing() or behavior.is_physics_processing():
			still_ticking += 1
	_check("an idle-at-start crowd of %d has every callback off (%d still ticking)" % [
		crowd.size(), still_ticking], still_ticking == 0)

	# Gates that start active really are on - the sweep must not park a running behavior.
	_check("sine starts active and is processing", sine.is_processing())
	_check("rotate starts enabled and is physics processing", rotate.is_physics_processing())
	_check("light_flicker starts running and is processing", flicker.is_processing())

	# Stop verbs park the callback, and the conditions that read state keep answering while it is off.
	flicker.call("stop_flickering", 1.0)
	_check("stop_flickering parks processing", not flicker.is_processing())
	_check("Is Flickering still answers false while parked", not bool(flicker.call("is_flickering")))
	sine.call("set_sine_active", false)
	_check("set_sine_active(false) parks processing", not sine.is_processing())
	rotate.call("set_rotation_enabled", false)
	_check("set_rotation_enabled(false) parks physics processing", not rotate.is_physics_processing())

	# A raw member write on an exported gate must wake a parked behavior: the generated
	# Set-property actions compile to exactly this assignment, so the gate's setter is the wire.
	flicker.set("running", true)
	_check("writing running = true wakes a parked light_flicker", flicker.is_processing())
	sine.set("active", true)
	_check("writing active = true wakes a parked sine", sine.is_processing())

	# Start verbs wake the callback - including a delayed start, because a behavior counting a
	# delay down is waiting, and waiting is not idle.
	var timer: Node = crowd[0]
	timer.call("start_timer", 60.0)
	_check("start_timer wakes the timer", timer.is_processing())
	timer.call("stop_timer")
	_check("stop_timer parks it again", not timer.is_processing())
	flicker.call("stop_flickering", 1.0)
	flicker.call("start_flickering", 5.0)
	_check("a delayed start_flickering keeps processing on while it waits", flicker.is_processing())

	print("%s checks=%d fails=%d" % [RESULT_PREFIX, _checks, _fails])
	quit(0 if _fails == 0 else 1)


## One behavior instance under a fresh host of the class its pack expects, both in the tree.
func _spawn(script_path: String, host_class: String) -> Node:
	var script: Script = load(script_path)
	if script == null:
		_check("behavior script loads: %s" % script_path, false)
		return Node.new()
	var host: Node = ClassDB.instantiate(host_class)
	var behavior: Node = script.new()
	host.add_child(behavior)
	root.add_child(host)
	return behavior


func _check(label: String, passed: bool) -> void:
	_checks += 1
	if passed:
		return
	_fails += 1
	print("%s_fail %s" % [RESULT_PREFIX, label])
