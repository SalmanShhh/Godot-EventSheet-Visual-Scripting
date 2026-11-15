@tool
class_name ScriptRowsFault9Test
extends RefCounted

# Godot EventSheets - a row from a script of yours reads the same in the picker, the parameters window
# and the canvas, belongs to your class in the parameters window, and is offered by the toolbar's Add
# Event as well as by the object cards.
#
# The script writes a sentence ("Take {amount} damage") and no name. The canvas says the sentence; the
# picker and the parameters window said the name made from the function ("Take Damage"), the window's
# head said "System" because it named the open sheet's object instead of the row's, and the classic
# tree the toolbar opens never listed the class's rows at all.

const SUPPORT := preload("res://tests/support.gd")
const READER := preload("res://addons/eventsheet/ace/script_reader.gd")
const FIXTURE: String = "res://tests/fixtures/script_rows_ui/sentence_thing.gd"
const CLASS_TEXT: String = "ScriptRowsSentenceThing"


static func run() -> bool:
	var ok: bool = _picker_says_the_sentence()
	ok = _window_says_the_sentence() and ok
	ok = _window_head_names_the_class() and ok
	ok = _toolbar_add_event_lists_the_class() and ok
	return ok


static func _take_damage() -> ACEDefinition:
	for definition: ACEDefinition in READER.definitions_for(CLASS_TEXT, load(FIXTURE) as Script, ""):
		if definition.id == "method:take_damage":
			return definition
	return null


## Fault 9 (a), the picker half: the row's words in the list are the script's sentence, its slots shown
## as gaps until the row is placed. Packs keep their names (they are not read through this door).
static func _picker_says_the_sentence() -> bool:
	var definition: ACEDefinition = _take_damage()
	var picker: ACEPickerDialog = ACEPickerDialog.new()
	var label: String = picker._item_label(definition) if definition != null else "<not read>"
	return SUPPORT.pins("script_rows_fault9_test", [
		["the script wrote a sentence and no name", [definition.metadata["authored"]["sentence"], definition.metadata["authored"]["name"]], [true, false]],
		["the picker row reads as the sentence", label.get_slice("  ·  ", 0), "Take … damage"],
	])


## Fault 9 (a), the window half: the parameters window's title says the same words.
static func _window_says_the_sentence() -> bool:
	var definition: ACEDefinition = _take_damage()
	return SUPPORT.pins("script_rows_fault9_test", [
		["the window title reads as the sentence", ACEParamsDialog.window_title(definition, CLASS_TEXT),
			"Parameters for ScriptRowsSentenceThing: Take … damage"],
	])


## Fault 9 (b): the head names the class the row belongs to, not the open sheet's object ("System").
static func _window_head_names_the_class() -> bool:
	var dialog: ACEParamsDialog = ACEParamsDialog.new()
	dialog._definition = _take_damage()
	dialog._row_owner = "System"
	var pack_row: ACEDefinition = ACEDefinition.new()
	pack_row.provider_id = "Core"
	pack_row.id = "Print"
	var core_dialog: ACEParamsDialog = ACEParamsDialog.new()
	core_dialog._definition = pack_row
	core_dialog._row_owner = "Player"
	return SUPPORT.pins("script_rows_fault9_test", [
		["a row of your class names your class", dialog._object_name(), CLASS_TEXT],
		["a built-in row still names the sheet's object", core_dialog._object_name(), "Player"],
	])


## Fault 9 (c): the toolbar's Add Event opens on the objects, like a double click on empty canvas, so the
## project's own class is a card there; picking the card lists its condition, browsed and typed.
static func _toolbar_add_event_lists_the_class() -> bool:
	EventSheetProjectScanner.reset_for_tests()
	var listed: bool = EventSheetProjectScanner.list_project_classes().any(func(entry: Dictionary) -> bool:
		return str(entry.get("name", "")) == CLASS_TEXT)
	var registry: EventSheetACERegistry = EventSheetACERegistry.new()
	registry.refresh_from_sources([])
	var host: Node = Node.new()
	var picker: ACEPickerDialog = ACEPickerDialog.new()
	picker.init_dialog(host, registry)
	picker.open("new_event", false, null, EventSheetAddRowRequests.ADD_EVENT_CONTEXT)
	picker._fill_after_popup(picker._fill_token)
	var has_card: bool = _card_named(picker._objects_tree.get_root(), CLASS_TEXT)
	picker.close()
	picker.open("new_event", false, null, {"object_scope": CLASS_TEXT})
	picker._fill_after_popup(picker._fill_token)
	var browsed: bool = _tree_offers(picker._tree.get_root(), "method:alive")
	picker._search.text = "alive"
	picker._refresh_tree()
	var typed: bool = _tree_offers(picker._tree.get_root(), "method:alive")
	picker.close()
	host.free()
	return SUPPORT.pins("script_rows_fault9_test", [
		["the toolbar asks for the objects first", EventSheetAddRowRequests.ADD_EVENT_CONTEXT, {"object_first": true}],
		["the class is one of the project's own", listed, true],
		["it is a card on the objects page", has_card, true],
		["its card lists the condition", browsed, true],
		["and typing its name finds it", typed, true],
	])


static func _card_named(item: TreeItem, card_name: String) -> bool:
	if item == null:
		return false
	if str(item.get_metadata(0)) == card_name or item.get_text(0) == card_name:
		return true
	for child: TreeItem in item.get_children():
		if _card_named(child, card_name):
			return true
	return false


static func _tree_offers(item: TreeItem, ace_id: String) -> bool:
	if item == null:
		return false
	var definition: ACEDefinition = item.get_metadata(0) as ACEDefinition if item.get_metadata(0) is ACEDefinition else null
	if definition != null and definition.provider_id == CLASS_TEXT and definition.id == ace_id:
		return true
	for child: TreeItem in item.get_children():
		if _tree_offers(child, ace_id):
			return true
	return false
