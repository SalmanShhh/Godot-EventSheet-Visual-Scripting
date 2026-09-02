@tool
class_name EventSheetFieldForm
extends RefCounted

# EventSheet - a built form of EventSheetFieldSpecs, and the one place it is read back.
#
# A dialog hands EventSheetPopupUI.form() a host container and a list of specs; it gets one of
# these back. From here the dialog asks for a field by id - its control, its row, its value - and
# reads the whole form in one gesture with values(). The point is that the read-back is derived
# from the SAME table the build came from, so a field added to the table cannot be forgotten in
# the accept handler, which is the bug this shape exists to make impossible.
#
# An id nothing in the table answers to is an ERROR NAMING THE ID and the ids that do exist, at
# the moment it is asked for, rather than a null that reaches three call sites before it fails.
# A duplicate id fails the build the same way.

## The specs of this form, in the order they were built, keyed by id.
var _by_id: Dictionary = {}
## The ids in build order, so values() and the error messages read in the order a person sees.
var _order: PackedStringArray = PackedStringArray()
## What the error messages call this form, so a project with six dialogs open says which one.
var _owner_name: String = "form"


## Builds `specs` into `host` in order and records them. Called by EventSheetPopupUI.form(); a
## dialog does not construct one of these by hand.
func fill(host: Control, specs: Array[EventSheetFieldSpec], owner_name: String = "form") -> EventSheetFieldForm:
	_owner_name = owner_name
	for spec: EventSheetFieldSpec in specs:
		if spec == null:
			continue
		if _by_id.has(spec.id):
			push_error("EventSheetFieldForm: %s declares the field id \"%s\" twice - ids are how the form is read back, so the second one would shadow the first." % [_owner_name, spec.id])
			continue
		_by_id[spec.id] = spec
		_order.append(spec.id)
		if host != null:
			host.add_child(spec.build())
		else:
			spec.build()
	return self


## The spec registered under `field_id`, or null with an error naming what IS registered.
func spec(field_id: String) -> EventSheetFieldSpec:
	if _by_id.has(field_id):
		return _by_id[field_id]
	push_error("EventSheetFieldForm: %s has no field \"%s\". It holds: %s." % [_owner_name, field_id, ", ".join(_order)])
	return null


## The built widget of one field - what the hand code that still needs a control reaches for
## (focus, register_text_enter, a live validator). Null, with a named error, for an unknown id.
func control(field_id: String) -> Control:
	var found: EventSheetFieldSpec = spec(field_id)
	return null if found == null else found.control


## The whole row of one field (label, field, and the hint under them when there is one) - what a
## dialog hides and shows, never the control. Null, with a named error, for an unknown id.
func row(field_id: String) -> Control:
	var found: EventSheetFieldSpec = spec(field_id)
	return null if found == null else found.row


## What one field currently says, typed by its kind.
func value(field_id: String) -> Variant:
	var found: EventSheetFieldSpec = spec(field_id)
	return null if found == null else found.value()


## Puts a value into one field.
func set_value(field_id: String, new_value: Variant) -> void:
	var found: EventSheetFieldSpec = spec(field_id)
	if found != null:
		found.set_value(new_value)


## THE READ-BACK: every field's current value, id -> value, in build order. The accept handler
## reads this instead of naming each control again, so the table is the only list of fields there
## is and a new row cannot be half-added.
func values() -> Dictionary:
	var out: Dictionary = {}
	for field_id: String in _order:
		out[field_id] = (_by_id[field_id] as EventSheetFieldSpec).value()
	return out


## Fills the form from a Dictionary of id -> value. Ids the form does not hold are IGNORED here
## rather than refused: a saved row from an older version legitimately carries keys this form
## retired, and dropping them quietly is the lossless-friendly reading.
func apply_values(stored: Dictionary) -> void:
	for field_id: String in _order:
		if stored.has(field_id):
			(_by_id[field_id] as EventSheetFieldSpec).set_value(stored[field_id])


## The ids this form holds, in build order. The door for anything that wants to walk the fields
## without knowing them: a help-strip wiring, a test, an explain line.
func field_ids() -> PackedStringArray:
	return _order.duplicate()


## The ids of the fields marked required() that are currently blank - what an accept check asks
## before it writes anything. Empty means every required field has been answered.
func unanswered_required() -> PackedStringArray:
	var missing: PackedStringArray = PackedStringArray()
	for field_id: String in _order:
		var found: EventSheetFieldSpec = _by_id[field_id]
		if not found.is_required:
			continue
		var current: Variant = found.value()
		if current == null or (current is String and (current as String).strip_edges().is_empty()):
			missing.append(field_id)
	return missing
