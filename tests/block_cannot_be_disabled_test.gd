# Godot EventSheets - a block row cannot be switched off.
#
# A block writes its line into the file whether or not a flag says otherwise: the compiler never
# looked at that flag for blocks. So the keys that toggle a row (Ctrl+/ and the row's own menu) refuse
# a block, leave it and the sheet's undo history alone, and say why in one plain line. A sheet that
# already holds a block marked off keeps compiling to the same bytes, and the row says in the quiet
# amber note that it still runs.
@tool
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")
const P := "block_cannot_be_disabled_test"


class NoopUndoManager:
	extends RefCounted
	func create_action(_a = null) -> void: pass
	func add_do_method(_a = null, _b = null, _c = null, _d = null, _e = null) -> void: pass
	func add_undo_method(_a = null, _b = null, _c = null, _d = null, _e = null) -> void: pass
	func commit_action() -> void: pass
	func has_undo() -> bool: return false
	func has_redo() -> bool: return false
	func undo() -> void: pass
	func redo() -> void: pass
	func clear_history() -> void: pass


static func run() -> bool:
	var ok: bool = true
	var note: CustomBlockRow = CustomBlockRow.new()
	note.kind_id = "demo.note"
	note.fields = {"text": "tune this after the jam"}
	var comment: CommentRow = CommentRow.new()
	comment.text = "after the block"
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	sheet.events.append(note)
	sheet.events.append(comment)
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(sheet)
	editor.set_undo_redo_manager(NoopUndoManager.new())
	var viewport: EventSheetViewport = editor._viewport
	var block_index: int = _index_of(viewport, "demo.note")
	ok = SUPPORT.check(P, "the block row is on the canvas", block_index >= 0, true) and ok
	if block_index < 0:
		editor.free()
		return false

	# Ctrl+/ on the block: nothing changes, nothing is dirty, and the status line says why.
	var dirty_before: bool = editor._dirty
	viewport._select_row(block_index, -1)
	editor._toggle_selected_rows_enabled()
	ok = SUPPORT.check(P, "Ctrl+/ leaves the block switched on", note.enabled, true) and ok
	ok = SUPPORT.check(P, "and makes no edit", editor._dirty, dirty_before) and ok
	ok = SUPPORT.check(P, "and says in one plain line why",
		editor._status_label.text.contains("A block cannot be disabled"), true) and ok

	# The row's own menu: the same refusal instead of silence.
	editor._set_status("")
	editor._context_row = viewport.get_flat_rows()[block_index].get("row")
	editor._row_edit_ops._toggle_context_row_enabled()
	ok = SUPPORT.check(P, "the row menu leaves it switched on too", note.enabled, true) and ok
	ok = SUPPORT.check(P, "and says the same line",
		editor._status_label.text.contains("A block cannot be disabled"), true) and ok

	# The refusal is reachable: a right-click on a block row opens the row's own menu (the same one every
	# plain row of the sheet gets), and its Disable Row item is the door that ends in that line.
	editor._context_menus._build_row_context_menu(editor._context_row)
	var menu: PopupMenu = editor._row_context_menu
	var items: PackedStringArray = PackedStringArray()
	for item_index: int in menu.item_count:
		items.append(menu.get_item_text(item_index))
	ok = SUPPORT.check(P, "a block row's menu offers Disable Row", items.has("Disable Row"), true) and ok
	ok = SUPPORT.check(P, "and the clipboard items beside it", [items.has("Cut"), items.has("Copy"), items.has("Delete")], [true, true, true]) and ok

	# A row that can be switched off still can.
	var comment_index: int = _index_of_source(viewport, comment)
	viewport._select_row(comment_index, -1)
	editor._toggle_selected_rows_enabled()
	ok = SUPPORT.check(P, "a comment still toggles", comment.enabled, false) and ok
	editor.free()

	# A sheet that already holds a block marked off keeps compiling the same bytes, and the row says so.
	var enabled_text: String = SUPPORT.compile_output(_sheet_with_block(true))
	var disabled_text: String = SUPPORT.compile_output(_sheet_with_block(false))
	ok = SUPPORT.check(P, "a block already marked off writes the same bytes", disabled_text, enabled_text) and ok
	ok = SUPPORT.check(P, "and still writes its line", disabled_text.contains("NOTE: tune this after the jam"), true) and ok
	var old_sheet: EventSheetResource = _sheet_with_block(false)
	var viewer: EventSheetEditor = EventSheetEditor.new()
	viewer.setup(old_sheet)
	var old_row: EventRowData = _row_of(viewer._viewport, "demo.note")
	ok = SUPPORT.check(P, "its row wears the quiet amber note", old_row != null and not old_row.attention_note.is_empty(), true) and ok
	ok = SUPPORT.check(P, "that is not the red state", old_row != null and old_row.attention_severe, false) and ok
	ok = SUPPORT.check(P, "that says it still runs",
		old_row != null and old_row.attention_note.contains("still runs"), true) and ok
	var live_row: EventRowData = _row_of(_viewer_for(_sheet_with_block(true)), "demo.note")
	ok = SUPPORT.check(P, "a block that is on wears no note", live_row != null and live_row.attention_note.is_empty(), true) and ok
	viewer.free()
	return ok


static func _sheet_with_block(enabled: bool) -> EventSheetResource:
	var block: CustomBlockRow = CustomBlockRow.new()
	block.kind_id = "demo.note"
	block.fields = {"text": "tune this after the jam"}
	block.enabled = enabled
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	sheet.events.append(block)
	return sheet


static func _viewer_for(sheet: EventSheetResource) -> EventSheetViewport:
	var viewer: EventSheetEditor = EventSheetEditor.new()
	viewer.setup(sheet)
	return viewer._viewport


static func _index_of(viewport: EventSheetViewport, kind_id: String) -> int:
	var rows: Array = viewport.get_flat_rows()
	for index: int in range(rows.size()):
		var row: EventRowData = rows[index].get("row")
		if row != null and row.source_resource is CustomBlockRow and (row.source_resource as CustomBlockRow).kind_id == kind_id:
			return index
	return -1


static func _index_of_source(viewport: EventSheetViewport, source: Resource) -> int:
	var rows: Array = viewport.get_flat_rows()
	for index: int in range(rows.size()):
		var row: EventRowData = rows[index].get("row")
		if row != null and row.source_resource == source:
			return index
	return -1


static func _row_of(viewport: EventSheetViewport, kind_id: String) -> EventRowData:
	var index: int = _index_of(viewport, kind_id)
	if index < 0:
		return null
	return viewport.get_flat_rows()[index].get("row")
