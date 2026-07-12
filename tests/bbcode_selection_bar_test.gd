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

	# ── Floating mode: pure UI - button presses route to the host via format_requested.
	var host: Control = Control.new()
	var floating: EventSheetBBCodeSelectionBar = EventSheetBBCodeSelectionBar.attach_floating(host)
	all_passed = _check("floating bar attaches hidden", floating.visible, false) and all_passed
	var routed: Array = []
	floating.format_requested.connect(func(open_tag: String, close_tag: String) -> void: routed.append([open_tag, close_tag]))
	floating._wrap_selection("[b]", "[/b]")
	all_passed = _check("floating mode routes the wrap to the host", routed, [["[b]", "[/b]"]]) and all_passed
	host.free()

	# ── The inline comment editor (custom-drawn viewport buffer): same wrap semantics
	# through the viewport's own selection model (Shift+arrows / Ctrl+A set anchor..caret).
	var viewport: EventSheetViewport = EventSheetViewport.new()
	viewport._editing_row_index = 0
	viewport._editing_buffer = "make it pop"
	viewport._editing_select_anchor = 5
	viewport._editing_caret = 7
	all_passed = _check("inline selection is live", viewport._editing_has_selection(), true) and all_passed
	viewport._wrap_editing_selection("[b]", "[/b]")
	all_passed = _check("inline bold wraps the selection", viewport._editing_buffer, "make [b]it[/b] pop") and all_passed
	all_passed = _check("inline wrap keeps the result selected", viewport._editing_selection_range(), Vector2i(5, 14)) and all_passed
	viewport._wrap_editing_selection("[i]", "[/i]")
	all_passed = _check("inline formats stack", viewport._editing_buffer, "make [i][b]it[/b][/i] pop") and all_passed
	viewport._wrap_editing_selection("[i]", "[/i]")
	viewport._wrap_editing_selection("[b]", "[/b]")
	all_passed = _check("inline re-press unwraps back to plain", viewport._editing_buffer, "make it pop") and all_passed
	viewport._delete_editing_selection()
	all_passed = _check("inline selection deletes as one unit", viewport._editing_buffer, "make  pop") and all_passed
	all_passed = _check("delete collapses the selection", viewport._editing_has_selection(), false) and all_passed
	viewport.free()

	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] bbcode_selection_bar_test: %s" % label)
		return true
	print("[FAIL] bbcode_selection_bar_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
