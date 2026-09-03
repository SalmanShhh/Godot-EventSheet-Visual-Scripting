@tool
class_name FieldSpecTest
extends RefCounted

# EventSheet - the typed field specs and the form that reads them back.
#
# The seam's whole claim is that a field said ONCE as data builds the same widget a hand-built
# dialog builds, and that the read-back is derived from the same table as the build - so a field
# added to the table cannot be missing from the accept handler. These pin both halves, plus the
# named errors that are the difference between a typed seam and a dictionary of strings.


const SUPPORT := preload("res://tests/support.gd")


static func run() -> bool:
	var ok: bool = true
	ok = _kinds_build_their_widgets() and ok
	ok = _the_row_is_the_plugins_own_form_row() and ok
	ok = _values_read_back_typed() and ok
	ok = _stored_option_values() and ok
	ok = _change_handlers_fire() and ok
	ok = _required_and_ids() and ok
	ok = _a_modifier_a_kind_does_not_wear_is_refused() and ok
	return ok


## Each kind builds the control the plugin already uses for that shape - the seam adds a
## description, never a new widget vocabulary.
static func _kinds_build_their_widgets() -> bool:
	var host: VBoxContainer = VBoxContainer.new()
	var form: EventSheetFieldForm = EventSheetPopupUI.form(host, [
		EventSheetPopupUI.text_field("name", "Name"),
		EventSheetPopupUI.number_field("count", "Count"),
		EventSheetPopupUI.options_field("mode", "Mode").options(PackedStringArray(["one", "two"])),
		EventSheetPopupUI.check_field("keep", "Keep"),
		EventSheetPopupUI.path_field("where", "Where"),
	], "field spec test")
	var rows: Array = [
		["a text field is a LineEdit", form.control("name") is LineEdit, true],
		["a number field is a SpinBox", form.control("count") is SpinBox, true],
		["an options field is an OptionButton", form.control("mode") is OptionButton, true],
		["a check field is a CheckBox", form.control("keep") is CheckBox, true],
		["a path field is a LineEdit", form.control("where") is LineEdit, true],
		["the form holds every id in build order", form.field_ids(),
			PackedStringArray(["name", "count", "mode", "keep", "where"])],
		["the host got one row per field", host.get_child_count(), 5],
	]
	var ok: bool = SUPPORT.pins("field kinds build the plugin's own widgets", rows)
	host.free()
	return ok


## A spec'd row IS a form_row - the label at its fixed leading width, the field expanding - so a
## dialog changing over cannot move a pixel.
static func _the_row_is_the_plugins_own_form_row() -> bool:
	var spec: EventSheetFieldSpec = EventSheetPopupUI.text_field("name", "Name").tooltip("what it is called")
	var row: Control = spec.build()
	var hinted: EventSheetFieldSpec = EventSheetPopupUI.text_field("note", "Note").hinted("a muted line")
	var hinted_row: Control = hinted.build()
	var label: Label = (row as HBoxContainer).get_child(0) as Label
	var rows: Array = [
		["a labelled field builds a form_row", row is HBoxContainer, true],
		["the label carries the words", label.text, "Name"],
		["the label keeps the shared leading width", label.custom_minimum_size.x,
			EventSheetPopupUI.LABEL_MIN_WIDTH],
		["the tooltip lands on the label too", label.tooltip_text, "what it is called"],
		["a hinted field stacks the row over its hint", hinted_row is VBoxContainer, true],
		["the hint is the plugin's muted label", (hinted_row as VBoxContainer).get_child(1) is Label, true],
	]
	var ok: bool = SUPPORT.pins("a spec'd row is the plugin's own form row", rows)
	row.free()
	hinted_row.free()
	return ok


## values() is derived from the SAME table the build came from, and each kind answers in its own
## type rather than in text.
static func _values_read_back_typed() -> bool:
	var host: VBoxContainer = VBoxContainer.new()
	var form: EventSheetFieldForm = EventSheetPopupUI.form(host, [
		EventSheetPopupUI.text_field("name", "Name").default("health"),
		EventSheetPopupUI.number_field("count", "Count").at_least(0.0).at_most(10.0).stepping(1.0, true).default(3.0),
		EventSheetPopupUI.check_field("keep", "Keep").default(true),
		EventSheetPopupUI.options_field("mode", "Mode").options(PackedStringArray(["one", "two"])),
	], "field spec test")
	var read: Dictionary = form.values()
	form.set_value("name", "shield")
	var rows: Array = [
		["text reads back a String", read["name"], "health"],
		["a whole number reads back an int", read["count"], 3],
		["a tick reads back a bool", read["keep"], true],
		["a dropdown reads back its choice", read["mode"], "one"],
		["the bounds reach the SpinBox", (form.control("count") as SpinBox).max_value, 10.0],
		["set_value puts a value back in", form.value("name"), "shield"],
		["apply_values ignores an id the form retired", _applied_unknown(form), "shield"],
	]
	var ok: bool = SUPPORT.pins("the form reads itself back typed", rows)
	host.free()
	return ok


