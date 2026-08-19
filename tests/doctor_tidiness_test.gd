# Godot EventSheets - the Doctor's tidiness sweep
#
# Seven questions about vocabulary that stopped earning its line, each pinned as a VALUE on a
# hand-built sheet: no fixture is planted in the project, because a planted one would make the
# repo's own audit report the finding forever.
@tool
class_name DoctorTidinessTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true
	ok = _test_unread_locals() and ok
	ok = _test_uncalled_functions() and ok
	ok = _test_unfired_triggers() and ok
	ok = _test_unused_behaviors() and ok
	ok = _test_disabled_events() and ok
	ok = _test_identical_events() and ok
	ok = _test_repeated_literals() and ok
	ok = _test_extract_to_variable() and ok
	return ok


static func _test_unread_locals() -> bool:
	var ok: bool = true
	var event: EventRow = EventRow.new()
	var read_local: LocalVariable = LocalVariable.new()
	read_local.name = "speed"
	var dead_local: LocalVariable = LocalVariable.new()
	dead_local.name = "old_speed"
	event.local_variables = [read_local, dead_local] as Array[LocalVariable]
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "SetProperty"
	action.params = {"value": "speed * 2"}
	event.actions = [action] as Array[Resource]
	ok = _check("the local a later row reads is left alone; the other one is named",
		str(EventSheetDoctorTidiness.unread_locals([event])), "[\"old_speed\"]") and ok
	return ok


static func _test_uncalled_functions() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = EventSheetResource.new()
	var called: EventFunction = EventFunction.new()
	called.function_name = "apply_damage"
	var dead: EventFunction = EventFunction.new()
	dead.function_name = "debug_dump"
	var published: EventFunction = EventFunction.new()
	published.function_name = "reset_run"
	published.expose_as_ace = true
	var lifecycle: EventFunction = EventFunction.new()
	lifecycle.function_name = "_ready"
	sheet.functions = [called, dead, published, lifecycle] as Array[Resource]
	ok = _check("only the function nothing calls is named",
		str(EventSheetDoctorTidiness.uncalled_functions(sheet, "apply_damage(2)")),
		"[\"debug_dump\"]") and ok
	ok = _check("a published function is vocabulary, never dead",
		str(EventSheetDoctorTidiness.uncalled_functions(sheet, "apply_damage(2)\ndebug_dump()")),
		"[]") and ok
	return ok


static func _test_unfired_triggers() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = EventSheetResource.new()
	var fired: SignalRow = SignalRow.new()
	fired.signal_name = "hit"
	fired.trigger = true
	var never: SignalRow = SignalRow.new()
	never.signal_name = "died"
	never.trigger = true
	var plain: SignalRow = SignalRow.new()
	plain.signal_name = "changed"
	plain.trigger = false
	sheet.events = [fired, never, plain] as Array[Resource]
	ok = _check("the declared trigger nothing emits is the only note",
		str(EventSheetDoctorTidiness.unfired_triggers(sheet, "hit.emit(damage)")),
		"[\"died\"]") and ok
	return ok


static func _test_unused_behaviors() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.requires_behaviors = ["FlashBehavior", "BulletBehavior"] as Array[String]
	ok = _check("the attached behavior no row names is reported",
		str(EventSheetDoctorTidiness.unused_behaviors(sheet, "BulletBehavior set_speed 300")),
		"[\"FlashBehavior\"]") and ok
	return ok


static func _test_disabled_events() -> bool:
	var ok: bool = true
	var live: EventRow = EventRow.new()
	var off: EventRow = EventRow.new()
	off.enabled = false
	var buried: EventRow = EventRow.new()
	buried.enabled = false
	off.sub_events = [buried] as Array[Resource]
	ok = _check("only the switched-off parent is numbered, not its buried child",
		str(EventSheetDoctorTidiness.disabled_event_numbers([live, off])), "[2]") and ok
	ok = _check("git can say how many days it has been",
		EventSheetDoctorTidiness.age_words("git", 44), "for 44 days (git)") and ok
	ok = _check("a file date can only say a long time",
		EventSheetDoctorTidiness.age_words("file date", 44), "for a long time (file date)") and ok
	return ok


