# Godot EventSheets — Project Doctor: the one CI-able audit for cross-file drift
# (stale generated outputs, unregistered autoload sheets, unused vocabulary, scene
# attachment). The final block runs the doctor on THIS repository — it doubles as the
# repo-health gate: every committed generated script must byte-match its sheet.
@tool
extends RefCounted
class_name ProjectDoctorTest

static func run() -> bool:
	var all_passed: bool = true

	# Output pairing: editor convention (<name>_generated.gd) first, the pack builder's
	# header-verified shipped sibling (<name>.gd) as fallback — ONE rule shared by the
	# doctor, compile-on-save and the export-integrity pass.
	all_passed = _check("demo sheet pairs with its _generated script",
		EventSheetProjectDoctor.output_path_for("res://demo/sheets/player.tres"),
		"res://demo/sheets/player_generated.gd") and all_passed
	all_passed = _check("pack sheet pairs with its shipped sibling",
		EventSheetProjectDoctor.output_path_for("res://eventsheet_addons/spring/spring_behavior.tres"),
		"res://eventsheet_addons/spring/spring_behavior.gd") and all_passed
	all_passed = _check("showcase pairs with the builder's sibling (the doctor's first catch)",
		EventSheetProjectDoctor.output_path_for("res://demo/showcase/showcase_v060.tres"),
		"res://demo/showcase/showcase_v060.gd") and all_passed
	# Regression: the export-integrity pass ran earlier in this suite — it must refresh
	# the showcase's existing pair, never recreate the parallel _generated duplicate.
	all_passed = _check("export pass no longer duplicates builder-shipped outputs",
		FileAccess.file_exists("res://demo/showcase/showcase_v060_generated.gd"), false) and all_passed
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

	# The repo gate: this repository must be doctor-clean at the error level — the
	# byte-identity contract pack goldens pin, generalized to every committed sheet.
	var report: Dictionary = EventSheetProjectDoctor.run()
	for finding: Dictionary in (report.get("findings", []) as Array):
		if str(finding.get("severity")) == "error":
			print("  doctor error: %s — %s" % [str(finding.get("path")), str(finding.get("message"))])
	all_passed = _check("repo is doctor-clean (0 errors)", int(report.get("errors", 0)), 0) and all_passed
	var unused_packs: PackedStringArray = PackedStringArray()
	for finding: Dictionary in (report.get("findings", []) as Array):
		if str(finding.get("check")) == "unused-pack":
			unused_packs.append(str(finding.get("path")))
	all_passed = _check("scene-attached packs count as used",
		unused_packs.has("res://eventsheet_addons/spring/spring_behavior.gd"), false) and all_passed
	all_passed = _check("never-referenced packs get an advisory note",
		unused_packs.has("res://eventsheet_addons/platformer_movement/platformer_movement_behavior.gd"), true) and all_passed

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
