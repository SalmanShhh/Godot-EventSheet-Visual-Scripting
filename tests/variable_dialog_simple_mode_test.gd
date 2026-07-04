# Godot EventSheets - Simple Mode finally reaches the Variable dialog
# (v0.11 chapter 2, P3). In Simple Mode the Advanced tier (show-if, lock-unless,
# on-changed, clamp, read-only, grouping fields) stays out of sight: it is wiring,
# not looks. Display-only: attributes already on a variable still round-trip, and
# the tier returns the moment Simple Mode turns off.
@tool
class_name VariableDialogSimpleModeTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(EventSheetResource.new())
	var dialog: VariableDialog = dock._variable_dlg
	ok = _check("dock wires the provider", dialog.simple_mode_provider.is_valid(), true) and ok

	# Exported variable, expert mode: the Advanced toggle is offered.
	dock._simple_mode = false
	dialog._exported_check.button_pressed = true
	dialog._update_attr_gating()
	ok = _check("expert mode offers the Advanced tier", dialog._attr_advanced_toggle.visible, true) and ok

	# Simple Mode: the whole Advanced tier disappears, even if it was expanded.
	dock._simple_mode = true
	dialog._attr_advanced_section.visible = true
	dialog._update_attr_gating()
	ok = _check("Simple Mode hides the Advanced toggle", dialog._attr_advanced_toggle.visible, false) and ok
	ok = _check("Simple Mode collapses the Advanced section", dialog._attr_advanced_section.visible, false) and ok

	# Turning Simple Mode off brings the tier straight back.
	dock._simple_mode = false
	dialog._update_attr_gating()
	ok = _check("the tier returns when Simple Mode ends", dialog._attr_advanced_toggle.visible, true) and ok

	dock.free()
	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] variable_dialog_simple_mode_test: %s" % label)
		return true
	print("[FAIL] variable_dialog_simple_mode_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
