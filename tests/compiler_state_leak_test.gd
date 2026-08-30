# Godot EventSheets - nothing a compile leaves behind may change the next one.
#
# The compiler keeps a handful of statics as per-compile working state (the breakpoint flag, the group
# maps, the behaviour host default). They are shared process-wide, so anything one compile forgets to
# clear is standing when the next caller arrives - and the damage never surfaces where it was done. A
# behaviour compile that left `host` standing made the importer's byte gate emit `host.move_and_slide()`
# for a file spelling `move_and_slide()`, so an unrelated script opened minutes later fell back to
# verbatim blocks with nothing in either place naming the cause.
#
# That one case is pinned where the idiom lives (host_target_codegen_test). THIS is the sweep that
# would have caught it before it shipped, and catches the next one: every static the compiler and its
# emitters declare is found by REFLECTION (no list to keep), poisoned one at a time, and every public
# emission entry point is asked to produce its output again. The output must not move. A static that
# genuinely outlives a compile says so in DURABLE_STATICS, with the reason.
#
# The sweep is only worth what it can fail on, so it is pointed at a deliberately leaky emitter once
# (see _test_the_sweep_can_fail) and asked to name it.
@tool
class_name CompilerStateLeakTest
extends RefCounted

## The scripts whose statics are swept. The compiler and everything it emits through: a cache in the
## action emitter would leak exactly as far as one in the compiler itself.
const EMITTER_SCRIPTS: Array[String] = [
	"res://addons/eventforge/compiler/sheet_compiler.gd",
	"res://addons/eventforge/compiler/action_codegen.gd",
	"res://addons/eventforge/compiler/condition_codegen.gd",
	"res://addons/eventforge/compiler/trigger_resolver.gd",
	"res://addons/eventforge/compiler/line_row_mapper.gd"
]

## The statics that are NOT per-compile working state, and why. An override list, so a static added later
## defaults to being swept rather than to being trusted.
const DURABLE_STATICS: Dictionary = {
	"_compile_mutex": "the lock itself - serializing compiles is what protects the working state below",
	"_template_re": "a compiled RegEx cached for the session; it has no per-compile state"
}

## Every working-state static the sweep expects to find, pinned as a VALUE rather than counted. A static
## added to the compiler shows up here as a failure with its own name in it, which is the moment to
## decide whether it is working state (leave it swept) or durable (name it above, with the reason).
const SWEPT_STATICS: Array[String] = [
	"_behavior_host_default", "_emit_breakpoints_flag", "_emit_event_trace_flag",
	"_error_reporter_pending", "_group_slugs", "_live_values_payload",
	"_live_values_receiver_pending", "_removal_guard_facts", "_row_group_path",
	"_runtime_group_guards", "_runtime_group_members", "_throttle_process_emitted",
	"_trouble_reporter_pending"
]

## The public statics of the compiler that are not emission entry points: pure answers about a row, a
## group name or a table enum, with no working state behind them. Listed so that a NEW public entry point
## fails this file until somebody decides which it is.
const PURE_HELPERS: Array[String] = [
	"condition_source_text", "group_declaration_lines", "guard_token", "static_local_declaration",
	"table_enum_entry", "table_enum_key", "table_enum_label", "table_enum_options",
	"table_enum_pair", "table_enum_type", "variable_emit_order"
]

## What a poisoned static is set to, by type. Any value that is not the default will do - what
## matters is that the emitters cannot tell the difference in what they write.
const POISON: Dictionary = {
	TYPE_BOOL: true,
	TYPE_INT: 4242,
	TYPE_STRING: "__leaked__",
	TYPE_DICTIONARY: {"__leaked__": "__leaked__"},
	TYPE_ARRAY: ["__leaked__"]
}


static func run() -> bool:
	var ok: bool = true
	ok = _test_the_swept_set() and ok
	ok = _test_every_public_entry_point_is_covered() and ok
	ok = _test_no_leftover_changes_an_emission() and ok
	ok = _test_a_behaviour_compile_leaves_a_plain_file_alone() and ok
	ok = _test_the_sweep_can_fail() and ok
	return ok


## Where the probes' own compiles land. Under `user://`, because a compile with no output path
## writes to the sheet's own source and a sheet naming none lands in the project root.
const UNNAMED_OUTPUT: String = "user://__eventsheets_state_leak_probe.gd"


## The swept set, by name. Reflection finds the statics; this pins which ones they are, so the day
## one is added is the day somebody reads this list.
static func _test_the_swept_set() -> bool:
	var found: Array[String] = []
	for entry: Dictionary in _working_statics():
		found.append(str(entry["name"]))
	found.sort()
	var expected: Array[String] = SWEPT_STATICS.duplicate()
	expected.sort()
	return _check("the compiler's working-state statics are the ones this sweep knows about", found, expected)


