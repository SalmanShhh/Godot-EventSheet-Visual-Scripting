# Godot EventSheets - the FORWARDING ADDRESSES, and the fixtures they write for themselves.
#
# A forwarding address is a promise about somebody's existing sheet: the row you already wrote can be
# rewritten as this other row, and land complete. The promise is only worth making if every address
# keeps it, and the way an address stops keeping it is by being added without a test.
#
# So nothing here is written per address. The harness walks EVERY successor map in the installed
# vocabulary - built-ins and packs alike - and for each one it:
#   1. BUILDS a row on the old spelling, filling each of its parameters with the value the verb
#      itself starts on, or a sample where the verb asks the author to say;
#   2. applies the rewrite the map describes, resolved to the end of its chain;
#   3. emits the successor row through the REAL emitter (ActionCodegen / ConditionCodegen), and
#      compiles it inside a one-row sheet through the real compiler, and pins that the two agree;
#   4. checks that every value the old row carried arrived, that no slot was left unfilled, and that
#      emitting twice writes the same byte.
# A map that names a verb nobody has, points at itself, joins a cycle, renames a parameter neither
# side has, or leaves a successor parameter unanswered fails `problems()` before any of that - which
# is what "an address cannot exist untested" means in practice, and is the same list the pack gate
# refuses to ship on.
@tool
class_name SuccessorMapTest
extends RefCounted

## The token a parameter the old verb asks the author to fill gets in the generated fixture. An
## identifier rather than prose, so the emitted line is a line somebody could have written.
const SAMPLE_PREFIX: String = "mg_"


static func run() -> bool:
	var ok: bool = true
	ok = _test_the_vocabulary_is_sound() and ok
	ok = _test_the_annotation() and ok
	ok = _test_the_builder() and ok
	ok = _test_the_first_customer() and ok
	ok = _test_the_sheet_says_it_quietly() and ok
	ok = _test_generated_fixtures() and ok
	ok = _test_the_engine() and ok
	ok = _test_a_broken_map_is_named() and ok
	return ok


## The whole installed vocabulary, held to the gate the pack audit fails on. Empty is the only
## shipping state.
static func _test_the_vocabulary_is_sound() -> bool:
	var known: Dictionary = EventForgeSuccessors.catalog()
	var ok: bool = _check("the vocabulary is found", known.size() > 100, true)
	ok = _check("every forwarding address in it is sound",
		EventForgeSuccessors.problems(known), PackedStringArray()) and ok
	return ok


## The annotation route, read the way the editor reads it: off a REAL file. A GDScript built from a
## source string in memory has no `resource_path`, and the analyzer reads annotations off disk - so a
## round-trip written that way would pass for the wrong reason.
static func _test_the_annotation() -> bool:
	var path: String = "user://_successor_annotation_probe.gd"
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("\n".join(PackedStringArray([
		"@tool",
		"extends RefCounted",
		"",
		"",
		"## @ace_action",
		"## @ace_name(\"Travel to state\")",
		"## @ace_succeeded_by(Core::GoToState, renames: destination=state, defaults: seconds=1.0)",
		"func travel_to_state(destination: String) -> void:",
		"\tprint(destination)",
		"",
	])))
	file.close()
	var script: GDScript = load(path)
	var ok: bool = _check("the probe script loads", script != null, true)
	if not ok:
		return false
	var generator: EventSheetACEGenerator = EventSheetACEGenerator.new()
	var carried: Dictionary = {}
	for definition: ACEDefinition in generator.generate_from_object(script.new()):
		if definition.id == "method:travel_to_state":
			carried = EventForgeSuccessors.map_of(definition)
	ok = _check("the annotation says the three things and no more", carried,
		{"id": "Core::GoToState", "renames": {"destination": "state"}, "defaults": {"seconds": "1.0"}}) and ok
	DirAccess.remove_absolute(path)
	# And the grammar's edges, asked of the reader directly rather than through a file each time.
	var analyzer: EventSheetSemanticAnalyzer = EventSheetSemanticAnalyzer.new()
	ok = _check("the id may be written with its key",
		analyzer._parse_successor_spec("id: Core::GoToState"),
		{"id": "Core::GoToState", "renames": {}, "defaults": {}}) and ok
	ok = _check("several pairs split on the bar, not the comma",
		analyzer._parse_successor_spec("P::B, renames: one=two|three=four"),
		{"id": "P::B", "renames": {"one": "two", "three": "four"}, "defaults": {}}) and ok
	ok = _check("and an annotation naming no successor is not an address",
		analyzer._parse_successor_spec("renames: one=two"), {}) and ok
	return ok


