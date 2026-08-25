# Godot EventSheets - the "Why didn't this fire?" answer (preview module).
#
# Rendered by tools/render_previews.gd, which owns the window and the shutter; this owns the picture.
# Every line of the answer is assembled by the real reporter from a real row, a real streamed frame
# and a real sheet - the trigger's count, each condition's verdict against the value it saw, and the
# facts about the group the row sits in.
@tool
extends RefCounted

const PREVIEW_NAME: String = "why-didnt-it-run"
const PREVIEW_SIZE: Vector2i = Vector2i(760, 460)


static func build(host: Window) -> Control:
	var row: EventRow = EventRow.new()
	row.trigger_id = "OnHurt"
	row.conditions.append(_condition("body", "==", "true"))
	row.conditions.append(_condition("hp", "<=", "0"))
	# The row sits in a group another row can switch off while the game runs, which is the fact the
	# answer could not say before it was handed the sheet.
	var group: EventGroup = EventGroup.new()
	group.name = "Damage"
	group.runtime_toggleable = true
	group.events.append(row)
	var switcher: EventRow = EventRow.new()
	var switch: ACEAction = ACEAction.new()
	switch.provider_id = "Core"
	switch.ace_id = "SetGroupActive"
	switch.params = {"group": "\"Damage\"", "active": "false"}
	switcher.actions.append(switch)
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.events.append(group)
	sheet.events.append(switcher)

	EventSheetRunProfile.forget()
	EventSheetRunProfile.adopt_run_for_test(row.event_uid, 12, 12, 3000, "last night")
	var report: Dictionary = EventSheetWhyPanel.build_report(row, {"body": true, "hp": 40}, true, sheet)
	var body: Control = EventSheetWhyPanel.build_body(report, 2)
	host.add_child(EventSheetPopupUI.margined(body))
	return body


## One comparison, spelled the way the dock bakes one at apply time: the shipped descriptor's
## template with this row's own values in it, so the panel reads and evaluates the same string.
static func _condition(left: String, operator: String, right: String) -> ACECondition:
	var condition: ACECondition = ACECondition.new()
	condition.provider_id = "Core"
	condition.ace_id = "CompareValues"
	condition.params = {"a": left, "op": operator, "b": right}
	condition.codegen_template = "%s %s %s" % [left, operator, right]
	return condition
