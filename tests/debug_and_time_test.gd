# Godot EventSheets - the debug-and-time parcel: Value Trails, frame budget + named stopwatches
# (both in the builtin Debug vocabulary) and the Debug Overlay pack.
#
# Three things are proved for every verb, because two of them are what a shipped-and-wrong ACE
# passes anyway:
#   1. the SHIPPED codegen template is pinned (a rename or a re-word breaks someone's sheet);
#   2. that same template, substituted through the real ActionCodegen, is compiled and RUN, so the
#      behaviour the blurb promises is executed rather than described (the ring trim, the empty
#      trail, the sustained-drop gate, the CSV file that actually lands on disk);
#   3. the compiler emits it into a real sheet unchanged, stateful member and all.
# The pack's trigger is proved the only way a trigger can be: connect to the real signal, make the
# moment happen, and assert the argument it carried.
@tool
class_name DebugAndTimeTest
extends RefCounted

const PACK_PATH := "res://eventsheet_addons/debug_overlay/debug_overlay_addon.gd"
const CSV_PATH := "user://ef_debug_trail_probe.csv"

## Every builtin id this file reaches for by name. Checked once, up front (see run()).
const REQUIRED_IDS: Array[String] = [
	"RememberInTrail", "TrailValues", "TrailLowest", "TrailHighest", "TrailAverage",
	"TrailNewest", "TrailLength", "LogTrail", "SaveTrailCsv", "ClearTrail",
	"FrameOverBudget", "FpsBelowFor", "StartMeasuring", "StopMeasuring",
	"MeasuredLast", "MeasuredAverage", "MeasuredPeak", "LogMeasurements", "ClearMeasurements",
]


static func run() -> bool:
	var all_passed: bool = true
	var by_id: Dictionary = {}
	for descriptor: ACEDescriptor in EventForgeBuiltinACEs.get_descriptors():
		by_id[descriptor.ace_id] = descriptor

	# Every id below is indexed unguarded further down, because writing a null check at each of the
	# forty use sites would bury the assertions. A renamed or dropped id would therefore CRASH run()
	# - and a crashed test prints no [FAIL] line at all, which is the one failure this suite cannot
	# see. So the census happens once, here, and a miss is a named failure instead of a stack trace.
	for ace_id: String in REQUIRED_IDS:
		if not by_id.has(ace_id):
			return _check("every verb this test pins is still registered (missing %s)" % ace_id, false, true)

	all_passed = _test_vocabulary_shape(by_id) and all_passed
	all_passed = _test_trails_runtime(by_id) and all_passed
	all_passed = _test_budget_runtime(by_id) and all_passed
	all_passed = _test_compiled_into_a_sheet(by_id) and all_passed
	all_passed = _test_overlay_pack_source() and all_passed
	all_passed = _test_overlay_runtime() and all_passed
	all_passed = _test_overlay_release_build_and_start_hidden() and all_passed
	all_passed = _test_overlay_trigger() and all_passed
	return all_passed


## The pack's two headline promises, RUN rather than grepped. A source check for the debug gate
## passes just as happily when the gate is inverted, and start_hidden was never set at all, so its
## branch in _ready had never been taken. Both are reached here by rewriting one name in the shipped
## source - OS.is_debug_build() becomes a flag the test owns - and leaving every other character.
static func _test_overlay_release_build_and_start_hidden() -> bool:
	var all_passed: bool = true
	var kept: PackedStringArray = PackedStringArray()
	for line: String in FileAccess.get_file_as_string(PACK_PATH).split("\n"):
		if line.begins_with("class_name ") or line.begins_with("@icon("):
			continue
		kept.append(line)
	var text: String = "\n".join(kept).replace("OS.is_debug_build()", "_pretend_debug_build")
	text += "\n\nvar _pretend_debug_build: bool = true\n"
	var script: GDScript = GDScript.new()
	script.source_code = text
	all_passed = _check("the release-build harness parses", script.reload(), OK) and all_passed
	if script.reload() != OK:
		return all_passed

	# A release build: every verb is reached, and every one of them must still draw nothing.
	var released: CanvasLayer = script.new()
	released.set("_pretend_debug_build", false)
	released.call("watch_value", "hp", 80)
	released.call("show_bar", "stamina", 0.5, Color.LIME)
	released.call("mark_point", Vector2.ZERO, "here", 1.0)
	released.call("draw_ray", Vector2.ZERO, Vector2.RIGHT, 10.0, Color.RED, 1.0)
	all_passed = _check("a release build builds no surface however many rows draw",
		released.get("_surface") == null, true) and all_passed
	all_passed = _check("and records nothing, so nothing can be shown later",
		(released.get("_watches") as Dictionary).size(), 0) and all_passed
	all_passed = _check("and Overlay Is Visible stays false",
		bool(released.call("is_overlay_visible")), false) and all_passed
	released.free()

	# start_hidden: the exported field that decides whether the toggle key REVEALS or hides.
	var hidden: CanvasLayer = script.new()
	hidden.set("start_hidden", true)
	hidden.call("_ready")
	all_passed = _check("start_hidden leaves the overlay hidden at boot", bool(hidden.get("_shown")), false) and all_passed
	hidden.call("watch_value", "hp", 1)
	all_passed = _check("a row still records while it is hidden",
		(hidden.get("_watches") as Dictionary).size(), 1) and all_passed
	all_passed = _check("but the surface it built starts invisible",
		(hidden.get("_surface") as Control).visible, false) and all_passed
	hidden.call("toggle_overlay")
	all_passed = _check("and the toggle REVEALS it, which is what the field is for",
		bool(hidden.get("_shown")), true) and all_passed
	hidden.free()

	var shown: CanvasLayer = script.new()
	shown.call("_ready")
	all_passed = _check("left alone, the overlay starts shown", bool(shown.get("_shown")), true) and all_passed
	shown.free()
	return all_passed


