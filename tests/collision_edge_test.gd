# Godot EventSheets - the edge triggers: the step a standing state changed.
#
# What this gate holds, in the order the mistakes actually happen:
#   1. THE ORDERING. The floor pair's whole correctness is that the comparison happens BEFORE the
#      memory is brought up to date. Swap the two lines and the row can never be true, and nothing
#      else in the suite can see it - so the emitted helper is pinned line by line, as text.
#   2. IT COMPILES IN ITS HOST. The compile sweep skips these four (they call a helper the sheet
#      synthesizes, which that harness deliberately does not build), so the member and the template
#      are built together here and reload()ed inside the character body they are filed under.
#   3. ONE HANDLER. An edge is a MOMENT of a callback, not a callback of its own. A landing event
#      and a plain physics event must land in ONE `_physics_process`, because two functions of one
#      name do not parse.
#   4. THE GATE IS A ROW. Applying an edge trigger puts an ordinary condition in the sheet, which is
#      what makes the edge readable, editable and deletable - never a wrapper the compiler adds.
#   5. THE LIFT. The hand-rolled was-on-floor pattern every platformer contains opens as the row it
#      is, in both orders and in the two-variable form, and the file comes back byte for byte. The
#      names a project uses for its own memory ride out untouched, because the name is not a value.
#   6. THE WALL THAT TEACHES. A touch row on a scene that has nothing physical in it greys with a
#      reason that IS the fix, in the collision family's own words.
#
# Values are pinned, never counts.
@tool
class_name CollisionEdgeTest
extends RefCounted

## The modules, loaded BY PATH so the test does not wait on the editor class cache having been
## regenerated for a newly added file.
const EDGE_MODULE_PATH: String = "res://addons/eventforge/registration/modules/collision_edge_aces.gd"
const EDGES_PATH: String = "res://addons/eventforge/registration/collision_edges.gd"
const FILTERS_PATH: String = "res://addons/eventforge/registration/collision_filters.gd"

## The uid a hand-built row bakes, standing in for the one the dock mints at apply time.
const UID: String = "1"


static func run() -> bool:
	var passed: bool = true
	passed = _test_the_helper_asks_before_it_remembers() and passed
	passed = _test_the_floor_gates_compile_in_their_host() and passed
	passed = _test_the_area_gates_ask_the_overlap_list() and passed
	passed = _test_a_landing_and_a_physics_event_share_one_handler() and passed
	passed = _test_the_first_overlap_is_the_arrival_signal_and_a_visible_gate() and passed
	passed = _test_applying_an_edge_trigger_puts_the_gate_in_the_sheet() and passed
	passed = _test_the_handwritten_landing_opens_as_the_row_it_is() and passed
	passed = _test_a_landing_check_that_says_more_is_left_alone() and passed
	passed = _test_the_handwritten_landing_re_emits_byte_for_byte() and passed
	passed = _test_a_touch_row_with_nothing_to_touch_says_what_to_add() and passed
	passed = _test_every_node_family_teaches_its_own_line() and passed
	return passed


# ── 1. The ordering ──


