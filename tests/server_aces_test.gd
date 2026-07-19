# EventForge - the Audio Server + Physics Server modules: bus mixing / effect toggles /
# metering and world-gravity / space-pause / profiling vocabulary compile to plain server
# calls that parse standalone, with buses addressed by name and world-scoped physics calls
# targeting the current viewport's world.
@tool
class_name ServerAcesTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true

	var by_id: Dictionary = {}
	for descriptor in EventForgeBuiltinACEs.get_descriptors():
		by_id[descriptor.ace_id] = descriptor
	all_passed = _check("audio server ACEs registered",
		by_id.has("AudioSetBusMuted") and by_id.has("AudioSetBusEffectEnabled")
		and by_id.has("AudioSetPlaybackSpeed") and by_id.has("AudioBusExists")
		and by_id.has("AudioBusPeakDb") and by_id.has("AudioOutputLatency"), true) and all_passed
	all_passed = _check("physics server ACEs registered (both dimensions)",
		by_id.has("PhysicsSetGravity2D") and by_id.has("PhysicsSetGravityVector3D")
		and by_id.has("PhysicsSetSpaceActive2D") and by_id.has("PhysicsActiveObjects3D")
		and by_id.has("PhysicsInterpolationFraction"), true) and all_passed

	# Compile a sheet exercising bus-by-name resolution, the effect toggle, playback speed,
	# both worlds' gravity, and a profiling read - plain server calls, parsing standalone.
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	sheet.variables = {"bodies": {"type": "int", "default": 0, "exported": false}}
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnReady"
	var gate: ACECondition = ACECondition.new()
	gate.provider_id = "Core"
	gate.ace_id = "AudioBusExists"
	gate.codegen_template = str(by_id["AudioBusExists"].codegen_template)
	gate.params = {"bus": "\"Music\""}
	event.conditions.append(gate)
	event.actions.append(_action(by_id, "AudioSetBusMuted", {"bus": "\"Music\"", "muted": "true"}))
	event.actions.append(_action(by_id, "AudioSetBusEffectEnabled", {"bus": "\"Master\"", "effect_index": "0", "enabled": "true"}))
	event.actions.append(_action(by_id, "AudioSetPlaybackSpeed", {"scale": "0.5"}))
	event.actions.append(_action(by_id, "PhysicsSetGravity2D", {"gravity": "490.0"}))
	event.actions.append(_action(by_id, "PhysicsSetGravityVector3D", {"direction": "Vector3.UP"}))
	event.actions.append(_action(by_id, "SetVar", {"var_name": "bodies", "value": str(by_id["PhysicsActiveObjects2D"].codegen_template)}))
	sheet.events.append(event)
	var output: String = str(SheetCompiler.compile(sheet, "user://server_aces.gd").get("output", ""))
	all_passed = _check("buses resolve by NAME at the call",
		output.contains("AudioServer.set_bus_mute(AudioServer.get_bus_index(\"Music\"), true)"), true) and all_passed
	all_passed = _check("the effect toggle compiles bus + slot + state",
		output.contains("AudioServer.set_bus_effect_enabled(AudioServer.get_bus_index(\"Master\"), 0, true)"), true) and all_passed
	all_passed = _check("playback speed is a plain assignment",
		output.contains("AudioServer.playback_speed_scale = 0.5"), true) and all_passed
	all_passed = _check("2D gravity targets the current world's space",
		output.contains("PhysicsServer2D.area_set_param(get_viewport().find_world_2d().space, PhysicsServer2D.AREA_PARAM_GRAVITY, 490.0)"), true) and all_passed
	all_passed = _check("3D gravity direction mirrors it",
		output.contains("PhysicsServer3D.area_set_param(get_viewport().find_world_3d().space, PhysicsServer3D.AREA_PARAM_GRAVITY_VECTOR, Vector3.UP)"), true) and all_passed
	all_passed = _check("the profiling expression feeds a variable",
		output.contains("bodies = PhysicsServer2D.get_process_info(PhysicsServer2D.INFO_ACTIVE_OBJECTS)"), true) and all_passed
	var generated: GDScript = GDScript.new()
	generated.source_code = output
	all_passed = _check("server output parses standalone", generated.reload(true) == OK, true) and all_passed

	# Every remaining template's constants/methods must resolve too - parse them all in one probe.
	var probe_lines: PackedStringArray = PackedStringArray(["extends Node", "func probe() -> void:"])
	for ace_id: String in ["AudioSetBusSolo", "AudioSetBusBypass", "AudioIsBusEffectEnabled", "AudioBusPeakDb", "AudioBusCount", "AudioOutputLatency", "PhysicsSetSpaceActive2D", "PhysicsSetSpaceActive3D", "PhysicsSetGravity3D", "PhysicsSetGravityVector2D", "PhysicsCollisionPairs2D", "PhysicsIslands2D", "PhysicsCollisionPairs3D", "PhysicsIslands3D", "PhysicsInterpolationFraction"]:
		var template: String = str((by_id[ace_id] as ACEDescriptor).codegen_template)
		for parameter: ACEParam in (by_id[ace_id] as ACEDescriptor).params:
			template = template.replace("{%s}" % parameter.id, str(parameter.default_value) if str(parameter.default_value) != "" else "0")
		# Every template in the list is a call, so a bare expression STATEMENT parses for
		# actions (void) and expressions alike - assigning would break on the void calls.
		probe_lines.append("\t%s" % template)
	var probe: GDScript = GDScript.new()
	probe.source_code = "\n".join(probe_lines)
	all_passed = _check("every server template's constants resolve", probe.reload(true) == OK, true) and all_passed

	return all_passed


static func _action(by_id: Dictionary, ace_id: String, params: Dictionary) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	action.codegen_template = str((by_id[ace_id] as ACEDescriptor).codegen_template)
	action.params = params
	return action


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] server_aces_test: %s" % label)
		return true
	print("[FAIL] server_aces_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
