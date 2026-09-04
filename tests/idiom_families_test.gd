# Godot EventSheets - the five hand-written idioms this pass taught the sheet to read, each pinned as
# VALUES on the shape a person actually writes.
#
#   1. THE INPUT-EVENT QUESTIONS.  `if event.is_action_pressed("jump"):` inside a handler, which used
#      to be Expression Is True - the honest catch-all, and the plainest thing a sheet can say about
#      the commonest input shape there is. Four spellings, both quotings, and the byte round-trip.
#   2. THE NAMED PROPERTY.         `var health: int = 100:` followed by `set = _set_health,` - the
#      older of Godot's two property spellings, whose two accessor lines are not statements and so
#      used to take the declaration above them into a code block.
#   3. THE BOUND CONNECT.          `pressed.connect(_open.bind(3))`, which the connect parser refused
#      outright, stranding the handler as a helper function nobody could see the caller of.
#   4. THE NOTIFICATION TRIGGERS.  The four cases a game really reacts to, which have lifted since the
#      notification reading shipped and had no NAME until they had descriptors.
#   5. THE PHYSICS QUERY.          The three statements the engine's own pages print for a ray asked
#      of the space state directly, which read as three unrelated declarations, and the compact
#      one-line spelling of the same question.
#
# A SIXTH FAMILY WAS LOOKED AT AND LEFT ALONE: the step of a held tween chain
# (`pop.tween_property(sprite, "scale", big, 0.12)`). It already has a reading, and the reading is
# better than an entry could be - it names the node being moved, says `opacity` where the line says
# `"modulate:a"`, carries the two modifiers as chips and puts `(after the previous)` on a step that
# follows one. An entry claiming the line takes all four of those away, because a lifted row shows
# its descriptor's own sentence and the ordering of a chain is not one of that row's values. Where
# a curated reading already outranks what a table could say, the table is the thing that does not
# get written - which is the same rule as the one that lets an entry outrank a derived row, read
# from the other end. `tween_reading_test` is where those words are pinned.
#
# WHAT IS PINNED, AND WHY IT IS PINNED THIS WAY:
#
#   The claim per line, by ENTRY ID rather than by a count. A count says a family matched something;
#   the id says WHICH spelling matched, which is the thing that breaks when a pattern is widened by
#   somebody who did not mean to.
#
#   The bytes, on every fixture. A derived row IS the line it read, so byte-exactness is structural -
#   which is exactly why it is worth proving rather than assuming.
#
#   The REFUSALS, beside the claims. A recogniser is only as good as what it declines: the polled
#   input questions that belong to another family, the bind spelling this cannot take apart, and the
#   property shapes the emitter would not write back all have to stay as they were, and a widening
#   that quietly swallows one of them fails here.
@tool
class_name IdiomFamiliesTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")

const HANDLER := "extends Node\n\n\nfunc _unhandled_input(event: InputEvent) -> void:\n"

## The named-property spelling, in both of its shapes: two accessors with the comma between them, and
## one on its own. The functions below are ordinary functions and read as such.
const NAMED_PROPERTY := """extends Node

var health: int = 100:
	set = _set_health,
	get = _get_health

var armour: int = 0:
	set = _set_armour


func _set_health(value: int) -> void:
	health = value


func _get_health() -> int:
	return health


func _set_armour(value: int) -> void:
	armour = value
"""

## A connect that binds one value, one that binds two, and one that binds nothing - the third is there
## so the widened parser is shown still reading what it always read.
const BOUND_CONNECTS := """extends Node


func _ready() -> void:
	$Button.pressed.connect(_on_pressed.bind(3))
	$Timer.timeout.connect(_on_timeout.bind("door", Vector2(0, 1)))
	$Area.body_entered.connect(_on_body_entered)


func _on_pressed(slot: int) -> void:
	print(slot)


func _on_timeout(which: String, at: Vector2) -> void:
	print(which)


func _on_body_entered(body: Node) -> void:
	print(body)
"""

