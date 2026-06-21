# Godot EventSheets — save_system pack: truthful On Save Written + value round-trip.
#
# The pack used to fire On Save Written optimistically from _write_all (so every Save Value emitted it,
# regardless of whether the write succeeded). _write_all now returns a bool that captures the
# FileAccess / ConfigFile error, and Save Game emits On Save Written only when the write genuinely
# succeeds. This drives real user:// I/O to prove the round-trip still works and the signal is truthful.
@tool
extends RefCounted
class_name SaveSystemPackTest

const PACK := "res://eventsheet_addons/save_system/save_system_addon.gd"

static func run() -> bool:
	var all_passed: bool = true
	var script: GDScript = load(PACK)
	all_passed = _check("save_system pack loads + parses", script != null, true) and all_passed
	if script == null:
		return all_passed

	var ss: Node = script.new()
	ss.slot = 7  # a dedicated test slot so we never clobber a real save

	# Value round-trip still works.
	ss.save_value("coins", 42.0)
	all_passed = _check("a saved value reads back", ss.load_value("coins", 0.0), 42.0) and all_passed
	all_passed = _check("has_save_key sees it", ss.has_save_key("coins"), true) and all_passed

	# Save Value writes but no longer emits On Save Written; Save Game emits it ONCE, on a real write.
	var emit_count: Array = [0]
	ss.save_written.connect(func(_s: int) -> void: emit_count[0] += 1)
	ss.save_value("gems", 7.0)
	all_passed = _check("Save Value writes without emitting On Save Written", emit_count[0], 0) and all_passed
	ss.save_game()
	all_passed = _check("Save Game emits On Save Written once on a successful write", emit_count[0], 1) and all_passed

	ss.delete_slot()  # cleanup the test slot
	ss.free()
	return all_passed

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] save_system_pack_test: %s" % label)
		return true
	print("[FAIL] save_system_pack_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