## Coverage of the entry points themselves: every public static the compiler offers is either swept
## as an emission path or named as a pure helper.
static func _test_every_public_entry_point_is_covered() -> bool:
	var script: Object = load(EMITTER_SCRIPTS[0])
	var public_statics: Array[String] = []
	for entry: Dictionary in script.get_script_method_list():
		var method_name: String = str(entry.get("name", ""))
		if method_name.begins_with("_") or int(entry.get("flags", 0)) & METHOD_FLAG_STATIC == 0:
			continue
		public_statics.append(method_name)
	public_statics.sort()
	var covered: Array[String] = PURE_HELPERS.duplicate()
	for runner: Dictionary in _emission_runners():
		if not covered.has(str(runner["entry_point"])):
			covered.append(str(runner["entry_point"]))
	covered.sort()
	return _check("every public compiler entry point is swept or declared pure", public_statics, covered)


## The sweep. One poisoned static at a time, every emission path re-run, every output compared with
## the one the same path produced from a clean start.
static func _test_no_leftover_changes_an_emission() -> bool:
	var ok: bool = true
	for runner: Dictionary in _emission_runners():
		var leaks: PackedStringArray = _sweep(runner["emit"] as Callable)
		ok = _check("%s writes the same file whatever a previous compile left behind" % str(runner["name"]),
			leaks, PackedStringArray()) and ok
	return ok


## The regression this generalises, end to end and in its own words: compile a behaviour sheet (which
## sets the host default), then put a plain file through EVERY public emission path.
static func _test_a_behaviour_compile_leaves_a_plain_file_alone() -> bool:
	var ok: bool = true
	for runner: Dictionary in _emission_runners():
		var emit: Callable = runner["emit"]
		_restore(_defaults())
		var clean: String = emit.call()
		_compile_a_behaviour_sheet()
		ok = _check("%s is unchanged by a behaviour compile before it" % str(runner["name"]),
			emit.call(), clean) and ok
		ok = _check("%s writes the bare call an opened file spells" % str(runner["name"]),
			emit.call().contains("host.move_and_slide()"), false) and ok
	_restore(_defaults())
	return ok


## The sweep pointed at an emitter that really does read its leftovers, to prove it can say so. A
## gate nobody has watched fail is a gate that passes everything.
static func _test_the_sweep_can_fail() -> bool:
	var leaky: Callable = func() -> String:
		return "velocity = %s" % str((load(EMITTER_SCRIPTS[0]) as Object).get("_behavior_host_default"))
	var leaks: PackedStringArray = _sweep(leaky)
	return _check("an emitter that reads its leftovers is named, with the static that changed it",
		leaks, PackedStringArray(["_behavior_host_default (sheet_compiler.gd)"]))


# ── the machinery ───────────────────────────────────────────────────────────────


## Every static that is not declared durable, as {script, script_name, name, type}. Found by
## reflection over the emitter scripts, so the sweep cannot fall behind the compiler.
static func _working_statics() -> Array[Dictionary]:
	var statics: Array[Dictionary] = []
	for path: String in EMITTER_SCRIPTS:
		var script: Object = load(path)
		if script == null:
			continue
		for entry: Dictionary in script.get_property_list():
			var property_name: String = str(entry.get("name", ""))
			if int(entry.get("usage", 0)) & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
				continue
			if DURABLE_STATICS.has(property_name):
				continue
			statics.append({"script": script, "script_name": path.get_file(),
				"name": property_name, "type": int(entry.get("type", 0))})
	return statics


## One emission path per entry: what to call it, which public static it goes through, and a callable
## that emits a fixed probe through it. `compile` appears twice because its two branches are two
## different emitters - a sheet the plugin owns, and a `.gd` file the user does.
static func _emission_runners() -> Array[Dictionary]:
	var plain: EventSheetResource = _plain_sheet()
	var opened: EventSheetResource = _opened_sheet()
	var mover: EventFunction = _probe_function()
	return [
		{
			"name": "a compiled sheet", "entry_point": "compile",
			"emit": func() -> String: return str(SheetCompiler.compile(plain, "").get("output", ""))
		},
		{
			"name": "an opened .gd saved back", "entry_point": "compile",
			"emit": func() -> String: return str(SheetCompiler.compile(opened, "").get("output", ""))
		},
		{
			"name": "the lift's function-block gate", "entry_point": "emit_function_block_text",
			"emit": func() -> String: return SheetCompiler.emit_function_block_text(mover, plain)
		},
		{
			"name": "the lift's anchored-handler gate", "entry_point": "emit_anchored_trigger_text",
			"emit": func() -> String: return SheetCompiler.emit_anchored_trigger_text(mover.events)
		}
	]


