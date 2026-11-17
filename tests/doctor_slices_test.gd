# EventSheets - the Project Doctor can be taken a step at a time without changing what it answers.
#
# The audit is a list of steps. `run()` takes them all; the editor takes them a few milliseconds at a
# time with a frame between, so a project of thousands of scripts never holds the window still. This
# pins the parts that do not need a running editor: the steps and the answer they give, the clock-free
# `breathe`, the corpus slicing, the margin number asked only when a finding names it, and the plain
# scripts being summed up in one line rather than reported one by one.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "doctor_slices_test"


static func run() -> bool:
	var Doctor: GDScript = EventSheetProjectDoctor
	var session: Dictionary = Doctor.begin()
	var names: PackedStringArray = PackedStringArray()
	for entry: Array in (session["steps"] as Array):
		names.append(str(entry[0]))
	var started: Vector2i = Doctor.progress_of(session)
	# Two steps by hand, then the audit is closed early: the whole of it is `run()`'s own work, which the
	# project doctor test already runs over this repository.
	var more: bool = Doctor.step(session)
	var after_one: Vector2i = Doctor.progress_of(session)
	Doctor.step(session)
	var report: Dictionary = Doctor.finish(session)

	# The margin number is asked only for a row a finding names: a clean sheet never builds it.
	var sheet: EventSheetResource = EventSheetResource.new()
	var loud: EventRow = EventRow.new()
	loud.trigger_id = "OnProcess"
	var awaiting: RawCodeRow = RawCodeRow.new()
	awaiting.code = "await get_tree().process_frame"
	loud.actions = [awaiting] as Array[Resource]
	var quiet: EventRow = EventRow.new()
	quiet.trigger_id = "OnProcess"
	sheet.events = [loud, quiet] as Array[Resource]
	Doctor.get("_margin_cache").clear()
	Doctor.set("_run_in_progress", true)
	var findings: Array[Dictionary] = []
	Doctor._scan_coroutine_misuse(quiet, "res://probe.gd", findings, sheet)
	var cache_after_quiet: int = Doctor.get("_margin_cache").size()
	Doctor._scan_coroutine_misuse(loud, "res://probe.gd", findings, sheet)
	var cache_after_loud: int = Doctor.get("_margin_cache").size()
	Doctor.set("_run_in_progress", false)
	Doctor.get("_margin_cache").clear()

	# Slicing a corpus gives the answer of running over the whole of it, finder by finder.
	var sources: Dictionary = {}
	for number: int in range(30):
		sources["res://s%02d.gd" % number] = "x" if number % 7 == 0 else "y"
	var finder_a: Callable = func(part: Dictionary) -> Array[Dictionary]:
		var out: Array[Dictionary] = []
		for path: String in part:
			if part[path] == "x":
				out.append({"check": "a", "path": path})
		return out
	var finder_b: Callable = func(part: Dictionary) -> Array[Dictionary]:
		var out: Array[Dictionary] = []
		for path: String in part:
			if path.ends_with("29.gd"):
				out.append({"check": "b", "path": path})
		return out
	var sliced: Array = Doctor.call("sliced_findings", sources, [finder_a, finder_b])
	var shape: PackedStringArray = PackedStringArray()
	for finding: Dictionary in sliced:
		shape.append("%s %s" % [finding["check"], str(finding["path"]).get_file()])

	var clash: GDScript = load("res://addons/eventforge/class_name_clash_doctor.gd")
	var bytes: PackedByteArray = "ab─".to_utf8_buffer()
	var cut: String = clash._whole_characters(bytes.slice(0, bytes.size() - 1))
	var whole: String = clash._whole_characters(bytes)

	return SUPPORT.pins(P, [
		["the audit lists its steps, sheet sorting and reading first", names.slice(0, 2), PackedStringArray(["which_scripts_are_sheets", "read_scripts"])],
		["the extension checks come last, as a step that lists each one", names[names.size() - 1], "extension_checks"],
		["nothing is done before the first step", started.x, 0],
		["one step moves it one on", after_one.x, 1],
		["and says there is more", more, true],
		["the report has the shape every runner reads", report.has("findings") and report.has("errors") and report.has("warnings") and report.has("infos"), true],
		["the plain scripts it sorted are counted in one note", (report["findings"] as Array)[0].get("check", ""), "sheet-coverage"],
		["outside a sliced audit there is nothing to wait for", Doctor.breathe(), null],
		["a clean row never builds the margin numbers", cache_after_quiet, 0],
		["a row a finding names builds them once", cache_after_loud, 1],
		["and the finding carries the row's number", findings.size(), 1],
		["a corpus taken in slices answers finder by finder in path order", shape,
			PackedStringArray(["a s00.gd", "a s07.gd", "a s14.gd", "a s21.gd", "a s28.gd", "b s29.gd"])],
		["a file cut in the middle of a character is read up to the last whole one", cut, "ab"],
		["a file that ends on a whole character keeps it", whole, "ab─"],
	])
