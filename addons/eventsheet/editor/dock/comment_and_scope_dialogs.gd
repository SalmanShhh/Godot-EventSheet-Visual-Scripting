@tool
class_name EventSheetCommentAndScopeDialogs
extends RefCounted

# Comment editing, "With node X:" action scoping, and comment <-> action-cell conversion.
#
# Two small ConfirmationDialogs (Edit Comment: multiline text + per-comment background colour;
# Scope Actions To Node: a node-expression field) plus the logic that moves a standalone comment
# row into the action cells of the event above it, and back out again. Extracted from
# event_sheet_dock.gd so the dock stays focused; the dock keeps thin delegates (_open_comment_dialog
# / _open_with_node_dialog / _attach_comment_to_event_above / _detach_comment_to_row) so the viewport
# signal connections and the row/action context menus keep calling the dock unchanged. This class
# reaches back through the dock reference for the active sheet, the undoable-edit wrapper, and the
# refresh / dirty / status feedback.

var _dock: Control = null


func init(dock: Control) -> void:
	_dock = dock

var _comment_dialog: ConfirmationDialog = null
var _comment_text_edit: TextEdit = null
var _comment_color_button: ColorPickerButton = null
var _comment_manual_check: CheckBox = null
var _comment_dialog_target: CommentRow = null
var _comment_band: EventSheetPopupUI.RowBand = null
var _comment_color_label: Label = null
var _comment_strip: EventSheetPopupUI.HelpStrip = null


## Dialog editor for comments: multiline comment rows, action-cell comments, and the row
## context menu's "Edit Comment…". Single-line comment rows keep inline editing.
func open_comment_dialog(comment_resource: Resource) -> void:
	var comment_row: CommentRow = comment_resource as CommentRow
	if comment_row == null:
		return
	_ensure_comment_dialog()
	_comment_dialog_target = comment_row
	_comment_text_edit.text = comment_row.text
	_comment_color_button.color = comment_row.custom_color
	_comment_manual_check.button_pressed = comment_row.is_documentation()
	_refresh_comment()
	if _dock.is_inside_tree():
		EventSheetPopupUI.popup_fitted(_comment_dialog, Vector2i(int(EventSheetPalette.scaled_f(560.0)), 0))
		_comment_text_edit.grab_focus()


func _ensure_comment_dialog() -> void:
	if _comment_dialog != null:
		return
	var parts: Dictionary = EventSheetPopupUI.panel_window(EventSheetL10n.translate("Edit comment"), Vector2i.ZERO,
		_dock, EventSheetL10n.translate("Save"), _on_comment_dialog_confirmed, true)
	_comment_dialog = parts["window"]
	var form: VBoxContainer = parts["box"]
	_comment_band = EventSheetPopupUI.RowBand.new()
	form.add_child(_comment_band)
	var card: VBoxContainer = EventSheetPopupUI.form_box()
	_comment_text_edit = TextEdit.new()
	_comment_text_edit.custom_minimum_size = Vector2(EventSheetPalette.scaled_f(500.0), EventSheetPalette.scaled_f(150.0))
	_comment_text_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_comment_text_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Wrap long lines to the box width so the whole comment is readable without a horizontal scroll
	# (event-sheet style); Enter still inserts a newline.
	_comment_text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_comment_text_edit.placeholder_text = EventSheetL10n.translate("Comment text (multiline supported; highlight text to format it)")
	_comment_text_edit.text_changed.connect(_refresh_comment)
	card.add_child(_comment_text_edit)
	# Discord-style formatting: highlight text and a small unfocused bar floats above the
	# selection to wrap it in BBCode (comments render BBCode in the sheet).
	EventSheetBBCodeSelectionBar.attach(_comment_text_edit)
	# The swatch says what it is set to beside it: "theme default" while its alpha is 0, which is
	# what a cleared background means.
	_comment_color_button = ColorPickerButton.new()
	_comment_color_button.custom_minimum_size = Vector2(EventSheetPalette.scaled_f(64.0), 0.0)
	_comment_color_button.color = Color(0, 0, 0, 0)
	_comment_color_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_comment_color_button.color_changed.connect(func(_color: Color) -> void: _refresh_comment())
	_comment_color_label = Label.new()
	_comment_color_label.add_theme_color_override("font_color", EventSheetPopupUI.muted_text_color())
	var swatch_row: HBoxContainer = HBoxContainer.new()
	swatch_row.add_child(_comment_color_button)
	swatch_row.add_child(_comment_color_label)
	card.add_child(EventSheetPopupUI.form_row(EventSheetL10n.translate("Background"), swatch_row))
	# The ONE control that decides which of GDScript's two comment spellings this row writes.
	# Ticked, the row writes `##` - the documentation form the engine renders and the project manual
	# sets as prose. Unticked, it writes `#` and never leaves this sheet. The marker in the file IS
	# the setting, so the row and the line always agree.
	_comment_manual_check = CheckBox.new()
	_comment_manual_check.text = EventSheetL10n.translate("Shows in the manual")
	_comment_manual_check.toggled.connect(func(_on: bool) -> void: _refresh_comment())
	card.add_child(_comment_manual_check)
	form.add_child(EventSheetPopupUI.titled_card(EventSheetL10n.translate("Comment"), card))
	_comment_strip = EventSheetPopupUI.help_strip(EventSheetL10n.translate("Comment"),
		EventSheetL10n.translate("Highlight text to format it; comments render BBCode in the sheet."),
		"", "", EventSheetPalette.scaled_f(480.0))
	form.add_child(_comment_strip)
	_comment_strip.follow(_comment_text_edit, EventSheetL10n.translate("Comment"),
		EventSheetL10n.translate("Highlight text to format it; comments render BBCode in the sheet."))
	_comment_strip.follow(_comment_color_button, EventSheetL10n.translate("Background"),
		EventSheetL10n.translate("A colour behind this comment on the sheet. Clear its alpha to 0 to go back to the theme default."))
	_comment_strip.follow(_comment_manual_check, EventSheetL10n.translate("Shows in the manual"),
		EventSheetL10n.translate("Writes ## instead of #. Notes left as # stay in this sheet - they are not documentation and nothing counts them as missing."))


