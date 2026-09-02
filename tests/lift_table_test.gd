# Godot EventSheets - the recogniser TABLE, and the fixtures it writes for itself.
#
# A lift is a promise about somebody else's file: this line means that row, and saving the sheet
# writes the line back exactly as it was found. The promise is only worth making if every entry
# keeps it, and the way an entry stops keeping it is by being added without a test.
#
# So nothing here is written per entry. The harness walks EVERY family table in the importer folder,
# and for each entry it:
#   1. GENERATES the fixture line, by filling the entry's own canonical `shape` with its own sample
#      `slots` through the real emitter (ActionCodegen), not a copy of it;
#   2. asks the engine what that line means, and pins the row, the values and the stored spelling;
#   3. re-emits the row through the same emitter and asserts the bytes are the line it started from.
# An entry with no shape, no samples, or a param that is not a capture fails validation before any of
# that - which is what "an entry cannot exist untested" means in practice.
#
# The families themselves are found by SCANNING for the `lift_entries` static, so a table added by a
# later pass is covered by this file on the strength of existing. There is no list to join.
@tool
class_name LiftTableTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
## When a re-emission is refused, the evidence goes on disk instead of into a rebuild by hand.
const Repro := preload("res://tests/repro_bundle.gd")


static func run() -> bool:
	var ok: bool = true
	ok = _test_families_are_found() and ok
	ok = _test_tables_are_sound() and ok
	ok = _test_generated_fixtures() and ok
	ok = _test_the_engine() and ok
	ok = _test_a_broken_table_is_named() and ok
	return ok


## Discovery, pinned as a VALUE: the multiplayer table is found by scanning rather than by being
## named here. A family that stops being discoverable (a renamed static, a moved file) fails here
## rather than by quietly never being tested again.
static func _test_families_are_found() -> bool:
	var ok: bool = true
	var families: Dictionary = EventForgeLiftTable.families()
	ok = _check("the multiplayer table is found by scanning",
		families.has("res://addons/eventforge/importer/multiplayer_lift.gd"), true) and ok
	var empty: PackedStringArray = PackedStringArray()
	for path: String in families.keys():
		if (families[path] as Array).is_empty():
			empty.append(path)
	ok = _check("and every family found has entries", empty, PackedStringArray()) and ok
	return ok


static func _test_tables_are_sound() -> bool:
	var ok: bool = true
	for path: String in _all_tables().keys():
		ok = _check("%s is a sound table" % path.get_file(),
			EventForgeLiftTable.validate(_all_tables()[path]), PackedStringArray()) and ok
	return ok


## Every table the engine matches against: the built-in families in the importer folder, and the
## spellings the installed PACKS teach (EventForgePackSpellings). A pack's entries are ordinary lift
## entries, so they are held to the ordinary gate here rather than to one of their own - which is what
## "an entry cannot exist untested" has to mean for a table that ships from outside this folder.
static func _all_tables() -> Dictionary:
	var tables: Dictionary = EventForgeLiftTable.families()
	tables.merge(EventForgePackSpellings.tables(), true)
	return tables


## The generated corpus. Every line printed here is one this harness invented from the table itself,
## so the printout doubles as the list of spellings the plugin claims to recognise.
static func _test_generated_fixtures() -> bool:
	var ok: bool = true
	var probed: int = 0
	for path: String in _all_tables().keys():
		var script: GDScript = EventForgeLiftTable.family_script(path)
		if script != null and script.has_method(EventForgeLiftTable.FIXTURE_CONTEXT_METHOD):
			script.call(EventForgeLiftTable.FIXTURE_CONTEXT_METHOD)
		var entries: Array = _all_tables()[path]
		for entry: Dictionary in entries:
			ok = _test_one_entry(entries, entry) and ok
			probed += 1
	# A harness that walked nothing would pass every assertion above in silence.
	ok = _check("every entry of every family was probed", probed > 0, true) and ok
	return ok


