# EventForge — the flash pack is authored as pure ACE rows (ZERO RawCodeRow): the first bundled
# behaviour to prove the behaviour-as-ACEs path end to end. Loads the shipped flash_behavior.tres and
# asserts no RawCode survives anywhere (top-level events, sub-events, in-flow actions, function bodies),
# and that the behaviour still publishes its API (trigger signal + the two exposed functions). A
# regression here means a GDScript block crept back into the pack.
@tool
extends RefCounted
class_name FlashPackZeroRawcodeTest

static func run() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = load("res://eventsheet_addons/flash/flash_behavior.tres")
	ok = _check("flash pack loads", sheet != null, true) and ok
	if sheet == null:
		return ok

	var raw_count: int = _count_rawcode(sheet.events)
	for fn: Variant in sheet.functions:
		if fn is EventFunction:
			raw_count += _count_rawcode((fn as EventFunction).events)
	ok = _check("flash pack has zero RawCode rows", raw_count, 0) and ok

	# Sanity: the behaviour still publishes its API as code-free rows.
	var has_trigger: bool = false
	for row: Variant in sheet.events:
		if row is SignalRow and (row as SignalRow).trigger:
			has_trigger = true
	ok = _check("flash declares its trigger signal as a row", has_trigger, true) and ok
	ok = _check("flash exposes flash() + stop_flash()", sheet.functions.size(), 2) and ok
	return ok

## Counts RawCodeRow rows reachable from a row list: top-level, nested sub-events, and in-flow actions.
static func _count_rawcode(rows: Array) -> int:
	var count: int = 0
	for row: Variant in rows:
		if row is RawCodeRow:
			count += 1
		elif row is EventRow:
			count += _count_rawcode((row as EventRow).sub_events)
			count += _count_rawcode((row as EventRow).actions)
	return count

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] flash_pack_zero_rawcode_test: %s" % label)
		return true
	print("[FAIL] flash_pack_zero_rawcode_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
