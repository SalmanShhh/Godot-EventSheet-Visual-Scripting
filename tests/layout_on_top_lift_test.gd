# Godot EventSheets - a layout ON TOP of the running game: the vocabulary, and the run it lifts from.
#
# Three rows are under test, and the thing they are all about is that a menu is not a level: Go To
# Layout replaces what is running, and these leave it running underneath. The rows say so in the
# words the sheet already uses for a scene the player travels to ("layout"), and the code they emit
# is the code a person writes by hand for the same job.
#
# What is pinned here, in the order the failures actually happen:
#   1. THE VOCABULARY. Ids, category, templates, display text, and that every row and every
#      parameter carries real help - values, never counts.
#   2. THE RUN LIFTS. The three statements a layout-on-top has always been written as read back as
#      one row, in both the `=`/`load` and the `:=`/`preload` spelling, with the author's own
#      spelling baked onto the row - which is what re-emits the file byte for byte.
#   3. THE BOUNDARY IN BOTH DIRECTIONS. The bare one-liner still reads as Spawn Scene Instance, and
#      the same three statements ending in a plain `add_child` are NOT claimed - a copy added under
#      this node dies with this node, which is right for an enemy and wrong for a menu.
#   4. BYTE-EXACT ROUND TRIP of the whole fixture, which is the contract everything above rides on.
#   5. WHAT THE SHEET AUTHORS. A sheet that picked these rows compiles to the canonical lines with
#      the row's own id baked into the local, and that output parses.
@tool
class_name LayoutOnTopLiftTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const FIXTURE_DIR: String = "res://tests/fixtures/"
const FIXTURE: String = "layout_on_top_pause_menu.gd"

## Every ace_id this vocabulary adds. Checked against the WHOLE registry, because an id is a
## compatibility promise the moment it ships and two descriptors answering to one id is a silent
## coin toss over which template a row compiles through.
const NEW_ACE_IDS: Array[String] = ["AddLayoutOnTop", "RemoveLayoutOnTop", "LayoutIsOnTop"]


static func run() -> bool:
	var ok: bool = true
	ok = _test_descriptors() and ok
	ok = _test_run_lifts() and ok
	ok = _test_boundary() and ok
	ok = _test_roundtrip() and ok
	ok = _test_authored_emission() and ok
	return ok


# ── the vocabulary ──────────────────────────────────────────────────────────────


static func _test_descriptors() -> bool:
	var ok: bool = true
	var counts: Dictionary = {}
	var missing_help: PackedStringArray = PackedStringArray()
	for descriptor: ACEDescriptor in ACERegistry.get_all_descriptors():
		if not NEW_ACE_IDS.has(descriptor.ace_id):
			continue
		counts[descriptor.ace_id] = int(counts.get(descriptor.ace_id, 0)) + 1
		if descriptor.description.strip_edges().is_empty():
			missing_help.append(descriptor.ace_id)
		for param: ACEParam in descriptor.params:
			if str(param.description).strip_edges().is_empty():
				missing_help.append("%s.%s" % [descriptor.ace_id, param.id])
	var absent: PackedStringArray = PackedStringArray()
	var duplicated: PackedStringArray = PackedStringArray()
	for ace_id: String in NEW_ACE_IDS:
		var seen: int = int(counts.get(ace_id, 0))
		if seen == 0:
			absent.append(ace_id)
		elif seen > 1:
			duplicated.append(ace_id)
	ok = _check("every new id is registered", absent, PackedStringArray()) and ok
	ok = _check("no new id collides with an existing one", duplicated, PackedStringArray()) and ok
	ok = _check("every new row and parameter carries real help", missing_help, PackedStringArray()) and ok

	var adding: ACEDescriptor = ACERegistry.find_descriptor("Core", "AddLayoutOnTop")
	# THE NAME IS THE PROMISE. `add_child` renames a newcomer whose name a sibling already has, so a
	# second add under one name used to leave a copy that neither of the rows below could ever find
	# again - under the tree root, where it outlives every change of layout. The add asks first.
	ok = _check("adding asks the name first and builds nothing when it is taken",
		adding.codegen_template,
		"var __layout_{uid}: Node = get_tree().root.get_node_or_null({layout_name})\n"
		+ "if __layout_{uid} == null:\n"
		+ "\t__layout_{uid} = (load({path}) as PackedScene).instantiate()\n"
		+ "\t__layout_{uid}.name = {layout_name}\n"
		+ "\tget_tree().root.add_child(__layout_{uid})") and ok
	ok = _check("and reads as a sentence", adding.get_display_text(),
		"Add layout {path} on top as {layout_name}") and ok
	ok = _check("filed with the layout rows it belongs beside", adding.category, "Scene") and ok
	ok = _check("its layout field completes with the project's scenes",
		adding.params[0].hint, "scene_path") and ok

	var removing: ACEDescriptor = ACERegistry.find_descriptor("Core", "RemoveLayoutOnTop")
	# And the removal takes it OFF THE TREE at once: a node only queued for freeing is still a child
	# for the rest of the frame, so the familiar close-then-open pair would find the dying one.
	ok = _check("removing looks the name up, takes it off the tree, then frees it",
		removing.codegen_template,
		"var __layout_{uid}: Node = get_tree().root.get_node_or_null({layout_name})\n"
		+ "if __layout_{uid} != null:\n"
		+ "\tget_tree().root.remove_child(__layout_{uid})\n"
		+ "\t__layout_{uid}.queue_free()") and ok
	ok = _check("and reads as a sentence", removing.get_display_text(),
		"Remove layout {layout_name} from on top") and ok

	var asking: ACEDescriptor = ACERegistry.find_descriptor("Core", "LayoutIsOnTop")
	ok = _check("the question is the same lookup, null-safe", asking.codegen_template,
		"get_tree().root.get_node_or_null({layout_name}) != null") and ok
	ok = _check("and is a condition", asking.ace_type, ACEDescriptor.ACEType.CONDITION) and ok
	ok = _check("the three rows agree on the name of the field they share",
		PackedStringArray([adding.params[1].id, removing.params[0].id, asking.params[0].id]),
		PackedStringArray(["layout_name", "layout_name", "layout_name"])) and ok

	# The row that keeps its own reading. Pinned here so a future pass cannot quietly redirect the
	# bare spelling to the new row: an enemy added under the node that spawned it is not a menu.
	ok = _check("Spawn Scene Instance still adds under this node", ACERegistry.find_descriptor(
		"Core", "SpawnScene").codegen_template, "add_child(load({path}).instantiate())") and ok
	return ok


