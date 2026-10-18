# Godot EventSheets - picking the group a Set/Is Group Active row switches, and renaming it.
#
# What this pins:
#   1. THE PICKER. A described dropdown of the groups the script will have, by the name they were
#      given, switchable ones first, each saying what picking it does; the value it stores is still the
#      frozen guard token. Groups of included sheets are offered too. A row naming no group keeps its
#      value as a choice of its own, so OK on an untouched dialog rewrites nothing.
#   2. PICKING A GROUP THAT IS NOT SWITCHABLE turns its switch on, in the same undo step as the row.
#   3. RENAMING A GROUP rewrites every row that switches it, in one undo step, and the name drives the
#      token from then on - while an older group whose two name fields differ keeps its token until it
#      is actually renamed.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const NAME := "group_switch_picker_test"
const INCLUDED_PATH := "user://group_switch_picker_included.tres"


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _test_picker_choices() and all_passed
	all_passed = _test_picker_field() and all_passed
	all_passed = _test_pick_switches_on() and all_passed
	all_passed = _test_rename_follows() and all_passed
	all_passed = _test_kept_token() and all_passed
	all_passed = _test_row_reads_name() and all_passed
	return all_passed


static func _group(group_name: String, description: String = "", switchable: bool = false,
		enabled: bool = true) -> EventGroup:
	var group: EventGroup = EventGroup.new()
	group.name = group_name
	group.group_name = group_name
	group.description = description
	group.runtime_toggleable = switchable
	group.enabled = enabled
	return group


static func _switch_row(ace_id: String, value: String) -> EventRow:
	var row: EventRow = EventRow.new()
	if ace_id == "IsGroupActive":
		var condition: ACECondition = ACECondition.new()
		condition.ace_id = ace_id
		condition.params = {"group": value}
		row.conditions.append(condition)
	else:
		var action: ACEAction = ACEAction.new()
		action.ace_id = ace_id
		action.params = {"group": value, "active": "true"}
		row.actions.append(action)
	return row


static func _sheet() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	var waves: EventGroup = _group("Waves", "Spawns each wave.")
	var boss: EventGroup = _group("Boss", "The boss fight.", true, false)
	waves.events.append(boss)
	sheet.events.append(waves)
	return sheet


# ── 1. The picker ──


static func _test_picker_choices() -> bool:
	var sheet: EventSheetResource = _sheet()
	var included: EventSheetResource = EventSheetResource.new()
	included.events.append(_group("Juice", "Screen shake and flashes."))
	ResourceSaver.save(included, INCLUDED_PATH)
	sheet.includes = [INCLUDED_PATH]
	var offered: Array[Dictionary] = EventSheetGroupFacts.choices(sheet)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(INCLUDED_PATH))
	var rows: Array = []
	for entry: Dictionary in offered:
		rows.append([str(entry.get("name")), str(entry.get("value")), str(entry.get("description"))])
	return SUPPORT.check(NAME, "the picker offers groups by name, switchable first, included sheets' too", rows, [
		["Boss", "\"boss\"", "The boss fight. Off at start, switchable."],
		["Waves", "\"waves\"", "Spawns each wave. Not switchable: picking it turns on Can be switched at runtime."],
		["Juice", "\"juice\"", "Screen shake and flashes. Not switchable, and it lives in group_switch_picker_included.tres: turn on Can be switched at runtime there."],
	])


static func _test_picker_field() -> bool:
	var sheet: EventSheetResource = _sheet()
	var dialog: ACEParamsDialog = ACEParamsDialog.new()
	dialog.set_lint_context_provider(func() -> EventSheetResource: return sheet)
	dialog._context = {"mode": "append_action"}
	var built: Array[Control] = [dialog._create_sheet_group_field("group", "\"combat\"")]
	var fresh: OptionButton = dialog._fields.get("group") as OptionButton
	var fresh_read: Array = [fresh.item_count, fresh.get_item_text(fresh.selected),
		str(dialog._extract_value(fresh))]
	dialog._context = {"mode": "replace_action"}
	built.append(dialog._create_sheet_group_field("group", "\"waves\""))
	var picked: OptionButton = dialog._fields.get("group") as OptionButton
	var picked_read: Array = [picked.get_item_text(picked.selected), picked.tooltip_text]
	built.append(dialog._create_sheet_group_field("group", "my_group_var"))
	var kept: OptionButton = dialog._fields.get("group") as OptionButton
	var kept_read: Array = [kept.item_count, str(dialog._extract_value(kept))]
	for control: Control in built:
		control.free()
	return SUPPORT.pins(NAME, [
		["a new row picks the first group, by name, storing its token", fresh_read, [2, "Boss", "\"boss\""]],
		["an existing row opens on its group, described", picked_read,
			["Waves", "Spawns each wave. Not switchable: picking it turns on Can be switched at runtime."]],
		["a value naming no group is kept as written", kept_read, [3, "my_group_var"]],
	])


# ── 2. Picking a group that is not switchable ──


