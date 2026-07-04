# EventForge - a SignalRow can publish itself as a trigger ACE (## @ace_trigger), so a behaviour
# declares a code-free trigger signal as a row instead of a hand-written GDScript block. A plain
# (non-trigger) signal emits exactly as before - no annotation lines - so existing signals are
# byte-identical. Pins _emit_signal_annotations + _emit_signal_line (both static).
@tool
class_name SignalTriggerRowTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true

	# A trigger signal with a name + category emits the full annotation block above the declaration.
	var trig: SignalRow = SignalRow.new()
	trig.signal_name = "flash_finished"
	trig.trigger = true
	trig.ace_name = "Flash Finished"
	trig.ace_category = "Juice"
	var ann: PackedStringArray = SheetCompiler._emit_signal_annotations(trig)
	ok = _check("trigger annotation block", "\n".join(ann), "## @ace_trigger\n## @ace_name(\"Flash Finished\")\n## @ace_category(\"Juice\")") and ok
	ok = _check("trigger signal line is the plain declaration", SheetCompiler._emit_signal_line(trig), "signal flash_finished") and ok

	# Name/category are optional - bare @ace_trigger when omitted.
	var trig_bare: SignalRow = SignalRow.new()
	trig_bare.signal_name = "jumped"
	trig_bare.trigger = true
	ok = _check("trigger with no name/category emits just @ace_trigger", "\n".join(SheetCompiler._emit_signal_annotations(trig_bare)), "## @ace_trigger") and ok

	# A plain signal emits NO annotations (byte-identical to before this feature).
	var plain: SignalRow = SignalRow.new()
	plain.signal_name = "died"
	plain.params = PackedStringArray(["amount: int"])
	ok = _check("plain signal emits no annotations", SheetCompiler._emit_signal_annotations(plain).is_empty(), true) and ok
	ok = _check("plain signal line unchanged", SheetCompiler._emit_signal_line(plain), "signal died(amount: int)") and ok

	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] signal_trigger_row_test: %s" % label)
		return true
	print("[FAIL] signal_trigger_row_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
