@tool
extends SceneTree

const SOURCE: String = """extends Node2D

@onready var hurtbox: Area2D = $Hurtbox

func _ready() -> void:
	$Hurtbox.body_entered.connect(_on_hurtbox_body_entered)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
		fire()
	elif event is InputEventKey and not (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_SPACE:
		stop_firing()

func _on_hurtbox_body_entered(body: Node2D) -> void:
	print(body.name)

func fire() -> void:
	print("fire")

func stop_firing() -> void:
	print("stop")
"""


func _init() -> void:
	var path: String = "user://probe_hand.gd"
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(SOURCE)
	file.close()
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(path)
	for entry: Variant in sheet.events:
		if entry is EventAnchorRow:
			print("ANCHOR ", (entry as EventAnchorRow).trigger_id, " rows=", (entry as EventAnchorRow).event_uids.size())
		elif entry is EventRow:
			print("EVENT trigger=", (entry as EventRow).trigger_id, " source=", (entry as EventRow).trigger_source_path, " args=", (entry as EventRow).trigger_args, " else=", (entry as EventRow).else_mode)
		elif entry is RawCodeRow:
			print("RAW <", (entry as RawCodeRow).code.split("\n")[0], ">")
		else:
			print("OTHER ", entry.get_class())
	var out: String = str(SheetCompiler.compile(sheet, path).get("output", ""))
	print("byte identical=", out == SOURCE)
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(sheet)
	var view: EventSheetViewport = dock._active_view()
	for entry_row: Dictionary in view.get_flat_rows():
		var row_data: EventRowData = entry_row.get("row")
		if row_data == null or not (row_data.source_resource is EventRow):
			continue
		view._ensure_event_spans(row_data)
		var out_spans: PackedStringArray = PackedStringArray()
		for span: SemanticSpan in row_data.spans:
			var label: String = ""
			if span.metadata is Dictionary:
				label = str((span.metadata as Dictionary).get("object_label", ""))
			out_spans.append("[%s|%s]" % [label, span.text])
		print("ROW ", " ".join(out_spans))
	quit(0)
