@tool
extends SceneTree


func _init() -> void:
	var path: String = "res://eventsheet_addons/fps_controller/fps_controller_behavior.gd"
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(path)
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(sheet)
	var view: EventSheetViewport = dock._active_view()
	var uids: Dictionary = {}
	for entry: Variant in sheet.events:
		if entry is EventAnchorRow and (entry as EventAnchorRow).trigger_id == "OnUnhandledInput":
			for u: String in (entry as EventAnchorRow).event_uids:
				uids[u] = true
	for entry_row: Dictionary in view.get_flat_rows():
		var row_data: EventRowData = entry_row.get("row")
		if row_data == null:
			continue
		var source: Resource = row_data.source_resource
		if source is EventRow and uids.has((source as EventRow).event_uid):
			view._ensure_event_spans(row_data)
			var out: PackedStringArray = PackedStringArray()
			for span: SemanticSpan in row_data.spans:
				var label: String = ""
				if span.metadata is Dictionary:
					label = str((span.metadata as Dictionary).get("object_label", ""))
				out.append("[%s|%s]" % [label, span.text])
			print("ROW ", " ".join(out))
	quit(0)
