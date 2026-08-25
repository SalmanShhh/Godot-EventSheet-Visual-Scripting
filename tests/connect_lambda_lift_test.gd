# `signal.connect(func(): …)` opens as the event it is.
#
# A handler written as a named function already lifts: `_ready` wires it, the connect line names it,
# and the function becomes the event's rows. A handler written as a LAMBDA inside the connect call
# had no name to find, so the whole `_ready` stayed code - and with it every reading of what that
# script actually does when the button is pressed.
#
# The signal, the emitter and the lambda's parameters are read, because they are what the row says.
# Everything else is kept verbatim, so writing it back is substituting the body in between the two
# halves of the author's own spelling. What cannot be re-spelled stays the statement it was.
@tool
class_name ConnectLambdaLiftTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true

	# ── The single-line form: one connect, one statement, one event ──
	var inline_source: String = "extends Control\n\n\nfunc _ready():\n\t$Play.pressed.connect(func(): start_game())\n\n\nfunc start_game():\n\tpass\n"
	var inline_sheet: EventSheetResource = GDScriptImporter.new().import_external_source(inline_source)
	var inline_events: Array = _events(inline_sheet)
	ok = _check("the inline lambda lifts to one event", inline_events.size(), 1) and ok
	if inline_events.size() == 1:
		var wired: EventRow = inline_events[0]
		ok = _check("on the signal it names", wired.trigger_id, "signal:pressed") and ok
		ok = _check("off the node it names", wired.trigger_source_path, "Play") and ok
		ok = _check("with the body as its one action", wired.actions.size(), 1) and ok
	ok = _check("and `_ready` is left with nothing of its own",
		_has_trigger(inline_sheet, "OnReady"), false) and ok
	ok = _check("the inline form round-trips byte-identically",
		_roundtrip(inline_sheet, "user://_lambda_inline.gd"), inline_source) and ok

	# ── The block form: a body of several statements, and a signal with a known trigger ──
	var block_source: String = "extends Node\n\n\nfunc _ready():\n\t$Timer.timeout.connect(func():\n\t\thide_banner()\n\t\tshown += 1\n\t)\n\n\nfunc hide_banner():\n\tpass\n"
	var block_sheet: EventSheetResource = GDScriptImporter.new().import_external_source(block_source)
	var block_events: Array = _events(block_sheet)
	ok = _check("the block lambda lifts to one event", block_events.size(), 1) and ok
	if block_events.size() == 1:
		ok = _check("on the trigger the signal maps to", (block_events[0] as EventRow).trigger_id, "OnTimeout") and ok
		ok = _check("with both statements as its actions", (block_events[0] as EventRow).actions.size(), 2) and ok
	ok = _check("the block form round-trips byte-identically",
		_roundtrip(block_sheet, "user://_lambda_block.gd"), block_source) and ok

	# ── The lambda's own parameters are the event's payload ──
	var arg_source: String = "extends Area2D\n\n\nfunc _ready():\n\tbody_entered.connect(func(body): collect(body))\n\n\nfunc collect(body):\n\tpass\n"
	var arg_sheet: EventSheetResource = GDScriptImporter.new().import_external_source(arg_source)
	var arg_events: Array = _events(arg_sheet)
	ok = _check("a lambda parameter arrives as the trigger's argument",
		(arg_events[0] as EventRow).trigger_args if arg_events.size() == 1 else "", "body") and ok
	ok = _check("the parameter form round-trips byte-identically",
		_roundtrip(arg_sheet, "user://_lambda_args.gd"), arg_source) and ok

	# ── Two lambdas on the SAME signal are two wirings, and stay two ──
	var pair_source: String = "extends Control\n\n\nfunc _ready():\n\t$Play.pressed.connect(func(): start_game())\n\t$Quit.pressed.connect(func(): get_tree().quit())\n\n\nfunc start_game():\n\tpass\n"
	var pair_sheet: EventSheetResource = GDScriptImporter.new().import_external_source(pair_source)
	ok = _check("two lambdas on one signal stay two events", _events(pair_sheet).size(), 2) and ok
	ok = _check("and both come back where they were",
		_roundtrip(pair_sheet, "user://_lambda_pair.gd"), pair_source) and ok

	# ── What cannot be re-spelled stays a statement, and the file still opens ──
	var late_source: String = "extends Node\n\n\nfunc _ready():\n\tadd_to_group(\"ui\")\n\t$Play.pressed.connect(func(): start_game())\n\n\nfunc start_game():\n\tpass\n"
	var late_sheet: EventSheetResource = GDScriptImporter.new().import_external_source(late_source)
	ok = _check("a lambda below other setup is left as a statement",
		_has_trigger(late_sheet, "signal:pressed"), false) and ok
	ok = _check("`_ready` keeps it, and the file round-trips",
		_roundtrip(late_sheet, "user://_lambda_late.gd"), late_source) and ok

	# ── Editing the row writes code: a second action no longer fits on one line, so the statement
	# is written in the shape that holds it. Nothing is dropped, which is the point ──
	var grown_sheet: EventSheetResource = GDScriptImporter.new().import_external_source(inline_source)
	var grown_events: Array = _events(grown_sheet)
	if grown_events.size() == 1:
		var added: RawCodeRow = RawCodeRow.new()
		added.code = "print(\"here\")"
		(grown_events[0] as EventRow).actions.append(added)
	var grown: String = _roundtrip(grown_sheet, "user://_lambda_grown.gd")
	ok = _check("the grown lambda is written as a block",
		grown.contains("$Play.pressed.connect(func():\n\t\tstart_game()\n\t\tprint(\"here\")\n\t)"), true) and ok

	return ok


static func _events(sheet: EventSheetResource) -> Array:
	var found: Array = []
	for item: Variant in sheet.events:
		if item is EventRow:
			found.append(item)
	return found


static func _has_trigger(sheet: EventSheetResource, trigger_id: String) -> bool:
	for item: Variant in sheet.events:
		if item is EventRow and (item as EventRow).trigger_id == trigger_id:
			return true
	return false


static func _roundtrip(sheet: EventSheetResource, path: String) -> String:
	sheet.external_source_path = path
	return str(SheetCompiler.compile(sheet, path).get("output", ""))


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] connect_lambda_lift_test: %s" % label)
		return true
	print("[FAIL] connect_lambda_lift_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
