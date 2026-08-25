@tool
class_name EventSheetArrangement
extends RefCounted
# ARRANGE BY - one sheet, four readings of its order.
#
# The same events, re-grouped under headers: by the object they talk about (Player / Enemy / HUD),
# by the trigger they hang off (On created / Every tick / On hit), by the group they sit in, or in
# the order the file has them. DISPLAY ONLY, and that word is load-bearing: nothing here touches the
# sheet, the events array keeps its order, the emitted GDScript cannot move and the byte round-trip
# is untouched. An event keeps its number too, because numbers are computed from `sheet.events`
# rather than from the row list this pass rewrites.
#
# The headers are read off the EVENTS, never off the built rows: a row's spans are built lazily,
# long after the pass that arranges them, so a header taken from spans would read the same empty
# answer for every row. Everything here is static and pure over the resources, which is also what
# makes the whole arrangement testable without a dock.

## The arrangement modes. The ORDER is the menu's order; the IDS are what a saved view stores, so
## they are frozen the way every other public id here is - add, never rename.
const MODE_FILE_ORDER := 0
const MODE_OBJECT := 1
const MODE_TRIGGER := 2
const MODE_GROUP := 3

const MODE_IDS: PackedStringArray = ["file_order", "object", "trigger", "group"]

## The words the View menu shows. Kept beside the ids so a menu and a saved view can never disagree.
const MODE_LABELS: PackedStringArray = ["File order", "Object", "Trigger", "Group"]

## What an event with no object of its own reads under when the sheet has no name to offer either.
const OBJECT_FALLBACK := "System"
## An event with no trigger runs on its conditions every tick, which is what the sheet calls it.
const TRIGGER_FALLBACK := "Every tick"
## Events that sit in no group at all.
const GROUP_FALLBACK := "Ungrouped"


## The id a saved view stores for `mode` ("" for an unknown one, which reads as file order).
static func mode_id(mode: int) -> String:
	return MODE_IDS[mode] if mode >= 0 and mode < MODE_IDS.size() else ""


## The mode a stored id means. Anything unrecognised reads as file order, so a saved view written by
## a newer build degrades to the untouched reading rather than to nothing.
static func mode_from_id(id: String) -> int:
	var found: int = Array(MODE_IDS).find(id.strip_edges())
	return found if found >= 0 else MODE_FILE_ORDER


static func mode_label(mode: int) -> String:
	return MODE_LABELS[mode] if mode >= 0 and mode < MODE_LABELS.size() else MODE_LABELS[MODE_FILE_ORDER]


## True when this built row is one of the sheet's own events - the only rows an arrangement moves.
## Head bars, the class-setup strip, published function blocks and the add affordances all answer
## false and stay exactly where the builder put them.
static func is_arrangeable(row: Variant) -> bool:
	var row_data: EventRowData = row as EventRowData
	if row_data == null:
		return false
	return row_data.row_type == EventRowData.RowType.EVENT and row_data.source_resource is EventRow


## True when this built row is a real group of the sheet (not a synthetic head folder).
static func is_group_row(row: Variant) -> bool:
	var row_data: EventRowData = row as EventRowData
	if row_data == null:
		return false
	return row_data.row_type == EventRowData.RowType.GROUP and row_data.source_resource is EventGroup


## The title a group row reads with - its own name.
static func group_title(row: EventRowData) -> String:
	var group: EventGroup = row.source_resource as EventGroup
	if group == null:
		return ""
	return str(group.get("group_name")).strip_edges()


## Every event this arrangement will move, in file order, each with the group it currently sits in.
## Entries are `{"row": EventRowData, "event": EventRow, "group": String}`. Groups are walked
## recursively, so an event nested two groups deep answers with the group that DIRECTLY holds it -
## the same answer the breadcrumb gives.
static func collect_events(rows: Array, group_name: String = "") -> Array:
	var found: Array = []
	for entry: Variant in rows:
		var row_data: EventRowData = entry as EventRowData
		if row_data == null:
			continue
		if is_arrangeable(row_data):
			found.append({
				"row": row_data,
				"event": row_data.source_resource as EventRow,
				"group": group_name,
			})
			continue
		if is_group_row(row_data):
			found.append_array(collect_events(row_data.children, group_title(row_data)))
	return found


## The header text one collected entry reads under in `mode`. `self_object` is what the sheet calls
## itself, which is the object an event that names nobody else is talking about.
static func header_for(entry: Dictionary, mode: int, self_object: String = OBJECT_FALLBACK) -> String:
	var event: EventRow = entry.get("event") as EventRow
	match mode:
		MODE_OBJECT:
			return object_words(event, self_object)
		MODE_TRIGGER:
			return trigger_words(event, self_object)
		MODE_GROUP:
			var group_label: String = str(entry.get("group", "")).strip_edges()
			return group_label if not group_label.is_empty() else GROUP_FALLBACK
	return ""


