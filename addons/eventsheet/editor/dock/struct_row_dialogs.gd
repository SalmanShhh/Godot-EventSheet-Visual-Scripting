@tool
class_name EventSheetStructRowDialogs
extends RefCounted

# Three small structural-row editors that share the same shape: Enum (name + members),
# Signal (name + params), and Match (expression + GDScript match branches, lint-gated).
#
# Each is a lazily-built ConfirmationDialog parsing a name + a one-per-line TextEdit into a
# resource. Extracted from event_sheet_dock.gd so the dock stays focused; the dock keeps thin
# _open_enum_dialog / _open_signal_dialog / _open_match_dialog delegates so the viewport
# enum/signal/match_edit_requested signal connections keep calling the dock unchanged. This class
# reaches back through the dock reference for the active sheet (the match lint context), the
# undoable-edit wrapper, and the refresh / dirty / status feedback.

var _dock: Control = null


func init(dock: Control) -> void:
	_dock = dock

# ── Enum dialog (name + one field per value, with a "+ Add value" button) ────────────
# Each enum value is its own LineEdit row instead of lines in one TextEdit, so it is unambiguous that
# every value is a separate entry (the "did I add another one?" confusion a shared text field breeds).
# The model is unchanged - members stays a PackedStringArray - so the compile + byte-gated lift are untouched.
var _enum_dialog: ConfirmationDialog = null
var _enum_name_edit: LineEdit = null
var _enum_members_box: VBoxContainer = null
var _enum_member_edits: Array[LineEdit] = []
var _enum_target: EnumRow = null


## Opens the enum editor for an EnumRow (double-click or "Add Enum Below").
func open_enum_dialog(enum_resource: Resource) -> void:
	var enum_row: EnumRow = enum_resource as EnumRow
	if enum_row == null:
		return
	_ensure_enum_dialog()
	_populate_enum_dialog(enum_row)
	_enum_dialog.popup_centered(Vector2i(440, 340))


## Fills the (already-built) dialog with the enum's name and one value field per member - the non-popup
## half of open_enum_dialog, so it is drivable without a window.
func _populate_enum_dialog(enum_row: EnumRow) -> void:
	_enum_target = enum_row
	_enum_name_edit.text = enum_row.enum_name
	# One value field per existing member (at least one empty field so the list is never blank).
	_clear_enum_member_rows()
	if enum_row.members.is_empty():
		_add_enum_member_row("")
	else:
		for member: String in enum_row.members:
			_add_enum_member_row(member)


func _ensure_enum_dialog() -> void:
	if _enum_dialog != null:
		return
	_enum_dialog = ConfirmationDialog.new()
	_enum_dialog.title = "Edit Enum"
	var form: VBoxContainer = EventSheetPopupUI.form_box()
	_enum_name_edit = LineEdit.new()
	_enum_name_edit.placeholder_text = "State"
	form.add_child(EventSheetPopupUI.form_row("Enum name", _enum_name_edit))
	form.add_child(EventSheetPopupUI.hint_label("Values - one per field; optional \"= 4\" to set an explicit number:"))
	# A scroll box so a long value list stays inside the dialog; each value is added as its own row.
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(400.0, 150.0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_enum_members_box = VBoxContainer.new()
	_enum_members_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_enum_members_box)
	form.add_child(scroll)
	var add_button: Button = Button.new()
	add_button.text = "+ Add value"
	add_button.tooltip_text = "Add another enum value"
	add_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	add_button.pressed.connect(func() -> void:
		var edit: LineEdit = _add_enum_member_row("")
		edit.grab_focus())
	form.add_child(add_button)
	_enum_dialog.add_child(EventSheetPopupUI.margined(form))
	_enum_dialog.confirmed.connect(_on_enum_dialog_confirmed)
	_dock.add_child(_enum_dialog)


