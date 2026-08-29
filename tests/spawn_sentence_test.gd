# Godot EventSheets - the spawn sentence, the name it leaves behind, and where it lands.
#
# What this gate holds, in the order the mistakes actually happen:
#   1. THE LINES. A spawn row is three plain statements and this pins all three, in order. The
#      placement line comes AFTER the parenting line on purpose (a global position means nothing
#      until the node is in a tree), and the deferred row puts the place BEFORE the parenting for
#      the opposite reason - swap either and the copy lands somewhere else at runtime while every
#      other test stays green.
#   2. THE NAME IS A REAL VARIABLE. The row's Called field is the identifier the emitted code uses,
#      which is the whole reason a following row can say it. Pinned as the literal line.
#   3. THE ROUND TRIP. Spawn code opens as these rows with the author's own name kept, and the
#      re-emitted file is byte-identical to what went in - the lossless rule, per row shape.
#   4. THE PLACEMENT WORDS. Each of the four answers to "where" is one expression, pinned as the
#      exact text it emits, and each survives the open-and-re-emit trip inside a spawn row's field.
#
# Values are pinned, never counts: a count would go on passing while the wrong line moved.
@tool
class_name SpawnSentenceTest
extends RefCounted

## The scene expression the fixtures spawn. A load() of a path rather than a declared name, so the
## fixture stands on its own the way the row's own default does.
const BULLET: String = "load(\"res://bullet.tscn\")"


static func run() -> bool:
	var passed: bool = true
	passed = _test_the_descriptors_say_what_they_emit() and passed
	passed = _test_the_spawn_row_emits_three_lines() and passed
	passed = _test_the_deferred_row_places_before_it_parents() and passed
	passed = _test_spawn_code_opens_as_rows_keeping_the_name() and passed
	passed = _test_the_placement_words_are_one_expression_each() and passed
	passed = _test_the_name_is_offered_to_the_rows_after_it() and passed
	return passed


# ── 1. The descriptors ──


static func _test_the_descriptors_say_what_they_emit() -> bool:
	var passed: bool = true
	var by_id: Dictionary = _descriptors()
	passed = _check("Spawn A Copy emits instance, parent, place - in that order",
		str(by_id.get("SpawnNewCopy", ACEDescriptor.new()).codegen_template),
		"var {name} = {scene}.instantiate()\n{parent}.add_child({name})\n{name}.global_position = {at}") and passed
	passed = _check("Spawn A Copy Safely defers the parenting and says so in its sentence",
		str(by_id.get("SpawnNewCopyDeferred", ACEDescriptor.new()).codegen_template),
		"var {name} = {scene}.instantiate()\n{name}.position = {at}\n{parent}.call_deferred(\"add_child\", {name})") and passed
	passed = _check("the deferral is stated on the row rather than done quietly",
		str(by_id.get("SpawnNewCopyDeferred", ACEDescriptor.new()).display_text).contains("added on the next idle moment"), true) and passed
	passed = _check("Make A Copy is the one statement that mints the name",
		str(by_id.get("MakeNewCopy", ACEDescriptor.new()).codegen_template), "var {name} = {scene}.instantiate()") and passed
	# The default placement IS where the spawner is, and the default parent IS the spawning node -
	# the two answers the sentence claims when nobody has touched the fields.
	passed = _check("the row opens placing the copy where the spawner is",
		_default_of(by_id.get("SpawnNewCopy", null), "at"), "global_position") and passed
	passed = _check("the row opens adding the copy under the spawning node",
		_default_of(by_id.get("SpawnNewCopy", null), "parent"), "self") and passed
	# Every placement word, as the exact expression it writes.
	passed = _check("place of a node", str(by_id.get("PlaceAtNode", ACEDescriptor.new()).codegen_template),
		"{node}.global_position") and passed
	passed = _check("a random place along a path samples the curve by distance",
		str(by_id.get("PlaceAlongPath", ACEDescriptor.new()).codegen_template),
		"({path}.global_position + {path}.curve.sample_baked(randf() * {path}.curve.get_baked_length()))") and passed
	passed = _check("a random place inside a shape measures the shape rather than retrying",
		str(by_id.get("PlaceInsideShape", ACEDescriptor.new()).codegen_template),
		"({shape}.global_position + (({shape}.shape as RectangleShape2D).size * Vector2(randf() - 0.5, randf() - 0.5)"
		+ " if {shape}.shape is RectangleShape2D"
		+ " else (Vector2.RIGHT.rotated(randf() * TAU) * ({shape}.shape as CircleShape2D).radius * sqrt(randf())"
		+ " if {shape}.shape is CircleShape2D else Vector2.ZERO)))") and passed
	passed = _check("the shape sampling says what it does and does not do",
		str(by_id.get("PlaceInsideShape", ACEDescriptor.new()).description).contains("no rejection sampling"), true) and passed
	passed = _check("a random place off a screen edge answers in world coordinates",
		str(by_id.get("PlaceAtScreenEdge", ACEDescriptor.new()).codegen_template).begins_with(
			"(get_viewport().get_canvas_transform().affine_inverse() *"), true) and passed
	return passed


