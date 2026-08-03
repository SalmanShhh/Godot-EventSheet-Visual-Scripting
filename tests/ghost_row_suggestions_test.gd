# EventSheet - Ghost Row Part II: the usage store (record / count / trim determinism), the
# learn-as-you-type tie-break (equal-score order FLIPS after use - red-before/green-after in one
# test), the summoning key's kind nudge, and the before-you-type suggestion chips (featured
# fallback cold, most-used first warm, chip click applies through the shared flow).
@tool
class_name GhostRowSuggestionsTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true
	EventSheetAceUsageStats.reset_for_tests()

	# ── The store's values ──
	ok = _check("an unknown verb counts zero", EventSheetAceUsageStats.count_for("Core", "Wait"), 0) and ok
	EventSheetAceUsageStats.record("Core", "Wait")
	EventSheetAceUsageStats.record("Core", "Wait")
	ok = _check("recording counts up", EventSheetAceUsageStats.count_for("Core", "Wait"), 2) and ok
	EventSheetAceUsageStats.record("", "")
	ok = _check("an empty identity never records", EventSheetAceUsageStats.count_for("", ""), 0) and ok
	# The trim keeps the most-used entries and is deterministic among equal counts.
	EventSheetAceUsageStats.reset_for_tests()
	for index: int in range(EventSheetAceUsageStats.MAX_ENTRIES + 1):
		EventSheetAceUsageStats.record("P", "ace_%03d" % index)
	EventSheetAceUsageStats.record("P", "ace_000")
	ok = _check("the store stays bounded after the trim",
		EventSheetAceUsageStats._cache.size() <= EventSheetAceUsageStats.TRIM_TO + 1, true) and ok
	ok = _check("the most-used entry survives the trim", EventSheetAceUsageStats.count_for("P", "ace_000") >= 1, true) and ok

	# ── The dock-backed pieces ──
	EventSheetAceUsageStats.reset_for_tests()
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnProcess"
	sheet.events.append(event)
	dock.setup(sheet)

	# Learn-as-you-type: "process" leaves OnProcess and OnPhysicsProcess in the same score band,
	# where the shorter name wins cold - until the LONGER one is what the user actually applies.
	var cold: Array = dock._quick_match_ranked("process", 5)
	ok = _check("cold, the shorter name wins the band",
		str(((cold[0] as Dictionary).get("definition") as ACEDefinition).id), "OnProcess") and ok
	EventSheetAceUsageStats.record("Core", "OnPhysicsProcess")
	var warm: Array = dock._quick_match_ranked("process", 5)
	ok = _check("after use, the applied verb wins the same band",
		str(((warm[0] as Dictionary).get("definition") as ACEDefinition).id), "OnPhysicsProcess") and ok

	# The kind nudge is exactly +5, INSIDE a band: "heal" matches actions either way, so the
	# preferred run's top score is the plain run's plus the nudge - never a band jump.
	EventSheetAceUsageStats.reset_for_tests()
	var plain_top: Dictionary = dock._quick_match_ranked("heal", 1)[0]
	var nudged_top: Dictionary = dock._quick_match_ranked("heal", 1, ACEDefinition.ACEType.ACTION)[0]
	ok = _check("the summoning kind earns exactly +5",
		int(nudged_top.get("score")), int(plain_top.get("score")) + 5) and ok
	ok = _check("the nudged winner is that kind",
		(nudged_top.get("definition") as ACEDefinition).ace_type == ACEDefinition.ACEType.ACTION, true) and ok

	# ── Applies feed the store (the funnel records) ──
	var view: EventSheetViewport = dock._active_view()
	for index: int in range(view.get_flat_rows().size()):
		var row_data: EventRowData = view.get_flat_rows()[index].get("row")
		if row_data != null and row_data.source_resource == event:
			view._selected_row_index = index
	dock._ghost_row.open("action")
	dock._ghost_row._refresh("heal 5")
	var applied: ACEDefinition = (dock._ghost_row._candidates[0] as Dictionary).get("definition")
	dock._ghost_row._apply_selected()
	ok = _check("a ghost-row apply records one use",
		EventSheetAceUsageStats.count_for(applied.provider_id, applied.id), 1) and ok

	# ── Suggestion chips ──
	# Warm: the just-used verb leads the action chips.
	dock._ghost_row.open("action")
	var chip_ids: Array = []
	for definition: ACEDefinition in dock._ghost_row._chip_definitions:
		chip_ids.append(definition.id)
	ok = _check("the used verb leads the warm chips", str(chip_ids[0]) if chip_ids.size() > 0 else "", applied.id) and ok
	# Cold: featured verbs of the summoning kind stand in, and every chip IS that kind.
	EventSheetAceUsageStats.reset_for_tests()
	var trigger_chips: Array = dock._quick_suggestions("event", 4)
	ok = _check("cold chips exist (featured fallback)", trigger_chips.size() > 0, true) and ok
	var kinds_right: bool = true
	for definition: ACEDefinition in trigger_chips:
		if definition.ace_type != ACEDefinition.ACEType.TRIGGER:
			kinds_right = false
	ok = _check("every event-key chip is a trigger", kinds_right, true) and ok
	var condition_chips: Array = dock._quick_suggestions("condition", 4)
	kinds_right = true
	for definition: ACEDefinition in condition_chips:
		if definition.ace_type != ACEDefinition.ACEType.CONDITION:
			kinds_right = false
	ok = _check("every C-key chip is a condition", kinds_right, true) and ok

	# A chip click applies through the shared flow: the action lands on the selected event.
	var live_event: EventRow = null
	for row: Variant in dock.get_current_sheet().events:
		if row is EventRow:
			live_event = row
	var actions_before: int = live_event.actions.size()
	dock._ghost_row.open("action")
	var chip_definition: ACEDefinition = dock._ghost_row._chip_definitions[0]
	dock._ghost_row._apply_definition(chip_definition, {})
	live_event = null
	for row: Variant in dock.get_current_sheet().events:
		if row is EventRow:
			live_event = row
	ok = _check("a chip apply lands on the selected event", live_event.actions.size(), actions_before + 1) and ok
	ok = _check("the chip apply recorded a use",
		EventSheetAceUsageStats.count_for(chip_definition.provider_id, chip_definition.id), 1) and ok

	EventSheetAceUsageStats.reset_for_tests()
	dock.free()
	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] ghost_row_suggestions_test: %s" % label)
		return true
	print("[FAIL] ghost_row_suggestions_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
