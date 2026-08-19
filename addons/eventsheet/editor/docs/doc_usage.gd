# EventSheet - EventSheetDocUsage: "where do I already use this?"
#
# The one question a reference entry can answer that a written page never can. A verb's page is
# the same page for everybody; the sheet in front of THIS reader is not, and "used in 2 events
# here" turns a definition into something they can act on - go and look at the two rows.
#
# Pure over the sheet it is handed: the walk takes an EventSheetResource, never the open dock, so
# the suite counts a fixture sheet without an editor around it. The rows come back as RESOURCES
# rather than as indices because that is what the viewport reveals a row by, and an index into a
# nested event tree is not a position anything can jump to.
@tool
class_name EventSheetDocUsage
extends RefCounted


## Every row of `sheet` that uses the verb, in reading order. The entries are the resources the
## viewport can reveal: the EventRow for a trigger, the ACECondition / ACEAction otherwise.
static func rows_using(sheet: EventSheetResource, provider_id: String, ace_id: String) -> Array[Resource]:
	var found: Array[Resource] = []
	if sheet == null or ace_id.strip_edges().is_empty():
		return found
	for event: Variant in sheet.events:
		_collect(event as Resource, provider_id.strip_edges(), ace_id.strip_edges(), found)
	return found


## How many rows of `sheet` use the verb. The number the entry prints, and the reason the count is
## its own call is that a caller which only wants the number should not build the list.
static func count(sheet: EventSheetResource, provider_id: String, ace_id: String) -> int:
	return rows_using(sheet, provider_id, ace_id).size()


## The sentence an entry shows, in the sheet's own words. "" when the verb is not used here at
## all - a reference entry that says "used 0 times" is noise, and the absence IS the answer.
static func usage_sentence(used: int) -> String:
	if used <= 0:
		return ""
	if used == 1:
		return "Used in this sheet: 1 event"
	return "Used in this sheet: %d events" % used


## One row, and everything nested under it.
static func _collect(row: Resource, provider_id: String, ace_id: String, into: Array[Resource]) -> void:
	var event: EventRow = row as EventRow
	if event == null:
		return
	if _matches(event.trigger_provider_id, event.trigger_id, provider_id, ace_id):
		into.append(event)
	elif event.trigger != null and _matches(str(event.trigger.get("provider_id")), str(event.trigger.get("ace_id")), provider_id, ace_id):
		into.append(event)
	for condition: ACECondition in event.conditions:
		if condition != null and _matches(condition.provider_id, condition.ace_id, provider_id, ace_id):
			into.append(condition)
	for action: Variant in event.actions:
		var ace_action: ACEAction = action as ACEAction
		if ace_action != null and _matches(ace_action.provider_id, ace_action.ace_id, provider_id, ace_id):
			into.append(ace_action)
	for sub_event: Variant in event.sub_events:
		_collect(sub_event as Resource, provider_id, ace_id, into)


## A row matches when its verb id matches, and its provider matches OR the caller named none.
## The provider is optional on purpose: a reader arriving from a search result holds the verb, and
## the same verb published by one provider is the verb they meant.
static func _matches(row_provider: String, row_ace: String, provider_id: String, ace_id: String) -> bool:
	if row_ace.strip_edges() != ace_id:
		return false
	return provider_id.is_empty() or row_provider.strip_edges() == provider_id