# ── 2 and 3. The lines the rows write ──


static func _test_the_spawn_row_emits_three_lines() -> bool:
	var output: String = _compiled_with("SpawnNewCopy", {
		"scene": BULLET, "name": "b", "at": "$SpawnPoint.global_position", "parent": "self"
	}, "user://eventforge_spawn_row.gd")
	var passed: bool = true
	passed = _check("the name the row was given is the variable the code declares",
		output.contains("\tvar b = load(\"res://bullet.tscn\").instantiate()"), true) and passed
	passed = _check("the copy is added under the parent the row names",
		output.contains("\tself.add_child(b)"), true) and passed
	passed = _check("the copy is placed after it is in the tree",
		output.contains("\tb.global_position = $SpawnPoint.global_position"), true) and passed
	return passed


static func _test_the_deferred_row_places_before_it_parents() -> bool:
	var output: String = _compiled_with("SpawnNewCopyDeferred", {
		"scene": BULLET, "name": "b", "at": "Vector2(0, 0)", "parent": "self"
	}, "user://eventforge_spawn_deferred.gd")
	var place_at: int = output.find("\tb.position = Vector2(0, 0)")
	var parent_at: int = output.find("\tself.call_deferred(\"add_child\", b)")
	var passed: bool = true
	passed = _check("the deferred row writes the deferred add", parent_at >= 0, true) and passed
	passed = _check("the deferred row places the copy before it hands it over",
		place_at >= 0 and place_at < parent_at, true) and passed
	return passed


static func _test_spawn_code_opens_as_rows_keeping_the_name() -> bool:
	# The spelling a person writes by hand: make it, add it, place it - with their own name for it.
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnReady"
	event.actions.append(_action("MakeNewCopy", {"scene": BULLET, "name": "b"}))
	event.actions.append(_action("AddChild", {"node": "b"}))
	sheet.events.append(event)
	var source: String = _compile(sheet, "user://eventforge_spawn_handwritten.gd")

	var passed: bool = true
	passed = _check("the hand-written spelling is the one the rows write",
		source.contains("\tvar b = load(\"res://bullet.tscn\").instantiate()\n\tadd_child(b)"), true) and passed

	# WHAT IT OPENS AS, and why it is not the Make A Copy row itself. The instancing line already has
	# a shipped reading that says more than that row could - it gathers the instance, the parent it
	# went under and the place it was put into one sentence and keeps the author's own name in it -
	# so Make A Copy is an authoring word and stays out of the reverse index. What has to hold either
	# way is this: the author's name for the copy survives the open, the add lands on the shipped Add
	# Child row, and the file re-emits byte for byte.
	var imported: EventSheetResource = GDScriptImporter.new().import_external_source(source)
	var minted: ACEAction = null
	var added: ACEAction = null
	for row: Variant in imported.events:
		if not (row is EventRow):
			continue
		for entry: Variant in (row as EventRow).actions:
			if not (entry is ACEAction):
				continue
			var action: ACEAction = entry
			if action.ace_id == "SetLocalVar":
				minted = action
			elif action.ace_id == "AddChild":
				added = action
	passed = _check("the instancing line opens as a row rather than a code cell", minted != null, true) and passed
	if minted != null:
		passed = _check("the author's own name is what the row shows", str(minted.params.get("name", "")), "b") and passed
		passed = _check("the scene and the instancing survive the open",
			str(minted.params.get("value", "")), "%s.instantiate()" % BULLET) and passed
	passed = _check("the add lands on the shipped Add Child row", added != null, true) and passed

	imported.external_source_path = "user://eventforge_spawn_roundtrip.gd"
	var again: String = _compile(imported, "user://eventforge_spawn_roundtrip.gd")
	passed = _check("opened spawn code re-emits byte for byte", again == source, true) and passed
	return passed


# ── 4. The placement words ──


