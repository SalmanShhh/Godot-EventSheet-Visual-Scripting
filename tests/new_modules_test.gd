# Phases 1/2/4/5 vocabulary: UI (Control/Button/Range/LineEdit), Particles, Tilemaps,
# AnimationTree, shader materials, input remapping, and physics joints. Verifies registry
# presence + node-type scoping, and end-to-end that the Button trigger resolver arms emit
# a real signal connection (the one delicate compiler touch-point).
@tool
extends RefCounted
class_name NewModulesTest

static func run() -> bool:
	var all_passed: bool = true

	var ids: Dictionary = {}
	var node_types: Dictionary = {}
	for d: ACEDescriptor in EventForgeBuiltinACEs.get_descriptors():
		ids[d.ace_id] = true
		node_types[d.ace_id] = d.node_type

	# ── Registry presence + node-type scoping across the five new surfaces ──
	for expected: Array in [
		["OnButtonPressed", "BaseButton"], ["OnButtonToggled", "BaseButton"],
		["GrabFocus", "Control"], ["SetRangeValue", "Range"], ["SetLineEditText", "LineEdit"],
		["GetButtonText", "Button"], ["SetEmitting", "GPUParticles2D"],
		["OnParticlesFinished", "GPUParticles2D"], ["TileMapSetCell", "TileMapLayer"],
		["TileMapLocalToMap", "TileMapLayer"], ["TravelToState", "AnimationTree"],
		["GetCurrentState", "AnimationTree"], ["SetShaderMaterial", "CanvasItem"],
		["ActionAddEvent", ""], ["SetJointBodyA", "Joint2D"], ["BreakJoint3D", "Joint3D"],
		["IsOnWall", "CharacterBody2D"], ["GetOverlappingBodies", "Area2D"],
		["SetCollisionLayerBit", "CollisionObject2D"], ["DisableCollisionShape", "CollisionShape2D"],
	]:
		var ace_id: String = str(expected[0])
		all_passed = _check("%s registered" % ace_id, ids.has(ace_id), true) and all_passed
		all_passed = _check("%s scoped to %s" % [ace_id, str(expected[1])], str(node_types.get(ace_id, "<missing>")), str(expected[1])) and all_passed

	# ── Dev helper ACEs (Debug / Groups / Metadata) register with their categories ──
	var categories: Dictionary = {}
	for d2: ACEDescriptor in EventForgeBuiltinACEs.get_descriptors():
		categories[d2.ace_id] = d2.category
	for dev: Array in [["Print", "Debug"], ["Assert", "Debug"], ["AddToGroup", "Groups"], ["IsInGroup", "Groups"], ["SetMeta", "Metadata"], ["GetMeta", "Metadata"]]:
		var dev_id: String = str(dev[0])
		all_passed = _check("%s registered" % dev_id, ids.has(dev_id), true) and all_passed
		all_passed = _check("%s in %s category" % [dev_id, str(dev[1])], str(categories.get(dev_id, "<missing>")), str(dev[1])) and all_passed
	# A multi-param dev ACE substitutes into its native one-liner + parses.
	var dev_sheet: EventSheetResource = EventSheetResource.new()
	dev_sheet.host_class = "Node"
	var dev_event: EventRow = EventRow.new()
	dev_event.trigger_provider_id = "Core"
	dev_event.trigger_id = "OnReady"
	var dev_action: ACEAction = ACEAction.new()
	dev_action.provider_id = "Core"
	dev_action.ace_id = "AddToGroup"
	dev_action.codegen_template = "{target}.add_to_group({group})"
	dev_action.params = {"target": "self", "group": "\"enemies\""}
	dev_event.actions.append(dev_action)
	dev_sheet.events.append(dev_event)
	var dev_output: String = str(SheetCompiler.compile(dev_sheet, "user://eventsheets_dev.gd").get("output", ""))
	all_passed = _check("Add To Group compiles to the native call", dev_output.contains("self.add_to_group(\"enemies\")"), true) and all_passed

	# ── Button On Pressed trigger compiles to a real signal connection (resolver arm) ──
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Control"
	var pressed_event: EventRow = EventRow.new()
	pressed_event.trigger_provider_id = "Core"
	pressed_event.trigger_id = "OnButtonPressed"
	pressed_event.trigger_source_path = "StartButton"
	var grab: ACEAction = ACEAction.new()
	grab.provider_id = "Core"
	grab.ace_id = "GrabFocus"
	grab.codegen_template = "grab_focus()"
	pressed_event.actions.append(grab)
	sheet.events.append(pressed_event)
	var output: String = str(SheetCompiler.compile(sheet, "user://eventsheets_ui_test.gd").get("output", ""))
	all_passed = _check("On Pressed connects the pressed signal", output.contains(".pressed.connect("), true) and all_passed
	all_passed = _check("On Pressed emits a handler", output.contains("_startbutton_pressed"), true) and all_passed
	all_passed = _check("On Pressed action lands in the handler", output.contains("grab_focus()"), true) and all_passed

	# ── On Toggled carries the toggled_on: bool argument ──
	var toggled_event: EventRow = EventRow.new()
	toggled_event.trigger_provider_id = "Core"
	toggled_event.trigger_id = "OnButtonToggled"
	toggled_event.trigger_source_path = "MuteButton"
	var print_act: ACEAction = ACEAction.new()
	print_act.provider_id = "Core"
	print_act.ace_id = "PrintLog"
	print_act.codegen_template = "print({m})"
	print_act.params = {"m": "toggled_on"}
	toggled_event.actions.append(print_act)
	var toggled_sheet: EventSheetResource = EventSheetResource.new()
	toggled_sheet.host_class = "Control"
	toggled_sheet.events.append(toggled_event)
	var toggled_output: String = str(SheetCompiler.compile(toggled_sheet, "user://eventsheets_ui_toggled.gd").get("output", ""))
	all_passed = _check("On Toggled connects the toggled signal", toggled_output.contains(".toggled.connect("), true) and all_passed
	all_passed = _check("On Toggled handler takes toggled_on: bool", toggled_output.contains("toggled_on: bool"), true) and all_passed

	# ── Both compiled scripts parse (parity / reload gate) ──
	var script: GDScript = GDScript.new()
	script.source_code = output
	all_passed = _check("UI Button sheet parses", script.reload() == OK, true) and all_passed
	var toggled_script: GDScript = GDScript.new()
	toggled_script.source_code = toggled_output
	all_passed = _check("UI Toggle sheet parses", toggled_script.reload() == OK, true) and all_passed

	return all_passed

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] new_modules_test: %s" % label)
		return true
	print("[FAIL] new_modules_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
