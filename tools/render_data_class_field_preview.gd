# EventForge - render harness (dev tool) for structured data-class field authoring: a
# lifting data class shows its field rows, and the Add Field dialog (Name / Type /
# Default) opens over it. Run NON-headless:
#   godot --path . --script tools/render_data_class_field_preview.gd
@tool
extends SceneTree

var _frames: int = 0
var _editor: EventSheetEditor = null


func _init() -> void:
	root.title = "Data Class Fields"
	root.size = Vector2i(860, 560)
	root.gui_embed_subwindows = true
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frames += 1
	if _frames == 2:
		var sheet: EventSheetResource = EventSheetResource.new()
		var raw_row: RawCodeRow = RawCodeRow.new()
		raw_row.code = "class Stats:\n\tvar hp: int = 10\n\tvar armor: float = 0.5\n\tvar label: String = \"rookie\""
		sheet.events.append(raw_row)
		_editor = EventSheetEditor.new()
		root.add_child(_editor)
		_editor.setup(sheet)
		for flat_entry: Dictionary in _editor.get_viewport_control().get_flat_rows():
			var row_data: EventRowData = flat_entry.get("row")
			if row_data != null and row_data.source_resource == raw_row:
				_editor._context_row = row_data
		_editor._open_data_class_add_field()
		return
	if _frames < 12 or _editor == null:
		return
	var img: Image = root.get_texture().get_image()
	img.save_png("res://docs/images/data-class-add-field.png")
	print("[preview] data class fields %dx%d" % [img.get_width(), img.get_height()])
	quit(0)
