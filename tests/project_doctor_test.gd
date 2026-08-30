# Godot EventSheets - Project Doctor: the one CI-able audit for cross-file drift
# (stale generated outputs, unregistered autoload sheets, unused vocabulary, scene
# attachment). The final block runs the doctor on THIS repository - it doubles as the
# repo-health gate: every committed generated script must byte-match its sheet.
@tool
class_name ProjectDoctorTest
extends RefCounted

## The whole audit, over this whole repository: 112 packs, every demo, every committed sheet, and
## the fifty-odd checks the union runs. Measured 81-92 seconds across four runs before three things
## were fixed: a pin reading that ran three times over every file that had no pin in it, a read of
## every scene in the project per script anybody asked about, and a directory walk repeated once per
## check. 41 to 48 seconds after, across seven runs on the same quiet machine and with the same 175
## findings.
##
## THE BUDGET IS UNDER THE OLD BAND ON PURPOSE, which is the one place the usual "roughly double the
## measurement" rule cannot apply: doubling 48 lands at 96, above everything the three faults used
## to cost, and the one gate protecting a 40-second saving would then pass with the saving gone.
## 65 seconds is a third clear of the worst run measured and a fifth under the best run of the code
## this replaced, so a return to any of the three fails rather than passing at half the margin.
##
## The Interop section joined the audit after that measurement and re-measured it at 48 to 54 seconds
## over three runs. Its own share is about two seconds: it reads every script of the project ONCE for
## the mark and the size together, and the lifts it does after that are capped by count and by a
## wall clock. Anything that reads the corpus a second time is where the next slow second will come
## from.
##
## Declaring it also moves this test into the runner's serial tail, which is the only place the
## number means anything: measured inside a shard beside seven other Godot processes it would flap,
## and a budget people learn to ignore is not a budget.
##
## MEASURED AGAIN 2026-08-25, alone, with nothing else running: 68.7, 77.0 and 70.4 seconds. The
## last of those had the scene reader's line folding switched off, so the answer is the same with and
## without it and the drift is not in that reader - it is in what the audit already did. The budget
## is deliberately left where it is: raising one to fit a number nobody has explained is how a budget
## stops meaning anything. What it is asking for is the audit measured on a quiet machine and the
## slow section found, not a bigger number.
##
## SO IT WAS MEASURED, 2026-08-30, section by section, and three sections were found: "which scenes
## carry this script" read every scene in the project per script asked about (four readers ask it
## twice each per opened file, so the file lift alone spent 30 of the 58 seconds there), thirty-odd
## checks each read the project's scripts off disk for themselves rather than sharing one read, and
## the pin notes ran a full grammar read of every line of every script to tell two thirds of them
## they had nothing. Alone in its own process on that machine: 58.1, 59.7 and 58.0 seconds before,
## 36.7, 36.4 and 34.8 after, with the report byte-identical - the same 207 findings in the same
## order. In the serial tail, which is where the number below is actually taken, the same audit
## measured 31.4 seconds against the 74-83 it had been. The budget stays 65: it is now comfortably
## more than the doubling rule would ask of 36, which is the point - the sections that were slow are
## the ones a regression would show up in first, and a budget with that much room left is one that
## still fails before anybody stops reading it.
const DOCTOR_BUDGET_MS: int = 65000


