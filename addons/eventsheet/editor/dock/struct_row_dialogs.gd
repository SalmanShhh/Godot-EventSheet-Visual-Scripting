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
var _match_cases_box: VBoxContainer = null
var _match_case_rows: Array = []  # each: {"pattern": LineEdit, "body": TextEdit, "row": Control}
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


## Opens the match editor (double-click a match cell or "Add Match To Actions…"). The switch is edited as
## first-class cases: one panel per branch (a pattern + the actions to run), added / removed with buttons,
## instead of one GDScript text blob - the same "+ Add" list gesture the enum editor uses.
func open_match_dialog(match_resource: Resource) -> void:
	var match_row: MatchRow = match_resource as MatchRow
	if match_row == null:
		return
	_ensure_match_dialog()
	_populate_match_dialog(match_row)
	_match_dialog.popup_centered(Vector2i(560, 460))


## Fills the (already-built) dialog with the match's expression and one case panel per branch - the non-popup
## half of open_match_dialog, so it is drivable without a window. Populates from the structured `cases` when
## present, else parses branches_text into cases (the same parse the importer uses), else one empty case.
func _populate_match_dialog(match_row: MatchRow) -> void:
	_match_target = match_row
	_match_expression_edit.text = match_row.match_expression
	_match_hint.text = ""
	_clear_match_case_rows()
	var cases: Array[MatchCase] = match_row.cases
	if cases.is_empty() and not match_row.branches_text.strip_edges().is_empty():
		cases = EventSheetACELifter._structure_match_cases(match_row.branches_text.split("\n"))
	if cases.is_empty():
		_add_match_case_row("_", "pass")
	else:
		for match_case: MatchCase in cases:
			_add_match_case_row(match_case.pattern, _case_body_text(match_case))


func _ensure_match_dialog() -> void:
	if _match_dialog != null:
		return
	_match_dialog = ConfirmationDialog.new()
	_match_dialog.title = "Edit Match (switch)"
	var form: VBoxContainer = EventSheetPopupUI.form_box()
	_match_expression_edit = LineEdit.new()
	_match_expression_edit.placeholder_text = "state"
	form.add_child(EventSheetPopupUI.form_row("Match on", _match_expression_edit))
	form.add_child(EventSheetPopupUI.hint_label("One case per branch - a pattern (State.IDLE, 1, _ for default) and the actions to run:"))
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(500.0, 220.0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_match_cases_box = VBoxContainer.new()
	_match_cases_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_match_cases_box)
	form.add_child(scroll)
	var buttons: HBoxContainer = HBoxContainer.new()
	var add_button: Button = Button.new()
	add_button.text = "+ Add case"
	add_button.tooltip_text = "Add another branch"
	add_button.pressed.connect(func() -> void:
		var entry: Dictionary = _add_match_case_row("", "")
		(entry["pattern"] as LineEdit).grab_focus())
	buttons.add_child(add_button)
	# One click adds a case for every value of a sheet enum (patterns pre-filled as Name.MEMBER), so a switch
	# on an enum starts exhaustive and correctly named - the user just fills each body. Non-destructive: it
	# only adds branches not already present and drops empty unfilled slots.
	var fill_button: MenuButton = MenuButton.new()
	fill_button.text = "Fill from enum ▾"
	fill_button.tooltip_text = "Add a case for each value of a sheet enum"
	fill_button.get_popup().about_to_popup.connect(func() -> void:
		var popup: PopupMenu = fill_button.get_popup()
		popup.clear()
		var enums: Array = _sheet_enums()
		for enum_entry: Dictionary in enums:
			popup.add_item(str(enum_entry.get("name")))
			popup.set_item_metadata(popup.item_count - 1, enum_entry)
		if enums.is_empty():
			popup.add_item("(no enums on this sheet)")
			popup.set_item_disabled(0, true))
	fill_button.get_popup().index_pressed.connect(func(index: int) -> void:
		var meta: Variant = fill_button.get_popup().get_item_metadata(index)
		if meta is Dictionary:
			_fill_cases_from_enum(meta as Dictionary))
	buttons.add_child(fill_button)
	form.add_child(buttons)
	_match_hint = Label.new()
	form.add_child(_match_hint)
	_match_dialog.add_child(EventSheetPopupUI.margined(form))
	_match_dialog.confirmed.connect(_on_match_dialog_confirmed)
	_dock.add_child(_match_dialog)