## The three parts of the pattern, in the hand-written order. Pinned as the lines they are: an
## update that happened before the comparison would leave the row permanently false, and every other
## test in the suite would still pass.
static func _test_the_helper_asks_before_it_remembers() -> bool:
	var passed: bool = true
	var landed: String = _member_of("JustLanded").replace("{uid}", UID)
	passed = _check("the memory starts off the floor",
		landed.contains("var __was_on_floor_1: bool = false"), true) and passed
	var lines: PackedStringArray = landed.split("\n")
	var ask: int = lines.find("\tvar landed: bool = on_floor and not __was_on_floor_1")
	var update: int = lines.find("\t__was_on_floor_1 = on_floor")
	passed = _check("the comparison is there", ask >= 0, true) and passed
	passed = _check("the update is there", update >= 0, true) and passed
	passed = _check("and the comparison comes BEFORE the update", ask < update, true) and passed
	var left: PackedStringArray = _member_of("JustLeftTheGround").replace("{uid}", UID).split("\n")
	var left_ask: int = left.find("\tvar left: bool = __was_on_floor_1 and not on_floor")
	var left_update: int = left.find("\t__was_on_floor_1 = on_floor")
	passed = _check("the departure asks the same memory the other way round", left_ask >= 0, true) and passed
	passed = _check("and it too asks before it remembers", left_ask < left_update, true) and passed
	# The row's own term is a call on THIS script, never on a neighbour: the memory belongs to the
	# script that declared it, so the cross-node field must not have been added to these rows.
	passed = _check("the landing term calls this script's own helper",
		_template_of("JustLanded"), "self.__just_landed_{uid}()") and passed
	passed = _check("and so does the departure's",
		_template_of("JustLeftTheGround"), "self.__just_left_the_ground_{uid}()") and passed
	return passed


# ── 2. It compiles in its host ──


static func _test_the_floor_gates_compile_in_their_host() -> bool:
	var passed: bool = true
	var hosts: Dictionary = {
		"JustLanded": "CharacterBody2D", "JustLeftTheGround": "CharacterBody2D",
		"JustLanded3D": "CharacterBody3D", "JustLeftTheGround3D": "CharacterBody3D"
	}
	for ace_id: String in hosts:
		var member: String = _member_of(ace_id).replace("{uid}", UID)
		var term: String = _template_of(ace_id).replace("{uid}", UID)
		var source: String = "@tool\nextends %s\n\n%s\n\n\nfunc __t() -> void:\n\tif %s:\n\t\tpass\n" % [
			str(hosts[ace_id]), member, term]
		var script: GDScript = GDScript.new()
		script.source_code = source
		passed = _check("%s compiles in a %s" % [ace_id, str(hosts[ace_id])],
			script.reload(), OK) and passed
	return passed


# ── 3. The area pair asks the list, and keeps no memory ──


static func _test_the_area_gates_ask_the_overlap_list() -> bool:
	var passed: bool = true
	# The shipped template wears the optional cross-node prefix every node-scoped row grows; a blank
	# receiver compiles to the bare member operation, which is what these two are asked as.
	passed = _check("the first one in is a list of exactly one",
		_template_of("IsTheFirstOneIn"), "{target.}get_overlapping_bodies().size() == 1") and passed
	passed = _check("the last one out is an empty list",
		_template_of("WasTheLastOneOut"), "{target.}get_overlapping_bodies().is_empty()") and passed
	passed = _check("the first one in keeps no memory", _member_of("IsTheFirstOneIn"), "") and passed
	passed = _check("the last one out keeps none either", _member_of("WasTheLastOneOut"), "") and passed
	return passed


# ── 4. One handler ──


static func _test_a_landing_and_a_physics_event_share_one_handler() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "CharacterBody2D"
	sheet.events.append(_edge_event("OnLanded", "JustLanded", "\"landed\""))
	var ticking: EventRow = EventRow.new()
	ticking.trigger_provider_id = "Core"
	ticking.trigger_id = "OnPhysicsProcess"
	ticking.actions.append(_print("\"stepping\""))
	sheet.events.append(ticking)
	var output: String = _compile(sheet, "user://eventforge_edge_landed.gd")
	var passed: bool = true
	passed = _check("the landing lives in the physics step",
		output.contains("func _physics_process(delta: float) -> void:"), true) and passed
	passed = _check("and there is exactly one of them",
		output.count("func _physics_process("), 1) and passed
	passed = _check("the memory is declared beside the handler",
		output.contains("var __was_on_floor_1: bool = false"), true) and passed
	passed = _check("the edge is the visible if of the handler",
		output.contains("\tif self.__just_landed_1():"), true) and passed
	passed = _check("the landing body runs under it",
		output.contains("\t\tprint(\"landed\")"), true) and passed
	passed = _check("and the plain physics event runs beside it",
		output.contains("\tprint(\"stepping\")"), true) and passed
	return passed


