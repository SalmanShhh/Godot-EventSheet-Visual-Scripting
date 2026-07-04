# Godot EventSheets - On Signal can carry the signal's parameters into the event.
#
# The generic "On Signal" trigger (react to any signal by name) gained an optional Arguments field. When
# set to the signal's signature (e.g. "amount: int"), the generated handler takes those typed parameters,
# so the event body can use them - like the reflected signal:<name> triggers already could. Empty = a
# no-argument handler (the prior behavior). Uses a source node path so the connect isn't self-validated.
@tool
class_name OnSignalArgsTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true

	# (1) With an args signature: the handler receives the typed parameter, usable in the body.
	var out_args: String = _compile_on_signal("Enemy", "damaged", "amount: int", "health -= amount")
	all_passed = _check("handler gets the typed signal parameter", out_args.contains("func _on_enemy_damaged(amount: int) -> void:"), true) and all_passed
	all_passed = _check("connects the source signal", out_args.contains("get_node(\"Enemy\").damaged.connect(_on_enemy_damaged)"), true) and all_passed
	all_passed = _check("event body can use the parameter", out_args.contains("health -= amount"), true) and all_passed
	all_passed = _check("output parses", _parses(out_args), true) and all_passed

	# (2) No args (default): backward-compatible - a no-argument handler.
	var out_none: String = _compile_on_signal("Enemy", "pinged", "", "health += 1")
	all_passed = _check("no-arg handler when Arguments is empty", out_none.contains("func _on_enemy_pinged() -> void:"), true) and all_passed
	all_passed = _check("no stray parameter leaks in", out_none.contains("_on_enemy_pinged()"), true) and all_passed
	all_passed = _check("output parses (no args)", _parses(out_none), true) and all_passed

	return all_passed


static func _compile_on_signal(source: String, signal_name: String, args: String, body: String) -> String:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	sheet.variables = {"health": {"type": "int", "default": 100, "exported": false}}
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnSignal"
	event.trigger_source_path = source
	event.trigger_params = {"signal_name": signal_name, "args": args}
	var act: RawCodeRow = RawCodeRow.new()
	act.code = body
	event.actions.append(act)
	sheet.events.append(event)
	return str(SheetCompiler.compile(sheet, "user://on_signal_args.gd").get("output", ""))


static func _parses(source: String) -> bool:
	var generated: GDScript = GDScript.new()
	generated.source_code = source
	return generated.reload(true) == OK


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] on_signal_args_test: %s" % label)
		return true
	print("[FAIL] on_signal_args_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
