# Godot EventSheets - Migrate lists a retired row that has no newer row to become.
#
# Two on-screen rows were retired because they test the window rectangle, which is wrong as soon as a
# camera moves. Neither has a row it can be rewritten into without changing what it means, so neither
# carries a forwarding address. Migrate must still LIST each one, under the rows it leaves alone, with
# a reason that says to pick a replacement by hand, and must never rewrite it: the row keeps its id,
# its template and its values, and the sheet compiles to the same bytes.
@tool
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")
const P := "migrate_lists_retired_rows_test"
const RETIRED: Array[String] = ["IsOnScreen", "IsOutsideLayout"]


static func run() -> bool:
	var known: Dictionary = EventForgeSuccessors.catalog()
	var ok: bool = true
	for ace_id: String in RETIRED:
		var entry: Dictionary = known.get("Core::%s" % ace_id, {})
		ok = SUPPORT.check(P, "%s is still in the vocabulary, retired, with no forwarding address" % ace_id,
			[bool(entry.get("is_deprecated", false)), EventForgeSuccessors.resolve("Core::%s" % ace_id, known).is_empty()], [true, true]) and ok
		var sheet: EventSheetResource = _sheet_with(ace_id)
		var before: String = SUPPORT.compile_output(sheet)
		var planned: Array[Dictionary] = EventSheetMigrationPlan.plan(sheet, known)
		var asking: Array[Dictionary] = EventSheetMigrationPlan.asking(planned)
		ok = SUPPORT.check(P, "Migrate lists %s among the rows it leaves alone" % ace_id, asking.size(), 1) and ok
		ok = SUPPORT.check(P, "and rewrites nothing for it", EventSheetMigrationPlan.migrating(planned).size(), 0) and ok
		if asking.size() == 1:
			ok = SUPPORT.check(P, "%s is not forwarded anywhere" % ace_id, str(asking[0].get("to", "")), "") and ok
			ok = SUPPORT.check(P, "its reason says to pick a replacement by hand",
				EventSheetMigrateDialog.reason_text(asking[0]).contains("by hand"), true) and ok
		ok = SUPPORT.check(P, "the sheet still compiles to the same bytes after the question", SUPPORT.compile_output(sheet), before) and ok
	ok = _window_shows_only_what_it_holds() and ok
	return ok


## Nothing here can be rewritten, so the empty "What will be rewritten" box is gone and the rows left
## as they are carry the room; the button that rewrites is switched off.
static func _window_shows_only_what_it_holds() -> bool:
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(_sheet_with("IsOnScreen"))
	editor.open_migrate_dialog()
	var dialog: EventSheetMigrateDialog = editor._migrate_dialog as EventSheetMigrateDialog
	var ok: bool = true
	ok = SUPPORT.check(P, "the window with nothing to rewrite hides the empty rewrite box",
		[dialog._rewrite_card.visible, dialog._left_alone_card.visible], [false, true]) and ok
	ok = SUPPORT.check(P, "and its rewrite button is off",
		dialog._dialog.get_ok_button().disabled, true) and ok
	editor.free()
	return ok


static func _sheet_with(ace_id: String) -> EventSheetResource:
	var condition := ACECondition.new()
	condition.provider_id = "Core"
	condition.ace_id = ace_id
	condition.codegen_template = "get_viewport_rect().has_point({point})" if ace_id == "IsOnScreen" else "not get_viewport_rect().has_point({point})"
	condition.params = {"point": "position"}
	var action := ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "Print"
	action.codegen_template = "print({message})"
	action.params = {"message": "\"here\""}
	var event := EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnProcess"
	event.conditions = [condition] as Array[ACECondition]
	event.actions = [action] as Array[Resource]
	var sheet := EventSheetResource.new()
	sheet.host_class = "Node2D"
	sheet.events = [event] as Array[Resource]
	return sheet
