@tool
extends RefCounted
class_name EventSheetCustomBlockDialog

# The Custom Block API's generic editor: ONE dialog auto-built from the kind's fields() schema
# (a LineEdit per String field, a CheckBox per bool, a SpinBox per int/float), so a registered
# kind gets add + edit UX with zero UI code. Opens in two modes: add (builds a CustomBlockRow
# from the schema defaults and inserts it below the selection) and edit (rewrites the block's
# fields). Both apply through the dock's undoable-edit funnel. Extracted-component pattern:
# reaches back through _dock for the sheet, insertion, and dirty/status feedback.

var _dock: Control = null

func init(dock: Control) -> void:
	_dock = dock

var _dialog: ConfirmationDialog = null
var _fields_box: VBoxContainer = null
var _field_controls: Dictionary = {}   # field id -> Control (rebuilt per open; kinds differ)
var _target_block: CustomBlockRow = null   # non-null = edit mode
var _target_kind: EventSheetBlockKind = null

## Add mode: prompt for a new block of this kind, inserted below the selection on OK.
func open_add(kind_id: String) -> void:
	var kind: EventSheetBlockKind = EventSheetBlockRegistry.get_kind(kind_id)
	if kind == null:
		_dock._set_status("Unknown block kind: %s" % kind_id, true)
		return
	if not _dock._ensure_sheet_for_editing():
		return
	_open(kind, null)

## Edit mode: rewrite an existing block's fields (double-click on the row).
func open_edit(block_resource: Resource) -> void:
	var block: CustomBlockRow = block_resource as CustomBlockRow
	if block == null:
		return
	var kind: EventSheetBlockKind = EventSheetBlockRegistry.get_kind(block.kind_id)
	if kind == null:
		_dock._set_status("This block's kind ('%s') is not registered - its code still compiles, but it needs its pack installed to edit as a form." % block.kind_id, true)
		return
	_open(kind, block)

func _open(kind: EventSheetBlockKind, block: CustomBlockRow) -> void:
	_target_kind = kind
	_target_block = block
	if _dialog == null:
		_dialog = ConfirmationDialog.new()
		_dialog.min_size = Vector2i(420, 0)
		_fields_box = EventSheetPopupUI.form_box()
		_dialog.add_child(EventSheetPopupUI.margined(_fields_box))
		_dialog.confirmed.connect(_apply)
		_dock.add_child(_dialog)
	_dialog.title = ("Edit %s" if block != null else "Add %s") % kind.title
	_dialog.ok_button_text = "Apply" if block != null else "Add"
	# Rebuild the form for THIS kind's schema (the dialog is shared across kinds).
	for stale: Node in _fields_box.get_children():
		stale.queue_free()
	_field_controls.clear()
	for field: Dictionary in kind.fields():
		var field_id: String = str(field.get("id", ""))
		var current: Variant = block.fields.get(field_id, field.get("default")) if block != null else field.get("default")
		var control: Control = _make_field_control(int(field.get("type", TYPE_STRING)), current)
		_field_controls[field_id] = control
		_fields_box.add_child(EventSheetPopupUI.form_row(str(field.get("label", field_id)), control))
	_dialog.popup_centered()
	# Focus the first field so add flows are type-and-Enter.
	if not kind.fields().is_empty():
		var first: Control = _field_controls.get(str(kind.fields()[0].get("id", "")), null)
		if first != null:
			first.grab_focus()

func _make_field_control(field_type: int, current: Variant) -> Control:
	match field_type:
		TYPE_BOOL:
			var check: CheckBox = CheckBox.new()
			check.button_pressed = bool(current)
			return check
		TYPE_INT, TYPE_FLOAT:
			var spin: SpinBox = SpinBox.new()
			spin.step = 1.0 if field_type == TYPE_INT else 0.01
			spin.allow_greater = true
			spin.allow_lesser = true
			spin.value = float(current) if current != null else 0.0
			return spin
		_:
			var edit: LineEdit = LineEdit.new()
			edit.text = str(current) if current != null else ""
			edit.text_submitted.connect(func(_t: String) -> void:
				_apply()
				_dialog.hide()
			)
			return edit

## Reads the form back into a fields Dictionary per the kind's schema.
func _collect_fields(kind: EventSheetBlockKind) -> Dictionary:
	var collected: Dictionary = {}
	for field: Dictionary in kind.fields():
		var field_id: String = str(field.get("id", ""))
		var control: Control = _field_controls.get(field_id, null)
		if control is CheckBox:
			collected[field_id] = (control as CheckBox).button_pressed
		elif control is SpinBox:
			var numeric: float = (control as SpinBox).value
			collected[field_id] = int(numeric) if int(field.get("type", TYPE_STRING)) == TYPE_INT else numeric
		elif control is LineEdit:
			collected[field_id] = (control as LineEdit).text
	return collected

## One-shot apply (guarded on the kind so confirmed + text_submitted can't double-fire).
func _apply() -> void:
	if _target_kind == null:
		return
	var kind: EventSheetBlockKind = _target_kind
	var block: CustomBlockRow = _target_block
	_target_kind = null
	_target_block = null
	var new_fields: Dictionary = _collect_fields(kind)
	if block != null:
		var edited: bool = _dock._perform_undoable_sheet_edit("Edit %s" % kind.title, func() -> bool:
			block.fields = new_fields
			return true
		)
		if edited:
			_dock._mark_dirty("Updated %s." % kind.title)
		return
	var added_block: CustomBlockRow = CustomBlockRow.new()
	added_block.kind_id = kind.kind_id
	added_block.fields = new_fields
	var added: bool = _dock._perform_undoable_sheet_edit("Add %s" % kind.title, func() -> bool:
		_dock._insert_row_below_selection(added_block)
		return true
	)
	if added:
		_dock._mark_dirty("Added %s." % kind.title)
