# EventForge — Sub-event compilation + else/elif chains
#
# Sub-events compile nested inside their parent's conditions; ELSE/ELIF siblings chain onto
# the previous if; comments compile to # lines; flow-dropped variables become locals; a
# block whose body emits nothing gets `pass` (always-valid GDScript). Mirrors the visual
# event-sheet event-flow semantics — see _emit_event_body's doc comment for the full rules.
@tool
class_name SubeventCompileTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true

	# Parent (condition + action) with a nested sub-event (condition + action) plus a
	# comment and a variable inside the flow.
	var sheet: EventSheetResource = EventSheetResource.new()
	var parent: EventRow = EventRow.new()
	parent.trigger_provider_id = "Core"
	parent.trigger_id = "OnProcess"
	parent.conditions.append(_condition("Core", "IsOnFloor"))
	parent.actions.append(_action("queue_free()"))
	var note: CommentRow = CommentRow.new()
	note.text = "only while grounded"
	parent.sub_events.append(note)
	var flow_var: LocalVariable = LocalVariable.new()
	flow_var.name = "combo"
	flow_var.type_name = "int"
	flow_var.default_value = 0
	parent.sub_events.append(flow_var)
	var child: EventRow = EventRow.new()
	child.conditions.append(_condition_with_template("health < 10"))
	child.actions.append(_action("health += 5"))
	parent.sub_events.append(child)
	sheet.events.append(parent)

	var compile_result: Dictionary = SheetCompiler.compile(sheet, "user://eventforge_subevents.gd")
	var output: String = str(compile_result.get("output", ""))
	all_passed = _check("parent condition at depth 1", output.contains("\tif is_on_floor():"), true) and all_passed
	all_passed = _check("parent action at depth 2", output.contains("\t\tqueue_free()"), true) and all_passed
	all_passed = _check("nested comment compiles inside the parent body", output.contains("\t\t# only while grounded"), true) and all_passed
	all_passed = _check("flow variable compiles as a local", output.contains("\t\tvar combo: int = 0"), true) and all_passed
	all_passed = _check("sub-event condition nests at depth 2", output.contains("\t\tif health < 10:"), true) and all_passed
	all_passed = _check("sub-event action nests at depth 3", output.contains("\t\t\thealth += 5"), true) and all_passed
	all_passed = _check("no sub-event TODO placeholder remains", output.contains("# TODO: row type not yet implemented"), false) and all_passed
	var child_mapped: bool = false
	for entry in compile_result.get("source_map", []):
		if entry is Dictionary and str((entry as Dictionary).get("uid", "")) == str(child.get_instance_id()):
			child_mapped = true
	all_passed = _check("sub-event gets its own provenance entry", child_mapped, true) and all_passed

	# ELSE / ELIF chaining on siblings.
	var chain_sheet: EventSheetResource = EventSheetResource.new()
	var if_event: EventRow = EventRow.new()
	if_event.trigger_provider_id = "Core"
	if_event.trigger_id = "OnProcess"
	if_event.conditions.append(_condition_with_template("health > 50"))
	if_event.actions.append(_action("sprint()"))
	var elif_event: EventRow = EventRow.new()
	elif_event.trigger_provider_id = "Core"
	elif_event.trigger_id = "OnProcess"
	elif_event.else_mode = EventRow.ElseMode.ELIF
	elif_event.conditions.append(_condition_with_template("health > 10"))
	elif_event.actions.append(_action("walk()"))
	var else_event: EventRow = EventRow.new()
	else_event.trigger_provider_id = "Core"
	else_event.trigger_id = "OnProcess"
	else_event.else_mode = EventRow.ElseMode.ELSE
	else_event.actions.append(_action("crawl()"))
	chain_sheet.events.append(if_event)
	chain_sheet.events.append(elif_event)
	chain_sheet.events.append(else_event)
	var chain_output: String = str(SheetCompiler.compile(chain_sheet, "user://eventforge_chain.gd").get("output", ""))
	all_passed = _check("if/elif/else chain emits in order",
		chain_output.contains("\tif health > 50:\n\t\tsprint()\n\telif health > 10:\n\t\twalk()\n\telse:\n\t\tcrawl()"), true) and all_passed

	# Else without a preceding if degrades with a warning, never invalid output.
	var orphan_sheet: EventSheetResource = EventSheetResource.new()
	var orphan_else: EventRow = EventRow.new()
	orphan_else.trigger_provider_id = "Core"
	orphan_else.trigger_id = "OnReady"
	orphan_else.else_mode = EventRow.ElseMode.ELSE
	orphan_else.actions.append(_action("setup()"))
	orphan_sheet.events.append(orphan_else)
	var orphan_result: Dictionary = SheetCompiler.compile(orphan_sheet, "user://eventforge_orphan_else.gd")
	all_passed = _check("orphan else degrades to standalone actions",
		str(orphan_result.get("output", "")).contains("\tsetup()"), true) and all_passed
	all_passed = _check("orphan else records a warning",
		not (orphan_result.get("warnings", []) as Array).is_empty(), true) and all_passed

	# A condition-only event emits `pass` so the script stays valid.
	var hollow_sheet: EventSheetResource = EventSheetResource.new()
	var hollow: EventRow = EventRow.new()
	hollow.trigger_provider_id = "Core"
	hollow.trigger_id = "OnReady"
	hollow.conditions.append(_condition_with_template("health > 0"))
	hollow_sheet.events.append(hollow)
	var hollow_output: String = str(SheetCompiler.compile(hollow_sheet, "user://eventforge_hollow.gd").get("output", ""))
	all_passed = _check("condition-only event emits pass", hollow_output.contains("\tif health > 0:\n\t\tpass"), true) and all_passed

	return all_passed


static func _condition(provider: String, ace_id: String) -> ACECondition:
	var condition: ACECondition = ACECondition.new()
	condition.provider_id = provider
	condition.ace_id = ace_id
	return condition


static func _condition_with_template(template: String) -> ACECondition:
	var condition: ACECondition = ACECondition.new()
	condition.provider_id = "Test"
	condition.ace_id = template
	condition.codegen_template = template
	return condition


static func _action(template: String) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Test"
	action.ace_id = template
	action.codegen_template = template
	return action


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] subevent_compile_test: %s" % label)
		return true
	print("[FAIL] subevent_compile_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
