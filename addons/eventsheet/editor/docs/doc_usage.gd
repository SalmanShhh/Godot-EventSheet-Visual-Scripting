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


## EVERY verb's count, from ONE walk of the sheet. The shape a caller with a LIST of verbs to
## label wants: the picker asks per row of a tree that is 1,878 rows long, and the Manual's search
## asks per matching verb per keystroke, and both were paying a whole-sheet walk for each ask - a
## project-sized job to answer a list-sized question. Build it once, read it with count_in().
##
## Two keys per row, because a caller may name the provider or leave it out and the answers differ:
## the ace_id alone counts the verb whoever published it, and "<ace_id>\n<provider_id>" counts the
## one provider's. That is exactly the rule the single-verb walk applies below.
static func counts_for(sheet: EventSheetResource) -> Dictionary:
	var counts: Dictionary = {}
	if sheet == null:
		return counts
	for event: Variant in sheet.events:
		_tally(event as Resource, counts)
	return counts


## One verb's count out of the map counts_for() built. The same question `count()` answers with a
## walk, answered with two dictionary lookups.
static func count_in(counts: Dictionary, provider_id: String, ace_id: String) -> int:
	var wanted_ace: String = ace_id.strip_edges()
	if wanted_ace.is_empty():
		return 0
	var wanted_provider: String = provider_id.strip_edges()
	if wanted_provider.is_empty():
		return int(counts.get(wanted_ace, 0))
	return int(counts.get("%s\n%s" % [wanted_ace, wanted_provider], 0))


## The sentence an entry shows, in the sheet's own words. "" when the verb is not used here at
## all - a reference entry that says "used 0 times" is noise, and the absence IS the answer.
static func usage_sentence(used: int) -> String:
	if used <= 0:
		return ""
	if used == 1:
		return "Used in this sheet: 1 event"
	return "Used in this sheet: %d events" % used


## One row, and everything nested under it, counted into the map rather than matched against one
## verb. Walks exactly what _collect walks, in the same order and with the same idea of what
## counts as a use, so the two answers cannot drift apart.
static func _tally(row: Resource, counts: Dictionary) -> void:
	var event: EventRow = row as EventRow
	if event == null:
		return
	# The trigger is the one part an event can spell TWICE - as the row's own trigger fields and as
	# an ACECondition beside them - and the single-verb walk counts such an event ONCE however many
	# of those spellings name the verb. So the trigger's keys are gathered and deduplicated before
	# they are counted, while a condition and an action each count on their own.
	var trigger_keys: Dictionary = {}
	_gather_keys(trigger_keys, event.trigger_provider_id, event.trigger_id)
	if event.trigger != null:
		_gather_keys(trigger_keys, str(event.trigger.get("provider_id")), str(event.trigger.get("ace_id")))
	for trigger_key: String in trigger_keys:
		counts[trigger_key] = int(counts.get(trigger_key, 0)) + 1
	for condition: ACECondition in event.conditions:
		if condition != null:
			_count_one(counts, condition.provider_id, condition.ace_id)
	for action: Variant in event.actions:
		var ace_action: ACEAction = action as ACEAction
		if ace_action != null:
			_count_one(counts, ace_action.provider_id, ace_action.ace_id)
	for sub_event: Variant in event.sub_events:
		_tally(sub_event as Resource, counts)


## One use, counted under both of its keys.
static func _count_one(counts: Dictionary, provider_id: String, ace_id: String) -> void:
	var keys: Dictionary = {}
	_gather_keys(keys, provider_id, ace_id)
	for key: String in keys:
		counts[key] = int(counts.get(key, 0)) + 1


## The two keys one use answers to: the verb on its own (the ask that names no provider) and the
## verb under the provider that published it. Nothing at all for a row with no verb.
static func _gather_keys(into: Dictionary, provider_id: String, ace_id: String) -> void:
	var row_ace: String = ace_id.strip_edges()
	if row_ace.is_empty():
		return
	into[row_ace] = true
	into["%s\n%s" % [row_ace, provider_id.strip_edges()]] = true


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
