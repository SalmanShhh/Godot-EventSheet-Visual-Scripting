@tool
class_name EventSheetDuplicateVariantDialog
extends AcceptDialog
# "Duplicate as Variant…" - the copy and the remap in one dialog and one undo step.
#
# Building the second of anything is a two-dialog chore today: Duplicate, then hunt down
# Replace Object References… and remap. This is the shipped Paste Special remap form pointed at
# the SELECTION instead of the clipboard, plus a preview of the rows it will produce and an
# "Again with…" button that keeps the form open so the third and fourth variant are one click each.
#
# Everything it does is reachable today as the shipped two-step, and it reuses both halves as they
# are (editor/duplicate_variant.gd): the portable row form, the token-safe remap, and the one paste
# path that assigns fresh event uids and creates missing variables without overwriting any.
#
# `confirm()` is the tested surface - the suite drives it with no window on screen.

const DIALOG_NAME := "EventSheetDuplicateVariantDialog"

var _dock: Control = null
var _rows: Array = []
var _object_fields: Array[Dictionary] = []
var _variable_fields: Array[Dictionary] = []
var _preview: Label = null
var _summary: Label = null
var _made: int = 0


## Opens the dialog for the current selection, replacing any form left from a previous variant
## (a different selection means different fields). Returns the dialog for callers and tests.
static func open_for(dock: Control, rows: Array) -> EventSheetDuplicateVariantDialog:
	if dock == null:
		return null
	var stale: Node = dock.get_node_or_null(DIALOG_NAME)
	if stale != null:
		dock.remove_child(stale)
		stale.queue_free()
	var dialog: EventSheetDuplicateVariantDialog = EventSheetDuplicateVariantDialog.new()
	dialog.name = DIALOG_NAME
	dialog.configure(dock, rows)
	dock.add_child(dialog)
	if dock.is_inside_tree():
		dialog.popup_centered(Vector2i(EventSheetPalette.scaled(620), EventSheetPalette.scaled(520)))
	return dialog


## Builds the remap form for THESE rows: one field per object reference they point at and per
## sheet variable they need, each seeded with its own name so an untouched field is a no-op.
func configure(dock: Control, rows: Array) -> void:
	_dock = dock
	_rows = rows
	_object_fields.clear()
	_variable_fields.clear()
	title = "Duplicate as Variant"
	ok_button_text = "Create Variant"
	# The dialog hides itself, never AcceptDialog: with hide_on_ok on, the form would vanish before
	# confirm() ran, so a refusal ("select the rows first") would also throw away the names typed.
	dialog_hide_on_ok = false
	add_cancel_button("Close")
	confirmed.connect(func() -> void: confirm())
	# "Again with…" commits the variant and keeps the form open, so the next one is one edit away.
	add_button("Again with…", true, "again")
	custom_action.connect(func(action: StringName) -> void:
		if str(action) == "again":
			confirm(true))
	var content: VBoxContainer = EventSheetPopupUI.form_box()
	content.add_child(EventSheetPopupUI.hint_label(
		"Copy these rows with names swapped. Object references are rewritten token-safely ($Player never touches $PlayerSpawner); a variable name this sheet already has is reused, one it lacks is created."))
	var fields_box: VBoxContainer = EventSheetPopupUI.form_box()
	var sheet: EventSheetResource = _dock._current_sheet if _dock != null else null
	var found: Dictionary = EventSheetDuplicateVariant.targets(sheet, rows)
	for reference: String in (found.get("objects", []) as Array):
		var object_edit: LineEdit = LineEdit.new()
		object_edit.text = reference
		object_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var object_note: Label = EventSheetPopupUI.hint_label("", 200.0)
		var object_row: HBoxContainer = HBoxContainer.new()
		object_row.add_theme_constant_override("separation", 6)
		object_row.add_child(object_edit)
		object_row.add_child(object_note)
		object_edit.text_changed.connect(func(_typed: String) -> void: refresh_preview())
		fields_box.add_child(EventSheetPopupUI.form_row(reference, object_row))
		_object_fields.append({"from": reference, "edit": object_edit, "note": object_note})
	for variable_name: String in (found.get("variables", []) as Array):
		var variable_edit: LineEdit = LineEdit.new()
		variable_edit.text = variable_name
		variable_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var variable_note: Label = EventSheetPopupUI.hint_label("", 200.0)
		var variable_row: HBoxContainer = HBoxContainer.new()
		variable_row.add_theme_constant_override("separation", 6)
		variable_row.add_child(variable_edit)
		variable_row.add_child(variable_note)
		variable_edit.text_changed.connect(func(_typed: String) -> void: refresh_preview())
		fields_box.add_child(EventSheetPopupUI.form_row(variable_name, variable_row))
		_variable_fields.append({"from": variable_name, "edit": variable_edit, "note": variable_note})
	if _object_fields.is_empty() and _variable_fields.is_empty():
		fields_box.add_child(EventSheetPopupUI.hint_label("These rows name no objects and no variables, so this is a plain duplicate."))
	content.add_child(EventSheetPopupUI.titled_card("Find and replace", fields_box))
	_preview = EventSheetPopupUI.hint_label("")
	var preview_scroll: ScrollContainer = ScrollContainer.new()
	preview_scroll.custom_minimum_size = Vector2(0.0, EventSheetPalette.scaled(150))
	preview_scroll.add_child(_preview)
	content.add_child(EventSheetPopupUI.titled_card("The rows this will produce", preview_scroll))
	_summary = EventSheetPopupUI.hint_label("")
	content.add_child(_summary)
	add_child(EventSheetPopupUI.margined(content))
	EventSheetL10n.apply_to(self)
	refresh_preview()