## Runs one emitter clean, then once per poisoned static, and names every static that moved the
## output. Restores the working state it found before returning, so no test after this one inherits a
## poisoned compiler.
static func _sweep(emit: Callable) -> PackedStringArray:
	var defaults: Dictionary = _defaults()
	_restore(defaults)
	var clean: String = emit.call()
	var leaks: PackedStringArray = PackedStringArray()
	for entry: Dictionary in _working_statics():
		if not POISON.has(int(entry["type"])):
			leaks.append("%s (%s): no poison value for type %d" % [str(entry["name"]),
				str(entry["script_name"]), int(entry["type"])])
			continue
		_restore(defaults)
		(entry["script"] as Object).set(str(entry["name"]), _poison_for(int(entry["type"])))
		if emit.call() != clean:
			leaks.append("%s (%s)" % [str(entry["name"]), str(entry["script_name"])])
	_restore(defaults)
	return leaks


## A fresh copy of every poison value, because a Dictionary or Array handed to a compiler that keeps
## it would be the same object the next probe reads.
static func _poison_for(type_id: int) -> Variant:
	var value: Variant = POISON[type_id]
	return value.duplicate() if value is Dictionary or value is Array else value


## The value every working-state static holds after a clean compile - snapshotted rather than assumed, so
## the sweep restores what it found instead of what it thinks the defaults are.
static func _defaults() -> Dictionary:
	SheetCompiler.compile(_plain_sheet(), "")
	var snapshot: Dictionary = {}
	for entry: Dictionary in _working_statics():
		snapshot["%s/%s" % [str(entry["script_name"]), str(entry["name"])]] = (entry["script"] as Object).get(str(entry["name"]))
	return snapshot


static func _restore(defaults: Dictionary) -> void:
	for entry: Dictionary in _working_statics():
		var key: String = "%s/%s" % [str(entry["script_name"]), str(entry["name"])]
		if defaults.has(key):
			var value: Variant = defaults[key]
			(entry["script"] as Object).set(str(entry["name"]),
				value.duplicate() if value is Dictionary or value is Array else value)


# ── the probes ──────────────────────────────────────────────────────────────────


## The sheet every runner emits: one node-scoped call, which is the one an escaped host default
## rewrites.
static func _plain_sheet() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "CharacterBody2D"
	sheet.custom_class_name = "StateLeakProbe"
	sheet.functions = [_probe_function()]
	# Under `user://` for the same reason the opened sheet's source path is: compiling with no output
	# path writes the result to the sheet's own source, and a plain sheet that names none lands in the
	# PROJECT ROOT - a script left in the repository, which the next gate to sweep every file of it
	# reports as a real one. The probes are about emitted TEXT; where it lands is nobody's question.
	sheet.external_source_path = UNNAMED_OUTPUT
	return sheet


## A `.gd`-backed sheet: the branch of compile() that returns before the main path's reset runs, and
## the one whose output has to reproduce the user's file byte for byte. The source path is under
## `user://` on purpose - compiling with no output path WRITES to the sheet's own external source, so
## a probe pointed at a fixture would rewrite the repository as a side effect of being tested.
static func _opened_sheet() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.external_source_path = "user://state_leak_probe_source.gd"
	sheet.host_class = "CharacterBody2D"
	var block: RawCodeRow = RawCodeRow.new()
	block.code = "extends CharacterBody2D\n\n\nfunc step() -> void:\n\tmove_and_slide()"
	sheet.events = [block]
	return sheet


static func _probe_function() -> EventFunction:
	var slide: ACEAction = ACEAction.new()
	slide.provider_id = "Core"
	slide.ace_id = "MoveAndSlide"
	slide.enabled = true
	var row: EventRow = EventRow.new()
	row.actions = [slide]
	var mover: EventFunction = EventFunction.new()
	mover.function_name = "step"
	mover.events = [row]
	return mover


static func _compile_a_behaviour_sheet() -> void:
	var behavior: EventSheetResource = EventSheetResource.new()
	behavior.behavior_mode = true
	behavior.host_class = "CharacterBody2D"
	behavior.custom_class_name = "StateLeakBehaviourProbe"
	behavior.functions = [_probe_function()]
	behavior.external_source_path = UNNAMED_OUTPUT
	SheetCompiler.compile(behavior, "")


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] compiler_state_leak_test: %s" % label)
		return true
	print("[FAIL] compiler_state_leak_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