## The builder route - the built-in half of the same fact, set where the descriptor is CONSTRUCTED
## because descriptors are normalized once and shared for the whole session.
static func _test_the_builder() -> bool:
	var descriptor: ACEDescriptor = ACEDescriptor.new()
	var ok: bool = _check("a verb with no address has no map", descriptor.successor_map(), {})
	descriptor.succeeded_by("Core::GoToState", {"next": "state"}, {"seconds": "1.0"})
	ok = _check("and .succeeded_by() writes the same three keys the annotation does",
		descriptor.successor_map(),
		{"id": "Core::GoToState", "renames": {"next": "state"}, "defaults": {"seconds": "1.0"}}) and ok
	ok = _check("a forwarding address is not a deprecation", descriptor.is_deprecated, false) and ok
	ok = _check("and says nothing in the deprecation note", descriptor.deprecation_note(), "") and ok
	return ok


## The first address the plugin ever shipped, pinned as VALUES: the State Machine pack's two
## superseded verbs point at the object-state vocabulary, with the one parameter each of them
## renames. The other two verbs of that pack deliberately point nowhere - Time in state is an
## expression the object-state family has no twin for, and On any state change names no single state
## - so their absence is pinned too, because a later pass adding an address there should have to say
## so out loud.
static func _test_the_first_customer() -> bool:
	var known: Dictionary = EventForgeSuccessors.catalog()
	var ok: bool = _check("Go to state points at the object-state Go to",
		EventForgeSuccessors.resolve("StateMachineBehavior::method:set_state", known),
		{"id": "Core::GoToState", "renames": {"next": "state"}, "defaults": {},
			"hops": PackedStringArray(["Core::GoToState"])})
	ok = _check("Current state is points at the object-state Is in",
		EventForgeSuccessors.resolve("StateMachineBehavior::method:is_in_state", known),
		{"id": "Core::InState", "renames": {"state_name": "state"}, "defaults": {},
			"hops": PackedStringArray(["Core::InState"])}) and ok
	ok = _check("Time in state points nowhere - the newer family has no expression twin",
		EventForgeSuccessors.resolve("StateMachineBehavior::method:time_in_state", known), {}) and ok
	ok = _check("and neither does On any state change, which names no one state",
		EventForgeSuccessors.resolve("StateMachineBehavior::signal:state_changed", known), {}) and ok
	# The pack itself is untouched by any of this: same ids, same templates, same emitted call.
	var go_to: Dictionary = known["StateMachineBehavior::method:set_state"]
	ok = _check("and the superseded verb keeps the template it always had",
		str(go_to["template"]), "{target}.set_state({next})") and ok
	return ok


## THE QUIET SHEET LAW, asked of the one thing this slice puts on screen. A row written in the older
## spelling grows NOTHING in the sheet: no block, no icon, no inline text, not even the amber state,
## because it is not wrong and still compiles exactly as written. The single place it is mentioned is
## the help strip once the row is selected, where it reads muted and offers no door.
static func _test_the_sheet_says_it_quietly() -> bool:
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnReady"
	var action: ACEAction = ACEAction.new()
	action.provider_id = "StateMachineBehavior"
	action.ace_id = "method:set_state"
	action.params = {"target": "$StateMachineBehavior", "next": "\"chasing\""}
	event.actions.append(action)
	sheet.events.append(event)
	dock.setup(sheet)
	var row: EventRowData = dock._viewport._root_rows[0]
	var ok: bool = _check("the row in the older spelling knows where the newer one is",
		row.successor_hint, "newer spelling: Go To State")
	ok = _check("but wears no amber state", row.attention_note, "") and ok
	ok = _check("and hangs nothing under itself", row.children.size(), 0) and ok
	dock._update_row_help_strip(row)
	ok = _check("selecting it puts the muted line on the strip",
		dock._row_help_label.text, "newer spelling: Go To State") and ok
	ok = _check("and shows it", dock._row_help_label.visible, true) and ok
	ok = _check("muted rather than in the warning colour",
		dock._row_help_label.modulate, EventSheetActiveTheme.reading().muted_text_color) and ok
	# No door: following an address is an edit somebody approves, offered from the head band, not a
	# button under one row.
	ok = _check("with no door beside it", dock._row_help_button.visible, false) and ok
	dock._update_row_help_strip(EventRowData.new())
	ok = _check("and a row whose verb is the current one says nothing at all",
		dock._row_help_label.visible, false) and ok
	dock.free()
	return ok


