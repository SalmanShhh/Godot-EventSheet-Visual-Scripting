# Godot EventSheets - the group-picking expression family + the state machine's timing sugar.
#
# Picking: beyond nearest/furthest by distance, a sheet can pick a group member at random WITHOUT
# the empty-array error Array.pick_random() raises, or pick by a named property (lowest hp, highest
# score). All three land as plain expressions, so they drop straight into a Set Variable row - this
# test compiles such a sheet and pins the exact emitted GDScript.
#
# State machine: Set State now also records where it came from and when it arrived, which is what
# lets Time In State answer "how long have I been dashing?" without any per-sheet bookkeeping.
@tool
class_name GroupPickingAcesTest
extends RefCounted

const STATE_MACHINE_PACK := "res://eventsheet_addons/state_machine/state_machine_behavior"


static func run() -> bool:
	var all_passed: bool = true

	var by_id: Dictionary = {}
	for descriptor in EventForgeNodeACEs.get_descriptors():
		by_id[descriptor.ace_id] = descriptor
	all_passed = _check("RandomInGroup registered", by_id.has("RandomInGroup"), true) and all_passed
	all_passed = _check("SmallestInGroup registered", by_id.has("SmallestInGroup"), true) and all_passed
	all_passed = _check("LargestInGroup registered", by_id.has("LargestInGroup"), true) and all_passed
	if by_id.has("SmallestInGroup"):
		var smallest: ACEDescriptor = by_id["SmallestInGroup"]
		all_passed = _check("Smallest is an EXPRESSION", smallest.ace_type == ACEDescriptor.ACEType.EXPRESSION, true) and all_passed
		all_passed = _check("Smallest sits under Nodes: Picking", str(smallest.category), "Nodes: Picking") and all_passed
		all_passed = _check("Smallest takes group + property", _param_ids(smallest), "group,property") and all_passed
		all_passed = _check("Smallest's group param keeps the picker hint", str((smallest.params[0] as ACEParam).hint), "group_reference") and all_passed
	if by_id.has("LargestInGroup"):
		all_passed = _check("Largest compares the other way", str((by_id["LargestInGroup"] as ACEDescriptor).codegen_template).contains("__n.get({property}) > __acc.get({property})"), true) and all_passed

	# --- The expressions inside a real sheet: a Set Variable row compiles to the exact call ---
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	sheet.custom_class_name = "GroupPickingProbe"
	sheet.variables = {
		"lucky": {"type": "Variant", "default": null, "exported": false},
		"weakest": {"type": "Variant", "default": null, "exported": false}
	}
	var row: EventRow = EventRow.new()
	row.trigger_id = "OnReady"
	row.actions.append(_action("SetVar", {"var_name": "lucky", "value": _filled(by_id, "RandomInGroup")}))
	row.actions.append(_action("SetVar", {"var_name": "weakest", "value": _filled(by_id, "SmallestInGroup")}))
	sheet.events.append(row)
	var output: String = str(SheetCompiler.compile(sheet, "user://group_picking_probe.gd").get("output", ""))
	all_passed = _check("random pick emits the guarded pick_random()",
		output.contains("get_tree().get_nodes_in_group(\"enemies\").pick_random() if not get_tree().get_nodes_in_group(\"enemies\").is_empty() else null"), true) and all_passed
	all_passed = _check("smallest pick emits the get()-comparing reduce",
		output.contains("__n.get(\"hp\") < __acc.get(\"hp\")"), true) and all_passed
	all_passed = _check("the compiled probe is valid GDScript", _parses(output), true) and all_passed

	# --- State machine pack: the recorded previous state, the arrival stamp, and Time In State ---
	var pack_sheet: EventSheetResource = GDScriptImporter.new().import_external(STATE_MACHINE_PACK + ".gd")
	all_passed = _check("state machine pack imports as a behavior", pack_sheet != null and pack_sheet.behavior_mode, true) and all_passed
	if pack_sheet != null:
		var pack_output: String = str(SheetCompiler.compile(pack_sheet, "user://state_machine_probe.gd").get("output", ""))
		all_passed = _check("previous_state is declared", pack_output.contains("var previous_state: String = \"\""), true) and all_passed
		all_passed = _check("the arrival stamp is declared", pack_output.contains("var _state_entered_ticks: int = 0"), true) and all_passed
		all_passed = _check("Set State records where it came from", pack_output.contains("previous_state = previous"), true) and all_passed
		all_passed = _check("Set State stamps the arrival time", pack_output.contains("_state_entered_ticks = Time.get_ticks_msec()"), true) and all_passed
		all_passed = _check("Time In State returns seconds since that stamp",
			pack_output.contains("return (float(Time.get_ticks_msec() - _state_entered_ticks) / 1000.0)"), true) and all_passed
		all_passed = _check("Time In State publishes as an expression", pack_output.contains("## @ace_expression\n## @ace_name(\"Time In State\")"), true) and all_passed

	# The shipped class really answers time_in_state at runtime (a fresh machine starts near zero).
	var script: GDScript = load(STATE_MACHINE_PACK + ".gd")
	all_passed = _check("the pack script loads", script != null, true) and all_passed
	if script != null:
		var machine: Node = script.new()
		all_passed = _check("a fresh machine reports its previous state as empty", str(machine.previous_state), "") and all_passed
		machine.set_state("dash")
		all_passed = _check("Set State records the state it left", str(machine.previous_state), "idle") and all_passed
		all_passed = _check("Time In State is a non-negative number of seconds", machine.time_in_state() >= 0.0, true) and all_passed
		machine.free()

	return all_passed


## Fills an ACE template with its own parameter defaults - what a row shows the moment it is dropped.
static func _filled(by_id: Dictionary, ace_id: String) -> String:
	var descriptor: ACEDescriptor = by_id[ace_id]
	var template: String = str(descriptor.codegen_template)
	for parameter: ACEParam in descriptor.params:
		template = template.replace("{%s}" % parameter.id, str(parameter.default_value))
	return template


static func _param_ids(descriptor: ACEDescriptor) -> String:
	var ids: PackedStringArray = PackedStringArray()
	for parameter: ACEParam in descriptor.params:
		ids.append(str(parameter.id))
	return ",".join(ids)


static func _parses(source: String) -> bool:
	var script: GDScript = GDScript.new()
	script.source_code = source
	return script.reload(true) == OK


static func _action(ace_id: String, params: Dictionary) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	action.params = params
	return action


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] group_picking_aces_test: %s" % label)
		return true
	print("[FAIL] group_picking_aces_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