## One entry, end to end. `entries` is the whole family, because the answer to "what does this line
## mean" has to be reached through the same ordered table the importer uses - an entry that is
## shadowed by an earlier one is a bug this notices.
static func _test_one_entry(entries: Array, entry: Dictionary) -> bool:
	var id: String = str(entry.get("id", ""))
	var shape: String = str(entry.get("shape", ""))
	var line: String = _emit(shape, entry.get("slots", {}))
	print("  [line] %s -> %s" % [id, line])
	var hit: Dictionary = EventForgeLiftTable.match_line(entries, line)
	var ok: bool = _check("%s: its own spelling is claimed by it" % id, str(hit.get("entry_id", "")), id)
	if not ok:
		return false
	ok = _check("%s: as the row it means" % id, str(hit.get("ace_id", "")), str(entry.get("ace_id", ""))) and ok
	ok = _check("%s: with the values the line says" % id,
		hit.get("params", {}), EventForgeLiftTable.expected_params(entry)) and ok
	ok = _check("%s: and the spelling stored on it" % id, str(hit.get("template", "")), shape) and ok
	var re_emitted: String = _emit(str(hit.get("template", "")), hit.get("params", {}))
	if re_emitted != line:
		print("  %s" % Repro.dump("lift_table_test", id, line, re_emitted))
	ok = _check("%s: re-emits byte for byte" % id, re_emitted, line) and ok
	return ok


## The engine itself, on a table written for the purpose - the mechanics the families rely on and
## none of them exercises alone.
static func _test_the_engine() -> bool:
	var table: Array = [
		{
			"id": "specific",
			"ace_id": "Specific",
			"pattern": "^set (?<name>[a-z]+) to 1$",
			"params": ["name"],
			"shape": "set {name} to 1",
			"slots": {"name": "hp"}
		},
		{
			"id": "general",
			"ace_id": "General",
			"pattern": "^set (?<name>[a-z]+) to (?<value>.+)$",
			"params": ["name", "value"],
			"shape": "set {name} to {value}",
			"slots": {"name": "hp", "value": "2"}
		},
		{
			"id": "guarded",
			"ace_id": "Guarded",
			"pattern": "^drop (?<what>[a-z]+)$",
			"guard": Callable(LiftTableTest, "_only_the_torch"),
			"shape": "drop torch",
			"slots": {}
		}
	]
	var ok: bool = _check("the earlier entry wins where two could match",
		str(EventForgeLiftTable.match_line(table, "set hp to 1").get("entry_id", "")), "specific")
	ok = _check("two values are spliced out of one line",
		EventForgeLiftTable.match_line(table, "set shield to 3 + 4"),
		{"entry_id": "general", "ace_id": "General", "provider": "Core",
			"params": {"name": "shield", "value": "3 + 4"}, "template": "set {name} to {value}"}) and ok
	# The splice runs right to left precisely so this holds: a value that looks like a slot is
	# spliced as text, never re-read.
	ok = _check("a value that looks like a slot is still just a value",
		str(EventForgeLiftTable.match_line(table, "set hp to {name}").get("params", {}).get("value", "")),
		"{name}") and ok
	ok = _check("a guard that says no leaves the line unclaimed",
		EventForgeLiftTable.match_line(table, "drop lantern"), {}) and ok
	ok = _check("and one that says yes claims it",
		str(EventForgeLiftTable.match_line(table, "drop torch").get("ace_id", "")), "Guarded") and ok
	ok = _check("a line no entry knows is nobody's", EventForgeLiftTable.match_line(table, "jump"), {}) and ok
	ok = _check("neither is a blank one", EventForgeLiftTable.match_line(table, "   "), {}) and ok
	# The indentation is the lifter's business, not the table's.
	ok = _check("a statement is matched dedented",
		str(EventForgeLiftTable.match_line(table, "\t\tset hp to 1").get("entry_id", "")), "specific") and ok
	# A REFUSAL carries a sentence and no pattern, and the empty string is a pattern that matches
	# every line ever written. One of those in one installed pack would claim every statement in
	# every opened file, so it is asked here on the lines it would have taken.
	var refused: Array = [EventForgeLiftExample.entry("bad", "method:whatever",
		"start_flickering([[oops]])")]
	ok = _check("a refused entry is a refusal, not a table",
		str((refused[0] as Dictionary).has(EventForgeLiftTable.REFUSAL_KEY)), "true") and ok
	for line: String in ["hp -= 1", "queue_free()", "$Door.open(true)"]:
		ok = _check("and it claims nothing: %s" % line,
			EventForgeLiftTable.match_line(refused, line), {}) and ok
	ok = _check("nor does an entry whose pattern is blank",
		EventForgeLiftTable.match_line([{"id": "blank", "ace_id": "A", "pattern": "",
			"shape": "", "slots": {}}], "hp -= 1"), {}) and ok
	return ok


