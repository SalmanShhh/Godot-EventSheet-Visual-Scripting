# Godot EventSheets - async events, the GDevelop-parity slices
# Await support is native (handlers are implicit coroutines); these pins cover the parity
# layer on top: UNPICK-ON-FREE (an awaiting event's pick loops guard every iteration so
# objects freed during a wait are skipped - the guard is ONE flat line so it lifts as a
# plain statement, is consumed by the lifter, and regenerates on emit: byte-exact both
# ways) and the ASYNC CHIP (awaiting actions wear an hourglass in the viewport). Pins:
# guard present with awaits, absent without, byte round-trip through the importer, the
# lifter consuming rather than duplicating, and the chip detection VALUES.
@tool
class_name AsyncEventsTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true

	# ---- unpick-on-free: an awaiting pick loop guards each iteration ----
	var awaiting_sheet: EventSheetResource = _loop_sheet(true)
	var awaiting_output: String = str(SheetCompiler.compile(awaiting_sheet, "user://async_guard_probe.gd").get("output", ""))
	all_passed = _check("an awaiting loop guards freed iterators",
		awaiting_output.contains("\t\tif child is Object and not is_instance_valid(child): continue"), true) and all_passed
	all_passed = _check("the guard sits before the awaiting action",
		awaiting_output.find("is_instance_valid(child)") < awaiting_output.find("await get_tree()"), true) and all_passed
	var parsed: GDScript = GDScript.new()
	parsed.source_code = awaiting_output
	all_passed = _check("the guarded output parses", parsed.reload(true) == OK, true) and all_passed

	# ---- the guard is generated, not stored: byte-exact round-trip both ways ----
	all_passed = _check("the awaiting loop round-trips byte-exact", EventSheets.round_trips(awaiting_output), true) and all_passed
	var lifted: EventSheetResource = GDScriptImporter.new().import_external_source(awaiting_output)
	var relifted_guards: int = 0
	for entry: Variant in lifted.events:
		if entry is EventRow:
			for action: Variant in (entry as EventRow).actions:
				if action is RawCodeRow and (action as RawCodeRow).code.contains("is_instance_valid"):
					relifted_guards += 1
	all_passed = _check("the lifter consumes the guard instead of keeping it as a row", relifted_guards, 0) and all_passed

	# ---- no await, no guard: non-suspending loops stay exactly as before ----
	var plain_sheet: EventSheetResource = _loop_sheet(false)
	var plain_output: String = str(SheetCompiler.compile(plain_sheet, "user://async_plain_probe.gd").get("output", ""))
	all_passed = _check("a non-awaiting loop stays guard-free", plain_output.contains("is_instance_valid"), false) and all_passed

	# ---- the async chip: awaiting actions are detected by VALUE ----
	var wait_action: ACEAction = ACEAction.new()
	wait_action.codegen_template = "await get_tree().create_timer({seconds}).timeout"
	all_passed = _check("a Wait template reads as awaiting", ViewportRowBuilder.action_awaits(wait_action), true) and all_passed
	var flagged_action: ACEAction = ACEAction.new()
	flagged_action.codegen_template = "do_thing()"
	flagged_action.is_awaited = true
	all_passed = _check("an awaited call reads as awaiting", ViewportRowBuilder.action_awaits(flagged_action), true) and all_passed
	var plain_action: ACEAction = ACEAction.new()
	plain_action.codegen_template = "print({value})"
	all_passed = _check("a plain action does not", ViewportRowBuilder.action_awaits(plain_action), false) and all_passed

	# ---- single-flight: Once At A Time gates re-entry via the new on_exit hook ----
	var gated: EventSheetResource = EventSheetResource.new()
	gated.host_class = "Node"
	var gated_row: EventRow = EventRow.new()
	gated_row.trigger_provider_id = "Core"
	gated_row.trigger_id = "OnProcess"
	var gate: ACECondition = ACECondition.new()
	gate.provider_id = "Core"
	gate.ace_id = "SingleFlight"
	gate.codegen_template = "not __busy_ab12"
	gate.member_declaration = "var __busy_ab12: bool = false"
	gate.codegen_on_true = "__busy_ab12 = true"
	gate.codegen_on_exit = "__busy_ab12 = false"
	gate.evaluate_last = true
	gated_row.conditions.append(gate)
	var gated_wait: ACEAction = ACEAction.new()
	gated_wait.provider_id = "Core"
	gated_wait.ace_id = "Wait"
	gated_wait.params = {"seconds": "2.0"}
	gated_row.actions.append(gated_wait)
	gated.events.append(gated_row)
	var gated_output: String = str(SheetCompiler.compile(gated, "user://async_sf_probe.gd").get("output", ""))
	all_passed = _check("the busy latch declares as a member", gated_output.contains("var __busy_ab12: bool = false"), true) and all_passed
	all_passed = _check("the gate guards the event", gated_output.contains("\tif not __busy_ab12:"), true) and all_passed
	all_passed = _check("entry marks busy first", gated_output.contains("\t\t__busy_ab12 = true\n\t\tawait "), true) and all_passed
	all_passed = _check("the run-finished hook resets AFTER the body", gated_output.find("__busy_ab12 = false") > gated_output.find("await "), true) and all_passed
	all_passed = _check("the gated event round-trips byte-exact", EventSheets.round_trips(gated_output), true) and all_passed
	var registry_descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", "SingleFlight")
	all_passed = _check("Once At A Time is registered", registry_descriptor != null, true) and all_passed
	if registry_descriptor != null:
		all_passed = _check("its reset rides the on_exit channel", registry_descriptor.codegen_on_exit, "__busy_{uid} = false") and all_passed

	# ---- the Doctor stays silent when the gate makes overlap impossible ----
	var gated_findings: Array[Dictionary] = []
	EventSheetProjectDoctor._scan_coroutine_misuse(gated_row, "res://probe.gd", gated_findings)
	all_passed = _check("coroutine-in-per-frame stays silent under the gate", gated_findings.is_empty(), true) and all_passed
	var ungated_row: EventRow = EventRow.new()
	ungated_row.trigger_provider_id = "Core"
	ungated_row.trigger_id = "OnProcess"
	ungated_row.actions.append(gated_wait)
	var ungated_findings: Array[Dictionary] = []
	EventSheetProjectDoctor._scan_coroutine_misuse(ungated_row, "res://probe.gd", ungated_findings)
	all_passed = _check("and still warns without it", ungated_findings.size(), 1) and all_passed

	# ---- sibling isolation: an awaiting event splits out of a shared per-frame handler ----
	var shared: EventSheetResource = EventSheetResource.new()
	shared.host_class = "Node"
	shared.variables = {"hp": {"type": "int", "default": 3, "exported": false}}
	var waiter: EventRow = EventRow.new()
	waiter.trigger_provider_id = "Core"
	waiter.trigger_id = "OnProcess"
	waiter.event_uid = "aa11"
	var waiter_cond: ACECondition = ACECondition.new()
	waiter_cond.provider_id = "Core"
	waiter_cond.ace_id = "CompareVariable"
	waiter_cond.codegen_template = "hp > 0"
	waiter.conditions.append(waiter_cond)
	var waiter_wait: ACEAction = ACEAction.new()
	waiter_wait.provider_id = "Core"
	waiter_wait.ace_id = "Wait"
	waiter_wait.params = {"seconds": "1.0"}
	waiter.actions.append(waiter_wait)
	shared.events.append(waiter)
	var sibling: EventRow = EventRow.new()
	sibling.trigger_provider_id = "Core"
	sibling.trigger_id = "OnProcess"
	var sibling_print: ACEAction = ACEAction.new()
	sibling_print.provider_id = "Core"
	sibling_print.ace_id = "Print"
	sibling_print.codegen_template = "print({value})"
	sibling_print.params = {"value": "\"every frame\""}
	sibling.actions.append(sibling_print)
	shared.events.append(sibling)
	var split_output: String = str(SheetCompiler.compile(shared, "user://async_split_probe.gd").get("output", ""))
	all_passed = _check("the awaiting event becomes a fire-and-forget call",
		split_output.contains("\t_event_aa11_async(delta)"), true) and all_passed
	all_passed = _check("its coroutine splits out below the dispatcher",
		split_output.contains("func _event_aa11_async(delta: float) -> void:"), true) and all_passed
	all_passed = _check("the sibling stays inline (never waits)",
		split_output.find("print(\"every frame\")") < split_output.find("func _event_aa11_async"), true) and all_passed
	var split_parsed: GDScript = GDScript.new()
	split_parsed.source_code = split_output
	all_passed = _check("the split output parses", split_parsed.reload(true) == OK, true) and all_passed
	all_passed = _check("the split shape round-trips byte-exact", EventSheets.round_trips(split_output), true) and all_passed
	# The lift is STRUCTURAL: both events come back under On Process, the split uid intact.
	var split_lifted: EventSheetResource = GDScriptImporter.new().import_external_source(split_output)
	var split_uids: Array = []
	for entry: Variant in split_lifted.events:
		if entry is EventRow and (entry as EventRow).trigger_id == "OnProcess":
			split_uids.append((entry as EventRow).event_uid)
	all_passed = _check("both events lift back under the trigger (got %s)" % str(split_uids), split_uids.size(), 2) and all_passed
	all_passed = _check("the split event's uid survives the round trip", split_uids.has("aa11"), true) and all_passed
	# A single awaiting event alone in the handler keeps the plain shape - nothing to isolate.
	var lone: EventSheetResource = EventSheetResource.new()
	lone.host_class = "Node"
	var lone_row: EventRow = EventRow.new()
	lone_row.trigger_provider_id = "Core"
	lone_row.trigger_id = "OnProcess"
	lone_row.actions.append(waiter_wait)
	lone.events.append(lone_row)
	var lone_output: String = str(SheetCompiler.compile(lone, "user://async_lone_probe.gd").get("output", ""))
	all_passed = _check("a lone awaiting event stays inline", lone_output.contains("_async(delta)"), false) and all_passed

	return all_passed


## A sheet with one On Ready event iterating children; with_wait adds the suspending action.
static func _loop_sheet(with_wait: bool) -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	var row: EventRow = EventRow.new()
	row.trigger_provider_id = "Core"
	row.trigger_id = "OnReady"
	var pick: PickFilter = PickFilter.new()
	pick.collection_kind = PickFilter.CollectionKind.EXPRESSION
	pick.collection_value = "get_children()"
	pick.iterator_name = "child"
	row.pick_filters.append(pick)
	if with_wait:
		var wait: ACEAction = ACEAction.new()
		wait.provider_id = "Core"
		wait.ace_id = "Wait"
		wait.codegen_template = "await get_tree().create_timer({seconds}).timeout"
		wait.params = {"seconds": "0.5"}
		row.actions.append(wait)
	var poke: ACEAction = ACEAction.new()
	poke.provider_id = "Core"
	poke.ace_id = "Print"
	poke.codegen_template = "print({value})"
	poke.params = {"value": "child"}
	row.actions.append(poke)
	sheet.events.append(row)
	return sheet


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		return true
	print("  [FAIL] async_events_test: %s (got %s, expected %s)" % [label, str(actual), str(expected)])
	return false