static func _test_the_placement_words_are_one_expression_each() -> bool:
	var passed: bool = true
	# Each placement word riding in the field it exists for, through a full open-and-re-emit trip.
	for placement: String in [
		"$Marker2D.global_position",
		"($Path2D.global_position + $Path2D.curve.sample_baked(randf() * $Path2D.curve.get_baked_length()))",
	]:
		var sheet: EventSheetResource = EventSheetResource.new()
		sheet.host_class = "Node2D"
		var event: EventRow = EventRow.new()
		event.trigger_provider_id = "Core"
		event.trigger_id = "OnReady"
		event.actions.append(_action("SpawnNewCopy", {
			"scene": BULLET, "name": "b", "at": placement, "parent": "self"
		}))
		sheet.events.append(event)
		var source: String = _compile(sheet, "user://eventforge_spawn_place.gd")
		passed = _check("the placement expression is emitted as written",
			source.contains("\tb.global_position = %s" % placement), true) and passed
		var imported: EventSheetResource = GDScriptImporter.new().import_external_source(source)
		imported.external_source_path = "user://eventforge_spawn_place_back.gd"
		passed = _check("a spawn placed by %s re-emits byte for byte" % placement.get_slice("(", 0),
			_compile(imported, "user://eventforge_spawn_place_back.gd") == source, true) and passed
	return passed


# ── 5. The name, offered onwards ──


static func _test_the_name_is_offered_to_the_rows_after_it() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnReady"
	event.actions.append(_action("SpawnNewCopy", {
		"scene": BULLET, "name": "new_bullet", "at": "global_position", "parent": "self"
	}))
	sheet.events.append(event)
	EventSheetCompletions.clear_cache()
	var offered: Dictionary = {}
	for entry: Dictionary in EventSheetCompletions.for_field(sheet, "expression", "new_"):
		offered[str(entry.get("text", ""))] = str(entry.get("detail", ""))
	var passed: bool = true
	passed = _check("an expression field offers the name the spawn row gave the copy",
		offered.has("new_bullet"), true) and passed
	passed = _check("the offer says which scene the copy is of",
		str(offered.get("new_bullet", "")).contains("bullet.tscn"), true) and passed
	EventSheetCompletions.clear_cache()

	# A spawn under a condition is still a spawn this sheet does, and its name is still a local the
	# rows beside it can say - so a sub-event's copy is offered exactly as a top-level one is.
	var nested: EventSheetResource = EventSheetResource.new()
	nested.host_class = "Node2D"
	var parent_event: EventRow = EventRow.new()
	parent_event.trigger_provider_id = "Core"
	parent_event.trigger_id = "OnProcess"
	var child_event: EventRow = EventRow.new()
	child_event.actions.append(_action("SpawnNewCopy", {
		"scene": BULLET, "name": "nested_bullet", "at": "global_position", "parent": "self"
	}))
	parent_event.sub_events.append(child_event)
	nested.events.append(parent_event)
	EventSheetCompletions.clear_cache()
	var nested_names: PackedStringArray = PackedStringArray()
	for entry: Dictionary in EventSheetCompletions.for_field(nested, "expression", "nested_"):
		nested_names.append(str(entry.get("text", "")))
	passed = _check("a copy spawned under a condition is offered too",
		nested_names.has("nested_bullet"), true) and passed
	EventSheetCompletions.clear_cache()
	return passed


# ── Harness ──


## The Spawn module's descriptors by id. Loaded BY PATH so the test does not wait on the editor
## class cache having been regenerated for a newly added module.
static func _descriptors() -> Dictionary:
	var module: GDScript = load("res://addons/eventforge/registration/modules/spawn_aces.gd")
	var by_id: Dictionary = {}
	for descriptor: Variant in module.call("get_descriptors"):
		if descriptor is ACEDescriptor:
			by_id[str((descriptor as ACEDescriptor).ace_id)] = descriptor
	return by_id


## One parameter's default, as the literal the row opens on. "" when the descriptor or the parameter
## is not there, which reads as a plain failure rather than a crash.
static func _default_of(descriptor: Variant, param_id: String) -> String:
	if not (descriptor is ACEDescriptor):
		return ""
	for param: ACEParam in (descriptor as ACEDescriptor).params:
		if str(param.id) == param_id:
			return str(param.default_value)
	return ""


static func _action(ace_id: String, params: Dictionary) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	action.params = params.duplicate()
	return action


## One row of the given kind, compiled in a ready handler on a Node2D - the smallest sheet that can
## hold a spawn.
static func _compiled_with(ace_id: String, params: Dictionary, path: String) -> String:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnReady"
	event.actions.append(_action(ace_id, params))
	sheet.events.append(event)
	return _compile(sheet, path)


static func _compile(sheet: EventSheetResource, path: String) -> String:
	return str(SheetCompiler.compile(sheet, path).get("output", ""))


static func _check(label: String, got: Variant, expected: Variant) -> bool:
	if got == expected:
		return true
	print("[FAIL] spawn_sentence_test: %s -> expected %s, got %s" % [label, expected, got])
	return false