## A ray asked of the physics world in both of its spellings: the three statements the manual prints,
## and the compact one line. The shape query below them is the honest code this claims nothing about.
const PHYSICS_QUERIES := """extends Node2D


func _physics_process(delta: float) -> void:
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position, Vector2(0, 100))
	query.collision_mask = 2
	var sight := space_state.intersect_ray(query)
	var ground := get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(global_position, target))
	var sweep := PhysicsShapeQueryParameters2D.new()
	var caught := get_world_2d().direct_space_state.intersect_shape(sweep, 8)
	print(sight, ground, caught)
"""

## The four questions in one handler, which is where they are written.
const INPUT_HANDLER := HANDLER \
	+ "\tif event.is_action_pressed(\"jump\"):\n\t\tprint(\"a\")\n" \
	+ "\tif event.is_action_pressed(&\"ui_down\", true):\n\t\tprint(\"b\")\n" \
	+ "\tif event.is_action_released(\"fire\"):\n\t\tprint(\"c\")\n" \
	+ "\tif event.is_action(\"aim\"):\n\t\tprint(\"d\")\n"


static func run() -> bool:
	var ok: bool = _test_the_input_event_questions()
	ok = _test_the_named_property() and ok
	ok = _test_the_bound_connect() and ok
	ok = _test_the_notification_triggers() and ok
	ok = _test_the_physics_queries() and ok
	ok = _test_the_property_refusals() and ok
	return ok


## The physics query: the run the manual prints reads as ONE row across its statements, the compact
## spelling as the same row on one line, and the shape query beside them as the code it is.
static func _test_the_physics_queries() -> bool:
	var ok: bool = SUPPORT.pin_table("idiom_families_test/physics_query_lines", {
		"var hit := get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(a, b))":
			"ray_query_line_2d",
		"var hit = get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a, b))":
			"ray_query_line_3d",
		"var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(a, b))":
			"ray_query_line_2d",
		# The cast alone, with no query built above it, is a method call and stays one.
		"var hit := space_state.intersect_ray(query)": "",
		# A shape sweep has no row that means the same job, so nothing here claims it.
		"var caught := get_world_2d().direct_space_state.intersect_shape(sweep, 8)": "",
		# A `from` written with a comma in it is one this pattern declines to take apart.
		"var hit := get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(Vector2(0, 0), b))": ""
	}, func(line: String) -> String:
		return str(EventForgePhysicsQueryLift.match_line(line).get("entry_id", "")))
	# The run, as the reading attributes it: four statements, one entry, said once per line - which is
	# what a run claiming a line at the ENTRY layer looks like, and the thing a family of runs could
	# not show at all before.
	ok = SUPPORT.pin_value("idiom_families_test", "the manual's own three statements are one claim",
		_entry_claims(PHYSICS_QUERIES),
		"ray_query_masked_run_2d | ray_query_masked_run_2d | ray_query_masked_run_2d"
		+ " | ray_query_masked_run_2d | ray_query_line_2d") and ok
	ok = SUPPORT.pin_value("idiom_families_test", "the queries save back byte for byte",
		_round_trips(PHYSICS_QUERIES), true) and ok
	return ok