## The retarget the fields currently describe: {"objects": {from: to}, "variables": {from: to}}.
func mapping() -> Dictionary:
	var objects: Dictionary = {}
	for field: Dictionary in _object_fields:
		objects[str(field.get("from", ""))] = (field.get("edit") as LineEdit).text.strip_edges()
	var variables: Dictionary = {}
	for field: Dictionary in _variable_fields:
		variables[str(field.get("from", ""))] = (field.get("edit") as LineEdit).text.strip_edges()
	return {"objects": objects, "variables": variables}


## Re-reads every field and rebuilds the preview from the ROWS the remap really produces - not a
## prediction of them - so what the pane shows and what the button lands can never disagree. The
## note beside each field is the shipped Paste Special sentence, for the same reason.
func refresh_preview() -> void:
	for object_field: Dictionary in _object_fields:
		var object_note: Label = object_field.get("note", null)
		if object_note != null:
			object_note.text = EventSheetPasteSpecial.describe_object_target((object_field.get("edit") as LineEdit).text.strip_edges())
	var snapshot: Dictionary = EventSheetDuplicateVariant.snapshot(_dock._current_sheet if _dock != null else null, _rows)
	for variable_field: Dictionary in _variable_fields:
		var variable_note: Label = variable_field.get("note", null)
		if variable_note != null:
			variable_note.text = EventSheetPasteSpecial.describe_variable_target(
				_dock._current_sheet if _dock != null else null,
				(variable_field.get("edit") as LineEdit).text.strip_edges(), snapshot, str(variable_field.get("from", "")))
	if _preview != null:
		_preview.text = "\n".join(preview_lines())


## The preview pane's text, exposed so the suite pins what the author reads before committing.
func preview_lines() -> PackedStringArray:
	return EventSheetDuplicateVariant.preview_lines(
		EventSheetDuplicateVariant.variant(_dock._current_sheet if _dock != null else null, _rows, mapping()))


## Creates the variant: remap + insert, as ONE undo step. `keep_open` is the "Again with…" path -
## the form stays up with the fields as you left them, so the next variant is one edit away.
func confirm(keep_open: bool = false) -> bool:
	if _dock == null or not _dock._ensure_sheet_for_editing():
		return false
	var remapped: Dictionary = EventSheetDuplicateVariant.variant(_dock._current_sheet, _rows, mapping())
	var rows: Array = remapped.get("rows", []) if remapped.get("rows") is Array else []
	if rows.is_empty():
		_dock._set_status("Select the rows to make a variant of first.", true)
		return false
	var created: bool = _dock._clipboard_glue.paste_snippet(remapped, "Duplicate as Variant",
		EventSheetDuplicateVariant.summary(rows.size(), remapped))
	if created:
		# `_rows` now points at the pre-commit resources (the funnel replaces them with snapshot
		# duplicates), which is exactly what "Again with…" wants: the next variant is made from the
		# SOURCE rows as they were, not from the variant just inserted.
		_made += 1
		if _summary != null:
			_summary.text = "%d variant(s) made from this selection." % _made
		if not keep_open:
			hide()
	return created