static func _test_identical_events() -> bool:
	var ok: bool = true
	ok = _check("two events that read identically are paired by their margin numbers",
		str(EventSheetDoctorTidiness.identical_event_pairs(
			[_scoring_event(), _other_event(), _scoring_event()])), "[[1, 3]]") and ok
	ok = _check("a differently-parameterised row is not a duplicate",
		str(EventSheetDoctorTidiness.identical_event_pairs([_scoring_event(), _other_event()])),
		"[]") and ok
	return ok


static func _test_repeated_literals() -> bool:
	var ok: bool = true
	var rows: Array = []
	for index: int in 3:
		rows.append(_literal_event("400"))
	rows.append(_literal_event("1"))
	rows.append(_literal_event("1"))
	rows.append(_literal_event("1"))
	ok = _check("three of the same number is a setting waiting for a name",
		str(EventSheetDoctorTidiness.repeated_literals(rows)), "{ \"400\": 3 }") and ok
	ok = _check("a number is not automatically nameable",
		EventSheetDoctorTidiness.is_nameable_literal("0"), false) and ok
	ok = _check("a quoted string is nameable",
		EventSheetDoctorTidiness.is_nameable_literal("\"jump.wav\""), true) and ok
	ok = _check("an expression belongs to what it names, not to a setting",
		EventSheetDoctorTidiness.is_nameable_literal("speed * 2"), false) and ok
	return ok


static func _test_extract_to_variable() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.events = [_literal_event("400"), _literal_event("400")] as Array[Resource]
	ok = _check("both parameters move over to the name",
		EventSheetDoctorTidiness.extract_literal_to_variable(sheet, "400", "jump_strength"), 2) and ok
	ok = _check("the sheet now declares the name",
		str(sheet.variables.get("jump_strength", {}).get("default", "")), "400") and ok
	ok = _check("the first row reads the name instead of the number",
		str(((sheet.events[0] as EventRow).actions[0] as ACEAction).params.get("value")),
		"jump_strength") and ok
	ok = _check("a name the sheet already uses is refused rather than overwritten",
		EventSheetDoctorTidiness.extract_literal_to_variable(sheet, "400", "jump_strength"), 0) and ok
	ok = _check("a number suggests a legal identifier to start from",
		EventSheetDoctorTidiness.suggested_variable_name("400"), "value_400") and ok
	ok = _check("a quoted string suggests its own words",
		EventSheetDoctorTidiness.suggested_variable_name("\"jump.wav\""), "jump_wav") and ok
	# The note reaches the reader as a one-click chip through the quick-fix seam, carrying the
	# value it is about - the same seam every other one-step Doctor answer goes through.
	ok = _check("the note offers Extract to variable, naming the value",
		str(EventSheetQuickFixes.fixes_for({"check": "repeated-literal", "subject": "400"})),
		"[{ \"id\": \"extract_to_variable\", \"label\": \"⚡ Extract 400 to a variable\", \"check\": \"repeated-literal\" }]") and ok
	ok = _check("a note with no value to name offers nothing",
		EventSheetQuickFixes.fixes_for({"check": "repeated-literal"}).is_empty(), true) and ok
	return ok


static func _scoring_event() -> EventRow:
	var event: EventRow = EventRow.new()
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "AddToVariable"
	action.params = {"variable": "score", "value": "10"}
	event.actions = [action] as Array[Resource]
	return event


static func _other_event() -> EventRow:
	var event: EventRow = EventRow.new()
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "AddToVariable"
	action.params = {"variable": "score", "value": "25"}
	event.actions = [action] as Array[Resource]
	return event


static func _literal_event(literal: String) -> EventRow:
	var event: EventRow = EventRow.new()
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "SetProperty"
	action.params = {"value": literal}
	event.actions = [action] as Array[Resource]
	return event


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] doctor_tidiness_test: %s" % label)
		return true
	print("[FAIL] doctor_tidiness_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