## Adds one case panel (pattern field + remove button, with a body editor beneath) and returns its controls.
func _add_match_case_row(pattern: String, body: String) -> Dictionary:
	var panel: VBoxContainer = VBoxContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var head: HBoxContainer = HBoxContainer.new()
	var pattern_edit: LineEdit = LineEdit.new()
	pattern_edit.text = pattern
	pattern_edit.placeholder_text = "State.IDLE  (or _ for default)"
	pattern_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(pattern_edit)
	# Autocomplete: a picker that suggests valid patterns for what the switch is ON - an enum variable's
	# members (State.IDLE, …), true / false for a bool, or any sheet enum otherwise - so the pattern is
	# steered to a real value instead of typed by hand (and still freely editable). The list filters by what
	# is typed (reusing the ACE param dialog's shared popup filter), and Down in the field opens it.
	var pick: MenuButton = MenuButton.new()
	pick.text = "▾"
	pick.tooltip_text = "Pick a valid value for this branch (you can still type any)"
	var pick_popup: PopupMenu = pick.get_popup()
	pick_popup.about_to_popup.connect(func() -> void:
		ACEParamsDialog._rebuild_autocomplete_popup(pick_popup, PackedStringArray(_match_pattern_choices()), pattern_edit.text))
	pick_popup.id_pressed.connect(func(picked_id: int) -> void:
		var choices: Array = _match_pattern_choices()
		if picked_id >= 0 and picked_id < choices.size():
			pattern_edit.text = str(choices[picked_id])
			pattern_edit.caret_column = pattern_edit.text.length()
			pattern_edit.grab_focus())
	head.add_child(pick)
	pattern_edit.gui_input.connect(func(event: InputEvent) -> void:
		var key_event: InputEventKey = event as InputEventKey
		if key_event != null and key_event.pressed and key_event.keycode == KEY_DOWN:
			ACEParamsDialog._rebuild_autocomplete_popup(pick_popup, PackedStringArray(_match_pattern_choices()), pattern_edit.text)
			pick_popup.position = Vector2i(pattern_edit.get_screen_position() + Vector2(0.0, pattern_edit.size.y))
			pick_popup.reset_size()
			pick_popup.popup()
			pattern_edit.accept_event())
	var remove_button: Button = Button.new()
	remove_button.text = "✕"
	remove_button.tooltip_text = "Remove this case"
	head.add_child(remove_button)
	panel.add_child(head)
	var body_edit: TextEdit = TextEdit.new()
	body_edit.text = body
	body_edit.placeholder_text = "actions to run (leave blank for pass)"
	body_edit.custom_minimum_size = Vector2(480.0, 52.0)
	panel.add_child(body_edit)
	_match_cases_box.add_child(panel)
	var entry: Dictionary = {"pattern": pattern_edit, "body": body_edit, "row": panel}
	remove_button.pressed.connect(_remove_match_case_row.bind(entry))
	_match_case_rows.append(entry)
	return entry


func _remove_match_case_row(entry: Dictionary) -> void:
	_match_case_rows.erase(entry)
	_match_cases_box.remove_child(entry["row"])
	(entry["row"] as Node).queue_free()
	if _match_case_rows.is_empty():
		_add_match_case_row("_", "pass")


func _clear_match_case_rows() -> void:
	for entry: Dictionary in _match_case_rows:
		_match_cases_box.remove_child(entry["row"])
		(entry["row"] as Node).free()
	_match_case_rows.clear()