# ── 5. The first overlap is the arrival signal ──


static func _test_the_first_overlap_is_the_arrival_signal_and_a_visible_gate() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Area2D"
	sheet.events.append(_edge_event("OnFirstOverlap", "IsTheFirstOneIn", "\"woke up\""))
	var output: String = _compile(sheet, "user://eventforge_edge_first.gd")
	var passed: bool = true
	passed = _check("it is the area's own arrival signal, connected in _ready",
		output.contains("\tbody_entered.connect(_on_body_entered)"), true) and passed
	passed = _check("the handler is handed what arrived",
		output.contains("func _on_body_entered(body: Node) -> void:"), true) and passed
	passed = _check("the gate is an ordinary if, not a wrapper",
		output.contains("\tif get_overlapping_bodies().size() == 1:"), true) and passed
	passed = _check("no memory is declared for it",
		output.contains("__was_on_floor"), false) and passed
	return passed


# ── 6. The gate is a row ──


static func _test_applying_an_edge_trigger_puts_the_gate_in_the_sheet() -> bool:
	var edges: GDScript = load(EDGES_PATH)
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(EventSheetResource.new())
	var passed: bool = true
	for trigger_id: String in (edges.get("EDGE_TRIGGERS") as Dictionary):
		var definition: ACEDefinition = dock._ace_registry.find_definition("Core", trigger_id)
		passed = _check("%s is registered" % trigger_id, definition != null, true) and passed
		if definition == null:
			continue
		var event: EventRow = EventRow.new()
		var trigger: ACECondition = ACECondition.new()
		trigger.provider_id = "Core"
		trigger.ace_id = trigger_id
		event.trigger = trigger
		dock._ace_apply._bake_trigger_signature(event, definition)
		passed = _check("applying %s adds one condition row" % trigger_id,
			event.conditions.size(), 1) and passed
		if event.conditions.size() != 1:
			continue
		var gate: ACECondition = event.conditions[0]
		passed = _check("the row added is %s's own gate" % trigger_id,
			gate.ace_id, str(edges.call("gate_for", trigger_id))) and passed
		# A floor gate carries its memory baked with a real uid, or the compiler declares nothing and
		# the emitted call has no function behind it.
		var wants_memory: bool = trigger_id.begins_with("OnLanded") or trigger_id.begins_with("OnLeft")
		passed = _check("%s's gate carries its own memory: %s" % [trigger_id, wants_memory],
			gate.member_declaration.contains("__was_on_floor_"), wants_memory) and passed
		passed = _check("and the uid placeholder is baked out of it",
			gate.codegen_template.contains("{uid}"), false) and passed
	dock.free()
	return passed


# ── 7. The lift ──


## The three parts a project writes by hand, and the row they open as. The memory's own name is the
## author's, so a project that calls it something else gets that name back.
static func _test_the_handwritten_landing_opens_as_the_row_it_is() -> bool:
	var passed: bool = true
	var cases: Array = [
		["is_on_floor() and not was_on_floor", "JustLanded"],
		["not grounded_last_frame and is_on_floor()", "JustLanded"],
		["was_on_floor and not is_on_floor()", "JustLeftTheGround"],
		["not is_on_floor() and previous_floor", "JustLeftTheGround"],
		["on_floor and not was_on_floor", "JustLanded"],
		["was_on_floor and not on_floor", "JustLeftTheGround"]
	]
	for entry: Variant in cases:
		var spelling: String = str((entry as Array)[0])
		var wanted: String = str((entry as Array)[1])
		var source: String = _landing_source(spelling)
		var imported: EventSheetResource = GDScriptImporter.new().import_external_source(source)
		var event: EventRow = _event_with_conditions(imported)
		passed = _check("`%s` opens as one row" % spelling, event != null, true) and passed
		if event == null:
			continue
		passed = _check("`%s` is one condition, not two halves" % spelling,
			event.conditions.size(), 1) and passed
		if event.conditions.size() != 1:
			continue
		passed = _check("`%s` is %s" % [spelling, wanted],
			(event.conditions[0] as ACECondition).ace_id, wanted) and passed
		passed = _check("`%s` keeps the author's own spelling" % spelling,
			(event.conditions[0] as ACECondition).codegen_template, spelling) and passed
		# And the EVENT reads as the moment it answers, not as "the physics step, which happens to
		# ask about landing".
		passed = _check("`%s` reads as its own trigger" % spelling,
			event.trigger_id, str(load(EDGES_PATH).call("trigger_for_gate", wanted))) and passed
	return passed


