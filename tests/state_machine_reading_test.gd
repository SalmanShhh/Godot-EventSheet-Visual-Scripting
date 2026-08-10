# The state-machine reading layer, all display-only views (rows and compiled output are gated
# elsewhere):
#   1. An Is In State condition renders as a "◆ State: <name>" header - keyed on the method
#      SHAPE (method:is_in_state + a state_name param), so any state-machine-like behavior gets
#      the reading, not just the bundled pack.
#   2. A lifted trigger id resolves its friendly name through the descriptor FALLBACK - the
#      condition path always had it, the trigger path printed raw ids ("OnPhysicsProcess").
#   3. A published signal row leads with the narrow glyph badge; the "Trigger" word pill is gone
#      (a word in a box is a pill, and pills lost that argument).
@tool
class_name StateMachineReadingTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true
	var viewport: EventSheetViewport = EventSheetViewport.new()
	viewport.set_ace_registry(EventSheetACERegistry.new())
	var builder: ViewportRowBuilder = viewport._row_builder

	# 1. The state header view: plain "State: <name>" text, the ◆ diamond as a BADGE span in the
	# trigger-icon column (never inline in the sentence).
	var in_state: ACECondition = ACECondition.new()
	in_state.provider_id = "StateMachineBehavior"
	in_state.ace_id = "method:is_in_state"
	in_state.params = {"state_name": "\"patrol\""}
	ok = _check("Is In State reads as a state header", builder._format_condition_descriptor_base(in_state), "State: patrol") and ok
	in_state.params = {"state_name": "previous_state"}
	ok = _check("an unquoted state expression shows verbatim", builder._format_condition_descriptor_base(in_state), "State: previous_state") and ok
	in_state.params = {"state_name": ""}
	ok = _check("an empty state falls through to normal formatting", builder._format_condition_descriptor_base(in_state).begins_with("State:"), false) and ok
	in_state.params = {"state_name": "\"patrol\""}
	var header_row: EventRow = EventRow.new()
	header_row.conditions.append(in_state)
	var header_texts: PackedStringArray = PackedStringArray()
	var diamond_is_badge: bool = false
	for span: SemanticSpan in builder._build_event_spans(header_row):
		header_texts.append(span.text)
		if span.text == "◆" and bool((span.metadata as Dictionary).get("badge", false)):
			diamond_is_badge = true
	ok = _check("the diamond renders as a badge span", diamond_is_badge, true) and ok
	ok = _check("the diamond never rides inside the text", Array(header_texts).has("◆ State: patrol"), false) and ok

	# 2. Trigger ids resolve friendly names through the descriptor fallback.
	ok = _check("physics trigger reads in words", builder._trigger_display_text("Core", "OnPhysicsProcess"), "Every Physics Tick") and ok
	ok = _check("update trigger reads in words", builder._trigger_display_text("Core", "OnProcess"), "Every Frame") and ok
	ok = _check("unknown signal ids still humanize", builder._trigger_display_text("", "signal:door_opened"), "On Door Opened") and ok

	# 3. The signal row's kind cue is a glyph badge, never a word pill.
	var signal_row: SignalRow = SignalRow.new()
	signal_row.signal_name = "state_changed"
	signal_row.trigger = true
	signal_row.ace_name = "On State Changed"
	var row_data: EventRowData = builder._build_signal_row(signal_row, 0)
	ok = _check("signal row leads with the glyph badge", row_data.spans[0].text, "➜") and ok
	var has_word_pill: bool = false
	for span: SemanticSpan in row_data.spans:
		if span.text == "Trigger" or span.text == "Signal":
			has_word_pill = true
	ok = _check("no Trigger/Signal word pill remains", has_word_pill, false) and ok
	ok = _check("the friendly name still shows", row_data.spans[1].text, "On State Changed") and ok

	viewport.free()
	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] state_machine_reading_test: %s" % label)
		return true
	print("[FAIL] state_machine_reading_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
