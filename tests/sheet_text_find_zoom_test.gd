# Godot EventSheets - the sheet's plain-text listing, the Find results bar, the Properties bar,
# Replace object's ranking, and sheet zoom.
#
# Pins VALUES, not counts: the exact listing a fixture produces (the "+ " / "-> " shape, one extra
# indent per sub-event, the event-number gutter, the Markdown wrapper), the Find results entry
# shapes, the Properties bar's heading, the ranking Replace object offers, and every zoom step.
@tool
class_name SheetTextFindZoomTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _test_listing() and all_passed
	all_passed = _test_markdown() and all_passed
	all_passed = _test_find_references_carry_their_row() and all_passed
	all_passed = _test_find_results_summary() and all_passed
	all_passed = _test_properties_heading() and all_passed
	all_passed = _test_replace_object_members() and all_passed
	all_passed = _test_zoom_steps() and all_passed
	return all_passed


static func _fixture_sheet() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnReady"
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "SetVariable"
	action.params = {"variable": "score", "value": "10"}
	event.actions.append(action)
	var sub: EventRow = EventRow.new()
	var condition: ACECondition = ACECondition.new()
	condition.provider_id = "Core"
	condition.ace_id = "CompareVariable"
	condition.params = {"variable": "score", "operator": ">", "value": "5"}
	sub.conditions.append(condition)
	var sub_action: ACEAction = ACEAction.new()
	sub_action.provider_id = "Core"
	sub_action.ace_id = "SetVariable"
	sub_action.params = {"variable": "score", "value": "0"}
	sub.actions.append(sub_action)
	event.sub_events.append(sub)
	sheet.events.append(event)
	return sheet


## The listing is the sheet's reading with "+ " for a condition and "-> " for an action, one extra
## indent per sub-event, and NOT the canvas's add affordances (an offer is not content).
static func _test_listing() -> bool:
	var viewport: EventSheetViewport = EventSheetViewport.new()
	viewport.set_sheet(_fixture_sheet())
	var listing: String = EventSheetTextListing.text_for_rows(viewport.get_row_tree(), false)
	viewport.free()
	var expected: String = "+ On created\n    -> SetVariable\n    + CompareVariable\n        -> SetVariable"
	return _check("the listing reads + condition / -> action, indented by sub-event", listing, expected)


## Save as text writes Markdown with the event numbers on, so the file and the sheet's margin
## agree about what "event 2" is.
static func _test_markdown() -> bool:
	var viewport: EventSheetViewport = EventSheetViewport.new()
	viewport.set_sheet(_fixture_sheet())
	var markdown: String = EventSheetTextListing.markdown_for_rows(viewport.get_row_tree(), "player")
	viewport.free()
	var passed: bool = _check("the Markdown names the sheet", markdown.begins_with("# player\n\n```text\n"), true)
	passed = _check("the second event prints its number in the gutter",
		markdown.contains("2         + CompareVariable"), true) and passed
	passed = _check("the listing is fenced", markdown.ends_with("\n```\n"), true) and passed
	return passed


## A reference carries the ROW it sits on, which is what lets a Find result jump to it.
static func _test_find_references_carry_their_row() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	var event: EventRow = EventRow.new()
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "SetVariable"
	action.params = {"variable": "hp", "value": "100"}
	event.actions.append(action)
	sheet.events.append(event)
	var references: Array = EventSheetFindReferences.find_in_sheet(sheet, "hp")
	var passed: bool = _check("the param hit is found once", references.size(), 1)
	if references.is_empty():
		return false
	passed = _check("the hit says which surface it lives in", str((references[0] as Dictionary).get("kind", "")), "param") and passed
	passed = _check("the hit carries its row", (references[0] as Dictionary).get("row", null) == event, true) and passed
	passed = _check("a whole-symbol search does not match a longer name",
		EventSheetFindReferences.find_in_sheet(sheet, "h").size(), 0) and passed
	return passed


static func _test_find_results_summary() -> bool:
	var passed: bool = _check("one sheet reads singular", EventSheetFindResultsBar.summary_text(3, 1), "3 in 1 sheet")
	passed = _check("more than one reads plural", EventSheetFindResultsBar.summary_text(7, 2), "7 in 2 sheets") and passed
	return passed


static func _test_properties_heading() -> bool:
	var passed: bool = _check("the heading names the thing and what it is",
		EventSheetPropertiesBar.heading_for("Flash", "action"), "PROPERTIES · Flash · action")
	passed = _check("nothing selected says only PROPERTIES",
		EventSheetPropertiesBar.heading_for("  ", "action"), "PROPERTIES") and passed
	return passed


## Replace object reads the members the selection uses through the object it is replacing - the
## list the Doctor warns about when the new object does not have them.
static func _test_replace_object_members() -> bool:
	var event: EventRow = EventRow.new()
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "SetVariable"
	action.params = {"variable": "hp", "value": "$Enemy.hp + $Enemy.armour"}
	event.actions.append(action)
	var used: PackedStringArray = EventSheetReplaceObject.members_used([event], "$Enemy")
	var passed: bool = _check("both members are read, in first-seen order", ", ".join(used), "hp, armour")
	passed = _check("a different object's members are not read",
		", ".join(EventSheetReplaceObject.members_used([event], "$Boss")), "") and passed
	passed = _check("no scene means nothing is claimed missing",
		EventSheetReplaceObject.missing_members([event], "$Enemy", "$Boss", null).size(), 0) and passed
	return passed


## Zoom runs 50% to 200% through the six steps the status-bar pill offers, and stops at the ends.
static func _test_zoom_steps() -> bool:
	var passed: bool = _check("in from 100% is 125%", EventSheetPalette.step_sheet_zoom(1.0, 1), 1.25)
	passed = _check("out from 100% is 75%", EventSheetPalette.step_sheet_zoom(1.0, -1), 0.75) and passed
	passed = _check("in from 150% is 200%", EventSheetPalette.step_sheet_zoom(1.5, 1), 2.0) and passed
	passed = _check("200% is the top", EventSheetPalette.step_sheet_zoom(2.0, 1), 2.0) and passed
	passed = _check("50% is the bottom", EventSheetPalette.step_sheet_zoom(0.5, -1), 0.5) and passed
	passed = _check("the pill says a percentage", EventSheetPalette.sheet_zoom_label(1.25), "125%") and passed
	var before: float = EventSheetPalette.sheet_zoom()
	EventSheetPalette.set_sheet_zoom(4.0)
	passed = _check("the remembered zoom is clamped to the range", EventSheetPalette.sheet_zoom(), 2.0) and passed
	EventSheetPalette.set_sheet_zoom(before)
	var viewport: EventSheetViewport = EventSheetViewport.new()
	viewport.set_sheet(_fixture_sheet())
	viewport.zoom_in()
	var zoomed: float = viewport.get_zoom_factor()
	viewport.zoom_reset()
	var reset: float = viewport.get_zoom_factor()
	viewport.free()
	passed = _check("zooming in steps to 125%", zoomed, 1.25) and passed
	passed = _check("Ctrl+0 returns to 100%", reset, 1.0) and passed
	return passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] sheet_text_find_zoom_test: %s" % label)
		return true
	print("[FAIL] sheet_text_find_zoom_test: %s (got %s, expected %s)" % [label, str(actual), str(expected)])
	return false
