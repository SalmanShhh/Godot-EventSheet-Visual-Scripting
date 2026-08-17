@tool
extends SceneTree


func _init() -> void:
	var path: String = "res://eventsheet_addons/fps_controller/fps_controller_behavior.gd"
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(path)
	var uids: Dictionary = {}
	for entry: Variant in sheet.events:
		if entry is EventAnchorRow and (entry as EventAnchorRow).trigger_id == "OnUnhandledInput":
			for u: String in (entry as EventAnchorRow).event_uids:
				uids[u] = true
	for entry: Variant in sheet.events:
		if entry is EventRow and uids.has((entry as EventRow).event_uid):
			_dump(entry as EventRow, 0)
	quit(0)


func _dump(row: EventRow, depth: int) -> void:
	var pad: String = "  ".repeat(depth)
	print(pad, "ROW trigger=", row.trigger_id, " else=", row.else_mode, " conds=", row.conditions.size(), " actions=", row.actions.size())
	for c: Variant in row.conditions:
		print(pad, "  COND ", (c as ACECondition).provider_id, "/", (c as ACECondition).ace_id, " params=", (c as ACECondition).params)
	for a: Variant in row.actions:
		if a is ACEAction:
			print(pad, "  ACT ", (a as ACEAction).provider_id, "/", (a as ACEAction).ace_id, " params=", (a as ACEAction).params)
		else:
			print(pad, "  ACT<", a.get_class(), "> ", a.get("code"))
	for s: Variant in row.sub_events:
		if s is EventRow:
			_dump(s as EventRow, depth + 1)
