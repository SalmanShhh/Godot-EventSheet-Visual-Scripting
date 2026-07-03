@tool
class_name GlobalTriggerTest
extends RefCounted
# Triggers can connect a signal on a GLOBAL source — get_tree() ("@tree") or get_window() ("@window") —
# not just self / an autoload / a node path. This powers On Post Tick (SceneTree.process_frame, after
# every node's _process this frame), its physics sibling, and On Close Requested (the window's X). Each
# compiles to a `<global>.<signal>.connect(<handler>)` in _ready + the handler func, and round-trips
# byte-exact (lifted or, worst case, verbatim — the lossless rule holds either way).

const GDScriptImporter := preload("res://addons/eventforge/importer/gdscript_importer.gd")


static func run() -> bool:
	var all_passed: bool = true

	# On Post Tick → get_tree().process_frame
	var post_tick: String = _compile_trigger("OnPostTick")
	all_passed = _check("post-tick connects process_frame on get_tree()",
		post_tick.contains("get_tree().process_frame.connect(_on_post_tick)"), true) and all_passed
	all_passed = _check("post-tick emits its handler", post_tick.contains("func _on_post_tick()"), true) and all_passed

	# On Close Requested → get_window().close_requested
	var close_req: String = _compile_trigger("OnCloseRequested")
	all_passed = _check("close-requested connects on get_window()",
		close_req.contains("get_window().close_requested.connect(_on_close_requested)"), true) and all_passed
	all_passed = _check("close-requested emits its handler", close_req.contains("func _on_close_requested()"), true) and all_passed

	# Lossless round-trip (the byte rule holds whether the trigger lifts back or stays verbatim).
	var reopened: EventSheetResource = GDScriptImporter.new().import_external_source(post_tick)
	reopened.external_source_path = "user://_global_trigger_rt.gd"
	var recompiled: String = str(SheetCompiler.compile(reopened, "user://_global_trigger_rt.gd").get("output", ""))
	all_passed = _check("post-tick round-trips byte-identical (drift=0)", recompiled == post_tick, true) and all_passed

	return all_passed


## Compiles a one-row sheet: <trigger_id> firing a single print, returns the generated .gd.
static func _compile_trigger(trigger_id: String) -> String:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	var row: EventRow = EventRow.new()
	row.trigger_provider_id = "Core"
	row.trigger_id = trigger_id
	var act: ACEAction = ACEAction.new()
	act.provider_id = "Core"
	act.ace_id = "Print"
	act.codegen_template = "print({value})"
	act.params = {"value": "\"hi\""}
	row.actions.append(act)
	sheet.events.append(row)
	return str(SheetCompiler.compile(sheet).get("output", ""))


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] global_trigger_test: %s" % label)
		return true
	print("[FAIL] global_trigger_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
