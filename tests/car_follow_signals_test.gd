# Godot EventSheets — car + follow discrete transition signals (behavior-pack quality fix).
#
# The behavior-fit assessment found car and follow each missing a discrete transition trigger (they
# only exposed continuous state). Car now edge-fires On Drift Started / On Drift Recovered; follow
# edge-fires On Reached Target at the min_distance boundary. follow's `following` flag was also a stray
# @export designer knob — it's internal state driven by Start/Stop Following, so it's now un-exported.
# Full motion needs a live host + physics, so this asserts the signals compiled in + the export flip.
@tool
class_name CarFollowSignalsTest
extends RefCounted

const CAR := "res://eventsheet_addons/car/car_behavior.gd"
const FOLLOW := "res://eventsheet_addons/follow/follow_behavior.gd"


static func run() -> bool:
	var all_passed: bool = true

	var car: GDScript = load(CAR)
	all_passed = _check("car pack loads + parses", car != null, true) and all_passed
	if car != null:
		var c: Node = car.new()
		all_passed = _check("car edge-fires On Drift Started + On Drift Recovered", c.has_signal("drift_started") and c.has_signal("drift_recovered"), true) and all_passed
		c.free()

	var follow: GDScript = load(FOLLOW)
	all_passed = _check("follow pack loads + parses", follow != null, true) and all_passed
	if follow != null:
		var f: Node = follow.new()
		all_passed = _check("follow edge-fires On Reached Target", f.has_signal("reached_target"), true) and all_passed
		f.free()

	# `following` is now internal state (driven by Start/Stop Following), not an exported designer knob.
	var follow_src: String = FileAccess.get_file_as_string(FOLLOW)
	all_passed = _check("follow keeps a 'following' state var", follow_src.contains("var following"), true) and all_passed
	all_passed = _check("'following' is no longer @export", not follow_src.contains("@export var following"), true) and all_passed

	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] car_follow_signals_test: %s" % label)
		return true
	print("[FAIL] car_follow_signals_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
