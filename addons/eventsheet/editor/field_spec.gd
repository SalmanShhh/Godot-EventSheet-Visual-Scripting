@tool
class_name EventSheetFieldSpec
extends RefCounted

# EventSheet - ONE typed description of one dialog field.
#
# A dialog field has always been five separate gestures spread over four lines: make a control,
# configure it, wire it, put it in a form_row, and read it back on accept. This says the same
# thing once, as data a reader can scan: what the field IS (its kind), what it is CALLED (its
# label), what it ANSWERS to (its id), and what it may additionally do (its modifiers). The
# widget is still built by the very helpers every dialog already uses - EventSheetPopupUI's
# form_row, hint_label and the rest - so nothing about the LOOK moves when a dialog changes over.
#
# The kind is an ENUM, never a string: a misspelled kind is a parse error at the call site rather
# than an empty row at runtime. The modifiers are chainable methods, so a misspelled modifier is
# a parse error too, and Godot's own completion lists the whole vocabulary from the dot.
#
# A spec is inert until build() is called. It holds no tree, reads no global state and touches no
# editor singleton, so it is unit-testable and safe headless.

## What a field IS. The kind decides the widget and the type value() reads back, and nothing else
## about the spec changes with it.
enum Kind {
	## A single line of text. Reads back a String.
	TEXT,
	## A number in a SpinBox, bounded by at_least() / at_most(). Reads back a float (an int when
	## whole() is set).
	NUMBER,
	## A dropdown of fixed choices, filled by options(). Reads back the chosen option's stored
	## value: its metadata when the choice carries one, its shown words otherwise.
	OPTIONS,
	## A tick. Reads back a bool.
	CHECK,
	## A path typed into a line edit. Reads back a String; identical to TEXT but for the
	## completion the field is offered and the placeholder it defaults to.
	PATH,
	## A multi-line GDScript box, hardened the way every editable code field in the plugin is.
	## Reads back a String.
	CODE,
	## Free text with a picker beside it, filled live from a suggestions provider. Reads back a
	## String - the typed text, whether it came from the list or from the keyboard.
	CHOICE,
}

## The name this field answers to in values() and control(). Unique within one form; a duplicate
## fails the build by name rather than shadowing the first field silently.
var id: String = ""
## The words at the left of the row. Empty means the field takes the whole row width with no
## leading label (a tick that carries its own text, normally).
var label: String = ""
## Which of the seven shapes this field is.
var kind: Kind = Kind.TEXT

## The grey prompt shown while a text-shaped field is empty.
var placeholder_text: String = ""
## The hover explanation, landing on the label as well as the field (see form_row).
var tooltip_text: String = ""
## A muted line under the field. Empty means no hint line is built at all.
var hint_text: String = ""
## The value the field opens with. Its type follows the kind: String, float, bool.
var default_value: Variant = null
## The fixed choices an OPTIONS field offers, as shown words.
var option_labels: PackedStringArray = PackedStringArray()
## What each OPTIONS choice STORES, one per option_labels entry. Empty means each choice stores
## the words it shows.
var option_values: Array = []
## The lower bound of a NUMBER field.
var minimum: float = 0.0
## The upper bound of a NUMBER field.
var maximum: float = 100.0
## The step a NUMBER field moves in. A whole-number field steps by one.
var step_size: float = 1.0
## True when a NUMBER field reads back an int rather than a float.
var whole_numbers: bool = false
## True when the field must be answered. The spec does not enforce it - it records it, so a
## dialog's own accept check and its help strip read the same fact rather than two.
var is_required: bool = false
## Called with the field's new value whenever it changes. One Callable, so the wiring a dialog
## used to spell per control is spelled here beside what it is wiring.
var change_handler: Callable = Callable()
## Returns the CURRENT suggestions for a CHOICE field, as a PackedStringArray. A Callable rather
## than a list, because the interesting lists (project classes, sheet enums) go stale.
var suggestions_provider: Callable = Callable()

## The widget this spec built, or null before build(). The hand code that still needs the control
## itself - to focus it, to register it for Enter, to gate its visibility - reaches it here rather
## than keeping a second reference to the same thing.
var control: Control = null
## The whole row build() produced (the label, the field, and the hint under them when there is
## one), or null before build(). A dialog hides or shows a field by this, never by the control.
var row: Control = null