## Every input-event spelling, as the entry that claims it. Both quotings answer to the SAME entry,
## because the `&` is the author's spelling rather than the row's value - which is the whole reason
## the capture grammar grew a fragment for it.
static func _test_the_input_event_questions() -> bool:
	var ok: bool = SUPPORT.pin_table("idiom_families_test/input_event_entries", {
		"event.is_action_pressed(\"jump\")": "event_action_pressed",
		"event.is_action_pressed(&\"jump\")": "event_action_pressed",
		"event.is_action_pressed(\"ui_down\", true)": "event_action_pressed_repeating",
		"event.is_action_pressed(&\"ui_down\", true)": "event_action_pressed_repeating",
		"event.is_action_released(\"fire\")": "event_action_released",
		"event.is_action(\"aim\")": "event_is_action",
		# The polled family's spellings are somebody else's rows, and stay so.
		"Input.is_action_pressed(&\"jump\")": "",
		# A press asked of something that is not the handler's event is not this question.
		"other.is_action_pressed(\"jump\")": "",
		# Nor is a press with something after it this pattern has no room for.
		"event.is_action_pressed(\"jump\", true, true)": ""
	}, func(term: String) -> String:
		return str(EventForgeInputEventLift.match_condition(term).get("entry_id", "")))
	# And the same four in a real handler, in file order, as the reading itself attributes them - so
	# the entry that claims a term on its own and the entry that claims it inside a branch are pinned
	# to be the same entry.
	ok = SUPPORT.pin_value("idiom_families_test", "the four questions are claimed by name, in order",
		_entry_claims(INPUT_HANDLER),
		"event_action_pressed | event_action_pressed_repeating | event_action_released"
		+ " | event_is_action") and ok
	ok = SUPPORT.pin_value("idiom_families_test", "the handler saves back byte for byte",
		_round_trips(INPUT_HANDLER), true) and ok
	return ok


## The named property: the declaration lifts carrying the two functions it points at, and the file
## comes back byte for byte - including the comma, which belongs to the first line only when a second
## line follows it.
static func _test_the_named_property() -> bool:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external_source(NAMED_PROPERTY,
		true, "user://eventforge_named_property.gd")
	var found: Dictionary = {}
	for entry: Variant in sheet.events:
		if entry is LocalVariable:
			var variable: LocalVariable = entry
			found[variable.name] = "%s / %s" % [variable.setter_name, variable.getter_name]
	var ok: bool = SUPPORT.pin_table("idiom_families_test/named_property", {
		"health": "_set_health / _get_health",
		"armour": "_set_armour / "
	}, func(name: String) -> String: return str(found.get(name, "MISSING")))
	var health: LocalVariable = _variable_named(sheet, "health")
	ok = SUPPORT.pin_value("idiom_families_test", "the named property saves back byte for byte",
		_round_trips(NAMED_PROPERTY), true) and ok
	ok = SUPPORT.pin_value("idiom_families_test", "a property is a property under either spelling",
		health.has_property_accessors(), true) and ok
	ok = SUPPORT.pin_value("idiom_families_test", "and this one is the named spelling",
		health.has_named_accessors(), true) and ok
	ok = SUPPORT.pin_value("idiom_families_test", "which is not the inline one",
		health.has_accessor_bodies(), false) and ok
	return ok


## The bound connect: the values are read back off the line the lift kept verbatim, and the handlers
## lift to their triggers rather than staying helper functions nobody can see the caller of.
static func _test_the_bound_connect() -> bool:
	var ok: bool = SUPPORT.pin_table("idiom_families_test/bound_values", {
		"\t$Button.pressed.connect(_on_pressed.bind(3))": "3",
		"\t$Timer.timeout.connect(_on_timeout.bind(\"door\", Vector2(0, 1)))":
			"\"door\" | Vector2(0, 1)",
		"\t$Area.body_entered.connect(_on_body_entered)": "",
		# A bind whose arguments nest deeper than one bracket is not taken apart, and its handler
		# keeps whatever reading it had.
		"\t$Ui.pressed.connect(_go.bind(make(inner(1))))": "",
		# A line that is not a connect at all is nobody's.
		"\tprint(_on_pressed.bind(3))": ""
	}, func(line: String) -> String:
		return " | ".join(EventSheetACELifter.bound_arguments(line)))
	ok = SUPPORT.pin_value("idiom_families_test", "a bound handler is a trigger, not a helper",
		_claims(BOUND_CONNECTS).contains("function _on_"), false) and ok
	ok = SUPPORT.pin_value("idiom_families_test", "the bound connects save back byte for byte",
		_round_trips(BOUND_CONNECTS), true) and ok
	return ok