static func _test_pick_switches_on() -> bool:
	var sheet: EventSheetResource = _sheet()
	var target: EventRow = EventRow.new()
	sheet.events.append(target)
	var dock: EventSheetDock = EventSheetDock.new()
	dock.setup(sheet)
	var undo: RefCounted = EventSheetEditorTest.FakeEditorUndoRedoManager.new()
	dock.set_undo_redo_manager(undo)
	var definition: ACEDefinition = dock._find_definition("Core", "SetGroupActive")
	dock._ace_apply._apply_ace_definition(definition, {"group": "\"waves\"", "active": "true"},
		{"mode": "append_action", "selected_resource": target})
	var waves: EventGroup = dock._current_sheet.events[0] as EventGroup
	var applied: Array = [waves.runtime_toggleable, (dock._current_sheet.events[1] as EventRow).actions.size()]
	undo.undo()
	var undone: EventGroup = dock._current_sheet.events[0] as EventGroup
	var reverted: Array = [undone.runtime_toggleable, (dock._current_sheet.events[1] as EventRow).actions.size()]
	dock.free()
	return SUPPORT.pins(NAME, [
		["picking a group that is not switchable turns its switch on with the row", applied, [true, 1]],
		["and one Ctrl+Z takes back both", reverted, [false, 0]],
	])


# ── 3. Renaming ──


static func _test_rename_follows() -> bool:
	var sheet: EventSheetResource = _sheet()
	sheet.events.append(_switch_row("SetGroupActive", "\"boss\""))
	sheet.events.append(_switch_row("IsGroupActive", "\"boss\""))
	sheet.events.append(_switch_row("SetGroupActive", "\"waves\""))
	var dock: EventSheetDock = EventSheetDock.new()
	dock.setup(sheet)
	var undo: RefCounted = EventSheetEditorTest.FakeEditorUndoRedoManager.new()
	dock.set_undo_redo_manager(undo)
	var boss: EventGroup = (dock._current_sheet.events[0] as EventGroup).events[0] as EventGroup
	dock._quick_prompts.apply_group_edit(boss, "Final Boss", boss.description)
	var renamed: Array = _values(dock._current_sheet)
	var head: EventGroup = (dock._current_sheet.events[0] as EventGroup).events[0] as EventGroup
	var fields: Array = [head.name, head.group_name]
	undo.undo()
	var undone: Array = _values(dock._current_sheet)
	dock.free()
	return SUPPORT.pins(NAME, [
		["renaming a group rewrites every row that switches it, and only those", renamed,
			["\"final_boss\"", "\"final_boss\"", "\"waves\""]],
		["the name drives the token", fields, ["Final Boss", "Final Boss"]],
		["one Ctrl+Z takes back the rename and the rows", undone, ["\"boss\"", "\"boss\"", "\"waves\""]],
	])


static func _values(sheet: EventSheetResource) -> Array:
	var values: Array = []
	for index: int in range(1, sheet.events.size()):
		var row: EventRow = sheet.events[index] as EventRow
		var ace: Resource = row.actions[0] if not row.actions.is_empty() else row.conditions[0]
		values.append(str((ace.get("params") as Dictionary).get("group")))
	return values


static func _test_kept_token() -> bool:
	var older: EventGroup = _group("Boss")
	older.group_name = "boss_fight"
	EventSheetQuickPromptDialogs.set_group_fields(older, "Boss", "a new description")
	var kept: String = older.group_name
	var described: String = EventSheetGroupFacts.choice_description(older)
	EventSheetQuickPromptDialogs.set_group_fields(older, "Big Boss", "")
	return SUPPORT.pins(NAME, [
		["an older group's differing token is kept while its name is unchanged", kept, "boss_fight"],
		["and the picker shows it", described,
			"a new description Not switchable: picking it turns on Can be switched at runtime. Its switch is written as boss_fight."],
		["a real rename moves the token to the name", older.group_name, "Big Boss"],
	])


# ── 4. The row ──


## The row says the group by the name it was given, the way the sheet shows the group's head; a
## token that names no group of the sheet reads exactly as it is stored.
static func _test_row_reads_name() -> bool:
	var sheet: EventSheetResource = _sheet()
	var known: EventRow = _switch_row("SetGroupActive", "\"boss\"")
	var unknown: EventRow = _switch_row("SetGroupActive", "\"combat\"")
	(known.actions[0] as ACEAction).provider_id = "Core"
	(unknown.actions[0] as ACEAction).provider_id = "Core"
	sheet.events.append(known)
	sheet.events.append(unknown)
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(sheet)
	var read: Array = [_action_text(editor.get_viewport_control(), known),
		_action_text(editor.get_viewport_control(), unknown)]
	editor.free()
	return SUPPORT.check(NAME, "a switch row names its group as the head does", read,
		["Set group Boss active", "Set group \"combat\" active"])


## The words of the one action span on the row that holds `event`, or "<missing>".
static func _action_text(viewport: EventSheetViewport, event: EventRow) -> String:
	for entry: Dictionary in viewport.get_flat_rows():
		var row: EventRowData = entry.get("row") as EventRowData
		if row == null or row.source_resource != event:
			continue
		for span: SemanticSpan in row.spans:
			if span != null and span.text.begins_with("Set group"):
				return span.text
	return "<missing>"