# ---------------------------------------------------------------- vocabulary shape (the freeze)
static func _test_vocabulary_shape(by_id: Dictionary) -> bool:
	var all_passed: bool = true
	var trail_ids: Array = ["RememberInTrail", "TrailValues", "TrailLowest", "TrailHighest",
		"TrailAverage", "TrailNewest", "TrailLength", "LogTrail", "SaveTrailCsv", "ClearTrail"]
	var budget_ids: Array = ["FrameOverBudget", "FpsBelowFor", "StartMeasuring", "StopMeasuring",
		"MeasuredLast", "MeasuredAverage", "MeasuredPeak", "LogMeasurements", "ClearMeasurements"]
	for ace_id: String in trail_ids + budget_ids:
		all_passed = _check("%s is registered" % ace_id, by_id.has(ace_id), true) and all_passed
		if not by_id.has(ace_id):
			continue
		all_passed = _check("%s sits in the Debug section" % ace_id,
			str((by_id[ace_id] as ACEDescriptor).category), "Debug") and all_passed

	# The LANE model: recording and dumping are effects, reading is an expression, the two
	# performance questions are conditions. A kind mistake here is the one the gates cannot catch.
	all_passed = _check("Remember In Trail is an action",
		(by_id["RememberInTrail"] as ACEDescriptor).ace_type, ACEDescriptor.ACEType.ACTION) and all_passed
	all_passed = _check("Lowest In Trail is an expression",
		(by_id["TrailLowest"] as ACEDescriptor).ace_type, ACEDescriptor.ACEType.EXPRESSION) and all_passed
	all_passed = _check("Frame Took Longer Than is a condition",
		(by_id["FrameOverBudget"] as ACEDescriptor).ace_type, ACEDescriptor.ACEType.CONDITION) and all_passed
	all_passed = _check("FPS Below For is a condition",
		(by_id["FpsBelowFor"] as ACEDescriptor).ace_type, ACEDescriptor.ACEType.CONDITION) and all_passed
	all_passed = _check("Start Measuring is an action",
		(by_id["StartMeasuring"] as ACEDescriptor).ace_type, ACEDescriptor.ACEType.ACTION) and all_passed
	all_passed = _check("Average Measured is an expression",
		(by_id["MeasuredAverage"] as ACEDescriptor).ace_type, ACEDescriptor.ACEType.EXPRESSION) and all_passed

	# Frozen templates. These strings are a compatibility promise the moment they ship.
	all_passed = _check("the frame-budget condition is the plain delta comparison",
		str((by_id["FrameOverBudget"] as ACEDescriptor).codegen_template),
		"(get_process_delta_time() * 1000.0 > {ms})") and all_passed
	all_passed = _check("the stopwatch start stamps the name inside one metadata dictionary",
		str((by_id["StartMeasuring"] as ACEDescriptor).codegen_template).contains("__starts_{uid}[{named}] = Time.get_ticks_usec()"), true) and all_passed
	all_passed = _check("Log Trail prints the whole trail",
		str((by_id["LogTrail"] as ACEDescriptor).codegen_template),
		"print(\"trail \", {trail}, \": \", (get_meta(&\"__ef_trails\", {}) as Dictionary).get({trail}, []))") and all_passed
	all_passed = _check("Clear Trail erases one name, so clearing twice is not an error",
		str((by_id["ClearTrail"] as ACEDescriptor).codegen_template).contains("__trails_{uid}.erase({trail})"), true) and all_passed
	# The trap this family walked into on the first pass: a metadata KEY must be a valid identifier,
	# so "spawn wave" cannot be one. Every name a user types is a dictionary key instead.
	var name_keyed: PackedStringArray = PackedStringArray()
	for ace_id: String in trail_ids + budget_ids:
		var template: String = str((by_id[ace_id] as ACEDescriptor).codegen_template)
		if template.contains("_\" + str({trail})") or template.contains("_\" + str({named})"):
			name_keyed.append(ace_id)
	all_passed = _check("no verb builds a metadata key out of a name the user typed",
		", ".join(name_keyed), "") and all_passed
	all_passed = _check("FPS Below For carries per-instance state, so it needs a {uid} member",
		str((by_id["FpsBelowFor"] as ACEDescriptor).member_template).contains("__fpslow_{uid}"), true) and all_passed
	all_passed = _check("no trail verb bakes a lambda name a sheet variable could shadow",
		str((by_id["TrailAverage"] as ACEDescriptor).codegen_template).contains("func(__acc, __v)"), true) and all_passed

	# Defaults are what the row SHOWS the moment it is dropped, so they have to read as a sentence.
	all_passed = _check("Remember In Trail starts on a named trail",
		str(((by_id["RememberInTrail"] as ACEDescriptor).params[1] as ACEParam).default_value), "\"vy\"") and all_passed
	all_passed = _check("Remember In Trail keeps 120 by default",
		str(((by_id["RememberInTrail"] as ACEDescriptor).params[2] as ACEParam).default_value), "120") and all_passed
	all_passed = _check("the CSV dump defaults to a user:// path that works in an exported game",
		str(((by_id["SaveTrailCsv"] as ACEDescriptor).params[1] as ACEParam).default_value), "\"user://trail.csv\"") and all_passed
	return all_passed