## The generated corpus. Every line printed here is one this harness invented from the map itself,
## so the printout doubles as the list of rewrites the plugin claims it can make.
static func _test_generated_fixtures() -> bool:
	var known: Dictionary = EventForgeSuccessors.catalog()
	var ok: bool = true
	var probed: int = 0
	var keys: PackedStringArray = PackedStringArray()
	for key: Variant in known.keys():
		if not EventForgeSuccessors.normalize_map((known[key] as Dictionary).get("map", {})).is_empty():
			keys.append(str(key))
	keys.sort()
	for key: String in keys:
		ok = _test_one_map(key, known) and ok
		probed += 1
	# A harness that walked nothing would pass every assertion above in silence.
	ok = _check("every forwarding address was probed", probed > 0, true) and ok
	return ok


## One address, end to end.
static func _test_one_map(key: String, known: Dictionary) -> bool:
	var entry: Dictionary = known[key]
	var resolved: Dictionary = EventForgeSuccessors.resolve(key, known)
	var ok: bool = _check("%s: resolves to the end of its chain" % key, not resolved.is_empty(), true)
	if not ok:
		return false
	var successor_key: String = str(resolved[EventForgeSuccessors.KEY_ID])
	var successor: Dictionary = known[successor_key]
	var old_params: Dictionary = _sample_params(entry)
	var old_line: String = _emit(str(entry["template"]), old_params, int(entry["ace_type"]))
	var new_params: Dictionary = EventForgeSuccessors.rewrite_params(old_params, resolved,
		successor.get("params", PackedStringArray()))
	var new_line: String = _emit(str(successor["template"]), new_params, int(successor["ace_type"]))
	print("  [rewrite] %s -> %s" % [old_line, new_line])
	# Nothing left unfilled: a slot still showing in the emitted line is a parameter the map does not
	# answer, which is a row that would land with a hole in it.
	var unfilled: PackedStringArray = PackedStringArray()
	for parameter: String in successor.get("params", PackedStringArray()):
		if new_line.contains("{%s}" % parameter):
			unfilled.append(parameter)
	ok = _check("%s: the rewritten row has no unfilled slot" % key, unfilled, PackedStringArray()) and ok
	# And every value the old row carried arrives under its new name - the whole point of a rename.
	var lost: PackedStringArray = PackedStringArray()
	for old_name: Variant in (resolved[EventForgeSuccessors.KEY_RENAMES] as Dictionary).keys():
		var carried: String = str(old_params.get(old_name, "")).strip_edges()
		if carried.is_empty() or not old_params.has(old_name):
			continue
		if not new_line.contains(carried):
			lost.append("%s -> %s" % [str(old_name), str((resolved[EventForgeSuccessors.KEY_RENAMES] as Dictionary)[old_name])])
	ok = _check("%s: every renamed value arrives" % key, lost, PackedStringArray()) and ok
	# Emission is deterministic: the same row writes the same byte every time it is asked.
	ok = _check("%s: emits the same byte twice" % key,
		_emit(str(successor["template"]), new_params, int(successor["ace_type"])), new_line) and ok
	# And the line the migrate receipt would show is the line the FILE would get - proved by putting
	# the rewritten row through the compiler rather than by trusting the emitter twice.
	ok = _check("%s: the compiled sheet carries that exact line" % key,
		_compiles_to(successor_key, successor, new_params, new_line), true) and ok
	return ok


