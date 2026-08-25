# Godot EventSheets - blank events mean what they mean in an event sheet.
#
# A blank SUB-EVENT follows its parent in order: plain statements after the parent's block, never
# `if true:`. A blank TOP-LEVEL event runs every tick: it compiles exactly as an every-tick event
# would, so its actions land in `_process(delta)` and its conditions (if it grew any) are checked
# there. Nothing is stored on the row - blank stays blank on disk - so this pins the COMPILER's
# reading of "blank", plus the fact that a blank event no longer records a "skipping" warning.
@tool
class_name BlankEventTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true

	# A blank top-level event: no trigger, no conditions, one action.
	var sheet: EventSheetResource = EventSheetResource.new()
	var blank: EventRow = EventRow.new()
	blank.actions.append(_action("label.text = str(hp)"))
	sheet.events.append(blank)
	var blank_result: Dictionary = SheetCompiler.compile(sheet, "user://eventforge_blank_event.gd")
	var blank_output: String = str(blank_result.get("output", ""))
	all_passed = _check("a blank top-level event emits the every-tick handler",
		blank_output.contains("func _process(delta: float) -> void:\n\tlabel.text = str(hp)"), true) and all_passed
	all_passed = _check("no `if true:` is written for the blank event",
		blank_output.contains("if true:"), false) and all_passed
	var skip_warning: bool = false
	for warning: Variant in (blank_result.get("warnings", []) as Array):
		if str(warning).contains("no trigger"):
			skip_warning = true
	all_passed = _check("a blank event is no longer reported as skipped", skip_warning, false) and all_passed

	# A blank top-level event that later grew a condition: still every tick, condition checked there.
	var conditioned_sheet: EventSheetResource = EventSheetResource.new()
	var conditioned: EventRow = EventRow.new()
	conditioned.conditions.append(_condition_with_template("hp > 0"))
	conditioned.actions.append(_action("tick()"))
	conditioned_sheet.events.append(conditioned)
	var conditioned_output: String = str(SheetCompiler.compile(
		conditioned_sheet, "user://eventforge_blank_event_conditioned.gd").get("output", ""))
	all_passed = _check("a trigger-less event with a condition checks it every tick",
		conditioned_output.contains("func _process(delta: float) -> void:\n\tif hp > 0:\n\t\ttick()"), true) and all_passed

	# A blank event and an explicit every-tick event share ONE _process handler, in sheet order.
	var shared_sheet: EventSheetResource = EventSheetResource.new()
	var explicit_tick: EventRow = EventRow.new()
	explicit_tick.trigger_provider_id = "Core"
	explicit_tick.trigger_id = "OnProcess"
	explicit_tick.actions.append(_action("first()"))
	var blank_tick: EventRow = EventRow.new()
	blank_tick.actions.append(_action("second()"))
	shared_sheet.events.append(explicit_tick)
	shared_sheet.events.append(blank_tick)
	var shared_output: String = str(SheetCompiler.compile(
		shared_sheet, "user://eventforge_blank_event_shared.gd").get("output", ""))
	all_passed = _check("blank and explicit every-tick events share one handler, in order",
		shared_output.contains("func _process(delta: float) -> void:\n\tfirst()\n\tsecond()"), true) and all_passed
	all_passed = _check("only one _process handler is emitted",
		shared_output.count("func _process("), 1) and all_passed

	# A blank SUB-EVENT is plain statements after its parent's block - no `if`, no `true`.
	var nested_sheet: EventSheetResource = EventSheetResource.new()
	var parent: EventRow = EventRow.new()
	parent.trigger_provider_id = "Core"
	parent.trigger_id = "OnReady"
	var guarded: EventRow = EventRow.new()
	guarded.conditions.append(_condition_with_template("shielded"))
	guarded.actions.append(_action("amount /= 2"))
	parent.sub_events.append(guarded)
	var blank_sub: EventRow = EventRow.new()
	blank_sub.actions.append(_action("hp -= amount"))
	blank_sub.actions.append(_action("flash.play()"))
	parent.sub_events.append(blank_sub)
	nested_sheet.events.append(parent)
	var nested_output: String = str(SheetCompiler.compile(
		nested_sheet, "user://eventforge_blank_subevent.gd").get("output", ""))
	all_passed = _check("a blank sub-event follows its parent's block as plain statements",
		nested_output.contains("\tif shielded:\n\t\tamount /= 2\n\thp -= amount\n\tflash.play()"), true) and all_passed

	# The resolver's own reading of blank, pinned by value.
	var probe: EventRow = EventRow.new()
	all_passed = _check("the resolver reads a blank trigger as the every-tick one",
		TriggerResolver.effective_trigger_id(probe), "OnProcess") and all_passed
	all_passed = _check("a blank event resolves to the _process handler",
		str(TriggerResolver.resolve_trigger(probe).get("function_name", "")), "_process") and all_passed
	probe.trigger_id = "OnReady"
	all_passed = _check("an event that picked a trigger keeps it",
		TriggerResolver.effective_trigger_id(probe), "OnReady") and all_passed

	# The READING of blank, pinned by value: an empty lane for the every-frame tick, one muted note
	# for the physics tick, and the full Every tick words back the moment a condition shows up.
	all_passed = _check("a blank event says nothing in the condition lane",
		str(EventSheetViewportReadingRows.blank_tick_reading("", false).get("note", "MISSING")),
		"") and all_passed
	all_passed = _check("an every-frame handler with no condition says nothing either",
		str(EventSheetViewportReadingRows.blank_tick_reading("OnProcess", false).get("note", "MISSING")),
		"") and all_passed
	all_passed = _check("the physics tick keeps a muted note, because blank cannot say which tick",
		str(EventSheetViewportReadingRows.blank_tick_reading("OnPhysicsProcess", false).get("note", "")),
		"every tick (physics)") and all_passed
	all_passed = _check("a tick event that carries a condition keeps its own words",
		EventSheetViewportReadingRows.blank_tick_reading("OnProcess", true).is_empty(), true) and all_passed
	all_passed = _check("with the Patterns reading off, the explicit Every tick word is back",
		EventSheetViewportReadingRows.blank_tick_reading("OnProcess", false, false).is_empty(), true) and all_passed
	all_passed = _check("every other trigger reads exactly as before",
		EventSheetViewportReadingRows.blank_tick_reading("OnReady", false).is_empty(), true) and all_passed

	# The READING of a blank SUB-event: an empty lane, because "Every Tick" under a parent would
	# be a plain lie about when its rows run. Built through a real viewport over the sheet above, so
	# the gate that decides it (the row is held UNDER another one) is the one the editor uses.
	var nested_viewport: EventSheetViewport = EventSheetViewport.new()
	nested_viewport._sheet = nested_sheet
	all_passed = _check("a blank sub-event says nothing in the condition lane",
		_has_span_text(nested_viewport._build_event_spans(blank_sub), "Every Tick"), false) and all_passed
	all_passed = _check("the sub-event with a condition keeps its own words",
		_has_span_text(nested_viewport._build_event_spans(guarded), "Every Tick"), false) and all_passed
	all_passed = _check("a row the sheet does not hold under anything keeps the placeholder",
		_has_span_text(nested_viewport._build_event_spans(EventRow.new()), "Every Tick"), true) and all_passed
	all_passed = _check("and the hover says which blank rule this one is",
		EventSheetViewportReadingRows.BLANK_SUB_EVENT_HOVER, "follows its parent, in order") and all_passed
	nested_viewport.free()

	# The Doctor's note: a blank event that only sets values is almost always meant to run once.
	var setup_event: EventRow = EventRow.new()
	var set_action: ACEAction = ACEAction.new()
	set_action.provider_id = "Core"
	set_action.ace_id = "SetVariable"
	setup_event.actions.append(set_action)
	all_passed = _check("a blank event that only sets values is a Doctor note",
		EventSheetProjectDoctor._is_setup_only_blank_event(setup_event), true) and all_passed
	setup_event.trigger_id = "OnReady"
	all_passed = _check("an event that picked a trigger is not",
		EventSheetProjectDoctor._is_setup_only_blank_event(setup_event), false) and all_passed
	setup_event.trigger_id = ""
	setup_event.actions.append(_action("queue_free()"))
	all_passed = _check("a blank event that does real work is not either",
		EventSheetProjectDoctor._is_setup_only_blank_event(setup_event), false) and all_passed

	return all_passed


static func _condition_with_template(template: String) -> ACECondition:
	var condition: ACECondition = ACECondition.new()
	condition.provider_id = "Test"
	condition.ace_id = template
	condition.codegen_template = template
	return condition


static func _action(template: String) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Test"
	action.ace_id = template
	action.codegen_template = template
	return action


## True when any of a row's spans carries the given text - what a reader would see in its cells.
static func _has_span_text(spans: Array[SemanticSpan], text: String) -> bool:
	for span: SemanticSpan in spans:
		if span != null and span.text.contains(text):
			return true
	return false


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] blank_event_test: %s" % label)
		return true
	print("[FAIL] blank_event_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