# ---------------------------------------------------------------- Value Trails, actually running
static func _test_trails_runtime(by_id: Dictionary) -> bool:
	var all_passed: bool = true
	var lines: Array[String] = ["@tool", "extends Node", ""]
	lines.append("func record(v: Variant) -> void:")
	lines.append(_indented(by_id, "RememberInTrail", {"value": "v", "trail": "\"vy\"", "keep": "3"}))
	lines.append("")
	lines.append("func record_long(v: Variant) -> void:")
	lines.append(_indented(by_id, "RememberInTrail", {"value": "v", "trail": "\"long\"", "keep": "999"}))
	lines.append("")
	lines.append("func values() -> Array:")
	lines.append("\treturn %s" % _line(by_id, "TrailValues", {"trail": "\"vy\""}))
	lines.append("")
	lines.append("func lowest() -> float:")
	lines.append("\treturn %s" % _line(by_id, "TrailLowest", {"trail": "\"vy\""}))
	lines.append("")
	lines.append("func highest() -> float:")
	lines.append("\treturn %s" % _line(by_id, "TrailHighest", {"trail": "\"vy\""}))
	lines.append("")
	lines.append("func average() -> float:")
	lines.append("\treturn %s" % _line(by_id, "TrailAverage", {"trail": "\"vy\""}))
	lines.append("")
	lines.append("func newest() -> Variant:")
	lines.append("\treturn %s" % _line(by_id, "TrailNewest", {"trail": "\"vy\""}))
	lines.append("")
	lines.append("func length() -> int:")
	lines.append("\treturn %s" % _line(by_id, "TrailLength", {"trail": "\"vy\""}))
	lines.append("")
	lines.append("func long_length() -> int:")
	lines.append("\treturn %s" % _line(by_id, "TrailLength", {"trail": "\"long\""}))
	lines.append("")
	lines.append("func empty_average() -> float:")
	lines.append("\treturn %s" % _line(by_id, "TrailAverage", {"trail": "\"nothing_here\""}))
	lines.append("")
	lines.append("func empty_newest() -> Variant:")
	lines.append("\treturn %s" % _line(by_id, "TrailNewest", {"trail": "\"nothing_here\""}))
	lines.append("")
	# The two print-only verbs are run with `print(` swapped for a recorder taking the same
	# arguments, so the LINE they compose is asserted. Reaching a print and asserting `true == true`
	# proves nothing at all - it passes just as happily when the verb prints the wrong trail.
	lines.append("var said: Array = []")
	lines.append("")
	lines.append("func _say(a: Variant, b: Variant, c: Variant, d: Variant) -> void:")
	lines.append("	said.append(str(a) + str(b) + str(c) + str(d))")
	lines.append("")
	lines.append("func log_it() -> void:")
	lines.append(_indented(by_id, "LogTrail", {"trail": "\"vy\""}).replace("print(", "_say("))
	lines.append("")
	lines.append("func save_csv(destination: String) -> void:")
	lines.append(_indented(by_id, "SaveTrailCsv", {"trail": "\"vy\"", "path": "destination"}))
	lines.append("")
	lines.append("func clear_it() -> void:")
	lines.append(_indented(by_id, "ClearTrail", {"trail": "\"vy\""}))
	lines.append("")

	var host: Node = _instantiate(lines)
	if host == null:
		return _check("the trail probe script compiles", false, true)

	for sample: int in [10, 20, 30, 40, 50]:
		host.call("record", sample)
	all_passed = _check("the ring keeps only the newest Keep values", str(host.call("values")), "[30, 40, 50]") and all_passed
	all_passed = _check("Trail Length tops out at Keep", int(host.call("length")), 3) and all_passed
	all_passed = _check("Lowest In Trail reads the smallest kept value", float(host.call("lowest")), 30.0) and all_passed
	all_passed = _check("Highest In Trail reads the largest kept value", float(host.call("highest")), 50.0) and all_passed
	all_passed = _check("Average In Trail is the mean of the kept values", float(host.call("average")), 40.0) and all_passed
	all_passed = _check("Newest In Trail is the last value recorded", int(host.call("newest")), 50) and all_passed
	# The edge case the ring promises: a Keep bigger than the sample count drops nothing.
	host.call("record_long", 1)
	host.call("record_long", 2)
	all_passed = _check("a trail under its Keep loses nothing", int(host.call("long_length")), 2) and all_passed
	# The edge case every trail expression promises: a trail nobody filled reads as a harmless zero.
	all_passed = _check("an empty trail averages 0", float(host.call("empty_average")), 0.0) and all_passed
	all_passed = _check("an empty trail's newest value is 0", int(host.call("empty_newest")), 0) and all_passed

	host.call("log_it")
	all_passed = _check("Log Trail prints the trail's name and its whole contents",
		str((host.get("said") as Array)[0]), "trail vy: [30, 40, 50]") and all_passed

	if FileAccess.file_exists(CSV_PATH):
		DirAccess.remove_absolute(CSV_PATH)
	host.call("save_csv", CSV_PATH)
	all_passed = _check("Save Trail To CSV writes a two-column file",
		FileAccess.get_file_as_string(CSV_PATH), "index,value\n0,30\n1,40\n2,50\n") and all_passed
	DirAccess.remove_absolute(CSV_PATH)

	host.call("clear_it")
	all_passed = _check("Clear Trail forgets everything", int(host.call("length")), 0) and all_passed
	host.call("clear_it")
	all_passed = _check("clearing an already-cleared trail is still empty", int(host.call("length")), 0) and all_passed
	host.free()
	return all_passed


