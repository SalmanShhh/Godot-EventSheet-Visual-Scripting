# Godot EventSheets - Arrange by object / trigger / group, and saved views.
#
# The arrangement is DISPLAY ONLY, and that is the first thing pinned here: the sheet's events array
# comes out of an arrangement in exactly the order it went in, so the file, the emitted GDScript and
# the byte round-trip cannot move. After that the VALUES: which header each event reads under in
# each mode, the order the headers come in (first appearance, so two reads agree), the muted count a
# header wears, the Outline that follows the arrangement, and the round-trip of a saved view.
@tool
class_name SheetArrangementTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _test_mode_ids() and all_passed
	all_passed = _test_file_order_is_untouched() and all_passed
	all_passed = _test_arrange_by_trigger() and all_passed
	all_passed = _test_arrange_by_object() and all_passed
	all_passed = _test_arrange_by_group() and all_passed
	all_passed = _test_header_subtitle() and all_passed
	all_passed = _test_outline_follows() and all_passed
	all_passed = _test_saved_views_round_trip() and all_passed
	return all_passed


## Two triggered events, one condition-only event, and one of the triggers inside a group - enough
## for every mode to have something to say.
static func _fixture_sheet() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.events.append(_triggered("OnReady", "score", "10"))
	var group: EventGroup = EventGroup.new()
	group.group_name = "Combat"
	group.events.append(_triggered("OnProcess", "score", "1"))
	sheet.events.append(group)
	sheet.events.append(_triggered("OnReady", "lives", "3"))
	return sheet


static func _triggered(trigger_id: String, variable: String, value: String) -> EventRow:
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = trigger_id
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "SetVariable"
	action.params = {"variable": variable, "value": value}
	event.actions.append(action)
	return event


static func _rows_for(sheet: EventSheetResource, mode: int) -> Array:
	var viewport: EventSheetViewport = EventSheetViewport.new()
	viewport.arrangement_mode = mode
	viewport.set_sheet(sheet)
	var rows: Array = []
	rows.assign(viewport.get_row_tree())
	viewport.free()
	return rows


# ── the ids a saved view stores ───────────────────────────────────────────────────────────────


static func _test_mode_ids() -> bool:
	var passed: bool = _check("file order is the first mode",
		EventSheetArrangement.mode_id(EventSheetArrangement.MODE_FILE_ORDER), "file_order")
	passed = _check("object has its own id",
		EventSheetArrangement.mode_id(EventSheetArrangement.MODE_OBJECT), "object") and passed
	passed = _check("a stored id comes back as its mode",
		EventSheetArrangement.mode_from_id("trigger"), EventSheetArrangement.MODE_TRIGGER) and passed
	passed = _check("an id this build does not know reads as file order",
		EventSheetArrangement.mode_from_id("by_phase_of_the_moon"), EventSheetArrangement.MODE_FILE_ORDER) and passed
	passed = _check("the menu word for group",
		EventSheetArrangement.mode_label(EventSheetArrangement.MODE_GROUP), "Group") and passed
	return passed


# ── display only ──────────────────────────────────────────────────────────────────────────────


## The point of the whole item: arranging is a way of READING. The sheet's own order is the same
## before and after, so nothing downstream of the resource can tell an arrangement happened.
static func _test_file_order_is_untouched() -> bool:
	var sheet: EventSheetResource = _fixture_sheet()
	var before: Array = sheet.events.duplicate()
	var plain: Array = _rows_for(sheet, EventSheetArrangement.MODE_FILE_ORDER)
	var arranged: Array = _rows_for(sheet, EventSheetArrangement.MODE_TRIGGER)
	var passed: bool = _check("the events array is the same array, in the same order",
		sheet.events == before, true)
	passed = _check("file order arranges nothing",
		EventSheetArrangement.plan(plain, EventSheetArrangement.MODE_FILE_ORDER).size(), 0) and passed
	# Arranged, the sheet's own events sit under the headers instead of at the top level - and every
	# one of them is still there, each still standing for its own EventRow.
	var headers: int = 0
	var under_headers: int = 0
	for row: Variant in arranged:
		var row_data: EventRowData = row as EventRowData
		if row_data == null or not row_data.row_uid.begins_with("arrange_"):
			continue
		headers += 1
		under_headers += row_data.children.size()
	passed = _check("the arranged reading draws one header per trigger", headers, 2) and passed
	passed = _check("every event still reads, under a header", under_headers, 3) and passed
	return passed


# ── by trigger ────────────────────────────────────────────────────────────────────────────────


static func _test_arrange_by_trigger() -> bool:
	var sheet: EventSheetResource = _fixture_sheet()
	var rows: Array = _rows_for(sheet, EventSheetArrangement.MODE_FILE_ORDER)
	var planned: Array = EventSheetArrangement.plan(rows, EventSheetArrangement.MODE_TRIGGER)
	var headers: PackedStringArray = PackedStringArray()
	for bucket: Variant in planned:
		headers.append(str((bucket as Dictionary).get("header", "")))
	# The headers are the words the ROWS use, not the raw trigger ids - "On created" for `_ready` on
	# an object, and the tick trigger's own spelling.
	var passed: bool = _check("the headers are the triggers, in first-appearance order",
		", ".join(headers), "On created, Every tick (draw)")
	passed = _check("both On created events read under the one header",
		((planned[0] as Dictionary).get("rows", []) as Array).size(), 2) and passed
	passed = _check("the tick event reads under its own header",
		((planned[1] as Dictionary).get("rows", []) as Array).size(), 1) and passed
	return passed


