# EventForge - a script opened as a sheet (read-only, before its first edit) reads its rows where the
# file writes them. No bar gathers the functions nobody published, the blank lines between two
# blocks cost one block gap rather than a tall empty row per line, an export group draws as the strip
# an edited sheet draws, and a `##` line the lift kept on its own above an exported member sits in
# that member's strip instead of ending it. Every reading leaves the file byte for byte.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "preview_rows_in_file_order_test"

const SOURCE := "@tool\nextends TileMapLayer\n\n@export_group(\"Brush\")\n## Cells painted per click\n@export_range(1, 8) var brush_size: int = 3:\n\tset(value):\n\t\tbrush_size = value\n\t\trebuild_preview()\n@export var brush_tile: String = \"grass\"\n\n\nfunc rebuild_preview() -> void:\n\tpass\n\n\nfunc _bake() -> void:\n\tfor cell: Vector2i in get_used_cells():\n\t\tset_cell(cell, 0, Vector2i.ZERO)\n\n\nfunc _ready() -> void:\n\tprint(\"ready\")\n\n\nfunc _clear() -> void:\n\tclear()\n"


static func run() -> bool:
	var sheet: EventSheetResource = _open()
	var view := EventSheetViewport.new()
	view.set_ace_registry(EventSheetACERegistry.new())
	view.set_sheet(sheet)
	var brush: EventRowData = _row_named(view, "Brush")
	var held: PackedStringArray = PackedStringArray()
	if brush != null:
		for child: EventRowData in brush.children:
			held.append(_texts(child).get_slice(" | ", 0))
	var ok: bool = SUPPORT.pins(P, [
		["the preview is read-only, as opening a file leaves it", sheet.read_only, true],
		["no Helpers bar gathers the unpublished functions", _uids_starting(view._root_rows, "helpers_group_"), 0],
		["every function reads at the root, in file order", _root_functions(view),
			["define_fn_rebuild_preview", "define_fn__bake", "define_fn__clear"]],
		["each run of two blank lines between blocks costs one block gap", _spacing_heights(view),
			[view.event_block_gap(), view.event_block_gap(), view.event_block_gap()]],
		["an export group is a strip on the preview too", brush != null and brush.row_type == EventRowData.RowType.SECTION, true],
		["the `##` line the lift kept on its own stays in its member's strip", held,
			PackedStringArray(["Cells painted per click", _texts(_member(view, "brush_size")).get_slice(" | ", 0),
				_texts(_member(view, "brush_tile")).get_slice(" | ", 0)])],
		["the file still re-emits byte for byte", str(SheetCompiler.compile(sheet).get("output", "")), SOURCE],
	])
	view.free()
	return ok


static func _open() -> EventSheetResource:
	var path: String = "user://preview_rows_in_file_order_probe.gd"
	var handle: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	handle.store_string(SOURCE)
	handle.close()
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(path)
	sheet.read_only = true
	var style: EventSheetEditorStyle = EventSheetEditorStyle.new()
	style.ensure_defaults()
	sheet.editor_style = style
	return sheet


## The uids of the function rows at the root, in the order they are drawn.
static func _root_functions(view: EventSheetViewport) -> Array:
	var found: Array = []
	for row_data: EventRowData in view._root_rows:
		if row_data.row_uid.begins_with("define_fn_"):
			found.append(row_data.row_uid)
	return found


## The measured height of every visible blank spacing row.
static func _spacing_heights(view: EventSheetViewport) -> Array:
	var heights: Array = []
	var flat: Array = view.get_flat_rows()
	for index: int in flat.size():
		var row_data: EventRowData = (flat[index] as Dictionary).get("row")
		if row_data != null and ViewportRowBuilder._is_spacing_row(row_data) and row_data.indent == 0:
			heights.append(view.get_row_height(index))
	return heights


static func _uids_starting(rows: Array, prefix: String) -> int:
	var found: int = 0
	for row_data: EventRowData in rows:
		if row_data.row_uid.begins_with(prefix):
			found += 1
		found += _uids_starting(row_data.children, prefix)
	return found


static func _row_named(view: EventSheetViewport, text: String) -> EventRowData:
	for entry: Dictionary in view.get_flat_rows():
		var row_data: EventRowData = entry.get("row")
		if row_data != null and not row_data.spans.is_empty() and row_data.spans[0].text == text:
			return row_data
	return null


static func _member(view: EventSheetViewport, var_name: String) -> EventRowData:
	for entry: Dictionary in view.get_flat_rows():
		var row_data: EventRowData = entry.get("row")
		if row_data != null and row_data.source_resource is LocalVariable \
				and (row_data.source_resource as LocalVariable).name == var_name:
			return row_data
	return EventRowData.new()


static func _texts(row_data: EventRowData) -> String:
	var parts := PackedStringArray()
	for span: SemanticSpan in row_data.spans:
		parts.append(span.text)
	return " | ".join(parts)
