@tool
class_name PickerWindowsTest
extends RefCounted
# Godot EventSheets - the three picking windows say what the pick answers. Add Action / Condition
# names the object in its title and bands the event the pick lands on; its one help strip says what
# the highlighted verb is, the line it ships as, and the other engine's word a search found it by
# (on its own ALSO CALLED line, no longer on the row's tail). The parameters window's Expressions
# panel bands the field it inserts into; Pick Node names the field it answers in the title and the
# band, and says the rest in a strip.


const SUPPORT := preload("res://tests/support.gd")
const NAME := "picker_windows_test"


static func run() -> bool:
	var ok: bool = true
	ok = _the_title_names_the_object() and ok
	ok = _the_band_reads_the_event() and ok
	ok = _the_strip_describes_the_verb() and ok
	ok = _the_dock_opens_on_the_event() and ok
	ok = _the_field_pickers_name_their_field() and ok
	return ok


static func _the_title_names_the_object() -> bool:
	return SUPPORT.pins(NAME, [
		["an action names the object", ACEPickerDialog.title_naming_object("append_action", "Add Action", "Player"),
			"Add an action to Player"],
		["so does a condition", ACEPickerDialog.title_naming_object("append_condition", "Add Condition", "Player"),
			"Add a condition to Player"],
		["a sheet with no object keeps the plain title",
			ACEPickerDialog.title_naming_object("append_action", "Add Action", ""), "Add Action"],
		["a new event is not added to an object", ACEPickerDialog.title_naming_object("new_event", "Add Event", "Player"),
			"Add Event"],
	])


static func _the_band_reads_the_event() -> bool:
	var row: EventRowData = EventRowData.new()
	row.spans.append(_span("Condition", SemanticSpan.SpanType.KEYWORD, {"lane": "condition", "badge": true}))
	row.spans.append(_span("Is on floor", SemanticSpan.SpanType.CONDITION, {"lane": "condition", "object_label": "Player"}))
	row.spans.append(_span("Is moving", SemanticSpan.SpanType.CONDITION, {"lane": "condition", "object_label": "Player"}))
	row.spans.append(_span("Every tick", SemanticSpan.SpanType.CONDITION, {"lane": "condition", "object_label": "System"}))
	row.spans.append(_span("+ Add condition", SemanticSpan.SpanType.CONDITION, {"lane": "condition", "kind": "add_condition"}))
	row.spans.append(_span("Jump", SemanticSpan.SpanType.ACTION, {"lane": "action", "object_label": "Player"}))
	return SUPPORT.pins(NAME, [
		["the conditions, each object said once, no badge, no add target, no action",
			ACEPickerDialog.landing_reading(row), "Player Is on floor - Is moving - System Every tick"],
		["no row, no band", ACEPickerDialog.landing_reading(null), ""],
	])


static func _the_strip_describes_the_verb() -> bool:
	var parent: Node = Node.new()
	var registry: EventSheetACERegistry = EventSheetACERegistry.new()
	registry.refresh_from_sources([], true)
	var picker: ACEPickerDialog = ACEPickerDialog.new()
	picker.init_dialog(parent, registry)
	picker._context = {"mode": "append_action", "signals_only": false, "selected_resource": null}
	picker._search.text = "WaitForSeconds"
	picker._refresh_tree()
	picker._select_first_match()
	var wait: ACEDefinition = picker._selected_definition
	var row: TreeItem = picker._find_definition_item("Core", "Wait")
	var rows: Array = [
		["typing the other engine's word lands on Wait", str(wait.id) if wait != null else "", "Wait"],
		["the row no longer carries the other name", row.get_text(0).contains("WaitForSeconds") if row != null else true, false],
		["the heading names the verb, its kind and category", picker._help_strip.heading_label.text, "WAIT · ACTION · TIME"],
		["the IN CODE line is what it ships as", picker._help_strip.in_code_value.text,
			str(wait.metadata.get("codegen_template", "")) if wait != null else ""],
		["the other name has its own line", picker._also_called.text,
			"You may know it as WaitForSeconds from another engine - the word you typed and this verb are one row."],
		["and it shows", picker._also_called.get_parent().visible, true],
		["the rest of the strip is the old description", picker._help_strip.body_label.text.begins_with(
			EventSheetL10n.translate(wait.description) if wait != null else "-"), true],
	]
	picker._update_info_panel(null)
	rows.append(["nothing highlighted says what the window is for", picker._help_strip.body_label.text,
		"Select an action to append to the selected event."])
	rows.append(["and drops the other name", picker._also_called.get_parent().visible, false])
	rows.append(["the Add button keeps its word", picker._window.get_ok_button().text, "Add"])
	parent.free()
	return SUPPORT.pins(NAME, rows)


