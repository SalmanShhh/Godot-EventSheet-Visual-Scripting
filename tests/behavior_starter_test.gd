# Godot EventSheets — Behavior Component starter (architecture steering by example).
#
# The bundled gameplay starters (Platformer, Top-down…) are monolithic host sheets that poll every
# physics frame — they teach the Construct god-sheet habit by example. This new starter models the
# Godot way instead: a small reusable BEHAVIOR you attach as a child (compiles to a Node with a typed
# `host` accessor), that REACTS to the host's body_entered signal (no per-frame polling) and EMITS its
# own. This verifies the starter is exactly that shape and compiles to valid GDScript.
@tool
extends RefCounted
class_name BehaviorStarterTest

static func run() -> bool:
	var all_passed: bool = true
	var sheet: EventSheetResource = EventSheetDock._build_behavior_component_starter()

	# Shape: a behavior component with a typed host and an EXPORTED designer knob.
	all_passed = _check("starter is a behavior component (not a god-sheet)", sheet.behavior_mode, true) and all_passed
	all_passed = _check("starter declares its required host class", sheet.host_class, "Area2D") and all_passed
	all_passed = _check("value is an exported designer knob", bool((sheet.variables.get("value", {}) as Dictionary).get("exported", false)), true) and all_passed

	var output: String = str(SheetCompiler.compile(sheet, "user://__behavior_starter.gd").get("output", ""))
	all_passed = _check("compiles to an attachable Node (the component idiom)", output.contains("extends Node"), true) and all_passed
	all_passed = _check("exposes the typed host accessor (its parent)", output.contains("var host: Area2D"), true) and all_passed
	all_passed = _check("REACTS to the host's signal", output.contains("host.body_entered.connect"), true) and all_passed
	all_passed = _check("does NOT poll every frame (the anti-idiom)", output.contains("_physics_process"), false) and all_passed
	all_passed = _check("emits its own decoupling signal", output.contains("signal collected"), true) and all_passed

	var generated: GDScript = GDScript.new()
	generated.source_code = output
	all_passed = _check("the starter compiles to valid GDScript", generated.reload(true) == OK, true) and all_passed

	return all_passed

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] behavior_starter_test: %s" % label)
		return true
	print("[FAIL] behavior_starter_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
