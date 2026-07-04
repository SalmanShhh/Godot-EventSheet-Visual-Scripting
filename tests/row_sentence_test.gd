# EventForge - the row-as-sentence hover. ViewportRowBuilder.row_sentence reads a
# whole event as one plain-English sentence, built ONLY from the descriptor strings the cells draw, with
# raw-code actions summarised honestly as "then N lines of code". Pins the structure (trigger lead / if /
# do / else / negation / truncation / raw count) without asserting exact ACE phrasing (that would be brittle).
@tool
class_name RowSentenceTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true
	var viewport: EventSheetViewport = EventSheetViewport.new()
	viewport.set_ace_registry(EventSheetACERegistry.new())
	var builder: ViewportRowBuilder = viewport._row_builder
	builder.init(viewport)

	# 1) trigger + condition + two actions → "When every physics tick - if … - do: …"
	var e1: EventRow = EventRow.new()
	e1.trigger_id = "OnPhysicsProcess"
	e1.conditions.append(_cond("IsMoving", false))
	e1.actions.append(_act("Jump"))
	e1.actions.append(_act("Dash"))
	var s1: String = builder.row_sentence(e1)
	ok = _check("leads with the friendly every-tick trigger", s1.begins_with("When every physics tick"), true) and ok
	ok = _check("has an 'if' clause", s1.contains(" if "), true) and ok
	ok = _check("has a 'do:' clause", s1.contains("do: "), true) and ok

	# 2) raw block counts its lines honestly, never invents prose
	var e2: EventRow = EventRow.new()
	e2.trigger_id = "OnReady"
	var raw: RawCodeRow = RawCodeRow.new()
	raw.code = "var a = 1\nvar b = 2\nprint(a + b)"
	e2.actions.append(raw)
	var s2: String = builder.row_sentence(e2)
	ok = _check("raw block summarised as N lines of code", s2.contains("then 3 lines of code"), true) and ok
	ok = _check("On Ready reads as 'ready'", s2.begins_with("When ready"), true) and ok

	# 3) truncation past the action cap of 3
	var e3: EventRow = EventRow.new()
	e3.trigger_id = "OnProcess"
	for index: int in range(5):
		e3.actions.append(_act("Act%d" % index))
	ok = _check("truncates extra actions with (+N more)", builder.row_sentence(e3).contains("(+2 more)"), true) and ok

	# 4) an else row leads with "Else"
	var e4: EventRow = EventRow.new()
	e4.else_mode = EventRow.ElseMode.ELSE
	e4.actions.append(_act("Reset"))
	ok = _check("else row reads as 'Else - do:'", builder.row_sentence(e4).begins_with("Else - do:"), true) and ok

	# 5) a negated condition reads "not …"
	var e5: EventRow = EventRow.new()
	e5.trigger_id = "OnProcess"
	e5.conditions.append(_cond("IsWallSliding", true))
	ok = _check("negated condition reads as 'not'", builder.row_sentence(e5).contains("not "), true) and ok

	# 6) a null row is the empty string (never crashes the tooltip)
	ok = _check("null row → empty sentence", builder.row_sentence(null), "") and ok

	return ok


static func _act(id: String) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Test"
	action.ace_id = id
	return action


static func _cond(id: String, negated: bool) -> ACECondition:
	var condition: ACECondition = ACECondition.new()
	condition.provider_id = "Test"
	condition.ace_id = id
	condition.negated = negated
	return condition


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] row_sentence_test: %s" % label)
		return true
	print("[FAIL] row_sentence_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
