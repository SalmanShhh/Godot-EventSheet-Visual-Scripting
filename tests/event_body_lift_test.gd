# EventForge — build-time de-coding of EVENT bodies (the sibling of the function-body lift).
# A behaviour's OnProcess/OnPhysicsProcess tick authored as one verbatim RawCode block is reverse-
# lifted into if/else/elseif CONDITION rows + action rows, folded into the event's sub_events (the
# ordered list the compiler walks). This is what makes a behaviour read like a Construct event sheet.
# The per-event byte-identical gate guarantees the shipped GDScript never changes.
@tool
extends RefCounted
class_name EventBodyLiftTest

static func run() -> bool:
	var ok: bool = true

	# An OnProcess event whose body is an if/else plus an assignment and a method call.
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnProcess"
	var raw: RawCodeRow = RawCodeRow.new()
	raw.code = "\n".join(PackedStringArray([
		"if health > 0:",
		"\tscore += 1",
		"else:",
		"\thealth = 100",
		"$Hud.refresh_now(true)",
	]))
	event.actions.append(raw)
	sheet.events.append(event)
	var before: String = str(SheetCompiler.compile(sheet, "user://eb_before.gd").get("output", ""))

	var lifted_count: int = EventSheetACELifter.lift_event_bodies(sheet)
	ok = _check("one event body lifted", lifted_count, 1) and ok

	var target: EventRow = null
	for row: Variant in sheet.events:
		if row is EventRow and (row as EventRow).trigger_id == "OnProcess":
			target = row
	ok = _check("body moved out of actions into sub_events",
		target != null and target.actions.is_empty() and not target.sub_events.is_empty(), true) and ok

	# The if/else structure renders as condition rows: a conditioned row + a chained ELSE row.
	var has_conditioned: bool = false
	var has_else: bool = false
	for row: Variant in (target.sub_events if target != null else []):
		if row is EventRow:
			if not (row as EventRow).conditions.is_empty():
				has_conditioned = true
			if (row as EventRow).else_mode == EventRow.ElseMode.ELSE:
				has_else = true
	ok = _check("the `if` becomes a conditioned row", has_conditioned, true) and ok
	ok = _check("the `else` becomes an ELSE row", has_else, true) and ok

	# The gate already enforces this, but assert the invariant directly.
	var after: String = str(SheetCompiler.compile(sheet, "user://eb_after.gd").get("output", ""))
	ok = _check("event-body lift round-trips byte-identically", after == before, true) and ok
	if after != before:
		print("  --- before ---\n%s\n  --- after ---\n%s" % [before, after])

	# Idempotent: a second pass finds nothing left to lift (the body is already rows).
	ok = _check("second pass is a no-op", EventSheetACELifter.lift_event_bodies(sheet), 0) and ok

	return ok

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] event_body_lift_test: %s" % label)
		return true
	print("[FAIL] event_body_lift_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
