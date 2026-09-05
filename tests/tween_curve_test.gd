# Godot EventSheets - any property along a curve the game owns (the Tween pack's curve half).
#
# Four readings of one curve, the memory that makes Tween Property Back exact, and the awaiting
# row. The readings are pinned BY VALUE at three points along the curve, because that is the whole
# of what a mode means; the memory is pinned by the number it kept. A tween itself needs a live
# scene tree, which a test here does not have - so the row records where the property was and then
# declines, which is exactly what it does for a host that has not entered the tree yet either.
@tool
class_name TweenCurveTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const COMPILER := preload("res://addons/eventforge/compiler/sheet_compiler.gd")
const DOCTOR := preload("res://addons/eventforge/project_doctor.gd")
const PACK := "res://eventsheet_addons/tween/tween_behavior.gd"
const OVERSHOOT := "res://eventsheet_addons/tween/starter_curve_overshoot.tres"
const FLARE := "res://eventsheet_addons/tween/starter_curve_flare.tres"
const PREFIX := "tween_curve_test"


static func run() -> bool:
	var script: GDScript = load(PACK)
	if script == null:
		return SUPPORT.check(PREFIX, "the tween pack loads", false, true)
	var all_passed: bool = true
	all_passed = _the_four_readings(script) and all_passed
	all_passed = _the_way_home(script) and all_passed
	all_passed = _the_awaiting_row() and all_passed
	all_passed = _the_starter_curves() and all_passed
	return all_passed


## What each mode means, at the start, the middle and the end of the curve. A property sitting at 2
## with a final value of 10: relative adds, to destination travels, remap ignores both ends and
## reads its own pair, absolute lets the curve be the value.
static func _the_four_readings(script: GDScript) -> bool:
	var behavior: Node = script.new()
	var passed: bool = SUPPORT.pins(PREFIX, [
		["relative at the start", behavior._along_value(2.0, 0.0, 10.0, "relative", 0.0, 4.0), 2.0],
		["relative half way", behavior._along_value(2.0, 0.5, 10.0, "relative", 0.0, 4.0), 7.0],
		["relative at the end", behavior._along_value(2.0, 1.0, 10.0, "relative", 0.0, 4.0), 12.0],
		["to destination at the start", behavior._along_value(2.0, 0.0, 10.0, "to destination", 0.0, 4.0), 2.0],
		["to destination half way", behavior._along_value(2.0, 0.5, 10.0, "to destination", 0.0, 4.0), 6.0],
		["to destination at the end", behavior._along_value(2.0, 1.0, 10.0, "to destination", 0.0, 4.0), 10.0],
		["remap at the start", behavior._along_value(2.0, 0.0, 10.0, "remap", 1.0, 5.0), 1.0],
		["remap half way", behavior._along_value(2.0, 0.5, 10.0, "remap", 1.0, 5.0), 3.0],
		["remap at the end", behavior._along_value(2.0, 1.0, 10.0, "remap", 1.0, 5.0), 5.0],
		["absolute is the curve, scaled", behavior._along_value(2.0, 0.5, 10.0, "absolute", 0.0, 4.0), 5.0],
		["an unknown word reads as absolute", behavior._along_value(2.0, 0.5, 10.0, "", 0.0, 4.0), 5.0],
	])
	behavior.free()
	return passed


## Where a property was before the FIRST curve tween touched it - the number Tween Property Back
## returns to, however many tweens have run since.
static func _the_way_home(script: GDScript) -> bool:
	var behavior: Node = script.new()
	var host: Node2D = Node2D.new()
	behavior.host = host
	var curve: Curve = load(OVERSHOOT)
	host.rotation_degrees = 12.0
	var first: Variant = behavior._tween_along("rotation_degrees", 90.0, 0.4, curve, "relative", 0.0, 0.0)
	var remembered: float = float(behavior._tween_starts.get("rotation_degrees", -1.0))
	host.rotation_degrees = 40.0
	behavior._tween_along("rotation_degrees", 90.0, 0.4, curve, "relative", 0.0, 0.0)
	var still: float = float(behavior._tween_starts.get("rotation_degrees", -1.0))
	behavior.tween_back("modulate:a", 0.3)
	var passed: bool = SUPPORT.pins(PREFIX, [
		["a tween outside the tree declines", first, null],
		["the first value is remembered", remembered, 12.0],
		["a second tween does not overwrite it", still, 12.0],
		["a property with no memory is left alone", snappedf(host.modulate.a, 0.001), 1.0],
	])
	behavior.free()
	host.free()
	return passed


## The awaiting row is a coroutine everywhere the project asks: in the compiler's list, in the
## Doctor's, and in the template the pack ships - which is what makes the rows under it wait.
static func _the_awaiting_row() -> bool:
	var emitted: String = FileAccess.get_file_as_string(PACK)
	return SUPPORT.pins(PREFIX, [
		["the compiler counts it a coroutine", COMPILER._COROUTINE_ACE_IDS.has("tween_along_and_wait"), true],
		["the Doctor counts it a coroutine", DOCTOR.COROUTINE_ACE_IDS.has("tween_along_and_wait"), true],
		["the shipped template awaits", emitted.contains("await $TweenBehavior.tween_along_and_wait("), true],
		["the word is quoted in the template, not in the key",
			emitted.contains("{seconds}, {curve}, \"{mode}\", {from_value}"), true],
	])


## The two curves that ship beside the pack are starters, and a starter has to be worth starting
## from: one overshoots and comes back, one flares and falls away.
static func _the_starter_curves() -> bool:
	var overshoot: Curve = load(OVERSHOOT)
	var flare: Curve = load(FLARE)
	if overshoot == null or flare == null:
		return SUPPORT.check(PREFIX, "both starter curves load", false, true)
	return SUPPORT.pins(PREFIX, [
		["overshoot starts at nothing", snappedf(overshoot.sample(0.0), 0.01), 0.0],
		["overshoot passes its target", overshoot.sample(0.55) > 1.0, true],
		["overshoot ends on it", snappedf(overshoot.sample(1.0), 0.01), 1.0],
		["flare is up before it is half over", flare.sample(0.2) > flare.sample(0.6), true],
		["flare falls back to nothing", snappedf(flare.sample(1.0), 0.01), 0.0],
	])
