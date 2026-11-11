# Godot EventSheets - a picked instance is an object the rows under its pick act on.
#
# Inside a pick (a For each, a pop or a pick row, a typed local, a signal that hands the event its instance)
# and every sub-event under it, Add action and Add condition list the picked instance by its TYPE beside
# the scene's nodes, with its class's rows and those of what the class is a kind of, and the rows read as
# that object's: "PickUnit | health < 20". Outside the pick nothing is offered. The code stays ordinary
# loops and locals; the sheet only reads the scope.
@tool
class_name PickInstanceOfferTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const NAME := "pick_instance_offer"

## The board example: one event picks the units in `selected`; a sub-event narrows them, its else picks one
## more object beside them, and the next event starts with nothing picked.
const BOARD := """extends Node

var selected: Array[PickUnit] = []
var targets: Array[PickEnemy] = []
var turn_order: Array[PickUnit] = []


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("attack"):
		for unit: PickUnit in selected:
			unit.start_turn()
			if unit.health < 20:
				unit.retreat()
			else:
				var enemy: PickEnemy = targets.pick_random()
				unit.start_turn()
				enemy.flash(0.1)
	if event.is_action_pressed("cancel"):
		selected.clear()


func _ready() -> void:
	if not turn_order.is_empty():
		var unit: PickUnit = turn_order.pop_front()
		unit.start_turn()
		unit.modulate = Color.YELLOW
		turn_order.append(unit)
"""


class Host extends Node:
	var sheet: EventSheetResource = null


	func get_current_sheet() -> EventSheetResource:
		return sheet


static func _events(items: Array, found: Array[EventRow]) -> void:
	for item: Variant in items:
		if item is EventRow:
			found.append(item as EventRow)
			_events((item as EventRow).sub_events, found)
		elif item is EventFunction:
			_events((item as EventFunction).events, found)
		elif item is EventGroup:
			_events(EventSheetGroupFacts.children(item as EventGroup), found)


static func _all_events(sheet: EventSheetResource) -> Array[EventRow]:
	var found: Array[EventRow] = []
	_events(sheet.events, found)
	_events(sheet.functions, found)
	return found


static func _has_action(event_row: EventRow, ace_id: String) -> bool:
	return event_row.actions.any(func(entry: Variant) -> bool: return entry is ACEAction and (entry as ACEAction).ace_id == ace_id)


static func _words(sheet: EventSheetResource, event_row: EventRow) -> Array:
	return EventSheetPickScope.offered_objects(sheet, event_row).map(func(entry: Dictionary) -> String: return str(entry["word"]))


## [[kind, object column, text, wrapped]] of every condition, loop and action cell the sheet draws.
static func _cells(sheet: EventSheetResource, width: float = 1200.0) -> Array:
	var view: EventSheetViewport = EventSheetViewport.new()
	view.set_ace_registry(EventSheetACERegistry.new())
	view.size = Vector2(width, 900.0)
	view.set_sheet(sheet)
	var cells: Array = []
	var flat: Array[Dictionary] = view.get_flat_rows()
	for index: int in flat.size():
		var row_data: EventRowData = flat[index].get("row")
		if row_data == null or not (row_data.source_resource is EventRow):
			continue
		view._layout_builder.get_or_build_row_layout(index, view.get_canvas_logical_width(), view._get_font(), view._get_font_size())
		for span: SemanticSpan in view._row_at(index).spans:
			if span.metadata is Dictionary and str(span.metadata.get("kind", "")) in ["condition", "action", "pick_filter"]:
				var wrapped: bool = bool(span.metadata.get("comment_wrap", false)) \
					or not (span.metadata.get("segment_wrap_breaks", PackedInt32Array()) as PackedInt32Array).is_empty()
				cells.append([str(span.metadata.get("kind", "")), str(span.metadata.get("object_label", "")), span.text, wrapped])
	view.free()
	return cells


