# Godot EventSheets - the migration band reaches every sheet that has something to migrate.
#
# The band at the head of a sheet counts the rows written in an older spelling and the rows that ask
# for a decision, and its Migrate door opens the receipt. Two sheets never got it: a script holding
# only rows whose verb was RETIRED (no newer spelling to count, so nothing to say), and a `.tres`
# sheet, which has no scaffold lines for the head to be built from. Both now say it, and a sheet with
# nothing to migrate still says nothing.
@tool
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")
const P := "head_migration_band_reach_test"


static func run() -> bool:
	var ok: bool = true
	ok = SUPPORT.check(P, "a script holding a retired row says one row asks you",
		_head_words(_script_sheet(["IsOnScreen"], "Print")).has("1 row asks you"), true) and ok
	ok = SUPPORT.check(P, "a script holding both retired on-screen rows says two ask you",
		_head_words(_script_sheet(["IsOnScreen", "IsOutsideLayout"], "Print")).has("2 rows ask you"), true) and ok
	ok = SUPPORT.check(P, "a script with only current verbs says nothing about migrating",
		_migration_words(_script_sheet([""], "Print")), PackedStringArray()) and ok
	ok = SUPPORT.check(P, "a script with a newer spelling still says so",
		_head_words(_script_sheet([""], "StopAudio")).has("1 row has a newer spelling"), true) and ok
	ok = SUPPORT.check(P, "a .tres sheet with a retired row says one row asks you",
		_head_words(_tres_sheet(["IsOnScreen"], "Print")).has("1 row asks you"), true) and ok
	ok = SUPPORT.check(P, "a .tres sheet with a newer spelling says so",
		_head_words(_tres_sheet([""], "StopAudio")).has("1 row has a newer spelling"), true) and ok
	ok = SUPPORT.check(P, "a .tres sheet with only current verbs says nothing about migrating",
		_migration_words(_tres_sheet([""], "Print")), PackedStringArray()) and ok
	# A script that opened as a read-only preview keeps the migration line as a door: the count says
	# rows ask you, so a click on it has to answer, and the window's Apply unlocks the preview itself.
	var preview: EventSheetResource = _script_sheet(["IsOnScreen"], "Print")
	preview.external_source_path = "res://head_migration_band_probe.gd"
	preview.read_only = true
	ok = SUPPORT.check(P, "a read-only script preview keeps the migration line clickable",
		_migration_actions(preview).has("migration"), true) and ok
	var locked_resource: EventSheetResource = _tres_sheet(["IsOnScreen"], "Print")
	locked_resource.read_only = true
	ok = SUPPORT.check(P, "a read-only sheet that is not a script preview stays without the door",
		_migration_actions(locked_resource), PackedStringArray()) and ok
	return ok


## The head action each word of the migration line carries (empty when the line is not a door).
static func _migration_actions(sheet: EventSheetResource) -> PackedStringArray:
	var actions: PackedStringArray = PackedStringArray()
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(sheet)
	for entry: Dictionary in editor._viewport.get_flat_rows():
		var row: EventRowData = entry.get("row")
		if row == null or row.source_resource != null:
			continue
		var is_migration: bool = false
		for span: EventSheetSemanticSpan in row.spans:
			if span.metadata is Dictionary and str((span.metadata as Dictionary).get("head_band", "")) == "migration":
				is_migration = true
		if not is_migration:
			continue
		for span: EventSheetSemanticSpan in row.spans:
			if span.metadata is Dictionary and not str((span.metadata as Dictionary).get("head_action", "")).is_empty():
				actions.append(str((span.metadata as Dictionary).get("head_action", "")))
	editor.free()
	return actions


static func _head_words(sheet: EventSheetResource) -> PackedStringArray:
	var words: PackedStringArray = PackedStringArray()
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(sheet)
	for entry: Dictionary in editor._viewport.get_flat_rows():
		var row: EventRowData = entry.get("row")
		if row == null or row.source_resource != null:
			continue
		for span: EventSheetSemanticSpan in row.spans:
			words.append(span.text)
	editor.free()
	return words


static func _migration_words(sheet: EventSheetResource) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for word: String in _head_words(sheet):
		if word.contains("asks you") or word.contains("ask you") or word.contains("newer spelling"):
			found.append(word)
	return found


## What an opened script looks like: scaffold lines first, then the events.
static func _script_sheet(condition_ids: Array, action_id: String) -> EventSheetResource:
	var sheet: EventSheetResource = _tres_sheet(condition_ids, action_id)
	var scaffold: RawCodeRow = RawCodeRow.new()
	scaffold.code = "extends Node2D"
	sheet.events.insert(0, scaffold)
	return sheet


## What a `.tres` sheet looks like: events only, no scaffold lines, a file behind it. One event for
## each condition id given; an empty id is an event with no condition.
static func _tres_sheet(condition_ids: Array, action_id: String) -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	sheet.external_source_path = "res://head_migration_band_probe.tres"
	for id: String in condition_ids:
		var event: EventRow = EventRow.new()
		event.trigger_provider_id = "Core"
		event.trigger_id = "OnProcess"
		if not id.is_empty():
			var condition: ACECondition = ACECondition.new()
			condition.provider_id = "Core"
			condition.ace_id = id
			condition.codegen_template = "get_viewport_rect().has_point(position)" if id == "IsOnScreen" else "not get_viewport_rect().has_point(position)"
			event.conditions = [condition] as Array[ACECondition]
		var action: ACEAction = ACEAction.new()
		action.provider_id = "Core"
		action.ace_id = action_id
		action.codegen_template = "print(\"here\")" if action_id == "Print" else "$Audio.stop()"
		event.actions = [action] as Array[Resource]
		sheet.events.append(event)
	return sheet