## The comment's first line as the file will hold it - `#` or `##` before it - for the band and the
## strip, and the swatch's own label.
func _refresh_comment() -> void:
	var marker: String = "##" if _comment_manual_check.button_pressed else "#"
	var first_line: String = _comment_text_edit.text.get_slice("\n", 0)
	var line: String = "%s %s" % [marker, first_line]
	if _comment_text_edit.text.contains("\n"):
		line += " …"
	_comment_band.show_row("", line)
	_comment_strip.set_reading("", line)
	_comment_color_label.text = EventSheetL10n.translate("theme default") if _comment_color_button.color.a <= 0.0 else ""


func _on_comment_dialog_confirmed() -> void:
	if _comment_dialog_target == null:
		return
	var target: CommentRow = _comment_dialog_target
	var new_text: String = _comment_text_edit.text
	var new_color: Color = _comment_color_button.color
	var documentation: bool = _comment_manual_check.button_pressed
	var changed: bool = _dock._perform_undoable_sheet_edit("Edit Comment", func() -> bool:
		# An OK that changed nothing is not an edit: no undo step, and the sheet stays clean (for an
		# opened .gd that means no rewrite at all).
		if target.text == new_text and target.custom_color == new_color \
				and target.is_documentation() == documentation:
			return false
		target.text = new_text
		target.custom_color = new_color
		# Leaves the marker completely alone when the side has not changed, so a comment lifted as
		# `##` (no trailing space) is not silently respelled and re-emits byte for byte.
		target.set_documentation(documentation)
		return true
	)
	if changed:
		_dock._refresh_after_edit()
		_dock._mark_dirty("Comment updated.")

# ── With-node scope dialog ("With node X:" - scope a row's actions to another node) ──
var _with_node_dialog: ConfirmationDialog = null
var _with_node_target_edit: LineEdit = null
var _with_node_dialog_target: EventRow = null


## Opens the editor for a row's "With node X:" scope. The target is a node expression ($Enemy,
## get_node("…"), a variable); blank removes the scope so the row's actions act on the host again.
func open_with_node_dialog(event_resource: Resource) -> void:
	var event_row: EventRow = event_resource as EventRow
	if event_row == null:
		return
	_ensure_with_node_dialog()
	_with_node_dialog_target = event_row
	_with_node_target_edit.text = event_row.with_node_target
	_with_node_dialog.popup_centered(Vector2i(460, 160))
	_with_node_target_edit.grab_focus()
	_with_node_target_edit.select_all()


