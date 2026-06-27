# Godot EventSheets — Native-node ACE providers (event-sheet coverage Lane 1)
# Tween/Scene/Audio/AnimatedSprite/Camera/Label/Navigation/CanvasItem/Math vocabulary
# wrapping NATIVE Godot features (the engine maintains the implementation, we maintain
# vocabulary — the compatibility covenant's lane 1). Event-sheet names + search synonyms.
@tool
extends RefCounted
class_name NativeNodeAcesTest

static func run() -> bool:
	var all_passed: bool = true

	var by_id: Dictionary = {}
	for descriptor in EventForgeBuiltinACEs.get_descriptors():
		by_id[descriptor.ace_id] = descriptor

	# Registry coverage per provider family.
	all_passed = _check("tween provider registered", by_id.has("TweenProperty"), true) and all_passed
	all_passed = _check("scene flow registered",
		by_id.has("ChangeScene") and by_id.has("ReloadScene") and by_id.has("QuitGame") and by_id.has("SetPaused") and by_id.has("SpawnScene") and by_id.has("IsPaused"), true) and all_passed
	all_passed = _check("audio vocabulary registered",
		by_id.has("PlayAudio") and by_id.has("SetVolumeDb") and by_id.has("IsAudioPlaying"), true) and all_passed
	all_passed = _check("animated sprite vocabulary registered",
		by_id.has("PlaySpriteAnimation") and by_id.has("SetFlipH") and by_id.has("GetSpriteAnimation"), true) and all_passed
	all_passed = _check("camera/label/navigation registered",
		by_id.has("SetCameraZoom") and by_id.has("SetLabelText") and by_id.has("SetNavTarget") and by_id.has("IsNavFinished"), true) and all_passed
	all_passed = _check("visibility vocabulary registered",
		by_id.has("ShowNode") and by_id.has("SetModulate") and by_id.has("IsVisible"), true) and all_passed
	all_passed = _check("math & random registered",
		by_id.has("RandomRange") and by_id.has("Choose") and by_id.has("ClampValue") and by_id.has("DistanceTo"), true) and all_passed

	# Node-type grouping drives the picker sections.
	all_passed = _check("audio groups under its node type", str(by_id["PlayAudio"].node_type), "AudioStreamPlayer") and all_passed
	all_passed = _check("navigation groups under its node type", str(by_id["SetNavTarget"].node_type), "NavigationAgent2D") and all_passed

	# Native idioms: every template is a direct engine call (lane 1 = wrap, never clone).
	all_passed = _check("tween wraps create_tween",
		str(by_id["TweenProperty"].codegen_template).begins_with("create_tween().tween_property("), true) and all_passed
	all_passed = _check("choose is choose() over pick_random",
		str(by_id["Choose"].codegen_template), "[{values}].pick_random()") and all_passed
	all_passed = _check("sprite play uses the StringName idiom",
		str(by_id["PlaySpriteAnimation"].codegen_template).contains("play(&{anim})"), true) and all_passed

	# Compile: one event exercising tween, scene flow, label and choose.
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnReady"
	var tween: ACEAction = ACEAction.new()
	tween.provider_id = "Core"
	tween.ace_id = "TweenProperty"
	tween.codegen_template = str(by_id["TweenProperty"].codegen_template)
	tween.params = {"target": "self", "property": "\"position\"", "value": "Vector2(100, 0)", "duration": "0.5", "transition": "Tween.TRANS_SINE", "ease": "Tween.EASE_IN_OUT"}
	event.actions.append(tween)
	var spawn: ACEAction = ACEAction.new()
	spawn.provider_id = "Core"
	spawn.ace_id = "SpawnScene"
	spawn.codegen_template = str(by_id["SpawnScene"].codegen_template)
	spawn.params = {"path": "\"res://enemy.tscn\""}
	event.actions.append(spawn)
	var roll: ACEAction = ACEAction.new()
	roll.provider_id = "Core"
	roll.ace_id = "SetVar"
	roll.codegen_template = "rotation = {value}"
	roll.params = {"value": "[0.0, PI, TAU].pick_random()"}
	event.actions.append(roll)
	sheet.events.append(event)
	var output: String = str(SheetCompiler.compile(sheet, "user://eventsheets_native.gd").get("output", ""))
	all_passed = _check("tween compiles",
		output.contains("create_tween().tween_property(self, \"position\", Vector2(100, 0), 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)"), true) and all_passed
	all_passed = _check("spawn compiles", output.contains("add_child(load(\"res://enemy.tscn\").instantiate())"), true) and all_passed
	all_passed = _check("choose-style expression compiles", output.contains("[0.0, PI, TAU].pick_random()"), true) and all_passed
	var generated: GDScript = GDScript.new()
	generated.source_code = output
	all_passed = _check("native-node output parses", generated.reload(true) == OK, true) and all_passed

	# Event-sheet search synonyms reach the new vocabulary.
	var layout_queries: Array = ACEPickerDialog._c3_synonym_queries("go to layout")
	all_passed = _check("'go to layout' maps to scene", layout_queries.has("scene"), true) and all_passed
	var choose_queries: Array = ACEPickerDialog._c3_synonym_queries("choose")
	all_passed = _check("'choose' is searchable", choose_queries.has("choose"), true) and all_passed

	return all_passed

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] native_node_aces_test: %s" % label)
		return true
	print("[FAIL] native_node_aces_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
