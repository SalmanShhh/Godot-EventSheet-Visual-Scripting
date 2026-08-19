@tool
class_name EventSheetInstanceVariableTable
extends RefCounted
# The INSTANCE VARIABLES table - the object's own variables, edited where they are read.
#
#   Name      Type            Initial value   Inspector
#   speed     number      ▾   200             ☑          ✎ ✕
#   hp        number      ▾   100             ☐          ✎ ✕
#   alive     boolean     ▾   true            ☐          ✎ ✕
#   + Add instance variable
#
# Until now a variable was created from the Add variable dialog and changed by finding its row on
# the sheet and double-clicking it; Object properties listed the same variables as read-only chips.
# One table answers all of it: add, rename, retype, revalue, show-in-the-Inspector and delete from
# the same place, on the Object properties popup and on the Properties bar.
#
# The table writes NOTHING itself. Every edit mutates the same model the Add variable dialog
# mutates - a tree-placed LocalVariable or the sheet's variables descriptor - inside
# _perform_undoable_sheet_edit, so the `var` / `@export var` line the compiler emits is the same
# line either route produces, and an opened .gd stays byte-exact for every line the edit does not
# touch. It never holds a resource across an edit either: every write re-resolves its variable by
# name against the live sheet, because the undo funnel replaces every resource on commit.
#
# rows_for() is static and display-free, so a test pins exactly what the table says about a sheet
# without a display server.


## One entry per variable the object carries, in the order the sheet declares them. Each:
## {"name", "type_name", "type_word", "value", "inspector", "description", "scope", "storage"}
## where `storage` is "tree" (a LocalVariable placed among the sheet's events) or "sheet" (an entry
## in the sheet's variables descriptor) - the two shapes a member variable is stored in.
static func rows_for(sheet: EventSheetResource) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if sheet == null:
		return rows
	var resource_host: bool = EventSheetVariableSentence.is_resource_host(str(sheet.host_class))
	var autoload: bool = not str(sheet.get("autoload_name")).strip_edges().is_empty()
	for entry: Variant in sheet.events:
		var variable: LocalVariable = entry as LocalVariable
		if variable == null:
			continue
		var attributes: Dictionary = variable.attributes if variable.attributes is Dictionary else {}
		rows.append({
			"name": variable.name,
			"type_name": variable.type_name,
			"type_word": ViewportRowBuilder.friendly_type_word(variable.type_name),
			"value": VariableDialog._default_display_text(variable.default_value),
			"inspector": variable.exported,
			"description": str(attributes.get("tooltip", "")),
			"scope": EventSheetVariableSentence.member_scope(
				variable.is_constant, variable.is_static, autoload, resource_host),
			"storage": "tree"
		})
	var names: Array = sheet.variables.keys()
	names.sort()
	for key: Variant in names:
		var descriptor: Dictionary = sheet.variables.get(key, {})
		var type_name: String = str(descriptor.get("type", "Variant"))
		var descriptor_attributes: Dictionary = descriptor.get("attributes") if descriptor.get("attributes") is Dictionary else {}
		rows.append({
			"name": str(key),
			"type_name": type_name,
			"type_word": ViewportRowBuilder.friendly_type_word(type_name),
			"value": VariableDialog._default_display_text(descriptor.get("default", null)),
			"inspector": bool(descriptor.get("exported", descriptor.get("exposed", true))),
			"description": str(descriptor_attributes.get("tooltip", "")),
			"scope": EventSheetVariableSentence.member_scope(
				bool(descriptor.get("const", descriptor.get("is_constant", false))),
				false, autoload, resource_host),
			"storage": "sheet"
		})
	return rows


