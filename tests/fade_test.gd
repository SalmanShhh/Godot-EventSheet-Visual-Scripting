# Godot EventSheets - fade pack (transparency fade behavior) logic.
#
# Loads the COMPILED behavior with a bare CanvasItem host. The tween-driven fades need a running scene
# tree (create_tween) and process frames to finish, so they are felt by playing; this proves the
# synchronous, tree-free logic - Set Opacity + its clamp, the Opacity read-back, and that a fresh
# behavior reports Is Fading = false.
@tool
class_name FadeTest
extends RefCounted

const PACK := "res://eventsheet_addons/fade/fade_behavior.gd"


static func run() -> bool:
	var all_passed: bool = true
	var script: GDScript = load(PACK)
	all_passed = _check("fade pack loads + parses", script != null, true) and all_passed
	if script == null:
		return all_passed

	var fade: Node = script.new()
	var host: Node2D = Node2D.new()
	fade.host = host

	all_passed = _check("a fresh behavior is not fading", fade.is_fading(), false) and all_passed
	fade.set_opacity(0.3)
	all_passed = _check("Set Opacity sets the alpha, and Opacity reads it back", is_equal_approx(fade.opacity(), 0.3), true) and all_passed
	fade.set_opacity(2.0)
	all_passed = _check("Set Opacity clamps above 1", is_equal_approx(fade.opacity(), 1.0), true) and all_passed
	fade.set_opacity(-1.0)
	all_passed = _check("Set Opacity clamps below 0", is_equal_approx(fade.opacity(), 0.0), true) and all_passed
	all_passed = _check("Opacity is read from the host's modulate alpha", is_equal_approx(host.modulate.a, 0.0), true) and all_passed
	# Stop Fade is safe to call with nothing running.
	fade.stop_fade()
	all_passed = _check("Stop Fade with no fade running stays not-fading", fade.is_fading(), false) and all_passed

	fade.free()
	host.free()
	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] fade_test: %s" % label)
		return true
	print("[FAIL] fade_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
