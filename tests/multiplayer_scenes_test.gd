# The scene's own two nodes as rows: spawning, despawning, who may see it, and the three
# events the pair raises.
#
# Pinned by VALUE, in the order the failures would matter:
#   the VOCABULARY - every new id, the exact Godot call it compiles to (as SHIPPED, which for a
#   node-scoped row is the `{target.}`-prefixed form the factory produces, not the one this module
#   authored), the sentence it reads as, and the shelf the Add event picker files it on;
#   what the sheet WRITES - an authored Spawn row emits the four canonical lines, and the file it
#   wrote OPENS BACK on the same row, which is the whole point of the recogniser;
#   what an existing project READS AS - a hand-written fixture of the same shapes, byte-exact;
#   the SEAM - which scenes a spawner offers, which spawner a row addresses, and what a Spawn row
#   naming a scene the spawner does not list yet still owes the scene;
#   the MARK - which of a sheet's functions a synchronizer asks about visibility, which is read off
#   the row that hands the function over and stored nowhere.
@tool
class_name MultiplayerScenesTest
extends RefCounted

const GDScriptImporter := preload("res://addons/eventforge/importer/gdscript_importer.gd")
const FieldFactory := preload("res://addons/eventsheet/editor/ace_dialog/param_field_factory.gd")

const FIXTURE: String = "res://tests/fixtures/multiplayer_scene_verbs.gd"
const LEVEL_SCRIPT: String = "res://tests/fixtures/multiplayer_scene_level.gd"
const PLAYER_SCENE: String = "res://tests/fixtures/multiplayer_scene_player.tscn"

## Every ace_id this slice adds, checked against the WHOLE registry: an id is a compatibility
## promise the moment it ships, and two descriptors answering to one is a silent coin toss over
## which template a row compiles through.
const NEW_ACE_IDS: Array[String] = [
	"SpawnReplicatedScene", "Despawn", "ShowToPlayer", "HideFromPlayer", "ShowToEveryone",
	"AddVisibilityFilter", "OnSpawned", "OnDespawned", "OnSynchronized"
]


static func run() -> bool:
	EventSheetSceneReplication.clear_cache()
	var ok: bool = true
	ok = _test_the_vocabulary() and ok
	ok = _test_the_picker_shelf() and ok
	ok = _test_what_a_spawn_row_writes() and ok
	ok = _test_what_a_written_spawn_reads_back_as() and ok
	ok = _test_the_fixture_reads_as_rows() and ok
	ok = _test_the_spawn_list_seam() and ok
	ok = _test_the_visibility_filter_mark() and ok
	ok = _test_the_help_strip_explains_the_scene_field() and ok
	EventSheetSceneReplication.clear_cache()
	return ok


# ── the vocabulary ──────────────────────────────────────────────────────────────────────────────


