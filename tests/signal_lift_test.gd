# Godot EventSheets - Signal-handler lifting
# Generated sheets that use SIGNAL triggers now lift back into events: `_ready`'s connect
# lines identify each handler's signal + source node; Core signals reverse to their trigger
# ids, custom ones become "signal:<name>" with baked trigger_args; the connects themselves
# are skipped (emission regenerates them). Byte-identical verification still gates it all.
@tool
class_name SignalLiftTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true

	# Authored sheet: self Core signal + custom signal from another node + OnReady body.
	var authored: EventSheetResource = EventSheetResource.new()
	authored.host_class = "Area2D"
	var ready_event: EventRow = EventRow.new()
	ready_event.trigger_provider_id = "Core"
	ready_event.trigger_id = "OnReady"
	ready_event.actions.append(_action("print(\"ready\")"))
	authored.events.append(ready_event)
	var body_event: EventRow = EventRow.new()
	body_event.trigger_provider_id = "Core"
	body_event.trigger_id = "OnBodyEntered"
	body_event.actions.append(_action("queue_free()"))
	authored.events.append(body_event)
	var powered_event: EventRow = EventRow.new()
	powered_event.trigger_provider_id = "PowerPlant"
	powered_event.trigger_id = "signal:powered"
	powered_event.trigger_source_path = "Generator"
	powered_event.trigger_args = "level: int"
	powered_event.actions.append(_action("print(level)"))
	authored.events.append(powered_event)

	var source: String = str(SheetCompiler.compile(authored, "user://eventsheets_signal_lift_src.gd").get("output", ""))
	var imported: EventSheetResource = GDScriptImporter.new().import_external_source(source)
	var lifted: Array[EventRow] = []
	var function_blocks: int = 0
	for row in imported.events:
		if row is EventRow:
			lifted.append(row)
		elif row is RawCodeRow and (row as RawCodeRow).code.begins_with("func "):
			function_blocks += 1
	all_passed = _check("all trigger functions lift (none stay blocks)", function_blocks, 0) and all_passed
	all_passed = _check("three events lifted", lifted.size(), 3) and all_passed
	var ids: Array[String] = []
	for event in lifted:
		ids.append(event.trigger_id)
	all_passed = _check("OnReady survives alongside its connects", ids.has("OnReady"), true) and all_passed
	all_passed = _check("Core signal handler reverses to its trigger id", ids.has("OnBodyEntered"), true) and all_passed
	all_passed = _check("custom signal handler reverses to signal:<name>", ids.has("signal:powered"), true) and all_passed
	for event in lifted:
		if event.trigger_id == "signal:powered":
			all_passed = _check("custom signal source node recovered", event.trigger_source_path, "Generator") and all_passed
			all_passed = _check("custom signal args recovered", event.trigger_args, "level: int") and all_passed
	imported.external_source_path = "user://eventsheets_signal_lift_rt.gd"
	var roundtrip: String = str(SheetCompiler.compile(imported, "user://eventsheets_signal_lift_rt.gd").get("output", ""))
	all_passed = _check("signal lift round-trips byte-identically", roundtrip == source, true) and all_passed

	# Connects-only _ready (no OnReady event): still lifts, still byte-identical.
	var only_signal: EventSheetResource = EventSheetResource.new()
	only_signal.host_class = "Area2D"
	var lone: EventRow = EventRow.new()
	lone.trigger_provider_id = "Core"
	lone.trigger_id = "OnBodyEntered"
	lone.actions.append(_action("queue_free()"))
	only_signal.events.append(lone)
	var lone_source: String = str(SheetCompiler.compile(only_signal, "user://eventsheets_signal_lone_src.gd").get("output", ""))
	var lone_imported: EventSheetResource = GDScriptImporter.new().import_external_source(lone_source)
	var lone_events: int = 0
	var lone_ready_events: int = 0
	for row in lone_imported.events:
		if row is EventRow:
			lone_events += 1
			if (row as EventRow).trigger_id == "OnReady":
				lone_ready_events += 1
	all_passed = _check("connects-only _ready lifts the handler", lone_events, 1) and all_passed
	all_passed = _check("no phantom OnReady event from connects", lone_ready_events, 0) and all_passed
	lone_imported.external_source_path = "user://eventsheets_signal_lone_rt.gd"
	var lone_roundtrip: String = str(SheetCompiler.compile(lone_imported, "user://eventsheets_signal_lone_rt.gd").get("output", ""))
	all_passed = _check("connects-only round-trip byte-identical", lone_roundtrip == lone_source, true) and all_passed

	# A handler with no connect entry (scene-wired) keeps the file as blocks - lossless.
	var unwired: String = "extends Node\n\nfunc _on_mystery(body: Node) -> void:\n\tprint(body)\n"
	var unwired_imported: EventSheetResource = GDScriptImporter.new().import_external_source(unwired)
	var unwired_lifted: bool = false
	for row in unwired_imported.events:
		if row is EventRow:
			unwired_lifted = true
	all_passed = _check("unwired handlers stay verbatim blocks", unwired_lifted, false) and all_passed
	unwired_imported.external_source_path = "user://eventsheets_signal_unwired.gd"
	var unwired_roundtrip: String = str(SheetCompiler.compile(unwired_imported, "user://eventsheets_signal_unwired.gd").get("output", ""))
	all_passed = _check("unwired file still byte-identical", unwired_roundtrip == unwired, true) and all_passed

	# Exit triggers (On Body / Area Exited): codegen via the new resolver arms + round-trip via the lifter.
	var exits: EventSheetResource = EventSheetResource.new()
	exits.host_class = "Area2D"
	var body_exit: EventRow = EventRow.new()
	body_exit.trigger_provider_id = "Core"
	body_exit.trigger_id = "OnBodyExited"
	body_exit.actions.append(_action("print(\"left\")"))
	exits.events.append(body_exit)
	var area_exit: EventRow = EventRow.new()
	area_exit.trigger_provider_id = "Core"
	area_exit.trigger_id = "OnAreaExited"
	area_exit.actions.append(_action("print(\"area left\")"))
	exits.events.append(area_exit)
	var exit_source: String = str(SheetCompiler.compile(exits, "user://eventsheets_exits_src.gd").get("output", ""))
	all_passed = _check("On Body Exited connects body_exited + names the handler",
		exit_source.contains("body_exited.connect(_on_body_exited)") and exit_source.contains("func _on_body_exited(body: Node) -> void:"), true) and all_passed
	all_passed = _check("On Area Exited connects area_exited + names the handler",
		exit_source.contains("area_exited.connect(_on_area_exited)") and exit_source.contains("func _on_area_exited(area: Area2D) -> void:"), true) and all_passed
	var exit_imported: EventSheetResource = GDScriptImporter.new().import_external_source(exit_source)
	var exit_ids: Array[String] = []
	for row in exit_imported.events:
		if row is EventRow:
			exit_ids.append((row as EventRow).trigger_id)
	all_passed = _check("On Body / Area Exited reverse to their trigger ids",
		exit_ids.has("OnBodyExited") and exit_ids.has("OnAreaExited"), true) and all_passed
	exit_imported.external_source_path = "user://eventsheets_exits_rt.gd"
	var exit_roundtrip: String = str(SheetCompiler.compile(exit_imported, "user://eventsheets_exits_rt.gd").get("output", ""))
	all_passed = _check("exit triggers round-trip byte-identically", exit_roundtrip == exit_source, true) and all_passed

	return all_passed


static func _action(template: String) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Test"
	action.ace_id = template
	action.codegen_template = template
	return action


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] signal_lift_test: %s" % label)
		return true
	print("[FAIL] signal_lift_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
