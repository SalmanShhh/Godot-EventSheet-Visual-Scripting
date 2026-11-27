# Godot EventSheets - a typed variable always wears the class of the node it points at.
#
# A 2D pack and its 3D twin (Pin and Pin 3D, Juice and Juice 3D, the camera rails, the navigation agents)
# publish verbs with the same names and the same call shape, and a scene can use the same node name for
# either. A node variable must be given the class of the pack the row came from, and a path that two packs
# claim must stay a path rather than be given either. This pins that on rows, and then on every shipped
# showcase: each script that declares typed variables is held up against its own scene, node by node,
# and the compiler's note above the declarations is never read as a cut comment.
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const TEST_NAME := "typed_node_twin_packs_test"
const NodeVariables := preload("res://addons/eventforge/compiler/node_variables.gd")
const Findings := preload("res://addons/eventsheet/ace/annotation_findings.gd")
const SHOWCASES := "res://demo/showcase/"


static func run() -> bool:
	var ok: bool = true
	ok = _rows_of_twin_packs(ok)
	ok = _every_showcase_matches_its_scene(ok)
	return ok


static func _call_row(provider: String, receiver: String) -> EventRow:
	var action: ACEAction = ACEAction.new()
	action.provider_id = provider
	action.ace_id = "method:set_mode"
	action.codegen_template = "%s.set_mode(\"x\")" % receiver
	var row: EventRow = EventRow.new()
	row.actions.append(action)
	return row


static func _rows_of_twin_packs(ok: bool) -> bool:
	var twins: Array = [
		["PinBehavior", "Pin3DBehavior"], ["JuiceBehavior", "Juice3DBehavior"],
		["CameraRailBehavior", "CameraRail3DBehavior"], ["VectorShape2D", "VectorShape3D"],
	]
	var rows: Array = []
	for pair: Array in twins:
		for name: Variant in pair:
			if _is_pack_class(str(name)):
				var typed: Dictionary = {}
				NodeVariables.types_from_rows([_call_row(str(name), "$Lantern/Mode")], typed, {})
				rows.append(["a %s row is typed with its own class" % name, typed, {"$Lantern/Mode": str(name)}])
		rows.append(["both twins of %s exist as global classes" % pair[0], [_is_pack_class(str(pair[0])), _is_pack_class(str(pair[1]))], [true, true]])
	# Two packs on one path: neither is the answer, so the path is left untyped.
	var together: Dictionary = {}
	var conflicts: Dictionary = {}
	NodeVariables.types_from_rows([_call_row("PinBehavior", "$A/Pin"), _call_row("Pin3DBehavior", "$A/Pin")], together, conflicts)
	rows.append(["a path that two twin packs claim is reported as a clash", conflicts.has("$A/Pin"), true])
	# Each row on its own path keeps its own pack.
	var apart: Dictionary = {}
	NodeVariables.types_from_rows([_call_row("PinBehavior", "$A/Pin"), _call_row("Pin3DBehavior", "$B/Pin")], apart, {})
	rows.append(["a 2D row and a 3D row on different paths keep their own classes", apart, {"$A/Pin": "PinBehavior", "$B/Pin": "Pin3DBehavior"}])
	return SUPPORT.pins(TEST_NAME, rows) and ok


static func _is_pack_class(name: String) -> bool:
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		if str(entry.get("class", "")) == name:
			return true
	return false


static func _every_showcase_matches_its_scene(ok: bool) -> bool:
	var checked: int = 0
	var wrong: PackedStringArray = PackedStringArray()
	var cut: PackedStringArray = PackedStringArray()
	for folder: String in DirAccess.get_directories_at(SHOWCASES):
		for file_name: String in DirAccess.get_files_at(SHOWCASES + folder):
			if not file_name.ends_with(".gd"):
				continue
			var script_path: String = "%s%s/%s" % [SHOWCASES, folder, file_name]
			var source: String = FileAccess.get_file_as_string(script_path)
			if not source.contains("# Nodes this sheet calls, declared once with their type."):
				continue
			checked += 1
			for finding: Dictionary in Findings.read(source):
				if str(finding.get("kind", "")) == Findings.KIND_BLOCK_CUT:
					cut.append(script_path)
			var scene_path: String = script_path.get_basename() + ".tscn"
			if not FileAccess.file_exists(scene_path):
				continue
			for finding: Dictionary in EventSheetBehaviourHostDoctor.report_for_scene(scene_path, FileAccess.get_file_as_string(scene_path)):
				if str(finding.get("message", "")).contains("calls the node"):
					wrong.append(str(finding["message"]))
	return SUPPORT.pins(TEST_NAME, [
		["the showcases that keep typed variables were found", checked > 10, true],
		["every typed variable of every showcase is the class its scene gives the node", wrong, PackedStringArray()],
		["the compiler's note over the declarations is never a cut comment", cut, PackedStringArray()],
	]) and ok
