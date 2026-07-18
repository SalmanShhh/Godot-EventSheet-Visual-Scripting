# Godot EventSheets - Connect Signal to Event Sheet (the Node-dock flow)
# Right-click a node with a sheet, pick a signal, and an On <Signal> trigger event lands in
# its sheet - the same gesture as connecting to a script method, but the handler is an event
# row. Pins: the trigger mapping (core signals to their named triggers, others to
# signal:<name> with args baked), the signal enumeration's signature format, the compiled
# handler + self-connect shapes, and the byte round-trip.
@tool
class_name SignalConnectTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true

	# ---- the trigger mapping, pure ----
	var core_row: EventRow = EventSheets.build_signal_trigger_event("body_entered")
	all_passed = _check("a core signal maps to its named trigger", core_row.trigger_id, "OnBodyEntered") and all_passed
	all_passed = _check("core triggers ride the Core provider", core_row.trigger_provider_id, "Core") and all_passed
	var custom_row: EventRow = EventSheets.build_signal_trigger_event("exploded", "power: int")
	all_passed = _check("a custom signal becomes signal:<name>", custom_row.trigger_id, "signal:exploded") and all_passed
	all_passed = _check("its handler signature is baked", custom_row.trigger_args, "power: int") and all_passed

	# ---- signal enumeration: script signals AND native ones, signatures formatted ----
	var probe: Node = Node.new()
	var probe_script: GDScript = GDScript.new()
	probe_script.source_code = "extends Node\n\nsignal exploded(power: int, source: Node)\n"
	probe_script.reload()
	probe.set_script(probe_script)
	var listed: Array[Dictionary] = EventSheets.signals_of(probe)
	var exploded_args: String = ""
	var has_native: bool = false
	for signal_info: Dictionary in listed:
		if str(signal_info.get("name", "")) == "exploded":
			exploded_args = str(signal_info.get("args", ""))
		if str(signal_info.get("name", "")) == "renamed":
			has_native = true
	all_passed = _check("the script signal enumerates with its baked signature", exploded_args, "power: int, source: Node") and all_passed
	all_passed = _check("native class signals enumerate too", has_native, true) and all_passed
	probe.free()

	# ---- compiled shape: named handler + self-connect for a real base-class signal ----
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Area2D"
	var hit_row: EventRow = EventSheets.build_signal_trigger_event("body_entered")
	var poke: ACEAction = ACEAction.new()
	poke.provider_id = "Core"
	poke.ace_id = "Print"
	poke.codegen_template = "print({value})"
	poke.params = {"value": "\"hit\""}
	hit_row.actions.append(poke)
	sheet.events.append(hit_row)
	var output: String = str(SheetCompiler.compile(sheet, "user://signal_connect_probe.gd").get("output", ""))
	all_passed = _check("the handler emits under its trigger name", output.contains("func _on_body_entered(body: Node) -> void:"), true) and all_passed
	all_passed = _check("the self-connect emits in _ready", output.contains("\tbody_entered.connect(_on_body_entered)"), true) and all_passed
	all_passed = _check("the connected sheet round-trips byte-exact", EventSheets.round_trips(output), true) and all_passed

	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		return true
	print("  [FAIL] signal_connect_test: %s (got %s, expected %s)" % [label, str(actual), str(expected)])
	return false
