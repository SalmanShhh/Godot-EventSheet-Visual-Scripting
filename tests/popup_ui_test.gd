# EventSheet — shared popup UI helpers (consistent dialog look).
# Verifies the pure factory helpers produce the expected control structure.
@tool
extends RefCounted
class_name PopupUITest

static func run() -> bool:
	var all_passed: bool = true

	# form_row: an aligned "Label  [field]" row.
	var field: LineEdit = LineEdit.new()
	var row: HBoxContainer = EventSheetPopupUI.form_row("Name", field)
	all_passed = _check("form_row holds a label + the field", row.get_child_count(), 2) and all_passed
	var label: Label = row.get_child(0) as Label
	all_passed = _check("form_row label carries the text", label.text, "Name") and all_passed
	all_passed = _check("form_row label has a fixed leading width", label.custom_minimum_size.x, EventSheetPopupUI.LABEL_MIN_WIDTH) and all_passed
	all_passed = _check("form_row field expands to fill", (row.get_child(1) as Control).size_flags_horizontal, Control.SIZE_EXPAND_FILL) and all_passed
	row.free()

	# margined: standard breathing room around content.
	var content: Label = Label.new()
	var margined: MarginContainer = EventSheetPopupUI.margined(content)
	all_passed = _check("margined wraps the content", margined.get_child(0) == content, true) and all_passed
	all_passed = _check("margined applies margins on every side",
		margined.has_theme_constant_override("margin_left") and margined.has_theme_constant_override("margin_bottom"), true) and all_passed
	margined.free()

	# form_box + hint_label.
	var box: VBoxContainer = EventSheetPopupUI.form_box()
	all_passed = _check("form_box sets a row-separation override", box.has_theme_constant_override("separation"), true) and all_passed
	box.free()
	var hint: Label = EventSheetPopupUI.hint_label("note")
	all_passed = _check("hint_label text", hint.text, "note") and all_passed
	all_passed = _check("hint_label is muted", hint.modulate.a < 1.0, true) and all_passed
	hint.free()

	# Keyboard Shortcuts editor (Tools ▸ Keyboard Shortcuts): the rebindable action list + the
	# read-only fixed-keys reference are both populated.
	all_passed = _check("rebindable shortcut list is populated", EventSheetShortcuts.ORDER.size() >= 4, true) and all_passed
	all_passed = _check("rebindable action labels resolve", EventSheetShortcuts.label_for("add_event"), "Add event") and all_passed
	var flat: String = ""
	for pair: Array in EventSheetDock.FIXED_KEYS:
		flat += str(pair[0]) + " | " + str(pair[1]) + "\n"
	all_passed = _check("fixed-keys reference lists the Command Palette", flat.contains("Ctrl + P") and flat.contains("Command Palette"), true) and all_passed
	all_passed = _check("fixed-keys reference lists Find & Replace", flat.contains("Ctrl + F"), true) and all_passed

	return all_passed

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] popup_ui_test: %s" % label)
		return true
	print("[FAIL] popup_ui_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
