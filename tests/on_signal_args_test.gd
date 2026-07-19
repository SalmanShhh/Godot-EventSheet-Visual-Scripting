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

	# (3) THE REAL AUTHORING PATH (review regression): picking On Signal in the editor
	# must reach the compiler with the USER'S signal, not the dummy fallback. The earlier
	# pins hand-set trigger_params, which masked that the picker bake never wrote it -
	# every picker-authored On Signal silently connected to "eventforge_signal".
	var editor: EventSheetEditor = EventSheetEditor.new()
	var authored_sheet: EventSheetResource = EventSheetResource.new()
	authored_sheet.host_class = "Node"
	# The realistic flow: the sheet DECLARES the signal (self-connections validate
	# against declared signals), then On Signal listens for it.
	var declared: SignalRow = SignalRow.new()
	declared.signal_name = "player_died"
	declared.params = PackedStringArray(["score: int"])
	authored_sheet.events.append(declared)
	editor.setup(authored_sheet)
	editor.set_undo_redo_manager(FakeNoopUndo.new())
	var on_signal_def: ACEDefinition = editor._find_definition("Core", "OnSignal")
	editor._apply_ace_definition(on_signal_def, {"signal_name": "player_died", "args": "score: int"}, {"mode": "new_condition_event", "insert_into": authored_sheet})
	var authored_out: String = str(SheetCompiler.compile(authored_sheet, "user://on_signal_authored.gd").get("output", ""))
	all_passed = _check("a picker-authored On Signal connects the USER'S signal", authored_out.contains("player_died.connect("), true) and all_passed
	all_passed = _check("the dummy fallback signal never appears", authored_out.contains("eventforge_signal"), false) and all_passed
	all_passed = _check("the authored args reach the handler", authored_out.contains("(score: int)"), true) and all_passed
	editor.free()

	# (4) Drag / paste baking: a trigger handed around as a bare ACECondition must bake
	# the identity the compiler keys on, and removal must clear it (no phantom trigger).
	var bake_editor: EventSheetEditor = EventSheetEditor.new()
	bake_editor.setup(EventSheetResource.new())
	bake_editor.set_undo_redo_manager(FakeNoopUndo.new())
	var moved: EventRow = EventRow.new()
	var dragged_trigger: ACECondition = ACECondition.new()
	dragged_trigger.provider_id = "Core"
	dragged_trigger.ace_id = "OnSignal"
	dragged_trigger.params = {"signal_name": "wave_cleared", "args": ""}
	moved.trigger = dragged_trigger
	bake_editor._ace_apply.bake_trigger_from_condition(moved)
	all_passed = _check("bake-from-condition writes the compiler's key", moved.trigger_id, "OnSignal") and all_passed
	all_passed = _check("bake-from-condition carries the signal values", str(moved.trigger_params.get("signal_name", "")), "wave_cleared") and all_passed
	bake_editor._ace_apply.clear_baked_trigger(moved)
	all_passed = _check("clearing removes the baked identity (no phantom)", moved.trigger_id, "") and all_passed
	all_passed = _check("clearing removes the baked values too", moved.trigger_params.is_empty(), true) and all_passed
	bake_editor.free()

	return all_passed


class FakeNoopUndo:
	extends RefCounted
	func create_action(_a = null) -> void: pass
	func add_do_method(_a = null, _b = null, _c = null, _d = null, _e = null) -> void: pass
	func add_undo_method(_a = null, _b = null, _c = null, _d = null, _e = null) -> void: pass
	func commit_action() -> void: pass
	func has_undo() -> bool: return false
	func has_redo() -> bool: return false


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