static func _test_the_vocabulary() -> bool:
	var ok: bool = true
	var counts: Dictionary = {}
	var missing_help: PackedStringArray = PackedStringArray()
	for descriptor: ACEDescriptor in ACERegistry.get_all_descriptors():
		if not NEW_ACE_IDS.has(descriptor.ace_id):
			continue
		counts[descriptor.ace_id] = int(counts.get(descriptor.ace_id, 0)) + 1
		if descriptor.description.strip_edges().length() < 40:
			missing_help.append(descriptor.ace_id)
		for param: ACEParam in descriptor.params:
			if str(param.description).strip_edges().length() < 20:
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
	ok = _check("no new id collides with one that already shipped", duplicated, PackedStringArray()) and ok
	ok = _check("every new row and parameter carries real help", missing_help, PackedStringArray()) and ok

	# The SHIPPED template, which for the four synchronizer rows is not the one the module authored:
	# a node-scoped ACE is given the optional `{target.}` prefix and an "On node" parameter, so a test
	# pinning the authored string would be pinning something no row ever compiles through.
	for pinned: Array in [
		["SpawnReplicatedScene", "var __spawn_{uid} = load({scene}).instantiate()\n__spawn_{uid}.name = {name}\n__spawn_{uid}.position = {at}\n{target}.get_node({target}.spawn_path).add_child(__spawn_{uid}, true)",
			"Spawn {scene} named {name} at {at}", "MultiplayerSpawner"],
		["Despawn", "queue_free()", "Despawn", ""],
		["ShowToPlayer", "{target.}set_visibility_for({id}, true)", "Show to player {id}", "MultiplayerSynchronizer"],
		["HideFromPlayer", "{target.}set_visibility_for({id}, false)", "Hide from player {id}", "MultiplayerSynchronizer"],
		["ShowToEveryone", "{target.}public_visibility = true", "Show to everyone", "MultiplayerSynchronizer"],
		["AddVisibilityFilter", "{target.}add_visibility_filter({filter})", "Ask {filter} who may see it", "MultiplayerSynchronizer"]
	]:
		var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", str(pinned[0]))
		if descriptor == null:
			ok = _check("%s is registered" % str(pinned[0]), false, true)
			continue
		ok = _check("%s writes its Godot call" % str(pinned[0]), descriptor.codegen_template, str(pinned[1])) and ok
		ok = _check("%s reads as a sentence" % str(pinned[0]), descriptor.get_display_text(), str(pinned[2])) and ok
		ok = _check("%s is an action" % str(pinned[0]), int(descriptor.ace_type), int(ACEDescriptor.ACEType.ACTION)) and ok
		ok = _check("%s is offered on its own node" % str(pinned[0]), descriptor.node_type, str(pinned[3])) and ok
		ok = _check("%s is filed under Multiplayer" % str(pinned[0]), descriptor.category,
			EventForgeMultiplayerACEs.CATEGORY) and ok

	# The Spawn row's fields, in the order the dialog asks them, each with the kind of field it opens.
	var spawn: ACEDescriptor = ACERegistry.find_descriptor("Core", "SpawnReplicatedScene")
	var fields: PackedStringArray = PackedStringArray()
	for param: ACEParam in spawn.params:
		fields.append("%s:%s" % [param.id, param.hint])
	ok = _check("Spawn asks for the spawner, the scene, a name and a place", fields,
		PackedStringArray(["target:scene_node", "scene:spawn_scene", "name:expression", "at:expression"])) and ok

	for pinned: Array in [["OnSpawned", "spawned", "On spawned {node}", "MultiplayerSpawner", ["node"]],
			["OnDespawned", "despawned", "On despawned {node}", "MultiplayerSpawner", ["node"]],
			["OnSynchronized", "synchronized", "On synchronized", "MultiplayerSynchronizer", []]]:
		var trigger: ACEDescriptor = ACERegistry.find_descriptor("Core", str(pinned[0]))
		if trigger == null:
			ok = _check("%s is registered" % str(pinned[0]), false, true)
			continue
		ok = _check("%s names the signal behind it" % str(pinned[0]), trigger.signal_name, str(pinned[1])) and ok
		ok = _check("%s reads as a sentence" % str(pinned[0]), trigger.get_display_text(), str(pinned[2])) and ok
		ok = _check("%s is a trigger" % str(pinned[0]), int(trigger.ace_type), int(ACEDescriptor.ACEType.TRIGGER)) and ok
		ok = _check("%s belongs to its node" % str(pinned[0]), trigger.node_type, str(pinned[3])) and ok
		# A trigger keeps its node_type, so the cross-node transform must leave it alone: an "On node"
		# parameter on an EVENT would be a second way to say what the event already says.
		var carried: PackedStringArray = PackedStringArray()
		for param: ACEParam in trigger.params:
			carried.append(param.id)
		ok = _check("%s hands on what its signal carries, and nothing else" % str(pinned[0]),
			carried, PackedStringArray(pinned[4])) and ok

	# Despawn writes the line every project writes to remove any node at all, so it must NOT speak for
	# one: the networked meaning is where it runs, not what it says.
	ok = _check("Despawn stays out of the reverse index",
		EventSheetACELifter.REVERSE_LIFT_EXCLUDED_ACE_IDS.has("Despawn"), true) and ok
	return ok


