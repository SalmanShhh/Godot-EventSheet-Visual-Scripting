# EventForge - dragging a param's label to scrub its number.
#
# The gesture is only as good as its step: a fixed increment cannot serve both a bullet speed of
# 3000 and an alpha of 0.5, so the step is derived from the value's own magnitude. These pin that
# derivation and the two guarantees around it - an expression is never scrubbable (so no drag can
# flatten `health + 10` into a literal), and an integer never picks up a decimal tail.
@tool
class_name NumberScrubTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true

	# ---- What is willing to be scrubbed at all ----
	ok = _check("a plain integer scrubs", EventSheetNumberScrub.is_scrubbable("250"), true) and ok
	ok = _check("so does a decimal", EventSheetNumberScrub.is_scrubbable("2.5"), true) and ok
	ok = _check("and a negative", EventSheetNumberScrub.is_scrubbable("-3"), true) and ok
	# The whole safety story: an ACE param is a GDScript expression, and overwriting one with a
	# number would silently destroy the author's work.
	ok = _check("an expression does NOT", EventSheetNumberScrub.is_scrubbable("health + 10"), false) and ok
	ok = _check("nor a node path", EventSheetNumberScrub.is_scrubbable("$Player/Gun"), false) and ok
	ok = _check("nor an empty field", EventSheetNumberScrub.is_scrubbable("   "), false) and ok

	# ---- Two significant digits of control, at every magnitude ----
	ok = _check("a 4-digit speed steps by 100", EventSheetNumberScrub.step_for(3000.0, true), 100.0) and ok
	ok = _check("a 3-digit one by 10", EventSheetNumberScrub.step_for(100.0, true), 10.0) and ok
	ok = _check("a 2-digit one by 1", EventSheetNumberScrub.step_for(25.0, true), 1.0) and ok
	ok = _check("the same formula runs below zero", EventSheetNumberScrub.step_for(0.5, false), 0.01) and ok
	ok = _check("and keeps going", EventSheetNumberScrub.step_for(0.05, false), 0.001) and ok
	# An integer count must never acquire a fractional step, however small it is.
	ok = _check("a small integer still steps by a whole 1", EventSheetNumberScrub.step_for(5.0, true), 1.0) and ok
	# log(0) is -inf - a zero field has no magnitude to read.
	ok = _check("zero does not blow up", EventSheetNumberScrub.step_for(0.0, true), 1.0) and ok
	ok = _check("negatives read their magnitude", EventSheetNumberScrub.step_for(-3000.0, true), 100.0) and ok

	# ---- Formatting: no stray decimals in the emitted code ----
	ok = _check("an integer stays an integer", EventSheetNumberScrub.format_value(7.0, 1.0, true), "7") and ok
	ok = _check("a rounded integer too", EventSheetNumberScrub.format_value(6.7, 1.0, true), "7") and ok
	ok = _check("a decimal keeps only what the step can reach",
		EventSheetNumberScrub.format_value(3.14159, 0.01, false), "3.14") and ok
	ok = _check("a coarse step keeps no decimals at all",
		EventSheetNumberScrub.format_value(3040.0, 100.0, false), "3000") and ok
	ok = _check("and snaps to its own grid",
		EventSheetNumberScrub.format_value(3060.0, 100.0, false), "3100") and ok

	# ---- Reading and writing every field kind the dialog builds ----
	var line_edit: LineEdit = LineEdit.new()
	line_edit.text = "42"
	ok = _check("reads a LineEdit", EventSheetNumberScrub.read_value(line_edit), "42") and ok
	EventSheetNumberScrub.write_value(line_edit, "84")
	ok = _check("and writes one", line_edit.text, "84") and ok
	line_edit.free()

	# The expression field is a CodeEdit, which is exactly why the drag lives on the label: this
	# control's own left-drag is text selection.
	var code_edit: CodeEdit = CodeEdit.new()
	code_edit.text = "1.5"
	ok = _check("reads a CodeEdit", EventSheetNumberScrub.read_value(code_edit), "1.5") and ok
	EventSheetNumberScrub.write_value(code_edit, "2.5")
	ok = _check("and writes one", code_edit.text, "2.5") and ok
	code_edit.free()

	var spin: SpinBox = SpinBox.new()
	spin.allow_greater = true
	spin.value = 12.0
	EventSheetNumberScrub.write_value(spin, "30")
	ok = _check("and drives a SpinBox by value", spin.value, 30.0) and ok
	spin.free()

	# ---- Wrapped fields, which is nearly all of them ----
	# An expression param (the overwhelmingly common kind) is an HBox holding a CodeEdit next to its
	# ƒx and node-picker buttons. Matching only bare controls silently skipped ~800 params and left
	# scrubbing working on the few dozen declared int/float - caught by the render preview, where
	# the value simply did not move.
	var wrapper: HBoxContainer = HBoxContainer.new()
	var inner: CodeEdit = CodeEdit.new()
	inner.text = "250"
	wrapper.add_child(inner)
	wrapper.add_child(Button.new())
	ok = _check("resolves the editor inside a wrapper", EventSheetNumberScrub.resolve_field(wrapper), inner) and ok
	ok = _check("and reads through it", EventSheetNumberScrub.read_value(wrapper), "250") and ok
	EventSheetNumberScrub.write_value(wrapper, "450")
	ok = _check("and writes through it", inner.text, "450") and ok
	wrapper.free()
	var buttons_only: HBoxContainer = HBoxContainer.new()
	buttons_only.add_child(Button.new())
	ok = _check("a wrapper with nothing to edit resolves to null",
		EventSheetNumberScrub.resolve_field(buttons_only), null) and ok
	buttons_only.free()

	# ---- attach() is safe to call for anything ----
	# The params dialog calls it for every row, so a control holding no number must be ignored
	# rather than special-cased at each call site.
	var label: Label = Label.new()
	var dropdown: OptionButton = OptionButton.new()
	EventSheetNumberScrub.attach(label, dropdown)
	ok = _check("a dropdown is left alone", label.gui_input.get_connections().is_empty(), true) and ok
	var numeric_field: LineEdit = LineEdit.new()
	numeric_field.text = "10"
	EventSheetNumberScrub.attach(label, numeric_field)
	ok = _check("a text field is wired up", label.gui_input.get_connections().size(), 1) and ok
	label.free()
	dropdown.free()
	numeric_field.free()

	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if typeof(actual) == TYPE_FLOAT and typeof(expected) == TYPE_FLOAT:
		if is_equal_approx(actual as float, expected as float):
			print("[PASS] number_scrub_test: %s" % label)
			return true
	elif actual == expected:
		print("[PASS] number_scrub_test: %s" % label)
		return true
	print("[FAIL] number_scrub_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
