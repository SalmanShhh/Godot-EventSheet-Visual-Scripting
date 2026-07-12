# Godot EventSheets - the Discord-style BBCode selection bar (comment dialog): highlight
# text, a small unfocused bar wraps the selection in BBCode. Pins the wrap/unwrap toggle,
# format stacking via re-selection, the color-tag unwrap, and the keep-selection contract.
@tool
class_name BBCodeSelectionBarTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true

	var text_edit: TextEdit = TextEdit.new()
	var bar: EventSheetBBCodeSelectionBar = EventSheetBBCodeSelectionBar.attach(text_edit)
	all_passed = _check("bar attaches hidden", bar.visible, false) and all_passed
	all_passed = _check("selection survives focus loss (the color picker contract)",
		text_edit.deselect_on_focus_loss_enabled, false) and all_passed

	# Wrap: the selected word gains the tags and STAYS SELECTED (so formats stack).
	text_edit.text = "make it pop"
	text_edit.select(0, 5, 0, 7)
	bar._wrap_selection("[b]", "[/b]")
	all_passed = _check("bold wraps the selection", text_edit.text, "make [b]it[/b] pop") and all_passed
	all_passed = _check("the wrapped text stays selected", text_edit.get_selected_text(), "[b]it[/b]") and all_passed

	# Stacking: a second format wraps around the first.
	bar._wrap_selection("[i]", "[/i]")
	all_passed = _check("formats stack", text_edit.text, "make [i][b]it[/b][/i] pop") and all_passed

	# Toggle off: the same button on an exactly-wrapped selection unwraps (Discord behavior).
	bar._wrap_selection("[i]", "[/i]")
	all_passed = _check("re-pressing unwraps", text_edit.text, "make [b]it[/b] pop") and all_passed
	bar._wrap_selection("[b]", "[/b]")
	all_passed = _check("unwrap restores the plain text", text_edit.text, "make it pop") and all_passed
	all_passed = _check("the inner text stays selected after unwrap", text_edit.get_selected_text(), "it") and all_passed

	# Color: any [color=...] wrap counts as wrapped, whatever the hex, so the toggle works.
	bar._wrap_selection("[color=#ff8800]", "[/color]")
	all_passed = _check("color wraps with the hex", text_edit.text, "make [color=#ff8800]it[/color] pop") and all_passed
	bar._wrap_selection("[color=#00ff00]", "[/color]")
	all_passed = _check("a second color unwraps (toggle semantics)", text_edit.text, "make it pop") and all_passed

	# No selection: a safe no-op.
	text_edit.deselect()
	bar._wrap_selection("[b]", "[/b]")
	all_passed = _check("no selection is a no-op", text_edit.text, "make it pop") and all_passed

	text_edit.free()
	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] bbcode_selection_bar_test: %s" % label)
		return true
	print("[FAIL] bbcode_selection_bar_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
