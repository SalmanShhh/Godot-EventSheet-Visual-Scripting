# Godot EventSheets - "by node type" picking ACEs (the node-heavy-object answer).
#
# Godot objects are deep node trees (a player can be dozens of nodes). Reaching "the AnimationPlayer of
# this object" used to need a brittle path ($A/B/C/D) or a GDScript block. These ACEs resolve a child by
# CLASS anywhere in the subtree, so you target it by type instead - no path, no code. This pins their
# registration + that they compile to the right find_children() call (incl. param substitution).
@tool
class_name NodeTypeAcesTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true

	var by_id: Dictionary = {}
	for descriptor: Variant in EventForgeNodeACEs.get_descriptors():
		if descriptor is ACEDescriptor:
			by_id[(descriptor as ACEDescriptor).ace_id] = descriptor

	# All three register under Nodes: Picking, with the expected ACE type.
	all_passed = _check("Find Children Of Type is an EXPRESSION under Nodes: Picking",
		_is(by_id, "FindChildrenOfType", ACEDescriptor.ACEType.EXPRESSION), true) and all_passed
	all_passed = _check("First Child Of Type is an EXPRESSION under Nodes: Picking",
		_is(by_id, "FirstChildOfType", ACEDescriptor.ACEType.EXPRESSION), true) and all_passed
	all_passed = _check("Has Child Of Type is a CONDITION under Nodes: Picking",
		_is(by_id, "HasChildOfType", ACEDescriptor.ACEType.CONDITION), true) and all_passed

	# First Child Of Type uses pop_front() so an empty subtree is null-safe (no runtime error).
	if by_id.has("FirstChildOfType"):
		all_passed = _check("First Child Of Type is null-safe on empty (pop_front)",
			(by_id["FirstChildOfType"] as ACEDescriptor).codegen_template.contains(".pop_front()"), true) and all_passed

	# End-to-end: an action built from the descriptor template + params compiles to the resolved call,
	# proving {target}/{type} substitution works (the whole point - target "the Area2D of $Player").
	if by_id.has("FindChildrenOfType"):
		var sheet: EventSheetResource = EventSheetResource.new()
		sheet.host_class = "Node2D"
		var event: EventRow = EventRow.new()
		event.trigger_provider_id = "Core"
		event.trigger_id = "OnReady"
		var action: ACEAction = ACEAction.new()
		action.provider_id = "Core"
		action.ace_id = "FindChildrenOfType"
		action.codegen_template = (by_id["FindChildrenOfType"] as ACEDescriptor).codegen_template
		action.params = {"target": "$Player", "type": "\"Area2D\""}
		event.actions.append(action)
		sheet.events.append(event)
		var output: String = str(SheetCompiler.compile(sheet, "user://node_type_aces.gd").get("output", ""))
		all_passed = _check("resolves to a typed find_children call (target + type substituted)",
			output.contains("$Player.find_children(\"*\", \"Area2D\", true, false)"), true) and all_passed

	# ── Object-level animation verbs: act on the OBJECT, auto-resolve its player (no path / no block) ──
	for anim_id: String in ["PlayAnimationInObject", "StopAnimationInObject", "PlaySpriteAnimationInObject", "IsObjectAnimating"]:
		all_passed = _check("%s registered under Animation" % anim_id,
			by_id.has(anim_id) and (by_id[anim_id] as ACEDescriptor).category == "Animation", true) and all_passed

	# Play Animation (in object) compiles to a null-guarded, typed auto-resolve that plays - and PARSES
	# (the multi-line {uid} template, baked here as the dock bakes it per row).
	if by_id.has("PlayAnimationInObject"):
		var anim_sheet: EventSheetResource = EventSheetResource.new()
		anim_sheet.host_class = "Node2D"
		var anim_event: EventRow = EventRow.new()
		anim_event.trigger_provider_id = "Core"
		anim_event.trigger_id = "OnReady"
		var anim_action: ACEAction = ACEAction.new()
		anim_action.provider_id = "Core"
		anim_action.ace_id = "PlayAnimationInObject"
		anim_action.codegen_template = (by_id["PlayAnimationInObject"] as ACEDescriptor).codegen_template.replace("{uid}", "t0")
		anim_action.params = {"target": "$Player", "anim": "\"walk\""}
		anim_event.actions.append(anim_action)
		anim_sheet.events.append(anim_event)
		var anim_out: String = str(SheetCompiler.compile(anim_sheet, "user://anim_in_object.gd").get("output", ""))
		all_passed = _check("Play Animation (in object) auto-resolves the AnimationPlayer, guards null, and plays",
			anim_out.contains("find_children(\"*\", \"AnimationPlayer\", true, false).pop_front() as AnimationPlayer") \
			and anim_out.contains("if __ap_t0:") and anim_out.contains("__ap_t0.play(&\"walk\")"), true) and all_passed
		var anim_script: GDScript = GDScript.new()
		anim_script.source_code = anim_out
		all_passed = _check("Play Animation (in object) output parses as GDScript", anim_script.reload() == OK, true) and all_passed

	# ── More object verbs (flip / frame / restart / particles) register; restart's 2-statement guarded
	# body is the riskiest multi-line - compile + parse it. ──
	for verb_id: String in ["FlipSpriteInObject", "SetSpriteFrameInObject", "RestartAnimationInObject", "EmitParticlesInObject"]:
		all_passed = _check("%s registered" % verb_id, by_id.has(verb_id), true) and all_passed
	if by_id.has("RestartAnimationInObject"):
		var r_sheet: EventSheetResource = EventSheetResource.new()
		r_sheet.host_class = "Node2D"
		var r_event: EventRow = EventRow.new()
		r_event.trigger_provider_id = "Core"
		r_event.trigger_id = "OnReady"
		var r_action: ACEAction = ACEAction.new()
		r_action.provider_id = "Core"
		r_action.ace_id = "RestartAnimationInObject"
		r_action.codegen_template = (by_id["RestartAnimationInObject"] as ACEDescriptor).codegen_template.replace("{uid}", "r1")
		r_action.params = {"target": "self", "anim": "\"run\""}
		r_event.actions.append(r_action)
		r_sheet.events.append(r_event)
		var r_out: String = str(SheetCompiler.compile(r_sheet, "user://restart_anim.gd").get("output", ""))
		all_passed = _check("Restart Animation (in object) stops then plays under a null guard",
			r_out.contains("if __ap_r1:") and r_out.contains("__ap_r1.stop()") and r_out.contains("__ap_r1.play(&\"run\")"), true) and all_passed
		var r_script: GDScript = GDScript.new()
		r_script.source_code = r_out
		all_passed = _check("Restart Animation (in object) output parses as GDScript", r_script.reload() == OK, true) and all_passed

	return all_passed


static func _is(by_id: Dictionary, ace_id: String, ace_type: int) -> bool:
	if not by_id.has(ace_id):
		return false
	var descriptor: ACEDescriptor = by_id[ace_id] as ACEDescriptor
	return descriptor.ace_type == ace_type and descriptor.category == "Nodes: Picking" \
		and descriptor.codegen_template.contains("find_children(\"*\", {type}, true, false)")


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] node_type_aces_test: %s" % label)
		return true
	print("[FAIL] node_type_aces_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
