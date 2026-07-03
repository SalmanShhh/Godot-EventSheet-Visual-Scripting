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

# ── Enum dialog (name + members, one per line) ───────────────────────────────────────
var _enum_dialog: ConfirmationDialog = null
var _enum_name_edit: LineEdit = null
var _enum_members_edit: TextEdit = null
var _enum_target: EnumRow = null


## Opens the enum editor for an EnumRow (double-click or "Add Enum Below").
func open_enum_dialog(enum_resource: Resource) -> void:
	var enum_row: EnumRow = enum_resource as EnumRow
	if enum_row == null:
		return
	_ensure_enum_dialog()
	_enum_target = enum_row
	_enum_name_edit.text = enum_row.enum_name
	_enum_members_edit.text = "
".join(enum_row.members)
	_enum_dialog.popup_centered(Vector2i(420, 300))


func _ensure_enum_dialog() -> void:
	if _enum_dialog != null:
		return
	_enum_dialog = ConfirmationDialog.new()
	_enum_dialog.title = "Edit Enum"
	var form: VBoxContainer = EventSheetPopupUI.form_box()
	_enum_name_edit = LineEdit.new()
	_enum_name_edit.placeholder_text = "State"
	form.add_child(EventSheetPopupUI.form_row("Enum name", _enum_name_edit))
	form.add_child(EventSheetPopupUI.hint_label("Members (one per line; optional \"NAME = 4\" values)"))
	_enum_members_edit = TextEdit.new()
	_enum_members_edit.custom_minimum_size = Vector2(380.0, 150.0)
	_enum_members_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	form.add_child(_enum_members_edit)
	_enum_dialog.add_child(EventSheetPopupUI.margined(form))
	_enum_dialog.confirmed.connect(_on_enum_dialog_confirmed)
	_dock.add_child(_enum_dialog)


func _on_enum_dialog_confirmed() -> void:
	if _enum_target == null:
		return
	var target: EnumRow = _enum_target
	var new_name: String = EventSheetIdentifierRules.sanitize(_enum_name_edit.text)
	if not EventSheetIdentifierRules.is_valid(new_name):
		_dock._set_status("\"%s\" can't be an enum name (letters/digits/underscores, not a GDScript keyword)." % _enum_name_edit.text, true)
		return
	var new_members: PackedStringArray = PackedStringArray()
	for line: String in _enum_members_edit.text.split("
"):
		if line.strip_edges().is_empty():
			continue
		var member_name: String = EventSheetIdentifierRules.sanitize(line.get_slice("=", 0))
		if not EventSheetIdentifierRules.is_valid(member_name):
			_dock._set_status("\"%s\" can't be an enum member name." % line.strip_edges(), true)
			return
		var member_text: String = member_name
		if line.contains("="):
			member_text += " = " + line.get_slice("=", 1).strip_edges()
		new_members.append(member_text)
	if new_members.is_empty():
		_dock._set_status("Enums need a name and at least one member.", true)
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
	form.add_child(EventSheetPopupUI.hint_label("Branches (GDScript match-body syntax — patterns + indented bodies)"))
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
		_match_hint.text = "✗ The match doesn't compile — fix it before applying."
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
