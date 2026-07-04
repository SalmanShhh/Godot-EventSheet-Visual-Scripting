# Godot EventSheets - spring pack (typed inner classes) behavioral equivalence.
#
# The spring pack was reworked from per-frame float()-cast Dictionary entries to typed inner classes
# (SpringEntry / ColorSpringEntry with an integrate(delta) method). This loads the COMPILED pack and
# drives the real integrator to prove (a) the inner classes emit + parse inside a single-file pack, and
# (b) the spring still settles to its target with zero residual velocity - i.e. behavior is unchanged.
@tool
class_name SpringPackTest
extends RefCounted

const PACK := "res://eventsheet_addons/spring/spring_behavior.gd"


static func run() -> bool:
	var all_passed: bool = true
	var script: GDScript = load(PACK)
	all_passed = _check("spring pack loads + parses (inner classes emit cleanly)", script != null, true) and all_passed
	if script == null:
		return all_passed

	var behavior: Node = script.new()
	# Numeric spring: starts springing, settles AT the target, stops, zero residual velocity.
	# Precision is ABSOLUTE (0.01), so a small target keeps the settle time well inside the loop budget.
	behavior.spring_to("test", 1.0)
	all_passed = _check("a sprung value is springing", behavior.is_springing("test"), true) and all_passed
	for _i in 2000:
		behavior._process(0.016)
		if not behavior.is_springing("test"):
			break
	all_passed = _check("the spring settles at the target", is_equal_approx(behavior.spring_value("test"), 1.0), true) and all_passed
	all_passed = _check("the spring stops once settled", behavior.is_springing("test"), false) and all_passed
	all_passed = _check("residual velocity is zero at rest", is_zero_approx(behavior.spring_velocity("test")), true) and all_passed

	# Snap + remove (no motion).
	behavior.set_spring("snap", 42.0)
	all_passed = _check("set_spring snaps without motion", behavior.spring_value("snap"), 42.0) and all_passed
	behavior.remove_spring("snap")
	all_passed = _check("remove deletes the spring", behavior.spring_value("snap"), 0.0) and all_passed

	# Colour spring settles component-wise.
	behavior.set_color("flash", Color.WHITE)
	behavior.spring_color("flash", Color.RED)
	for _j in 2000:
		behavior._process(0.016)
	all_passed = _check("a colour spring settles to its target", behavior.color_value("flash").is_equal_approx(Color.RED), true) and all_passed

	behavior.free()
	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] spring_pack_test: %s" % label)
		return true
	print("[FAIL] spring_pack_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
