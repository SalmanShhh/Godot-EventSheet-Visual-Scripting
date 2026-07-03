# EventForge — Core ACE runtime-safety regression guards
#
# The adversarial template audit found 9 built-in ACEs that PARSED fine but crashed, leaked, or
# misbehaved at runtime (null-deref on a failed file/focus, a leaked one-shot player, a wrong-host
# global_position, a delta that doesn't exist outside _process, defaults that no-op or error-spam).
# Each was fixed in its module; this test asserts the SHIPPED descriptor still carries the corrected
# form, so a future edit can't quietly reintroduce the hazard. Pairs with builtin_ace_compile_test
# (which proves they parse) — this proves the specific runtime guards are present.
@tool
class_name ACESafetyTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true
	var by_id: Dictionary = {}
	for d: ACEDescriptor in EventForgeBuiltinACEs.get_descriptors():
		by_id[d.ace_id] = d

	# JsonSaveFile: guard the FileAccess handle (was a null-deref crash) and close it.
	all_passed = _check("JsonSaveFile guards + closes the file handle",
		_tmpl(by_id, "JsonSaveFile").contains("if __json_") and _tmpl(by_id, "JsonSaveFile").contains(".close()"), true) and all_passed
	# FocusNext / FocusPrevious: guard the null focus result (was a null-deref crash).
	all_passed = _check("FocusNext guards a null next-focus",
		_tmpl(by_id, "FocusNext").contains("if __n_"), true) and all_passed
	all_passed = _check("FocusPrevious guards a null prev-focus",
		_tmpl(by_id, "FocusPrevious").contains("if __p_"), true) and all_passed
	# FindChildrenByPattern: pass owned=false so runtime-spawned nodes are included.
	all_passed = _check("FindChildrenByPattern searches unowned (spawned) nodes",
		_tmpl(by_id, "FindChildrenByPattern").contains(", false)"), true) and all_passed
	# Nearest / Furthest In Group: host-typed to Node2D (global_position only exists on spatial nodes).
	all_passed = _check("NearestInGroup is Node2D-hosted",
		_node_type(by_id, "NearestInGroup") == "Node2D", true) and all_passed
	all_passed = _check("FurthestInGroup is Node2D-hosted",
		_node_type(by_id, "FurthestInGroup") == "Node2D", true) and all_passed
	# EveryXSeconds: prelude uses get_process_delta_time() so it compiles under any trigger.
	all_passed = _check("EveryXSeconds prelude is trigger-agnostic",
		str(by_id["EveryXSeconds"].codegen_prelude).contains("get_process_delta_time"), true) and all_passed
	# LookAt3D: default target offset from the node's own origin (Vector3.ZERO error-spammed).
	all_passed = _check("LookAt3D default target is offset from origin",
		_param_default(by_id, "LookAt3D", "target") == "Vector3(0, 0, -1)", true) and all_passed
	# PlaySound / PlaySoundAt: free the throwaway player when the stream fails to load (was a leak).
	all_passed = _check("PlaySound frees a failed-stream player",
		_tmpl(by_id, "PlaySound").contains("if __sfx_") and _tmpl(by_id, "PlaySound").contains("== null"), true) and all_passed
	all_passed = _check("PlaySoundAt frees a failed-stream player",
		_tmpl(by_id, "PlaySoundAt").contains("if __sfx_") and _tmpl(by_id, "PlaySoundAt").contains("== null"), true) and all_passed

	return all_passed


static func _tmpl(by_id: Dictionary, ace_id: String) -> String:
	return str(by_id[ace_id].codegen_template) if by_id.has(ace_id) else ""


static func _node_type(by_id: Dictionary, ace_id: String) -> String:
	return str(by_id[ace_id].node_type) if by_id.has(ace_id) else ""


static func _param_default(by_id: Dictionary, ace_id: String, param_id: String) -> String:
	if not by_id.has(ace_id):
		return ""
	for p: ACEParam in by_id[ace_id].params:
		if p.id == param_id:
			return str(p.default_value)
	return ""


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] ace_safety_test: %s" % label)
		return true
	print("[FAIL] ace_safety_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