## A landing check with something else and-ed onto it means more than this row says, so it is left
## to the general reading - a row that dropped the rest of the question would not write the file back.
static func _test_a_landing_check_that_says_more_is_left_alone() -> bool:
	var lift: GDScript = load("res://addons/eventforge/importer/collision_edge_lift.gd")
	var passed: bool = true
	for spelling: String in ["is_on_floor() and not was_on_floor and hp > 0",
			"is_on_floor() and not dead", "attacking and not was_attacking"]:
		passed = _check("`%s` is not claimed" % spelling,
			(lift.call("match_whole_condition", spelling) as Dictionary).is_empty(), true) and passed
	return passed


static func _test_the_handwritten_landing_re_emits_byte_for_byte() -> bool:
	var passed: bool = true
	for spelling: String in ["is_on_floor() and not was_on_floor", "on_floor and not was_on_floor"]:
		var source: String = _landing_source(spelling)
		var imported: EventSheetResource = GDScriptImporter.new().import_external_source(source)
		imported.external_source_path = "user://eventforge_edge_trip.gd"
		passed = _check("`%s` re-emits byte for byte" % spelling,
			_compile(imported, "user://eventforge_edge_trip.gd"), source) and passed
	return passed


# ── 8. The wall that teaches ──


static func _test_a_touch_row_with_nothing_to_touch_says_what_to_add() -> bool:
	var definition: ACEDefinition = ACEDefinition.new()
	definition.provider_id = "Core"
	definition.id = "OnFirstOverlap"
	definition.category = "Collisions"
	definition.ace_type = ACEDefinition.ACEType.TRIGGER
	definition.metadata = {"node_type": "Area2D"}
	# A scene that is known, and holds nothing that can touch anything.
	var context: Dictionary = {
		"is_behavior_sheet": false, "tool_gate_wired": false, "is_tool_sheet": false,
		"scene_known": true, "has_scene": true, "scene_classes": PackedStringArray(["Sprite2D"])
	}
	var gate: Dictionary = EventSheetPickerGates.gate_for(definition, context)
	var passed: bool = _check("the entry is gated, not hidden and not silently offered",
		str(gate.get("id", "")), EventSheetPickerGates.GATE_NEEDS_TOUCH)
	passed = _check("the reason says what is missing in the family's own words",
		EventSheetPickerGates.reason_text(gate),
		"Nothing in this scene can touch anything yet - this row needs one: Area2D.") and passed
	passed = _check("and the button IS the fix",
		EventSheetPickerGates.fix_text(gate), "Add a Area2D to the scene") and passed
	passed = _check("which the dock knows how to perform",
		str(gate.get("fix_id", "")), "add_node") and passed
	# The same entry on a scene that HAS an area is offered plainly - a wall that stays up after the
	# fix is worse than no wall.
	context["scene_classes"] = PackedStringArray(["Area2D"])
	passed = _check("and it is offered plainly once the scene can touch",
		EventSheetPickerGates.gate_for(definition, context).is_empty(), true) and passed
	return passed


# ── 9. The four families, four lines ──