static func _applied_unknown(form: EventSheetFieldForm) -> String:
	form.apply_values({"gone_in_an_older_version": 1})
	return str(form.value("name"))


## A choice whose stored value is not the words it shows reads back the stored value - the
## metadata idiom every dropdown in this editor already uses.
static func _stored_option_values() -> bool:
	var host: VBoxContainer = VBoxContainer.new()
	var form: EventSheetFieldForm = EventSheetPopupUI.form(host, [
		EventSheetPopupUI.options_field("scope", "Scope").options(
			PackedStringArray(["on this object", "everywhere"]), ["instance", "global"]),
	], "field spec test")
	var first: Variant = form.value("scope")
	form.set_value("scope", "global")
	var rows: Array = [
		["the first choice stores its metadata", first, "instance"],
		["set_value selects by the stored value", form.value("scope"), "global"],
		["a mismatched stored list is refused, not half-applied",
			EventSheetPopupUI.options_field("bad", "Bad").options(
				PackedStringArray(["a", "b"]), ["only one"]).option_labels, PackedStringArray()],
	]
	var ok: bool = SUPPORT.pins("a dropdown stores what it means", rows)
	host.free()
	return ok


## One on_change per field, wired to whichever signal that kind actually emits.
static func _change_handlers_fire() -> bool:
	var seen: Array = []
	var host: VBoxContainer = VBoxContainer.new()
	var form: EventSheetFieldForm = EventSheetPopupUI.form(host, [
		EventSheetPopupUI.text_field("name", "Name").on_change(func(v: Variant) -> void: seen.append(v)),
		EventSheetPopupUI.check_field("keep", "Keep").on_change(func(v: Variant) -> void: seen.append(v)),
	], "field spec test")
	(form.control("name") as LineEdit).text = "typed"
	(form.control("name") as LineEdit).text_changed.emit("typed")
	(form.control("keep") as CheckBox).toggled.emit(true)
	var rows: Array = [
		["the text handler saw the new text", seen[0] if seen.size() > 0 else "", "typed"],
		["the tick handler saw the new state", seen[1] if seen.size() > 1 else false, true],
	]
	var ok: bool = SUPPORT.pins("one change handler per field", rows)
	host.free()
	return ok


## An id nothing answers to is an error naming what the form DOES hold, not a silent null that
## travels; a required field that is blank is named before anything is written.
static func _required_and_ids() -> bool:
	var host: VBoxContainer = VBoxContainer.new()
	var form: EventSheetFieldForm = EventSheetPopupUI.form(host, [
		EventSheetPopupUI.text_field("name", "Name").required(),
		EventSheetPopupUI.text_field("note", "Note"),
	], "field spec test")
	var blank: PackedStringArray = form.unanswered_required()
	form.set_value("name", "health")
	var rows: Array = [
		["a blank required field is named", blank, PackedStringArray(["name"])],
		["an answered one is not", form.unanswered_required(), PackedStringArray()],
		["field_ids is a copy, so a caller cannot edit the form's order",
			_ids_are_a_copy(form), PackedStringArray(["name", "note"])],
	]
	var ok: bool = SUPPORT.pins("required fields and unknown ids", rows)
	host.free()
	return ok


## THE SILENT NO-OP THIS SEAM MUST NOT HAVE. `number_field(...).placeholder("x")` compiled, built and
## dropped the placeholder without a word - the modifier looked applied and was not. A modifier a
## kind does not wear is refused now, and the pin is that the VALUE did not move: an error a nobody
## reads is not the point, the point is that the spec did not quietly pretend.
static func _a_modifier_a_kind_does_not_wear_is_refused() -> bool:
	var number: EventSheetFieldSpec = EventSheetPopupUI.number_field("count", "Count")
	var text: EventSheetFieldSpec = EventSheetPopupUI.text_field("name", "Name")
	var check: EventSheetFieldSpec = EventSheetPopupUI.check_field("keep", "Keep")
	var rows: Array = [
		["a placeholder on a number field is refused",
			number.placeholder("nothing").placeholder_text, ""],
		["a bound on a text field is refused", text.at_least(3.0).minimum, 0.0],
		["a step on a text field is refused", text.stepping(0.5).step_size, 1.0],
		["options on a tick are refused",
			check.options(PackedStringArray(["a"])).option_labels, PackedStringArray()],
		["and a placeholder on the kinds that DO wear it still lands",
			text.placeholder("a name").placeholder_text, "a name"],
		["the table names every restricted modifier once",
			EventSheetFieldSpec.KIND_ONLY_MODIFIERS.keys().size(), 5],
	]
	return SUPPORT.pins("a modifier a kind does not wear", rows)


static func _ids_are_a_copy(form: EventSheetFieldForm) -> PackedStringArray:
	var taken: PackedStringArray = form.field_ids()
	taken.append("meddled")
	return form.field_ids()