## The grey prompt shown while the field is empty. Text-shaped kinds only; ignored elsewhere.
func placeholder(text: String) -> EventSheetFieldSpec:
	placeholder_text = text
	return self


## The hover explanation for the field AND its label.
func tooltip(text: String) -> EventSheetFieldSpec:
	tooltip_text = text
	return self


## A muted line under the field. Use it for the sentence that would otherwise be a tooltip nobody
## opens; the dialog's one help strip is still the place for a paragraph.
func hinted(text: String) -> EventSheetFieldSpec:
	hint_text = text
	return self


## The value the field opens with.
func default(value: Variant) -> EventSheetFieldSpec:
	default_value = value
	return self


## The lower bound of a NUMBER field.
func at_least(value: float) -> EventSheetFieldSpec:
	minimum = value
	return self


## The upper bound of a NUMBER field.
func at_most(value: float) -> EventSheetFieldSpec:
	maximum = value
	return self


## The step a NUMBER field moves in, and whether it reads back whole numbers.
func stepping(value: float, whole: bool = false) -> EventSheetFieldSpec:
	step_size = value
	whole_numbers = whole
	return self


## Marks the field as one that must be answered. Recorded, not enforced - see is_required.
func required(value: bool = true) -> EventSheetFieldSpec:
	is_required = value
	return self


## Called with the field's new value whenever it changes.
func on_change(handler: Callable) -> EventSheetFieldSpec:
	change_handler = handler
	return self


## The fixed choices an OPTIONS field offers. `stored` (optional) gives each choice the value it
## stores when the shown words are not it; it must be the same length as `labels` or it is
## refused by name rather than half-applied.
func options(labels: PackedStringArray, stored: Array = []) -> EventSheetFieldSpec:
	if not stored.is_empty() and stored.size() != labels.size():
		push_error("EventSheetFieldSpec: field \"%s\" was given %d option labels and %d stored values - they must match one for one." % [id, labels.size(), stored.size()])
		return self
	option_labels = labels
	option_values = stored
	return self


## Where a CHOICE field's live suggestions come from: a Callable returning a PackedStringArray.
func suggesting(provider: Callable) -> EventSheetFieldSpec:
	suggestions_provider = provider
	return self


## Builds the widget and its row, through the same EventSheetPopupUI helpers a hand-built dialog
## uses, and returns the row ready to parent. Calling it twice returns the row already built.
func build() -> Control:
	if row != null:
		return row
	control = _build_control()
	_apply_common()
	var field_row: Control = control
	if not label.is_empty():
		field_row = EventSheetPopupUI.form_row(label, control, EventSheetPopupUI.LABEL_MIN_WIDTH, tooltip_text)
	if hint_text.is_empty():
		row = field_row
		return row
	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 2)
	stack.add_child(field_row)
	stack.add_child(EventSheetPopupUI.hint_label(hint_text))
	row = stack
	return row


## What the field currently says, typed by its kind: String, float or int, or bool. Null before
## build(), because a field that was never built has no answer to give.
func value() -> Variant:
	if control == null:
		return null
	match kind:
		Kind.CHECK:
			return (control as CheckBox).button_pressed
		Kind.NUMBER:
			var number: float = (control as SpinBox).value
			return int(number) if whole_numbers else number
		Kind.OPTIONS:
			return _selected_option_value()
		Kind.CODE:
			return (control as CodeEdit).text
		Kind.CHOICE:
			return (_choice_edit() as LineEdit).text
		_:
			return (control as LineEdit).text


## Puts a value INTO the field - the other half of value(), for a dialog re-opening on a row it is
## editing. A value the field cannot wear is ignored rather than half-applied.
func set_value(new_value: Variant) -> void:
	if control == null:
		return
	match kind:
		Kind.CHECK:
			(control as CheckBox).button_pressed = bool(new_value)
		Kind.NUMBER:
			(control as SpinBox).value = float(new_value)
		Kind.OPTIONS:
			_select_option_value(new_value)
		Kind.CODE:
			(control as CodeEdit).text = str(new_value)
		Kind.CHOICE:
			(_choice_edit() as LineEdit).text = str(new_value)
		_:
			(control as LineEdit).text = str(new_value)