## The shelf rule, applied to the three new events: a trigger that names a node in the scene is
## about that node, so it is filed under Scenes with no table edited.
static func _test_the_picker_shelf() -> bool:
	var ok: bool = true
	for ace_id: String in ["OnSpawned", "OnDespawned", "OnSynchronized"]:
		var definition: ACEDefinition = _definition(ace_id)
		ok = _check("%s is offered under Scenes" % ace_id, ACEPickerDialog.multiplayer_group_key(definition),
			EventForgeMultiplayerACEs.SECTION_SCENES) and ok
	return ok


# ── what the sheet writes, and reads back ───────────────────────────────────────────────────────


static func _test_what_a_spawn_row_writes() -> bool:
	var output: String = _compile(_authored_spawn_sheet())
	var ok: bool = _check("the copy is made from the scene the row names", output.contains(
		"\tvar __spawn_a1 = load(\"res://tests/fixtures/multiplayer_scene_player.tscn\").instantiate()"), true)
	ok = _check("it is named before it joins the tree", output.contains("\t__spawn_a1.name = str(id)"), true) and ok
	ok = _check("and placed before it joins the tree", output.contains("\t__spawn_a1.position = Vector2(0, 0)"), true) and ok
	ok = _check("then handed to the node the spawner watches", output.contains(
		"\t$Spawner.get_node($Spawner.spawn_path).add_child(__spawn_a1, true)"), true) and ok
	ok = _check("a Despawn row is the one line it names", output.contains("\tqueue_free()"), true) and ok
	ok = _check("the spawner's own event connects on the node", output.contains(
		"\tget_node(\"Spawner\").spawned.connect(_on_spawner_spawned)"), true) and ok
	ok = _check("and lands in a handler taking the copy", output.contains(
		"func _on_spawner_spawned(node: Node) -> void:"), true) and ok
	return ok


## The file the sheet just wrote, opened again. This is the property the four-line template exists
## for: a run the sheet emits has to come back as the row that emitted it, or saving a sheet as `.gd`
## and reopening it would show a script block where a Spawn row was.
static func _test_what_a_written_spawn_reads_back_as() -> bool:
	var written: String = _compile(_authored_spawn_sheet())
	var reopened: EventSheetResource = GDScriptImporter.new().import_external_source(written, true, FIXTURE)
	var spawn: ACEAction = _function_action(reopened, "welcome", 0)
	var ok: bool = _check("the emitted run opens as the row that wrote it", _row_of(spawn), "SpawnReplicatedScene")
	ok = _check("with every answer it was given", _params_of(spawn), {
		"target": "$Spawner",
		"scene": "\"res://tests/fixtures/multiplayer_scene_player.tscn\"",
		"name": "str(id)",
		"at": "Vector2(0, 0)"
	}) and ok
	ok = _check("and the file's own variable name baked into the template", _template_of(spawn),
		"var __spawn_a1 = load({scene}).instantiate()\n__spawn_a1.name = {name}\n__spawn_a1.position = {at}\n{target}.get_node({target}.spawn_path).add_child(__spawn_a1, true)") and ok
	reopened.external_source_path = "user://_multiplayer_scenes_roundtrip.gd"
	ok = _check("and re-emits it byte for byte",
		_compile(reopened) == written, true) and ok
	return ok