static func _the_dock_opens_on_the_event() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.custom_class_name = "Player"
	sheet.host_class = "CharacterBody2D"
	var event: EventRow = EventRow.new()
	var condition: ACECondition = ACECondition.new()
	condition.ace_id = "IsOnFloor"
	event.conditions.append(condition)
	sheet.events.append(event)
	var dock: EventSheetDock = EventSheetDock.new()
	dock.setup(sheet)
	var event_row: EventRowData = null
	for entry: Dictionary in dock.get_viewport_control().get_flat_rows():
		var candidate: EventRowData = entry.get("row")
		if candidate != null and candidate.source_resource is EventRow:
			event_row = candidate
			break
	dock._ace_apply._on_viewport_ace_picker_requested(event_row, "action")
	var picker: ACEPickerDialog = dock._ace_picker
	var rows: Array = [
		["the title names the object", picker._window.title, "Add an action to Player"],
		# The band leads as the line does on the sheet: the object in its column, then the words.
		["the band reads the event, its object in the object column", [picker._band.object_label.text,
			picker._band.words_label.text], ["Player", "Is on floor"]],
		["and says where the pick goes", picker._band.note_label.text, "the action you pick lands here"],
		["it shows", picker._band.visible, true],
	]
	dock.free()
	return SUPPORT.pins(NAME, rows)


static func _the_field_pickers_name_their_field() -> bool:
	var host: Node = Node.new()
	var dialog: ACEParamsDialog = ACEParamsDialog.new()
	dialog.init_dialog(host)
	var definition: ACEDefinition = ACEDefinition.new()
	definition.display_name = "Move Toward"
	dialog._definition = definition
	dialog._param_dicts["speed"] = {"id": "speed", "display_name": "Speed"}
	dialog._param_dicts["target"] = {"id": "target", "display_name": "Target"}
	var speed: LineEdit = LineEdit.new()
	speed.text = "base_speed * "
	speed.caret_column = speed.text.length()
	dialog._fields["speed"] = speed
	var target: LineEdit = LineEdit.new()
	target.text = "$Enemy"
	dialog._fields["target"] = target
	var expressions: ACEParamsExpressionPicker = dialog._expression_picker
	expressions._expression_target_key = "speed"
	expressions._say_field()
	var nodes: ACEParamsNodePicker = dialog._node_picker
	nodes._ensure_node_picker_ui()
	nodes._say_field("target")
	var root: Node2D = Node2D.new()
	var enemies: Node2D = Node2D.new()
	enemies.name = "Enemies"
	root.add_child(enemies)
	var enemy: CharacterBody2D = CharacterBody2D.new()
	enemy.name = "Enemy1"
	enemies.add_child(enemy)
	nodes._populate_node_picker_from_root(root)
	var enemy_item: TreeItem = null
	for item: TreeItem in nodes._node_picker_tree.get_root().get_children():
		if item.get_text(0) == "Enemies/Enemy1":
			enemy_item = item
	if enemy_item != null:
		enemy_item.select(0)
	nodes._on_node_picker_selection_changed()
	var rows: Array = [
		["the Expressions panel's band names the verb and the field", expressions._band.object_label.text, "Move Toward Speed"],
		["and what the field holds", expressions._band.words_label.text, "base_speed * "],
		["Pick Node's title names the field", nodes._node_picker_window.title, "Pick a node for Target"],
		["its band names the verb and the field", nodes._band.object_label.text, "Move Toward Target"],
		["and what the field holds", nodes._band.words_label.text, "$Enemy"],
		["a highlighted node says what it is", nodes._help_strip.body_label.text, "A CharacterBody2D."],
		["and the reference it goes in as", nodes._help_strip.in_code_value.text, "$\"Enemies/Enemy1\""],
	]
	# The panel keeps its band in step with the field as results chain into it.
	expressions._insert_into_expression_target("base_speed")
	rows.append(["an insert refreshes the band", expressions._band.words_label.text, "base_speed * base_speed"])
	root.free()
	speed.free()
	target.free()
	host.free()
	return SUPPORT.pins(NAME, rows)


static func _span(text: String, type: SemanticSpan.SpanType, metadata: Dictionary) -> SemanticSpan:
	var span: SemanticSpan = SemanticSpan.new()
	span.text = text
	span.type = type
	span.metadata = metadata
	return span
