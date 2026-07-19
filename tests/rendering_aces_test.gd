# EventForge - the Rendering module: RenderingServer vocabulary (clear color, global shader
# parameters, AA / resolution-scale switches, debug draw, perf-HUD statistics) compiles to
# plain RenderingServer calls that parse standalone, and the option dropdowns carry full
# constant expressions so the picker writes valid GDScript verbatim.
@tool
class_name RenderingAcesTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true

	var by_id: Dictionary = {}
	for descriptor in EventForgeBuiltinACEs.get_descriptors():
		by_id[descriptor.ace_id] = descriptor
	all_passed = _check("rendering actions registered",
		by_id.has("RenderingSetClearColor") and by_id.has("RenderingSetGlobalShaderParam")
		and by_id.has("RenderingSetMsaa3D") and by_id.has("RenderingSetScaling3DScale")
		and by_id.has("RenderingSetDebugDraw") and by_id.has("RenderingSetOcclusionCulling"), true) and all_passed
	all_passed = _check("rendering condition + expressions registered",
		by_id.has("RenderingUsesModernRenderer") and by_id.has("RenderingDrawCallsInFrame")
		and by_id.has("RenderingVideoMemoryUsed") and by_id.has("RenderingGetGlobalShaderParam"), true) and all_passed
	all_passed = _check("MSAA levels are a dropdown of full constants",
		((by_id["RenderingSetMsaa3D"].params[0] as ACEParam).options as Array).size() == 4
		and str((by_id["RenderingSetMsaa3D"].params[0] as ACEParam).options[2]) == "RenderingServer.VIEWPORT_MSAA_4X", true) and all_passed
	all_passed = _check("debug draw offers the diagnostic modes",
		((by_id["RenderingSetDebugDraw"].params[0] as ACEParam).options as Array).has("RenderingServer.VIEWPORT_DEBUG_DRAW_OVERDRAW"), true) and all_passed

	# Compile a sheet exercising an option constant, the shader-parameter pair, a viewport-
	# scoped call, the condition, and a perf expression - the output must be plain calls
	# (no plugin references) and parse standalone.
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	sheet.variables = {"hud_calls": {"type": "int", "default": 0, "exported": false}}
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnProcess"
	var gate: ACECondition = ACECondition.new()
	gate.provider_id = "Core"
	gate.ace_id = "RenderingUsesModernRenderer"
	gate.codegen_template = str(by_id["RenderingUsesModernRenderer"].codegen_template)
	event.conditions.append(gate)
	event.actions.append(_action(by_id, "RenderingSetMsaa3D", {"level": "RenderingServer.VIEWPORT_MSAA_4X"}))
	event.actions.append(_action(by_id, "RenderingSetGlobalShaderParam", {"name": "\"wind_strength\"", "value": "2.5"}))
	event.actions.append(_action(by_id, "RenderingSetScaling3DScale", {"scale": "0.75"}))
	event.actions.append(_action(by_id, "SetVar", {"var_name": "hud_calls", "value": str(by_id["RenderingDrawCallsInFrame"].codegen_template)}))
	sheet.events.append(event)
	var output: String = str(SheetCompiler.compile(sheet, "user://rendering_aces.gd").get("output", ""))
	all_passed = _check("MSAA compiles the chosen constant verbatim",
		output.contains("RenderingServer.viewport_set_msaa_3d(get_viewport().get_viewport_rid(), RenderingServer.VIEWPORT_MSAA_4X)"), true) and all_passed
	all_passed = _check("global shader parameter compiles name + value",
		output.contains("RenderingServer.global_shader_parameter_set(\"wind_strength\", 2.5)"), true) and all_passed
	all_passed = _check("resolution scale targets the current viewport",
		output.contains("RenderingServer.viewport_set_scaling_3d_scale(get_viewport().get_viewport_rid(), 0.75)"), true) and all_passed
	all_passed = _check("the renderer gate compiles as a plain condition",
		output.contains("if RenderingServer.get_rendering_device() != null:"), true) and all_passed
	all_passed = _check("the perf expression feeds a variable",
		output.contains("hud_calls = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)"), true) and all_passed
	# Parity: no plugin references in CODE lines (the generated-file banner comment may
	# name the plugin; comments carry no runtime dependency).
	var plugin_reference_in_code: bool = false
	for line: String in output.split("\n"):
		if not line.strip_edges().begins_with("#") and (line.contains("EventForge") or line.contains("EventSheet")):
			plugin_reference_in_code = true
	all_passed = _check("no plugin references leak into the code", plugin_reference_in_code, false) and all_passed
	var generated: GDScript = GDScript.new()
	generated.source_code = output
	all_passed = _check("rendering output parses standalone", generated.reload(true) == OK, true) and all_passed

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
		print("[PASS] rendering_aces_test: %s" % label)
		return true
	print("[FAIL] rendering_aces_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