## A hand-written script in the shapes people publish. The whole file has to come back byte for
## byte, and every row it reads as is pinned by value.
static func _test_the_fixture_reads_as_rows() -> bool:
	var source: String = FileAccess.get_file_as_string(FIXTURE)
	var sheet: EventSheetResource = GDScriptImporter.new().import_external_source(source, true, FIXTURE)
	sheet.external_source_path = "user://_multiplayer_scenes_fixture.gd"
	var ok: bool = _check("the fixture comes back byte for byte", _compile(sheet) == source, true)
	sheet.external_source_path = FIXTURE

	var spawn: ACEAction = _function_action(sheet, "welcome", 0)
	ok = _check("a four-line spawn reads as one row", _row_of(spawn), "SpawnReplicatedScene") and ok
	ok = _check("naming the spawner, the scene, the name and the place", _params_of(spawn), {
		"target": "$Spawner",
		"scene": "\"res://tests/fixtures/multiplayer_scene_player.tscn\"",
		"name": "str(id)",
		"at": "Vector2(0, 0)"
	}) and ok
	ok = _check("showing one player what it keeps in step", _row_of(_function_action(sheet, "welcome", 1)),
		"ShowToPlayer") and ok
	ok = _check("and the false half is the other row", _row_of(_function_action(sheet, "forget", 0)),
		"HideFromPlayer") and ok
	ok = _check("public visibility back on is Show to everyone",
		_row_of(_function_action(sheet, "open_up", 0)), "ShowToEveryone") and ok
	var filter: ACEAction = _function_action(sheet, "guard_the_view", 0)
	ok = _check("handing a function over reads as asking it", _row_of(filter), "AddVisibilityFilter") and ok
	ok = _check("naming the synchronizer and the function", _params_of(filter),
		{"target": "$PlayerSync", "filter": "can_see"}) and ok

	var triggers: PackedStringArray = PackedStringArray()
	for event: EventRow in _events_of(sheet):
		triggers.append("%s@%s" % [event.trigger_id, event.trigger_source_path])
	ok = _check("the three signals read as the three events", triggers, PackedStringArray([
		"OnSpawned@Spawner", "OnDespawned@Spawner", "OnSynchronized@PlayerSync"])) and ok
	# Every line above counts against the per-script networking number, so a spawn or a visibility
	# call that stayed a block would show up as a gap rather than as nothing at all.
	ok = _check("the scene calls count as networking lines",
		EventForgeMultiplayerLift.is_networking_line("\t$PlayerSync.set_visibility_for(id, true)")
			and EventForgeMultiplayerLift.is_networking_line("\t$Spawner.get_node($Spawner.spawn_path).add_child(p, true)"),
		true) and ok
	return ok


# ── the seam ────────────────────────────────────────────────────────────────────────────────────


