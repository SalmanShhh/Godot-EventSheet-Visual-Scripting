# Godot EventSheets - blink patterns (the Flash pack's pattern half).
#
# A pattern is a file of phases - on for this long, off for that long, this many times - and the
# pack walks them in order. The walk is pinned BY VALUE as a trace of phase-and-visibility, one
# entry per flip, so a pattern that lost a repeat or skipped a phase says which. The accessibility
# clamp is pinned as the number it holds a part to, and the Engine meta this test sets to ask for
# it is removed again, with the ledger asserted at the end.
@tool
class_name BlinkPatternTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const PACK := "res://eventsheet_addons/flash/flash_behavior.gd"
const PATTERN := "res://eventsheet_addons/flash/blink_pattern_resource.gd"
const STARTER := "res://eventsheet_addons/flash/starter_blink_invulnerable.tres"
const PREFIX := "blink_pattern_test"
const NO_FLASHING := "no_flashing"


static func run() -> bool:
	var script: GDScript = load(PACK)
	var pattern_script: GDScript = load(PATTERN)
	if script == null or pattern_script == null:
		return SUPPORT.check(PREFIX, "the flash pack and the pattern resource load", false, true)
	var all_passed: bool = true
	all_passed = _the_walk(script, pattern_script) and all_passed
	all_passed = _stopping(script, pattern_script) and all_passed
	all_passed = _the_flashing_clamp(script, pattern_script) and all_passed
	all_passed = _the_starter() and all_passed
	all_passed = SUPPORT.check(PREFIX, "the meta this test asked for is gone again",
		Engine.has_meta(NO_FLASHING), false) and all_passed
	return all_passed


## Two phases, walked one flip at a time: three winks of the first, one of the second, and then the
## host handed back whole. Stepping by exactly the timer plus a hair makes each call one flip, so
## the trace is the pattern rather than a frame rate.
static func _the_walk(script: GDScript, pattern_script: GDScript) -> bool:
	var behavior: Node = script.new()
	var host: Node2D = Node2D.new()
	behavior.host = host
	var pattern: Resource = pattern_script.new()
	var phases: Array[Dictionary] = [
		{"on": 0.1, "off": 0.1, "count": 2},
		{"on": 0.2, "off": 0.2, "count": 1},
	]
	pattern.phases = phases
	behavior.blink(pattern, 0.0)
	var trace: PackedStringArray = PackedStringArray([_state(behavior, host)])
	for _flip: int in 6:
		behavior._blink_step(float(behavior.blink_timer) + 0.001)
		trace.append(_state(behavior, host))
	var passed: bool = SUPPORT.pins(PREFIX, [
		["the pattern walks its phases in order", " ".join(trace), "1+ 1- 1+ 1- 2+ 2- 0+"],
		["a finished blink is not blinking", behavior.is_blinking(), false],
		["a finished blink hands the host back", host.visible, true],
		["and at full opacity", snappedf(host.modulate.a, 0.01), 1.0],
		["Blink Phase is 0 when nothing blinks", behavior.blink_phase(), 0],
	])
	behavior.free()
	host.free()
	return passed


## Stop Blink ends it wherever it had got to, and hands the host back visible.
static func _stopping(script: GDScript, pattern_script: GDScript) -> bool:
	var behavior: Node = script.new()
	var host: Node2D = Node2D.new()
	behavior.host = host
	var pattern: Resource = pattern_script.new()
	var phases: Array[Dictionary] = [{"on": 0.1, "off": 0.1, "count": 8}]
	pattern.phases = phases
	behavior.blink(pattern, 0.0)
	behavior._blink_step(float(behavior.blink_timer) + 0.001)
	var hidden_mid_pattern: bool = not host.visible
	behavior.stop_blink()
	var passed: bool = SUPPORT.pins(PREFIX, [
		["a blink hides the host between winks", hidden_mid_pattern, true],
		["Stop Blink ends it", behavior.is_blinking(), false],
		["Stop Blink hands the host back", host.visible, true],
		["a pattern with no phases never starts", _blinks_on_nothing(script, pattern_script), false],
	])
	behavior.free()
	host.free()
	return passed


## A player who has asked for no flashing gets the same pattern, held to the floor and faded rather
## than hidden. The meta is the project's own, so it is set here and taken away again.
static func _the_flashing_clamp(script: GDScript, pattern_script: GDScript) -> bool:
	var behavior: Node = script.new()
	var host: Node2D = Node2D.new()
	behavior.host = host
	var pattern: Resource = pattern_script.new()
	var phases: Array[Dictionary] = [{"on": 0.05, "off": 0.05, "count": 4}]
	pattern.phases = phases
	var free_rate: float = float(behavior._blink_hold(0.05))
	Engine.set_meta(NO_FLASHING, true)
	var held_rate: float = float(behavior._blink_hold(0.05))
	behavior.blink(pattern, 0.0)
	var first_part: float = float(behavior.blink_timer)
	behavior._blink_step(float(behavior.blink_timer) + 0.001)
	var still_seen: bool = host.visible
	# A colour channel is a float32, so the faint step is pinned in hundredths rather than compared
	# against a double that is one bit away from it.
	var faded: int = int(roundf(host.modulate.a * 100.0))
	Engine.remove_meta(NO_FLASHING)
	var passed: bool = SUPPORT.pins(PREFIX, [
		["a part is as short as the file says", snappedf(free_rate, 0.001), 0.05],
		["no flashing holds a part to the floor", snappedf(held_rate, 0.001), 0.4],
		["and the blink starts at that floor", snappedf(first_part, 0.001), 0.4],
		["the host is never taken off the screen", still_seen, true],
		["it steps between full and faint instead", faded, 35],
	])
	behavior.free()
	host.free()
	return passed


## The starter that ships beside the pack: an ordinary file with phases a game can read and retune.
static func _the_starter() -> bool:
	var starter: Resource = load(STARTER)
	if starter == null:
		return SUPPORT.check(PREFIX, "the starter pattern loads", false, true)
	var phases: Array = starter.get("phases")
	var first: Dictionary = phases[0] if not phases.is_empty() else {}
	return SUPPORT.pins(PREFIX, [
		["the starter is named", str(starter.get("pattern_name")), "Invulnerable"],
		["it opens with fast winks", snappedf(float(first.get("on", 0.0)), 0.01), 0.08],
		["it repeats them", int(first.get("count", 0)), 6],
		["it slows down after that", phases.size(), 2],
	])


## Whether a pattern holding no phases at all starts anything (it must not).
static func _blinks_on_nothing(script: GDScript, pattern_script: GDScript) -> bool:
	var behavior: Node = script.new()
	var host: Node2D = Node2D.new()
	behavior.host = host
	var empty: Resource = pattern_script.new()
	behavior.blink(empty, 0.0)
	var blinking: bool = behavior.is_blinking()
	behavior.free()
	host.free()
	return blinking


## One entry of the walk's trace: which phase is playing, and whether the host can be seen.
static func _state(behavior: Node, host: Node2D) -> String:
	return "%d%s" % [behavior.blink_phase(), "+" if host.visible else "-"]
