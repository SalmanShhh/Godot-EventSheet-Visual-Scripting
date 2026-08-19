# Godot EventSheets - the shared per-hint parameter widgets.
#
# The colour swatch, the enum dropdown, the node picker, the Input Map picker and the rest used to be
# reachable from exactly one place - the Edit Parameter dialog - so the Properties bar showed the
# same parameters of the same row through one untyped text box, and editing a colour there meant
# typing `Color("#ff9b3c")` by hand. This pins that the shared door hands back the RIGHT WIDGET per
# hint, and that a value read back out of one is the literal the dialog would have committed.
@tool
class_name ParamFieldFactoryTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _test_widget_per_hint() and all_passed
	all_passed = _test_value_round_trip() and all_passed
	all_passed = _test_change_signals() and all_passed
	return all_passed


## Each hint gets its own widget, and an unknown hint still gets a usable field rather than nothing -
## a caller never has to ask whether a parameter is "supported".
static func _test_widget_per_hint() -> bool:
	var passed: bool = true
	var factory: EventSheetParamFieldFactory = EventSheetParamFieldFactory.new()
	passed = _check("a colour parameter is a swatch",
		_class_of(factory, {"id": "tint", "type": TYPE_COLOR, "hint": "color"}, "Color(1, 0.6, 0.2, 1)"),
		"ColorPickerButton") and passed
	passed = _check("a fixed-option parameter is a dropdown",
		_class_of(factory, {"id": "mode", "type": TYPE_STRING, "hint": "", "options": ["one", "two"]}, "one"),
		"OptionButton") and passed
	passed = _check("a true/false parameter is a tick",
		_class_of(factory, {"id": "loop", "type": TYPE_BOOL, "hint": ""}, "true"),
		"CheckBox") and passed
	passed = _check("a number parameter is a number field",
		_class_of(factory, {"id": "speed", "type": TYPE_FLOAT, "hint": ""}, "200.0"),
		"SpinBox") and passed
	# An input action is an EDITABLE combo: the live Input Map list to pick from, and a typable field
	# for an action the map does not have yet - so the value-bearing half is the text field, and the
	# list rides beside it in the returned control.
	var action_built: Dictionary = factory.build({"id": "action", "type": TYPE_STRING, "hint": "input_action"}, "\"ui_accept\"")
	passed = _check("an input action is typable",
		(action_built["field"] as Control).get_class(), "LineEdit") and passed
	passed = _check("and carries the Input Map list beside it",
		(action_built["control"] as Control) != (action_built["field"] as Control), true) and passed
	passed = _check("a hint this build never heard of still gets a field",
		_class_of(factory, {"id": "whatever", "type": TYPE_STRING, "hint": "not_a_real_hint"}, "hello"),
		"LineEdit") and passed
	passed = _check("a parameter with no id builds nothing",
		factory.build({"type": TYPE_STRING}, "x").is_empty(), true) and passed
	return passed


## A value read back out of a widget is the GDScript the dialog would have committed - that is what
## makes the bar and the dialog the same edit rather than two edits that usually agree.
static func _test_value_round_trip() -> bool:
	var passed: bool = true
	var factory: EventSheetParamFieldFactory = EventSheetParamFieldFactory.new()
	var colour: Dictionary = factory.build({"id": "tint", "type": TYPE_COLOR, "hint": "color"}, "Color(1, 0.6, 0.2, 1)")
	passed = _check("a colour ships as a Color literal",
		factory.value_of(colour["field"] as Control).begins_with("Color("), true) and passed
	var tick: Dictionary = factory.build({"id": "loop", "type": TYPE_BOOL, "hint": ""}, "true")
	passed = _check("a ticked box reads as true", factory.value_of(tick["field"] as Control), "true") and passed
	var text: Dictionary = factory.build({"id": "label", "type": TYPE_STRING, "hint": ""}, "Hello")
	passed = _check("a text field reads back what it holds",
		factory.value_of(text["field"] as Control), "Hello") and passed
	passed = _check("nothing reads as nothing", factory.value_of(null), "") and passed
	# A wrapped widget hands back BOTH nodes: the row to add, and the field to read.
	passed = _check("a wrapped field is not its own wrapper",
		(text["control"] as Control) is HBoxContainer and (text["field"] as Control) is LineEdit, true) and passed
	return passed


## Which signal a bar commits on, per widget kind. Connecting to the wrong one is how a field
## silently stops saving, so the table is pinned rather than trusted.
static func _test_change_signals() -> bool:
	var passed: bool = true
	passed = _check("a tick commits when toggled",
		EventSheetParamFieldFactory.change_signal_of(CheckBox.new()), "toggled") and passed
	passed = _check("a swatch commits when the colour changes",
		EventSheetParamFieldFactory.change_signal_of(ColorPickerButton.new()), "color_changed") and passed
	passed = _check("a dropdown commits on the choice",
		EventSheetParamFieldFactory.change_signal_of(OptionButton.new()), "item_selected") and passed
	passed = _check("a text field commits on Enter",
		EventSheetParamFieldFactory.change_signal_of(LineEdit.new()), "text_submitted") and passed
	passed = _check("a number field commits on the value",
		EventSheetParamFieldFactory.change_signal_of(SpinBox.new()), "value_changed") and passed
	# A physics-layer mask commits through its own popup, so it names no signal and stays a dialog job.
	passed = _check("a mask names no single moment",
		EventSheetParamFieldFactory.change_signal_of(MenuButton.new()), "") and passed
	return passed


static func _class_of(factory: EventSheetParamFieldFactory, descriptor: Dictionary, value: String) -> String:
	var built: Dictionary = factory.build(descriptor, value)
	var field: Control = built.get("field") as Control
	return field.get_class() if field != null else ""


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual != expected:
		print("  [FAIL] %s (got %s, expected %s)" % [label, actual, expected])
		return false
	print("[PASS] param_field_factory_test: %s" % label)
	return true
