# EventForge — While / Repeat loops compile to real GDScript loops, so a behaviour can loop code-free
# (no GDScript block). They are the PickFilter WHILE / REPEAT kinds, added via Add Pick Filter ->
# "While (condition)" / "Repeat N times". This pins that a While loop compiles to `while <expr>:`
# wrapping the event body — the loop construct that was the last gap for fully code-free authoring.
@tool
class_name WhileLoopTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true

	# While loop: PickFilter WHILE -> `while <condition>:` around the event body.
	var while_out: String = _compile_loop(PickFilter.CollectionKind.WHILE, "remaining > 0", "item")
	ok = _check("While loop compiles to a `while <expr>:` header", while_out.contains("while remaining > 0:"), true) and ok
	ok = _check("While loop body sits inside the loop", while_out.contains("remaining += -1"), true) and ok

	# Repeat loop: PickFilter REPEAT -> a `for <i> in range(<n>):` counted loop.
	var repeat_out: String = _compile_loop(PickFilter.CollectionKind.REPEAT, "5", "i")
	ok = _check("Repeat loop compiles to a `for … in range(5):` header", repeat_out.contains("in range(5):"), true) and ok

	return ok


static func _compile_loop(kind: int, collection_value: String, iterator_name: String) -> String:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	sheet.variables = {"remaining": {"type": "int", "default": 3, "exported": false}}
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnReady"
	var pick: PickFilter = PickFilter.new()
	pick.collection_kind = kind
	pick.collection_value = collection_value
	pick.iterator_name = iterator_name
	event.pick_filters.append(pick)
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "AddVar"
	action.params = {"var_name": "remaining", "amount": "-1"}
	event.actions.append(action)
	sheet.events.append(event)
	return str(SheetCompiler.compile(sheet).get("output", ""))


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] while_loop_test: %s" % label)
		return true
	print("[FAIL] while_loop_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
