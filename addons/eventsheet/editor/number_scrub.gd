# Godot EventSheets - drag a parameter's LABEL to scrub its number.
#
# Tuning a value by select-all / retype / look / repeat is the slowest loop in event-sheet
# authoring: most of the numbers that matter (speed, damage, duration, angle) are found by feel,
# not calculated, and every guess costs a full edit cycle. Dragging turns that into one gesture
# with continuous feedback.
#
# WHY THE LABEL AND NOT THE FIELD. The obvious surface is the number itself, but the field holding
# it is usually a CodeEdit (an ACE param is a GDScript expression, so `health + 10` is as valid as
# `250`). Claiming left-drag inside a text editor costs click-to-place-caret and drag-to-select -
# two things authors use constantly - to buy one they use occasionally. Dragging the property NAME
# is also what Godot's own Inspector does, so the gesture is already in muscle memory.
#
# SCRUBBING NEVER DESTROYS AN EXPRESSION. The drag only arms when the field currently holds a plain
# number, checked at press time. A field reading `speed * delta` is not scrubbable and its label
# keeps the ordinary arrow cursor - there is no gesture that can silently flatten an expression
# into a literal.
@tool
class_name EventSheetNumberScrub
extends RefCounted

## Pixels of horizontal travel per step. One step per pixel is unusably twitchy on a trackpad.
const PIXELS_PER_STEP: float = 4.0

## Travel before a press becomes a drag, so clicking a label (to read its tooltip, say) never
## nudges the value.
const DRAG_THRESHOLD: float = 3.0

## Modifier multipliers: Shift for a fine pass, Ctrl for a coarse one.
const FINE_SCALE: float = 0.1
const COARSE_SCALE: float = 10.0


## Makes `label` scrub `field`. Safe to call for any field - a control this cannot read or write
## (a dropdown, a checkbox) is simply left alone, so callers need no type test of their own.
static func attach(label: Control, field: Control) -> void:
	if label == null or field == null:
		return
	if resolve_field(field) == null:
		return
	label.mouse_filter = Control.MOUSE_FILTER_STOP
	# The drag lives across several input events, so its state rides in a Dictionary: GDScript
	# lambdas capture locals BY VALUE, and a Dictionary is a reference, so all three closures
	# below see the same one.
	var state: Dictionary = {"dragging": false, "armed": false, "origin": 0.0, "start": 0.0, "step": 1.0, "integral": true}
	label.mouse_entered.connect(func() -> void:
		label.mouse_default_cursor_shape = Control.CURSOR_HSIZE if is_scrubbable(read_value(field)) else Control.CURSOR_ARROW)
	label.gui_input.connect(func(event: InputEvent) -> void: _handle_input(event, label, field, state))


## True when `text` is a bare number - the only thing this is willing to overwrite.
static func is_scrubbable(text: String) -> bool:
	var trimmed: String = text.strip_edges()
	if trimmed.is_empty():
		return false
	return trimmed.is_valid_float() or trimmed.is_valid_int()


## The value-bearing control inside `field`, or null when there is none.
##
## Most param fields are not a bare text control: an expression param is an HBox holding a CodeEdit
## plus its ƒx and node-picker buttons, and several others wrap an editor next to a browse button.
## Resolving through the wrapper is what makes scrubbing reach the 800-odd expression params rather
## than only the few dozen declared as int/float.
static func resolve_field(field: Control) -> Control:
	if field == null:
		return null
	if field is SpinBox or field is CodeEdit or field is LineEdit:
		return field
	for child: Node in field.get_children():
		var control: Control = child as Control
		if control == null:
			continue
		var found: Control = resolve_field(control)
		if found != null:
			return found
	return null


## The field's current text, whatever kind of control it is (or is wrapped in).
static func read_value(field: Control) -> String:
	var control: Control = resolve_field(field)
	if control is SpinBox:
		return str((control as SpinBox).value)
	if control is CodeEdit:
		return (control as CodeEdit).text
	if control is LineEdit:
		return (control as LineEdit).text
	return ""


## Writes a scrubbed value back. A CodeEdit keeps its caret where it was, so the field does not
## jump around under a drag that is not touching the caret at all.
static func write_value(field: Control, text: String) -> void:
	var control: Control = resolve_field(field)
	if control is SpinBox:
		(control as SpinBox).value = text.to_float()
		return
	if control is CodeEdit:
		var code_edit: CodeEdit = control as CodeEdit
		var caret: int = code_edit.get_caret_column()
		code_edit.text = text
		code_edit.set_caret_column(mini(caret, text.length()))
		return
	if control is LineEdit:
		(control as LineEdit).text = text


## The increment one step of travel applies, derived from the value's own magnitude so a bullet
## speed of 3000 and an alpha of 0.5 both feel right under the same gesture. A fixed step cannot
## do both: 1 makes the speed take a thousand pixels of dragging, 100 makes the alpha meaningless.
##
## The rule is "two significant digits of control": a 4-digit number steps by 100, a 3-digit one by
## 10, a 2-digit one by 1 - and the same formula continues below zero, so 0.5 steps by 0.01 and
## 0.05 by 0.001. Integers never step below 1, so scrubbing a count stays a count.
static func step_for(value: float, integral: bool) -> float:
	var magnitude: float = absf(value)
	# log(0) is -inf; a zero field has no magnitude to read, so start at the finest useful step.
	var digits: int = 1 if magnitude <= 0.0 else int(floorf(log(magnitude) / log(10.0))) + 1
	var step: float = pow(10.0, float(digits - 2))
	if integral:
		return maxf(1.0, step)
	return step


## Formats a scrubbed value: an integer stays an integer (no stray `.0` in the emitted code), and a
## decimal keeps only as many places as the step can actually reach.
static func format_value(value: float, step: float, integral: bool) -> String:
	if integral:
		return str(int(roundf(value)))
	var places: int = maxi(0, int(ceilf(-log(step) / log(10.0))))
	return String.num(snappedf(value, step), places)


static func _handle_input(event: InputEvent, label: Control, field: Control, state: Dictionary) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			# Arm rather than start: the value must not move until the pointer does.
			var text: String = read_value(field).strip_edges()
			if not is_scrubbable(text):
				return
			state["armed"] = true
			state["dragging"] = false
			state["origin"] = button.global_position.x
			state["start"] = text.to_float()
			state["integral"] = text.is_valid_int()
			state["step"] = step_for(text.to_float(), text.is_valid_int())
		else:
			state["armed"] = false
			state["dragging"] = false
			label.mouse_default_cursor_shape = Control.CURSOR_HSIZE if is_scrubbable(read_value(field)) else Control.CURSOR_ARROW
		return

	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion == null or not bool(state.get("armed", false)):
		return
	var travel: float = motion.global_position.x - float(state["origin"])
	if not bool(state["dragging"]):
		if absf(travel) < DRAG_THRESHOLD:
			return
		state["dragging"] = true
	var step: float = float(state["step"])
	if motion.shift_pressed:
		step *= FINE_SCALE
	elif motion.ctrl_pressed:
		step *= COARSE_SCALE
	var integral: bool = bool(state["integral"])
	if integral:
		step = maxf(1.0, roundf(step))
	write_value(field, format_value(float(state["start"]) + (travel / PIXELS_PER_STEP) * step, step, integral))
