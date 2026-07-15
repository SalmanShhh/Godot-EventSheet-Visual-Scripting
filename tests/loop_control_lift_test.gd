# EventForge (gap G2) - `break` / `continue` inside a lifted loop body reverse-lift to Break Loop /
# Continue Loop ACTION rows, instead of staying an in-flow GDScript cell. They lift ONLY inside a loop
# (they are invalid GDScript anywhere else), including when nested in an `if` inside the loop, so a loop with
# an early-exit reads fully as events. `pass` is NOT lifted: it has no ACE and the compiler emits it only as
# an empty-body stub, so an empty block stays empty (reads as "no actions") rather than gaining a spurious
# action. Every reconstruction is gated by the byte-identical recompile, so the `.gd` round-trips.
@tool
class_name LoopControlLiftTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true

	# The natural "do work, then conditionally exit at the end" pattern: a `break` guarded by an `if` that is
	# the last thing in the loop body lifts to a Break Loop action row nested under the if.
	ok = _case("guarded break at the end of a loop lifts to Break Loop",
		"while alive:\n\ttick()\n\tif done:\n\t\tbreak",
		["LoopBreak"], []) and ok
	# The same for `continue` guarded by a trailing if.
	ok = _case("guarded continue lifts to Continue Loop",
		"for e in items:\n\te.tick()\n\tif e.dead:\n\t\tcontinue",
		["LoopContinue"], []) and ok
	# A bare `break` directly in the loop body (not behind an if).
	ok = _case("bare break in a for lifts to Break Loop",
		"for x in a:\n\tbreak",
		["LoopBreak"], []) and ok
	# Nested loops: the inner break belongs to the INNER loop (that is where it lifts).
	ok = _case("nested loops each keep their own break",
		"for a in outer:\n\tfor b in inner:\n\t\tbreak",
		["LoopBreak"], []) and ok
	# The empty-body `pass` stub must NOT become an action - an empty loop reads as empty and re-emits `pass`.
	ok = _case("an empty loop's pass stub is not lifted to an action",
		"for x in a:\n\tpass",
		[], ["LoopBreak", "LoopContinue"]) and ok

	return ok


## Authors an OnProcess body, compiles it, re-opens the output, and asserts the lifted ACTION ace_ids
## contain every id in `present` and none in `forbidden`, then that the whole thing round-trips byte-exact.
static func _case(label: String, body: String, present: Array, forbidden: Array) -> bool:
	var ok: bool = true
	var authored: EventSheetResource = EventSheetResource.new()
	authored.host_class = "Node2D"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnProcess"
	var raw: RawCodeRow = RawCodeRow.new()
	raw.code = body
	event.actions.append(raw)
	authored.events.append(event)
	var source: String = str(SheetCompiler.compile(authored, "user://lc_source.gd").get("output", ""))

	var imported: EventSheetResource = GDScriptImporter.new().import_external_source(source)
	var ids: Array = _collect_action_ace_ids(imported.events)
	for want: String in present:
		ok = _check("%s: '%s' lifted as an action" % [label, want], ids.has(want), true) and ok
	for nope: String in forbidden:
		ok = _check("%s: '%s' did NOT lift" % [label, nope], ids.has(nope), false) and ok

	imported.external_source_path = "user://lc_rt.gd"
	var roundtrip: String = str(SheetCompiler.compile(imported, "user://lc_rt.gd").get("output", ""))
	ok = _check("%s: round-trips byte-identically" % label, roundtrip == source, true) and ok
	if roundtrip != source:
		print("  --- source ---\n%s\n  --- roundtrip ---\n%s" % [source, roundtrip])
	return ok


## Walks events + sub_events, collecting every ACEAction's ace_id (loop-control lifts land in sub_events).
static func _collect_action_ace_ids(rows: Array) -> Array:
	var out: Array = []
	for row: Variant in rows:
		if row is EventRow:
			for a: Variant in (row as EventRow).actions:
				if a is ACEAction:
					out.append((a as ACEAction).ace_id)
			out.append_array(_collect_action_ace_ids((row as EventRow).sub_events))
	return out


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] loop_control_lift_test: %s" % label)
		return true
	print("[FAIL] loop_control_lift_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
