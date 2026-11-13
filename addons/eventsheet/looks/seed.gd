@tool
extends EventSheetInspectorLook

## Seed with a New seed button
## A number field and a button that writes a fresh seed. For a seed where 0 means a new one every run.

## The kinds of property this look can be put on.
@export var works_on: String = "int,String"

## The sentence the preview card says under a variable that wears this look.
const PREVIEW_SENTENCE := "A seed, with a button that writes a new one."

## The range the field is set to. A number beyond it can still be typed (the field allows greater and
## lesser), but a range this size keeps the field's own rounding exact.
const LARGEST: float = 2147483647.0

var _flow: HFlowContainer = null
var _number: Range = null
var _text: LineEdit = null
var _button: Button = null
var _note: Label = null


## A fresh seed: a positive whole number that is never 0, since 0 means "a new one every run".
static func fresh_seed(rng: RandomNumberGenerator = null) -> int:
	var source: RandomNumberGenerator = rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		source.randomize()
	var picked: int = int(source.randi() & 0x7fffffff)
	return picked if picked != 0 else 1


## The sentence under the field while the value means "different every run", or "" when it does not.
static func zero_note(value: Variant) -> String:
	if value is String or value is StringName:
		return EventSheetL10n.translate("Empty: different every run.") if str(value).strip_edges().is_empty() else ""
	return EventSheetL10n.translate("0: different every run.") if int(value) == 0 else ""


func _look_built() -> void:
	_flow = HFlowContainer.new()
	_flow.add_theme_constant_override("h_separation", int(px(4.0)))
	_flow.add_theme_constant_override("v_separation", int(px(4.0)))
	if field_type() == TYPE_STRING or field_type() == TYPE_STRING_NAME:
		_text = LineEdit.new()
		_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_text.custom_minimum_size.x = EventSheetLookStyle.number_field_min_width()
		_text.text_submitted.connect(_on_typed)
		_text.focus_exited.connect(func() -> void: _on_typed(_text.text))
		_flow.add_child(_text)
		add_focusable(_text)
	else:
		_number = number_field()
		EventSheetLookStyle.open_number_field(_number, 1.0)
		_number.min_value = -LARGEST - 1.0
		_number.max_value = LARGEST
		_number.value_changed.connect(_on_number)
		_flow.add_child(_number)
		add_focusable(_number)
	_button = Button.new()
	_button.text = EventSheetL10n.translate("New seed")
	_button.tooltip_text = EventSheetL10n.translate("Writes a fresh seed into the field.")
	_button.pressed.connect(_on_new_seed)
	_flow.add_child(_button)
	add_child(_flow)
	add_focusable(_button)


## The quiet line under the field while the seed means "different every run".
func _rows_under_field() -> Array[Control]:
	_note = EventSheetLookStyle.message_line("")
	_note.visible = false
	return [_note]


func _value_shown(value: Variant) -> void:
	if _number != null:
		_number.set_value_no_signal(float(int(value)))
		EventSheetLookStyle.set_number_field_locked(_number, is_field_read_only())
	elif _text != null and not _text.has_focus():
		_text.text = str(value)
		_text.editable = not is_field_read_only()
	_button.disabled = is_field_read_only()
	_show_note(value)


func _show_note(value: Variant) -> void:
	if _note == null:
		return
	var words: String = zero_note(value)
	_note.text = words
	_note.visible = not words.is_empty()


func _on_number(value: float) -> void:
	set_field_value(int(value))


func _on_typed(text: String) -> void:
	if text != str(field_value()):
		set_field_value(StringName(text) if field_type() == TYPE_STRING_NAME else text)


func _on_new_seed() -> void:
	var picked: int = fresh_seed()
	if _text != null:
		_text.text = str(picked)
		set_field_value(StringName(str(picked)) if field_type() == TYPE_STRING_NAME else str(picked))
	else:
		set_field_value(picked)
