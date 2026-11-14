# Godot EventSheets - what the Timer behavior does today, pinned before anyone changes how it counts.
#
# The pack counts down in its own `_process`. Whatever it is later built on, what a sheet sees must
# hold: the verbs and their ids, the trigger, the exported and read-only variables, what Start and
# Stop do to them, how a one-shot and a repeating clock end, how a zero or negative start behaves,
# that a stopped clock parks its processing, and the saved state's shape. Each pin is a VALUE on a
# real node, driven by calling the callback the engine would call, because the suite has no scene
# tree and no main loop to tick a real one.
@tool
class_name TimerBehaviorPinsTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const PREFIX := "timer_behavior_pins_test"
const PACK := "res://eventsheet_addons/timer/timer_behavior.gd"


static func run() -> bool:
	var rows: Array = []
	var script: GDScript = load(PACK) as GDScript
	rows.append(["the pack loads", script != null, true])
	if script == null:
		return SUPPORT.pins(PREFIX, rows)
	var source: String = FileAccess.get_file_as_string(PACK)
	# The surface a sheet addresses: names, never counts.
	for needle: String in ["signal timer_finished", "@export var duration: float = 1.0", "@export var repeating: bool = false",
			"var remaining: float = 0.0", "var running: bool = false", "func start_timer(seconds: float) -> void:",
			"func stop_timer() -> void:", "@ace_name(\"On Timer\")", "@ace_name(\"Start Timer\")",
			"@ace_name(\"Stop Timer\")", "@ace_codegen_template(\"$TimerBehavior.start_timer({seconds})\")",
			"@ace_codegen_template(\"$TimerBehavior.stop_timer()\")", "@ace_expose_all(node)"]:
		rows.append(["the pack keeps %s" % needle, source.contains(needle), true])

	# A fresh clock is stopped and costs nothing per frame.
	var clock: Node = script.new()
	rows.append(["a fresh clock is stopped", clock.get("running"), false])
	rows.append(["a fresh clock has nothing left", clock.get("remaining"), 0.0])
	rows.append(["a fresh clock lasts one second", clock.get("duration"), 1.0])
	rows.append(["a fresh clock is a one-shot", clock.get("repeating"), false])
	clock._ready()
	rows.append(["a stopped clock parks its processing", clock.is_processing(), false])

	# Start sets all three and wakes processing.
	clock.start_timer(2.0)
	rows.append(["start sets the duration", clock.get("duration"), 2.0])
	rows.append(["start sets the time left", clock.get("remaining"), 2.0])
	rows.append(["start sets running", clock.get("running"), true])
	rows.append(["start wakes processing", clock.is_processing(), true])

	# Counting down, and a one-shot ending: fires once, stops, parks.
	var fired: Array = [0]
	clock.connect("timer_finished", func() -> void: fired[0] += 1)
	clock._process(0.5)
	rows.append(["a tick takes the frame off the time left", clock.get("remaining"), 1.5])
	rows.append(["a tick short of zero does not fire", fired[0], 0])
	clock._process(1.5)
	rows.append(["reaching exactly zero fires", fired[0], 1])
	rows.append(["a fired one-shot has stopped", clock.get("running"), false])
	rows.append(["a fired one-shot parks its processing", clock.is_processing(), false])
	clock._process(1.0)
	rows.append(["a stopped clock does not fire again", fired[0], 1])

	# Overshoot is not carried: a repeating clock restarts from the full duration.
	fired[0] = 0
	clock.set("repeating", true)
	clock.start_timer(1.0)
	clock._process(1.25)
	rows.append(["a repeating clock fires on elapse", fired[0], 1])
	rows.append(["a repeating clock restarts at the full duration, dropping the overshoot", clock.get("remaining"), 1.0])
	rows.append(["a repeating clock keeps running", clock.get("running"), true])
	rows.append(["a repeating clock keeps processing", clock.is_processing(), true])

	# Stop cancels without firing, and keeps what was left.
	fired[0] = 0
	clock.start_timer(3.0)
	clock._process(1.0)
	clock.stop_timer()
	rows.append(["stop does not fire", fired[0], 0])
	rows.append(["stop clears running", clock.get("running"), false])
	rows.append(["stop keeps the seconds that were left", clock.get("remaining"), 2.0])
	rows.append(["stop parks processing", clock.is_processing(), false])

	# Restart: starting a running clock replaces its countdown.
	clock.set("repeating", false)
	clock.start_timer(5.0)
	clock._process(1.0)
	clock.start_timer(2.0)
	rows.append(["starting again restarts the countdown", clock.get("remaining"), 2.0])

	# Zero and negative lengths fire on the very next tick, once.
	fired[0] = 0
	clock.start_timer(0.0)
	clock._process(0.016)
	rows.append(["a zero-second start fires on the next tick", fired[0], 1])
	clock.start_timer(-1.0)
	clock._process(0.016)
	rows.append(["a negative start fires on the next tick", fired[0], 2])

	# Saved state: plain data, and a mid-countdown load resumes it.
	clock.start_timer(4.0)
	clock._process(1.0)
	clock.set("repeating", true)
	var saved: Dictionary = clock.save_state()
	rows.append(["the saved state names its four values", ",".join(PackedStringArray(saved.keys())), "remaining,running,duration,repeating"])
	rows.append(["the saved time left", saved.get("remaining"), 3.0])
	var restored: Node = script.new()
	restored.load_state(saved)
	rows.append(["a loaded clock has the time left", restored.get("remaining"), 3.0])
	rows.append(["a loaded mid-countdown clock is running", restored.get("running"), true])
	rows.append(["a loaded mid-countdown clock processes", restored.is_processing(), true])
	rows.append(["a loaded clock keeps repeating", restored.get("repeating"), true])
	var stopped_clone: Node = script.new()
	stopped_clone.load_state({"remaining": 0.0, "running": false, "duration": 1.0, "repeating": false})
	rows.append(["a loaded stopped clock does not process", stopped_clone.is_processing(), false])
	var untouched: Node = script.new()
	untouched.load_state({})
	rows.append(["an empty state changes nothing", untouched.get("duration"), 1.0])
	clock.free()
	restored.free()
	stopped_clone.free()
	untouched.free()
	return SUPPORT.pins(PREFIX, rows)
