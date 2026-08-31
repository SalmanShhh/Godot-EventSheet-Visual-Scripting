# EventForge - render harness (dev tool) for the files band and the table read: builds a sheet that
# reads a spreadsheet, writes a scoreboard back and asks the player for a file, so the head's files
# bands and the Set + Table Of File row can be eyeballed together. Run NON-headless:
#   godot --path . --script tools/render_files_band_preview.gd
@tool
extends SceneTree

var _frames: int = 0
var _editor: EventSheetEditor = null


func _init() -> void:
	root.title = "The Files Band"
	root.size = Vector2i(1100, 520)
	root.gui_embed_subwindows = true
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frames += 1
	if _frames == 2:
		_editor = EventSheetEditor.new()
		root.add_child(_editor)
		_editor.setup(_sheet())
		_editor._set_status("The head says what this sheet touches on disk, before any row is opened.")
		return
	if _frames < 14 or _editor == null:
		return
	var image: Image = root.get_texture().get_image()
	image.save_png("res://docs/images/files-band.png")
	print("[preview] files band %dx%d" % [image.get_width(), image.get_height()])
	quit(0)


## A sheet that reads a table, writes one back and asks the player for a file - the three things the
## band has words for, in one sheet.
func _sheet() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.custom_class_name = "ScoreBoard"
	sheet.host_class = "Node"
	sheet.variables["items"] = {"type": "Array", "default": []}
	# The band stack is built from the file's own leading lines, so the preview opens a sheet that
	# has them - the same shape an opened `.gd` arrives in.
	for line: String in ["class_name ScoreBoard", "extends Node",
			"## Reads the item table and writes the run's scores back out."]:
		var prelude: RawCodeRow = RawCodeRow.new()
		prelude.code = line
		sheet.events.append(prelude)

	var read_row: EventRow = _event()
	read_row.actions.append(_action("SetVar", {"var_name": "items",
		"value": _template("FileTable", {"path": "\"res://data/items.csv\"", "separator": "\",\"",
			"headers": EventForgeTableACEs.HEADERS_NAMED})}))
	sheet.events.append(read_row)

	var write_row: EventRow = _event()
	write_row.actions.append(_action("WriteFileTable", {"path": "\"user://scores.csv\"",
		"table": "items", "separator": "\",\"", "headers": EventForgeTableACEs.HEADERS_NAMED}))
	sheet.events.append(write_row)

	var log_row: EventRow = _event()
	log_row.conditions.append(_condition("ForEachLineInFile", {"path": "\"user://run.log\""}))
	log_row.actions.append(_action("Print", {"message": "line"}))
	sheet.events.append(log_row)

	var ask_row: EventRow = _event()
	ask_row.actions.append(_action("OpenFileChooser", {}))
	sheet.events.append(ask_row)
	return sheet


func _event() -> EventRow:
	var row: EventRow = EventRow.new()
	row.trigger_provider_id = "Core"
	row.trigger_id = "OnReady"
	return row


func _action(ace_id: String, params: Dictionary) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	action.params = params
	action.codegen_template = _descriptor_template(ace_id)
	return action


func _condition(ace_id: String, params: Dictionary) -> ACECondition:
	var condition: ACECondition = ACECondition.new()
	condition.provider_id = "Core"
	condition.ace_id = ace_id
	condition.params = params
	condition.codegen_template = _descriptor_template(ace_id)
	return condition


## One verb's shipped template with these values baked in - what the row would hold after the picker.
func _template(ace_id: String, params: Dictionary) -> String:
	return ActionCodegen._apply_template(_descriptor_template(ace_id), params)


func _descriptor_template(ace_id: String) -> String:
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", ace_id)
	return "" if descriptor == null else descriptor.codegen_template
