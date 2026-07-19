# Phases 1/2/4/5 vocabulary: UI (Control/Button/Range/LineEdit), Particles, Tilemaps,
# AnimationTree, shader materials, input remapping, and physics joints. Verifies registry
# presence + node-type scoping, and end-to-end that the Button trigger resolver arms emit
# a real signal connection (the one delicate compiler touch-point).
@tool
class_name NewModulesTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true

	var ids: Dictionary = {}
	var node_types: Dictionary = {}
	for d: ACEDescriptor in EventForgeBuiltinACEs.get_descriptors():
		ids[d.ace_id] = true
		node_types[d.ace_id] = d.node_type

	# ── Registry identity: no two builtin descriptors may share provider_id::ace_id ──
	# A collision silently overwrites one entry in the registry index (ace_registry.gd), so the
	# picker shows a stray category or a row resolves to the wrong codegen. This guards against
	# regressions like the duplicate "Core::GetFrameCount" a parallel audit caught in this loop.
	var seen_keys: Dictionary = {}
	var duplicate_keys: Array[String] = []
	for dk: ACEDescriptor in EventForgeBuiltinACEs.get_descriptors():
		var reg_key: String = "%s::%s" % [dk.provider_id, dk.ace_id]
		if seen_keys.has(reg_key):
			if not duplicate_keys.has(reg_key):
				duplicate_keys.append(reg_key)
		else:
			seen_keys[reg_key] = true
	all_passed = _check("no duplicate provider::ace_id in builtin descriptors", ", ".join(duplicate_keys) if not duplicate_keys.is_empty() else "(none)", "(none)") and all_passed

	# Module auto-discovery: builtin_aces scans registration/modules/ instead of a hand-edited list,
	# so dropping a module file registers its ACEs with no wiring. Confirm the scan finds the modules,
	# orders the generic helper_aces module LAST (so its catch-all templates never shadow specific ACEs
	# in the reverse-lifter), and yields a full vocabulary.
	var module_files: PackedStringArray = EventForgeBuiltinACEs._module_files()
	all_passed = _check("module scan discovers the modules", module_files.size() >= 15, true) and all_passed
	all_passed = _check("helper_aces module is ordered last",
		not module_files.is_empty() and module_files[module_files.size() - 1] == "helper_aces.gd", true) and all_passed
	all_passed = _check("auto-discovered vocabulary is substantial", EventForgeBuiltinACEs.get_descriptors().size() >= 400, true) and all_passed

	# ── Registry presence + node-type scoping across the five new surfaces ──
	for expected: Array in [
		["OnButtonPressed", "BaseButton"], ["OnButtonToggled", "BaseButton"],
		["OnBodyExited", "Area2D"], ["OnAreaExited", "Area2D"],
		["GrabFocus", "Control"], ["SetRangeValue", "Range"], ["SetLineEditText", "LineEdit"],
		["GetButtonText", "Button"], ["SetEmitting", "GPUParticles2D"],
		["OnParticlesFinished", "GPUParticles2D"], ["TileMapSetCell", "TileMapLayer"],
		["TileMapLocalToMap", "TileMapLayer"], ["TravelToState", "AnimationTree"],
		["GetCurrentState", "AnimationTree"], ["SetShaderMaterial", "CanvasItem"],
		["ActionAddEvent", ""], ["SetJointBodyA", "Joint2D"], ["BreakJoint3D", "Joint3D"],
		["IsOnWall", "CharacterBody2D"], ["GetOverlappingBodies", "Area2D"],
		["SetCollisionLayerBit", "CollisionObject2D"], ["DisableCollisionShape", "CollisionShape2D"],
		["SetAnchorsPreset", "Control"], ["SetThemeColorOverride", "Control"], ["FileExists", ""],
		["SetSelfModulate", "CanvasItem"], ["ApplyCentralForce2D", "RigidBody2D"],
		["ApplyTorqueImpulse2D", "RigidBody2D"], ["RotateNode3D", "Node3D"],
		["SetParticleSpeedScale", "GPUParticles2D"], ["SetParticleSpeedScaleCPU", "CPUParticles2D"],
	]:
		var ace_id: String = str(expected[0])
		all_passed = _check("%s registered" % ace_id, ids.has(ace_id), true) and all_passed
		all_passed = _check("%s scoped to %s" % [ace_id, str(expected[1])], str(node_types.get(ace_id, "<missing>")), str(expected[1])) and all_passed
	# Fresh-ACE method-call templates are valid Godot 4.7 GDScript on their node types.
	var ctrl_script: GDScript = GDScript.new()
	ctrl_script.source_code = "extends Control\nfunc _t() -> void:\n\tset_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)\n\tadd_theme_color_override(&\"font_color\", Color(1, 1, 1, 1))\n\tself_modulate = Color(1, 1, 1, 1)\n"
	all_passed = _check("Control fresh-ACE templates parse", ctrl_script.reload() == OK, true) and all_passed
	var phys_script: GDScript = GDScript.new()
	phys_script.source_code = "extends RigidBody2D\nfunc _t() -> void:\n\tapply_central_force(Vector2(0, 0))\n\tapply_torque_impulse(0.0)\n"
	all_passed = _check("RigidBody2D force ACEs parse", phys_script.reload() == OK, true) and all_passed
	var n3d_script: GDScript = GDScript.new()
	n3d_script.source_code = "extends Node3D\nfunc _t() -> void:\n\trotate(Vector3.UP, 0.0)\n"
	all_passed = _check("Node3D rotate ACE parses", n3d_script.reload() == OK, true) and all_passed

	# ── Dev helper ACEs (Debug / Groups / Metadata) register with their categories ──
	var categories: Dictionary = {}
	for d2: ACEDescriptor in EventForgeBuiltinACEs.get_descriptors():
		categories[d2.ace_id] = d2.category
	for dev: Array in [["Print", "Debug"], ["Assert", "Debug"], ["AddToGroup", "Groups"], ["IsInGroup", "Groups"], ["SetMeta", "Metadata"], ["GetMeta", "Metadata"], ["GetParent", "Nodes"], ["HasNode", "Nodes"], ["FindChild", "Nodes"]]:
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
	# Additional math idioms register under Math & Random.
	for math: Array in [["Snapped", "Math & Random"], ["AngleDifference", "Math & Random"], ["IsEqualApprox", "Math & Random"], ["RotateTowardAngle", "Math & Random"], ["LerpAngle", "Math & Random"], ["SmoothLerp", "Math & Random"], ["Atan2", "Math & Random"]]:
		var math_id: String = str(math[0])
		all_passed = _check("%s registered" % math_id, ids.has(math_id), true) and all_passed
		all_passed = _check("%s in %s" % [math_id, str(math[1])], str(categories.get(math_id, "<missing>")), str(math[1])) and all_passed
	# The eased-lerp and atan2 templates are valid GDScript that computes what they promise.
	var math_probe: GDScript = GDScript.new()
	math_probe.source_code = "extends Node\nfunc _t() -> void:\n\tvar a: float = lerpf(0.0, 10.0, smoothstep(0.0, 1.0, 0.5))\n\tvar b: float = atan2(1.0, 0.0)\n\tassert(is_equal_approx(a, 5.0))\n\tassert(is_equal_approx(b, PI / 2.0))\n"
	all_passed = _check("SmoothLerp + Atan2 templates parse", math_probe.reload() == OK, true) and all_passed
	# Color helper expressions register under Color, and their templates are valid GDScript.
	for col: Array in [["ColorLighten", "Color"], ["ColorLerp", "Color"], ["ColorFromHSV", "Color"], ["ColorWithAlpha", "Color"]]:
		var col_id: String = str(col[0])
		all_passed = _check("%s registered" % col_id, ids.has(col_id), true) and all_passed
		all_passed = _check("%s in %s" % [col_id, str(col[1])], str(categories.get(col_id, "<missing>")), str(col[1])) and all_passed
	var color_script: GDScript = GDScript.new()
	color_script.source_code = "extends Node\nfunc _t() -> void:\n\tvar a: Color = (Color(1, 1, 1, 1)).lightened(0.2)\n\tvar b: Color = (Color(1, 1, 1, 1)).lerp(Color(1, 0, 0, 1), 0.5)\n\tvar c: Color = Color(Color(1, 1, 1, 1), 0.5)\n\tvar d: Color = Color.from_hsv(0.0, 1.0, 1.0, 1.0)\n\tprint(a, b, c, d)\n"
	all_passed = _check("Color helper templates parse", color_script.reload() == OK, true) and all_passed
	# Roadmap ACE batch (audit-driven): registry + category, and the trickier templates parse.
	for r2: Array in [["DictHasAllKeys", "Variables: Dictionary"], ["CallAfterDelay", "Time"], ["TweenCallback", "Tween"], ["SetCameraLimits", "General Actions"], ["StringRepeat", "Variables: String"], ["SeedRandom", "Math & Random"], ["RandomizeSeed", "Math & Random"]]:
		var r2_id: String = str(r2[0])
		all_passed = _check("%s registered" % r2_id, ids.has(r2_id), true) and all_passed
		all_passed = _check("%s in %s" % [r2_id, str(r2[1])], str(categories.get(r2_id, "<missing>")), str(r2[1])) and all_passed
	var batch_script: GDScript = GDScript.new()
	batch_script.source_code = "extends Camera2D\nfunc _t() -> void:\n\tlimit_left = 0\n\tlimit_top = 0\n\tlimit_right = 1920\n\tlimit_bottom = 1080\n\tcreate_tween().tween_callback(queue_free).set_delay(1.0)\n\tget_tree().create_timer(1.0).timeout.connect(queue_free)\n\tseed(0)\n\trandomize()\n\tvar d := {\"a\": 1, \"b\": 2}\n\tprint(d.has_all([\"a\", \"b\"]), \"#\".repeat(3))\n"
	all_passed = _check("Roadmap ACE templates parse", batch_script.reload() == OK, true) and all_passed
	# helper/core roadmap slice: registry + category, the templates parse, and EmitSignalOn emits
	# the modern signal.emit() form cleanly (no dangling parens) when args is empty.
	for r3: Array in [["IsSignalConnected", "Helpers"], ["EmitSignalOn", "Helpers"], ["SetTextFormatted", "Helpers"], ["MoveBy2D", "General Actions"]]:
		var r3_id: String = str(r3[0])
		all_passed = _check("%s registered" % r3_id, ids.has(r3_id), true) and all_passed
		all_passed = _check("%s in %s" % [r3_id, str(r3[1])], str(categories.get(r3_id, "<missing>")), str(r3[1])) and all_passed
	var emit_sheet: EventSheetResource = EventSheetResource.new()
	emit_sheet.host_class = "Node"
	var emit_event: EventRow = EventRow.new()
	emit_event.trigger_provider_id = "Core"
	emit_event.trigger_id = "OnReady"
	var emit_action: ACEAction = ACEAction.new()
	emit_action.provider_id = "Core"
	emit_action.ace_id = "EmitSignalOn"
	emit_action.codegen_template = "{target}.{signal}.emit({args})"
	emit_action.params = {"target": "self", "signal": "died", "args": ""}
	emit_event.actions.append(emit_action)
	emit_sheet.events.append(emit_event)
	var emit_output: String = str(SheetCompiler.compile(emit_sheet, "user://eventsheets_emit.gd").get("output", ""))
	all_passed = _check("Emit Signal On emits the modern .emit() form with clean empty args", emit_output.contains("self.died.emit()"), true) and all_passed
	var hc_script: GDScript = GDScript.new()
	hc_script.source_code = "extends Label\nsignal died\nfunc _t() -> void:\n\tposition += Vector2(0, 0)\n\ttext = \"Score: %d\" % [0]\n\tprint(self.died.is_connected(_t))\n"
	all_passed = _check("Move By / Set Text / Is Connected templates parse", hc_script.reload() == OK, true) and all_passed
	# Spawn Scene (Full): the {uid} local, the multi-line template, and the optional-group guard
	# compile, and the whole emitted script parses.
	var spawn_sheet: EventSheetResource = EventSheetResource.new()
	spawn_sheet.host_class = "Node2D"
	var spawn_event: EventRow = EventRow.new()
	spawn_event.trigger_provider_id = "Core"
	spawn_event.trigger_id = "OnReady"
	var spawn_action: ACEAction = ACEAction.new()
	spawn_action.provider_id = "Core"
	spawn_action.ace_id = "SpawnSceneFull"
	all_passed = _check("SpawnSceneFull registered", ids.has("SpawnSceneFull"), true) and all_passed
	all_passed = _check("SpawnSceneFull in Scene", str(categories.get("SpawnSceneFull", "<missing>")), "Scene") and all_passed
	var spawn_template: String = ""
	for d4: ACEDescriptor in EventForgeBuiltinACEs.get_descriptors():
		if d4.ace_id == "SpawnSceneFull":
			spawn_template = d4.codegen_template
	all_passed = _check("SpawnSceneFull template uses a {uid} local", spawn_template.contains("{uid}"), true) and all_passed
	# The dock bakes {uid} into a unique token at apply time (event_sheet_dock.gd) - mirror that.
	spawn_action.codegen_template = spawn_template.replace("{uid}", "t1")
	spawn_action.params = {"path": "\"res://enemy.tscn\"", "position": "Vector2(8, 0)", "rotation": "180.0", "group": "\"targets\""}
	spawn_event.actions.append(spawn_action)
	spawn_sheet.events.append(spawn_event)
	var spawn_output: String = str(SheetCompiler.compile(spawn_sheet, "user://eventsheets_spawn.gd").get("output", ""))
	all_passed = _check("Spawn Scene (Full) wires rotation + group", spawn_output.contains(".rotation_degrees = 180.0") and spawn_output.contains(".add_to_group(\"targets\")"), true) and all_passed
	var spawn_script: GDScript = GDScript.new()
	spawn_script.source_code = spawn_output
	all_passed = _check("Spawn Scene (Full) output parses", spawn_script.reload() == OK, true) and all_passed
	# Utility ACEs (project toolkit): registry + sub-category, and the multi-line / formatting parse.
	for util: Array in [["SaveSetting", "Utility: Settings"], ["LoadSettingInto", "Utility: Settings"], ["SetWindowTitle", "Utility: Window"], ["GetPerfMonitor", "Utility: Debug"], ["FormatTime", "Utility: Time"], ["ReparentNode", "Utility: Nodes"]]:
		var util_id: String = str(util[0])
		all_passed = _check("%s registered" % util_id, ids.has(util_id), true) and all_passed
		all_passed = _check("%s in %s" % [util_id, str(util[1])], str(categories.get(util_id, "<missing>")), str(util[1])) and all_passed
	var util_script: GDScript = GDScript.new()
	util_script.source_code = "extends Node\nfunc _t() -> void:\n\tvar __cfg_t = ConfigFile.new()\n\t__cfg_t.load(\"user://settings.cfg\")\n\t__cfg_t.set_value(\"audio\", \"volume\", 1.0)\n\t__cfg_t.save(\"user://settings.cfg\")\n\tget_window().title = \"My Game\"\n\tInput.mouse_mode = Input.MOUSE_MODE_VISIBLE\n\tvar t: String = (\"%02d:%02d\" % [int(125.0) / 60, int(125.0) % 60])\n\tprint(Performance.get_monitor(Performance.TIME_FPS), t, DisplayServer.screen_get_size())\n"
	all_passed = _check("Utility templates parse", util_script.reload() == OK, true) and all_passed
	# Node manipulation / picking ACEs: registry + (sub)category, and the native templates parse.
	for nd: Array in [["AddChild", "Nodes"], ["QueueFreeNode", "Nodes"], ["DuplicateNode", "Nodes"], ["IsInsideTree", "Nodes"], ["GetChildren", "Nodes: Picking"], ["GetNodesInGroup", "Nodes: Picking"], ["GetRandomNodeInGroup", "Nodes: Picking"]]:
		var nd_id: String = str(nd[0])
		all_passed = _check("%s registered" % nd_id, ids.has(nd_id), true) and all_passed
		all_passed = _check("%s in %s" % [nd_id, str(nd[1])], str(categories.get(nd_id, "<missing>")), str(nd[1])) and all_passed
	var node_script: GDScript = GDScript.new()
	node_script.source_code = "extends Node\nfunc _t() -> void:\n\tadd_child(Node.new())\n\tmove_child(get_node(\"Child\"), 0)\n\tself.name = \"Renamed\"\n\tprint(self.duplicate(), self.get_index(), self.is_inside_tree(), get_tree().current_scene, self.get_children(), find_children(\"E*\"), get_tree().get_nodes_in_group(\"enemies\").pick_random())\n"
	all_passed = _check("Node manipulation/picking templates parse", node_script.reload() == OK, true) and all_passed

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
