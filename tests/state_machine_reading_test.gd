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

	# 1b. A reflected verb reads in WORDS in the condition lane too, not as its raw id. The
	# action lane always had this registry-free fallback; the condition lane leaked
	# "method:can_afford_entry" into the first cell a beginner reads. Pinned against a provider
	# the registry does NOT know, so the fallback itself is what runs (a registered pack
	# resolves its real display name one branch earlier).
	var reflected: ACECondition = ACECondition.new()
	reflected.provider_id = "NoSuchProviderForTest"
	reflected.ace_id = "method:can_afford_entry"
	reflected.params = {"entry_id": "slot_id"}
	ok = _check("a reflected condition reads as a sentence", builder._format_condition_descriptor_base(reflected), "Can Afford Entry ( slot_id )") and ok
	var reflected_bare: ACECondition = ACECondition.new()
	reflected_bare.provider_id = "NoSuchProviderForTest"
	reflected_bare.ace_id = "method:is_sold_out"
	ok = _check("a param-less reflected condition is just its name", builder._format_condition_descriptor_base(reflected_bare), "Is Sold Out") and ok
	var unknown: ACECondition = ACECondition.new()
	unknown.provider_id = "NoSuchProviderForTest"
	unknown.ace_id = "NotAMethodId"
	ok = _check("a non-reflected unknown id is left alone", builder._format_condition_descriptor_base(unknown), "NotAMethodId") and ok

	# 2. Trigger ids resolve friendly names through the descriptor fallback.
	ok = _check("physics trigger reads in words", builder._trigger_display_text("Core", "OnPhysicsProcess"), "Every Physics Tick") and ok
	ok = _check("update trigger reads in words", builder._trigger_display_text("Core", "OnProcess"), "Every Frame") and ok
	ok = _check("unknown signal ids still humanize", builder._trigger_display_text("", "signal:door_opened"), "On Door Opened") and ok
	ok = _check("an on_-named signal never reads On On", builder._trigger_display_text("", "signal:on_quest_completed"), "On Quest Completed") and ok

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

	# 4. A lifted `match` on a state-shaped subject reads in the same grammar: case rows carry
	# the ◆ badge and "State: <leaf>" text; other matches (and the `_` default) keep their
	# pattern text untouched.
	ok = _check("state subject detected", builder._is_state_shaped_subject("state"), true) and ok
	ok = _check("dotted state subject detected", builder._is_state_shaped_subject("machine.current_state"), true) and ok
	ok = _check("non-state subject passes through", builder._is_state_shaped_subject("damage_type"), false) and ok
	ok = _check("enum pattern leafs", builder._pattern_leaf("State.PATROL"), "PATROL") and ok
	ok = _check("quoted pattern leafs", builder._pattern_leaf("\"patrol\""), "patrol") and ok
	var match_event: EventRow = EventRow.new()
	var lifted_match: MatchRow = MatchRow.new()
	lifted_match.match_expression = "state"
	var patrol_case: MatchCase = MatchCase.new()
	patrol_case.pattern = "State.PATROL"
	var patrol_body: RawCodeRow = RawCodeRow.new()
	patrol_body.code = "patrol_step(delta)"
	patrol_case.events = [patrol_body]
	lifted_match.cases.append(patrol_case)
	match_event.actions.append(lifted_match)
	var case_rows: Array[EventRowData] = builder._build_match_case_rows(match_event, 1)
	ok = _check("one case row built", case_rows.size(), 1) and ok
	ok = _check("case row leads with the state badge", case_rows[0].spans[0].text, "◆") and ok
	ok = _check("case row reads State: leaf", case_rows[0].spans[1].text, "State: PATROL") and ok
	# M37 - a match on an ORDINARY value is not a state machine at all, and an event sheet has no switch:
	# it reads as the if / else-if chain an event-sheet user knows, so the first case states the test.
	lifted_match.match_expression = "damage_type"
	var plain_rows: Array[EventRowData] = builder._build_match_case_rows(match_event, 1)
	ok = _check("a non-state match reads as its test", plain_rows[0].spans[0].text, "damage_type = State.PATROL") and ok

	# 5. A case body's if block is a nested CONDITION row whose guard SPEAKS: a bare self-call
	# humanizes ("Can See Player"), `not` reads as the word Not - a beginner never meets
	# parentheses in a condition cell.
	lifted_match.match_expression = "state"
	var spot: RawCodeRow = RawCodeRow.new()
	spot.code = "if can_see_player():
	state = State.CHASE"
	patrol_case.events = [patrol_body, spot]
	var guarded_rows: Array[EventRowData] = builder._build_match_case_rows(match_event, 1)
	ok = _check("the transition is a child row of its state", guarded_rows[0].children.size(), 1) and ok
	var transition: EventRowData = guarded_rows[0].children[0]
	ok = _check("the guard leads with the ƒ badge", transition.spans[0].text, "ƒ") and ok
	ok = _check("the ƒ is a badge span, not text", bool((transition.spans[0].metadata as Dictionary).get("badge", false)), true) and ok
	ok = _check("the guard humanizes in the condition cell", transition.spans[1].text, "Can See Player") and ok
	ok = _check("the effect reads as a sentence in the action cell", transition.spans[2].text, "Set state to State.CHASE") and ok
	spot.code = "if not can_see_player():
	state = State.PATROL"
	var negated_rows: Array[EventRowData] = builder._build_match_case_rows(match_event, 1)
	# M12 - the inversion is the red ✕ in the badge column, the same mark an inverted ACE condition
	# wears, and the SENTENCE is the positive one. It used to read "Not Can See Player"; a word in
	# the middle of a sentence is easy to skim past, and it meant the sheet had two ways of saying
	# "inverted" depending on where the condition came from.
	var negated_transition: EventRowData = negated_rows[0].children[0]
	var negated_texts: PackedStringArray = PackedStringArray()
	for span: SemanticSpan in negated_transition.spans:
		negated_texts.append(span.text)
	ok = _check("a negated guard draws the invert mark", negated_texts.has("✕"), true) and ok
	ok = _check("the invert mark is a badge span, not text",
		bool((negated_transition.spans[negated_texts.find("✕")].metadata as Dictionary).get("badge", false)), true) and ok
	ok = _check("a negated guard's sentence is the positive one",
		negated_texts.has("Can See Player"), true) and ok
	ok = _check("a negated guard never says the word Not",
		" ".join(negated_texts).contains("Not"), false) and ok

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