## The body text a case shows in the editor: its RawCodeRow bodies joined (empty for a `pass`-only case).
func _case_body_text(match_case: MatchCase) -> String:
	var lines: PackedStringArray = PackedStringArray()
	for item: Variant in match_case.events:
		if item is RawCodeRow:
			lines.append((item as RawCodeRow).code)
	return "\n".join(lines)


## The sheet's enums as [{name, members}], read straight off the live sheet (the same shape the variable
## dialog uses) - no provider callable, since the dialog already has the dock.
func _sheet_enums() -> Array:
	var out: Array = []
	var sheet: EventSheetResource = _dock._current_sheet
	if sheet == null:
		return out
	var rows: Array = []
	SheetCompiler._collect_enum_rows(sheet.events, rows)  # group-recursive, so enums inside groups count too
	for row: Variant in rows:
		if row is EnumRow and (row as EnumRow).enabled:
			out.append({"name": (row as EnumRow).enum_name, "members": (row as EnumRow).members})
	return out


## The declared type name of a sheet variable (a tree LocalVariable row or a dict-form sheet variable), or
## "" when the name isn't a known variable. Used to steer the case patterns by what the switch is ON.
func _sheet_variable_type(var_name: String) -> String:
	var sheet: EventSheetResource = _dock._current_sheet
	if sheet == null or var_name.is_empty():
		return ""
	if sheet.variables is Dictionary and (sheet.variables as Dictionary).has(var_name):
		var entry: Variant = (sheet.variables as Dictionary)[var_name]
		return str((entry as Dictionary).get("type", "")) if entry is Dictionary else ""
	for row: Variant in sheet.events:
		if row is LocalVariable and (row as LocalVariable).name == var_name:
			return (row as LocalVariable).type_name
	return ""


## The name of the sheet enum the switch is ON (its subject variable's type is that enum), or "".
func _subject_enum_name() -> String:
	var expr: String = _match_expression_edit.text.strip_edges()
	var ident: RegEx = RegEx.new()
	if ident.compile("^([A-Za-z_][A-Za-z0-9_]*)") != OK:
		return ""
	var leading: RegExMatch = ident.search(expr)
	if leading == null:
		return ""
	var type_name: String = _sheet_variable_type(leading.get_string(1))
	for enum_entry: Dictionary in _sheet_enums():
		if str(enum_entry.get("name")) == type_name:
			return type_name
	return ""


## The pattern values offered for a case (the "autocomplete"). When the switch is on a known enum variable,
## only that enum's members (Name.MEMBER); true / false when it's a bool; otherwise every sheet enum's
## members (so any is pickable). Always ends with `_` (the default branch). Member "= 4" values are stripped.
func _match_pattern_choices() -> Array:
	var choices: Array = []
	var subject_enum: String = _subject_enum_name()
	for enum_entry: Dictionary in _sheet_enums():
		var enum_name: String = str(enum_entry.get("name"))
		if not subject_enum.is_empty() and enum_name != subject_enum:
			continue  # the switched type is known - offer only its values
		for member: Variant in enum_entry.get("members", []):
			choices.append("%s.%s" % [enum_name, str(member).get_slice("=", 0).strip_edges()])
	var ident: RegEx = RegEx.new()
	if ident.compile("^([A-Za-z_][A-Za-z0-9_]*)") == OK:
		var leading: RegExMatch = ident.search(_match_expression_edit.text.strip_edges())
		if leading != null and _sheet_variable_type(leading.get_string(1)) == "bool":
			choices.append("true")
			choices.append("false")
	choices.append("_")
	return choices


