@tool
class_name EventSheetVariableRetypeDialog
extends RefCounted
# "Change Type Everywhere..." - the guided retype on the variable context menu.
#
# Pick the new type, READ the list of rows that will be rewritten, then press the button: the
# declaration, its default and every value field that stands in an assignment or comparison with
# the variable change in ONE undo step. Rows the refactor refuses to guess at (an expression, a
# literal with no honest conversion) get a card of their own, "Left for you to check", so the
# dialog tells you where to look instead of quietly leaving the old shape behind - and never mixes
# them into the list of what the button writes.
#
# The dialog owns no rules: the whole preview comes from EventSheetVariableRetype.plan and the
# commit from .apply, so what is shown and what happens are the same scan. The type list is the
# variable dialog's own (VariableDialog.add_type_items), so retyping offers exactly the types
# creating offered, each with the sentence that says what it holds.
#
# Headless-safe by construction: everything except the popup itself runs without a tree, and
# `preview_lines()` is the tested surface - the suite reads the very strings the lists show.

var _dock: Control = null
var _dialog: AcceptDialog = null
var _type_option: OptionButton = null
var _summary_label: Label = null
var _preview_list: ItemList = null
var _review_list: ItemList = null
var _review_card: Control = null
## The foot: the chosen type's sentence kept in view, and the declaration it would write.
var _strip: EventSheetPopupUI.HelpStrip = null
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
		_dock._set_status(EventSheetL10n.translate("Right-click a variable to change its type."), true)
		return
	_ordinal = EventSheetVariableRetype.ordinal_of(_dock._current_sheet, entry) if _dock != null else -1
	_build_dialog()
	_dialog.title = EventSheetL10n.translate("Change the type of %s everywhere") % _variable_name
	select_type(str(entry.get("type", "Variant")))
	refresh_preview()
	if _dock.is_inside_tree():
		_dialog.popup_centered(Vector2i(int(EventSheetPalette.scaled_f(560.0)), int(EventSheetPalette.scaled_f(500.0))))


func _build_dialog() -> void:
	if _dialog != null:
		return
	_dialog = AcceptDialog.new()
	_dialog.ok_button_text = EventSheetL10n.translate("Change It Everywhere")
	_dialog.add_cancel_button(EventSheetL10n.translate("Cancel"))
	_dialog.confirmed.connect(confirm)
	var content: VBoxContainer = EventSheetPopupUI.form_box()
	content.add_child(EventSheetPopupUI.hint_label(EventSheetL10n.translate("Changes the variable's type AND every row that sets or compares it, in one step you can undo. Values it cannot convert on its own are listed below rather than guessed at.")))
	_type_option = EventSheetPopupUI.described_option()
	VariableDialog.add_type_items(_type_option)
	_type_option.item_selected.connect(func(_index: int) -> void: refresh_preview())
	content.add_child(EventSheetPopupUI.titled_card(EventSheetL10n.translate("Make it a…"),
		EventSheetPopupUI.form_row(EventSheetL10n.translate("New type"), _type_option)))
	var preview_box: VBoxContainer = EventSheetPopupUI.form_box()
	_summary_label = EventSheetPopupUI.hint_label("")
	preview_box.add_child(_summary_label)
	_preview_list = EventSheetPopupUI.sized_list(150.0)
	preview_box.add_child(_preview_list)
	content.add_child(EventSheetPopupUI.titled_card(EventSheetL10n.translate("What will change"), preview_box))
	_review_list = EventSheetPopupUI.sized_list(60.0)
	_review_card = EventSheetPopupUI.titled_card(EventSheetL10n.translate("Left for you to check"), _review_list)
	content.add_child(_review_card)
	_strip = EventSheetPopupUI.help_strip()
	content.add_child(_strip)
	_dialog.add_child(EventSheetPopupUI.margined(content))
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
			EventSheetPopupUI.follow_description(_type_option)
			return
	EventSheetPopupUI.add_described_item(_type_option, type_name,
		EventSheetL10n.translate("The type this variable already has."), type_name)
	_type_option.select(_type_option.item_count - 1)
	EventSheetPopupUI.follow_description(_type_option)