# ── the run ─────────────────────────────────────────────────────────────────────


static func _test_run_lifts() -> bool:
	var sheet: EventSheetResource = _open(FIXTURE)
	var ok: bool = true
	var opening: ACEAction = _function_action(sheet, "open_pause_menu", 0)
	ok = _check("the three lines a pause menu is read as one row", _row_of(opening),
		"AddLayoutOnTop") and ok
	ok = _check("with the layout and the name the file wrote", _params_of(opening),
		{"path": "\"res://pause_menu.tscn\"", "layout_name": "\"PauseMenu\""}) and ok
	ok = _check("and the author's own spelling baked on", _template_of(opening),
		"var menu = load({path}).instantiate()\nmenu.name = {layout_name}\nget_tree().root.add_child(menu)") and ok
	ok = _check("the line under it is the pause it pairs with",
		_row_of(_function_action(sheet, "open_pause_menu", 1)), "PauseGame") and ok

	var inventory: ACEAction = _function_action(sheet, "open_inventory", 0)
	ok = _check("the walrus-and-preload spelling is the same row", _row_of(inventory),
		"AddLayoutOnTop") and ok
	ok = _check("with its own values", _params_of(inventory),
		{"path": "\"res://inventory.tscn\"", "layout_name": "\"Inventory\""}) and ok
	ok = _check("and its own spelling baked on, preload and all", _template_of(inventory),
		"var panel := preload({path}).instantiate()\npanel.name = {layout_name}\nget_tree().root.add_child(panel)") and ok
	return ok


static func _test_boundary() -> bool:
	var sheet: EventSheetResource = _open(FIXTURE)
	var ok: bool = true
	ok = _check("the bare one-liner keeps the reading it has always had",
		_function_row_ids(sheet, "spawn_enemy"), PackedStringArray(["SpawnScene"])) and ok
	ok = _check("the same three statements onto THIS node are not claimed",
		_function_row_ids(sheet, "add_hud").has("AddLayoutOnTop"), false) and ok
	ok = _check("closing the menu is still the pause row it is",
		_function_row_ids(sheet, "close_pause_menu"), PackedStringArray(["UnpauseGame"])) and ok
	return ok


static func _test_roundtrip() -> bool:
	var sheet: EventSheetResource = _open(FIXTURE)
	sheet.external_source_path = "user://_layout_on_top_roundtrip.gd"
	var output: String = str(SheetCompiler.compile(sheet, sheet.external_source_path).get("output", ""))
	return _check("%s comes back byte for byte" % FIXTURE, output, _source(FIXTURE))


# ── what the sheet authors ──────────────────────────────────────────────────────