# ------------------------------------------------- frame budget + stopwatches, actually running
static func _test_budget_runtime(by_id: Dictionary) -> bool:
	var all_passed: bool = true
	var member: String = str((by_id["FpsBelowFor"] as ACEDescriptor).member_template).replace("{uid}", "probe")
	var lines: Array[String] = ["@tool", "extends Node", ""]
	for member_line: String in member.split("\n"):
		lines.append(member_line)
	lines.append("")
	lines.append("func over_budget(ms: float) -> bool:")
	lines.append("\treturn %s" % _line(by_id, "FrameOverBudget", {"ms": "ms"}))
	lines.append("")
	lines.append("func fps_below_for(limit: float, seconds: float) -> bool:")
	lines.append("\treturn %s" % _line(by_id, "FpsBelowFor", {"fps": "limit", "seconds": "seconds"}).replace("{uid}", "probe"))
	lines.append("")
	lines.append("func seed_span(usec_ago: int) -> void:")
	lines.append("\tset_meta(&\"__ef_span_starts\", {\"spawn wave\": Time.get_ticks_usec() - usec_ago})")
	lines.append("")
	lines.append("func start_span() -> void:")
	lines.append(_indented(by_id, "StartMeasuring", {"named": "\"spawn wave\""}))
	lines.append("")
	lines.append("func stop_span() -> void:")
	lines.append(_indented(by_id, "StopMeasuring", {"named": "\"spawn wave\""}))
	lines.append("")
	lines.append("func last_ms() -> float:")
	lines.append("\treturn %s" % _line(by_id, "MeasuredLast", {"named": "\"spawn wave\""}))
	lines.append("")
	lines.append("func average_ms() -> float:")
	lines.append("\treturn %s" % _line(by_id, "MeasuredAverage", {"named": "\"spawn wave\""}))
	lines.append("")
	lines.append("func peak_ms() -> float:")
	lines.append("\treturn %s" % _line(by_id, "MeasuredPeak", {"named": "\"spawn wave\""}))
	lines.append("")
	lines.append("var said: Array = []")
	lines.append("")
	lines.append("func _say(text: String) -> void:")
	lines.append("	said.append(text)")
	lines.append("")
	lines.append("func log_all() -> void:")
	lines.append(_indented(by_id, "LogMeasurements", {}))
	lines.append("")
	lines.append("func clear_all() -> void:")
	lines.append(_indented(by_id, "ClearMeasurements", {}))
	lines.append("")

	var host: Node = _instantiate(lines)
	if host == null:
		return _check("the budget probe script compiles", false, true)

	# Frame Took Longer Than is a plain comparison against this frame's delta, so a budget below
	# the delta is true and a budget above it is false. Treeless, the delta is 0.
	all_passed = _check("a budget under the frame's cost is over budget", bool(host.call("over_budget", -1.0)), true) and all_passed
	all_passed = _check("a budget over the frame's cost is not", bool(host.call("over_budget", 20.0)), false) and all_passed

	# FPS Below For: the whole point is that ONE bad frame is not a drop. A huge floor means the
	# framerate is always "below", yet a three-second window is still not satisfied on the first
	# two calls - which is the sustained-drop gate the blurb promises.
	all_passed = _check("the first tick of a drop only starts the clock",
		bool(host.call("fps_below_for", 100000.0, 3.0)), false) and all_passed
	all_passed = _check("a drop shorter than the window is still not a drop",
		bool(host.call("fps_below_for", 100000.0, 3.0)), false) and all_passed
	all_passed = _check("a drop that has lasted the whole window is true",
		bool(host.call("fps_below_for", 100000.0, 0.0)), true) and all_passed
	all_passed = _check("a healthy framerate is never below",
		bool(host.call("fps_below_for", -1.0, 0.0)), false) and all_passed
	all_passed = _check("and recovering re-arms the clock, so the next drop starts over",
		bool(host.call("fps_below_for", 100000.0, 0.0)), false) and all_passed

	# Named stopwatches. The start stamp is seeded a known distance in the past so the reading is
	# a value to pin rather than a race against the test's own runtime.
	host.call("clear_all")
	host.call("seed_span", 20000)
	host.call("stop_span")
	all_passed = _check("Last Measured reads the span in milliseconds", roundi(float(host.call("last_ms"))), 20) and all_passed
	all_passed = _check("one sample makes the average the same reading", roundi(float(host.call("average_ms"))), 20) and all_passed
	all_passed = _check("one sample makes the peak the same reading", roundi(float(host.call("peak_ms"))), 20) and all_passed
	host.call("seed_span", 40000)
	host.call("stop_span")
	all_passed = _check("a second sample moves the average to the mean", roundi(float(host.call("average_ms"))), 30) and all_passed
	all_passed = _check("the peak keeps the worst run, not the latest", roundi(float(host.call("peak_ms"))), 40) and all_passed
	all_passed = _check("the last reading is the latest run", roundi(float(host.call("last_ms"))), 40) and all_passed
	host.call("log_all")
	host.call("clear_all")
	all_passed = _check("Clear Measurements empties the record", float(host.call("last_ms")), 0.0) and all_passed
	host.call("clear_all")
	all_passed = _check("clearing twice is still empty", float(host.call("average_ms")), 0.0) and all_passed
	# Start Measuring without a Stop leaves nothing behind to read wrongly.
	host.call("start_span")
	all_passed = _check("an unfinished measurement reports nothing", float(host.call("last_ms")), 0.0) and all_passed
	host.free()
	return all_passed


