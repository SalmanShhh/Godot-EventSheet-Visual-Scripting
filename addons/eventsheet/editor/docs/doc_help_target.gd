# EventSheet - EventSheetDocHelpTarget: "help for the selected item".
#
# F1 is not "open the manual" - it is the reflex every reader of an event sheet already has:
# point at the thing, ask what it is. So the answer depends on WHAT is selected, and this file is
# that one mapping, kept pure and in one place so the key, the row menu and the Manual's
# follow-selection can never disagree about what the reader is pointing at.
#
#   a condition or an action row   -> its entry on the reference
#   an object label                -> that object's reference page (its conditions, actions and
#                                     expressions; the engine's own class reference is one click
#                                     further, in the Script editor's help)
#   an event group                 -> the Manual's page on groups
#   a behavior's Include bar       -> that behavior's reference
#   anything else                  -> the row's own most identifying verb, or "" for a row that
#                                     names none (a comment, a blank group)
#
# Everything is static and pure over its inputs - the sheet, the selected resource and the span
# metadata of the click - so the whole mapping is pinned by the suite with no editor around it.
@tool
class_name EventSheetDocHelpTarget
extends RefCounted

## Where behavior packs live, for the Include bar of an opened pack.
const PACKS_ROOT := "res://eventsheet_addons/"

## The guide the Manual answers "what is a group?" with when it ships, and the glossary entry that
## answers it when it does not. Asked in that order, because a written page teaches and a glossary
## line only translates.
const GROUPS_GUIDE_PAGE := "Modules/Groups-Tags-And-Systems"
const GROUPS_GLOSSARY_TERM := "group"


## The doc id F1 should open for the current selection. "" when the selection explains nothing,
## so a caller says so rather than opening a blank page.
static func doc_id_for(sheet: EventSheetResource, resource: Resource, metadata: Dictionary = {}) -> String:
	var object_label: String = str(metadata.get("object_label", "")).strip_edges()
	if not object_label.is_empty():
		var object_id: String = doc_id_for_object(sheet, object_label)
		if not object_id.is_empty():
			return object_id
	if str(metadata.get("kind", "")) == "pack_include":
		var include_id: String = doc_id_for_include(sheet)
		if not include_id.is_empty():
			return include_id
	if is_group(resource):
		return groups_page_id()
	return EventSheetDocExplain.doc_id_for_row(resource, metadata)


## The reference page an object label names. The CLASS is what gets a page - an object is an
## instance of something, and what it can do is what its class can do - so a label the sheet's own
## census cannot place resolves to nothing rather than to a page named after a variable.
static func doc_id_for_object(sheet: EventSheetResource, object_label: String) -> String:
	var entry: Dictionary = EventSheetObjectProperties.find_entry(sheet, object_label)
	var class_id: String = str(entry.get("class", "")).strip_edges()
	if class_id.is_empty():
		return ""
	return EventSheetDocReference.doc_id(EventSheetDocReference.KIND_CLASS, class_id)


## The behavior reference for the pack a sheet IS, from the file it was opened from. "" for any
## other sheet - a plain script's Include bar names the script, and a script is not a behavior.
static func doc_id_for_include(sheet: EventSheetResource) -> String:
	var pack_dir: String = pack_directory_of(sheet)
	if pack_dir.is_empty():
		return ""
	return EventSheetDocReference.doc_id(EventSheetDocReference.KIND_PACK, pack_dir)


## The pack directory a sheet was opened from ("res://eventsheet_addons/quest/quest.gd" ->
## "quest"), or "" for a sheet that does not live in a pack.
static func pack_directory_of(sheet: EventSheetResource) -> String:
	if sheet == null:
		return ""
	var path: String = str(sheet.get("external_source_path")).strip_edges()
	if not path.begins_with(PACKS_ROOT):
		return ""
	return path.substr(PACKS_ROOT.length()).get_slice("/", 0)


## The Manual's page on groups: the written guide when the bundle carries it, and the glossary
## entry when it does not. Never "" - a group is one of the few things this editor can always
## explain, because the glossary ships in the plugin itself.
static func groups_page_id() -> String:
	if EventSheetDocLibrary.has_page(GROUPS_GUIDE_PAGE):
		return "guide:%s" % GROUPS_GUIDE_PAGE
	return EventSheetDocReference.doc_id(EventSheetDocReference.KIND_GLOSSARY, GROUPS_GLOSSARY_TERM)


## True for a row that is a group rather than an event. Both shapes count: the group resource a
## sheet stores, and the event row a group is drawn as when a lifted file only had the band.
static func is_group(resource: Resource) -> bool:
	if resource == null:
		return false
	if resource is EventGroup or resource is EventGroupResource:
		return true
	var event: EventRow = resource as EventRow
	if event == null:
		return false
	# An event with nothing in either lane but children under it is the shape a group takes on a
	# sheet: nothing to explain about the row itself, everything to explain about the band.
	return event.trigger == null and event.trigger_id.strip_edges().is_empty() \
		and event.conditions.is_empty() and event.actions.is_empty() and not event.sub_events.is_empty()