## The line edit a CHOICE field types into. A CHOICE builds a box holding the edit and its picker,
## so the control the caller reaches for is one level in.
func _choice_edit() -> Control:
	if kind != Kind.CHOICE or control == null:
		return control
	return control.get_child(0) as Control


func _build_control() -> Control:
	match kind:
		Kind.CHECK:
			var check: CheckBox = CheckBox.new()
			if label.is_empty():
				check.text = str(default_value) if default_value is String else ""
			return check
		Kind.NUMBER:
			var spin: SpinBox = SpinBox.new()
			spin.min_value = minimum
			spin.max_value = maximum
			spin.step = step_size
			spin.rounded = whole_numbers
			return spin
		Kind.OPTIONS:
			var dropdown: OptionButton = OptionButton.new()
			for index: int in option_labels.size():
				dropdown.add_item(option_labels[index])
				if index < option_values.size():
					dropdown.set_item_metadata(index, option_values[index])
			if dropdown.item_count > 0:
				dropdown.select(0)
			return dropdown
		Kind.CODE:
			var code: CodeEdit = CodeEdit.new()
			EventSheetPopupUI.configure_code_editor(code)
			code.custom_minimum_size = Vector2(0.0, 96.0)
			return code
		Kind.CHOICE:
			var box: HBoxContainer = HBoxContainer.new()
			var edit: LineEdit = LineEdit.new()
			edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			box.add_child(edit)
			if suggestions_provider.is_valid():
				box.add_child(EventSheetPopupUI.autocomplete_combo(edit, suggestions_provider))
			return box
		_:
			return LineEdit.new()


## The configuration every kind shares, applied once instead of per field: the prompt, the hover
## line, the opening value and the change handler.
func _apply_common() -> void:
	if control == null:
		return
	control.tooltip_text = tooltip_text
	var text_field: Control = _choice_edit() if kind == Kind.CHOICE else control
	if text_field is LineEdit:
		(text_field as LineEdit).placeholder_text = placeholder_text
		(text_field as LineEdit).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	elif text_field is CodeEdit:
		(text_field as CodeEdit).placeholder_text = placeholder_text
	if default_value != null and not (kind == Kind.CHECK and label.is_empty() and default_value is String):
		set_value(default_value)
	_wire_change(text_field)


## Wires the one change handler to whichever signal this kind actually emits.
func _wire_change(text_field: Control) -> void:
	if not change_handler.is_valid():
		return
	var handler: Callable = change_handler
	match kind:
		Kind.CHECK:
			(control as CheckBox).toggled.connect(func(pressed: bool) -> void: handler.call(pressed))
		Kind.NUMBER:
			(control as SpinBox).value_changed.connect(func(new_value: float) -> void: handler.call(new_value))
		Kind.OPTIONS:
			(control as OptionButton).item_selected.connect(func(_index: int) -> void: handler.call(_selected_option_value()))
		Kind.CODE:
			(control as CodeEdit).text_changed.connect(func() -> void: handler.call((control as CodeEdit).text))
		_:
			(text_field as LineEdit).text_changed.connect(func(new_text: String) -> void: handler.call(new_text))


## The chosen option's stored value: its metadata when it carries one, its words otherwise.
func _selected_option_value() -> Variant:
	var dropdown: OptionButton = control as OptionButton
	if dropdown == null or dropdown.selected < 0:
		return ""
	var stored: Variant = dropdown.get_item_metadata(dropdown.selected)
	return dropdown.get_item_text(dropdown.selected) if stored == null else stored


## Selects the option whose stored value (or, failing that, whose words) match. Nothing matching
## leaves the selection alone: a dropdown re-opened on a value that has since been deleted keeps
## a readable choice rather than going blank.
func _select_option_value(wanted: Variant) -> void:
	var dropdown: OptionButton = control as OptionButton
	if dropdown == null:
		return
	for index: int in dropdown.item_count:
		var stored: Variant = dropdown.get_item_metadata(index)
		var here: Variant = dropdown.get_item_text(index) if stored == null else stored
		if here == wanted:
			dropdown.select(index)
			return