static func _picker_cards(sheet: EventSheetResource, target: Resource) -> Array:
	var picker: ACEPickerDialog = ACEPickerDialog.new()
	var host: Host = Host.new()
	host.sheet = sheet
	picker._host_node = host
	picker._objects_tree = Tree.new()
	picker._context = {"selected_resource": target}
	var root: TreeItem = picker._objects_tree.create_item()
	picker._populate_picked_cards(root)
	var cards: Array = root.get_children().map(func(item: TreeItem) -> Array: return [item.get_text(0), str(item.get_metadata(0))])
	picker._objects_tree.free()
	host.free()
	return cards


static func run() -> bool:
	var sheet: EventSheetResource = SUPPORT.reopen(BOARD, true, "")
	sheet.external_source_path = "user://pick_instance_offer.gd"
	var events: Array[EventRow] = _all_events(sheet)
	var looped: EventRow = events.filter(func(entry: EventRow) -> bool: return not entry.pick_filters.is_empty())[0]
	var narrowing: EventRow = looped.sub_events[0] as EventRow
	var otherwise: EventRow = narrowing
	for entry: EventRow in events:
		if _has_action(entry, "SetLocalVarTyped"):
			otherwise = entry
	var cancel: EventRow = events.filter(func(entry: EventRow) -> bool: return _has_action(entry, "DictClear"))[0]
	var popping: EventRow = events.filter(func(entry: EventRow) -> bool: return _has_action(entry, "ArrayPopFrontInto"))[0]

	# Two picks of one type are listed by the names as written.
	var twice: EventSheetResource = EventSheetResource.new()
	twice.variables = {"selected": {"type": "Array[PickUnit]", "default": [], "exported": false}}
	var both: EventRow = EventRow.new()
	for item: String in ["attacker", "target"]:
		var pick: PickFilter = PickFilter.new()
		pick.iterator_name = item
		pick.collection_kind = PickFilter.CollectionKind.ARRAY
		pick.collection_value = "selected"
		both.pick_filters.append(pick)
	twice.events.append(both)

	# The ways to pick, and what a trigger hands over.
	var kinds: EventSheetResource = EventSheetResource.new()
	kinds.variables = {"targets": {"type": "Array[PickEnemy]", "default": [], "exported": false}}
	var making: EventRow = EventRow.new()
	for ace_id: String in ["ArrayPopBackInto", "PickNearest", "PickFirstWhere", "PickRandomInstance"]:
		var action: ACEAction = ACEAction.new()
		action.provider_id = "Core"
		action.ace_id = ace_id
		action.params = {"name": "got_" + ace_id.to_snake_case(), "var_name": "targets", "list": "targets"}
		making.actions.append(action)
	kinds.events.append(making)
	var carried: EventRow = EventRow.new()
	carried.trigger_args = "unit: PickUnit, amount: int"
	carried.trigger_source_path = "Enemy"
	kinds.events.append(carried)

	var picker: ACEPickerDialog = ACEPickerDialog.new()
	var host: Host = Host.new()
	host.sheet = sheet
	picker._host_node = host
	picker._registry = EventSheetACERegistry.new()
	picker._registry.refresh_from_sources([])
	picker._unique_scope = {"name": "unit", "class": "PickUnit", "plain": true}
	var own_rows: Array = picker._unique_scope_definitions().map(func(entry: ACEDefinition) -> String: return entry.display_name)
	var base_rows: Array[ACEDefinition] = picker._picked_base_definitions()
	var tint: Array = base_rows.filter(func(entry: ACEDefinition) -> bool: return entry.display_name == "Set Color Tint")
	var tint_target: Variant = ""
	if not tint.is_empty():
		for parameter: Variant in (tint[0] as ACEDefinition).parameters:
			if parameter is Dictionary and str((parameter as Dictionary).get("id", "")) == "target":
				tint_target = (parameter as Dictionary).get("default_value")
	var ancestry: PackedStringArray = ACEPickerDialog.class_ancestry("PickUnit")
	host.free()

	var cells: Array = _cells(sheet)
	var narrow_cells: Array = _cells(sheet, 300.0).filter(func(entry: Array) -> bool: return entry[0] == "pick_filter")
	var renderer: String = FileAccess.get_file_as_string("res://addons/eventsheet/editor/event_row_renderer.gd")

	return SUPPORT.pins(NAME, [
		["the board example opens and re-emits byte for byte", SUPPORT.reemit(BOARD, "user://pick_instance_offer_out.gd").contains("unit.start_turn()"), true],
		# What is offered where.
		["the event that picks offers its unit by type", _words(sheet, looped), ["PickUnit"]],
		["the sub-event that narrows has it too", _words(sheet, narrowing), ["PickUnit"]],
		["the sub-event that picks another type keeps the outer one and adds its own", _words(sheet, otherwise), ["PickUnit", "PickEnemy"]],
		["the next event, not under the pick, offers nothing", _words(sheet, cancel), []],
		["a pop names the unit it took", _words(sheet, popping), ["PickUnit"]],
		["two picks of one type are listed by their names as written", _words(twice, both), ["attacker", "target"]],
		["the picker's card is the type, scoped to the name as written", _picker_cards(sheet, looped), [["PickUnit", "narrow:unit|PickUnit"]]],
		["a sub-event's picker has it as well", _picker_cards(sheet, narrowing), [["PickUnit", "narrow:unit|PickUnit"]]],
		["outside the pick the picker has no such card", _picker_cards(sheet, cancel), []],
		# What the card offers.
		["the class's own rows are offered", [own_rows.has("Start Turn"), own_rows.has("Retreat")], [true, true]],
		["and the rows of what it is a kind of, aimed at the picked name", [base_rows.size() > 20, tint_target], [true, "unit"]],
		["the class reads up through its bases", [ancestry.has("PickUnit"), ancestry.has("Node2D"), ancestry.has("Node")], [true, true, true]],
		# All the ways to pick, and what a trigger hands over.
		["a pop, a nearest, a first-where and a random pick all name their instance",
			EventSheetPickScope.own_picks(kinds, making).map(func(entry: Dictionary) -> String: return "%s:%s" % [entry["name"], entry["type"]]),
			["got_array_pop_back_into:PickEnemy", "got_pick_nearest:PickEnemy", "got_pick_first_where:PickEnemy", "got_pick_random_instance:PickEnemy"]],
		["a signal that carries the instance offers it as an instance, not the number beside it",
			EventSheetPickScope.carried_instances(carried), [{"name": "unit", "type": "PickUnit"}]],
		["and as a value for Push back and Contains, with the node a trigger is aimed at",
			EventSheetPickScope.values_offered(kinds, carried).map(func(entry: Dictionary) -> String: return str(entry["name"])), ["unit", "$Enemy"]],
		# Reading.
		["the unit's own rows read under its type",
			cells.filter(func(entry: Array) -> bool: return entry[1] == "PickUnit").map(func(entry: Array) -> String: return entry[2]).slice(0, 4),
			["Start turn", "health < 20", "Retreat", "Start turn"]],
		["a test of its member reads as the object's",
			cells.filter(func(entry: Array) -> bool: return entry[0] == "condition" and entry[1] == "PickUnit").map(func(entry: Array) -> String: return entry[2]),
			["health < 20"]],
		["the enemy picked beside it reads under its own type", cells.filter(func(entry: Array) -> bool: return entry[1] == "PickEnemy").size() >= 1, true],
		# Looks.
		["a loop's cell wraps like any other long condition", narrow_cells.map(func(entry: Array) -> bool: return entry[3]), [true]],
		["a finding draws no frame round its event, only a tint and the amber number",
			[renderer.contains("draw_rect(row_fill_rect.grow(-1.0)"), renderer.contains("_gutter_attention_ink")], [false, true]],
	])