static func _only_the_torch(captures: Dictionary) -> bool:
	return str(captures.get("what", "")) == "torch"


## Validation, by the sentences it produces. Every way an entry can be wrong is seeded once, because
## a validator nobody has watched fail is a validator that passes everything.
##
## Every entry below has its OWN spelling, so the seeded faults do not collide with each other - the
## one pair that shares a fixture line shares it deliberately, because that is one of the faults.
static func _test_a_broken_table_is_named() -> bool:
	var problems: PackedStringArray = EventForgeLiftTable.validate([
		{"id": "twin", "ace_id": "A", "pattern": "^a$", "shape": "a", "slots": {}},
		{"id": "twin", "ace_id": "A", "pattern": "^b$", "shape": "b", "slots": {}},
		{"id": "loose", "ace_id": "A", "pattern": "c", "shape": "c", "slots": {}},
		{"id": "uncaptured", "ace_id": "A", "pattern": "^a (?<one>.+)$", "params": ["two"],
			"shape": "a {two}", "slots": {"two": "x"}},
		{"id": "unsampled", "ace_id": "A", "pattern": "^d (?<one>.+)$", "params": ["one"],
			"shape": "d {one}", "slots": {}},
		{"id": "unshaped", "ace_id": "A", "pattern": "^e (?<one>.+)$", "params": ["one"],
			"shape": "e", "slots": {"one": "x"}},
		{"id": "stray", "ace_id": "A", "pattern": "^f$", "shape": "f", "slots": {}, "colour": "red"},
		{"id": "unguarded", "ace_id": "A", "pattern": "^g$", "shape": "g", "slots": {}, "guard": "nope"},
		{"id": "grouped", "ace_id": "A", "pattern": "^i (i+)$", "shape": "i", "slots": {}},
		{"id": "unbacked", "ace_id": "A", "pattern": "^j$", "shape": "j {k}", "slots": {}},
		{"id": "echo", "ace_id": "A", "pattern": "^m$", "shape": "m", "slots": {}},
		{"id": "echo_again", "ace_id": "A", "pattern": "^n$", "shape": "m", "slots": {}},
		EventForgeLiftExample.entry("by_example", "A", ""),
		{"ace_id": "A", "pattern": "^z$", "shape": "z"}
	])
	return _check("every broken entry is named, and why", problems, PackedStringArray([
		"twin: two entries share this id",
		"loose: the pattern must anchor to the whole statement (^…$)",
		"uncaptured: two is a param with no capture group of that name",
		"unsampled: no sample value for {one}",
		"unshaped: the shape has no {one} for the sample value",
		"unshaped: one is neither in the shape nor given a default",
		"stray: unknown key colour",
		"unguarded: the guard is not a callable",
		"grouped: every group in the pattern must be named or non-capturing",
		"unbacked: the shape's {k} is backed by no capture",
		"echo_again: its fixture line is already echo's",
		"by_example: refused - the example is empty",
		"(unnamed entry): no id",
		"(unnamed entry): no slots"
	]))


## One row's line, through the compiler's own emitter - never a copy of the substitution. A fixture
## the harness wrote with its own `replace()` would agree with itself and prove nothing.
static func _emit(template: String, params: Dictionary) -> String:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.codegen_template = template
	action.params = params.duplicate()
	return ActionCodegen.generate_action(action)


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("lift_table_test", label, actual, expected)
