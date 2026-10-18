# Godot EventSheets - a #region inside a group survives a save.
#
# A group's events are written inside the trigger functions (`_process`, `_ready`...), not at the top
# of the class, so a region the group holds has to be written there too, beside the events it wraps.
# It used to be dropped on a .gd save, and written at the top of the class (wrapping nothing) on a
# .tres one. What this pins:
#   1. A .gd sheet: the fences are written inside the function at the events' indent, reopen as the
#      same fence rows in the same group at the same places, and a second save is byte-identical.
#   2. A .tres sheet: the fences are written beside the events, never at the top of the class.
#   3. A styled region (colour and description) keeps its `## @ace_region(...)` line through all that.
#   4. A region whose events have two triggers opens in one function and closes in the other, and the
#      saved script still parses.
# Every file is saved and read back from disk, the way the editor saves and opens it.
@tool
class_name RegionInGroupSaveTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const NAME := "region_in_group_save_test"
const PATH := "user://_region_in_group_save.gd"


static func run() -> bool:
	var passed: bool = true
	passed = _test_gd_save() and passed
	passed = _test_tres_save() and passed
	passed = _test_styled_region() and passed
	passed = _test_two_triggers() and passed
	return passed


static func _test_gd_save() -> bool:
	var opened: EventSheetResource = _opened_with_group(["print(\"a\")", "print(\"b\")", "print(\"c\")"])
	var group: EventGroup = _group_of(opened)
	if group == null:
		return SUPPORT.check(NAME, "the group reopens from its .gd", false, true)
	group.events.insert(1, EventSheetRegionFacts.make_fence("Hits"))
	group.events.append(EventSheetRegionFacts.make_fence("", true))
	var saved: String = _save(opened)
	var reopened: EventSheetResource = _open(saved)
	var reopened_group: EventGroup = _group_of(reopened)
	return SUPPORT.pins(NAME, [
		["the opener is written inside the function, before the event it wraps",
			saved.contains("\tprint(\"a\")\n\t#region Hits\n\t# @group:combat\n\tprint(\"b\")"), true],
		["the closer is written after the last event it wraps", saved.contains("\tprint(\"c\")\n\t#endregion"), true],
		["no fence is written at the top of the class", saved.contains("\n#region"), false],
		["the saved script parses", _parses(saved), true],
		["the fences reopen in the group, where they were", _shape(reopened_group), ["event", "region Hits", "event", "event", "end"]],
		["no fence is left at the top of the sheet", _top_fences(reopened), 0],
		["a second save writes the same bytes", _save(reopened), saved],
	])


static func _test_tres_save() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	var group: EventGroup = EventGroup.new()
	group.group_name = "Combat"
	group.events.append(EventSheetRegionFacts.make_fence("Hits"))
	group.events.append(_event("print(\"a\")"))
	group.events.append(EventSheetRegionFacts.make_fence("", true))
	sheet.events.append(group)
	var output: String = SUPPORT.compile_output(sheet)
	return SUPPORT.pins(NAME, [
		["a .tres sheet writes the fences beside the events", output.contains("\t#region Hits\n\t# @group:combat\n\tprint(\"a\")\n\t#endregion"), true],
		["and not at the top of the class", output.contains("\n#region"), false],
	])


static func _test_styled_region() -> bool:
	var opened: EventSheetResource = _opened_with_group(["print(\"a\")", "print(\"b\")"])
	var group: EventGroup = _group_of(opened)
	if group == null:
		return SUPPORT.check(NAME, "the group reopens for the styled region", false, true)
	var opener: CustomBlockRow = EventSheetRegionFacts.make_fence("Hits")
	opener.fields["description"] = "Every way a hit lands."
	opener.fields["color"] = "#5FA35F"
	group.events.insert(0, opener)
	group.events.append(EventSheetRegionFacts.make_fence("", true))
	var saved: String = _save(opened)
	var reopened_group: EventGroup = _group_of(_open(saved))
	var reopened_opener: CustomBlockRow = null
	if reopened_group != null and not reopened_group.events.is_empty() and reopened_group.events[0] is CustomBlockRow:
		reopened_opener = reopened_group.events[0] as CustomBlockRow
	return SUPPORT.pins(NAME, [
		["the style line is written above the opener, inside the function", saved.contains("\t## @ace_region("), true],
		["the styled region reopens with its description",
			str(reopened_opener.fields.get("description", "")) if reopened_opener != null else "", "Every way a hit lands."],
		["a second save of the styled region writes the same bytes", _save(_open(saved)), saved],
	])


static func _test_two_triggers() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	var group: EventGroup = EventGroup.new()
	group.group_name = "Combat"
	var on_ready: EventRow = _event("print(\"ready\")")
	on_ready.trigger_id = "OnReady"
	group.events.append(EventSheetRegionFacts.make_fence("Setup"))
	group.events.append(on_ready)
	group.events.append(_event("print(\"tick\")"))
	group.events.append(EventSheetRegionFacts.make_fence("", true))
	sheet.events.append(group)
	var output: String = SUPPORT.compile_output(sheet)
	return SUPPORT.pins(NAME, [
		["the region opens in the first function", output.contains("#region Setup\n\t# @group:combat\n\tprint(\"ready\")"), true],
		["and closes in the second", output.contains("\tprint(\"tick\")\n\t#endregion"), true],
		["the script still parses", _parses(output), true],
	])


# ── helpers ──────────────────────────────────────────────────────────────────────────────────────


## A sheet with one Combat group of every-tick events, saved to disk and opened back as a .gd sheet.
static func _opened_with_group(statements: Array) -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	var group: EventGroup = EventGroup.new()
	group.group_name = "Combat"
	for statement: Variant in statements:
		group.events.append(_event(str(statement)))
	sheet.events.append(group)
	return _open(SUPPORT.compile_output(sheet, PATH))


static func _save(sheet: EventSheetResource) -> String:
	sheet.external_source_path = PATH
	var output: String = SUPPORT.compile_output(sheet, PATH)
	var file: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(output)
	file.close()
	return output


static func _open(source: String) -> EventSheetResource:
	var file: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(source)
	file.close()
	var sheet: EventSheetResource = SUPPORT.reopen(FileAccess.get_file_as_string(PATH), true, PATH)
	sheet.external_source_path = PATH
	return sheet


static func _event(statement: String) -> EventRow:
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnProcess"
	var raw: RawCodeRow = RawCodeRow.new()
	raw.code = statement
	event.actions.append(raw)
	return event


static func _group_of(sheet: EventSheetResource) -> EventGroup:
	if sheet == null:
		return null
	for row: Variant in sheet.events:
		if row is EventGroup:
			return row as EventGroup
	return null


## A group's rows as words: "event", "region <name>" for an opener, "end" for a closer.
static func _shape(group: EventGroup) -> Array:
	var shape: Array = []
	if group == null:
		return shape
	for row: Variant in group.events:
		if EventSheetRegionFacts.is_closing_fence(row):
			shape.append("end")
		elif EventSheetRegionFacts.is_fence(row):
			shape.append("region " + str((row as CustomBlockRow).fields.get("label", "")))
		elif row is EventRow:
			shape.append("event")
	return shape


static func _top_fences(sheet: EventSheetResource) -> int:
	var count: int = 0
	for row: Variant in sheet.events:
		if EventSheetRegionFacts.is_fence(row):
			count += 1
	return count


static func _parses(source: String) -> bool:
	var script: GDScript = GDScript.new()
	script.source_code = source
	return script.reload() == OK
