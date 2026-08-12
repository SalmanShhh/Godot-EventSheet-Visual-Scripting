@tool
class_name EventSheetPasteSpecialDialog
extends RefCounted
# "Paste Special..." - paste copied rows retargeted, in one gesture.
#
# Copy already puts a portable snippet on the system clipboard and Paste already creates the sheet
# variables it needs. What was missing is choosing what the pasted rows point AT: this dialog lists
# every object reference and every variable name the snippet carries, each with a target field, and
# pastes the remapped rows in ONE step. That is what reusing a Player-wired pattern for an Enemy,
# fanning one door pattern over eight doors, or pasting a teammate's snippet whose names collide
# actually needs - instead of pasting and then hunting through Replace Object References twice.
#
# The variable side answers create-versus-reuse in words as you type: a name this sheet already has
# REUSES that declaration (paste never overwrites one), a name it lacks CREATES it. No radio button
# to misread - the sentence beside the field says which will happen.
#
# The remap itself is EventSheetPasteSpecial (shipped refactor machinery, deep-copied rows) and the
# insertion is the clipboard helper's own paste path, so pasted events still get fresh uids and
# missing variables are still declared. `confirm()` is the tested surface; `open()` accepts a
# snippet directly so the suite never has to touch the OS clipboard.

var _dock: Control = null
var _dialog: AcceptDialog = null
var _rows_box: VBoxContainer = null
var _summary_label: Label = null
var _snippet: Dictionary = {}
var _object_fields: Array[Dictionary] = []
var _variable_fields: Array[Dictionary] = []


func init(dock: Control) -> void:
	_dock = dock


## Opens the dialog for the clipboard's snippet (or `snippet_override`, which is how the suite
## drives it). Says so plainly when there is nothing to paste specially.
func open(snippet_override: Dictionary = {}) -> void:
	_snippet = snippet_override if not snippet_override.is_empty() else EventSheetSnippet.deserialize(EventSheetSnippet.clipboard_text())
	var rows: Array = _snippet.get("rows", []) if _snippet.get("rows") is Array else []
	if rows.is_empty():
		_dock._set_status("Copy some rows first - Paste Special retargets a copied snippet.", true)
		return
	_build_dialog()
	_populate(rows)
	if _dock.is_inside_tree():
		_dialog.popup_centered(Vector2i(560, 460))


func _build_dialog() -> void:
	if _dialog != null:
		return
	_dialog = AcceptDialog.new()
	_dialog.title = "Paste Special"
	_dialog.ok_button_text = "Paste Retargeted"
	_dialog.add_cancel_button("Cancel")
	_dialog.confirmed.connect(func() -> void: confirm())
	var content: VBoxContainer = EventSheetPopupUI.form_box()
	content.add_child(EventSheetPopupUI.hint_label("Point the copied rows at something else on the way in. Object references are rewritten token-safely ($Enemy never touches $EnemySpawner); a variable name this sheet already has is reused, one it lacks is created."))
	_rows_box = EventSheetPopupUI.form_box()
	content.add_child(EventSheetPopupUI.titled_card("Point it at…", _rows_box))
	_summary_label = EventSheetPopupUI.hint_label("")
	content.add_child(_summary_label)
	_dialog.add_child(EventSheetPopupUI.margined(content))
	EventSheetL10n.apply_to(_dialog)
	_dock.add_child(_dialog)