# ------------------------------------------------------- the compiler emits them into a real sheet
static func _test_compiled_into_a_sheet(by_id: Dictionary) -> bool:
	var all_passed: bool = true
	var condition: ACECondition = ACECondition.new()
	condition.provider_id = "Core"
	condition.ace_id = "FpsBelowFor"
	condition.codegen_template = str((by_id["FpsBelowFor"] as ACEDescriptor).codegen_template).replace("{uid}", "row0")
	condition.member_declaration = str((by_id["FpsBelowFor"] as ACEDescriptor).member_template).replace("{uid}", "row0")
	condition.params = {"fps": "45.0", "seconds": "3.0"}

	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "RememberInTrail"
	action.codegen_template = str((by_id["RememberInTrail"] as ACEDescriptor).codegen_template).replace("{uid}", "row0")
	action.params = {"value": "0.0", "trail": "\"vy\"", "keep": "120"}

	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnProcess"
	event.conditions.append(condition)
	event.actions.append(action)
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.events.append(event)
	var output: String = str(SheetCompiler.compile(sheet, "user://eventsheets_debug_and_time.gd").get("output", ""))

	all_passed = _check("the stateful drop-clock is declared at class level",
		output.contains("var __fpslow_row0: float = -1.0"), true) and all_passed
	all_passed = _check("the condition reads as the helper call, params substituted",
		output.contains("if __fps_below_for_row0(45.0, 3.0):"), true) and all_passed
	all_passed = _check("the trail action emits plain dependency-free GDScript",
		output.contains("var __trail_row0: Array = __trails_row0.get(\"vy\", []) as Array"), true) and all_passed
	all_passed = _check("the ring trim survives the compile",
		output.contains("__trail_row0 = __trail_row0.slice(__trail_row0.size() - maxi(int(120), 1))"), true) and all_passed
	var generated: GDScript = GDScript.new()
	generated.source_code = output
	all_passed = _check("the emitted sheet parses", generated.reload(true) == OK, true) and all_passed
	return all_passed