func _ensure_with_node_dialog() -> void:
	if _with_node_dialog != null:
		return
	var parts: Dictionary = EventSheetPopupUI.panel_window("Scope Actions To Node", Vector2i.ZERO, _dock, "OK",
		_on_with_node_dialog_confirmed, true)
	_with_node_dialog = parts["window"]
	var form: VBoxContainer = parts["box"]
	# Width-bound hint (helper handles autowrap + width clamp) so the label can't balloon the dialog.
	var hint: Label = EventSheetPopupUI.hint_label("Actions in this event act on this node instead of the host.\nUse $Enemy, get_node(\"UI/Score\"), or a variable. Leave blank to act on this node.", 420.0)
	form.add_child(hint)
	_with_node_target_edit = LineEdit.new()
	_with_node_target_edit.placeholder_text = "$Enemy"
	_with_node_target_edit.custom_minimum_size = Vector2(420.0, 0.0)
	_with_node_target_edit.text_submitted.connect(func(_submitted: String) -> void:
		_with_node_dialog.hide()
		_on_with_node_dialog_confirmed()
	)
	form.add_child(_with_node_target_edit)


func _on_with_node_dialog_confirmed() -> void:
	if _with_node_dialog_target == null:
		return
	var target: EventRow = _with_node_dialog_target
	var new_target: String = _with_node_target_edit.text.strip_edges()
	var changed: bool = _dock._perform_undoable_sheet_edit("Scope To Node", func() -> bool:
		target.with_node_target = new_target
		return true
	)
	if changed:
		_dock._refresh_after_edit()
		_dock._mark_dirty("Scoped actions to %s." % (new_target if not new_target.is_empty() else "this node (host)"))

# ── Comment ↔ action-cell conversion ─────────────────────────────────────────


## Finds the array + index holding `target` among sheet rows (recursing into groups and
## sub-events). Returns {} when not found.
func _locate_row_container(rows: Array, target: Resource) -> Dictionary:
	for index in range(rows.size()):
		var row: Variant = rows[index]
		if row == target:
			return {"container": rows, "index": index}
		if row is EventRow:
			var found: Dictionary = _locate_row_container((row as EventRow).sub_events, target)
			if not found.is_empty():
				return found
		elif row is EventGroup:
			var group_children: Array = _dock._ace_apply._group_children_array(row as EventGroup)
			var found_in_group: Dictionary = _locate_row_container(group_children, target)
			if not found_in_group.is_empty():
				return found_in_group
	return {}


## Finds the EventRow whose actions contain `target` (action-cell comments/blocks).
func _locate_owning_event(rows: Array, target: Resource) -> EventRow:
	for row: Variant in rows:
		if row is EventRow:
			if (row as EventRow).actions.has(target):
				return row as EventRow
			var nested: EventRow = _locate_owning_event((row as EventRow).sub_events, target)
			if nested != null:
				return nested
		elif row is EventGroup:
			var found: EventRow = _locate_owning_event(_dock._ace_apply._group_children_array(row as EventGroup), target)
			if found != null:
				return found
	return null


## Comment row → action-cell comment of the nearest EventRow ABOVE it (the "comment in
## the actions"). The reverse of detach_comment_to_row.
func attach_comment_to_event_above(comment_row: CommentRow) -> void:
	if _dock._current_sheet == null or comment_row == null:
		return
	var location: Dictionary = _locate_row_container(_dock._current_sheet.events, comment_row)
	if location.is_empty():
		_dock._set_status("Comment not found in the sheet.", true)
		return
	var container: Array = location.get("container")
	var target_event: EventRow = null
	for index in range(int(location.get("index")) - 1, -1, -1):
		if container[index] is EventRow:
			target_event = container[index] as EventRow
			break
	if target_event == null:
		_dock._set_status("No event above this comment to attach to.", true)
		return
	var changed: bool = _dock._perform_undoable_sheet_edit("Attach Comment To Event", func() -> bool:
		container.erase(comment_row)
		target_event.actions.append(comment_row)
		return true
	)
	if changed:
		_dock._refresh_after_edit()
		_dock._mark_dirty("Comment attached to the event above (action note).")


## Action-cell comment → standalone comment row directly below its event.
func detach_comment_to_row(comment_row: CommentRow) -> void:
	if _dock._current_sheet == null or comment_row == null:
		return
	var owner_event: EventRow = _locate_owning_event(_dock._current_sheet.events, comment_row)
	if owner_event == null:
		_dock._set_status("This comment is not inside an event.", true)
		return
	var owner_location: Dictionary = _locate_row_container(_dock._current_sheet.events, owner_event)
	if owner_location.is_empty():
		_dock._set_status("Owning event not found in the sheet.", true)
		return
	var changed: bool = _dock._perform_undoable_sheet_edit("Detach Comment", func() -> bool:
		owner_event.actions.erase(comment_row)
		var container: Array = owner_location.get("container")
		container.insert(int(owner_location.get("index")) + 1, comment_row)
		return true
	)
	if changed:
		_dock._refresh_after_edit()
		_dock._mark_dirty("Comment detached to its own row.")
