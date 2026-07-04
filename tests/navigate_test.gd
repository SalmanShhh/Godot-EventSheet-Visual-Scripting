# EventForge - Ctrl+Click go-to-definition. An addon ACE's provider_id is its script's class_name, so a
# consumer sheet's "Stop Car" cell resolves to eventsheet_addons/car/car_behavior.gd and Ctrl+Click opens
# that behaviour AS A SHEET; Core built-ins resolve to nothing (their cells keep multi-select). Pins the
# class→path map, the per-cell probe, and the end-to-end jump on a real dock.
@tool
class_name NavigateTest
extends RefCounted

const CAR_PATH := "res://eventsheet_addons/car/car_behavior.gd"


static func run() -> bool:
	var ok: bool = true

	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnReady"
	var car_action: ACEAction = ACEAction.new()
	car_action.provider_id = "CarBehavior"
	car_action.ace_id = "stop_car"
	event.actions.append(car_action)
	var core_action: ACEAction = ACEAction.new()
	core_action.provider_id = "Core"
	core_action.ace_id = "MoveAndSlide"
	event.actions.append(core_action)
	sheet.events.append(event)
	dock.setup(sheet)

	# The class→path map reads the addon scripts' class_name lines.
	ok = _check("CarBehavior resolves to its script", dock._navigate._script_path_for_class("CarBehavior"), CAR_PATH) and ok
	ok = _check("an unknown class resolves to nothing", dock._navigate._script_path_for_class("NoSuchBehavior"), "") and ok

	# Per-cell probe: the addon verb navigates, the Core verb and non-ACE spans don't.
	var view: EventSheetViewport = dock._active_view()
	var row_data: EventRowData = null
	for entry: Dictionary in view.get_flat_rows():
		var candidate: EventRowData = entry.get("row")
		if candidate != null and candidate.source_resource == event:
			row_data = candidate
	view._ensure_event_spans(row_data)
	var car_meta: Dictionary = {}
	var core_meta: Dictionary = {}
	for span: SemanticSpan in row_data.spans:
		if str((span.metadata as Dictionary).get("kind", "")) == "action":
			var ace_index: int = int((span.metadata as Dictionary).get("ace_index", -1))
			if ace_index == 0:
				car_meta = span.metadata
			elif ace_index == 1:
				core_meta = span.metadata
	ok = _check("found the two action spans", not car_meta.is_empty() and not core_meta.is_empty(), true) and ok
	ok = _check("the addon verb is navigable", dock._navigate.can_navigate(row_data, car_meta), true) and ok
	ok = _check("the Core verb is not (keeps multi-select)", dock._navigate.can_navigate(row_data, core_meta), false) and ok
	ok = _check("a non-ACE span is not navigable", dock._navigate.can_navigate(row_data, {"kind": "comment"}), false) and ok
	var target: Dictionary = dock._navigate.resolve_target(row_data, car_meta)
	ok = _check("the target is the car behaviour sheet", str(target.get("path", "")), CAR_PATH) and ok

	# The jump itself: Ctrl+Click opens the behaviour AS A SHEET (lossless .gd-as-events open).
	dock._navigate.navigate(row_data, -1, car_meta)
	var opened: EventSheetResource = dock.get_current_sheet()
	ok = _check("the car behaviour opened as the current sheet",
		opened != null and opened.external_source_path == CAR_PATH, true) and ok
	ok = _check("it opened as a behaviour (host recovered)",
		opened != null and opened.behavior_mode and opened.host_class == "CharacterBody2D", true) and ok

	dock.free()
	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] navigate_test: %s" % label)
		return true
	print("[FAIL] navigate_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
