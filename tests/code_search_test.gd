# Godot EventSheets - finding a row by the Godot call it writes.
#
# The promise is exact: a Godot user types `queue_free` and lands on Destroy, `is_on_floor` on Is on
# floor, `add_child` on Create object, `tween_property` on Tween property - and the GDScript is
# written beside the name so the two are visibly one thing. So the pins here are the ROW NAMES the
# real shipped vocabulary answers with, not counts and not a fixture's made-up templates.
@tool
class_name CodeSearchTest
extends RefCounted


static func run() -> bool:
	var passed: bool = true
	passed = _which_queries_are_code() and passed
	passed = _calls_a_template_writes() and passed
	passed = _the_shipped_vocabulary_answers() and passed
	passed = _the_gdscript_beside_the_name() and passed
	passed = _idiom_tables_answer_too() and passed
	return passed


static func _which_queries_are_code() -> bool:
	var passed: bool = true
	passed = _check("a snake_case call is a code query",
		EventSheetCodeSearch.is_code_query("queue_free"), true) and passed
	passed = _check("an explicit call is a code query",
		EventSheetCodeSearch.is_code_query("hide()"), true) and passed
	passed = _check("a dotted member is a code query",
		EventSheetCodeSearch.is_code_query("self.position"), true) and passed
	passed = _check("a plain word is not",
		EventSheetCodeSearch.is_code_query("destroy"), false) and passed
	passed = _check("a short word is not",
		EventSheetCodeSearch.is_code_query("hp"), false) and passed
	passed = _check("a sheet phrase is not",
		EventSheetCodeSearch.is_code_query("Set position"), false) and passed
	passed = _check("the sugar comes off",
		EventSheetCodeSearch.normalize("node.queue_free()"), "queue_free") and passed
	return passed


static func _calls_a_template_writes() -> bool:
	var passed: bool = true
	passed = _check("a call and a property are both indexed",
		" ".join(EventSheetCodeSearch.template_calls("{target.}add_child({node})\n{target.}position = {p}")),
		"add_child position") and passed
	passed = _check("an empty template writes nothing",
		" ".join(EventSheetCodeSearch.template_calls("")), "") and passed
	return passed


# ── The shipped vocabulary, asked the way a Godot user asks it ─────────────────────────────────


static func _the_shipped_vocabulary_answers() -> bool:
	var passed: bool = true
	passed = _check("queue_free leads with the row that frees an object",
		_first_hit("queue_free"), "Queue Free") and passed
	passed = _check("add_child leads with the row that adds one",
		_first_hit("add_child"), "Add Child") and passed
	passed = _check("tween_property leads with the tween row",
		_first_hit("tween_property"), "Tween Property") and passed
	passed = _check("is_on_floor leads with the floor condition",
		_first_hit("is_on_floor"), "Is On Floor") and passed
	var free_rank: int = EventSheetCodeSearch.match_rank(_definition_named("Queue Free"), "queue_free")
	var sound_rank: int = EventSheetCodeSearch.match_rank(_definition_named("Play Sound"), "queue_free")
	passed = _check("a one-call row is the row the call is about, and an incidental use ranks past it",
		[free_rank, sound_rank > EventSheetCodeSearch.RANK_INCIDENTAL], [1, true]) and passed
	return passed


static func _the_gdscript_beside_the_name() -> bool:
	var passed: bool = true
	var free_row: ACEDefinition = _definition_named("Queue Free")
	passed = _check("a call is written as a call",
		EventSheetCodeSearch.gdscript_hint(free_row, "queue_free"), "queue_free()") and passed
	passed = _check("a row that does not write the call says nothing",
		EventSheetCodeSearch.gdscript_hint(free_row, "tween_property"), "") and passed
	passed = _check("a plain-word search writes nothing beside anything",
		EventSheetCodeSearch.gdscript_hint(free_row, "destroy"), "") and passed
	return passed


static func _idiom_tables_answer_too() -> bool:
	var passed: bool = true
	passed = _check("is_on_floor is called what the reading calls it",
		EventSheetCodeSearch.idiom_words("is_on_floor"), "Is on floor") and passed
	passed = _check("is_on_wall too",
		EventSheetCodeSearch.idiom_words("is_on_wall"), "Is by wall") and passed
	passed = _check("rotation_degrees is the angle",
		EventSheetCodeSearch.idiom_words("rotation_degrees"), "angle") and passed
	passed = _check("a call no table names answers nothing",
		EventSheetCodeSearch.idiom_words("not_a_real_call"), "") and passed
	return passed


# ── Asking the real registry ──────────────────────────────────────────────────────────────────


static var _cached_registry: EventSheetACERegistry = null


static func _registry() -> EventSheetACERegistry:
	if _cached_registry == null:
		_cached_registry = EventSheetACERegistry.new()
		_cached_registry.refresh_from_sources([], true)
	return _cached_registry


static func _first_hit(query: String) -> String:
	var found: Array[ACEDefinition] = EventSheetCodeSearch.matching_definitions(
		_registry().get_all_definitions(), query)
	return found[0].display_name if not found.is_empty() else "(nothing)"


static func _definition_named(display_name: String) -> ACEDefinition:
	for definition: ACEDefinition in _registry().get_all_definitions():
		if definition.display_name == display_name:
			return definition
	return null


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] code search: %s" % label)
		return true
	print("[FAIL] code search: %s\n  expected: %s\n  actual:   %s" % [label, str(expected), str(actual)])
	return false
