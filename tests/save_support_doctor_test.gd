# Godot EventSheets - the Doctor's "missing save support" check. A behavior or autoload
# that declares State (non-exported) variables but whose compiled script has no
# save_state/load_state seam is nudged (info-tier) - its runtime state would not survive
# Save Game. Property-only behaviors, seamed behaviors, and plain (non-node) sheets are
# left alone. Mirrors project_doctor_test: build a fixture, compile it to its output,
# run the single check, assert the finding.
@tool
class_name SaveSupportDoctorTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true

	# A behavior that declares State (non-exported) variables but ships no seam is flagged.
	all_passed = _check("stateful behavior without the seam is flagged",
		_message_for(_behavior_sheet(false), "ss_bare").contains("no save_state/load_state seam"), true) and all_passed

	# A behavior that DOES ship the seam is left alone.
	all_passed = _check("a behavior with the seam is not flagged",
		_message_for(_behavior_sheet(true), "ss_seamed").is_empty(), true) and all_passed

	# A behavior whose variables are all Properties (exported) has no runtime State to save.
	var props: EventSheetResource = _behavior_sheet(false)
	props.variables = {"speed": {"type": "float", "default": 1.0, "exported": true}}
	all_passed = _check("a behavior with only Property vars is not flagged",
		_message_for(props, "ss_props").is_empty(), true) and all_passed

	# A plain (non-behavior, non-autoload) sheet is scene glue, not a reusable node - skipped.
	var plain: EventSheetResource = _behavior_sheet(false)
	plain.behavior_mode = false
	all_passed = _check("a plain sheet with State is not flagged",
		_message_for(plain, "ss_plain").is_empty(), true) and all_passed

	# A stateful autoload (a singleton like an economy) is flagged, and named as one.
	var economy: EventSheetResource = _behavior_sheet(false)
	economy.behavior_mode = false
	economy.autoload_mode = true
	economy.autoload_name = "SsEconomy"
	var economy_message: String = _message_for(economy, "ss_auto")
	all_passed = _check("a stateful autoload without the seam is flagged as an autoload",
		economy_message.contains("This autoload holds"), true) and all_passed

	return all_passed


## A behavior sheet with one State variable; with_seam adds a save_state/load_state pair
## as a raw block (the same shape the packs ship), so the compiled output carries the seam.
static func _behavior_sheet(with_seam: bool) -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	sheet.behavior_mode = true
	sheet.custom_class_name = "SsDoctorFixture"
	sheet.variables = {"phase": {"type": "float", "default": 0.0, "exported": false}}
	if with_seam:
		var seam: RawCodeRow = RawCodeRow.new()
		seam.code = "func save_state() -> Dictionary:\n\treturn {\"phase\": phase}\n\nfunc load_state(state: Dictionary) -> void:\n\tphase = float(state.get(\"phase\", phase))"
		sheet.events.append(seam)
	return sheet


## Saves the fixture, compiles it to its output path, runs the single check, and returns
## the save-support finding's message ("" when there is none). Cleans up both files.
static func _message_for(sheet: EventSheetResource, name: String) -> String:
	var path: String = "user://%s.tres" % name
	ResourceSaver.save(sheet, path)
	var output_path: String = EventSheetProjectDoctor.output_path_for(path)
	SheetCompiler.compile(sheet, output_path)
	var findings: Array[Dictionary] = []
	EventSheetProjectDoctor.check_missing_save_support(PackedStringArray([path]), findings)
	var message: String = ""
	for finding: Dictionary in findings:
		if str(finding.get("check")) == "save-support":
			message = str(finding.get("message"))
	DirAccess.remove_absolute(path)
	if FileAccess.file_exists(output_path):
		DirAccess.remove_absolute(output_path)
	return message


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] save_support_doctor_test: %s" % label)
		return true
	print("[FAIL] save_support_doctor_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
