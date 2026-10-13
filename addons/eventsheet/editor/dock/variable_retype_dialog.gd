@tool
class_name EventSheetVariableRetypeDialog
extends RefCounted
# "Change Type Everywhere..." - the guided retype on the variable context menu.
#
# Pick the new type, READ the list of rows that will be rewritten, then press the button: the
# declaration, its default and every value field that stands in an assignment or comparison with
# the variable change in ONE undo step. Rows the refactor refuses to guess at (an expression, a
# literal with no honest conversion) are listed too, under their own heading, so the dialog tells
# you where to look instead of quietly leaving the old shape behind.
#
# The dialog owns no rules: the whole preview comes from EventSheetVariableRetype.plan and the
# commit from .apply, so what is shown and what happens are the same scan. The type list is the
# variable dialog's own (VariableDialog.add_type_items), so retyping offers exactly the types
# creating offered, each with the sentence that says what it holds.
#
# Headless-safe by construction: everything except the popup itself runs without a tree, and
# `preview_lines()` is the tested surface - the suite reads the very strings the list shows.

var _dock: Control = null
var _dialog: AcceptDialog = null
var _type_option: OptionButton = null
var _summary_label: Label = null
var _preview_list: ItemList = null
var _variable_name: String = ""
## WHICH declaration of that name was right-clicked (two events may each declare their own `i`).
## Resolved once, while the clicked resources are still the live ones, and kept as a structural
## position so it survives the undo funnel replacing every resource with a snapshot duplicate.
var _ordinal: int = -1


func init(dock: Control) -> void:
	_dock = dock


## Opens the dialog for one variable-context entry (the dict the variable context menu acts on).
func open(entry: Dictionary) -> void:
	_variable_name = str(entry.get("name", ""))
	if _variable_name.is_empty():
		_dock._set_status("Right-click a variable to change its type.", true)
		return
	_ordinal = EventSheetVariableRetype.ordinal_of(_dock._current_sheet, entry) if _dock != null else -1
	_build_dialog()
	_dialog.title = "Change Type Everywhere - %s" % _variable_name
	select_type(str(entry.get("type", "Variant")))
	refresh_preview()
	if _dock.is_inside_tree():
		_dialog.popup_centered(Vector2i(560, 460))


func _build_dialog() -> void:
	if _dialog != null:
		return
	_dialog = AcceptDialog.new()
	_dialog.ok_button_text = "Change It Everywhere"
	_dialog.add_cancel_button("Cancel")
	_dialog.confirmed.connect(confirm)
	var content: VBoxContainer = EventSheetPopupUI.form_box()
	content.add_child(EventSheetPopupUI.hint_label("Changes the variable's type AND every row that sets or compares it, in one step you can undo. Values it cannot convert on its own are listed below rather than guessed at."))
	var type_box: VBoxContainer = EventSheetPopupUI.form_box()
	_type_option = EventSheetPopupUI.described_option()
	VariableDialog.add_type_items(_type_option)
	_type_option.item_selected.connect(func(_index: int) -> void: refresh_preview())
	type_box.add_child(EventSheetPopupUI.form_row("New type", _type_option))
	content.add_child(EventSheetPopupUI.titled_card("Make it a…", type_box))
	var preview_box: VBoxContainer = EventSheetPopupUI.form_box()
	_summary_label = EventSheetPopupUI.hint_label("")
	preview_box.add_child(_summary_label)
	_preview_list = ItemList.new()
	_preview_list.custom_minimum_size = Vector2(0.0, 180.0)
	preview_box.add_child(_preview_list)
	content.add_child(EventSheetPopupUI.titled_card("What will change", preview_box))
	_dialog.add_child(EventSheetPopupUI.margined(content))
	EventSheetL10n.apply_to(_dialog)
	_dock.add_child(_dialog)


## The Godot type the dropdown currently means.
func selected_type() -> String:
	if _type_option == null or _type_option.selected < 0:
		return "Variant"
	return str(_type_option.get_item_metadata(_type_option.selected))