## The values a fixture row starts on: what the verb itself declares, and a sample where the verb
## leaves the answer to the author (a blank default means "a row must say which", and a fixture that
## honoured the blank would prove nothing about whether the value travels).
static func _sample_params(entry: Dictionary) -> Dictionary:
	var declared: Dictionary = entry.get("declared_defaults", {})
	var filled: Dictionary = {}
	for parameter: String in entry.get("params", PackedStringArray()):
		var value: String = str(declared.get(parameter, "")).strip_edges()
		filled[parameter] = value if not value.is_empty() else "%s%s" % [SAMPLE_PREFIX, parameter]
	return filled


## One row's line, through the compiler's own emitters - never a copy of the substitution. A fixture
## the harness wrote with its own `replace()` would agree with itself and prove nothing.
static func _emit(template: String, params: Dictionary, ace_type: int) -> String:
	if ace_type == ACEDefinition.ACEType.CONDITION:
		var condition: ACECondition = ACECondition.new()
		condition.provider_id = "Core"
		condition.codegen_template = template
		condition.params = params.duplicate()
		return ConditionCodegen.generate_condition(condition)
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.codegen_template = template
	action.params = params.duplicate()
	return ActionCodegen.generate_action(action)


## Whether a one-row sheet holding the rewritten row compiles, and whether the GDScript it wrote
## really does carry the emitted line. This is the byte gate the migrate dialog runs before it
## commits, asked here of every address the vocabulary ships.
static func _compiles_to(successor_key: String, successor: Dictionary, params: Dictionary, line: String) -> bool:
	var address: PackedStringArray = EventForgeSuccessors.split_key(successor_key)
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.custom_class_name = "SuccessorFixture"
	sheet.host_class = "Node"
	var event: EventRow = EventRow.new()
	if int(successor["ace_type"]) == ACEDefinition.ACEType.CONDITION:
		var condition: ACECondition = ACECondition.new()
		condition.provider_id = address[0]
		condition.ace_id = address[1]
		condition.codegen_template = str(successor["template"])
		condition.params = params.duplicate()
		event.conditions.append(condition)
		# A condition needs something to do when it is true, or the event has no body to emit.
		var body: ACEAction = ACEAction.new()
		body.provider_id = "Core"
		body.codegen_template = "pass"
		event.actions.append(body)
	else:
		var action: ACEAction = ACEAction.new()
		action.provider_id = address[0]
		action.ace_id = address[1]
		action.codegen_template = str(successor["template"])
		action.params = params.duplicate()
		event.actions.append(action)
	sheet.events.append(event)
	var compiled: Dictionary = SheetCompiler.compile(sheet, "user://_successor_map_fixture.gd")
	if not bool(compiled.get("success", false)):
		print("  [why] %s did not compile: %s" % [successor_key, str(compiled.get("errors", []))])
		return false
	var written: String = str(compiled.get("output", ""))
	if written.contains(line):
		return true
	print("  [why] %s compiled without its own line: %s" % [successor_key, line])
	return false


## The engine itself, on maps written for the purpose - the mechanics the shipped addresses rely on
## and none of them exercises alone.
static func _test_the_engine() -> bool:
	var known: Dictionary = _table()
	# A chain resolves to its END, with the renames composed through the middle and the middle's own
	# default carried along and re-keyed on the way.
	var ok: bool = _check("a chain resolves to the last verb in it",
		EventForgeSuccessors.resolve("P::A", known),
		{"id": "P::C", "renames": {"one": "three"}, "defaults": {"extra": "1.0"},
			"hops": PackedStringArray(["P::B", "P::C"])})
	ok = _check("and one hop is left exactly as it was authored",
		EventForgeSuccessors.resolve("P::B", known),
		{"id": "P::C", "renames": {"two": "three"}, "defaults": {"extra": "1.0"},
			"hops": PackedStringArray(["P::C"])}) and ok
	ok = _check("a verb with no address answers nothing",
		EventForgeSuccessors.resolve("P::C", known), {}) and ok
	ok = _check("nor does a key the vocabulary has never heard of",
		EventForgeSuccessors.resolve("P::Nobody", known), {}) and ok
	ok = _check("a cycle answers nothing rather than looping",
		EventForgeSuccessors.resolve("P::Ring", known), {}) and ok
	# The rewrite itself: values move to their new names, new parameters get their value, and a
	# parameter the successor does not have is left behind rather than carried as baggage.
	ok = _check("the rewrite renames, fills and drops",
		EventForgeSuccessors.rewrite_params({"one": "hp", "gone": "9"},
			EventForgeSuccessors.resolve("P::A", known), PackedStringArray(["three", "extra"])),
		{"three": "hp", "extra": "1.0"}) and ok
	ok = _check("and a row already holding a value keeps it over the default",
		EventForgeSuccessors.rewrite_params({"two": "hp", "extra": "9.0"},
			EventForgeSuccessors.resolve("P::B", known), PackedStringArray(["three", "extra"])),
		{"three": "hp", "extra": "9.0"}) and ok
	ok = _check("the two halves of a key come apart",
		EventForgeSuccessors.split_key("Core::GoToState"), PackedStringArray(["Core", "GoToState"])) and ok
	ok = _check("and a bare id is a built-in",
		EventForgeSuccessors.split_key("GoToState"), PackedStringArray(["Core", "GoToState"])) and ok
	ok = _check("an address with no destination is not an address",
		EventForgeSuccessors.normalize_map({"id": "  "}), {}) and ok
	return ok


