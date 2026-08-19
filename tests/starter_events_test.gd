# Godot EventSheets - starter events per object type, and the same events for another object (V13).
#
# Pins VALUES, not counts: exactly which starters each class offers and what each one READS as, that
# a class nobody curated still derives its own from its signals, that a starter naming a signal the
# class does not have makes the sheet declare it, and that duplicating an object's events copies
# them with the object swapped and the originals untouched.
@tool
class_name StarterEventsTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _test_curated_classes() and all_passed
	all_passed = _test_inherited_and_derived() and all_passed
	all_passed = _test_declared_signals() and all_passed
	all_passed = _test_built_event() and all_passed
	all_passed = _test_pack_triggers() and all_passed
	all_passed = _test_duplicate_events() and all_passed
	return all_passed


static func _labels(host_class: String) -> String:
	var words: PackedStringArray = PackedStringArray()
	for starter: Variant in EventSheetStarterEvents.starters_for(host_class):
		words.append(str((starter as Dictionary).get("label", "")))
	return ", ".join(words)


# ── the curated sets ──────────────────────────────────────────────────────────────────────────


static func _test_curated_classes() -> bool:
	var passed: bool = _check("a body starts with the four events it always gets",
		_labels("CharacterBody2D"), "On created, Every tick (physics), On hit, On died")
	passed = _check("a button starts with the one event it has", _labels("Button"), "On clicked") and passed
	passed = _check("a timer starts with its timeout", _labels("Timer"), "On timer") and passed
	passed = _check("an area starts with the collision", _labels("Area2D"), "On collision with") and passed
	return passed


# ── inherited, and derived ────────────────────────────────────────────────────────────────────


static func _test_inherited_and_derived() -> bool:
	# A class nobody listed inherits the nearest curated set rather than falling through to nothing.
	var passed: bool = _check("a Button subclass gets the button's starters",
		_labels("MenuButton"), "On clicked")
	# And a class with no curated ancestor derives its own from the signals it declares.
	var derived: PackedStringArray = EventSheetStarterEvents.derived_trigger_ids("HTTPRequest")
	passed = _check("a class nobody curated derives its own signals",
		Array(derived).has("signal:request_completed"), true) and passed
	var starters: Array = EventSheetStarterEvents.starters_for("HTTPRequest")
	passed = _check("a derived set still leads with On created",
		str((starters[0] as Dictionary).get("label", "")), "On created") and passed
	passed = _check("a derived set stays a starter set, not a directory",
		starters.size() <= EventSheetStarterEvents.DERIVED_LIMIT + 1, true) and passed
	return passed


# ── the signals a starter set needs the sheet to declare ──────────────────────────────────────


static func _test_declared_signals() -> bool:
	var starters: Array = EventSheetStarterEvents.starters_for("CharacterBody2D")
	var sheet: EventSheetResource = EventSheetResource.new()
	var rows: Array = EventSheetStarterEvents.missing_signal_rows(starters, sheet)
	var names: PackedStringArray = PackedStringArray()
	for row: Variant in rows:
		names.append((row as SignalRow).signal_name)
	var passed: bool = _check("the two signals nobody declared are declared", ", ".join(names), "hit, died")
	# A signal the class itself has (a Timer's timeout) is the ENGINE's, never re-declared.
	passed = _check("an engine signal is not re-declared by the sheet",
		EventSheetStarterEvents.missing_signal_rows(
			EventSheetStarterEvents.starters_for("Timer"), sheet).size(), 0) and passed
	# Nor is one the sheet already declares.
	var declaration: SignalRow = SignalRow.new()
	declaration.signal_name = "hit"
	sheet.events.append(declaration)
	var second_pass: Array = EventSheetStarterEvents.missing_signal_rows(starters, sheet)
	passed = _check("a signal the sheet already declares is left alone", second_pass.size(), 1) and passed
	return passed


# ── the event a starter builds ────────────────────────────────────────────────────────────────


static func _test_built_event() -> bool:
	var timer: Dictionary = EventSheetStarterEvents.entry_for("signal:timeout", "Timer")
	var passed: bool = _check("an engine signal rides its own Core trigger",
		str(timer.get("trigger_id", "")), "OnTimeout")
	var area: Dictionary = EventSheetStarterEvents.entry_for("signal:body_entered", "Area2D")
	passed = _check("so does a collision", str(area.get("trigger_id", "")), "OnBodyEntered") and passed
	var clicked: Dictionary = EventSheetStarterEvents.entry_for("signal:pressed", "Button")
	passed = _check("a signal with no Core trigger rides the generic one",
		str(clicked.get("trigger_id", "")), "signal:pressed") and passed
	var event: EventRow = EventSheetStarterEvents.build_event(area)
	passed = _check("the starter's event carries the trigger", event.trigger_id, "OnBodyEntered") and passed
	passed = _check("and nothing in its action lane yet - the sheet's own placeholder",
		event.actions.size(), 0) and passed
	passed = _check("and no condition either", event.conditions.size(), 0) and passed
	return passed


# ── a pack's own triggers ─────────────────────────────────────────────────────────────────────


static func _test_pack_triggers() -> bool:
	var starters: Array = EventSheetStarterEvents.starters_for("Button",
		PackedStringArray(["landed"]))
	var words: PackedStringArray = PackedStringArray()
	for starter: Variant in starters:
		words.append(str((starter as Dictionary).get("label", "")))
	return _check("an attached pack's trigger joins the starters", ", ".join(words), "On clicked, On Landed")


# ── the same events, for another object ───────────────────────────────────────────────────────


static func _test_duplicate_events() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	var event: EventRow = EventRow.new()
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "SetProperty"
	action.codegen_template = "{target}.visible = false"
	action.params = {"target": "$Enemy"}
	event.actions.append(action)
	sheet.events.append(event)
	var untouched: EventRow = EventRow.new()
	sheet.events.append(untouched)
	var reference: String = EventSheetDuplicateEvents.reference_for(sheet, "Enemy")
	var passed: bool = _check("the object's own reference is what gets swapped", reference, "$Enemy")
	passed = _check("a sibling target keeps the source's spelling",
		EventSheetDuplicateEvents.target_reference("$Level/Enemy", "Enemy2"), "$Level/Enemy2") and passed
	passed = _check("a unique-name source gives a unique-name target",
		EventSheetDuplicateEvents.target_reference("%Enemy", "Enemy2"), "%Enemy2") and passed
	var copies: Array = EventSheetDuplicateEvents.copies_for(sheet, reference, "Enemy2")
	passed = _check("only the events that name the object are copied", copies.size(), 1) and passed
	passed = _check("the copy points at the other object",
		str(((copies[0] as EventRow).actions[0] as ACEAction).params.get("target", "")), "$Enemy2") and passed
	passed = _check("the original is untouched",
		str((action.params.get("target", ""))), "$Enemy") and passed
	passed = _check("duplicating for the object itself copies nothing",
		EventSheetDuplicateEvents.copies_for(sheet, reference, "Enemy").size(), 0) and passed
	return passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] starter_events_test: %s" % label)
		return true
	print("[FAIL] starter_events_test: %s - expected %s, got %s" % [label, str(expected), str(actual)])
	return false
