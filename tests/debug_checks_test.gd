# EventForge - the four windows that check a project and answer for it: the Project Doctor, Run Tests,
# Why didn't this fire? and Loose Ends. A finding or a failing claim is a coloured edge plus one
# sentence; the Doctor's fixes open as rows under the selected finding and are the only door a fix
# has; Run Tests runs again and copies its report without closing; Loose Ends reads the sheet again.
@tool
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")
const NAME := "debug_checks_test"
const TEST_PANEL_PATH := "res://addons/eventsheet/editor/dock/test_report_panel.gd"


static func run() -> bool:
	var ok: bool = _test_doctor_fix_rows()
	ok = _test_run_tests() and ok
	ok = _test_why_edge() and ok
	return _test_loose_ends_refresh() and ok


## The selected finding's fixes are rows under it; choosing another finding takes them away, and the
## blue button names the file it opens.
static func _test_doctor_fix_rows() -> bool:
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	var panel: EventSheetProjectDoctorPanel = EventSheetProjectDoctorPanel.new()
	panel.init(dock)
	panel._build()
	var page: Array[Dictionary] = [
		{"severity": "warning", "check": "unknown-input-action", "subject": "dash", "path": "res://player.gd",
			"event": 3, "message": "\"dash\" is not in the Input Map.", "is_new": true},
		{"severity": "warning", "check": "generated-output-drift", "path": "res://enemy.gd",
			"message": "The script differs from its sheet.", "is_new": false},
	]
	EventSheetProjectDoctorPanel.fill_inbox(panel._doctor_tree, panel._doctor_tree.create_item(), page)
	var branch: TreeItem = panel._doctor_tree.get_root().get_first_child()
	var first: TreeItem = branch.get_child(0)
	first.select(3)
	panel._on_finding_selected()
	var fixes: Array = first.get_children().map(func(row: TreeItem) -> String: return row.get_text(3))
	var opened: Array = [panel._open_button.text, panel._open_button.disabled, panel._this_finding.text]
	branch.get_child(1).select(3)
	panel._on_finding_selected()
	var ok: bool = SUPPORT.pins(NAME, [
		["the selected finding's fixes open as rows under it", fixes,
			["Fix: Add \"dash\" to the Input Map", "Fix: Pick an existing action…"]],
		["the blue button names the file it opens", opened,
			["Open player.gd", false, "Double-click it, or press Open, to open player.gd · event 3."]],
		["choosing another finding takes the last one's fixes away", first.get_child_count(), 0],
		["...and a finding with no fix gets no rows", branch.get_child(1).get_child_count(), 0],
		["the mark says which line is new", [first.get_metadata(3), branch.get_child(1).get_metadata(3)], [true, false]],
		["the Fix selected button is gone", panel.get("_fix_button"), null],
	])
	dock.free()
	return ok


## Run Again and Copy Report sit in the footer; a failing claim is a red edge plus its reason.
static func _test_run_tests() -> bool:
	var host: Control = Control.new()
	var panel: RefCounted = load(TEST_PANEL_PATH).new()
	panel.call("init", host)
	panel.call("_ensure_dialog")
	var dialog: ConfirmationDialog = panel.get("_dialog")
	var copy: Button = dialog.get_ok_button().get_parent().get_child(0) as Button
	var body: VBoxContainer = load(TEST_PANEL_PATH).build_body([{"test": "player_test", "entries": [
		["gravity pulls down", true, ""], ["death fires", false, "health never reached 0"]]}])
	var notes: Array = body.find_children("*", "PanelContainer", true, false).filter(
		func(node: Node) -> bool: return node is EventSheetPopupUI.StateNote).map(
		func(node: Node) -> Array: return [(node as EventSheetPopupUI.StateNote).text, (node as EventSheetPopupUI.StateNote).tone])
	var ok: bool = SUPPORT.pins(NAME, [
		["the footer runs again and closes", [dialog.ok_button_text, dialog.cancel_button_text, dialog.dialog_hide_on_ok],
			["Run Again", "Close", false]],
		["Copy Report stands first, on the left", copy.text if copy != null else "", "Copy Report"],
		["only the failing claim wears the edge, with its reason", notes,
			[["death fires - health never reached 0", EventSheetPopupUI.TONE_ERROR]]],
	])
	body.free()
	host.free()
	return ok


## The condition that said no wears the red edge; there is no arrow left in the table.
static func _test_why_edge() -> bool:
	var row: EventRow = EventRow.new()
	for expression: String in ["score >= 100", "lives > 0"]:
		var condition: ACECondition = ACECondition.new()
		condition.provider_id = "Core"
		condition.ace_id = "TestCondition"
		condition.codegen_template = expression
		row.conditions.append(condition)
	var body: Control = EventSheetWhyPanel.build_body(
		EventSheetWhyPanel.build_report(row, {"score": 142, "lives": 0}, true), 12)
	var blocker: EventSheetPopupUI.StateNote = body.find_child("Blocker", true, false) as EventSheetPopupUI.StateNote
	var arrows: Array = body.find_children("*", "Label", true, false).filter(
		func(label: Node) -> bool: return (label as Label).text.contains("←"))
	var ok: bool = SUPPORT.pins(NAME, [
		["the blocking condition is a red edge plus its words",
			[blocker.text, blocker.tone] if blocker != null else [],
			["false   TestCondition   lives = 0", EventSheetPopupUI.TONE_ERROR]],
		["no arrow is drawn beside it", arrows.size(), 0],
	])
	body.free()
	return ok


## Refresh reads the sheet again, so an entry fixed since the window opened goes away.
static func _test_loose_ends_refresh() -> bool:
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	var sheet: EventSheetResource = EventSheetResource.new()
	var comment: CommentRow = CommentRow.new()
	comment.text = "TODO tune the jump height"
	sheet.events.append(comment)
	dock.setup(sheet)
	var panel: EventSheetLooseEndsPanel = EventSheetLooseEndsPanel.new()
	panel.init(dock)
	var before: int = panel.refresh()
	dock._current_sheet.events.clear()
	var refresh: Button = panel.window.find_children("*", "Button", true, false).filter(
		func(button: Node) -> bool: return (button as Button).text == "Refresh").front()
	refresh.pressed.emit()
	var ok: bool = SUPPORT.pins(NAME, [
		["the list counts what it found", before, 1],
		["Refresh reads the sheet again", panel._entries.size(), 0],
		["the title says which sheet it read", panel.window.title, "Find what is unfinished in this sheet"],
	])
	dock.free()
	return ok