## One row read back as plain text, so a test pins what the table says without walking Controls:
## `speed  number  200  Inspector`.
static func row_text(row: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray([
		str(row.get("name", "")), str(row.get("type_word", "")), str(row.get("value", ""))
	])
	if bool(row.get("inspector", false)):
		parts.append(EventSheetL10n.translate("Inspector"))
	return "  ".join(parts)


# ── The live table (editor only) ───────────────────────────────────────────────────────────────

var _dock: Control = null
# The names whose description line is folded open. Kept per table (not per rebuild) so a rebuild
# after an edit does not close the field the user is typing into.
var _open_descriptions: Dictionary = {}


func init(dock: Control) -> void:
	_dock = dock


## The whole table as one control: the header words, a line per variable, and the add button.
## Returns null when the sheet carries no variables AND cannot take one (no dock), so a caller can
## simply skip the section.
func build_for(sheet: EventSheetResource) -> Control:
	if _dock == null:
		return null
	var column: VBoxContainer = EventSheetPopupUI.form_box()
	var grid: GridContainer = GridContainer.new()
	grid.columns = 5
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", int(EventSheetPalette.scaled_f(10.0)))
	for header: String in [
		EventSheetL10n.translate("Name"), EventSheetL10n.translate("Type"),
		EventSheetL10n.translate("Initial value"), EventSheetL10n.translate("Inspector"), ""
	]:
		grid.add_child(EventSheetPopupUI.hint_label(header, EventSheetPalette.scaled_f(90.0)))
	var rows: Array[Dictionary] = rows_for(sheet)
	for row: Dictionary in rows:
		_add_variable_line(grid, row)
	column.add_child(grid)
	if rows.is_empty():
		column.add_child(EventSheetPopupUI.hint_label(
			EventSheetL10n.translate("This object has no instance variables yet.")))
	var add_button: Button = Button.new()
	add_button.text = EventSheetL10n.translate("+ Add instance variable")
	add_button.pressed.connect(func() -> void: _add_variable())
	column.add_child(add_button)
	column.add_child(EventSheetPopupUI.hint_label(
		EventSheetL10n.translate("Renaming here renames every use of the variable.")))
	return EventSheetPopupUI.panel_section(column)


func _add_variable_line(grid: GridContainer, row: Dictionary) -> void:
	var variable_name: String = str(row.get("name", ""))
	var name_edit: LineEdit = LineEdit.new()
	name_edit.text = variable_name
	name_edit.custom_minimum_size = Vector2(EventSheetPalette.scaled_f(110.0), 0.0)
	name_edit.tooltip_text = EventSheetL10n.translate(
		"Enter renames the variable and every use of it.")
	name_edit.text_submitted.connect(func(text: String) -> void: _rename(variable_name, text))
	grid.add_child(name_edit)
	var type_picker: OptionButton = OptionButton.new()
	var type_word: String = str(row.get("type_word", ""))
	var offered: PackedStringArray = EventSheetVariableSentence.TYPE_WORD_ORDER
	# A type the shortlist has no word for (a class, a typed list, a scene) is still shown - as its
	# own word, selected, so retyping is never a trap that silently drops what the author wrote.
	if not offered.has(type_word):
		type_picker.add_item(type_word)
		type_picker.set_item_metadata(0, str(row.get("type_name", "")))
	for word: String in offered:
		type_picker.add_item(EventSheetL10n.translate(word))
		type_picker.set_item_metadata(type_picker.item_count - 1,
			str(EventSheetVariableSentence.TYPE_WORD_TO_GDSCRIPT.get(word, "Variant")))
		if word == type_word:
			type_picker.selected = type_picker.item_count - 1
	if not offered.has(type_word):
		type_picker.selected = 0
	type_picker.item_selected.connect(func(index: int) -> void:
		_retype(variable_name, str(type_picker.get_item_metadata(index))))
	grid.add_child(type_picker)
	var value_edit: LineEdit = LineEdit.new()
	value_edit.text = str(row.get("value", ""))
	value_edit.custom_minimum_size = Vector2(EventSheetPalette.scaled_f(110.0), 0.0)
	value_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_edit.tooltip_text = EventSheetL10n.translate("Enter applies. One undo step.")
	value_edit.text_submitted.connect(func(text: String) -> void: _revalue(variable_name, text))
	grid.add_child(value_edit)
	var inspector_check: CheckBox = CheckBox.new()
	inspector_check.button_pressed = bool(row.get("inspector", false))
	inspector_check.tooltip_text = EventSheetL10n.translate(
		"Editable in the Inspector (a designer property).")
	inspector_check.toggled.connect(func(on: bool) -> void: _set_inspector(variable_name, on))
	grid.add_child(inspector_check)
	var trailing: HBoxContainer = HBoxContainer.new()
	var describe: Button = Button.new()
	describe.text = "✎"
	describe.tooltip_text = EventSheetL10n.translate("Describe this variable")
	describe.pressed.connect(func() -> void: _toggle_description(variable_name))
	trailing.add_child(describe)
	var remove: Button = Button.new()
	remove.text = "✕"
	remove.tooltip_text = EventSheetL10n.translate("Delete this variable")
	remove.pressed.connect(func() -> void: _delete(variable_name))
	trailing.add_child(remove)
	grid.add_child(trailing)
	if not bool(_open_descriptions.get(variable_name, false)):
		return
	# The description column FOLDS OPEN under its variable rather than standing as a fifth column -
	# a sentence needs the width of the table, and most variables never carry one.
	grid.add_child(EventSheetPopupUI.hint_label(EventSheetL10n.translate("Description"),
		EventSheetPalette.scaled_f(90.0)))
	var description_edit: LineEdit = LineEdit.new()
	description_edit.text = str(row.get("description", ""))
	description_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	description_edit.text_submitted.connect(func(text: String) -> void:
		_describe(variable_name, text))
	grid.add_child(description_edit)
	grid.add_child(Control.new())
	grid.add_child(Control.new())
	grid.add_child(Control.new())


func _toggle_description(variable_name: String) -> void:
	_open_descriptions[variable_name] = not bool(_open_descriptions.get(variable_name, false))
	_dock._refresh_after_edit()


## "+ Add instance variable" opens the Add variable dialog on the Instance scope, so one dialog
## still owns every field a new variable can carry (type, description, Inspector, the drawers).
func _add_variable() -> void:
	if not _dock._ensure_sheet_for_editing():
		return
	_dock._variable_dlg.open_for_edit(
		"tree", {}, "", "float", "0", false, EventSheetL10n.translate("Add variable"), false, false)


## Renaming in the table IS Rename Everywhere - a variable's name is used by rows all over the
## sheet, and a table that renamed only the declaration would break them all silently.
func _rename(variable_name: String, new_name: String) -> void:
	if new_name.strip_edges().is_empty() or new_name == variable_name:
		return
	_dock._open_rename_dialog(variable_name)


func _retype(variable_name: String, type_name: String) -> void:
	if type_name.is_empty():
		return
	# Change Type Everywhere: the declaration AND every row that sets or compares it, one undo step.
	_dock._variables.retype_variable(variable_name, type_name)


func _revalue(variable_name: String, text: String) -> void:
	var type_name: String = _type_name_of(variable_name)
	var parsed: Variant = VariableDialog._parse_default(type_name, text)
	_write(variable_name, "Set %s" % variable_name,
		func(variable: LocalVariable) -> void: variable.default_value = parsed,
		func(descriptor: Dictionary) -> void: descriptor["default"] = parsed)


func _set_inspector(variable_name: String, shown: bool) -> void:
	_write(variable_name, "Show %s in the Inspector" % variable_name,
		func(variable: LocalVariable) -> void: variable.exported = shown,
		func(descriptor: Dictionary) -> void: _write_inspector(descriptor, shown))


## Both keys, always: the descriptor has carried `exposed` since before `exported` existed and
## readers still fall back to it, so writing one and leaving the other would let them disagree.
static func _write_inspector(descriptor: Dictionary, shown: bool) -> void:
	descriptor["exported"] = shown
	descriptor["exposed"] = shown


func _describe(variable_name: String, text: String) -> void:
	var description: String = text.strip_edges()
	_write(variable_name, "Describe %s" % variable_name,
		func(variable: LocalVariable) -> void: _write_tree_tooltip(variable, description),
		func(descriptor: Dictionary) -> void: _write_sheet_tooltip(descriptor, description))


static func _write_tree_tooltip(variable: LocalVariable, description: String) -> void:
	variable.attributes = _with_tooltip(variable.attributes, description)


static func _write_sheet_tooltip(descriptor: Dictionary, description: String) -> void:
	var attributes: Dictionary = _with_tooltip(descriptor.get("attributes"), description)
	if attributes.is_empty():
		descriptor.erase("attributes")
	else:
		descriptor["attributes"] = attributes


static func _with_tooltip(source: Variant, description: String) -> Dictionary:
	var attributes: Dictionary = (source as Dictionary).duplicate(true) if source is Dictionary else {}
	if description.is_empty():
		attributes.erase("tooltip")
	else:
		attributes["tooltip"] = description
	return attributes


func _delete(variable_name: String) -> void:
	var sheet: EventSheetResource = _dock._current_sheet
	if sheet == null:
		return
	var removed: bool = _dock._perform_undoable_sheet_edit("Delete %s" % variable_name,
		func() -> bool:
			var live: EventSheetResource = _dock._current_sheet
			for index: int in range(live.events.size()):
				var variable: LocalVariable = live.events[index] as LocalVariable
				if variable != null and variable.name == variable_name:
					live.events.remove_at(index)
					return true
			if live.variables.has(variable_name):
				live.variables.erase(variable_name)
				return true
			return false)
	if removed:
		_open_descriptions.erase(variable_name)
		_dock._refresh_after_edit()
		_dock._mark_dirty("Deleted variable %s." % variable_name)


func _type_name_of(variable_name: String) -> String:
	for row: Dictionary in rows_for(_dock._current_sheet):
		if str(row.get("name", "")) == variable_name:
			return str(row.get("type_name", "Variant"))
	return "Variant"


## The one write path: re-resolve the variable by name against the LIVE sheet inside the funnel,
## then apply whichever half of the pair matches how it is stored. Holding the resource from when
## the field was built would write into a snapshot the commit has already replaced.
func _write(variable_name: String, undo_label: String, on_tree: Callable, on_sheet: Callable) -> void:
	if _dock._current_sheet == null or variable_name.is_empty():
		return
	var changed: bool = _dock._perform_undoable_sheet_edit(undo_label, func() -> bool:
		var live: EventSheetResource = _dock._current_sheet
		for entry: Variant in live.events:
			var variable: LocalVariable = entry as LocalVariable
			if variable != null and variable.name == variable_name:
				on_tree.call(variable)
				return true
		if live.variables.has(variable_name):
			var descriptor: Dictionary = live.variables.get(variable_name, {})
			on_sheet.call(descriptor)
			live.variables[variable_name] = descriptor
			return true
		return false)
	if changed:
		_dock._refresh_after_edit()
		_dock._mark_dirty("%s." % undo_label)