## The four notifications now have descriptors, so the picker can offer them and a reader can be told
## what they are. The WORDS have to be the reading's own words: a row picked off the list and a row
## lifted out of a file are the same event, and calling them two things would make a reader ask which
## is which. Pinned as a COMPARISON of the two sources rather than as two separate pins, because two
## pins can both be edited and still disagree.
static func _test_the_notification_triggers() -> bool:
	return SUPPORT.pin_table("idiom_families_test/notification_triggers", {
		"NOTIFICATION_PAUSED": "On paused",
		"NOTIFICATION_UNPAUSED": "On unpaused",
		"NOTIFICATION_PREDELETE": "On object freed",
		"NOTIFICATION_WM_CLOSE_REQUEST": "On close",
		# One the sheet has no row for: no descriptor, and the reading still humanizes it elsewhere.
		"NOTIFICATION_WM_MOUSE_ENTER": ""
	}, func(constant: String) -> String:
		var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core",
			EventForgeNotificationACEs.PREFIX + constant)
		if descriptor == null:
			return ""
		var reading: String = str(
			EventSheetViewportReadingRows.NOTIFICATION_TRIGGER_WORDS.get(constant, ""))
		return descriptor.display_name if descriptor.display_name == reading \
			else "%s != %s" % [descriptor.display_name, reading])


## What the named-property lift DECLINES, which is half of what makes it safe to run over everybody's
## code: every shape here is one the emitter would not write back the same way, so it stays the
## verbatim block it always was.
static func _test_the_property_refusals() -> bool:
	return SUPPORT.pin_table("idiom_families_test/property_refusals", {
		# The emitter writes setter then getter, so the other order is a shape it could not put back.
		"\tget = _get_health,\n\tset = _set_health": false,
		# A comma with nothing after it.
		"\tset = _set_health,": false,
		# A name that is not one name.
		"\tset = _set_health()": false,
		"\tset = self._set_health": false,
		# The same accessor twice.
		"\tset = _a,\n\tset = _b": false,
		# And the two that are.
		"\tset = _set_health": true,
		"\tset = _set_health,\n\tget = _get_health": true
	}, func(block: String) -> bool:
		var source: String = "extends Node\n\nvar health: int = 100:\n%s\n" % block
		var sheet: EventSheetResource = GDScriptImporter.new().import_external_source(source, true,
			"user://eventforge_named_property_refusal.gd")
		for entry: Variant in sheet.events:
			if entry is LocalVariable and (entry as LocalVariable).has_named_accessors():
				return true
		return false)


# ── the pieces ──────────────────────────────────────────────────────────────────


## The lift-table entries a source's lines are claimed by, in file order - read through the same
## reading the corpus gate and the workbench panel use, so this test and those two can never disagree
## about what claimed a line.
static func _entry_claims(source: String) -> String:
	var ids: PackedStringArray = PackedStringArray()
	for line: Variant in EventSheetLiftReading.read(source).get("lines", []) as Array:
		var row: Dictionary = line
		if str(row["layer"]) == EventSheetLiftReading.LAYER_ENTRY:
			ids.append(str(row["entry_id"]))
	return " | ".join(ids)


## Every claim a source reads as, joined - for the questions that are about what is NOT there.
static func _claims(source: String) -> String:
	var names: PackedStringArray = PackedStringArray()
	for line: Variant in EventSheetLiftReading.read(source).get("lines", []) as Array:
		names.append(str((line as Dictionary)["claim"]))
	return " | ".join(names)


## True when a source opens as a sheet and saves back byte for byte.
static func _round_trips(source: String) -> bool:
	return bool(EventSheetLiftReading.read(source).get("identical", false))


static func _variable_named(sheet: EventSheetResource, name: String) -> LocalVariable:
	for entry: Variant in sheet.events:
		if entry is LocalVariable and (entry as LocalVariable).name == name:
			return entry
	return LocalVariable.new()
