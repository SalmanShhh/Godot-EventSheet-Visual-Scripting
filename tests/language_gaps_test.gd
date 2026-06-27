# Godot EventSheets — Language gaps closed (Loops + Pick Instances + returns + more)
# Ordered picking (pick nearest/highest), Repeat/While loop kinds, function return types
# (+ Return actions), group-local variables, and real breakpoints (gated emission).
@tool
extends RefCounted
class_name LanguageGapsTest

class NoopUndoManager:
	extends RefCounted
	func create_action(_a = null) -> void: pass
	func add_do_method(_a = null, _b = null, _c = null, _d = null, _e = null) -> void: pass
	func add_undo_method(_a = null, _b = null, _c = null, _d = null, _e = null) -> void: pass
	func commit_action() -> void: pass
	func has_undo() -> bool: return false
	func has_redo() -> bool: return false
	func undo() -> void: pass
	func redo() -> void: pass
	func clear_history() -> void: pass

static func run() -> bool:
	var all_passed: bool = true

	# Ordered picking: pick nearest = order by distance, first 1.
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnProcess"
	var nearest: PickFilter = PickFilter.new()
	nearest.collection_kind = PickFilter.CollectionKind.GROUP
	nearest.collection_value = "enemies"
	nearest.iterator_name = "enemy"
	nearest.order_by_expression = "enemy.global_position.distance_to(global_position)"
	nearest.pick_first_n = 1
	event.pick_filters.append(nearest)
	var hit: ACEAction = ACEAction.new()
	hit.provider_id = "Core"
	hit.ace_id = "PrintLog"
	hit.codegen_template = "print({m})"
	hit.params = {"m": "enemy.name"}
	event.actions.append(hit)
	sheet.events.append(event)
	var output: String = str(SheetCompiler.compile(sheet, "user://eventsheets_lang.gd").get("output", ""))
	all_passed = _check("ordered picking sorts a copy",
		output.contains(".sort_custom(func(__pick_a, __pick_b): return (__pick_a.global_position.distance_to(global_position)) < (__pick_b.global_position.distance_to(global_position)))"), true) and all_passed
	all_passed = _check("pick nearest caps at one", output.contains("if __pick_count_0 > 1:"), true) and all_passed
	nearest.order_descending = true
	output = str(SheetCompiler.compile(sheet, "user://eventsheets_lang.gd").get("output", ""))
	all_passed = _check("descending flips the comparator", output.contains(") > (__pick_b"), true) and all_passed

	# Repeat / While kinds.
	var repeat_pick: PickFilter = PickFilter.new()
	repeat_pick.collection_kind = PickFilter.CollectionKind.REPEAT
	repeat_pick.collection_value = "5"
	repeat_pick.iterator_name = "i"
	var while_pick: PickFilter = PickFilter.new()
	while_pick.collection_kind = PickFilter.CollectionKind.WHILE
	while_pick.collection_value = "queue.size() > 0"
	var loop_event: EventRow = EventRow.new()
	loop_event.trigger_provider_id = "Core"
	loop_event.trigger_id = "OnReady"
	loop_event.pick_filters.append(repeat_pick)
	loop_event.pick_filters.append(while_pick)
	var pop: ACEAction = ACEAction.new()
	pop.provider_id = "Core"
	pop.ace_id = "X"
	pop.codegen_template = "queue.pop_front()"
	loop_event.actions.append(pop)
	var loop_sheet: EventSheetResource = EventSheetResource.new()
	loop_sheet.variables = {"queue": {"type": "Array", "default": [], "exported": false}}
	loop_sheet.events.append(loop_event)
	var loop_output: String = str(SheetCompiler.compile(loop_sheet, "user://eventsheets_loops.gd").get("output", ""))
	all_passed = _check("Repeat compiles to range", loop_output.contains("for i in range(5):"), true) and all_passed
	all_passed = _check("While compiles to while", loop_output.contains("while queue.size() > 0:"), true) and all_passed
	var loop_script: GDScript = GDScript.new()
	loop_script.source_code = loop_output
	all_passed = _check("loop output parses", loop_script.reload(true) == OK, true) and all_passed

	# Function return types + Return Value action.
	var fn: EventFunction = EventFunction.new()
	fn.function_name = "pick_damage"
	fn.return_type = TYPE_INT
	var ret: ACEAction = ACEAction.new()
	ret.provider_id = "Core"
	ret.ace_id = "ReturnValue"
	ret.codegen_template = "return {value}"
	ret.params = {"value": "7"}
	var ret_event: RawCodeRow = RawCodeRow.new()
	ret_event.code = "return 7"
	var fn_sheet: EventSheetResource = EventSheetResource.new()
	fn.events.append(ret_event)
	fn_sheet.functions.append(fn)
	var fn_output: String = str(SheetCompiler.compile(fn_sheet, "user://eventsheets_fn_ret.gd").get("output", ""))
	all_passed = _check("function return types emit", fn_output.contains("func pick_damage() -> int:"), true) and all_passed
	var fn_script: GDScript = GDScript.new()
	fn_script.source_code = fn_output
	all_passed = _check("typed function parses", fn_script.reload(true) == OK, true) and all_passed
	# Lift round-trip with a return type.
	var ext: String = "extends Node\n\n## @ace_hidden\nfunc pick_damage() -> int:\n\treturn 7\n"
	var imported: EventSheetResource = GDScriptImporter.new().import_external_source(ext)
	var lifted_fn: EventFunction = null
	for f in imported.functions:
		lifted_fn = f
	all_passed = _check("typed functions lift", lifted_fn != null and lifted_fn.return_type == TYPE_INT, true) and all_passed
	imported.external_source_path = "user://eventsheets_fn_rt.gd"
	all_passed = _check("typed function round-trips",
		str(SheetCompiler.compile(imported, "user://eventsheets_fn_rt.gd").get("output", "")) == ext, true) and all_passed

	# Group locals.
	var group: EventGroup = EventGroup.new()
	group.group_name = "Combat"
	var combo: LocalVariable = LocalVariable.new()
	combo.name = "combo_count"
	combo.type_name = "int"
	combo.default_value = 0
	group.local_variables.append(combo)
	var gl_sheet: EventSheetResource = EventSheetResource.new()
	gl_sheet.events.append(group)
	var gl_output: String = str(SheetCompiler.compile(gl_sheet, "user://eventsheets_gl.gd").get("output", ""))
	all_passed = _check("group locals emit under their header",
		gl_output.contains("# Combat — group locals") and gl_output.contains("var combo_count: int = 0"), true) and all_passed

	# Real breakpoints: gated on the sheet toggle.
	var bp_event: EventRow = EventRow.new()
	bp_event.trigger_provider_id = "Core"
	bp_event.trigger_id = "OnReady"
	bp_event.debug_break = true
	var bp_act: ACEAction = ACEAction.new()
	bp_act.provider_id = "Core"
	bp_act.ace_id = "QueueFree"
	bp_act.codegen_template = "queue_free()"
	bp_event.actions.append(bp_act)
	var bp_sheet: EventSheetResource = EventSheetResource.new()
	bp_sheet.events.append(bp_event)
	var off_output: String = str(SheetCompiler.compile(bp_sheet, "user://eventsheets_bp_off.gd").get("output", ""))
	all_passed = _check("breakpoints stay out of normal compiles", off_output.contains("breakpoint"), false) and all_passed
	bp_sheet.emit_breakpoints = true
	var on_output: String = str(SheetCompiler.compile(bp_sheet, "user://eventsheets_bp_on.gd").get("output", ""))
	all_passed = _check("debug compiles emit breakpoint first",
		on_output.contains("\tbreakpoint") and on_output.find("breakpoint") < on_output.find("queue_free()"), true) and all_passed

	# Preset wiring: presets fill the dialog into the right kinds.
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(EventSheetResource.new())
	editor.set_undo_redo_manager(NoopUndoManager.new())
	editor._ensure_pick_dialog()
	editor._apply_pick_preset(5)  # While
	all_passed = _check("While preset selects the while kind",
		editor._pick_option_to_kind(editor._pick_kind_option.selected), PickFilter.CollectionKind.WHILE) and all_passed
	editor._apply_pick_preset(8)  # Pick by highest value
	all_passed = _check("highest-value preset = ordered descending first-1",
		editor._pick_desc_check.button_pressed and int(editor._pick_first_n_spin.value) == 1 and not editor._pick_order_edit.text.is_empty(), true) and all_passed
	editor._apply_pick_preset(11)  # Pick random
	all_passed = _check("random preset wraps pick_random",
		editor._pick_collection_edit.text.contains(".pick_random()"), true) and all_passed
	editor.free()

	# Runtime-toggleable groups (Set Group Active, opt-in).
	var rt_sheet: EventSheetResource = EventSheetResource.new()
	var rt_group: EventGroup = EventGroup.new()
	rt_group.group_name = "Combat"
	rt_group.runtime_toggleable = true
	var rt_event: EventRow = EventRow.new()
	rt_event.trigger_provider_id = "Core"
	rt_event.trigger_id = "OnProcess"
	var rt_action: ACEAction = ACEAction.new()
	rt_action.provider_id = "Core"
	rt_action.ace_id = "X"
	rt_action.codegen_template = "rotation += delta"
	rt_event.actions.append(rt_action)
	rt_group.events.append(rt_event)
	rt_sheet.events.append(rt_group)
	rt_sheet.host_class = "Node2D"
	var rt_output: String = str(SheetCompiler.compile(rt_sheet, "user://eventsheets_rtgroup.gd").get("output", ""))
	all_passed = _check("runtime groups declare their flag member",
		rt_output.contains("var __group_combat_active: bool = true"), true) and all_passed
	all_passed = _check("contained events guard on the flag",
		rt_output.contains("if __group_combat_active:"), true) and all_passed
	var rt_script: GDScript = GDScript.new()
	rt_script.source_code = rt_output
	all_passed = _check("runtime-group output parses", rt_script.reload(true) == OK, true) and all_passed
	rt_group.runtime_toggleable = false
	var plain_output: String = str(SheetCompiler.compile(rt_sheet, "user://eventsheets_rtgroup2.gd").get("output", ""))
	all_passed = _check("non-toggleable groups stay zero-cost",
		plain_output.contains("__group_combat_active"), false) and all_passed
	# The Set Group Active ACE compiles a dynamic set() (works from any sheet code).
	var by_id: Dictionary = {}
	for descriptor in EventForgeBuiltinACEs.get_descriptors():
		by_id[descriptor.ace_id] = descriptor
	all_passed = _check("Set/Is Group Active registered",
		by_id.has("SetGroupActive") and by_id.has("IsGroupActive"), true) and all_passed
	# OR-mode events inside runtime groups must AND-wrap the guard (joining it into
	# the OR list would silently disable the gate).
	rt_group.runtime_toggleable = true
	rt_event.condition_mode = EventRow.ConditionMode.OR
	var or_a: ACECondition = ACECondition.new()
	or_a.provider_id = "Core"
	or_a.ace_id = "A"
	or_a.codegen_template = "is_on_floor()"
	var or_b: ACECondition = ACECondition.new()
	or_b.provider_id = "Core"
	or_b.ace_id = "B"
	or_b.codegen_template = "is_on_wall()"
	rt_event.conditions.append(or_a)
	rt_event.conditions.append(or_b)
	var or_guard_output: String = str(SheetCompiler.compile(rt_sheet, "user://eventsheets_rtor.gd").get("output", ""))
	all_passed = _check("OR events AND-wrap the runtime guard",
		or_guard_output.contains("if __group_combat_active and (is_on_floor() or is_on_wall()):"), true) and all_passed

	return all_passed

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] language_gaps_test: %s" % label)
		return true
	print("[FAIL] language_gaps_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