## The trigger an event hangs off, in the words the sheet reads it with ("On created", "Every tick",
## "On hit"). The descriptor registry is asked first - it is static, so this answer is the same one
## the row shows - and a signal trigger is named after the signal, never after its raw id.
static func trigger_words(event: EventRow, self_object: String = OBJECT_FALLBACK,
		scene_root: bool = false) -> String:
	if event == null:
		return TRIGGER_FALLBACK
	var trigger_id: String = str(event.trigger_id).strip_edges()
	if trigger_id.is_empty():
		var authored: ACECondition = event.trigger
		if authored != null:
			trigger_id = str(authored.ace_id).strip_edges()
		if trigger_id.is_empty():
			return TRIGGER_FALLBACK
	var provider_id: String = str(event.trigger_provider_id).strip_edges()
	var display_text: String = trigger_id
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor(provider_id, trigger_id)
	if descriptor != null and not descriptor.display_name.strip_edges().is_empty():
		display_text = EventSheetL10n.translate(descriptor.display_name)
	elif trigger_id.begins_with("signal:"):
		# A signal already NAMED on_* must not read "On On ..." - strip the prefix first.
		display_text = "On %s" % trigger_id.trim_prefix("signal:").trim_prefix("on_").capitalize()
	# The same two lens hooks the ROW goes through, in the same order, so a header and the rows
	# under it can never call the one trigger by two different names.
	display_text = EventSheetViewportReadingRows.tick_trigger_words(trigger_id, display_text)
	var lifecycle: Dictionary = EventSheetViewportReadingRows.lifecycle_trigger_reading(
		trigger_id, self_object, scene_root, self_object)
	if not lifecycle.is_empty():
		display_text = str(lifecycle.get("text", display_text))
	return display_text


## The object an event talks about: the first node it names anywhere in its own rows, read the way
## the Object bar names it (no leading `$`, no path). An event that names nobody is talking about
## the object the sheet itself is.
static func object_words(event: EventRow, self_object: String = OBJECT_FALLBACK) -> String:
	if event == null:
		return self_object
	var scoped: String = str(event.with_node_target).strip_edges()
	if not scoped.is_empty():
		return object_name_of(scoped)
	var named: Array[String] = EventSheetRefactor.collect_node_references([event])
	if not named.is_empty():
		return object_name_of(named[0])
	var fallback: String = self_object.strip_edges()
	return fallback if not fallback.is_empty() else OBJECT_FALLBACK


## `$Enemies/Slime` reads as `Slime` - a node reference names an object by its last segment, which
## is the name the Object bar, the rows and this header all use.
static func object_name_of(reference: String) -> String:
	var clean: String = reference.strip_edges().trim_prefix("$").trim_prefix("%")
	clean = clean.replace("\"", "").strip_edges()
	if clean.contains("/"):
		clean = clean.get_slice("/", clean.get_slice_count("/") - 1)
	return clean if not clean.is_empty() else OBJECT_FALLBACK


## What a sheet calls itself - the object every event that names nobody else is talking about. Its
## class name when it has one, otherwise the file's own name read as words, so `player_body.gd`
## answers `Player Body` rather than a path. One answer, shared by the headers and the Outline, so
## the two can never disagree about which object an event belongs to.
static func self_object_of(sheet: EventSheetResource) -> String:
	if sheet == null:
		return OBJECT_FALLBACK
	var declared: String = str(sheet.get("custom_class_name")).strip_edges()
	if not declared.is_empty():
		return declared
	var path: String = str(sheet.get("external_source_path")).strip_edges()
	if path.is_empty():
		path = str(sheet.resource_path).strip_edges()
	var base: String = path.get_file().get_basename().strip_edges()
	return base.capitalize() if not base.is_empty() else OBJECT_FALLBACK


## The arrangement itself: `[{"header": String, "rows": Array[EventRowData]}]`, headers in the order
## they first appear in the file so two reads of the same sheet always list them the same way, and
## the events inside each header in file order. `MODE_FILE_ORDER` plans nothing (the caller leaves
## the rows alone).
static func plan(rows: Array, mode: int, self_object: String = OBJECT_FALLBACK) -> Array:
	if mode == MODE_FILE_ORDER:
		return []
	var order: PackedStringArray = PackedStringArray()
	var buckets: Dictionary = {}
	for entry: Variant in collect_events(rows):
		var header: String = header_for(entry as Dictionary, mode, self_object)
		if header.is_empty():
			header = OBJECT_FALLBACK
		if not buckets.has(header):
			buckets[header] = []
			order.append(header)
		(buckets[header] as Array).append((entry as Dictionary).get("row"))
	var planned: Array = []
	for header: String in order:
		planned.append({"header": header, "rows": buckets[header]})
	return planned


## The muted note a header wears: how many events read under it, in the sheet's own words.
static func header_subtitle(count: int) -> String:
	return "1 event" if count == 1 else "%d events" % count


## How one arranged event reads in a jump tree: its trigger, and the object it talks about when that
## is not what the tree is already grouped by.
static func event_label(entry: Dictionary, mode: int, self_object: String = OBJECT_FALLBACK) -> String:
	var event: EventRow = entry.get("event") as EventRow
	var trigger: String = trigger_words(event, self_object)
	if mode == MODE_TRIGGER:
		var object_label: String = object_words(event, self_object)
		return "%s %s" % [object_label, trigger] if not object_label.is_empty() else trigger
	return trigger