# ------------------------------------------------------------------ the Debug Overlay pack source
static func _test_overlay_pack_source() -> bool:
	var all_passed: bool = true
	var source: String = FileAccess.get_file_as_string(PACK_PATH)
	all_passed = _check("the pack ships", source.is_empty(), false) and all_passed
	all_passed = _check("it is a CanvasLayer, so it draws on the game and never on the sheet",
		source.contains("extends CanvasLayer"), true) and all_passed
	all_passed = _check("the surface is built lazily by one guarded function",
		source.contains("func _ensure_surface() -> bool:"), true) and all_passed
	all_passed = _check("and its gate is OS.is_debug_build(), the same one Log (Debug Builds Only) uses",
		source.contains("if not OS.is_debug_build():\n\t\treturn false"), true) and all_passed
	all_passed = _check("every drawing verb goes through that gate",
		source.count("if not _ensure_surface():"), 5) and all_passed
	all_passed = _check("the toggle key is read by name so the Inspector field stays readable",
		source.contains("OS.find_keycode_from_string(toggle_key.strip_edges())"), true) and all_passed
	all_passed = _check("the trigger is a real signal carrying whether it is now shown",
		source.contains("signal overlay_toggled(shown: bool)"), true) and all_passed
	all_passed = _check("Watch Value ships as the autoload call",
		source.contains("## @ace_codegen_template(\"DebugOverlay.watch_value({watch_name}, {value})\")"), true) and all_passed
	all_passed = _check("Mark Point ships as the autoload call",
		source.contains("## @ace_codegen_template(\"DebugOverlay.mark_point({at}, {mark_label}, {seconds})\")"), true) and all_passed
	all_passed = _check("Overlay Is Visible is published as a condition",
		source.contains("## @ace_condition\n## @ace_name(\"Overlay Is Visible\")"), true) and all_passed
	all_passed = _check("nothing in the pack touches the editor",
		source.contains("EditorInterface") or source.contains("EditorPlugin"), false) and all_passed
	all_passed = _check("the pack carries its own icon",
		source.contains("@icon(\"res://eventsheet_addons/debug_overlay/icon.svg\")"), true) and all_passed
	return all_passed