static func _test_authored_emission() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnReady"
	event.actions.append(_authored_action("AddLayoutOnTop",
		{"path": "\"res://pause_menu.tscn\"", "layout_name": "\"PauseMenu\""}, "a1"))
	event.actions.append(_authored_action("RemoveLayoutOnTop", {"layout_name": "\"PauseMenu\""}, "b2"))
	sheet.events.append(event)
	sheet.external_source_path = "user://_layout_on_top_authored.gd"
	var output: String = str(SheetCompiler.compile(sheet, sheet.external_source_path).get("output", ""))
	var ok: bool = _check("the picked add writes the canonical lines",
		output.contains("\tvar __layout_a1: Node = get_tree().root.get_node_or_null(\"PauseMenu\")\n\tif __layout_a1 == null:\n\t\t__layout_a1 = (load(\"res://pause_menu.tscn\") as PackedScene).instantiate()\n\t\t__layout_a1.name = \"PauseMenu\"\n\t\tget_tree().root.add_child(__layout_a1)"), true)
	ok = _check("the picked removal writes its guard",
		output.contains("\tvar __layout_b2: Node = get_tree().root.get_node_or_null(\"PauseMenu\")\n\tif __layout_b2 != null:\n\t\tget_tree().root.remove_child(__layout_b2)\n\t\t__layout_b2.queue_free()"), true) and ok
	# And what the ADD wrote opens again as the row that wrote it, which is the other half of the
	# promise the three hand-written statements already keep. The removal is deliberately not
	# claimed - it is an `if` block, and an `if` block already has a reading of its own.
	var reopened: EventSheetResource = GDScriptImporter.new().import_external_source(
		output, true, sheet.external_source_path)
	ok = _check("and the file it wrote re-opens with the add as the row that wrote it",
		_event_row_ids(reopened)[0] if not _event_row_ids(reopened).is_empty() else "(nothing)",
		"AddLayoutOnTop") and ok
	ok = _check("with the file and the name it was given still on it",
		_event_row_params(reopened),
		{"path": "\"res://pause_menu.tscn\"", "layout_name": "\"PauseMenu\""}) and ok
	# Compiled inside the host these rows are for. A sheet with no source file of its own emits the
	# body alone, and a body calling get_tree() would not parse under GDScript's implicit RefCounted
	# base - which would say nothing about the lines under test, so the base is stated here.
	var compiled := GDScript.new()
	compiled.source_code = "extends Node\n%s" % output
	ok = _check("and what it wrote parses inside a Node", compiled.reload(), OK) and ok
	return ok


# ── helpers ─────────────────────────────────────────────────────────────────────


static func _source(file_name: String) -> String:
	return FileAccess.get_file_as_string(FIXTURE_DIR + file_name)


static func _open(file_name: String) -> EventSheetResource:
	var path: String = FIXTURE_DIR + file_name
	return GDScriptImporter.new().import_external_source(_source(file_name), true, path)


## A row the SHEET authored. `uid` bakes the per-row id of a template that declares locals, which is
## what the dock does at apply time and what nothing downstream does for it: a test that skipped the
## bake would pin a line no sheet ever writes.
static func _authored_action(ace_id: String, params: Dictionary, uid: String) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	action.params = params
	action.codegen_template = ACERegistry.find_descriptor("Core", ace_id).codegen_template.replace("{uid}", uid)
	return action


static func _function_of(sheet: EventSheetResource, function_name: String) -> EventFunction:
	for entry: Variant in sheet.functions:
		if entry is EventFunction and (entry as EventFunction).function_name == function_name:
			return entry as EventFunction
	return null


## The nth ACE action of a lifted function's body, counting across its rows in order.
static func _function_action(sheet: EventSheetResource, function_name: String, index: int) -> ACEAction:
	var found: Array[ACEAction] = []
	var event_function: EventFunction = _function_of(sheet, function_name)
	if event_function != null:
		for row: Variant in event_function.events:
			if row is EventRow:
				for action: Variant in (row as EventRow).actions:
					if action is ACEAction:
						found.append(action as ACEAction)
	return found[index] if index < found.size() else null


## The ace ids of the actions of a sheet's top-level events, in order - what an emitted file reads
## back as when it is opened again.
static func _event_row_ids(sheet: EventSheetResource) -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray()
	for row: Variant in sheet.events:
		if not (row is EventRow):
			continue
		for action: Variant in (row as EventRow).actions:
			if action is ACEAction:
				ids.append((action as ACEAction).ace_id)
	return ids


## The values of the FIRST action of a sheet's top-level events - the row an emitted file re-opens
## with, and what it kept.
static func _event_row_params(sheet: EventSheetResource) -> Dictionary:
	for row: Variant in sheet.events:
		if not (row is EventRow):
			continue
		for action: Variant in (row as EventRow).actions:
			if action is ACEAction:
				return (action as ACEAction).params
	return {}


static func _function_row_ids(sheet: EventSheetResource, function_name: String) -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray()
	var index: int = 0
	while true:
		var action: ACEAction = _function_action(sheet, function_name, index)
		if action == null:
			break
		ids.append(action.ace_id)
		index += 1
	return ids


static func _row_of(action: ACEAction) -> String:
	return action.ace_id if action != null else "(no row)"


static func _params_of(action: ACEAction) -> Dictionary:
	return action.params if action != null else {}


static func _template_of(action: ACEAction) -> String:
	return action.codegen_template if action != null else "(no row)"


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("layout_on_top_lift_test", label, actual, expected)
