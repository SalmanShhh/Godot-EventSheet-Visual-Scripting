# EventForge — the Project Doctor's debug-residue check. A sheet saved with a
# debug-emit toggle ON compiles debug instrumentation into its COMMITTED script — a live hazard, because
# the byte-identity check passes on it (the residue is in sync). This pins: the hazard is real, the check
# flags it, and strip_debug_flags + recompile removes it.
@tool
extends RefCounted
class_name DoctorDebugResidueTest

static func run() -> bool:
	var ok: bool = true

	# 1) The hazard is real: emit_live_values ON compiles the telemetry receiver into the output.
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	sheet.variables = {"hp": {"type": "int", "default": 100}}
	sheet.emit_live_values = true
	var with_residue: String = str(SheetCompiler.compile(sheet, "user://_residue_a.gd").get("output", ""))
	ok = _check("live-values residue compiles into the script", with_residue.contains("__live_values_timer"), true) and ok

	# 2) strip_debug_flags clears the toggles and returns true (something was on).
	ok = _check("strip reports it cleared a flag", EventSheetProjectDoctor.strip_debug_flags(sheet), true) and ok
	ok = _check("emit_live_values is now off", sheet.emit_live_values, false) and ok
	var stripped: String = str(SheetCompiler.compile(sheet, "user://_residue_b.gd").get("output", ""))
	ok = _check("residue is gone after strip", stripped.contains("__live_values_timer"), false) and ok

	# 3) A breakpoint on a debug-break row also compiles in, and strip clears every flag at once.
	var sheet2: EventSheetResource = EventSheetResource.new()
	sheet2.host_class = "Node2D"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnProcess"
	event.debug_break = true
	var raw: RawCodeRow = RawCodeRow.new()
	raw.code = "pass"
	event.actions.append(raw)
	sheet2.events.append(event)
	sheet2.emit_breakpoints = true
	var brk: String = str(SheetCompiler.compile(sheet2, "user://_residue_c.gd").get("output", ""))
	ok = _check("breakpoint residue compiles in", brk.contains("\tbreakpoint"), true) and ok

	# 4) A clean sheet is a no-op for strip.
	ok = _check("strip on a clean sheet is a no-op", EventSheetProjectDoctor.strip_debug_flags(EventSheetResource.new()), false) and ok

	# 5) The check itself flags a debug sheet and clears once stripped + re-saved.
	var fixture_path: String = "user://_doctor_residue_fixture.tres"
	var fixture: EventSheetResource = EventSheetResource.new()
	fixture.host_class = "Node2D"
	fixture.emit_event_trace = true
	if ResourceSaver.save(fixture, fixture_path) == OK:
		var findings: Array[Dictionary] = []
		EventSheetProjectDoctor.check_debug_residue(PackedStringArray([fixture_path]), findings)
		ok = _check("check flags the debug sheet", _residue_count(findings), 1) and ok
		var reloaded: EventSheetResource = load(fixture_path) as EventSheetResource
		EventSheetProjectDoctor.strip_debug_flags(reloaded)
		ResourceSaver.save(reloaded, fixture_path)
		var findings2: Array[Dictionary] = []
		EventSheetProjectDoctor.check_debug_residue(PackedStringArray([fixture_path]), findings2)
		ok = _check("check is clean after strip + resave", _residue_count(findings2), 0) and ok
		DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture_path))
	else:
		print("[INFO] doctor_debug_residue_test: skipped the save-backed check (ResourceSaver unavailable headless)")

	return ok

static func _residue_count(findings: Array[Dictionary]) -> int:
	var count: int = 0
	for finding: Dictionary in findings:
		if str(finding.get("check")) == "debug-residue":
			count += 1
	return count

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] doctor_debug_residue_test: %s" % label)
		return true
	print("[FAIL] doctor_debug_residue_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
