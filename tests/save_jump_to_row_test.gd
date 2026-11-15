# EventSheets - a save whose written script Godot cannot compile takes the reader to the row it came
# from. The status line already said "the row it came from is marked"; for a script sheet the reader
# was left to find that row by hand, where a sheet saved as a resource already jumped to it.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "save_jump_to_row_test"
const STUB := "extends Control\nvar _current_sheet = null\nvar view = null\nfunc _active_view():\n\treturn view\nfunc _set_status(_text, _is_error = false):\n\tpass\n"


static func run() -> bool:
	EventSheetSaveChecks.clear_layers()
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.external_source_path = "res://tests/save_jump_to_row_probe.gd"
	var first: EventRow = EventRow.new()
	first.trigger_provider_id = "Core"
	first.trigger_id = "OnReady"
	var second: EventRow = EventRow.new()
	second.trigger_provider_id = "Core"
	second.trigger_id = "OnProcess"
	sheet.events.append(first)
	sheet.events.append(second)
	var view: EventSheetViewport = EventSheetViewport.new()
	view.set_ace_registry(EventSheetACERegistry.new())
	view.size = Vector2(1200.0, 900.0)
	view.set_sheet(sheet)
	var stub_script: GDScript = GDScript.new()
	stub_script.source_code = STUB
	stub_script.reload()
	var dock: Control = stub_script.new() as Control
	dock._current_sheet = sheet
	dock.view = view
	var checks: EventSheetSaveChecks = EventSheetSaveChecks.new()
	checks.init(dock)
	var request: Dictionary = {
		"path": sheet.external_source_path, "sheet_key": EventSheetCompileFindings.key_of(sheet),
		"source_map": [{"uid": str(second.get_instance_id()), "start": 3, "end": 5, "kind": "event"}], "backed": true,
	}
	var before: Resource = view.get_selected_row_data().source_resource if view.get_selected_row_data() != null else null
	checks.apply_engine_result(request, [{"line": 4, "message": "Identifier \"flub\" not declared in the current scope."}])
	var selected: EventRowData = view.get_selected_row_data()
	var rows: Array = [
		["nothing was selected before the answer", before, null],
		["the row the failing line came from is selected", selected.source_resource if selected != null else null, second],
	]
	# A clean answer moves nothing.
	view.select_resource(first)
	checks.apply_engine_result(request, [])
	var after_clean: EventRowData = view.get_selected_row_data()
	rows.append(["a clean answer leaves the selection alone", after_clean.source_resource if after_clean != null else null, first])
	EventSheetSaveChecks.clear_layers()
	dock.free()
	view.free()
	return SUPPORT.pins(P, rows)
