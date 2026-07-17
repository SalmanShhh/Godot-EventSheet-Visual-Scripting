# Godot EventSheets - the Doctor's pack-dependency check
# An IN-USE pack whose `## @ace_requires(...)` names something absent gets a warning
# (clickable - the path is the pack's own .gd); an unused pack's unmet dependency stays
# silent, and a satisfied requirement emits nothing. Pins: each _requirement_present form
# (bare class via ClassDB AND project global classes, autoload:, pack:), fires-when-missing
# with the exact message, silent-when-present, silent-when-unused, and the real repo
# reporting zero pack-dependency findings (all shipped declarations are satisfied).
@tool
class_name PackDependencyDoctorTest
extends RefCounted

const PROBE_DIR := "res://eventsheet_addons/__dep_probe__"
const PROBE_SCRIPT := "res://eventsheet_addons/__dep_probe__/dep_probe.gd"
const PROBE_SCENE := "res://__dep_probe_usage.tscn"


static func run() -> bool:
	var all_passed: bool = true

	# ---- the resolver, form by form ----
	all_passed = _check("an engine class satisfies a bare name", EventSheetProjectDoctor._requirement_present("Node2D"), true) and all_passed
	all_passed = _check("a project global class satisfies a bare name (ClassDB alone would miss it)",
		EventSheetProjectDoctor._requirement_present("StatSheetResource"), true) and all_passed
	all_passed = _check("a missing class reports absent", EventSheetProjectDoctor._requirement_present("NoSuchClassAnywhere"), false) and all_passed
	all_passed = _check("an installed pack satisfies pack:", EventSheetProjectDoctor._requirement_present("pack:stat_forge"), true) and all_passed
	all_passed = _check("a missing pack reports absent", EventSheetProjectDoctor._requirement_present("pack:no_such_pack"), false) and all_passed
	all_passed = _check("an unregistered autoload reports absent", EventSheetProjectDoctor._requirement_present("autoload:NoSuchAutoload"), false) and all_passed

	# ---- fires-when-missing: an in-use probe pack with an unmet requirement warns ----
	_write_probe("## @ace_requires(NoSuchClassAnywhere, autoload:NoSuchAutoload)", true)
	var findings: Array[Dictionary] = []
	EventSheetProjectDoctor.check_pack_dependencies(PackedStringArray(), findings)
	var probe_findings: Array[Dictionary] = _probe_findings(findings)
	all_passed = _check("a missing requirement on an in-use pack warns", probe_findings.size(), 1) and all_passed
	if probe_findings.size() == 1:
		all_passed = _check("the finding is a warning", str(probe_findings[0].get("severity", "")), "warning") and all_passed
		all_passed = _check("the path is the pack's own script (clickable)", str(probe_findings[0].get("path", "")), PROBE_SCRIPT) and all_passed
		all_passed = _check("the message names the missing entries, sorted",
			str(probe_findings[0].get("message", "")),
			"Pack class DepProbePack requires NoSuchClassAnywhere, autoload:NoSuchAutoload, which isn't present - install the pack it names (or register the autoload).") and all_passed

	# ---- silent-when-present: a satisfied requirement emits nothing ----
	_write_probe("## @ace_requires(Node2D, pack:stat_forge)", true)
	findings = []
	EventSheetProjectDoctor.check_pack_dependencies(PackedStringArray(), findings)
	all_passed = _check("a satisfied requirement stays silent", _probe_findings(findings).size(), 0) and all_passed

	# ---- silent-when-unused: an unmet requirement on an UNUSED pack is noise, not a warning ----
	_write_probe("## @ace_requires(NoSuchClassAnywhere)", false)
	findings = []
	EventSheetProjectDoctor.check_pack_dependencies(PackedStringArray(), findings)
	all_passed = _check("an unused pack's unmet requirement stays silent", _probe_findings(findings).size(), 0) and all_passed

	_cleanup()

	# ---- the real repo: every shipped declaration is satisfied ----
	findings = []
	EventSheetProjectDoctor.check_pack_dependencies(PackedStringArray(), findings)
	all_passed = _check("shipped packs' declarations are all satisfied", findings.size(), 0) and all_passed

	return all_passed


## Drops the probe pack on disk; `in_use` also writes a scene file that references the
## script path, which is exactly how the check's usage corpus sees real packs.
static func _write_probe(requires_line: String, in_use: bool) -> void:
	_cleanup()
	DirAccess.make_dir_recursive_absolute(PROBE_DIR)
	var script_file: FileAccess = FileAccess.open(PROBE_SCRIPT, FileAccess.WRITE)
	script_file.store_string("## A test-only probe pack.\n%s\nclass_name DepProbePack\nextends Node\n" % requires_line)
	script_file.close()
	if in_use:
		var scene_file: FileAccess = FileAccess.open(PROBE_SCENE, FileAccess.WRITE)
		scene_file.store_string("[gd_scene format=3]\n\n[node name=\"Probe\" type=\"Node\"]\n; %s\n" % PROBE_SCRIPT)
		scene_file.close()


static func _probe_findings(findings: Array[Dictionary]) -> Array[Dictionary]:
	var matched: Array[Dictionary] = []
	for finding: Dictionary in findings:
		if str(finding.get("check", "")) == "pack-dependency" and str(finding.get("path", "")) == PROBE_SCRIPT:
			matched.append(finding)
	return matched


static func _cleanup() -> void:
	if FileAccess.file_exists(PROBE_SCRIPT):
		DirAccess.remove_absolute(PROBE_SCRIPT)
	if DirAccess.dir_exists_absolute(PROBE_DIR):
		DirAccess.remove_absolute(PROBE_DIR)
	if FileAccess.file_exists(PROBE_SCENE):
		DirAccess.remove_absolute(PROBE_SCENE)


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		return true
	print("  [FAIL] pack_dependency_doctor_test: %s" % label)
	print("    expected: %s" % str(expected))
	print("    actual:   %s" % str(actual))
	return false
