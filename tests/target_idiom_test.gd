# Godot EventSheets — Optional {target.} idiom + node-scoped ACE retargeting.
#
# Node-scoped ACEs (Set Modulate, Set Volume, Play, …) used to act only on the host. They now carry an
# optional "On node" target via the {target.} optional-prefix idiom: blank = the host (output is
# byte-identical to before — the covenant), set = act on another node ($Enemy.modulate = …). This
# verifies the idiom substitution, that the post-pass added the target to a real node-scoped ACE (and
# correctly SKIPPED a non-prefixable one), the blank-target covenant, retargeting, and that BOTH shapes
# round-trip through import (the lifter expands {target.} into its two reverse forms).
@tool
class_name TargetIdiomTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true

	# 1. The idiom itself: {target.} emits "<value>." only when set; optional-comma and plain unaffected.
	all_passed = _check("blank target (absent) drops the prefix", ActionCodegen._apply_template("{target.}play()", {}), "play()") and all_passed
	all_passed = _check("blank target (empty) drops the prefix", ActionCodegen._apply_template("{target.}play()", {"target": ""}), "play()") and all_passed
	all_passed = _check("set target prefixes the call", ActionCodegen._apply_template("{target.}play()", {"target": "$Enemy"}), "$Enemy.play()") and all_passed
	all_passed = _check("self target prefixes too", ActionCodegen._apply_template("{target.}volume_db = {db}", {"target": "self", "db": "-6.0"}), "self.volume_db = -6.0") and all_passed
	all_passed = _check("optional-comma still drops when empty", ActionCodegen._apply_template("emit({a}{, b})", {"a": "1", "b": ""}), "emit(1)") and all_passed
	all_passed = _check("optional-comma still joins when set", ActionCodegen._apply_template("emit({a}{, b})", {"a": "1", "b": "2"}), "emit(1, 2)") and all_passed
	all_passed = _check("plain placeholders still substitute", ActionCodegen._apply_template("{x} + {y}", {"x": "a", "y": "b"}), "a + b") and all_passed

	# 2. The post-pass added an optional target to a real node-scoped ACE, and the template now leads
	#    with {target.} so a blank value vanishes.
	var modulate: ACEDescriptor = ACERegistry.find_descriptor("Core", "SetModulate")
	all_passed = _check("SetModulate exists", modulate != null, true) and all_passed
	if modulate != null:
		all_passed = _check("SetModulate gained an 'On node' target", _has_param(modulate, "target"), true) and all_passed
		all_passed = _check("SetModulate template leads with {target.}", str(modulate.codegen_template).begins_with("{target.}"), true) and all_passed
		all_passed = _check("the target defaults to blank (host)", _param_default(modulate, "target"), "") and all_passed
		all_passed = _check("the target uses the expression field (so it gets the node picker)", _param_hint(modulate, "target"), "expression") and all_passed

	# 3. The non-prefixable spawn-a-node ACE was correctly left host-only (no target param).
	var play_at: ACEDescriptor = ACERegistry.find_descriptor("Core", "PlaySoundAt")
	all_passed = _check("PlaySoundAt stays host-only (not retargetable)", play_at != null and not _has_param(play_at, "target"), true) and all_passed

	# 4. Covenant: a blank target compiles to the exact host call (unchanged from before the idiom).
	all_passed = _check("blank target compiles to the host form", _compile_modulate(""), "\tmodulate = Color.RED") and all_passed
	# 5. Retargeting: a set target redirects the whole assignment to that node.
	all_passed = _check("set target redirects the assignment", _compile_modulate("$Sprite"), "\t$Sprite.modulate = Color.RED") and all_passed

	# 6. Round-trip: both shapes survive import. Blank-target output lifts back with no target; a
	#    set-target output lifts back with the node captured. Each recompiles byte-identically.
	all_passed = _roundtrip("", all_passed)
	all_passed = _roundtrip("$Sprite", all_passed)

	return all_passed


## Compiles a one-action OnReady sheet (Set Modulate to Color.RED) with the given target and returns the
## single emitted statement line (with its leading body tab), so the exact codegen can be asserted.
static func _compile_modulate(target: String) -> String:
	var source: String = _compile_modulate_source(target)
	for line: String in source.split("\n"):
		if line.strip_edges().begins_with("modulate") or line.strip_edges().contains(".modulate"):
			return line
	return "(modulate line not found)"


static func _compile_modulate_source(target: String) -> String:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnReady"
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "SetModulate"
	action.params = {"color": "Color.RED"} if target.is_empty() else {"color": "Color.RED", "target": target}
	event.actions.append(action)
	sheet.events.append(event)
	return str(SheetCompiler.compile(sheet, "user://__target_idiom_compiled.gd").get("output", ""))


## Author → compile → import → assert the action lifts back to SetModulate with the right target, then
## recompile and confirm the byte-identical round-trip (the lifter's two-form {target.} expansion).
static func _roundtrip(target: String, running: bool) -> bool:
	var source: String = _compile_modulate_source(target)
	var imported: EventSheetResource = GDScriptImporter.new().import_external_source(source)
	var lifted: ACEAction = null
	for row: Variant in imported.events:
		if row is EventRow:
			for entry: Variant in (row as EventRow).actions:
				if entry is ACEAction:
					lifted = entry
	var label: String = "host" if target.is_empty() else "node"
	running = _check("[%s] action lifts back to SetModulate" % label, lifted != null and lifted.ace_id == "SetModulate", true) and running
	if lifted != null:
		var lifted_target: String = str(lifted.params.get("target", ""))
		running = _check("[%s] target round-trips" % label, lifted_target, target) and running
	imported.external_source_path = "user://__target_idiom_roundtrip.gd"
	var roundtrip: String = str(SheetCompiler.compile(imported, "user://__target_idiom_roundtrip.gd").get("output", ""))
	running = _check("[%s] lifted sheet recompiles byte-identically" % label, roundtrip == source, true) and running
	return running


static func _has_param(descriptor: ACEDescriptor, param_id: String) -> bool:
	for param: ACEParam in descriptor.params:
		if str(param.id) == param_id:
			return true
	return false


static func _param_default(descriptor: ACEDescriptor, param_id: String) -> String:
	for param: ACEParam in descriptor.params:
		if str(param.id) == param_id:
			return str(param.default_value)
	return "(missing)"


static func _param_hint(descriptor: ACEDescriptor, param_id: String) -> String:
	for param: ACEParam in descriptor.params:
		if str(param.id) == param_id:
			return str(param.hint)
	return "(missing)"


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] target_idiom_test: %s" % label)
		return true
	print("[FAIL] target_idiom_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