## Adds one "value field + remove button" row and returns its LineEdit (so callers can focus it).
func _add_enum_member_row(text: String) -> LineEdit:
	var row: HBoxContainer = HBoxContainer.new()
	var edit: LineEdit = LineEdit.new()
	edit.text = text
	edit.placeholder_text = "IDLE"
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.text_submitted.connect(func(_t: String) -> void: _enum_dialog.get_ok_button().grab_focus())
	row.add_child(edit)
	var remove_button: Button = Button.new()
	remove_button.text = "✕"
	remove_button.tooltip_text = "Remove this value"
	remove_button.pressed.connect(_remove_enum_member_row.bind(row, edit))
	row.add_child(remove_button)
	_enum_members_box.add_child(row)
	_enum_member_edits.append(edit)
	return edit


func _remove_enum_member_row(row: HBoxContainer, edit: LineEdit) -> void:
	_enum_member_edits.erase(edit)
	_enum_members_box.remove_child(row)
	row.queue_free()
	# Keep at least one field so the list is never empty and there is always somewhere to type.
	if _enum_member_edits.is_empty():
		_add_enum_member_row("")


func _clear_enum_member_rows() -> void:
	for row: Node in _enum_members_box.get_children():
		_enum_members_box.remove_child(row)
		row.free()
	_enum_member_edits.clear()


func _on_enum_dialog_confirmed() -> void:
	if _enum_target == null:
		return
	var target: EnumRow = _enum_target
	var new_name: String = EventSheetIdentifierRules.sanitize(_enum_name_edit.text)
	if not EventSheetIdentifierRules.is_valid(new_name):
		_dock._set_status("\"%s\" can't be an enum name (letters/digits/underscores, not a GDScript keyword)." % _enum_name_edit.text, true)
		return
	var new_members: PackedStringArray = PackedStringArray()
	for edit: LineEdit in _enum_member_edits:
		var entry: String = edit.text
		if entry.strip_edges().is_empty():
			continue  # a blank field is just an unfilled slot, not an error
		var member_name: String = EventSheetIdentifierRules.sanitize(entry.get_slice("=", 0))
		if not EventSheetIdentifierRules.is_valid(member_name):
			_dock._set_status("\"%s\" can't be an enum value name." % entry.strip_edges(), true)
			return
		var member_text: String = member_name
		if entry.contains("="):
			member_text += " = " + entry.get_slice("=", 1).strip_edges()
		new_members.append(member_text)
	if new_members.is_empty():
		_dock._set_status("Enums need a name and at least one value.", true)
		return
	var changed: bool = _dock._perform_undoable_sheet_edit("Edit Enum", func() -> bool:
		target.enum_name = new_name
		target.members = new_members
		return true
	)
	if changed:
		_dock._refresh_after_edit()
		_dock._mark_dirty("Enum updated (compiles before variables; use it as a variable type).")

# ── Signal + match dialogs ─────────────────────────────────────────────────────────────
var _signal_dialog: ConfirmationDialog = null
var _signal_name_edit: LineEdit = null
var _signal_params_edit: TextEdit = null
var _signal_target: SignalRow = null
var _match_dialog: ConfirmationDialog = null
var _match_expression_edit: LineEdit = null
var _match_branches_edit: TextEdit = null
var _match_hint: Label = null
var _match_target: MatchRow = null


## Opens the signal editor (double-click or "Add Signal Below").
func open_signal_dialog(signal_resource: Resource) -> void:
	var signal_row: SignalRow = signal_resource as SignalRow
	if signal_row == null:
		return
	_ensure_signal_dialog()
	_signal_target = signal_row
	_signal_name_edit.text = signal_row.signal_name
	_signal_params_edit.text = "\n".join(signal_row.params)
	_signal_dialog.popup_centered(Vector2i(420, 280))


func _ensure_signal_dialog() -> void:
	if _signal_dialog != null:
		return
	_signal_dialog = ConfirmationDialog.new()
	_signal_dialog.title = "Edit Signal"
	var form: VBoxContainer = EventSheetPopupUI.form_box()
	_signal_name_edit = LineEdit.new()
	_signal_name_edit.placeholder_text = "hit"
	form.add_child(EventSheetPopupUI.form_row("Signal name", _signal_name_edit))
	form.add_child(EventSheetPopupUI.hint_label("Parameters (one per line; optional \"damage: int\" types)"))
	_signal_params_edit = TextEdit.new()
	_signal_params_edit.custom_minimum_size = Vector2(380.0, 120.0)
	_signal_params_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	form.add_child(_signal_params_edit)
	_signal_dialog.add_child(EventSheetPopupUI.margined(form))
	_signal_dialog.confirmed.connect(_on_signal_dialog_confirmed)
	_dock.add_child(_signal_dialog)


