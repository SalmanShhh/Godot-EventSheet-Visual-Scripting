# Godot EventSheets — dialogs must not balloon on launch.
#
# A ConfirmationDialog/AcceptDialog sizes itself to its content's MINIMUM. An autowrap Label with no
# bounded width reports a runaway one-glyph-per-line minimum height during the initial zero-width
# pass, which balloons the whole popup to thousands of px tall when it opens (the "Edit GDScript
# Block" popup did exactly this). The fix is to give every wrapping label a custom_minimum_size.x.
#
# This pins the invariant: in the plugin's content-sized dialogs, every autowrap Label that we add
# is width-bounded. The dialog's OWN built-in message label (AcceptDialog.get_label()) is excluded —
# the dialog manages and sizes that one itself, so it never balloons.
@tool
extends RefCounted
class_name DialogBalloonTest

static func run() -> bool:
	var all_passed: bool = true

	# The shared helper is the root cause we hardened: hint_label() must bound its width.
	var hint: Label = EventSheetPopupUI.hint_label("A fairly long hint sentence that would wrap to one glyph per line at width zero and balloon a dialog.")
	all_passed = _check("hint_label() is width-bounded", hint.custom_minimum_size.x > 0.0, true) and all_passed
	all_passed = _check("hint_label() still autowraps", hint.autowrap_mode != TextServer.AUTOWRAP_OFF, true) and all_passed
	var narrow_hint: Label = EventSheetPopupUI.hint_label("x", 200.0)
	all_passed = _check("hint_label() honours a custom wrap width", narrow_hint.custom_minimum_size.x, 200.0) and all_passed

	# Build the dock dialogs the balloon fix touched and assert none contain an unbounded autowrap
	# label. _ensure_*() build the UI without needing a loaded sheet.
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.setup(null)
	dock._ensure_raw_code_dialog()
	dock._ensure_with_node_dialog()
	dock._ensure_sheet_type_dialog()
	dock._ensure_enum_dialog()
	dock._ensure_signal_dialog()
	dock._ensure_match_dialog()
	dock._welcome._build()  # the first-launch dialog (now dock/welcome_window.gd) — an autowrap blurb here ballooned it to ~5000px
	for probe: Array in [
		["Edit GDScript Block", dock._raw_code_dialog],
		["Scope Actions To Node", dock._with_node_dialog],
		["Sheet Type", dock._sheet_type_dialog],
		["Edit Enum", dock._enum_dialog],
		["Edit Signal", dock._signal_dialog],
		["Edit Match", dock._match_dialog],
		["Welcome", dock._welcome._welcome_window],
	]:
		var unbounded: Array[String] = _unbounded_autowrap_labels(probe[1] as Window)
		all_passed = _check("%s has no unbounded autowrap label" % probe[0], unbounded, [] as Array[String]) and all_passed
	dock.free()

	# The function dialog's validation/problem label is autowrap and shows on error — bound too.
	var fn_parent: Node = Node.new()
	var fn_dialog: EventSheetFunctionDialog = EventSheetFunctionDialog.new()
	fn_dialog.init_dialog(fn_parent)
	all_passed = _check("function dialog problem label is width-bounded",
		fn_dialog._problem_label.custom_minimum_size.x > 0.0, true) and all_passed
	fn_parent.free()

	return all_passed

## Recursively collects the names of autowrap Labels under `dialog` that have NO width bound
## (custom_minimum_size.x ~ 0). The dialog's built-in message label is excluded — AcceptDialog
## sizes that one to the dialog width itself, so it cannot balloon.
static func _unbounded_autowrap_labels(dialog: Window) -> Array[String]:
	var offenders: Array[String] = []
	var builtin_label: Label = null
	if dialog is AcceptDialog:
		builtin_label = (dialog as AcceptDialog).get_label()
	var stack: Array[Node] = [dialog]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is Label:
			var label: Label = node as Label
			if label != builtin_label and label.autowrap_mode != TextServer.AUTOWRAP_OFF and label.custom_minimum_size.x <= 0.5:
				offenders.append('"%s"' % label.text.substr(0, 30))
		for child: Node in node.get_children():
			stack.push_back(child)
	return offenders

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] dialog_balloon_test: %s" % label)
		return true
	print("[FAIL] dialog_balloon_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