static func _test_overlay_runtime() -> bool:
	var all_passed: bool = true
	var overlay: Node = _load_overlay()
	if overlay == null:
		return _check("the Debug Overlay pack instantiates", false, true)

	# Off until a row asks for it: no surface, and the condition says so.
	all_passed = _check("no surface exists before any row draws", overlay.get("_surface") == null, true) and all_passed
	all_passed = _check("Overlay Is Visible is false before any row draws",
		bool(overlay.call("is_overlay_visible")), false) and all_passed

	overlay.call("watch_value", "hp", 80)
	all_passed = _check("the first verb call builds the surface", overlay.get("_surface") != null, true) and all_passed
	all_passed = _check("Overlay Is Visible is true once a row has drawn to it",
		bool(overlay.call("is_overlay_visible")), true) and all_passed
	all_passed = _check("a watch stores its value as text", str((overlay.get("_watches") as Dictionary).get("hp", "")), "80") and all_passed
	overlay.call("watch_value", "hp", 55)
	all_passed = _check("re-watching the same name refreshes rather than duplicates",
		(overlay.get("_watch_order") as PackedStringArray).size(), 1) and all_passed
	all_passed = _check("and the refreshed value is the new one",
		str((overlay.get("_watches") as Dictionary).get("hp", "")), "55") and all_passed
	overlay.call("clear_watch", "hp")
	all_passed = _check("Clear Watch drops the line",
		(overlay.get("_watch_order") as PackedStringArray).size(), 0) and all_passed
	overlay.call("clear_watch", "never_watched")
	all_passed = _check("clearing a watch that was never set is harmless",
		(overlay.get("_watch_order") as PackedStringArray).size(), 0) and all_passed

	overlay.call("show_bar", "stamina", 0.5, Color.LIME)
	all_passed = _check("a bar records its fraction and colour",
		float(((overlay.get("_bars") as Dictionary)["stamina"] as Array)[0]), 0.5) and all_passed

	overlay.call("mark_point", Vector2(120.0, 40.0), "dash start", 2.0)
	all_passed = _check("a mark records where it happened",
		((overlay.get("_marks") as Array)[0] as Array)[0], Vector2(120.0, 40.0)) and all_passed
	all_passed = _check("a mark records its label",
		str(((overlay.get("_marks") as Array)[0] as Array)[1]), "dash start") and all_passed

	# The blurb promises a ray drawn ALONG a direction for a length, so the direction is normalized
	# first: an un-normalized (0, 2) with length 200 still ends 200 pixels away.
	overlay.call("draw_ray", Vector2.ZERO, Vector2(0.0, 2.0), 200.0, Color.RED, 1.0)
	all_passed = _check("a ray ends one length along the normalized direction",
		((overlay.get("_rays") as Array)[0] as Array)[1], Vector2(0.0, 200.0)) and all_passed

	var target: Node2D = Node2D.new()
	target.position = Vector2(64.0, 16.0)
	overlay.call("label_above", target, "patrolling", 1.0)
	all_passed = _check("a label remembers the node it belongs to",
		((overlay.get("_labels") as Array)[0] as Array)[0] == target, true) and all_passed
	all_passed = _check("a 2D node's screen position comes from its world position",
		overlay.call("_node_screen_position", target), Vector2(64.0, 16.0)) and all_passed
	all_passed = _check("world to screen degrades to the world position with no viewport",
		overlay.call("_world_to_screen", Vector2(9.0, 9.0)), Vector2(9.0, 9.0)) and all_passed

	# Timed entries age themselves out on the pack's own tick: expire the mark by hand and tick.
	((overlay.get("_marks") as Array)[0] as Array)[3] = 0
	((overlay.get("_rays") as Array)[0] as Array)[3] = 0
	((overlay.get("_labels") as Array)[0] as Array)[2] = 0
	overlay.call("_expire_overlay_entries")
	all_passed = _check("an expired mark is dropped", (overlay.get("_marks") as Array).size(), 0) and all_passed
	all_passed = _check("an expired ray is dropped", (overlay.get("_rays") as Array).size(), 0) and all_passed
	all_passed = _check("an expired label is dropped", (overlay.get("_labels") as Array).size(), 0) and all_passed

	overlay.call("watch_value", "fps", 60)
	overlay.call("clear_overlay")
	all_passed = _check("Clear Overlay wipes the watches", (overlay.get("_watches") as Dictionary).size(), 0) and all_passed
	all_passed = _check("Clear Overlay wipes the bars", (overlay.get("_bars") as Dictionary).size(), 0) and all_passed
	all_passed = _check("Clear Overlay leaves the overlay itself standing",
		bool(overlay.call("is_overlay_visible")), true) and all_passed

	target.free()
	overlay.free()
	return all_passed


