@tool
class_name EventSheetPasteSpecialDialog
extends RefCounted
# "Paste Special..." - paste copied rows retargeted, in one gesture.
#
# Copy already puts a portable snippet on the system clipboard and Paste already creates the sheet
# variables it needs. What was missing is choosing what the pasted rows point AT: this window lists
# every object reference (one card) and every variable name (another) the snippet carries, each with
# a target field, and pastes the remapped rows in ONE step - reusing a Player-wired pattern for an
# Enemy, fanning one door pattern over eight doors, or pasting a teammate's snippet whose names
# collide.
#
# Each field says, under it, what will happen to it as you type: an object target "points at" what
# it names, and a variable name this sheet already has is REUSED (paste never overwrites one) while
# one it lacks is CREATED. No radio button to misread.
#
# The remap itself is EventSheetPasteSpecial (deep-copied rows) and the insertion is the clipboard
# helper's own paste path, so pasted events still get fresh uids and missing variables are still
# declared. `confirm()` is the tested surface; `open()` accepts a snippet directly so the suite
# never has to touch the OS clipboard.

var _dock: Control = null
var _dialog: ConfirmationDialog = null
var _objects_box: VBoxContainer = null
var _objects_card: Control = null
var _variables_box: VBoxContainer = null
var _variables_card: Control = null
var _summary_label: Label = null
var _strip: EventSheetPopupUI.HelpStrip = null
var _snippet: Dictionary = {}
var _object_fields: Array[Dictionary] = []
var _variable_fields: Array[Dictionary] = []


func init(dock: Control) -> void:
	_dock = dock


## Opens the window for the clipboard's snippet (or `snippet_override`, which is how the suite
## drives it). Says so plainly when there is nothing to paste specially.
func open(snippet_override: Dictionary = {}) -> void:
	_snippet = snippet_override if not snippet_override.is_empty() else EventSheetSnippet.deserialize(EventSheetSnippet.clipboard_text())
	var rows: Array = _snippet.get("rows", []) if _snippet.get("rows") is Array else []
	if rows.is_empty():
		_dock._set_status("Copy some rows first - Paste Special retargets a copied snippet.", true)
		return
	_build_dialog()
	_populate(rows)
	_dialog.title = EventSheetL10n.translate("Paste {n} row(s) retargeted").replace("{n}", str(rows.size()))
	if _dock.is_inside_tree():
		_dialog.popup_centered(Vector2i(int(EventSheetPalette.scaled_f(560.0)), 0))


func _build_dialog() -> void:
	if _dialog != null:
		return
	_dialog = ConfirmationDialog.new()
	_dialog.ok_button_text = EventSheetL10n.translate("Paste Retargeted")
	# confirm() closes the window once the rows have landed; a refused paste keeps the form and every
	# retarget typed into it, instead of closing on them.
	_dialog.dialog_hide_on_ok = false
	_dialog.confirmed.connect(func() -> void: confirm())
	var content: VBoxContainer = EventSheetPopupUI.form_box()
	_objects_box = EventSheetPopupUI.form_box()
	_objects_card = EventSheetPopupUI.titled_card(EventSheetL10n.translate("Objects"), _objects_box)
	content.add_child(_objects_card)
	_variables_box = EventSheetPopupUI.form_box()
	_variables_card = EventSheetPopupUI.titled_card(EventSheetL10n.translate("Variables"), _variables_box)
	content.add_child(_variables_card)
	_summary_label = EventSheetPopupUI.hint_label("")
	content.add_child(_summary_label)
	_strip = EventSheetPopupUI.help_strip(EventSheetL10n.translate("On the way in"),
		EventSheetL10n.translate("Object references are rewritten token-safely ($Enemy never touches $EnemySpawner); a variable this sheet has is reused, one it lacks is created."))
	content.add_child(_strip)
	_dialog.add_child(EventSheetPopupUI.margined(content))
	EventSheetL10n.apply_to(_dialog)
	_dock.add_child(_dialog)