# ── by object ─────────────────────────────────────────────────────────────────────────────────


## An event that names a node is about that node; an event that names nobody is about the object
## the sheet itself IS, which is the answer the head bar and the Object bar already give.
static func _test_arrange_by_object() -> bool:
	var passed: bool = _check("a node reference names the object it is",
		EventSheetArrangement.object_name_of("$Enemies/Slime"), "Slime")
	passed = _check("a unique-name reference names the object too",
		EventSheetArrangement.object_name_of("%HUD"), "HUD") and passed
	var about_enemy: EventRow = _triggered("OnReady", "hp", "5")
	about_enemy.with_node_target = "$Enemy"
	passed = _check("a With-Node event is about that node",
		EventSheetArrangement.object_words(about_enemy, "Player"), "Enemy") and passed
	passed = _check("an event that names nobody is about the sheet's own object",
		EventSheetArrangement.object_words(_triggered("OnReady", "hp", "5"), "Player"), "Player") and passed
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.custom_class_name = "Player"
	passed = _check("a class_name is what the sheet calls itself",
		EventSheetArrangement.self_object_of(sheet), "Player") and passed
	var unnamed: EventSheetResource = EventSheetResource.new()
	unnamed.external_source_path = "res://game/player_body.gd"
	passed = _check("without one, the file's own name reads as words",
		EventSheetArrangement.self_object_of(unnamed), "Player Body") and passed
	return passed


# ── by group ──────────────────────────────────────────────────────────────────────────────────


static func _test_arrange_by_group() -> bool:
	var sheet: EventSheetResource = _fixture_sheet()
	var rows: Array = _rows_for(sheet, EventSheetArrangement.MODE_FILE_ORDER)
	var planned: Array = EventSheetArrangement.plan(rows, EventSheetArrangement.MODE_GROUP)
	var headers: PackedStringArray = PackedStringArray()
	for bucket: Variant in planned:
		headers.append(str((bucket as Dictionary).get("header", "")))
	var passed: bool = _check("the ungrouped events and the group each get a header",
		", ".join(headers), "Ungrouped, Combat")
	passed = _check("the group's own event reads under the group's name",
		((planned[1] as Dictionary).get("rows", []) as Array).size(), 1) and passed
	return passed


# ── the header's own words ────────────────────────────────────────────────────────────────────


static func _test_header_subtitle() -> bool:
	var passed: bool = _check("one event says so in the singular",
		EventSheetArrangement.header_subtitle(1), "1 event")
	passed = _check("more than one counts them",
		EventSheetArrangement.header_subtitle(4), "4 events") and passed
	return passed


# ── the Outline follows ───────────────────────────────────────────────────────────────────────


static func _test_outline_follows() -> bool:
	var sheet: EventSheetResource = _fixture_sheet()
	var rows: Array = _rows_for(sheet, EventSheetArrangement.MODE_FILE_ORDER)
	var entries: Array = EventSheetOutlinePanel.arranged_entries(sheet, rows, EventSheetArrangement.MODE_TRIGGER)
	var first: Dictionary = entries[0]
	var second: Dictionary = entries[1]
	var passed: bool = _check("the first entry is the first header", str(first.get("label", "")), "On created")
	passed = _check("a header is a group in the jump tree", str(first.get("kind", "")), "group") and passed
	passed = _check("its events hang under it", int(second.get("parent", -1)), 0) and passed
	passed = _check("an arranged event still points at its own event row",
		second.get("resource", null) is EventRow, true) and passed
	passed = _check("file order falls back to the structural walk",
		EventSheetOutlinePanel.arranged_entries(sheet, rows, EventSheetArrangement.MODE_FILE_ORDER).size(),
		EventSheetOutlinePanel.outline_entries(sheet).size()) and passed
	return passed


# ── saved views ───────────────────────────────────────────────────────────────────────────────


static func _test_saved_views_round_trip() -> bool:
	EventSheetSavedViews.delete_view("Combat pass")
	var blob: Dictionary = EventSheetSavedViews.describe(EventSheetArrangement.MODE_OBJECT, "  hp  ",
		{"humanized_names": true, "compact_rows": false})
	var passed: bool = _check("a view stores the arrangement by its id", str(blob.get("arrangement", "")), "object")
	passed = _check("the filter is stored trimmed", str(blob.get("filter", "")), "hp") and passed
	passed = _check("a view needs a name", EventSheetSavedViews.save_view("   ", blob), false) and passed
	passed = _check("naming one keeps it", EventSheetSavedViews.save_view("Combat pass", blob), true) and passed
	passed = _check("it is offered by name",
		Array(EventSheetSavedViews.view_names()).has("Combat pass"), true) and passed
	var restored: Dictionary = EventSheetSavedViews.view("Combat pass")
	passed = _check("the arrangement comes back",
		EventSheetSavedViews.arrangement_of(restored), EventSheetArrangement.MODE_OBJECT) and passed
	passed = _check("the filter comes back", EventSheetSavedViews.filter_of(restored), "hp") and passed
	passed = _check("a lens comes back",
		bool(EventSheetSavedViews.lenses_of(restored).get("humanized_names", false)), true) and passed
	passed = _check("forgetting one removes it", EventSheetSavedViews.delete_view("Combat pass"), true) and passed
	passed = _check("forgetting it twice says so", EventSheetSavedViews.delete_view("Combat pass"), false) and passed
	return passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] sheet_arrangement_test: %s" % label)
		return true
	print("[FAIL] sheet_arrangement_test: %s - expected %s, got %s" % [label, str(expected), str(actual)])
	return false