static func _test_overlay_trigger() -> bool:
	var all_passed: bool = true
	var overlay: Node = _load_overlay()
	if overlay == null:
		return _check("the Debug Overlay pack instantiates for the trigger check", false, true)

	# The signal is DECLARED with the payload the row reads back.
	var declared: Dictionary = {}
	for entry: Dictionary in overlay.get_signal_list():
		declared[str(entry.get("name", ""))] = entry
	all_passed = _check("overlay_toggled is a declared signal", declared.has("overlay_toggled"), true) and all_passed
	if declared.has("overlay_toggled"):
		var args: Array = (declared["overlay_toggled"] as Dictionary).get("args", []) as Array
		all_passed = _check("it carries exactly one argument", args.size(), 1) and all_passed
		all_passed = _check("and that argument is named shown",
			str((args[0] as Dictionary).get("name", "")), "shown") and all_passed

	var seen: Array = []
	overlay.connect("overlay_toggled", func(shown: bool) -> void: seen.append(shown))

	# It fires at the moment the overlay actually changes state, and carries the NEW state.
	overlay.call("hide_overlay")
	all_passed = _check("hiding fires the trigger once", seen.size(), 1) and all_passed
	all_passed = _check("and its payload says the overlay is now hidden", bool(seen[0]), false) and all_passed
	overlay.call("hide_overlay")
	all_passed = _check("hiding an already-hidden overlay fires nothing", seen.size(), 1) and all_passed
	overlay.call("show_overlay")
	all_passed = _check("showing fires it again", seen.size(), 2) and all_passed
	all_passed = _check("and its payload says the overlay is now shown", bool(seen[1]), true) and all_passed
	overlay.call("toggle_overlay")
	all_passed = _check("the toggle fires it too", seen.size(), 3) and all_passed
	all_passed = _check("and the toggle's payload is the flipped state", bool(seen[2]), false) and all_passed

	# The toggle KEY is the same seam, so a key press reaches the same trigger.
	var press: InputEventKey = InputEventKey.new()
	press.keycode = OS.find_keycode_from_string("F3")
	press.pressed = true
	overlay.call("_unhandled_input", press)
	all_passed = _check("the toggle key reaches the trigger", seen.size(), 4) and all_passed
	all_passed = _check("and the key press payload is the flipped state", bool(seen[3]), true) and all_passed
	var release: InputEventKey = InputEventKey.new()
	release.keycode = OS.find_keycode_from_string("F3")
	release.pressed = false
	overlay.call("_unhandled_input", release)
	all_passed = _check("a key RELEASE does not toggle a second time", seen.size(), 4) and all_passed

	overlay.free()
	return all_passed


# ------------------------------------------------------------------------------------- helpers
static func _load_overlay() -> Node:
	var script: GDScript = load(PACK_PATH) as GDScript
	if script == null:
		return null
	var overlay: Node = CanvasLayer.new()
	overlay.set_script(script)
	return overlay


## The shipped template, substituted through the real codegen, with the row uid baked the way the
## dock bakes it at apply time.
static func _line(by_id: Dictionary, ace_id: String, params: Dictionary) -> String:
	var filled: Dictionary = params.duplicate()
	filled["uid"] = "probe"
	return ActionCodegen._apply_template(str((by_id[ace_id] as ACEDescriptor).codegen_template), filled)


## The same, laid out as an indented function body (an action template may be several lines).
static func _indented(by_id: Dictionary, ace_id: String, params: Dictionary) -> String:
	var body: PackedStringArray = PackedStringArray()
	for line: String in _line(by_id, ace_id, params).split("\n"):
		body.append("\t" + line)
	return "\n".join(body)


static func _instantiate(lines: Array[String]) -> Node:
	var script: GDScript = GDScript.new()
	script.source_code = "\n".join(lines) + "\n"
	if script.reload() != OK:
		print("[FAIL] debug_and_time_test: probe script did not compile\n----\n%s\n----" % script.source_code)
		return null
	var host: Node = Node.new()
	host.set_script(script)
	return host


## Prints on BOTH outcomes on purpose. A test that printed only on failure left no trace in the
## suite log at all, so a run that crashed at check three looked exactly like a run that passed
## every one of them.
static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual != expected:
		print("[FAIL] debug_and_time_test: %s (got %s, expected %s)" % [label, str(actual), str(expected)])
		return false
	print("[PASS] debug_and_time_test: %s" % label)
	return true
