# Godot EventSheets - the bbcode_text rich param (Discord-style formatting)
# Select part of a BBCode param and hit B / I / U / S: the selection wraps in the matching
# tag, toggling back off when already wrapped, never breaking the string literal the param
# compiles into. Pins: the pure wrap kernel (wrap, both toggle-off shapes, caret insert,
# quote refusal, arged tags closing bare, reversed selections) and the wiring (the hint is
# registered, Print Rich carries it).
@tool
class_name BBCodeParamTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true
	var dialog := ACEParamsDialog

	# ---- wrap ----
	var wrapped: Dictionary = dialog.bbcode_wrap_selection("\"hello world\"", 1, 6, "b")
	all_passed = _check("a selection wraps in the tag", wrapped.get("text"), "\"[b]hello[/b] world\"") and all_passed
	all_passed = _check("the selection tracks the moved text", [int(wrapped.get("from")), int(wrapped.get("to"))], [4, 9]) and all_passed

	# ---- toggle off, selection-is-wrapped ----
	var untoggled: Dictionary = dialog.bbcode_wrap_selection("\"[b]hello[/b] world\"", 1, 13, "b")
	all_passed = _check("selecting the whole wrapped run unwraps it", untoggled.get("text"), "\"hello world\"") and all_passed

	# ---- toggle off, tags-surround-selection ----
	var surrounded: Dictionary = dialog.bbcode_wrap_selection("\"[b]hello[/b] world\"", 4, 9, "b")
	all_passed = _check("selecting the inner text unwraps the surround", surrounded.get("text"), "\"hello world\"") and all_passed
	all_passed = _check("the unwrapped selection lands on the text", [int(surrounded.get("from")), int(surrounded.get("to"))], [1, 6]) and all_passed

	# ---- caret only: an empty pair with the caret inside ----
	var inserted: Dictionary = dialog.bbcode_wrap_selection("\"hi\"", 3, 3, "i")
	all_passed = _check("no selection inserts an empty pair", inserted.get("text"), "\"hi[i][/i]\"") and all_passed
	all_passed = _check("the caret sits between the tags", int(inserted.get("from")), 6) and all_passed

	# ---- the literal stays intact: a selection containing a quote is refused ----
	var refused: Dictionary = dialog.bbcode_wrap_selection("\"hello\"", 0, 3, "b")
	all_passed = _check("a selection crossing the quote is refused", refused.get("text"), "\"hello\"") and all_passed

	# ---- arged tags close bare ----
	var colored: Dictionary = dialog.bbcode_wrap_selection("\"hot\"", 1, 4, "color=red")
	all_passed = _check("an arged tag closes with the bare name", colored.get("text"), "\"[color=red]hot[/color]\"") and all_passed

	# ---- reversed selections normalize ----
	var reversed_selection: Dictionary = dialog.bbcode_wrap_selection("\"hello\"", 6, 1, "u")
	all_passed = _check("a reversed selection wraps the same", reversed_selection.get("text"), "\"[u]hello[/u]\"") and all_passed

	# ---- wiring: Print Rich rides the hint ----
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", "PrintRich")
	all_passed = _check("Print Rich exists", descriptor != null, true) and all_passed
	if descriptor != null:
		all_passed = _check("its value param carries the bbcode_text hint", (descriptor.params[0] as ACEParam).hint, "bbcode_text") and all_passed

	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		return true
	print("  [FAIL] bbcode_param_test: %s (got %s, expected %s)" % [label, str(actual), str(expected)])
	return false
