# EventForge - a script opened as a sheet that ends on a `#` paragraph under its last function reads
# that paragraph last. The file writes its top-level notes after its functions, so the canvas waits
# for the functions before it draws them, rather than reading the closing words above the function
# they close under.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "closing_note_reads_last_test"

const SOURCE := "extends Node2D\n\nfunc _ready() -> void:\n\tprint(\"ready\")\n\nfunc juice_tile(index: int) -> void:\n\tprint(index)\n\n# Closing words about this file.\n"


static func run() -> bool:
	var sheet: EventSheetResource = _open()
	var view := EventSheetViewport.new()
	view.set_ace_registry(EventSheetACERegistry.new())
	view.set_sheet(sheet)
	var ok: bool = SUPPORT.pins(P, [
		["the lift keeps the paragraph as a note row", _note_count(sheet), 1],
		["the paragraph reads under the function it closes under", _tail_kinds(view, 2),
			["define_fn_juice_tile", "comment"]],
		["the file still re-emits byte for byte", str(SheetCompiler.compile(sheet).get("output", "")), SOURCE],
	])
	view.free()
	return ok


static func _open() -> EventSheetResource:
	var path: String = "user://closing_note_reads_last_probe.gd"
	var handle: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	handle.store_string(SOURCE)
	handle.close()
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(path)
	sheet.read_only = true
	var style: EventSheetEditorStyle = EventSheetEditorStyle.new()
	style.ensure_defaults()
	sheet.editor_style = style
	return sheet


static func _note_count(sheet: EventSheetResource) -> int:
	var found: int = 0
	for entry: Variant in sheet.events:
		if entry is CommentRow:
			found += 1
	return found


## The last `count` root rows, a note named "comment" and every other row by its uid.
static func _tail_kinds(view: EventSheetViewport, count: int) -> Array:
	var kinds: Array = []
	var rows: Array = view._root_rows
	for index: int in range(maxi(rows.size() - count, 0), rows.size()):
		var row_data: EventRowData = rows[index]
		kinds.append("comment" if row_data.source_resource is CommentRow else row_data.row_uid)
	return kinds