func _on_signal_dialog_confirmed() -> void:
	if _signal_target == null:
		return
	var target: SignalRow = _signal_target
	var new_name: String = EventSheetIdentifierRules.sanitize(_signal_name_edit.text)
	if not EventSheetIdentifierRules.is_valid(new_name):
		_dock._set_status("\"%s\" can't be a signal name (letters/digits/underscores, not a GDScript keyword)." % _signal_name_edit.text, true)
		return
	var new_params: PackedStringArray = PackedStringArray()
	for line: String in _signal_params_edit.text.split("\n"):
		if line.strip_edges().is_empty():
			continue
		var param_name: String = EventSheetIdentifierRules.sanitize(line.get_slice(":", 0))
		if not EventSheetIdentifierRules.is_valid(param_name):
			_dock._set_status("\"%s\" can't be a signal parameter name." % line.strip_edges(), true)
			return
		var param_text: String = param_name
		if line.contains(":"):
			param_text += ": " + line.get_slice(":", 1).strip_edges()
		new_params.append(param_text)
	var changed: bool = _dock._perform_undoable_sheet_edit("Edit Signal", func() -> bool:
		target.signal_name = new_name
		target.params = new_params
		return true
	)
	if changed:
		_dock._refresh_after_edit()
		_dock._mark_dirty("Signal updated (it now appears in the On/Emit Signal pickers).")


## Opens the match editor (double-click a match cell or "Add Match To Actions…").
func open_match_dialog(match_resource: Resource) -> void:
	var match_row: MatchRow = match_resource as MatchRow
	if match_row == null:
		return
	_ensure_match_dialog()
	_match_target = match_row
	_match_expression_edit.text = match_row.match_expression
	_match_branches_edit.text = match_row.branches_text
	_match_hint.text = ""
	_match_dialog.popup_centered(Vector2i(520, 380))


func _ensure_match_dialog() -> void:
	if _match_dialog != null:
		return
	_match_dialog = ConfirmationDialog.new()
	_match_dialog.title = "Edit Match (switch)"
	var form: VBoxContainer = EventSheetPopupUI.form_box()
	_match_expression_edit = LineEdit.new()
	_match_expression_edit.placeholder_text = "state"
	form.add_child(EventSheetPopupUI.form_row("Match expression", _match_expression_edit))
	form.add_child(EventSheetPopupUI.hint_label("Branches (GDScript match-body syntax - patterns + indented bodies)"))
	_match_branches_edit = TextEdit.new()
	_match_branches_edit.custom_minimum_size = Vector2(480.0, 200.0)
	_match_branches_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	form.add_child(_match_branches_edit)
	_match_hint = Label.new()
	form.add_child(_match_hint)
	_match_dialog.add_child(EventSheetPopupUI.margined(form))
	_match_dialog.confirmed.connect(_on_match_dialog_confirmed)
	_dock.add_child(_match_dialog)


func _on_match_dialog_confirmed() -> void:
	if _match_target == null:
		return
	var target: MatchRow = _match_target
	var expression: String = _match_expression_edit.text.strip_edges()
	var branches: String = _match_branches_edit.text
	# Guardrail: the WHOLE construct must compile before it commits.
	var construct: String = "match %s:\n" % expression
	for branch_line: String in branches.split("\n"):
		construct += "\t" + branch_line + "\n"
	var verdict: Dictionary = EventSheetGDScriptLint.lint(construct.trim_suffix("\n"), true, _dock._current_sheet)
	if expression.is_empty() or not bool(verdict.get("ok", true)):
		_match_hint.text = "✗ The match doesn't compile - fix it before applying."
		if _dock.is_inside_tree():
			_match_dialog.call_deferred("popup_centered", Vector2i(520, 380))
		return
	var changed: bool = _dock._perform_undoable_sheet_edit("Edit Match", func() -> bool:
		target.match_expression = expression
		target.branches_text = branches
		return true
	)
	if changed:
		_dock._refresh_after_edit()
		_dock._mark_dirty("Match updated.")