## One retarget row: the name the snippet carries on the left, its target field (with the
## suggestions for an object) and the live note under it.
func _field_row(box: VBoxContainer, from: String, suggestions: PackedStringArray, heading: String, help: String) -> Dictionary:
	var edit: LineEdit = LineEdit.new()
	edit.text = from
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var field: HBoxContainer = HBoxContainer.new()
	field.add_child(edit)
	if not suggestions.is_empty():
		field.add_child(EventSheetPopupUI.autocomplete_combo(edit, func() -> PackedStringArray: return suggestions))
	var column: VBoxContainer = VBoxContainer.new()
	column.add_child(field)
	var note: Label = EventSheetPopupUI.hint_label("", EventSheetPalette.scaled_f(300.0))
	note.add_theme_color_override("font_color", EventSheetPopupUI.muted_text_color())
	column.add_child(note)
	edit.text_changed.connect(func(_text: String) -> void: refresh_notes())
	box.add_child(EventSheetPopupUI.form_row(from, column))
	_strip.follow(edit, heading, help)
	return {"from": from, "edit": edit, "note": note}


## Rebuilds the field rows for THIS snippet (a different copy means different references).
func _populate(rows: Array) -> void:
	for box: VBoxContainer in [_objects_box, _variables_box]:
		for stale: Node in box.get_children():
			box.remove_child(stale)
			stale.queue_free()
	_strip.followed.clear()
	_object_fields.clear()
	_variable_fields.clear()
	var found: Dictionary = EventSheetPasteSpecial.targets(_snippet)
	var scene_root: Node = EditorInterface.get_edited_scene_root() if Engine.is_editor_hint() else null
	var suggestions: PackedStringArray = PackedStringArray(EventSheetRefactor.reference_suggestions(
		_dock._current_sheet.events if _dock != null and _dock._current_sheet != null else [], scene_root))
	for reference: String in (found.get("objects", []) as Array):
		_object_fields.append(_field_row(_objects_box, reference, suggestions, EventSheetL10n.translate("Objects"),
			EventSheetL10n.translate("The object these rows point at once pasted. Pick one from the scene or type a node path.")))
	for variable_name: String in (found.get("variables", []) as Array):
		_variable_fields.append(_field_row(_variables_box, variable_name, PackedStringArray(), EventSheetL10n.translate("Variables"),
			EventSheetL10n.translate("The variable these rows use once pasted: one this sheet has is reused, one it lacks is created.")))
	_objects_card.visible = not _object_fields.is_empty()
	_variables_card.visible = not _variable_fields.is_empty()
	refresh_notes()
	_summary_label.text = EventSheetL10n.translate("{n} row(s) on the clipboard.").replace("{n}", str(rows.size())) \
		if not (_object_fields.is_empty() and _variable_fields.is_empty()) \
		else EventSheetL10n.translate("These rows name no objects and no variables, so a plain Paste already does the job.")


## Re-reads every field and says, under it, exactly what will happen to it - create versus reuse for
## a variable, and whether an object target is something a row can point at. Called on every
## keystroke AND from mapping(), so a field filled in any other way still reads true. These are the
## rules remap applies, so a refusal is read here rather than discovered in the pasted rows.
func refresh_notes() -> void:
	for object_field: Dictionary in _object_fields:
		(object_field["note"] as Label).text = EventSheetPasteSpecial.describe_object_target(
			(object_field.get("edit") as LineEdit).text.strip_edges())
	for field: Dictionary in _variable_fields:
		(field["note"] as Label).text = EventSheetPasteSpecial.describe_variable_target(
			_dock._current_sheet if _dock != null else null,
			(field.get("edit") as LineEdit).text.strip_edges(), _snippet, str(field.get("from", "")))
	# What the paste will change, said in one line: every name that points somewhere else.
	var changes: PackedStringArray = PackedStringArray()
	for field: Dictionary in _object_fields + _variable_fields:
		var target: String = (field.get("edit") as LineEdit).text.strip_edges()
		if not target.is_empty() and target != str(field.get("from", "")):
			changes.append("%s → %s" % [str(field.get("from", "")), target])
	_strip.set_reading(", ".join(changes) if not changes.is_empty() else EventSheetL10n.translate("pasted as copied"))


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