static func _test_every_node_family_teaches_its_own_line() -> bool:
	var filters: GDScript = load(FILTERS_PATH)
	var said: Dictionary = {}
	var passed: bool = true
	for class_text: String in ["Area2D", "CharacterBody3D", "RigidBody2D", "StaticBody3D"]:
		var note: String = str(filters.call("kind_note", class_text))
		passed = _check("%s has a line of its own" % class_text, note.is_empty(), false) and passed
		passed = _check("%s does not borrow another family's line" % class_text,
			said.has(note), false) and passed
		said[note] = class_text
	passed = _check("the four families say four different things", said.size(), 4) and passed
	passed = _check("an area's line is about noticing",
		str(filters.call("kind_note", "Area2D")).contains("area"), true) and passed
	passed = _check("a character body's is about being driven",
		str(filters.call("kind_note", "CharacterBody2D")).contains("character body"), true) and passed
	# And the lesson is owed on every touch trigger, bare, filtered or edged.
	for trigger_id: String in ["OnBodyEntered", "OnOverlapWithGroup", "OnFirstOverlap3D"]:
		passed = _check("%s is owed the lesson" % trigger_id,
			bool(filters.call("is_touch_trigger", trigger_id)), true) and passed
	passed = _check("a layer verb is not", bool(filters.call("is_touch_trigger", "BeOnLayer")), false) and passed
	return passed


# ── Harness ──


## The hand-written landing check, whole: the memory, the comparison, and the update after it.
static func _landing_source(spelling: String) -> String:
	var preamble: String = ""
	if spelling.begins_with("on_floor") or spelling.contains("not on_floor"):
		preamble = "\tvar on_floor: bool = is_on_floor()\n"
	var memory: String = "was_on_floor"
	for name: String in ["grounded_last_frame", "previous_floor"]:
		if spelling.contains(name):
			memory = name
	return "extends CharacterBody2D\n\nvar %s: bool = false\n\n\nfunc _physics_process(delta: float) -> void:\n%s\tif %s:\n\t\tprint(\"landed\")\n\t%s = is_on_floor()\n" % [
		memory, preamble, spelling, memory]


## The first event of an imported sheet that carries conditions - the `if` the fixture is about.
static func _event_with_conditions(sheet: EventSheetResource) -> EventRow:
	for entry: Variant in sheet.events:
		if entry is EventRow and not (entry as EventRow).conditions.is_empty():
			return entry as EventRow
	return null


## One event with an edge trigger, its gate baked with a fixed uid, and one thing to say.
static func _edge_event(trigger_id: String, gate_id: String, message: String) -> EventRow:
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = trigger_id
	var gate: ACECondition = ACECondition.new()
	gate.provider_id = "Core"
	gate.ace_id = gate_id
	gate.codegen_template = _template_of(gate_id).replace("{uid}", UID)
	gate.member_declaration = _member_of(gate_id).replace("{uid}", UID)
	event.conditions.append(gate)
	event.actions.append(_print(message))
	return event


static func _print(value: String) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "Print"
	action.params = {"value": value}
	return action


## The edge module's descriptors by id, read straight off the module rather than the registry so the
## shipped words and the shipped template are the ones under test.
static func _descriptors() -> Dictionary:
	var by_id: Dictionary = {}
	for descriptor: Variant in (load(EDGE_MODULE_PATH) as GDScript).call("get_descriptors"):
		if descriptor is ACEDescriptor:
			by_id[str((descriptor as ACEDescriptor).ace_id)] = descriptor
	return by_id


static func _template_of(ace_id: String) -> String:
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", ace_id)
	return "" if descriptor == null else str(descriptor.codegen_template)


static func _member_of(ace_id: String) -> String:
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", ace_id)
	return "" if descriptor == null else str(descriptor.member_template)


static func _compile(sheet: EventSheetResource, path: String) -> String:
	return str(SheetCompiler.compile(sheet, path).get("output", ""))


static func _check(label: String, got: Variant, expected: Variant) -> bool:
	if got == expected:
		return true
	print("[FAIL] collision_edge_test: %s -> expected %s, got %s" % [label, expected, got])
	return false
