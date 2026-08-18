# Godot EventSheets - inline colour-swatch picker (event-sheet style).
#
# Clicking the colour swatch drawn on a condition/action cell opens a ColorPicker right there (no dialog)
# and writes the chosen colour back into the ACE's Color param. Pins: finding WHICH param holds the
# colour, literal round-trip fidelity, the SAVED PALETTE store (dedupe / cap / removal / picker
# wiring both ways), the swatch hover hand-cursor predicate, and the whole commit path through the
# real undo funnel onto the LIVE sheet.
@tool
class_name ColorSwatchPickerTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true
	var viewport: EventSheetViewport = EventSheetViewport.new()

	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "SetModulateColor"
	action.params = {"target": "$Sprite2D", "color": "Color(1, 0, 0, 1)"}

	all_passed = _check("finds the Color param's key", viewport._first_color_param_id(action), "color") and all_passed
	var read_color: Variant = viewport._first_color_in_params(action)
	all_passed = _check("reads the swatch Color value",
		read_color is Color and (read_color as Color).is_equal_approx(Color(1, 0, 0, 1)), true) and all_passed

	var no_color: ACEAction = ACEAction.new()
	no_color.params = {"x": "5", "name": "\"hi\""}
	all_passed = _check("an ACE with no Color param yields an empty key",
		viewport._first_color_param_id(no_color), "") and all_passed

	# The picked colour must round-trip through color_to_literal -> str_to_var (write-back fidelity).
	var picked: Color = Color(0.25, 0.5, 0.75, 1.0)
	var literal: String = ACEParamsDialog.color_to_literal(picked)
	var parsed: Variant = str_to_var(literal)
	all_passed = _check("color_to_literal emits a Color(...) literal", literal.begins_with("Color("), true) and all_passed
	all_passed = _check("the written colour round-trips losslessly",
		parsed is Color and (parsed as Color).is_equal_approx(picked), true) and all_passed

	# ── The saved palette store (the event-sheet swatch shelf) ──
	EventSheetColorPresets.reset_for_tests()
	all_passed = _check("the shelf starts empty", EventSheetColorPresets.all().size(), 0) and all_passed
	EventSheetColorPresets.add(Color.RED)
	EventSheetColorPresets.add(Color.SEA_GREEN)
	EventSheetColorPresets.add(Color.RED)
	all_passed = _check("saving dedupes by value (re-save keeps one entry)",
		EventSheetColorPresets.all().size(), 2) and all_passed
	EventSheetColorPresets.remove(Color.SEA_GREEN)
	var shelf: PackedColorArray = EventSheetColorPresets.all()
	all_passed = _check("removal leaves exactly the other colour",
		shelf.size() == 1 and shelf[0].is_equal_approx(Color.RED), true) and all_passed
	EventSheetColorPresets.reset_for_tests()
	for index: int in range(EventSheetColorPresets.MAX_PRESETS + 5):
		EventSheetColorPresets.add(Color(float(index) / 64.0, 0.5, 0.5))
	all_passed = _check("the shelf stays capped", EventSheetColorPresets.all().size(),
		EventSheetColorPresets.MAX_PRESETS) and all_passed

	# ── The swatch hover predicate (drives the hand cursor) ──
	var over: Dictionary = {"span_metadata": {"swatch_rect": Rect2(10, 10, 16, 16)}}
	all_passed = _check("hovering inside the swatch reads as over it",
		viewport._input_handlers._over_color_swatch(over, Vector2(12, 12)), true) and all_passed
	all_passed = _check("hovering outside the swatch reads as not over it",
		viewport._input_handlers._over_color_swatch(over, Vector2(40, 12)), false) and all_passed
	all_passed = _check("a span without a swatch never matches",
		viewport._input_handlers._over_color_swatch({"span_metadata": {}}, Vector2(12, 12)), false) and all_passed
	viewport.free()

	# ── End to end: open (headless-safe) -> picker carries the shelf -> close commits ──
	EventSheetColorPresets.reset_for_tests()
	EventSheetColorPresets.add(Color.ORANGE)
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnProcess"
	var tint: ACEAction = ACEAction.new()
	tint.provider_id = "Core"
	tint.ace_id = "SetModulateColor"
	tint.params = {"target": "$Sprite2D", "color": "Color(1, 0, 0, 1)"}
	event.actions.append(tint)
	sheet.events.append(event)
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	editor.setup(sheet)
	var live_action: ACEAction = _live_color_action(editor)
	editor._inline_params.on_color_swatch_edit_requested(live_action, "color", Color(1, 0, 0, 1))
	var picker: ColorPicker = editor._inline_params._color_swatch_picker
	all_passed = _check("the opened picker carries the saved shelf",
		picker.get_presets().size() == 1 and picker.get_presets()[0].is_equal_approx(Color.ORANGE), true) and all_passed
	all_passed = _check("the picker starts on the cell's current colour",
		picker.color.is_equal_approx(Color(1, 0, 0, 1)), true) and all_passed
	# Saving a preset in the picker lands on the persistent shelf (the signal wiring).
	picker.preset_added.emit(Color.DODGER_BLUE)
	all_passed = _check("a preset saved in the picker lands on the shelf",
		EventSheetColorPresets.all().size(), 2) and all_passed
	# Closing commits ONCE through the undo funnel onto the LIVE sheet.
	editor._inline_params._commit_color_swatch_edit(Color(0.2, 0.6, 0.9, 1.0))
	live_action = _live_color_action(editor)
	all_passed = _check("closing the picker writes the colour literal onto the live ACE",
		str(live_action.params.get("color", "")), ACEParamsDialog.color_to_literal(Color(0.2, 0.6, 0.9, 1.0))) and all_passed
	EventSheetColorPresets.reset_for_tests()
	editor.free()
	return all_passed


## The LIVE colour action - re-fetched from the current sheet every time, because the undo
## funnel's commit replaces resources with snapshot duplicates.
static func _live_color_action(editor: EventSheetEditor) -> ACEAction:
	for row: Variant in editor.get_current_sheet().events:
		if row is EventRow:
			for action: Variant in (row as EventRow).actions:
				if action is ACEAction and (action as ACEAction).ace_id == "SetModulateColor":
					return action
	return null


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] color_swatch_picker_test: %s" % label)
		return true
	print("[FAIL] color_swatch_picker_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