## Points the dropdown at a stored type - the reverse of selected_type. A type the list does not
## name is added at its foot, so the variable's own type is always the one shown.
func select_type(type_name: String) -> void:
	if _type_option == null:
		return
	for index: int in range(_type_option.item_count):
		if not _type_option.is_item_separator(index) and str(_type_option.get_item_metadata(index)) == type_name:
			_type_option.select(index)
			return
	EventSheetPopupUI.add_described_item(_type_option, type_name, "The type this variable already has.", type_name)
	_type_option.select(_type_option.item_count - 1)


## The preview, exactly as the list shows it: the declaration line, then one line per rewritten
## field, then one per row left alone with the reason. The suite reads THIS.
func preview_lines() -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	if _dock == null or _dock._current_sheet == null:
		return lines
	var new_type: String = selected_type()
	var report: Dictionary = EventSheetVariableRetype.plan(_dock._current_sheet, _variable_name, new_type, _ordinal)
	if not bool(report.get("found", false)):
		lines.append("%s is not declared in this sheet." % _variable_name)
		return lines
	lines.append("Declaration: %s is %s, becomes %s" % [_variable_name, str(report.get("old_type", "")), new_type])
	if bool(report.get("default_changed", false)):
		lines.append("Default: %s becomes %s" % [str(report.get("default_before", "")), str(report.get("default_after", ""))])
	for change: Dictionary in (report.get("changes", []) as Array):
		lines.append("%s - %s %s: %s becomes %s" % [
			str(change.get("where", "")),
			_display_name(change),
			str(change.get("param", "")),
			str(change.get("before", "")),
			str(change.get("after", ""))
		])
	for review: Dictionary in (report.get("reviews", []) as Array):
		lines.append("%s - %s %s: %s left as written (%s)" % [
			str(review.get("where", "")),
			_display_name(review),
			str(review.get("param", "")),
			str(review.get("before", "")),
			str(review.get("why", ""))
		])
	return lines


## The verb's readable name when its definition is loadable, else its id (a pack that is no longer
## installed must still preview, so the id is a fallback, never an error).
func _display_name(entry: Dictionary) -> String:
	if _dock == null or not _dock.has_method("_find_definition"):
		return str(entry.get("ace_id", ""))
	var definition: ACEDefinition = _dock._find_definition(str(entry.get("provider_id", "")), str(entry.get("ace_id", "")))
	return definition.display_name if definition != null else str(entry.get("ace_id", ""))


func refresh_preview() -> void:
	if _preview_list == null:
		return
	_preview_list.clear()
	var lines: PackedStringArray = preview_lines()
	for line: String in lines:
		_preview_list.add_item(line)
		# A long row (an expression left as written) is wider than the list; the tooltip carries the
		# whole sentence so nothing the preview promises to say is only half-said.
		_preview_list.set_item_tooltip(_preview_list.item_count - 1, line)
	var report: Dictionary = EventSheetVariableRetype.plan(_dock._current_sheet, _variable_name, selected_type(), _ordinal) if _dock != null and _dock._current_sheet != null else {}
	# Nothing to change when the name is not declared here: the preview says so, and the button that
	# would apply it is off rather than pressable into a silent no-op.
	if _dialog != null:
		_dialog.get_ok_button().disabled = not bool(report.get("found", false))
	if _summary_label != null:
		var reviews: int = (report.get("reviews", []) as Array).size() if report.has("reviews") else 0
		var changes: int = (report.get("changes", []) as Array).size() if report.has("changes") else 0
		_summary_label.text = "%d row(s) rewritten, %d left for you to check." % [changes, reviews]


## Applies the retype through the variables manager (one undo step) and closes.
func confirm() -> void:
	if _dock == null:
		return
	if _dock._variables.retype_variable(_variable_name, selected_type(), _ordinal):
		_dialog.hide()
