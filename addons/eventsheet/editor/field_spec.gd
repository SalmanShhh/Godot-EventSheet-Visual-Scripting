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
# A MODIFIER THIS KIND DOES NOT WEAR IS REFUSED BY NAME. `number_field(...).placeholder("x")`
# used to compile, build and drop the placeholder without a word, which is the silent no-op this
# shape exists to make impossible: the restricted modifiers are a table below, and one that does
# not fit says which field, which modifier and which kind. So does an unhandled kind - every match
# over Kind names its arms and ends in an error rather than in a LineEdit nobody asked for.
#
# A spec is inert until build() is called. It holds no tree, reads no global state and touches no
# editor singleton, so it is unit-testable and safe headless.

## What a field IS. The kind decides the widget and the type value() reads back, and nothing else
## about the spec changes with it.
enum Kind {
	## A single line of text. Reads back a String.
	TEXT,
	## A number in a SpinBox, bounded by at_least() / at_most(). Reads back a float, or an int when
	## stepping() was told the field is whole.
	NUMBER,
	## A dropdown of fixed choices, filled by options(). Reads back the chosen option's stored
	## value: its metadata when the choice carries one, its shown words otherwise.
	OPTIONS,
	## A tick. Reads back a bool.
	CHECK,
	## A path typed into a line edit. Reads back a String; identical to TEXT but for the
	## completion the field is offered and the placeholder it defaults to.
	PATH,
}

## The modifiers only SOME kinds wear, and which kinds those are. A modifier absent from this table
## fits every kind; one present here is refused, by name, for any other.
##
## A TABLE RATHER THAN A CHECK PER MODIFIER, because the fact is what fits what - and because a
## modifier added tomorrow is one row here, beside the ones it has to be consistent with, rather
## than a guard somebody writes from memory.
const KIND_ONLY_MODIFIERS: Dictionary = {
	"placeholder": [Kind.TEXT, Kind.PATH],
	"at_least": [Kind.NUMBER],
	"at_most": [Kind.NUMBER],
	"stepping": [Kind.NUMBER],
	"options": [Kind.OPTIONS],
}

## The name this field answers to in values() and control(). Unique within one form; a duplicate
## fails the build by name rather than shadowing the first field silently.
var id: String = ""
## The words at the left of the row. Empty means the field takes the whole row width with no
## leading label (a tick that carries its own text, normally).
var label: String = ""
## Which of the five shapes this field is.
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

## The widget this spec built, or null before build(). The hand code that still needs the control
## itself - to focus it, to register it for Enter, to gate its visibility - reaches it here rather
## than keeping a second reference to the same thing.
var control: Control = null
## The whole row build() produced (the label, the field, and the hint under them when there is
## one), or null before build(). A dialog hides or shows a field by this, never by the control.
var row: Control = null


## The grey prompt shown while the field is empty. Text-shaped kinds only; refused by name on any
## other, because a prompt that silently never appears is a bug that looks like a preference.
func placeholder(text: String) -> EventSheetFieldSpec:
	if not _wears("placeholder"):
		return self
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
	if not _wears("at_least"):
		return self
	minimum = value
	return self


## The upper bound of a NUMBER field.
func at_most(value: float) -> EventSheetFieldSpec:
	if not _wears("at_most"):
		return self
	maximum = value
	return self


## The step a NUMBER field moves in, and whether it reads back whole numbers.
func stepping(value: float, whole: bool = false) -> EventSheetFieldSpec:
	if not _wears("stepping"):
		return self
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
	if not _wears("options"):
		return self
	if not stored.is_empty() and stored.size() != labels.size():
		push_error("EventSheetFieldSpec: field \"%s\" was given %d option labels and %d stored values - they must match one for one." % [id, labels.size(), stored.size()])
		return self
	option_labels = labels
	option_values = stored
	return self


## True when this kind wears `modifier`. False, with an error naming the field, the modifier and
## the kind, when it does not - so the caller's next line does not quietly build a field that is
## missing the thing it asked for.
func _wears(modifier: String) -> bool:
	var kinds: Array = KIND_ONLY_MODIFIERS.get(modifier, []) as Array
	if kinds.is_empty() or kinds.has(kind):
		return true
	var wearers: PackedStringArray = PackedStringArray()
	for wearer: Variant in kinds:
		wearers.append(_kind_name(int(wearer)))
	push_error("EventSheetFieldSpec: field \"%s\" is a %s field, and %s() belongs to %s. The modifier was NOT applied." % [
		id, _kind_name(kind), modifier, " / ".join(wearers)])
	return false


## One kind as the word the enum spells it with, for an error a reader can act on.
func _kind_name(which: int) -> String:
	var names: Array = Kind.keys()
	return str(names[which]) if which >= 0 and which < names.size() else str(which)


## What is said when a match over Kind reaches an arm nobody wrote: the field, the kind and the
## place. A kind added to the enum without its arms is a defect and says so the moment it is used,
## which is the one thing a fall-through arm could never do.
func _unhandled(where: String) -> void:
	push_error("EventSheetFieldSpec: field \"%s\" is of kind %s, which %s does not handle. Add its arm there." % [
		id, _kind_name(kind), where])


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
## build(), because a field that was never built has no answer to give - and null with a named
## error for a kind this match has no arm for.
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
		Kind.TEXT, Kind.PATH:
			return (control as LineEdit).text
	_unhandled("value()")
	return null


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
		Kind.TEXT, Kind.PATH:
			(control as LineEdit).text = str(new_value)
		_:
			_unhandled("set_value()")


## The widget itself. An unhandled kind is NAMED and still given a line edit, because build() has
## to hand a row back: the error is the answer, and the empty field beside it is what stops one
## missing arm from taking a whole dialog down.
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
		Kind.TEXT, Kind.PATH:
			return LineEdit.new()
	_unhandled("_build_control()")
	return LineEdit.new()


## The configuration every kind shares, applied once instead of per field: the prompt, the hover
## line, the opening value and the change handler.
func _apply_common() -> void:
	if control == null:
		return
	control.tooltip_text = tooltip_text
	if control is LineEdit:
		(control as LineEdit).placeholder_text = placeholder_text
		(control as LineEdit).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if default_value != null and not (kind == Kind.CHECK and label.is_empty() and default_value is String):
		set_value(default_value)
	_wire_change()


## Wires the one change handler to whichever signal this kind actually emits.
func _wire_change() -> void:
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
		Kind.TEXT, Kind.PATH:
			(control as LineEdit).text_changed.connect(func(new_text: String) -> void: handler.call(new_text))
		_:
			_unhandled("_wire_change()")


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
