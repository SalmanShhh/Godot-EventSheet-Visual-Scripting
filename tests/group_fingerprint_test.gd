# EventForge — group chapter fingerprints. ViewportRowBuilder.group_fingerprint reads
# a group's weight + hotness as "N events · ⟳a · ➜b · ▶c · ⚠d" (child events by trigger tempo class + the
# RawCode blocks inside), so a COLLAPSED group still tells you what's in it. Pins the counts + pluralisation.
@tool
class_name GroupFingerprintTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true

	var group: EventGroup = EventGroup.new()
	group.events.append(_ev("OnProcess"))         # ⟳ every-tick
	group.events.append(_ev("OnBodyEntered"))     # ➜ signal
	group.events.append(_ev("OnBodyEntered"))     # ➜ signal
	var once_event: EventRow = _ev("OnReady")     # ▶ once, with a raw block inside
	var raw: RawCodeRow = RawCodeRow.new()
	raw.code = "pass"
	once_event.actions.append(raw)
	group.events.append(once_event)
	ok = _check("full fingerprint", ViewportRowBuilder.group_fingerprint(group), "4 events · ⟳1 · ➜2 · ▶1 · ⚠1") and ok

	ok = _check("empty group → empty string", ViewportRowBuilder.group_fingerprint(EventGroup.new()), "") and ok
	ok = _check("null group → empty string", ViewportRowBuilder.group_fingerprint(null), "") and ok

	# Nested sub-events count as events (weight), but untimed rows add no tempo; singular pluralises.
	var group2: EventGroup = EventGroup.new()
	var parent: EventRow = _ev("OnProcess")
	parent.sub_events.append(_ev(""))              # a conditioned sub-event: an event, but untimed
	group2.events.append(parent)
	ok = _check("nested sub-event counted, singular kept", ViewportRowBuilder.group_fingerprint(group2), "2 events · ⟳1") and ok

	# A raw-only group (all code, no events) still reports its code weight.
	var group3: EventGroup = EventGroup.new()
	var block: RawCodeRow = RawCodeRow.new()
	block.code = "var x = 1"
	group3.events.append(block)
	ok = _check("raw-only group reports code", ViewportRowBuilder.group_fingerprint(group3), "0 events · ⚠1") and ok

	return ok


static func _ev(trigger_id: String) -> EventRow:
	var event_row: EventRow = EventRow.new()
	event_row.trigger_id = trigger_id
	if not trigger_id.is_empty():
		event_row.trigger_provider_id = "Core"
	return event_row


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] group_fingerprint_test: %s" % label)
		return true
	print("[FAIL] group_fingerprint_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