## Every way a map can be wrong, each said once and named. A gate that stopped detecting these would
## report a clean vocabulary while shipping rewrites that land blank.
static func _test_a_broken_map_is_named() -> bool:
	return _check("every broken address is named, and why",
		EventForgeSuccessors.problems(_broken_table()), PackedStringArray([
			"P::Blank: nothing answers P::C's three, so a rewritten row would land blank",
			"P::Itself: succeeded by itself",
			"P::Renamer: renames nothing_here, which it has no parameter called",
			"P::Renamer: renames one to elsewhere, which P::C has no parameter called",
			"P::Renamer: nothing answers P::C's three, so a rewritten row would land blank",
			"P::Ring: the chain comes back to itself (P::Ring -> P::Round -> P::Ring)",
			"P::Round: the chain comes back to itself (P::Round -> P::Ring -> P::Round)",
			"P::Stranger: succeeded by P::Nobody, which no installed vocabulary has",
			"P::Twice: gives three both a renamed value and a default",
		]))


## A sound little vocabulary: A -> B -> C, plus a verb that cycles.
static func _table() -> Dictionary:
	return {
		"P::A": _entry("P::A", ["one"], {"id": "P::B", "renames": {"one": "two"}, "defaults": {}}),
		"P::B": _entry("P::B", ["two"], {"id": "P::C", "renames": {"two": "three"}, "defaults": {"extra": "1.0"}}),
		"P::C": _entry("P::C", ["three", "extra"], {}),
		"P::Ring": _entry("P::Ring", ["one"], {"id": "P::Round", "renames": {"one": "one"}, "defaults": {}}),
		"P::Round": _entry("P::Round", ["one"], {"id": "P::Ring", "renames": {"one": "one"}, "defaults": {}}),
	}


## And every way of being wrong, one verb each.
static func _broken_table() -> Dictionary:
	var table: Dictionary = _table()
	table["P::Itself"] = _entry("P::Itself", ["one"], {"id": "P::Itself", "renames": {}, "defaults": {}})
	table["P::Stranger"] = _entry("P::Stranger", ["one"], {"id": "P::Nobody", "renames": {}, "defaults": {}})
	table["P::Renamer"] = _entry("P::Renamer", ["one"],
		{"id": "P::C", "renames": {"one": "elsewhere", "nothing_here": "three"}, "defaults": {"extra": "1.0"}})
	table["P::Blank"] = _entry("P::Blank", ["one"], {"id": "P::C", "renames": {}, "defaults": {"extra": "1.0"}})
	table["P::Twice"] = _entry("P::Twice", ["one"],
		{"id": "P::C", "renames": {"one": "three"}, "defaults": {"three": "x", "extra": "1.0"}})
	return table


## One entry in the shape the catalogue holds them, with every parameter asking to be answered - the
## strict case, so a map that leaves one blank is caught rather than excused by a default.
static func _entry(key: String, params: Array, map: Dictionary) -> Dictionary:
	return {
		"key": key,
		"name": key,
		"template": "",
		"ace_type": ACEDefinition.ACEType.ACTION,
		"params": PackedStringArray(params),
		"declared_defaults": {},
		"answered_by_default": PackedStringArray(),
		"map": map,
	}


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] successor_map_test: %s" % label)
		return true
	print("[FAIL] successor_map_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
