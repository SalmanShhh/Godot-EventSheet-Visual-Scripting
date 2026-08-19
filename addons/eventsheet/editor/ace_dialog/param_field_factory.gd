@tool
class_name EventSheetParamFieldFactory
extends RefCounted

# The ONE door to "give me the right editor for this parameter".
#
# The per-hint widgets - the colour swatch, the enum dropdown, the node picker, the Input Map
# picker, the physics-layer mask, the key capture, the animation and audio and scene pickers, the
# ƒx expression field - were reachable from exactly one place: the Edit Parameter dialog. So the
# Properties bar, which shows the very same parameters of the very same row, had one untyped
# LineEdit for all of them, and editing a colour there meant typing `Color("#ff9b3c")` by hand.
#
# This is the shared door both now use. It is deliberately a DOOR and not a second implementation:
# the builders stay where they are (`ace_params_dialog.gd`), because there are forty of them, they
# reach each other, and two copies of a widget set is exactly how a colour picker in one place and a
# colour picker in another come to disagree. What the factory owns is the part that made them
# unreachable - a dialog-free host to build them in, and one way to read a built widget's value
# back out.
#
# WHAT A CALLER GETS BACK: `build()` returns {control, field}. They are usually the same node, but
# several builders wrap their value-bearing widget in a row (a LineEdit beside a 🌐 toggle, a path
# field beside a Browse button, three axis fields in a box). `control` is what you add to your
# layout; `field` is what you read with `value_of()` and connect a change signal on. Mixing them up
# is the one mistake this shape is designed to make impossible.
#
# WHY THERE IS NO OK BUTTON HERE: the dialog commits every field at once when OK is pressed; a bar
# commits one field the moment it changes. So the factory reports which SIGNAL a built widget
# changes on (`change_signal_of`) rather than deciding when a value is worth keeping.

## The dialog instance the widgets are built in. Never shown: `init_dialog` is not called, so it owns
## no window, and every builder that would reach for one is already null-guarded (a plain field just
## does not get its Enter-presses-OK binding, which is right - there is no OK).
var _builder: ACEParamsDialog = ACEParamsDialog.new()


## Points the factory at the same registry and sheet context the Edit Parameter dialog uses, so the
## enum lists, the ƒx validation and the variable dropdowns say the same things in both places.
func init(dock: Control) -> void:
	if dock == null:
		return
	_builder.set_registry(dock._ace_registry)
	_builder.set_lint_context_provider(func() -> EventSheetResource: return dock._current_sheet)
	# The variable dropdowns read the sheet's own variables through the same provider the dialog uses,
	# so a `variable_reference` parameter offers the same names in the bar as in the dialog.
	_builder._variable_names_provider = dock._collect_sheet_variable_names


## The editor for one parameter. `descriptor` is the shipped parameter dictionary (id, type, hint,
## options, autocomplete, default_value); `value` is what the row currently holds.
##
## Returns {control, field}. A hint this build does not know still returns a plain text field, so a
## caller never has to check whether a parameter is "supported" - every parameter is.
func build(descriptor: Dictionary, value: String) -> Dictionary:
	var param_id: String = str(descriptor.get("id", ""))
	if param_id.is_empty():
		return {}
	# The builders register the value-bearing node in `_fields` under this key, which is how a wrapped
	# widget is told apart from its wrapper. Cleared per call so one caller's field is never another's.
	_builder._fields.erase(param_id)
	# Refreshed per build rather than once: a variable added since the last field was made must be in
	# the next dropdown, and there is no OK here to hang a refresh off.
	_builder._variable_names = _builder._resolve_variable_names()
	var hint: String = str(descriptor.get("hint", ""))
	var control: Control = _builder._create_field(descriptor, {param_id: value}, param_id, hint)
	var field: Control = _builder._fields.get(param_id) as Control
	return {"control": control, "field": field if field != null else control}


## The GDScript the built widget currently names - the same conversion the dialog commits with, so a
## colour picked in the Properties bar ships as the literal the dialog would have written.
func value_of(field: Control) -> String:
	if field == null:
		return ""
	return str(_builder._extract_value(field))


## Which signal on a built widget means "the user changed this", and "" for the widgets that have no
## such moment (a container, an unknown control). A bar connects to this; the dialog does not need it
## because OK is its moment.
##
## Deliberately a small table rather than a guess: connecting to the wrong signal is how a field
## silently stops saving, and the widget kinds are exactly the ones `_extract_value` reads.
static func change_signal_of(field: Control) -> String:
	if field is CheckBox:
		return "toggled"
	if field is ColorPickerButton:
		return "color_changed"
	if field is OptionButton:
		return "item_selected"
	if field is SpinBox:
		return "value_changed"
	if field is LineEdit:
		return "text_submitted"
	if field is CodeEdit or field is TextEdit:
		return "focus_exited"
	# A physics-layer mask (a MenuButton) commits through its own popup's checkboxes, with no single
	# "changed" moment on the button itself. Rather than guess at one and have the field silently stop
	# saving, it stays a job for the Edit Parameter dialog and says so by naming no signal.
	return ""