static func run() -> bool:
	var all_passed: bool = true

	# Output pairing: editor convention (<name>_generated.gd) first, the pack builder's
	# header-verified shipped sibling (<name>.gd) as fallback - ONE rule shared by the
	# doctor, compile-on-save and the export-integrity pass.
	all_passed = _check("demo sheet pairs with its _generated script",
		EventSheetProjectDoctor.output_path_for("res://tests/fixtures/compiler_golden_sheet.tres"),
		"res://tests/fixtures/compiler_golden_sheet_generated.gd") and all_passed
	all_passed = _check("a behaviour pack .gd is its own output (compiles in place, no .tres)",
		EventSheetProjectDoctor.output_path_for("res://eventsheet_addons/spring/spring_behavior.gd"),
		"res://eventsheet_addons/spring/spring_behavior.gd") and all_passed
	all_passed = _check("a showcase .gd is its own output (compiles in place, no .tres)",
		EventSheetProjectDoctor.output_path_for("res://demo/showcase/carousel/showcase_carousel.gd"),
		"res://demo/showcase/carousel/showcase_carousel.gd") and all_passed
	# Regression: the export-integrity pass ran earlier in this suite - it must refresh
	# the showcase's existing pair, never recreate the parallel _generated duplicate.
	all_passed = _check("export pass no longer duplicates builder-shipped outputs",
		FileAccess.file_exists("res://demo/showcase/carousel/showcase_carousel_generated.gd"), false) and all_passed
	# A hand-written same-name sibling (no "# Source:" header) is never adopted.
	var handwritten: FileAccess = FileAccess.open("user://doctor_handwritten.gd", FileAccess.WRITE)
	handwritten.store_string("extends Node\n# my own script, not generated\n")
	handwritten.close()
	var paired_sheet: EventSheetResource = EventSheetResource.new()
	paired_sheet.host_class = "Node"
	ResourceSaver.save(paired_sheet, "user://doctor_handwritten.tres")
	all_passed = _check("hand-written siblings are never clobbered",
		EventSheetProjectDoctor.output_path_for("user://doctor_handwritten.tres"),
		"user://doctor_handwritten_generated.gd") and all_passed
	DirAccess.remove_absolute("user://doctor_handwritten.gd")
	DirAccess.remove_absolute("user://doctor_handwritten.tres")

	# Staleness ladder on a user:// fixture: never compiled → warning; freshly
	# compiled → clean; hand-edited output → error.
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	sheet.variables = {
		"used_var": {"type": "int", "default": 1, "exported": false},
		"dead_var": {"type": "int", "default": 0, "exported": false},
		"inspector_var": {"type": "int", "default": 0, "exported": true},
	}
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnProcess"
	var action: ACEAction = ACEAction.new()
	action.ace_id = "SetVar"
	action.codegen_template = "used_var = used_var + 1"
	event.actions.append(action)
	sheet.events.append(event)
	var sheet_path: String = "user://doctor_sheet.tres"
	var generated_path: String = "user://doctor_sheet_generated.gd"
	if FileAccess.file_exists(generated_path):
		DirAccess.remove_absolute(generated_path)
	ResourceSaver.save(sheet, sheet_path)
	var findings: Array[Dictionary] = []
	EventSheetProjectDoctor.check_generated_outputs(PackedStringArray([sheet_path]), findings)
	all_passed = _check("never-compiled sheet warns",
		_has(findings, "warning", "stale-output"), true) and all_passed
	SheetCompiler.compile(load(sheet_path), "")
	findings = []
	EventSheetProjectDoctor.check_generated_outputs(PackedStringArray([sheet_path]), findings)
	all_passed = _check("freshly compiled sheet is clean", findings.is_empty(), true) and all_passed
	var tamper: FileAccess = FileAccess.open(generated_path, FileAccess.READ_WRITE)
	tamper.seek_end()
	tamper.store_string("\n# hand edit\n")
	tamper.close()
	findings = []
	EventSheetProjectDoctor.check_generated_outputs(PackedStringArray([sheet_path]), findings)
	all_passed = _check("hand-edited output is flagged stale",
		_has(findings, "error", "stale-output"), true) and all_passed

	# Autoload registration: unregistered warns, matching entry is clean, an entry
	# pointing at a different script warns.
	var bus_sheet: EventSheetResource = EventSheetResource.new()
	bus_sheet.host_class = "Node"
	bus_sheet.autoload_mode = true
	bus_sheet.autoload_name = "DoctorBus"
	var bus_path: String = "user://doctor_bus.tres"
	ResourceSaver.save(bus_sheet, bus_path)
	findings = []
	EventSheetProjectDoctor.check_autoload_registration(PackedStringArray([bus_path]), findings)
	all_passed = _check("unregistered autoload sheet warns",
		_has(findings, "warning", "autoload"), true) and all_passed
	ProjectSettings.set_setting("autoload/DoctorBus", "*user://doctor_bus_generated.gd")
	findings = []
	EventSheetProjectDoctor.check_autoload_registration(PackedStringArray([bus_path]), findings)
	all_passed = _check("matching registration is clean", findings.is_empty(), true) and all_passed
	ProjectSettings.set_setting("autoload/DoctorBus", "*res://somewhere_else.gd")
	findings = []
	EventSheetProjectDoctor.check_autoload_registration(PackedStringArray([bus_path]), findings)
	all_passed = _check("registration to a different script warns",
		_has(findings, "warning", "autoload"), true) and all_passed
	ProjectSettings.set_setting("autoload/DoctorBus", null)

	# Unused vocabulary: the dead private variable is noted; the referenced private
	# one and the exported one stay quiet.
	findings = []
	EventSheetProjectDoctor.check_unused_variables(PackedStringArray([sheet_path]), findings)
	all_passed = _check("dead private variable is the only note",
		findings.size() == 1 and str(findings[0].get("message")).contains("dead_var"), true) and all_passed

	# Shadowed variables: a name colliding with a host member breaks the generated
	# script at load AND blinds expression lint - error tier, with prevention in the
	# variable dialog sharing the same rule.
	var shadow_sheet: EventSheetResource = EventSheetResource.new()
	shadow_sheet.host_class = "CharacterBody2D"
	shadow_sheet.variables = {"velocity": {"type": "float", "default": 0.0, "exported": true}}
	all_passed = _check("host-member shadows are detected",
		EventSheetProjectDoctor.shadowed_member_class(shadow_sheet, "velocity"), "CharacterBody2D") and all_passed
	all_passed = _check("free names pass",
		EventSheetProjectDoctor.shadowed_member_class(shadow_sheet, "hp"), "") and all_passed
	var behavior_scope: EventSheetResource = EventSheetResource.new()
	behavior_scope.behavior_mode = true
	behavior_scope.host_class = "CharacterBody2D"
	all_passed = _check("behaviors scope to Node (host members live behind host.)",
		EventSheetProjectDoctor.shadowed_member_class(behavior_scope, "velocity") == ""
		and EventSheetProjectDoctor.shadowed_member_class(behavior_scope, "name") == "Node", true) and all_passed
	ResourceSaver.save(shadow_sheet, "user://doctor_shadow.tres")
	findings = []
	EventSheetProjectDoctor.check_shadowed_variables(PackedStringArray(["user://doctor_shadow.tres"]), findings)
	all_passed = _check("shadowing is an error pointing at Rename Everywhere",
		_has(findings, "error", "shadowed-variable")
		and str(findings[0].get("message")).contains("Rename Everywhere"), true) and all_passed
	DirAccess.remove_absolute("user://doctor_shadow.tres")

	# Duplicated-global → autoload nudge: the same name across 2 sheets advises promoting it to an
	# autoload; a single-sheet name stays quiet, and a name a GameState autoload already publishes
	# is exempt (the solved case).
	var dup_a: EventSheetResource = EventSheetResource.new()
	dup_a.variables = {"score": {"type": "int", "default": 0, "exported": false}, "only_a": {"type": "int", "default": 0, "exported": false}}
	var dup_b: EventSheetResource = EventSheetResource.new()
	dup_b.variables = {"score": {"type": "int", "default": 0, "exported": false}}
	ResourceSaver.save(dup_a, "user://doctor_dup_a.tres")
	ResourceSaver.save(dup_b, "user://doctor_dup_b.tres")
	findings = []
	EventSheetProjectDoctor.check_duplicated_globals(PackedStringArray(["user://doctor_dup_a.tres", "user://doctor_dup_b.tres"]), findings)
	all_passed = _check("a global in 2 sheets is flagged for an autoload",
		_has(findings, "info", "duplicated-global") and str(findings[0].get("message")).contains("score"), true) and all_passed
	all_passed = _check("only the shared name is flagged (single-sheet stays quiet)", findings.size(), 1) and all_passed
	var dup_auto: EventSheetResource = EventSheetResource.new()
	dup_auto.autoload_mode = true
	dup_auto.variables = {"score": {"type": "int", "default": 0, "exported": false}}
	ResourceSaver.save(dup_auto, "user://doctor_dup_auto.tres")
	findings = []
	EventSheetProjectDoctor.check_duplicated_globals(PackedStringArray(["user://doctor_dup_a.tres", "user://doctor_dup_b.tres", "user://doctor_dup_auto.tres"]), findings)
	all_passed = _check("a name a GameState autoload publishes is exempt", _has(findings, "info", "duplicated-global"), false) and all_passed
	DirAccess.remove_absolute("user://doctor_dup_a.tres")
	DirAccess.remove_absolute("user://doctor_dup_b.tres")
	DirAccess.remove_absolute("user://doctor_dup_auto.tres")

	# Fan-out god-sheet nudge: a plain sheet reaching into many DISTINCT external nodes is flagged (by
	# node count, NOT row count); a behavior sheet is exempt; below the threshold stays quiet.
	ProjectSettings.set_setting("eventsheets/doctor/fanout_threshold", 3)
	var fan_sheet: EventSheetResource = EventSheetResource.new()
	var fan_event: EventRow = EventRow.new()
	fan_event.trigger_provider_id = "Core"
	fan_event.trigger_id = "OnReady"
	var fan_code: RawCodeRow = RawCodeRow.new()
	fan_code.code = "$Player.x = 1\n$Enemy.x = 1\n$Boss.x = 1\n$HUD/Score.text = \"\""
	fan_event.actions.append(fan_code)
	fan_sheet.events.append(fan_event)
	ResourceSaver.save(fan_sheet, "user://doctor_fan.tres")
	findings = []
	EventSheetProjectDoctor.check_fanout_god_sheets(PackedStringArray(["user://doctor_fan.tres"]), findings)
	all_passed = _check("a sheet reaching into many distinct nodes is flagged", _has(findings, "info", "fanout-god-sheet"), true) and all_passed
	fan_sheet.behavior_mode = true
	ResourceSaver.save(fan_sheet, "user://doctor_fan.tres")
	findings = []
	EventSheetProjectDoctor.check_fanout_god_sheets(PackedStringArray(["user://doctor_fan.tres"]), findings)
	all_passed = _check("a behavior sheet is exempt (a coordinator is a valid choice)", _has(findings, "info", "fanout-god-sheet"), false) and all_passed
	var small_sheet: EventSheetResource = EventSheetResource.new()
	var small_event: EventRow = EventRow.new()
	small_event.trigger_provider_id = "Core"
	small_event.trigger_id = "OnReady"
	var small_code: RawCodeRow = RawCodeRow.new()
	small_code.code = "$Player.x = 1\n$Enemy.x = 1"
	small_event.actions.append(small_code)
	small_sheet.events.append(small_event)
	ResourceSaver.save(small_sheet, "user://doctor_small.tres")
	findings = []
	EventSheetProjectDoctor.check_fanout_god_sheets(PackedStringArray(["user://doctor_small.tres"]), findings)
	all_passed = _check("a sheet touching few nodes is not flagged (rows aren't the trigger)", _has(findings, "info", "fanout-god-sheet"), false) and all_passed
	ProjectSettings.set_setting("eventsheets/doctor/fanout_threshold", null)
	DirAccess.remove_absolute("user://doctor_fan.tres")
	DirAccess.remove_absolute("user://doctor_small.tres")

	# The repo gate: this repository must be doctor-clean at the error level - the
	# byte-identity contract pack goldens pin, generalized to every committed sheet.
	var audit_start_usec: int = Time.get_ticks_usec()
	var report: Dictionary = EventSheetProjectDoctor.run()
	var audit_ms: float = float(Time.get_ticks_usec() - audit_start_usec) / 1000.0
	all_passed = _check("the whole audit runs under %d ms (took %.0f ms)" % [
		DOCTOR_BUDGET_MS, audit_ms], audit_ms <= float(DOCTOR_BUDGET_MS), true) and all_passed
	for finding: Dictionary in (report.get("findings", []) as Array):
		if str(finding.get("severity")) == "error":
			print("  doctor error: %s - %s" % [str(finding.get("path")), str(finding.get("message"))])
	all_passed = _check("repo is doctor-clean (0 errors)", int(report.get("errors", 0)), 0) and all_passed
	var unused_packs: PackedStringArray = PackedStringArray()
	for finding: Dictionary in (report.get("findings", []) as Array):
		if str(finding.get("check")) == "unused-pack":
			unused_packs.append(str(finding.get("path")))
	all_passed = _check("scene-attached packs count as used",
		unused_packs.has("res://eventsheet_addons/spring/spring_behavior.gd"), false) and all_passed
	all_passed = _check("never-referenced packs get an advisory note",
		unused_packs.has("res://eventsheet_addons/car/car_behavior.gd"), true) and all_passed

	DirAccess.remove_absolute(generated_path)
	DirAccess.remove_absolute(sheet_path)
	DirAccess.remove_absolute(bus_path)
	return all_passed


static func _has(findings: Array[Dictionary], severity: String, check: String) -> bool:
	for finding: Dictionary in findings:
		if str(finding.get("severity")) == severity and str(finding.get("check")) == check:
			return true
	return false


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] project_doctor_test: %s" % label)
		return true
	print("[FAIL] project_doctor_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
