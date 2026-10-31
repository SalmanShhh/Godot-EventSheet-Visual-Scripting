# Godot EventSheets - a Project Doctor finding lists its fixes in the editor
#
# Selecting a finding builds its fix rows and its Learn more row under it. Built while the Tree was
# still handling the click that selected the finding, Godot refused every one of them, so in the
# editor no fix row ever appeared, while a test that called the handler directly saw them all. The
# rows are built once the click is over: the selection reaches the handler deferred. Pinned here as
# the wiring itself, since only a real click can show the refusal: the inbox's item_selected reaches
# the panel's handler once, and deferred.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const TEST_NAME := "doctor_fix_rows_deferred_test"


static func run() -> bool:
	var dock: Control = Control.new()
	var panel: EventSheetProjectDoctorPanel = EventSheetProjectDoctorPanel.new()
	panel.init(dock)
	panel._build()
	var tree: Tree = panel._doctor_tree
	var flags: Array = []
	for connection: Dictionary in tree.get_signal_connection_list("item_selected"):
		var callable: Callable = connection.get("callable")
		if callable.get_method() == "_on_finding_selected":
			flags.append(int(connection.get("flags", 0)) & CONNECT_DEFERRED)
	var ok: bool = SUPPORT.pins(TEST_NAME, [
		["the selection reaches the finding handler once, deferred", flags, [CONNECT_DEFERRED]],
	])
	dock.free()
	return ok