static func _test_the_spawn_list_seam() -> bool:
	EventSheetSceneReplication.clear_cache()
	var level: EventSheetResource = EventSheets.new_sheet({"class_name": "Level"})
	level.external_source_path = LEVEL_SCRIPT
	var ok: bool = _check("the Spawn field offers what the spawner may make",
		EventSheetSceneVerbs.spawn_scene_choices(level), PackedStringArray(["\"%s\"" % PLAYER_SCENE]))
	ok = _check("the row's Spawner value finds the node in the scene",
		str(EventSheetSceneVerbs.spawner_named(level, "$Spawner").get("name", "")), "Spawner") and ok
	ok = _check("...and so does the bare name", str(EventSheetSceneVerbs.spawner_named(level, "Spawner")
		.get("name", "")), "Spawner") and ok
	ok = _check("a scene with one spawner needs no answer at all",
		str(EventSheetSceneVerbs.spawner_named(level, "self").get("name", "")), "Spawner") and ok
	ok = _check("a node the scene does not have finds nothing",
		EventSheetSceneVerbs.spawner_named(level, "$Nowhere"), {}) and ok
	ok = _check("a computed node cannot be checked, so it is not guessed at",
		EventSheetSceneVerbs.node_name_of("get_node(path)"), "") and ok

	ok = _check("a scene the spawner already lists owes it nothing",
		EventSheetSceneVerbs.unlisted_spawn_scene(level,
			{"target": "$Spawner", "scene": "\"%s\"" % PLAYER_SCENE}), {}) and ok
	var pending: Dictionary = EventSheetSceneVerbs.unlisted_spawn_scene(level,
		{"target": "$Spawner", "scene": "\"res://tests/fixtures/multiplayer_scene_level.tscn\""})
	ok = _check("one it does not names the write it needs", pending, {
		"scene_path": "res://tests/fixtures/multiplayer_scene_level.tscn",
		"spawner_path": "Spawner",
		"scene": "res://tests/fixtures/multiplayer_scene_level.tscn",
		"spawner": "Spawner"
	}) and ok
	ok = _check("and the dialog says so before OK is pressed",
		EventSheetSceneVerbs.unlisted_scene_note(pending),
		"multiplayer_scene_level.tscn is not in Spawner's list of scenes it may spawn yet. Pressing OK adds it, as one step of the scene's own undo.") and ok
	ok = _check("nothing pending says nothing", EventSheetSceneVerbs.unlisted_scene_note({}), "") and ok
	ok = _check("and the strip says how many copies the spawner may be watching",
		EventSheetSceneVerbs.spawn_limit_note(level, {"target": "$Spawner"}),
		"Spawner may be watching 4 copies at once - its Spawn limit in the Inspector. Past that it refuses to make another until one goes.") and ok
	ok = _check("a spawner nobody named says no number",
		EventSheetSceneVerbs.spawn_limit_note(level, {"target": "$Nowhere"}), "") and ok
	ok = _check("a value that is not a path is nobody's scene",
		EventSheetSceneVerbs.unlisted_spawn_scene(level, {"target": "$Spawner", "scene": "chosen_scene"}), {}) and ok
	# The writer refuses outside the editor rather than writing a scene file behind the Inspector's
	# back - the same refusal every other write through this seam makes.
	var refused: Dictionary = EventSheetSceneReplication.add_spawnable_scene(
		"res://tests/fixtures/multiplayer_scene_level.tscn", "Spawner", PLAYER_SCENE)
	ok = _check("the write is refused with a reason outside the editor",
		bool(refused.get("ok", true)) == false and not str(refused.get("reason", "")).is_empty(), true) and ok

	var lonely: EventSheetResource = EventSheets.new_sheet({"class_name": "Alone"})
	ok = _check("a sheet with no scene offers nothing to pick",
		EventSheetSceneVerbs.spawn_scene_choices(lonely), PackedStringArray()) and ok
	ok = _check("...and owes nothing either",
		EventSheetSceneVerbs.unlisted_spawn_scene(lonely, {"target": "$Spawner", "scene": "\"res://x.tscn\""}), {}) and ok
	return ok


# ── the mark ────────────────────────────────────────────────────────────────────────────────────


static func _test_the_visibility_filter_mark() -> bool:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external_source(
		FileAccess.get_file_as_string(FIXTURE), true, FIXTURE)
	var ok: bool = _check("the function a synchronizer asks is read off the row that asks it",
		EventSheetSceneVerbs.visibility_filters_in(sheet), [{"name": "can_see", "synchronizer": "PlayerSync"}])
	ok = _check("so the row can say which synchronizer asks it",
		EventSheetSceneVerbs.filter_of(sheet, "can_see"), {"name": "can_see", "synchronizer": "PlayerSync"}) and ok
	ok = _check("an ordinary function is not one", EventSheetSceneVerbs.filter_of(sheet, "welcome"), {}) and ok
	ok = _check("and the list is public", EventSheets.sheet_visibility_filters(sheet),
		[{"name": "can_see", "synchronizer": "PlayerSync"}]) and ok
	# The commonest thing anybody does to a sheet is put its events in a group. The reading walks
	# into one: a filter asked for inside a folder is asked for just the same, and a walk that only
	# looked at the top level lost the function's mark and under-reported the public list.
	_group_the_events(sheet)
	ok = _check("a row inside a group is read the same way",
		EventSheetSceneVerbs.visibility_filters_in(sheet), [{"name": "can_see", "synchronizer": "PlayerSync"}]) and ok
	# Nothing is written into the `.gd` for the mark: take the asking row away and the function is an
	# ordinary function again, with no annotation to clean up.
	for entry: Variant in sheet.functions:
		var event_function: EventFunction = entry as EventFunction
		if event_function != null and event_function.function_name == "guard_the_view":
			event_function.events.clear()
	ok = _check("a filter nobody asks stops being one",
		EventSheetSceneVerbs.visibility_filters_in(sheet), []) and ok
	return ok