## The plan for the type picked now - the one scan the lists, the summary and the button all read.
func _plan() -> Dictionary:
	if _dock == null or _dock._current_sheet == null:
		return {}
	return EventSheetVariableRetype.plan(_dock._current_sheet, _variable_name, selected_type(), _ordinal)


## The preview, exactly as the two lists show it: [rewritten, left for you to check]. The rewritten
## list leads with the declaration line, then one line per rewritten field; the other list holds one
## line per row left alone with the reason.
func preview_parts(report: Dictionary) -> Array[PackedStringArray]:
	var rewritten: PackedStringArray = PackedStringArray()
	var left: PackedStringArray = PackedStringArray()
	if report.is_empty():
		return [rewritten, left]
	if not bool(report.get("found", false)):
		rewritten.append(EventSheetL10n.translate("%s is not declared in this sheet.") % _variable_name)
		return [rewritten, left]
	rewritten.append(EventSheetL10n.translate("Declaration: %s is %s, becomes %s") % [
		_variable_name, str(report.get("old_type", "")), selected_type()])
	if bool(report.get("default_changed", false)):
		rewritten.append(EventSheetL10n.translate("Default: %s becomes %s") % [
			str(report.get("default_before", "")), str(report.get("default_after", ""))])
	for change: Dictionary in (report.get("changes", []) as Array):
		rewritten.append(EventSheetL10n.translate("%s - %s %s: %s becomes %s") % [str(change.get("where", "")),
			_display_name(change), str(change.get("param", "")), str(change.get("before", "")),
			str(change.get("after", ""))])
	for review: Dictionary in (report.get("reviews", []) as Array):
		left.append(EventSheetL10n.translate("%s - %s %s: %s left as written (%s)") % [str(review.get("where", "")),
			_display_name(review), str(review.get("param", "")), str(review.get("before", "")),
			str(review.get("why", ""))])
	return [rewritten, left]


## Both lists as one, in reading order. The suite reads THIS.
func preview_lines() -> PackedStringArray:
	var parts: Array[PackedStringArray] = preview_parts(_plan())
	return parts[0] + parts[1]


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
	var report: Dictionary = _plan()
	var parts: Array[PackedStringArray] = preview_parts(report)
	_fill_list(_preview_list, parts[0])
	_fill_list(_review_list, parts[1])
	# A card with nothing under it would say there is something to check when there is not.
	_review_card.visible = not parts[1].is_empty()
	# Nothing to change when the name is not declared here: the preview says so, and the button that
	# would apply it is off rather than pressable into a silent no-op.
	_dialog.get_ok_button().disabled = not bool(report.get("found", false))
	_summary_label.text = EventSheetL10n.translate("%d row(s) rewritten, %d left for you to check.") % [
		(report.get("changes", []) as Array).size(), parts[1].size()]
	_strip.show_note(_type_option.get_item_text(_type_option.selected), _type_option.get_item_tooltip(_type_option.selected))
	_strip.set_reading("", "var %s: %s = %s" % [_variable_name, selected_type(), str(report.get("default_after", ""))]
		if bool(report.get("found", false)) else "")


## One list, each line with its whole sentence as the tooltip: an expression left as written is
## often wider than the list, and nothing the preview promises to say may be only half-said.
static func _fill_list(list: ItemList, lines: PackedStringArray) -> void:
	list.clear()
	for line: String in lines:
		list.add_item(line)
		list.set_item_tooltip(list.item_count - 1, line)


## Applies the retype through the variables manager (one undo step) and closes.
func confirm() -> void:
	if _dock == null:
		return
	if _dock._variables.retype_variable(_variable_name, selected_type(), _ordinal):
		_dialog.hide()