## Rebuilds the field rows for THIS snippet (a different copy means different references).
func _populate(rows: Array) -> void:
	for stale: Node in _rows_box.get_children():
		_rows_box.remove_child(stale)
		stale.queue_free()
	_object_fields.clear()
	_variable_fields.clear()
	var found: Dictionary = EventSheetPasteSpecial.targets(_snippet)
	var scene_root: Node = EditorInterface.get_edited_scene_root() if Engine.is_editor_hint() else null
	var suggestions: PackedStringArray = PackedStringArray(EventSheetRefactor.reference_suggestions(
		_dock._current_sheet.events if _dock != null and _dock._current_sheet != null else [], scene_root))
	for reference: String in (found.get("objects", []) as Array):
		var edit: LineEdit = LineEdit.new()
		edit.text = reference
		edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var object_note: Label = EventSheetPopupUI.hint_label("", 200.0)
		var field_row: HBoxContainer = HBoxContainer.new()
		field_row.add_theme_constant_override("separation", 4)
		field_row.add_child(edit)
		field_row.add_child(EventSheetPopupUI.autocomplete_combo(edit, func() -> PackedStringArray: return suggestions))
		field_row.add_child(object_note)
		edit.text_changed.connect(func(_text: String) -> void: refresh_notes())
		_rows_box.add_child(EventSheetPopupUI.form_row(reference, field_row))
		_object_fields.append({"from": reference, "edit": edit, "note": object_note})
	for variable_name: String in (found.get("variables", []) as Array):
		var edit: LineEdit = LineEdit.new()
		edit.text = variable_name
		edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var note: Label = EventSheetPopupUI.hint_label("", 200.0)
		var field_row: HBoxContainer = HBoxContainer.new()
		field_row.add_theme_constant_override("separation", 6)
		field_row.add_child(edit)
		field_row.add_child(note)
		edit.text_changed.connect(func(_text: String) -> void: refresh_notes())
		_rows_box.add_child(EventSheetPopupUI.form_row(variable_name, field_row))
		_variable_fields.append({"from": variable_name, "edit": edit, "note": note})
	refresh_notes()
	if _object_fields.is_empty() and _variable_fields.is_empty():
		_rows_box.add_child(EventSheetPopupUI.hint_label("These rows name no objects and no variables, so a plain Paste already does the job."))
	_summary_label.text = "%d row(s) on the clipboard." % rows.size()


## Re-reads every field and says, beside it, exactly what will happen to it - which of create versus
## reuse for a variable, and whether an object target is even something a row can point at. Called on
## every keystroke AND from mapping(), so a field filled in any other way still reads true. These are
## the same rules remap applies, so a refusal is read here rather than discovered in the pasted rows.
func refresh_notes() -> void:
	for object_field: Dictionary in _object_fields:
		var object_note: Label = object_field.get("note", null)
		if object_note != null:
			object_note.text = EventSheetPasteSpecial.describe_object_target((object_field.get("edit") as LineEdit).text.strip_edges())
	for field: Dictionary in _variable_fields:
		var note: Label = field.get("note", null)
		if note != null:
			note.text = EventSheetPasteSpecial.describe_variable_target(
				_dock._current_sheet if _dock != null else null,
				(field.get("edit") as LineEdit).text.strip_edges(), _snippet, str(field.get("from", "")))


## The retarget the fields currently describe: {"objects": {from: to}, "variables": {from: to}}.
func mapping() -> Dictionary:
	refresh_notes()
	var objects: Dictionary = {}
	for field: Dictionary in _object_fields:
		objects[str(field.get("from", ""))] = (field.get("edit") as LineEdit).text.strip_edges()
	var variables: Dictionary = {}
	for field: Dictionary in _variable_fields:
		variables[str(field.get("from", ""))] = (field.get("edit") as LineEdit).text.strip_edges()
	return {"objects": objects, "variables": variables}


## Remaps and pastes. Returns true when rows landed in the sheet.
func confirm() -> bool:
	if _dock == null or not _dock._ensure_sheet_for_editing():
		return false
	var remapped: Dictionary = EventSheetPasteSpecial.remap(_snippet, mapping())
	var rows: Array = remapped.get("rows", [])
	if rows.is_empty():
		_dock._set_status("That snippet has no rows to paste.", true)
		return false
	var pasted: bool = _dock._clipboard_glue.paste_snippet(remapped, "Paste Special",
		EventSheetPasteSpecial.summary(rows.size(), remapped.get("remapped", {})))
	if pasted and _dialog != null:
		_dialog.hide()
	return pasted