## Every row of the sheet moved inside a group, the functions' rows included - the first thing a
## reader does to a sheet with more than a screenful in it.
static func _group_the_events(sheet: EventSheetResource) -> void:
	var top: Array[Resource] = [_grouped(sheet.events)]
	sheet.events = top
	for entry: Variant in sheet.functions:
		var event_function: EventFunction = entry as EventFunction
		if event_function == null:
			continue
		var body: Array[Resource] = [_grouped(event_function.events)]
		event_function.events = body


static func _grouped(rows: Array) -> EventGroup:
	var group: EventGroup = EventGroup.new()
	group.name = "Networking"
	group.events.assign(rows)
	return group


static func _test_the_help_strip_explains_the_scene_field() -> bool:
	var paragraph: String = FieldFactory.hint_paragraph("spawn_scene", "Level")
	var ok: bool = _check("the Scene field says where the list comes from",
		paragraph.contains("the spawner's own") and paragraph.contains("added when you press OK"), true)
	ok = _check("...and what a spawner does with a scene it does not list",
		paragraph.contains("made here and nowhere else"), true) and ok
	ok = _check("the heading says what kind of value it takes",
		FieldFactory.type_phrase({"hint": "spawn_scene"}), "a scene") and ok
	return ok


# ── the walk ────────────────────────────────────────────────────────────────────────────────────


## A sheet that AUTHORS the two spawner rows, the way the dock would: the `{uid}` slot of a
## multi-statement template is baked at apply time, so a test that skipped that step would be
## pinning a line no sheet ever writes.
static func _authored_spawn_sheet() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnSpawned"
	event.trigger_source_path = "Spawner"
	var spawn: ACEAction = _authored_action("SpawnReplicatedScene", {
		"target": "$Spawner",
		"scene": "\"%s\"" % PLAYER_SCENE,
		"name": "str(id)",
		"at": "Vector2(0, 0)"
	})
	spawn.codegen_template = EventForgeMultiplayerACEs.SPAWN_SCENE_TEMPLATE.replace("{uid}", "a1")
	event.actions.append(spawn)
	event.actions.append(_authored_action("Despawn", {}))
	sheet.events.append(event)
	var welcome: EventFunction = EventFunction.new()
	welcome.function_name = "welcome"
	welcome.parameters = ["id"] as Array[String]
	var body: EventRow = EventRow.new()
	body.actions.append(spawn.duplicate(true))
	welcome.events.append(body)
	sheet.functions.append(welcome)
	return sheet


static func _compile(sheet: EventSheetResource) -> String:
	return str(SheetCompiler.compile(sheet, "user://_multiplayer_scenes.gd").get("output", ""))


static func _authored_action(ace_id: String, params: Dictionary) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	action.params = params
	return action


static func _definition(ace_id: String) -> ACEDefinition:
	return EventSheetACEAdapter.from_eventforge_descriptor(ACERegistry.find_descriptor("Core", ace_id))


static func _events_of(sheet: EventSheetResource) -> Array[EventRow]:
	var found: Array[EventRow] = []
	for row: Variant in sheet.events:
		if row is EventRow and not (row as EventRow).trigger_id.is_empty():
			found.append(row as EventRow)
	return found


static func _function_action(sheet: EventSheetResource, function_name: String, index: int) -> ACEAction:
	var found: Array[ACEAction] = []
	for entry: Variant in sheet.functions:
		var event_function: EventFunction = entry as EventFunction
		if event_function == null or event_function.function_name != function_name:
			continue
		for row: Variant in event_function.events:
			if row is EventRow:
				for action: Variant in (row as EventRow).actions:
					if action is ACEAction:
						found.append(action as ACEAction)
	return found[index] if index < found.size() else null


static func _row_of(action: ACEAction) -> String:
	return action.ace_id if action != null else "(no row)"


static func _params_of(action: ACEAction) -> Dictionary:
	return action.params if action != null else {}


static func _template_of(action: ACEAction) -> String:
	return action.codegen_template if action != null else "(no row)"


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] multiplayer_scenes_test: %s" % label)
		return true
	print("[FAIL] multiplayer_scenes_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