## Adds one case per value of the given sheet enum (patterns as Name.MEMBER), skipping values already present
## and dropping empty unfilled slots, then a `_` default - so a switch on an enum starts exhaustive.
func _fill_cases_from_enum(enum_entry: Dictionary) -> void:
	var enum_name: String = str(enum_entry.get("name"))
	var existing: Array = []
	for entry: Dictionary in _match_case_rows:
		var pattern: String = (entry["pattern"] as LineEdit).text.strip_edges()
		if not pattern.is_empty():
			existing.append(pattern)
	# Drop purely-empty slots (blank pattern AND body) so filling does not leave stray rows.
	for entry: Dictionary in _match_case_rows.duplicate():
		if (entry["pattern"] as LineEdit).text.strip_edges().is_empty() and (entry["body"] as TextEdit).text.strip_edges().is_empty():
			_match_case_rows.erase(entry)
			_match_cases_box.remove_child(entry["row"])
			(entry["row"] as Node).free()
	for member: Variant in enum_entry.get("members", []):
		var pattern: String = "%s.%s" % [enum_name, str(member).get_slice("=", 0).strip_edges()]
		if not existing.has(pattern):
			_add_match_case_row(pattern, "")
			existing.append(pattern)
	if not existing.has("_"):
		_add_match_case_row("_", "")


func _on_match_dialog_confirmed() -> void:
	if _match_target == null:
		return
	var target: MatchRow = _match_target
	var expression: String = _match_expression_edit.text.strip_edges()
	# Build cases from the panels; a blank pattern is an unfilled slot (skipped), an empty body compiles to
	# `pass`. The body text is stripped of surrounding whitespace so a blank line never truncates the re-lift.
	var new_cases: Array[MatchCase] = []
	for entry: Dictionary in _match_case_rows:
		var pattern: String = (entry["pattern"] as LineEdit).text.strip_edges()
		if pattern.is_empty():
			continue
		var body: String = (entry["body"] as TextEdit).text.strip_edges()
		var match_case: MatchCase = MatchCase.new()
		match_case.pattern = pattern
		if not body.is_empty():
			var raw: RawCodeRow = RawCodeRow.new()
			raw.code = body
			match_case.events = [raw]
		new_cases.append(match_case)
	# Guardrail: the WHOLE construct must compile before it commits.
	var verdict: Dictionary = EventSheetGDScriptLint.lint(_match_construct_preview(expression, new_cases), true, _dock._current_sheet)
	if expression.is_empty() or new_cases.is_empty() or not bool(verdict.get("ok", true)):
		_match_hint.text = "✗ The match doesn't compile - fix it before applying."
		if _dock.is_inside_tree():
			_match_dialog.call_deferred("popup_centered", Vector2i(560, 460))
		return
	var branches: String = _match_branches_from_cases(new_cases)
	var changed: bool = _dock._perform_undoable_sheet_edit("Edit Match", func() -> bool:
		target.match_expression = expression
		target.cases = new_cases
		target.branches_text = branches  # kept in sync as the raw fallback
		return true
	)
	if changed:
		_dock._refresh_after_edit()
		_dock._mark_dirty("Match updated.")


## The whole match construct (for the lint gate): `match expr:` + each case's pattern and its body one indent
## deeper, an empty body as `pass`.
func _match_construct_preview(expression: String, cases: Array[MatchCase]) -> String:
	var lines: PackedStringArray = PackedStringArray(["match %s:" % expression])
	for match_case: MatchCase in cases:
		lines.append("\t" + match_case.pattern + ":")
		var body_text: String = _case_body_text(match_case)
		if body_text.strip_edges().is_empty():
			lines.append("\t\tpass")
		else:
			for body_line: String in body_text.split("\n"):
				lines.append("\t\t" + body_line)
	return "\n".join(lines)


## The verbatim branches_text form kept in sync with the cases (the raw fallback / what the importer lifts).
func _match_branches_from_cases(cases: Array[MatchCase]) -> String:
	var lines: PackedStringArray = PackedStringArray()
	for match_case: MatchCase in cases:
		lines.append(match_case.pattern + ":")
		var body_text: String = _case_body_text(match_case)
		if body_text.strip_edges().is_empty():
			lines.append("\tpass")
		else:
			for body_line: String in body_text.split("\n"):
				lines.append("\t" + body_line)
	return "\n".join(lines)
