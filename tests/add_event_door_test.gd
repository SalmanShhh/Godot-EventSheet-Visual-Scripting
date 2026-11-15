@tool
class_name AddEventDoorTest
extends RefCounted

# Godot EventSheets - the toolbar's Add Event keeps a door to the full list.
#
# Add Event opens on the short object page (the same page a double click on empty canvas opens), and that
# page ends with one plain entry, "Browse every row", that opens the full list with Favourites and Recent
# exactly as the toolbar used to. Picking it needs no typing. Beside it, the live-dock pin that a row
# on the open sheet follows its sentence at once after the sentence is changed.

const SUPPORT := preload("res://tests/support.gd")
const NAME := "add_event_door_test"
const SENTENCE_FIXTURE: String = "res://tests/fixtures/script_rows_ui/sentence_thing.gd"
const SENTENCE_BOX_PATH: String = "res://addons/eventsheet/editor/dock/sentence_box.gd"


static func run() -> bool:
	var ok: bool = _the_door_opens_the_full_list()
	ok = _a_row_follows_its_sentence_at_once() and ok
	return ok


static func _picker_open_on_the_objects(host: Node) -> ACEPickerDialog:
	var registry: EventSheetACERegistry = EventSheetACERegistry.new()
	registry.refresh_from_sources([])
	var picker: ACEPickerDialog = ACEPickerDialog.new()
	picker.init_dialog(host, registry)
	picker.open("new_event", false, null, EventSheetAddRowRequests.ADD_EVENT_CONTEXT)
	picker._fill_after_popup(picker._fill_token)
	return picker


static func _door_item(picker: ACEPickerDialog) -> TreeItem:
	var last: TreeItem = null
	for child: TreeItem in picker._objects_tree.get_root().get_children():
		last = child
	return last


static func _the_door_opens_the_full_list() -> bool:
	var host: Node = Node.new()
	var picker: ACEPickerDialog = _picker_open_on_the_objects(host)
	var door: TreeItem = _door_item(picker)
	var on_objects: bool = picker._objects_page.visible and not picker._body_holder.visible
	var door_text: String = door.get_text(0) if door != null else "<none>"
	# The door is last, after every object and class the page lists.
	door.select(0)
	var rows: Array = [
		["Add Event still opens on the short object page", on_objects, true],
		["its last entry is the door", door_text, "Browse every row"],
		["the door is picked with no typing, and the object page steps aside", picker._objects_page.visible, false],
		["the full list takes its place, with Favourites and Recent beside it", picker._body_holder.visible, true],
		["no object is left chosen", picker._object_filter_provider, ""],
		["nothing was typed", picker._search.text, ""],
		["the list is the whole vocabulary, not one object's", picker._tree.get_root().get_child_count() > 3, true],
		["Favourites and Recent sit in the page that is now showing", [picker._favorites_list != null and _inside(picker._body_holder, picker._favorites_list),
			picker._recent_list != null and _inside(picker._body_holder, picker._recent_list)], [true, true]],
	]
	picker.close()
	host.free()
	return SUPPORT.pins(NAME, rows)


## Whether `node` hangs somewhere under `ancestor`.
static func _inside(ancestor: Node, node: Node) -> bool:
	return ancestor != null and ancestor.is_ancestor_of(node)


## The words the row of `event` says on the canvas, its spans joined.
static func _row_words(dock: EventSheetDock, event: EventRow) -> String:
	for entry: Dictionary in dock.get_viewport_control().get_flat_rows():
		var row: EventRowData = entry.get("row")
		if row == null or row.source_resource != event:
			continue
		var words: PackedStringArray = PackedStringArray()
		for span: EventSheetSemanticSpan in row.spans:
			words.append(span.text)
		return "".join(words)
	return "<no such row>"


## A row of a script of yours on the open sheet reads with the sentence the script gives its function. Once the
## sentence is written again through the box's own door, the dock drops what it kept from the old file and
## reads the rows again, so the open sheet shows the new sentence at once, not after a reopen.
static func _a_row_follows_its_sentence_at_once() -> bool:
	var original: String = FileAccess.get_file_as_string(SENTENCE_FIXTURE)
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	var event: EventRow = EventRow.new()
	event.trigger_id = "OnReady"
	var action: ACEAction = ACEAction.new()
	action.provider_id = "ScriptRowsSentenceThing"
	action.ace_id = "method:take_damage"
	action.params = {"amount": "10"}
	event.actions.append(action)
	sheet.events.append(event)
	var dock: EventSheetDock = EventSheetDock.new()
	dock.setup(sheet)
	# The sheet reads the script, as it does once the script is in use.
	dock.add_ace_provider_script(SENTENCE_FIXTURE)
	dock._viewport.rebuild_rows()
	var before: String = _row_words(dock, event)
	# Another tab's dock is the one the editor's write door tells about, so this dock hears nothing from it.
	var other: EventSheetDock = EventSheetDock.new()
	other.setup(EventSheetResource.new())
	var edits: Array = [{"source_kind": "method", "member": "take_damage", "display_template": "Hit for {amount}"}]
	var result: Dictionary = EventSheets.curate_provider(SENTENCE_FIXTURE, edits)
	var box: GDScript = load(SENTENCE_BOX_PATH)
	box.refresh_after_write(dock)
	var after: String = _row_words(dock, event)
	# The fixture goes back exactly as it was, and the backup the write made goes with the probe.
	var handle: FileAccess = FileAccess.open(SENTENCE_FIXTURE, FileAccess.WRITE)
	handle.store_string(original)
	handle.close()
	var backup: String = str(result.get("backup", ""))
	if not backup.is_empty() and FileAccess.file_exists(backup):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(backup))
	other.free()
	dock.free()
	return SUPPORT.pins(NAME, [
		["the write went through", str(result.get("ok", "")), "true"],
		["the row first reads with the sentence the script gave", before.contains("Take 10 damage"), true],
		["and after the sentence is written again it reads the new one at once", after.contains("Hit for 10"), true],
		["and no longer the old one", after.contains("Take 10 damage"), false],
		["the fixture is back as it was", FileAccess.get_file_as_string(SENTENCE_FIXTURE), original],
	])
