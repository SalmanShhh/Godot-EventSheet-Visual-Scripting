# Godot EventSheets - the shipped packs and the builders that produce them must agree.
# eventsheet_addons/ is compiler output: every file there is supposed to be exactly what
# tools/pack_builders/<name>.gd emits today. Nothing noticed when the two drifted apart, because
# the disagreement only surfaces when somebody runs the rebuild - and then it looks like their
# change, not like a debt that had been sitting there. So this gate rebuilds a couple of packs
# through the real builders (redirected to a scratch directory, so the repository is never
# touched) and compares the bytes against the shipped files.
#
# Two packs, not all 112 - the full sweep is the build tool itself
# (tools/build_sample_behaviors.gd, whose faithfulness gate is tools/audit_addons.gd). These two
# cover what actually drifted: member order with exported and internal variables interleaved
# (car), and Inspector groups, whose headers move with the variables they precede
# (uhtn_plan_resource).
#
# When this fails: the builder is the thing to change, never the shipped pack - member order is
# user-visible (the head bars read in file order, and a .tres stores properties in the script's
# declaration order), so reordering a builder's `sheet.variables` rewrites shipped files and any
# resource saved against them.
@tool
class_name PackBuilderMatchesShippedTest
extends RefCounted

const Lib := preload("res://tools/pack_builders/_lib.gd")

const SCRATCH_DIR := "user://eventsheets_pack_builder_gate"

# builder file basename -> the pack .gd it ships.
const GATED_PACKS := {
	"car": "res://eventsheet_addons/car/car_behavior.gd",
	"uhtn_plan_resource": "res://eventsheet_addons/uhtn_plan_resource/uhtn_plan_resource.gd"
}


static func run() -> bool:
	var all_passed: bool = true
	DirAccess.make_dir_recursive_absolute(SCRATCH_DIR)
	for builder_name: String in GATED_PACKS:
		all_passed = _check_pack(builder_name, str(GATED_PACKS[builder_name])) and all_passed
	return all_passed


## Rebuilds one pack through its real builder and compares it byte-for-byte with the shipped file.
static func _check_pack(builder_name: String, shipped_path: String) -> bool:
	var builder: GDScript = load("res://tools/pack_builders/%s.gd" % builder_name)
	if builder == null or not builder.has_method("build"):
		return _check("%s: the builder loads" % builder_name, false, true)
	var shipped: String = FileAccess.get_file_as_string(shipped_path)
	if shipped.is_empty():
		return _check("%s: the shipped pack reads" % builder_name, false, true)
	# The override is a shared static, so it is cleared the moment the build returns - a later
	# test that publishes a pack must not inherit this test's scratch directory.
	Lib.output_override_dir = SCRATCH_DIR
	var built: bool = bool(builder.call("build"))
	Lib.output_override_dir = ""
	var rebuilt_path: String = SCRATCH_DIR.path_join(shipped_path.get_file())
	var rebuilt: String = FileAccess.get_file_as_string(rebuilt_path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(rebuilt_path))
	var passed: bool = _check("%s: the builder compiles" % builder_name, built, true)
	if rebuilt == shipped:
		return passed
	return _check("%s: the builder reproduces %s (%s)" % [builder_name, shipped_path.get_file(),
		_first_difference(shipped, rebuilt)], false, true) and passed


## The first line that differs, so a failure names the drift instead of dumping two files.
static func _first_difference(shipped: String, rebuilt: String) -> String:
	var shipped_lines: PackedStringArray = shipped.split("\n")
	var rebuilt_lines: PackedStringArray = rebuilt.split("\n")
	for index: int in range(max(shipped_lines.size(), rebuilt_lines.size())):
		var left: String = shipped_lines[index] if index < shipped_lines.size() else "<end of file>"
		var right: String = rebuilt_lines[index] if index < rebuilt_lines.size() else "<end of file>"
		if left != right:
			return "line %d: shipped %s, rebuilt %s" % [index + 1, left, right]
	return "no line differs (trailing bytes)"


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		return true
	print("  [FAIL] pack_builder_matches_shipped_test: %s (got %s, expected %s)" % [label, str(actual), str(expected)])
	return false
